# Frontend Team Handoff — Phase 2 Integration Guide

**Date:** 2026-03-27
**Author:** Backend/Infrastructure Team
**For:** Flutter UI Team + Web UI Team

---

## TL;DR

Phase 1 frontend is BUILT. The screens exist. The engine is integrated. This document tells you what backend infrastructure was added in the hardening sprint, and how to wire the **remaining Phase 2 hooks** into the existing UI. You are NOT building from scratch.

---

## SECURITY BOUNDARY (READ THIS FIRST)

### The Iron Rule: UI Never Talks to the Backend Directly

```
FORBIDDEN:
  supabase.from('decision_items').select(...)   // NEVER
  supabase.from('users').select(...)            // NEVER
  supabase.from('messages').select(...)         // NEVER
  supabase.rpc('mark_group_read', ...)          // NEVER (from UI)

REQUIRED:
  engine.getSession(groupId).messages           // YES — engine handles sync + crypto
  engine.conversations                          // YES — engine handles offline cache
  engine.discoverContacts(phoneHashes)          // YES — engine handles hashing + batching
  session.sendText(plaintext)                   // YES — engine handles encrypt + outbox
  session.markRead(messageId)                   // YES — engine handles watermark update
```

**Why:** The `fe2ee` engine is the ONLY component that may touch the network. It manages the encrypted SQLCipher local cache, the crypto isolate, the outbox queue, and the sync coordinator. If the UI queries Supabase directly:
1. It bypasses the local cache, breaking offline functionality
2. It risks exposing plaintext data outside the E2EE trust boundary
3. It creates race conditions with the sync coordinator's Drift streams

**The engine is the API. Supabase is an implementation detail the UI never sees.**

The ONLY exception is the web React client (`web/src/`), which has its own crypto layer (`web/src/lib/crypto/`) and talks to API routes. The Flutter UI talks exclusively to `package:chat_engine`.

---

## PART 1: What Was Built in the Hardening Sprint

37 commits adding planet-scale infrastructure to the engine. Here's what's new and ready for the UI to consume:

### New Engine Capabilities (Flutter UI can use NOW)

| Capability | Engine API | What Changed |
|-----------|-----------|-------------|
| **Offline-first feeds** | `engine.conversations`, `session.messages` | Now backed by `LocalFeedRepository` — zero network in render path. Drift reactive streams. |
| **Optimistic send** | `session.sendText()`, `session.sendMedia()` | Writes to outbox instantly. `OutboxWorker` drains serially per group in background. |
| **Gap sync on reconnect** | `engine.resume()` | `WatermarkSync` fetches missed messages, `ConflictResolver` reconciles with server. |
| **Delivery receipts** | `session.receipts` | Ephemeral via Realtime Broadcast (never DB). `Receipt` model has `deliveredAt` + `readAt`. |
| **Typing indicators** | `session.typing` | `TypingIndicatorManager` with 5s auto-clear. `session.sendTyping()` debounced. |
| **Presence** | `session.presence` | `PresenceState` with `isOnline` + `lastSeenAt`. 1:1 conversations only. |
| **Background uploads** | `session.sendMedia()` | `BackgroundUploader` with Drift-persisted queue. Survives force-quit (WorkManager/BGTask). |
| **Streaming AEAD** | Transparent to UI | Files >1MB encrypted in 64KB chunks. No OOM on 4K video. |
| **Crypto isolate** | Transparent to UI | All encrypt/decrypt in dedicated isolate. TransferableTypedData. 10s watchdog. |
| **Multi-device registry** | `engine.getDevices()` (coming) | `user_devices` table, 5-device limit, fan-out encryption per device. |
| **Device linking** | `DeviceLinking` interface | QR-based linking with encrypted history transfer. Replace the `Future.delayed(1500ms)` mock. |
| **Push decryption** | `decryptPushPayload()` | iOS NSE + Android Service scaffolding. Needs native bridge wiring. |
| **Contact discovery** | `engine.discoverContacts(hashes)` | Truncated SHA-256, batched (100/request), privacy-preserving. |
| **Post-quantum** | Transparent to UI | PQXDH hybrid X25519 + Kyber-1024. Backward compatible. |
| **Hardware keys** | Transparent to UI | Identity keys wrapped by Secure Enclave / Keystore wrapping key. |
| **Connection state** | `engine.connectionState` | `connecting` / `connected` / `disconnected` / `suspended` |
| **Unread counts** | `engine.totalUnreadCount` | Local calculation via `read_watermarks` (no deadlocks). |

### New Web API Routes the Engine Calls (UI doesn't call these directly)

| Route | Purpose | Called By |
|-------|---------|----------|
| `POST /api/message` | Atomic E2EE send (UUIDv7 idempotent) | Engine `OutboxWorker` |
| `POST /api/keys/fetch` | Key bundle + OTK (Redis cached) | Engine key manager |
| `POST /api/keys/bundle` | Upload key bundle | Engine on init |
| `POST /api/keys/otk` | Upload OTKs | Engine on init |
| `GET /api/devices` | List devices | Engine `DeviceRegistry` |
| `DELETE /api/devices` | Unlink device | Engine `DeviceRegistry` |
| `POST /api/contacts/check` | Phone discovery | Engine `discoverContacts()` |

### Routes the UI MAY Call Directly (web React only, NOT Flutter)

| Route | Purpose | Notes |
|-------|---------|-------|
| `POST /api/phone-auth` | Login (Firebase OTP → JWT) | Auth flow only |
| `POST /api/join` | Name-only invite join | Onboarding only |
| `POST /api/hello` | @hello AI (SSE streaming) | See security boundary in Part 4 |
| `POST /api/invite` | Generate invite link | Social features |
| `POST /api/local-action` | Group mutations | Via engine in Flutter |

---

## PART 2: Existing Screens — What's Built, What Needs Wiring

These screens are ALREADY BUILT in Phase 1. Do NOT rebuild them. Wire the Phase 2 hooks.

### Auth Flow (`views/auth/auth_flow_page.dart`)
**Status:** Built. Single-page state machine with blur transitions.
**Phase 2 wiring needed:**
- After successful auth, call `engine.discoverContacts()` with hashed phone contacts
- Wire Firebase AppCheck token to the auth request header

### Home Screen (`views/home/home_layout.dart` + `chats_tab_view.dart`)
**Status:** Built. PageController with typographic header animation.
**Phase 2 wiring needed:**
- Build `groups_tab_view.dart` — streams from `engine.conversations` filtered by `type == group`
- Build `memories_tab_view.dart` — streams settled group media from engine
- Wire `engine.totalUnreadCount` to app badge
- Wire `engine.connectionState` to a top connection banner (show "Connecting..." on disconnect)

### Chat View (`views/chat/chat_view.dart`)
**Status:** Built. Reverse message feed with @hello intent boundary.
**Phase 2 wiring needed:**
- Wire `session.receipts` → visual ticks on each `ChatBubble` (sending/sent/delivered/read)
- Wire `session.typing` → "Alice is typing..." indicator below composer
- Wire `session.presence` → "Online" / "Last seen" in app bar (1:1 only)
- Wire `VirtualizedChatList.onLoadMore` → `session.loadMore(limit: 50)` on scroll-to-top
- Wire media send: `session.sendMedia(MediaPayload(...))` → `BackgroundUploader` → progress stream → `EncryptedImageView`
- Wire media receive: engine delivers `Message.media` with `MediaMetadata` → use `inlineThumbnail` for instant blur → `AnimatedCrossFade(300ms)` to `FileImage(File(localPath))` when download completes
- **MEMORY RULE:** ALWAYS use `FileImage(File(localPath))`. NEVER use `MemoryImage`. Loading a 50MB video into RAM via MemoryImage will OOM-kill the app.

### Decision Board (`views/action_carousel_page.dart` + `widgets/action_card_widget.dart`)
**Status:** Built. Netflix-style PageView with SpringSimulation.
**Phase 2 wiring needed:**
- Wire decision items and reactions through the engine (NOT direct Supabase queries)
- Engine needs new methods: `engine.getDecisionItems(groupId)` and `engine.react(itemId, signal)`
- **BACKEND TEAM ACTION REQUIRED:** Expose `decision_items` and `reactions` through the engine's public API. The UI must not query Supabase directly.

### Device Linking (`views/settings/device_linking_page.dart`)
**Status:** Built. QR scanner with CustomClipper mask.
**Phase 2 wiring needed:**
- Replace `Future.delayed(1500ms)` simulation with real `DeviceLinking` protocol:
  ```dart
  // Primary device:
  final request = await engine.deviceLinking.generateLinkingRequest();
  displayQrCode(request.toQrPayload());
  engine.deviceLinking.linkingState.listen((state) { ... });

  // New device:
  final request = LinkingRequest.fromQrPayload(scannedData);
  await engine.deviceLinking.processLinkingRequest(request);
  ```

---

## PART 3: New Screens to Build (Phase 2)

These screens do NOT exist yet. Build them.

### Settings Screen
**Files:** `views/settings/settings_page.dart`, `views/settings/profile_edit.dart`, `views/settings/device_list.dart`
**Engine APIs:**
- Device list: `engine.getDevices()` (needs to be added to public API — wraps `DeviceRegistry.getUserDevices()`)
- Unlink device: `engine.unlinkDevice(deviceId)` (needs to be added — wraps `DeviceRegistry.unlinkDevice()`)
- Profile: engine must expose profile read/write (currently not in public API — BACKEND ACTION REQUIRED)

### @hello AI Sheet
**Files:** `views/ai/spotlight_sheet.dart`, `views/ai/ghost_input.dart`
**Engine APIs:** The AI endpoint follows the SAME security boundary as everything else. The UI does NOT make raw HTTP calls. The engine wraps the `/api/hello` SSE endpoint and exposes a native Dart stream:
```dart
// CORRECT — UI passes prompt to engine, engine handles HTTP + auth + SSE parsing
final aiStream = engine.streamHelloResponse(
  prompt: userPrompt,
  groupId: groupId,
);

await for (final chunk in aiStream) {
  // chunk.text — incremental AI response text
  // chunk.done — true when stream is complete
  setState(() => aiResponse += chunk.text);
}
```
**Why no raw http.post:** If the UI calls `http.post` directly, it must manage the JWT (`authToken`), the `serverBaseUrl`, and token refresh. The engine already manages all of this. If the token expires mid-stream, the engine handles `AuthTokenExpired` and routes it to the global error bus. A raw `http.post` would just fail silently or crash.

**SECURITY BOUNDARY:** The UI passes ONLY the user's immediate prompt text + groupId to the engine. The engine forwards it to `/api/hello`. The UI NEVER sends decrypted message history, local Drift data, or any E2EE content. The server fetches its own grounding context (the state map) from `server_content` fields (non-E2EE metadata).

**BACKEND ACTION REQUIRED:** `engine.streamHelloResponse(prompt, groupId)` must be added to the engine's public API. It wraps `POST /api/hello` with SSE parsing and returns a `Stream<HelloResponseChunk>`.

### Invite Flow
**Files:** `views/invite/invite_surface.dart`, `views/invite/claim_sheet.dart`
**Engine APIs:** Invite generation/claiming goes through the engine (engine wraps the HTTP calls).

---

## PART 4: Phase 2 Native Work (Heavy Lifting)

### A. Push Notification Decryption (iOS + Android)

The scaffolding is in place. What needs to happen:

**iOS (NotificationServiceExtension):**
1. `app/ios/NotificationServiceExtension/NotificationService.swift` exists (stub)
2. Must be wired to the engine's `decryptPushPayload()` via Flutter method channel
3. NSE and main app share an App Group keychain (`group.com.hello.app`)
4. NSE loads ratchet state from shared SQLCipher database
5. 30-second iOS budget — if decryption fails, fall back to "New Message"
6. `app/ios/Runner/Runner.entitlements` needs App Group entitlement added

**Android (FirebaseMessagingService):**
1. `app/android/app/src/main/kotlin/.../HelloMessagingService.kt` exists (stub)
2. Must spawn a headless Dart isolate to run `decryptPushPayload()`
3. Find the crypto isolate via `IsolateNameServer.lookupPortByName('crypto_isolate')`
4. If crypto isolate not running (app killed), open Drift DB directly from the headless isolate
5. Post local notification via `NotificationCompat.Builder`

**The bridge pattern:**
```
Silent push arrives
  → Native code (Swift/Kotlin) receives it
  → Calls Flutter method channel: `channel.invokeMethod('decryptPush', payload)`
  → Engine's PushDecryptor runs in headless isolate
  → Returns PushDecryptResult {senderName, messagePreview}
  → Native code mutates notification content with plaintext
```

### B. Biometric Gateway (App Lock)

The document previously said "Show PIN entry screen" on `BiometricUnavailable`. That's incomplete.

**What actually needs to happen:**
1. Before `runApp()`, before ANY Drift database opens, before the engine initializes — the app must authenticate the user via biometric/PIN
2. The SQLCipher database encryption key is derived from the biometric/PIN authentication
3. If biometric fails, the ENTIRE app is locked. No navigation, no home screen, no engine.
4. Implementation:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();

     // BLOCK HERE until biometric/PIN verified
     final authenticated = await BiometricGateway.authenticate();
     if (!authenticated) {
       runApp(const LockedApp()); // Shows PIN pad only
       return;
     }

     // Only now initialize the engine (which opens the encrypted DB)
     final engine = await ChatEngine.initialize(config);
     runApp(HelloApp(engine: engine));
   }
   ```
5. If `engine.errors` emits `BiometricUnavailable` during runtime (e.g., user disabled biometrics while app was open), immediately lock the app and require re-authentication.

### C. @hello AI Security Context

The `/api/hello` endpoint receives the user's prompt and returns AI responses via SSE.

**What the UI MUST do:**
- Send ONLY: `{ prompt: "user's typed text", groupId: "group_123" }`
- The server fetches its own grounding context from the state map (locked decisions, active items, member profiles) using `server_content` fields — which are NOT E2EE encrypted

**What the UI MUST NEVER do:**
- Send decrypted message history from the local Drift database
- Send the `session.messages` stream content
- Send any `Message.text` (decrypted plaintext) to any HTTP endpoint
- Include local user preferences or contacts in the AI request

The @hello AI operates on a strictly scoped context. The server sees ONLY what was explicitly stored in `server_content` (non-E2EE metadata). The UI's job is to forward the user's prompt — nothing else.

---

## PART 5: Engine Data Models (Unchanged from Phase 1)

All models are **freezed** immutable classes from `package:chat_engine`.

### Message
```dart
Message {
  String id;              // UUIDv7, client-generated
  String groupId;
  String senderId;
  String senderDeviceId;
  MessageType type;       // e2ee | hello | system | media | sender_key_dist | tombstone
  MessageStatus status;   // sending | sent | delivered | read | failed
  DateTime timestamp;
  String role;            // 'user' | 'hello' | 'system'
  int? serverSeq;         // null = outbox/pending
  String? text;           // null for media-only
  MediaMetadata? media;
  String? replyToMessageId;
  Map<String, List<String>> reactions;
  bool isStarred;
  bool isViewOnce;
  int? disappearsAt;
  bool isDeleted;
}
```

**UI rendering rules:**
| Field | Visual |
|-------|--------|
| `status == sending` | Clock icon, grey |
| `status == sent` | Single check |
| `status == delivered` | Double check (grey) |
| `status == read` | Double check (accent) |
| `status == failed` | Red error + retry button |
| `serverSeq == null` | Outbox message — show at bottom, sort by `timestamp` |
| `type == tombstone` | "This message was deleted" |
| `type == hello` | Accent color bubble, @hello branding, L-corner |
| `type == system` | Centered, no bubble, caption text |
| `isViewOnce` | Blur after first view |

### Conversation
```dart
Conversation {
  String id;
  ConversationType type;  // oneToOne | group
  List<String> participantIds;
  String? lastMessageText;
  DateTime? lastMessageTimestamp;
  int unreadCount;
  bool isPinned;
  bool isMuted;
}
```

### Receipt, TypingIndicator, PresenceState
```dart
Receipt { String messageId; String userId; DateTime? deliveredAt; DateTime? readAt; }
TypingIndicator { String groupId; String userId; DateTime startedAt; }
PresenceState { String userId; bool isOnline; DateTime? lastSeenAt; }
```

### ChatEngineError (All 15 Types)
The UI MUST handle every error type exhaustively:

| Error | UI Response |
|-------|------------|
| `AuthTokenExpired` | Wipe session → navigate to /login |
| `DeviceRevoked(deviceId)` | "This device was unlinked" dialog → /login |
| `KeyVerificationFailed(userId)` | Safety number changed warning (yellow banner) |
| `BiometricUnavailable` | **BLOCK ENTIRE APP** → show PIN/biometric re-auth |
| `DecryptionFailed(messageId)` | "Could not decrypt" placeholder on that message |
| `ConnectionLost` | "Connecting..." banner at top |
| `ConnectionTimeout` | "No connection" banner |
| `ServerError(code, body)` | Transient — show briefly then dismiss |
| `PreKeyExhausted(userId)` | Engine auto-replenishes — no UI needed |
| `SessionNotFound(deviceId)` | Engine auto-initiates X3DH — no UI needed |
| `DatabaseCorrupted` | Fatal — "Data corrupted, please reinstall" |
| `StorageFull` | "Storage full" toast |
| `MediaUploadFailed(id)` | Show retry button on that media message |
| `MediaDownloadFailed(url)` | Show retry button on that media message |
| `OutboxFull(count)` | "Too many pending messages" warning |

---

## PART 6: Database Tables (Engine Manages These — UI Never Queries Directly)

ALL tables are accessed through the engine. This list is for backend reference only.

| Table | Purpose | Accessed Via |
|-------|---------|-------------|
| `users` | User profiles | Engine (future `engine.getProfile()`) |
| `groups` | Conversations | `engine.conversations` stream |
| `group_members` | Membership | Engine checks internally |
| `messages` | Message metadata | `session.messages` stream |
| `message_ciphertexts` | Per-device encrypted payloads | Engine crypto layer |
| `key_bundles` | E2EE public keys | Engine key manager |
| `one_time_pre_keys` | OTKs | Engine key manager |
| `group_sequences` | Monotonic counters | Engine `send_e2ee_message` RPC |
| `read_watermarks` | Unread tracking | `session.markRead()` |
| `decision_items` | Heart-Sort items | Engine (needs new API — see Backend Actions) |
| `reactions` | Votes | Engine (needs new API — see Backend Actions) |
| `sk_acknowledgments` | Sender key ACKs | Engine SK distribution |
| `user_devices` | Multi-device registry | Engine `DeviceRegistry` |
| `space_dates` | Trip dates | Engine (needs new API) |
| `space_ledger` | Audit trail | Engine (needs new API) |
| `media` | Media references | Engine media pipeline |

---

## PART 7: Backend Actions Required (Before UI Can Wire)

The engine's public API needs these additions before the UI team can complete integration:

| Missing Engine API | What It Wraps | Needed By |
|-------------------|--------------|-----------|
| `engine.getDecisionItems(groupId)` | `decision_items` + `reactions` query via Drift | Decision Board |
| `engine.react(itemId, signal)` | Reaction insert via API | Decision Board |
| `engine.lockItem(itemId, proof)` | Green-Lock commitment | Decision Board |
| `engine.getProfile(userId)` | `users` table query | Settings, chat headers |
| `engine.updateProfile(name, photo)` | `users` table update | Settings |
| `engine.getDevices()` | `user_devices` query | Settings device list |
| `engine.unlinkDevice(deviceId)` | `unlink_device` RPC | Settings |
| `engine.getSpaceDates(groupId)` | `space_dates` query | Group detail |
| `engine.getLedger(groupId)` | `space_ledger` query | Settlement/audit |
| `engine.createGroup(title, atmosphere)` | `create_space` local-action | Home screen |
| `engine.inviteToGroup(groupId, userId)` | Invite flow | Invite surface |
| `engine.streamHelloResponse(prompt, groupId)` | `POST /api/hello` SSE streaming + auth + token refresh | @hello AI Sheet / Ghost Input |

**These must be added to `engine/lib/src/public_api/chat_engine.dart` before the UI team can wire the corresponding screens.**

**The `streamHelloResponse` API is critical:** It wraps the SSE endpoint, manages the auth token lifecycle, and returns a `Stream<HelloResponseChunk>`. Without this, the UI would need to import `http` and manage tokens directly — violating the security boundary.

---

## PART 8: Design System (Unchanged)

### Colors
| Token | Hex | Use |
|-------|-----|-----|
| Accent (Rose) | `#D4536B` | Primary actions, @hello bubbles, unread dots |
| Sent bubble | `#EF7C6E` | Right-aligned sender bubbles |
| Received bubble | `#E8E3DD` | Left-aligned receiver bubbles |
| Void | `#1A1A1A` | Dark mode background |
| White | `#FAFAFA` | Light mode background |
| Amber | signal color | LoveIt (+5) |
| Green | signal color | Green-Lock |
| Orange | signal color | NotForMe (-3) |
| Gold | signal color | Consensus achieved |

### Rules (Non-Negotiable)
- **No bold.** Max FontWeight.w400. Hierarchy via size + opacity.
- **No boxes.** No Container borders, BoxShadow, Card. Use spacing + opacity.
- **No Material.** No ElevatedButton, InkWell, ripple. Use GestureDetector + SpringSimulation.
- **Haptics always.** selectionClick() on tap, heavyImpact() on consensus lock.

---

## PART 9: Validation Checklist

### Existing Screens (Wire Phase 2 Hooks)
- [ ] Chat receipts: `session.receipts` → visual ticks on `ChatBubble`
- [ ] Chat typing: `session.typing` → "typing..." indicator
- [ ] Chat presence: `session.presence` → "Online" in app bar (1:1 only)
- [ ] Chat pagination: `VirtualizedChatList.onLoadMore` → `session.loadMore(limit: 50)`
- [ ] Chat media send: `session.sendMedia()` → progress stream → FileImage on disk
- [ ] Chat media receive: `inlineThumbnail` blur → `AnimatedCrossFade(300ms)` → `FileImage`
- [ ] Home connection: `engine.connectionState` → "Connecting..." banner
- [ ] Home badge: `engine.totalUnreadCount` → app badge
- [ ] Device linking: Replace `Future.delayed(1500ms)` → real `DeviceLinking` protocol
- [ ] Error handling: All 15 `ChatEngineError` types handled exhaustively

### New Screens
- [ ] Groups tab built and streaming from engine
- [ ] Memories tab built and streaming from engine
- [ ] Settings screen with device list, profile edit, theme toggle
- [ ] @hello AI sheet with SSE streaming (security boundary enforced)
- [ ] Invite flow with QR code generation

### Native Platform Work
- [ ] iOS NSE wired to `decryptPushPayload()` via method channel
- [ ] Android Service wired to `decryptPushPayload()` via headless isolate
- [ ] Biometric gateway blocks `runApp()` until authenticated
- [ ] App Group keychain shared between main app + NSE

### Security Verification
- [ ] UI NEVER imports `supabase_flutter` or `@supabase/supabase-js` directly
- [ ] UI NEVER sends decrypted message text to `/api/hello` or any HTTP endpoint
- [ ] UI NEVER uses `MemoryImage` for media (OOM risk)
- [ ] UI NEVER logs Message.text, keys, or any E2EE content to console

---

## PART 10: How to Run

```bash
# Web
cd web && npm run dev  # http://localhost:3000

# Flutter
cd app && flutter run -d chrome    # Web
cd app && flutter run -d macos     # macOS
cd app && flutter run               # Connected device

# Engine tests
cd engine && flutter test

# Algo tests
cd algo && npm test

# Seed demo data
# First: CREATE EXTENSION IF NOT EXISTS pgcrypto; in Supabase SQL editor
cd web && npx tsx src/lib/seed.ts
```
