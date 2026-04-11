# CLAUDE.md — e2ee_chat_sdk

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Read this file completely before writing a single line of code.

## Package Identity

- **Package name:** `e2ee_chat_sdk` (pubspec.yaml confirms this)
- **Barrel file:** `engine/lib/e2ee_chat.dart` — the only file external code imports
- **Backward-compat shim:** `engine/lib/chat_engine.dart` re-exports `e2ee_chat.dart`. **New code must import from `package:e2ee_chat_sdk/e2ee_chat.dart`.**
- **Concrete entry point:** `ChatEngineImpl.initialize(config)` — `ChatEngineImpl` is the concrete class. The abstract `ChatEngine` class has no `initialize` method.
- **Version:** 0.1.0 (`publish_to: none` — private SDK)

## Commands

```bash
# Testing
flutter test                            # Run all 35 test files
flutter test test/crypto/               # Crypto tests only
flutter test test/discovery/            # Discovery pipeline tests only
flutter test test/crypto/ratchet_test.dart  # Single test file

# Code generation (freezed, drift ORM)
dart run build_runner build --delete-conflicting-outputs

# Analysis & formatting
dart analyze                            # Lint with very_good_analysis (0 errors target)
dart format .

# Dependencies
flutter pub get
```

---

## Architectural Principles

### 1. Engine, Not an App

This is a **headless Flutter package** (`e2ee_chat_sdk`). Zero UI code — no widgets, no themes, no animations. The UI lives in `~/hello/app/`.

- Exposes a clean public API surface via `ChatEngineImpl`, `ChatSession`, and the barrel file
- Host apps inject auth tokens, user identity, device ID, and push token — nothing else
- Zero dependencies on any UI framework, router, or state manager
- Must compile and run identically on: iOS, Android, Web (WASM), macOS, Windows, Linux
- **Do not create any widget, screen, or visual component in this package**

### 2. Offline-First, Sync-Second

The engine functions fully offline and syncs when connectivity is restored.

- All messages written to local encrypted storage first (SQLCipher via drift)
- Outbox queue with retry logic, deduplication, and ordering guarantees
- Sync protocol handles gaps, re-ordering, and conflict resolution without data loss
- UI never waits for network confirmation to display a sent message

### 3. Layered Separation (Strict)

```
  ~/hello/app/ (EXTERNAL — not this repo)
  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
  UI Layer — widgets, themes, animations
  Consumes ChatEngine via pub dependency
  ═══════════════════════════════════════════
  THIS REPO (e2ee_chat_sdk package):
┌───────────────────────────────────────────┐
│         Public API (barrel file)          │  ← The only thing external code imports.
├───────────────────────────────────────────┤
│           Domain Layer                    │  ← Pure Dart. Zero Flutter deps.
├───────────────────────────────────────────┤
│         Crypto / Security Layer           │  ← Isolated. Tested independently.
├───────────────────────────────────────────┤
│        Transport / Network Layer          │  ← WebSocket + HTTP. Pluggable.
├───────────────────────────────────────────┤
│         Persistence Layer                 │  ← Encrypted local DB. Abstracted.
└───────────────────────────────────────────┘
```

**No layer may import from a layer above it.** Violations are bugs, not style issues.

---

## Public API Contract

Everything external code touches is exported from `engine/lib/e2ee_chat.dart`. Nothing else is public.

### Initialization

```dart
// ChatEngineConfig — all fields:
class ChatEngineConfig {
  final String authToken;         // Opaque token from host's auth system
  final String userId;            // Authenticated user ID (text format, e.g. "name_ram")
  final int deviceId;             // Unique per-device INTEGER — matches backend schema
  final String pushToken;         // FCM/APNs token
  final Uri serverBaseUrl;        // WebSocket + REST base URL
  final String supabaseAnonKey;   // Required for PostgREST access (defaults to '')
  final ChatEngineObserver? observer;  // Optional diagnostics hook
  final BrandConfig brand;        // White-label config (default: hello brand)
}

// Entry point — call ChatEngineImpl.initialize, NOT ChatEngine.initialize.
// ChatEngine is abstract and has no static initialize method.
final engine = await ChatEngineImpl.initialize(ChatEngineConfig(
  authToken: token,
  userId: 'name_ram',
  deviceId: 1,                    // int, not String
  pushToken: fcmToken,
  serverBaseUrl: Uri.parse('https://gethello.ai'),
  supabaseAnonKey: anonKey,
  brand: BrandConfig(appName: 'hello', aiName: '@hello'),
));
```

### ChatEngine (abstract — top-level handle)

```dart
abstract class ChatEngine {
  ChatSession getSession(String groupId);

  Stream<List<Conversation>> get conversations;       // Pinned-first, then updatedAt desc
  Stream<EngineConnectionState> get connectionState;  // NOT ConnectionState — EngineConnectionState
  Stream<int> get totalUnreadCount;
  Stream<ChatEngineError> get errors;

  Future<List<ContactMatch>> discoverContacts(List<String> phoneHashes);
  Future<UserProfile> getProfile(String userId);
  Future<void> updateProfile({String? displayName, String? photoUrl});
  Future<List<DeviceInfo>> getDevices();
  Future<void> unlinkDevice(int deviceId);            // deviceId is int
  Future<String> getDisplayName(String userId);       // Cached
  Future<Conversation> createGroup({required String title, String? atmosphere});
  Future<String> findOrCreateChat(String peerId);     // 1:1 X3DH session
  Future<InviteLink> generateInvite();
  Future<JoinResult> claimInvite(String code);

  Stream<HelloResponseChunk> streamHelloResponse({
    required String prompt,
    required String groupId,
  });

  Future<void> suspend();   // App backgrounded
  Future<void> resume();    // App foregrounded
  Future<void> dispose();   // Full teardown — zeroes key material in memory
}
```

**Note:** `updatePushToken` does NOT exist. Push token is provided at init time in `ChatEngineConfig.pushToken`.

### ChatSession (per-conversation handle)

```dart
abstract class ChatSession {
  Stream<List<Message>> get messages;       // Decrypted, ordered, deduplicated
  Stream<List<TypingIndicator>> get typing; // Ephemeral, clears after 5s
  Stream<List<Receipt>> get receipts;       // Delivered + read
  Stream<PresenceState> get presence;       // Online/last-seen (1:1 only)

  Future<Message> sendText(String plaintext);
  Future<Message> sendMedia(MediaPayload payload);
  Future<void> sendTyping();
  Future<void> markRead(String messageId);
  Future<void> react(String messageId, String emoji);
  Future<void> deleteForMe(String messageId);        // Local delete only
  Future<void> deleteForEveryone(String messageId);  // Revokes for all participants
  Future<List<Message>> loadMore({int limit = 50});
  Future<KeyFingerprint> getKeyFingerprint();
}
```

### ChatEngineDecisions (optional mixin)

Applied to `ChatEngineImpl` via `with ChatEngineDecisions`. Check before use:

```dart
if (engine is ChatEngineDecisions) {
  await engine.getDecisionItems('group_123');   // Future<List<DecisionItem>>
  await engine.reactToItem('item_1', 'love_it'); // love_it / works_for_me / not_for_me
  await engine.lockItem('item_1', proof);        // CommitmentProof — Green-Lock

  // E2EE oblivious decision payloads:
  final encrypted = await engine.encryptPayload(groupId: gid, plaintext: json);
  // returns Map<String, String> { 'ciphertextPayload': ..., 'nonce': ... }
  await engine.addDecisionItem(gid, ciphertextPayload: ..., nonce: ...);
  final plain = await engine.decryptPayload(groupId: gid, ciphertext: ..., nonce: ...);
}
```

### AuthService (call BEFORE ChatEngineImpl.initialize)

```dart
final auth = AuthService(serverBaseUrl);
final result = await auth.authenticateWithFirebase(firebaseIdToken: token);
// result.accessToken → feed into ChatEngineConfig.authToken
```

### Exported Models

`Message`, `Conversation`, `Receipt`, `TypingIndicator`, `PresenceState`, `ContactMatch`, `KeyFingerprint`, `MediaPayload`, `MediaMetadata`, `DecryptedMessage`, `HelloResponseChunk`, `InviteLink`, `JoinResult`, `UserProfile`, `CommitmentProof`, `DecisionItem`, `BrandConfig`, `ChatEngineError`, `EngineConnectionState`, `UploadProgress`, `ChatEngineObserver`.

All models are **freezed** immutable classes. Internal models (`RatchetState`, `SessionKey`, `PreKeyBundle`, etc.) are never exported.

---

## Package & Module Structure

```
engine/
├── lib/
│   ├── e2ee_chat.dart            # Canonical public barrel (import this)
│   ├── chat_engine.dart          # Backward-compat shim — re-exports e2ee_chat.dart only
│   └── src/
│       ├── chat_engine_impl.dart     # ChatEngineImpl (concrete, at src/ root)
│       ├── chat_session_impl.dart    # ChatSessionImpl (concrete, at src/ root)
│       ├── adapters/             # Pluggable transport adapter implementations
│       ├── auth/                 # AuthService, AppLockManager
│       ├── config/               # BrandConfig
│       ├── contacts/             # Private contact discovery (truncated SHA-256)
│       ├── crypto/               # Signal Protocol implementation
│       │   ├── franking/         # MessageFranking (abstract interface — NO impl yet)
│       │   ├── keys/             # Key management, hardware key store, DatabaseKeyManager
│       │   ├── media/            # Streaming AEAD (64KB chunks, up to 2GB)
│       │   ├── pqxdh/            # Post-quantum hybrid X25519 + Kyber-1024 (STUB — see below)
│       │   ├── profile/          # Profile key encryption
│       │   ├── ratchet/          # Double Ratchet with bounded skipped-key dictionary
│       │   ├── sender_keys/      # Group cipher, SK recovery handler
│       │   └── x3dh/             # Extended Triple Diffie-Hellman
│       ├── devices/              # DeviceRegistry + DeviceLinking (abstract — NO Supabase impl yet)
│       ├── discovery/            # Taste-ranked discovery pipeline (see below)
│       │   ├── cache/            # DiscoveryCache
│       │   ├── feedback/         # ErrorCapture, FeedbackCollector
│       │   ├── models/           # CarouselCard, DiscoveryFilter, DiscoveryItem,
│       │   │                     #   DiscoveryItemDetail, ErrorReport, TasteProfile
│       │   └── ranking/          # TasteRanker, TasteSignal
│       ├── domain/               # Freezed models, repositories, use cases (pure Dart)
│       ├── extensions/           # ChatEngineDecisions mixin
│       ├── intelligence/         # OnDeviceSLM abstract + FallbackSLM (regex only — see below)
│       ├── media/                # BackgroundUploader, link unfurling, UploadProgress
│       ├── notifications/        # PushDecryptor, PushHandler, PushMethodChannel
│       ├── observer/             # ChatEngineObserver, E2EE diagnostic events
│       ├── persistence/          # Drift ORM + SQLCipher, repositories, local feed
│       ├── ports/                # Transport interfaces (MessageGateway, RealtimeGateway,
│       │                         #   TransientQueue, PushAdapter, AIAdapter)
│       ├── public_api/           # ChatEngine (abstract), ChatSession (abstract), ChatEngineConfig
│       ├── sync/                 # SyncCoordinator, OutboxProcessor, GapDetector,
│       │                         #   ConflictResolver, WatermarkSync
│       └── transport/            # SupabaseClientWrapper, RealtimeListener, typing, receipts
├── test/                         # 35 test files (see Test Infrastructure)
└── pubspec.yaml                  # name: e2ee_chat_sdk
```

**No `src/ui/` directory.** Zero Flutter widget code. UI lives in `~/hello/app/`.

**The `crypto/` directory is sacred.** Every function in it has a unit test. No exceptions.

---

## Discovery Pipeline (`engine/lib/src/discovery/`)

Full taste-ranked discovery pipeline. Exports via barrel: `DiscoveryMixin`, `CarouselCard`, `DiscoveryFilter`, `DiscoveryItem`, `DiscoveryItemDetail`, `ErrorReport`, `TasteProfile`.

Ranking is via `TasteRanker` + `TasteSignal` (implicit feedback loop). Caching via `DiscoveryCache`. Error capture via `ErrorCapture` and `FeedbackCollector`. 10 test files under `engine/test/discovery/`.

---

## Critical Stubs and Partial Implementations

**These must be flagged and resolved before any production deployment.**

### PQXDH Kyber-1024 — STUB

`engine/lib/src/crypto/pqxdh/kyber.dart` re-exports `StubKyber` from `pqxdh.dart`.

From the source comments:
> "Stub Kyber-1024 implementation for protocol testing. Uses random bytes as a placeholder. In production, replace with a real Kyber-1024 implementation (e.g., via FFI to liboqs or a pure-Dart port). Real Kyber-1024 key sizes: 1568B public, 3168B secret, 1568B ciphertext. This stub uses 32-byte keys for simplicity."

**Consequence:** The PQXDH protocol layer (combining DH + KEM via HKDF) is correctly implemented, but the KEM is not real. Any code that checks or persists key material sizes will break when a real Kyber-1024 library is swapped in. Do not ship post-quantum claims without a real Kyber implementation.

### MessageFranking — NO concrete implementation

`engine/lib/src/crypto/franking/` defines an abstract `MessageFranking` interface. There is no concrete implementation in the engine. E2EE moderation via franking is not yet functional.

### Interactive Notifications — STUB

`notifications/interactive_actions.dart::DefaultInteractiveHandler` has empty method bodies. `registerCategories` and `handleAction` are stubs.

### DeviceRegistry / DeviceLinking — Interfaces only

Both are abstract interfaces with no Supabase-backed concrete implementation. Multi-device fan-out is defined at the crypto layer (Sesame protocol) but is not end-to-end wired.

### DatabaseFactory — CRITICAL: Web build is unencrypted

`engine/lib/src/persistence/database/database_factory_stub.dart` (used when `dart.library.js_interop` is the compilation target, i.e., Web/WASM) returns an **unencrypted in-memory database**. The native implementation (`database_factory_native.dart`) correctly uses SQLCipher.

**This means the E2EE "at rest" guarantee does not hold on Web.** This is the "DatabaseFactory disabled" critical issue from the prior code review. Fix before any web deployment that claims at-rest encryption.

### OnDeviceSLM — Regex fallback only

`engine/lib/src/intelligence/` defines `OnDeviceSLM` as an abstract interface. The only concrete implementation is `FallbackSLM`, which uses regex-based pattern matching. No CoreML, NNAPI, or real ML inference is connected.

---

## Test Infrastructure

35 test files across 10 categories. Run all with `flutter test` from `engine/`.

| Category | Count | Path |
|---|---|---|
| crypto | 10 | `test/crypto/` |
| discovery | 10 | `test/discovery/` |
| transport | 4 | `test/transport/` |
| domain | 2 | `test/domain/` |
| interop | 2 | `test/interop/` |
| integration | 1 | `test/integration/` |
| media | 1 | `test/media/` |
| persistence | 1 | `test/persistence/` |
| sync | 1 | `test/sync/` |
| root | 1 | `test/` (public_api_test.dart) |

---

## Security Requirements (Non-Negotiable)

This section defines hard requirements. They are not suggestions. Do not ship code that violates them.

### Encryption Protocol
- **Signal Protocol** (Double Ratchet + X3DH) for 1:1 messaging — use `cryptography` package (pure Dart, works on all platforms including Web/WASM; libsignal FFI does not)
- **Sender Keys** for group chats (2-15 members)
- **No server-side key escrow** — the server never sees plaintext, never stores private keys, never has the ability to decrypt messages
- Keys are generated on-device. Identity keys are backed up only with user-controlled passcodes

### Key Management
- Identity Key Pair: `Ed25519` (signing) + `X25519` (key exchange)
- Signed PreKeys: rotated every 7 days
- One-Time PreKeys: 100 uploaded at registration, replenished as consumed
- Session keys: never written to disk in plaintext
- **HKDF info strings use `XarkE2EE-*` prefix** — these are cryptographic constants. Do NOT rename them.

### Transport Security
- All connections over **TLS 1.3** minimum
- Certificate pinning enabled by default in production builds
- WebSocket frames carry only ciphertext — no metadata leakage in payload

### Local Storage
- All persisted data encrypted at rest using device-derived keys + user PIN/biometric
- Secure key storage via platform keychain (iOS Keychain, Android Keystore)
- Message database encrypted with SQLCipher (**except Web — see DatabaseFactory stub above**)
- No plaintext logs in production

### Threat Model
- Compromised server (server sees only ciphertext)
- Stolen device (local DB encrypted, keys protected)
- Network interception (TLS + certificate pinning)
- Metadata analysis (minimize server-observable metadata)
- Forward secrecy attacks (Double Ratchet — per-message key derivation)

### Multi-Device Architecture
Sessions are established between **devices**, not users.

- Every device gets its own Identity Key Pair, Signed PreKey, and One-Time PreKeys
- Server maintains a device registry: `userId → [deviceId1, deviceId2, ...]` (max 5 devices)
- Sender fetches PreKey bundles for **all** recipient devices; sends N ciphertexts (one per device)
- Device linking: primary device transfers encrypted history over local encrypted channel (QR + proximity)
- Unlinking a device revokes its keys and rotates the Sender Key for all shared groups

### Media Encryption Pipeline
Large files do not pass through the Double Ratchet.

- Sender generates one-time random AES-256-GCM key
- Sender encrypts file locally; encrypted blob uploaded to dumb storage bucket
- Sender sends `{ downloadUrl, aesKey, iv, sha256Hash }` through the ratchet as a normal E2EE message
- Recipient decrypts ratchet message, downloads blob, verifies SHA-256, decrypts with AES key
- Thumbnails follow the same pipeline (separate key, separate upload)

### Push Notification Decryption
- **iOS:** Notification Service Extension (Swift) — decrypts within 30-second iOS budget
- **Android:** FirebaseMessagingService (Kotlin) — decrypts in background worker
- **Web:** Service Worker intercepts push event, decrypts, shows `Notification`
- Server push payload contains only: `{ recipientDeviceId, encryptedPayload }` — no plaintext metadata
- Failed decryption: fall back to "New Message" — never expose failure reason

### Contact Discovery
- Client-side: truncated SHA-256 (first 10 bytes) per phone number before sending to server
- Server returns only the intersection of registered hashes — never sees full phone numbers
- Discovery requests are batched and rate-limited

### Profile Metadata Encryption
- Each user has a **Profile Key** (32-byte random symmetric key)
- Profile picture, display name, status encrypted with Profile Key before upload
- Profile Key shared only with verified contacts via E2EE message
- Profile Key rotation: on contact removal, generate new key and re-distribute

---

## Performance Targets

| Metric | Target |
|---|---|
| Message encrypt + enqueue (online) | < 50ms |
| Engine initialize to `connected` | < 2 seconds |
| Incoming message decrypt + emit on stream | < 20ms |
| Incoming push decrypt (native extension) | < 500ms end-to-end |
| Offline message queue drain on reconnect | < 3 seconds for 50 queued msgs |
| Encryption overhead per message | < 5ms on mid-range device |
| Media encrypt (10MB file) | < 500ms in background isolate |

### Engine Performance Rules
- Crypto operations always run in a separate `Isolate` — never block the calling thread
- Media compression and encryption happen in background isolates
- Streams emit immutable snapshots — never mutate a previously emitted list
- DB queries are batched where possible

---

## Technology Decisions

| Concern | Choice | Rationale |
|---|---|---|
| Local DB | **SQLCipher via drift** | SQL-level encryption, migration support |
| Secure Storage | **flutter_secure_storage** | Platform keychain integration |
| Networking | **supabase_flutter** + **http** | Realtime + REST via Supabase |
| Crypto | **cryptography** (pure Dart) | Cross-platform (including Web/WASM) |
| Media | Raw byte streams + background uploader | No image/video display libs — UI handles rendering |
| Notifications | **firebase_messaging** (data messages only) | Platform push relay; native extensions handle decrypt |
| Serialization | **freezed** + **json_serializable** | Immutable models, null-safe |
| IDs | **UUID v7** via `uuid` package | Time-ordered, client-generated, embeds timestamp |

Do not introduce new dependencies without justification. Every dependency is an attack surface and a maintenance burden.

---

## Error Taxonomy

All errors the engine surfaces. The UI and host must handle these — they are typed, not arbitrary strings.

```dart
sealed class ChatEngineError {
  // Crypto
  SessionNotFound(String recipientDeviceId);
  DecryptionFailed(String messageId);
  PreKeyExhausted(String userId);
  KeyVerificationFailed(String userId);

  // Transport
  ConnectionLost();
  ConnectionTimeout();
  ServerError(int statusCode, String body);

  // Auth
  AuthTokenExpired();
  DeviceRevoked(String deviceId);

  // Storage
  DatabaseCorrupted();
  BiometricUnavailable();
  StorageFull();

  // Media
  MediaUploadFailed(String mediaId);
  MediaDownloadFailed(String url);
  MediaDecryptionFailed(String mediaId);

  // Sync
  OutboxFull(int pendingCount);
  DuplicateMessage(String messageId);
}
```

The UI decides how to render each error. The engine never shows toasts, dialogs, or snackbars.

---

## Observability

```dart
abstract class ChatEngineObserver {
  void onSessionEstablished(String userId, int deviceId);
  void onSessionFailed(String userId, int deviceId, ChatEngineError error);
  void onPreKeyReplenishment(int keysUploaded, int keysRemaining);
  void onSyncCompleted(int messagesPulled, Duration elapsed);
  void onOutboxDrained(int messagesSent, int messagesFailed);
  void onRatchetAdvanced(String sessionId, int chainIndex);
  void onMediaUpload(String mediaId, int bytes, Duration elapsed);
  void onMediaDownload(String mediaId, int bytes, Duration elapsed);
  void onWebSocketStateChange(EngineConnectionState from, EngineConnectionState to);
  void onContactDiscovery(int hashesSent, int matchesFound);
  void onProfileKeyRotation(String userId);
  void onDeviceLinked(int deviceId);
  void onDeviceRevoked(int deviceId);
}
```

- Pass a `ChatEngineObserver` in `ChatEngineConfig` — all methods have no-op defaults
- **Never log plaintext, keys, or user content in observer callbacks** — only event names, IDs, counts, and durations
- In debug builds, the engine logs to `dart:developer` at `Level.FINE` — production builds emit nothing

---

## Hard Rules

1. **Never write plaintext message storage.** If a message touches disk, it is encrypted.
2. **Never block the calling isolate with crypto or I/O.** Use `compute()` or dedicated isolates.
3. **Never expose internal implementation details in the public API.** Hide everything behind the barrel file.
4. **Never assume network availability.** Every operation has an offline path.
5. **Never write a crypto function without a test.** Security-critical code with no tests is a liability.
6. **Never create widgets, screens, or any visual code.** This is a headless engine. UI lives in `~/hello/app/`.

---

## API Stability Policy

- **Public API** = everything exported from `engine/lib/e2ee_chat.dart`
- Breaking changes = **major** version bump
- New methods/streams/models = **minor** version bump
- Bug fixes, crypto patches, internal refactors = **patch** version bump
- All `src/` internals are private — changes to them are never breaking
- Deprecations: mark with `@Deprecated('Use X instead. Will be removed in vN+1')`, remove one major version later

---

## Code Style

- Dart analysis: `very_good_analysis` (strict)
- Commit messages: Conventional Commits (`feat:`, `fix:`, `crypto:`, `perf:`, `test:`)
- File length soft limit: 300 lines
