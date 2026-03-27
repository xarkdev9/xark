# CLAUDE.md — E2EE Flutter Chat Engine

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Read this file completely before writing a single line of code.

## Commands

```bash
# Development
flutter run                          # Run on connected device/emulator
flutter run -d chrome                # Run on web (Chrome)
flutter run -d macos                 # Run on macOS desktop

# Testing
flutter test                         # Run all tests
flutter test test/crypto/            # Run crypto tests only
flutter test test/crypto/ratchet_test.dart  # Run single test file

# Code generation (freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Analysis & formatting
dart analyze                         # Lint with very_good_analysis
dart format .                        # Format all Dart files

# Dependencies
flutter pub get                      # Install dependencies
```

## Project Mission

Production-grade, end-to-end encrypted chat **engine** in Flutter. This is a headless library package (`hello_engine`) — it owns crypto, transport, persistence, and sync. It does **not** own UI. The UI is developed separately in `~/hello/app/`.

Portable (embeddable as a package into any Flutter app), scalable (millions of concurrent users), secure by default (no plaintext fallback, ever). Target feature set: WhatsApp parity on the protocol/data side (see FEATURES.md for engine vs UI responsibility split).

---

## Architectural Principles

### 1. Engine, Not an App
The chat system is a **headless Flutter package** (`hello_engine`). It has zero UI code — no widgets, no themes, no animations. The UI lives in `~/hello/app/`.

- Exposes a clean public API surface: `ChatEngine.initialize()`, `ChatSession`, `ChatController` (see Public API Contract below)
- Host apps inject auth tokens, user identity, device ID, and push token — nothing else
- Zero dependencies on any UI framework, router, or state manager
- Must compile and run identically on: iOS, Android, Web (WASM), macOS, Windows, Linux
- **Do not create any widget, screen, or visual component in this package**

### 2. Offline-First, Sync-Second
The engine must function fully offline and sync when connectivity is restored.

- All messages written to local encrypted storage first (SQLCipher via drift)
- Outbox queue with retry logic, deduplication, and ordering guarantees
- Sync protocol handles gaps, re-ordering, and conflict resolution without data loss
- UI never waits for network confirmation to display a sent message

### 3. Layered Separation (Strict)

```
  ~/hello/app/ (EXTERNAL — not this repo)
  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
  UI Layer — widgets, themes, animations
  Consumes ChatEngine via pub dependency
  ═══════════════════════════════════════════
  THIS REPO (hello_engine package):
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

## Security Requirements (Non-Negotiable)

This section defines hard requirements. They are not suggestions. Do not ship code that violates them.

### Encryption Protocol
- **Signal Protocol** (Double Ratchet + X3DH) for 1:1 messaging — use `cryptography` package (pure Dart, works on all platforms including Web/WASM; libsignal FFI does not)
- **Sender Keys** for group chats
- **No server-side key escrow** — the server never sees plaintext, never stores private keys, never has the ability to decrypt messages
- Keys are generated on-device. Identity keys are backed up only with user-controlled passcodes (not server-synced)

### Key Management
- Identity Key Pair: `Ed25519` (signing) + `X25519` (key exchange)
- Signed PreKeys: rotated every 7 days
- One-Time PreKeys: 100 uploaded at registration, replenished as consumed
- Session keys: never written to disk in plaintext

### Transport Security
- All connections over **TLS 1.3** minimum
- Certificate pinning enabled by default in production builds
- WebSocket frames carry only ciphertext — no metadata leakage in payload

### Local Storage
- All persisted data encrypted at rest using device-derived keys + user PIN/biometric
- Secure key storage via platform keychain (iOS Keychain, Android Keystore)
- Message database encrypted with SQLCipher or equivalent
- No plaintext logs in production. Log levels enforced by build flavor.

### Threat Model Awareness
Claude must understand we defend against:
- Compromised server (server sees only ciphertext)
- Stolen device (local DB encrypted, keys protected)
- Network interception (TLS + certificate pinning)
- Metadata analysis (minimize server-observable metadata where possible)
- Forward secrecy attacks (Double Ratchet guarantees per-message key derivation)

### Multi-Device Architecture
Sessions are established between **devices**, not users. If Alice has a phone and a laptop, Bob encrypts and sends two distinct ciphertexts — one per device.

- Every device gets its own Identity Key Pair, Signed PreKey, and One-Time PreKeys
- The server maintains a **device registry** per user: `userId → [deviceId1, deviceId2, ...]`
- When sending a message, the sender fetches PreKey bundles for **all** of the recipient's devices, establishes/reuses a session with each, and sends N ciphertexts (one per device)
- Linking a new device requires a **device-linking protocol**: the primary device transfers the encrypted message history to the new device over a local encrypted channel (QR code + proximity, like Signal) — the server never mediates this transfer
- Device limit: 5 linked devices per user (1 primary + 4 linked)
- Unlinking a device revokes its keys and rotates the Sender Key for all groups the user is in

### Media Encryption Pipeline
Large files (images, video, documents) do **not** pass through the Double Ratchet. The ratchet is for small message payloads only.

- Sender generates a one-time random AES-256-GCM key
- Sender encrypts the file locally with that key
- Encrypted blob is uploaded to a dumb REST storage bucket (server sees only ciphertext)
- Sender packages `{ downloadUrl, aesKey, iv, sha256Hash }` into a small JSON payload
- That JSON payload is sent through the Double Ratchet as a normal E2EE message
- Recipient decrypts the ratchet message, downloads the blob, verifies the SHA-256 hash, decrypts with the AES key
- The storage bucket enforces no access control beyond URL — security comes entirely from the AES key being E2EE-protected
- Thumbnails follow the same pipeline (separate key, separate upload) so the server never sees even a preview

### Push Notification Decryption
A blank "New Message" push is unacceptable UX. The app must decrypt notifications in the background before the user sees them.

- **iOS**: Build a **Notification Service Extension** (native Swift). When a silent push arrives, the extension wakes a minimal crypto isolate, fetches the encrypted payload from the server, decrypts it using keys from the shared Keychain (App Group), mutates the `UNNotificationContent` to show sender name + message preview, and returns — all within the 30-second iOS budget
- **Android**: Use a **FirebaseMessagingService** (native Kotlin). On data-message receipt, decrypt in a background worker, then post a local notification with plaintext content
- **Web**: Service Worker intercepts the push event, decrypts, and shows a `Notification` with the plaintext
- The server push payload contains only: `{ recipientDeviceId, encryptedPayload }` — no sender name, no message preview, no metadata
- If decryption fails (e.g., missing session), fall back to a generic "New Message" notification — never expose why it failed

### Contact Discovery
Uploading a raw contact book to the server leaks the user's social graph. Contact discovery must be privacy-preserving.

- Client-side: hash each phone number with a truncated SHA-256 (first 10 bytes) before sending to the server
- Server: maintains a hash table of registered user hashes — returns only the intersection (which contacts are on the platform)
- The server never sees full phone numbers during discovery
- Discovery requests are batched and rate-limited to prevent enumeration attacks
- The contact hash table is ephemeral — the server does not permanently log discovery queries
- Phase 1 simplification: hashed phone number lookup is sufficient. SGX/TEE-based private set intersection is a Phase 4 hardening target.

### Profile Metadata Encryption
A compromised server should not yield profile pictures, display names, or status text in plaintext.

- Each user has a **Profile Key** (random 32-byte symmetric key)
- Profile picture, display name, and status are encrypted with the Profile Key before upload
- The Profile Key is shared only with verified contacts — sent as an E2EE message when a contact is added or when the key rotates
- When rendering a contact's profile, the client decrypts locally using the stored Profile Key
- If a Profile Key is not available (e.g., non-contact in a group), show a generic placeholder — never request the server to decrypt
- Profile Key rotation: whenever the user removes a contact, generate a new Profile Key and re-distribute to remaining contacts

---

## Performance Targets (WhatsApp Parity)

These are benchmarks, not aspirations. Measure against them.

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
- DB queries are batched where possible (e.g., bulk message insert on sync drain)

---

## Package & Module Structure

```
hello_engine/
├── lib/
│   ├── hello_engine.dart         # Public API barrel file (ONLY export point)
│   ├── src/
│   │   ├── crypto/               # Signal protocol, key management, ratchet, profile keys
│   │   ├── transport/            # WebSocket client, HTTP client, reconnect logic
│   │   ├── persistence/          # Encrypted DB (SQLCipher/drift), repositories, migrations
│   │   ├── sync/                 # Message sync, gap detection, ordering, device fan-out
│   │   ├── media/                # AES-GCM encrypt → upload → URL+key via ratchet (raw bytes, no UI)
│   │   ├── notifications/        # Platform-native decrypt (iOS NSE, Android Service, Web SW)
│   │   ├── contacts/             # Hashed phone discovery, profile key distribution
│   │   ├── devices/              # Device registry, linking protocol, key rotation
│   │   ├── domain/               # Entities, value objects, use cases (pure Dart)
│   │   └── observer/             # ChatEngineObserver interface, diagnostic events
├── test/
│   ├── crypto/                   # Unit tests for every crypto operation
│   ├── transport/                # Mock server tests
│   ├── persistence/              # DB migration tests
│   ├── domain/                   # Domain model + use case tests
│   └── integration/              # Full send/receive flow tests (mock server)
├── ios/
│   └── NotificationServiceExtension/  # Native Swift push decryption
├── android/
│   └── app/src/.../MessagingService.kt  # Native Kotlin push decryption
├── example/                      # Minimal CLI/headless integration test app
└── CLAUDE.md                     # This file
```

**No `src/ui/` directory. No `src/controllers/` directory.** This package has zero Flutter widget code. UI lives in `~/hello/app/`.

**The `crypto/` directory is sacred.** Every function in it has a unit test. No exceptions.

---

## Backend Contract

The engine is backend-agnostic but assumes the following server capabilities:

- **WebSocket endpoint** for real-time message delivery (with reconnection + heartbeat)
- **REST endpoints** for: user registration, PreKey upload/fetch, message history pull, media upload/download
- **Push notification relay** — server sends FCM/APNs push without message content (content delivered via WS or pull)
- **Server stores**: encrypted ciphertext blobs, PreKey bundles, delivery receipts, user metadata (no plaintext, no keys)

The server is treated as an **untrusted relay**. All security assumptions are built around this.

---

## Public API Contract

Everything external code touches is exported from `hello_engine.dart`. Nothing else is public.

### Initialization

```dart
/// Host provides these at startup. All required.
class ChatEngineConfig {
  final String authToken;       // Opaque token from host's auth system
  final String userId;          // Authenticated user ID
  final String deviceId;        // Unique per-device, persisted locally by host
  final String pushToken;       // FCM/APNs token, updated by host on refresh
  final Uri serverBaseUrl;      // WebSocket + REST base URL
  final ChatEngineObserver? observer;  // Optional diagnostics hook
}

/// Entry point. Call once at app start.
static Future<ChatEngine> ChatEngine.initialize(ChatEngineConfig config);
```

### ChatEngine (top-level handle)

```dart
class ChatEngine {
  ChatSession getSession(String conversationId);
  Stream<List<Conversation>> get conversations;       // All conversations, sorted
  Stream<ConnectionState> get connectionState;         // connected / connecting / disconnected
  Stream<int> get totalUnreadCount;                    // Badge count across all conversations
  Future<List<ContactMatch>> discoverContacts(List<String> phoneHashes);
  Future<void> updatePushToken(String newToken);
  Future<void> suspend();   // App backgrounded — pause sync, keep push alive
  Future<void> resume();    // App foregrounded — reconnect, drain queue
  Future<void> dispose();   // Full teardown
}
```

### ChatSession (per-conversation handle)

```dart
class ChatSession {
  Stream<List<Message>> get messages;          // Decrypted, ordered, deduplicated
  Stream<List<TypingIndicator>> get typing;    // Ephemeral, not persisted
  Stream<List<Receipt>> get receipts;          // Delivered + read
  Stream<PresenceState> get presence;          // Online / last seen (1:1 only)
  Future<Message> sendText(String plaintext);
  Future<Message> sendMedia(MediaPayload payload);  // Raw bytes + mime type
  Future<void> sendTyping();
  Future<void> markRead(String messageId);
  Future<void> react(String messageId, String emoji);
  Future<void> deleteForMe(String messageId);
  Future<void> deleteForEveryone(String messageId);
  Future<List<Message>> loadMore({int limit = 50}); // Pagination
  Future<KeyFingerprint> getKeyFingerprint();        // For safety number verification
}
```

### Exposed Models (public)

`Message`, `Conversation`, `Receipt`, `TypingIndicator`, `PresenceState`, `ContactMatch`, `KeyFingerprint`, `MediaPayload`, `MediaMetadata`, `ConnectionState`.

All models are **freezed** immutable classes. Internal models (`RatchetState`, `SessionKey`, `PreKeyBundle`, etc.) are never exported.

---

## Host App Integration Requirements

The host app (or UI package) must provide at init time:

| Requirement | Why | How |
|---|---|---|
| `authToken` | Engine authenticates to server | Host's auth system (Firebase, custom, etc.) |
| `userId` | Identity for key ownership | From host's auth |
| `deviceId` | Sessions are per-device | Host generates UUID on first launch, persists in secure storage |
| `pushToken` | Server routes push notifications | Host registers with FCM/APNs, passes token |
| `serverBaseUrl` | Engine connects to backend | Host provides from config/env |

The engine gives back:
- **Streams** for the UI to observe (messages, typing, receipts, presence, connection state, unread counts)
- **Futures** for the UI to trigger actions (send, react, delete, mark read)
- **Error callbacks** via the error stream and observer (see Error Taxonomy)

The engine does **not** give back:
- Widgets, themes, or rendered UI of any kind
- Image/video display components (engine provides raw decrypted bytes via `MediaPayload`)
- Waveform visualizations (engine provides raw PCM/Opus audio data)

---

## Engine-to-UI Event Contract

These are the streams the UI subscribes to. This is the primary interface between `hello_engine` and `~/hello/app/`.

| Stream | Type | Description |
|---|---|---|
| `engine.conversations` | `Stream<List<Conversation>>` | All conversations with last message, unread count, pinned/muted state |
| `engine.connectionState` | `Stream<ConnectionState>` | `connected`, `connecting`, `disconnected`, `suspended` |
| `engine.totalUnreadCount` | `Stream<int>` | Sum of unread across all conversations |
| `session.messages` | `Stream<List<Message>>` | Decrypted messages for one conversation, ordered |
| `session.typing` | `Stream<List<TypingIndicator>>` | Who is typing (ephemeral, clears after 5s) |
| `session.receipts` | `Stream<List<Receipt>>` | Delivered/read per message |
| `session.presence` | `Stream<PresenceState>` | Online/last-seen for 1:1 conversations |
| `engine.errors` | `Stream<ChatEngineError>` | All errors (see Error Taxonomy) |
| `engine.observer` | `ChatEngineObserver` | Diagnostic events for logging/debugging |

---

## Error Taxonomy

All errors the engine surfaces. The UI and host must handle these — they are typed, not arbitrary strings.

```dart
sealed class ChatEngineError {
  /// Crypto
  SessionNotFound(String recipientDeviceId);  // No ratchet session — trigger X3DH
  DecryptionFailed(String messageId);         // Corrupt or out-of-order ratchet
  PreKeyExhausted(String userId);             // No one-time PreKeys left on server
  KeyVerificationFailed(String userId);       // Identity key changed (possible MITM)

  /// Transport
  ConnectionLost();                           // WebSocket dropped
  ConnectionTimeout();                        // Server unreachable
  ServerError(int statusCode, String body);   // Non-2xx from REST

  /// Auth
  AuthTokenExpired();                         // Host must provide a fresh token
  DeviceRevoked(String deviceId);             // This device was unlinked remotely

  /// Storage
  DatabaseCorrupted();                        // SQLCipher integrity check failed
  BiometricUnavailable();                     // Can't unlock DB — PIN/biometric not enrolled
  StorageFull();                              // Device storage insufficient

  /// Media
  MediaUploadFailed(String mediaId);          // Upload to bucket failed (retryable)
  MediaDownloadFailed(String url);            // Download from bucket failed (retryable)
  MediaDecryptionFailed(String mediaId);      // AES key mismatch or corrupt blob

  /// Sync
  OutboxFull(int pendingCount);               // Too many queued messages (>500)
  DuplicateMessage(String messageId);         // Already processed — safe to ignore
}
```

The UI decides how to render each error. The engine never shows toasts, dialogs, or snackbars.

---

## Session Lifecycle

### `initialize()` — App cold start
1. Opens the encrypted DB (requires biometric/PIN unlock)
2. Loads persisted ratchet sessions from secure storage
3. Connects WebSocket to server
4. Drains the outbox (sends queued messages)
5. Pulls any missed messages from server (gap fill)
6. Emits `ConnectionState.connected`
7. **If biometric unavailable**: emits `BiometricUnavailable` error — host must handle (show PIN screen, etc.)

### `suspend()` — App backgrounded
1. Pauses WebSocket heartbeat (server knows device is inactive)
2. Stops emitting typing/presence updates
3. Push notifications continue via platform-native path
4. DB remains locked — no reads/writes until `resume()`
5. Ratchet state remains in memory (survives backgrounding, not force-kill)

### `resume()` — App foregrounded
1. Reconnects WebSocket
2. Drains any messages received via push while suspended
3. Re-syncs presence state
4. Emits `ConnectionState.connected`

### `dispose()` — Full teardown
1. Closes WebSocket
2. Flushes outbox to DB (persists unsent messages for next `initialize()`)
3. Zeroes ratchet session keys in memory (secure wipe)
4. Closes DB connection

### Force-kill / crash recovery
- On next `initialize()`, the engine detects the unclean shutdown
- Ratchet state is restored from DB (last persisted checkpoint)
- Outbox is drained (messages sent before crash are retried with deduplication)
- Any ratchet chain counter gaps are resolved via the server's stored message queue

---

## Message ID & Ordering Strategy

### Message IDs
- **Client-generated UUID v7** (time-ordered UUID) — generated at send time, before encryption
- The ID is included inside the encrypted payload (server cannot forge or reorder)
- Server assigns a monotonically increasing **sequence number** per conversation on receipt
- Both `clientId` (UUID v7) and `serverSeq` (int64) are stored on the `Message` model

### Ordering
- **Display order**: `serverSeq` (authoritative, assigned by server on receipt)
- **Offline fallback**: `clientId` timestamp component (UUID v7 embeds millisecond timestamp) — used when `serverSeq` is not yet assigned (outbox messages)
- On reconnect, the engine fetches `serverSeq` for any outbox messages that were delivered while offline and reorders

### Deduplication
- Messages are deduplicated by `clientId` — if the same UUID v7 arrives twice (e.g., retry after timeout), the duplicate is dropped
- The engine maintains a **seen set** of the last 1000 `clientId`s per conversation in memory, backed by DB index
- Cross-device: each device generates its own `clientId`, so the same user on two devices never collides

---

## Observability & Diagnostics

The engine exposes a `ChatEngineObserver` interface for host apps and the UI team to debug without access to engine internals.

```dart
abstract class ChatEngineObserver {
  void onSessionEstablished(String userId, String deviceId);
  void onSessionFailed(String userId, String deviceId, ChatEngineError error);
  void onPreKeyReplenishment(int keysUploaded, int keysRemaining);
  void onSyncCompleted(int messagesPulled, Duration elapsed);
  void onOutboxDrained(int messagesSent, int messagesFailed);
  void onRatchetAdvanced(String sessionId, int chainIndex);
  void onMediaUpload(String mediaId, int bytes, Duration elapsed);
  void onMediaDownload(String mediaId, int bytes, Duration elapsed);
  void onWebSocketStateChange(ConnectionState from, ConnectionState to);
  void onContactDiscovery(int hashesSent, int matchesFound);
  void onProfileKeyRotation(String userId);
  void onDeviceLinked(String deviceId);
  void onDeviceRevoked(String deviceId);
}
```

- Pass a `ChatEngineObserver` in `ChatEngineConfig` — all methods have no-op defaults
- **Never log plaintext, keys, or user content in observer callbacks** — only event names, IDs, counts, and durations
- In debug builds, the engine logs to `dart:developer` at `Level.FINE` — production builds emit nothing

---

## API Stability Policy

This package follows **semver** strictly.

- **Public API** = everything exported from `hello_engine.dart`
- Breaking changes (removed methods, changed signatures, renamed models) = **major** version bump
- New methods/streams/models = **minor** version bump
- Bug fixes, crypto patches, internal refactors = **patch** version bump
- All `src/` internals are private — changes to them are never breaking
- Deprecations: mark with `@Deprecated('Use X instead. Will be removed in vN+1')`, remove one major version later

---

## Testing Standards

- **Crypto layer**: 100% unit test coverage. Test vectors from Signal spec where available.
- **Domain layer**: 100% unit test coverage.
- **Integration tests**: Full message send/receive loop using mock server (multi-device fan-out, media pipeline, outbox drain).
- **Performance tests**: Encryption throughput, sync drain time, cold-start time.

No golden tests, no widget tests — this package has no UI. Every PR must pass all tests.

---

## Technology Decisions

| Concern | Choice | Rationale |
|---|---|---|
| Local DB | **SQLCipher via drift** | SQL-level encryption, migration support |
| Secure Storage | **flutter_secure_storage** | Platform keychain integration |
| Networking | **web_socket_channel** + **dio** | Mature, well-tested |
| Crypto | **cryptography** (pure Dart) | Cross-platform (including Web/WASM), audited |
| Media | Raw byte streams + **dio** for upload/download | No image/video display libs — UI handles rendering |
| Notifications | **firebase_messaging** (data messages only) | Platform push relay; native extensions handle decrypt |
| Serialization | **freezed** + **json_serializable** | Immutable models, null-safe |
| IDs | **UUID v7** via `uuid` package | Time-ordered, client-generated, embeds timestamp |

Do not introduce new dependencies without justification. Every dependency is an attack surface and a maintenance burden.

---

## Hard Rules

1. **Never write plaintext message storage.** If a message touches disk, it is encrypted.
2. **Never block the calling isolate with crypto or I/O.** Use `compute()` or dedicated isolates.
3. **Never expose internal implementation details in the public API.** Hide everything behind the barrel file.
4. **Never assume network availability.** Every operation has an offline path.
5. **Never write a crypto function without a test.** Security-critical code with no tests is a liability.
6. **Never create widgets, screens, or any visual code.** This is a headless engine. UI lives in `~/hello/app/`.

---

## Code Style

- Dart analysis: `very_good_analysis` (strict)
- Commit messages: Conventional Commits (`feat:`, `fix:`, `crypto:`, `perf:`, `test:`)
- File length soft limit: 300 lines

---

## Development Phases

### Phase 1 — Foundation (Current)
Crypto layer, key management, local encrypted storage, WebSocket transport, basic 1:1 messaging send/receive, delivered receipts.

### Phase 2 — Feature Core
Group chats, media (images/video/voice), read receipts, typing indicators, push notifications, reply/quote.

### Phase 3 — WhatsApp Parity
Reactions, disappearing messages, view-once media, search, link previews, key verification UI, app lock, background sync hardening.

### Phase 4 — Portability & Polish
Package publication, host app integration guide, theming API, accessibility audit, performance profiling and optimization, security audit.