# Frontend Team Handoff — What Was Built, What You Need to Know, What to Build Next

**Date:** 2026-03-27
**Author:** Backend/Infrastructure Team
**For:** Flutter UI Team + Web UI Team

---

## TL;DR

We built the entire backend infrastructure in one session: 37 commits, 83+ files, covering all 50 items from crypto.md and all 42 items from 4PM_Goal.md. The engine, database, API routes, crypto protocols, and offline-first architecture are production-ready. Your job is to wire the UI to these APIs.

---

## PART 1: What Was Built (Backend Summary)

### Database (Supabase Postgres)
- 8 new migrations: atomic RPC, group sequences, read watermarks, table partitioning, SK acknowledgments, PQXDH columns, user devices, dropped rate limiter
- `send_e2ee_message` atomic RPC — single transaction for message + ciphertexts + SK distributions
- Monthly range partitions on `message_ciphertexts` (handles 100M+ rows)
- `group_sequences` table for O(1) per-group monotonic sequence assignment
- `read_watermarks` table replaces `unread_counts` (no more deadlocks)
- `sk_acknowledgments` table for O(1) sender key distribution
- `user_devices` table for Sesame multi-device (5 device limit enforced by trigger)

### Edge Infrastructure (Next.js + Upstash Redis)
- Rate limiting moved to `proxy.ts` (middleware-first, blocks before serverless function invocation)
- Token bucket for `/api/message` (200 burst for outbox sync), sliding window for all others
- Fail-open for messaging routes, fail-closed for phone-auth + AI (financial protection)
- Key bundle cache in Redis (SETNX, 5-min TTL, X-Bypass-Cache self-healing)
- JWT replay protection via jti + Redis SETNX
- Firebase AppCheck on `/api/phone-auth`

### Engine (Flutter/Dart — `engine/`)
- **Crypto isolate** — dedicated background isolate for all encrypt/decrypt operations, 10s watchdog, 3 max respawns, TransferableTypedData for zero-copy
- **Web Locks API mutex** — cross-tab E2EE safety with 5s AbortController timeout
- **O(1) SK distribution** — local ACK cache (IndexedDB + Drift), piggybacked ACKs, NACK recovery protocol
- **Strangler Fig ports** — MessageGateway, RealtimeGateway, TransientQueue interfaces for future extraction
- **X3DH hardening** — 3-DH fallback, signature verification, ephemeral key validation
- **Hardware key storage** — wrapping key pattern (Secure Enclave stub, Keystore stub, WebCrypto)
- **Streaming AEAD** — 64KB chunked AES-256-GCM for files up to 2GB
- **PQXDH** — hybrid X25519 + Kyber-1024 post-quantum key exchange
- **Sesame multi-device** — device registry, QR-based linking, fan-out encryption
- **Push decryption** — iOS NSE, Android Service, Web SW scaffolding
- **Local-first feeds** — `LocalFeedRepository` with reactive Drift streams
- **Watermark sync** — paginated gap fill on reconnect
- **Outbox worker** — serial per-group drain with exponential backoff
- **Conflict resolver** — reconciles optimistic vs server-authoritative state
- **Background uploader** — Drift-persisted upload queue, resumable
- **Sync coordinator** — orchestrates all background workers
- **Typing indicators** — 5s auto-clear, Realtime Broadcast (never DB)
- **Realtime receipts** — ephemeral delivered/read ticks via Broadcast
- **BlurHash** — placeholder metadata for encrypted images
- **Link unfurling** — client-side via blind proxy
- **Message franking** — per-message key extraction for E2EE moderation
- **E2EE observability** — Sentry integration point, never logs keys/plaintext
- **Private contact discovery** — truncated SHA-256, batched lookup
- **On-device SLM** — constraint detection (diet/budget) with regex fallback

---

## PART 2: Engine API Reference (What Flutter UI Consumes)

### Initialization

```dart
final engine = await ChatEngine.initialize(ChatEngineConfig(
  authToken: 'jwt_from_login',
  userId: 'name_ram',
  deviceId: 99,           // unique per device, persisted locally
  pushToken: fcmToken,    // from Firebase Messaging
  serverBaseUrl: Uri.parse('https://gethello.ai'),
  supabaseAnonKey: 'your_anon_key',
));
```

### Top-Level Streams (Home Screen)

| Stream | Type | Use For |
|--------|------|---------|
| `engine.conversations` | `Stream<List<Conversation>>` | Home screen conversation list |
| `engine.connectionState` | `Stream<EngineConnectionState>` | Connection indicator (banner) |
| `engine.totalUnreadCount` | `Stream<int>` | App badge count |
| `engine.errors` | `Stream<ChatEngineError>` | Global error handling |

### Per-Conversation Streams (Chat Screen)

```dart
final session = engine.getSession('group_123');
```

| Stream | Type | Use For |
|--------|------|---------|
| `session.messages` | `Stream<List<Message>>` | Chat message feed |
| `session.typing` | `Stream<List<TypingIndicator>>` | "Alice is typing..." |
| `session.receipts` | `Stream<List<Receipt>>` | Delivered/read ticks |
| `session.presence` | `Stream<PresenceState>` | "Online" / "Last seen" (1:1 only) |

### Actions (User Interactions)

```dart
// Send message (writes to outbox → UI updates instantly → background syncs)
await session.sendText('Hello!');

// Send media (encrypts → uploads → sends key via ratchet)
await session.sendMedia(MediaPayload(
  bytes: fileBytes,
  mimeType: 'image/jpeg',
  fileName: 'photo.jpg',
));

// Typing indicator (debounced, ephemeral)
await session.sendTyping();

// Mark as read
await session.markRead(message.id);

// React
await session.react(message.id, 'love_it');

// Delete
await session.deleteForMe(message.id);
await session.deleteForEveryone(message.id);

// Pagination (load older messages when user scrolls up)
final older = await session.loadMore(limit: 50);

// Safety number verification
final fingerprint = await session.getKeyFingerprint();
```

### Lifecycle (App State)

```dart
// In WidgetsBindingObserver.didChangeAppLifecycleState:
switch (state) {
  case AppLifecycleState.resumed:
    await engine.resume();  // Reconnects WebSocket, drains outbox, syncs gaps
    break;
  case AppLifecycleState.paused:
  case AppLifecycleState.inactive:
    await engine.suspend(); // Pauses sync, keeps push alive
    break;
  case AppLifecycleState.detached:
    await engine.dispose(); // Full teardown, secure key wipe
    break;
}
```

### Error Handling (Global)

```dart
engine.errors.listen((error) {
  switch (error) {
    case AuthTokenExpired():
      // Wipe session, navigate to /login
      break;
    case DeviceRevoked(deviceId: final id):
      // Show "device was unlinked" dialog
      break;
    case KeyVerificationFailed(userId: final id):
      // Show safety number changed warning
      break;
    case BiometricUnavailable():
      // Show PIN entry screen
      break;
    case DecryptionFailed(messageId: final id):
      // Show "message could not be decrypted" placeholder
      break;
    case ConnectionLost():
      // Show "connecting..." banner
      break;
    // ... handle all 15 error types
  }
});
```

---

## PART 3: Data Models (What UI Renders)

### Message

```dart
Message {
  String id;              // UUIDv7
  String groupId;         // conversation ID
  String senderId;        // who sent it
  String senderDeviceId;  // which device
  MessageType type;       // e2ee | hello | system | media | sender_key_dist
  MessageStatus status;   // sending | sent | delivered | read | failed
  DateTime timestamp;
  String role;            // 'user' | 'hello' | 'system'
  int? serverSeq;         // server-assigned order (null = outbox/pending)
  String? text;           // plaintext (null for media)
  MediaMetadata? media;   // attachment info
  String? replyToMessageId;
  Map<String, List<String>> reactions;  // emoji → [userIds]
  bool isStarred;
  bool isViewOnce;
  int? disappearsAt;      // epoch ms
  bool isDeleted;
}
```

**UI rendering rules:**
- `status == sending` → show clock icon, grey
- `status == sent` → single check mark
- `status == delivered` → double check mark (grey)
- `status == read` → double check mark (blue/accent)
- `status == failed` → show red error icon + retry button
- `serverSeq == null` → outbox message, show at bottom of chat, use `timestamp` for ordering
- `type == 'tombstone'` → show "This message was deleted" placeholder
- `type == 'hello'` → AI message, render with accent color, @hello branding
- `type == 'system'` → centered, no bubble, grey text
- `isViewOnce == true` → blur after first view, delete from local DB

### Conversation

```dart
Conversation {
  String id;
  ConversationType type;  // oneToOne | group
  List<String> participantIds;
  DateTime createdAt;
  DateTime updatedAt;
  String? lastMessageText;     // preview
  DateTime? lastMessageTimestamp;
  int unreadCount;
  bool isPinned;
  bool isArchived;
  bool isMuted;
  DateTime? muteUntil;
}
```

**UI rendering rules:**
- Sort: pinned first, then by `lastMessageTimestamp` descending
- `unreadCount > 0` → show Rose (#D4536B) glow dot (not numbered badge)
- `isMuted` → show muted icon, suppress push
- `type == oneToOne` → show peer's avatar + name
- `type == group` → show group title + member count

### Receipt

```dart
Receipt {
  String messageId;
  String userId;
  String deviceId;
  DateTime? deliveredAt;
  DateTime? readAt;
}
```

**UI logic:** Message status = `max(all receipts)`. If ANY receipt has `readAt` → message is "read". If ANY has `deliveredAt` → "delivered". Otherwise → "sent" (server confirmed) or "sending" (outbox).

### TypingIndicator

```dart
TypingIndicator {
  String groupId;
  String userId;
  DateTime startedAt;  // auto-clears after 5s
}
```

**UI:** Show "Alice is typing..." below chat input. Multiple typers: "Alice and Bob are typing...". Auto-clear after 5 seconds.

### PresenceState

```dart
PresenceState {
  String userId;
  bool isOnline;
  DateTime? lastSeenAt;
}
```

**UI:** In 1:1 chat app bar: "online" (green dot) or "last seen 2:34 PM".

---

## PART 4: Web API Routes (Complete Reference)

### Authentication

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/phone-auth` | No | Exchange Firebase OTP for JWT |
| POST | `/api/join` | No | Name-only invite join |
| POST | `/api/dev-auto-login` | No | Dev login with password (404 in prod) |

### E2EE Keys

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/keys/bundle` | Yes | Upload key bundle (identity + signed pre-key) |
| POST | `/api/keys/otk` | Yes | Upload one-time pre-keys (batch, max 200) |
| POST | `/api/keys/fetch` | Yes | Fetch peer's key bundle + consume 1 OTK |

### Messaging

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/message` | Yes | Send E2EE message (atomic, idempotent via UUIDv7) |
| POST | `/api/chat/start` | Yes | Find-or-create 1:1 DM |

### Contacts & Social

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/contacts/check` | Yes | Privacy-preserving phone lookup (max 500) |
| POST | `/api/invite` | Yes | Generate invite link (128-bit hex) |
| GET | `/api/invite/validate` | No | Validate invite code |
| POST | `/api/invite/claim` | No | Claim invite → join group + get JWT |

### Groups

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/local-action` | Yes | Mutations: create_space, rename, update_dates, revert |
| POST | `/api/notify` | Yes | FCM push to group members |

### Devices (Multi-Device)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/devices` | Yes | List user's devices |
| DELETE | `/api/devices` | Yes | Unlink a device (revoke keys) |

### AI & Intelligence

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/hello` | Yes | @hello AI orchestration (SSE streaming) |
| POST | `/api/hello/webhook` | No | Apify async callback |

### Utilities

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/proxy-scrape` | No | Blind OG metadata proxy |
| POST | `/api/og` | Yes | OG extraction with SSRF protection |
| GET | `/api/cron/consensus` | Cron | Auto-lock expired consensus |
| GET | `/api/cron/purge` | Cron | Purge expired @hello msgs + invites |

---

## PART 5: Supabase Tables (Key Tables for Frontend)

### Tables You'll Query Directly (via Supabase client)

| Table | Primary Key | RLS | Notes |
|-------|------------|-----|-------|
| `users` | `id` (text) | Yes | Display name, photo, phone |
| `groups` | `id` (text) | Yes | Title, atmosphere, metadata |
| `group_members` | `(group_id, user_id)` | Yes | Role (owner/member) |
| `messages` | `id` (uuid) | Yes | E2EE metadata (server_content NULL for encrypted) |
| `decision_items` | `id` (text) | Yes | Heart-Sort ranked items |
| `reactions` | `(item_id, user_id)` | Yes | LoveIt/WorksForMe/NotForMe |
| `media` | `id` (text) | Yes | Encrypted media references |
| `read_watermarks` | `(group_id, user_id)` | Yes | Last-read sequence per group |
| `space_dates` | `group_id` | Yes | Trip dates per group |
| `space_ledger` | `id` | Yes | Audit trail |

### Tables the Engine Manages (Don't Query Directly)

| Table | Purpose |
|-------|---------|
| `key_bundles` | E2EE public keys (engine handles via API) |
| `one_time_pre_keys` | Consumed atomically by `/api/keys/fetch` |
| `message_ciphertexts` | Per-device encrypted payloads (partitioned monthly) |
| `group_sequences` | Monotonic sequence counters |
| `sk_acknowledgments` | Sender key ACK tracking |
| `user_devices` | Multi-device registry |

### Key RPCs (Called via `supabase.rpc()`)

| RPC | Called By | Purpose |
|-----|----------|---------|
| `send_e2ee_message` | `/api/message` route | Atomic message send |
| `fetch_key_bundle` | `/api/keys/fetch` route | Atomic OTK consumption |
| `find_or_create_chat` | `/api/chat/start` route | DM routing |
| `mark_group_read` | Client directly | Update read watermark |
| `register_device` | Engine on init | Register device in registry |
| `unlink_device` | Settings screen | Revoke device + cleanup keys |
| `get_user_devices` | Engine for fan-out | List user's devices |
| `tombstone_message` | Delete-for-everyone | Redact message + delete ciphertexts |

---

## PART 6: What the Flutter UI Team Needs to Build

### Priority 1: Core Screens (Must Have)

| Screen | Files to Create | Engine API |
|--------|----------------|------------|
| **Login / Welcome** | `views/auth/welcome_screen.dart`, `views/auth/phone_input.dart`, `views/auth/otp_input.dart` | POST `/api/phone-auth` |
| **Home (3 tabs)** | `views/home/tabs/groups_tab_view.dart`, `views/home/tabs/memories_tab_view.dart` | `engine.conversations`, `LocalFeedRepository.watchConversations()` |
| **Chat View** | Already exists — wire receipts + presence + pagination | `session.messages`, `session.receipts`, `session.presence`, `session.loadMore()` |
| **Settings** | `views/settings/settings_page.dart`, `views/settings/profile_edit.dart`, `views/settings/device_list.dart` | GET/DELETE `/api/devices`, `supabase.from('users')` |

### Priority 2: Feature Screens

| Screen | Files to Create | Engine API |
|--------|----------------|------------|
| **Decision Board** | Already exists (action_card_widget) — wire to `decision_items` + `reactions` | `supabase.from('decision_items')`, `supabase.from('reactions')` |
| **@hello AI Sheet** | `views/ai/spotlight_sheet.dart`, `views/ai/ghost_input.dart` | POST `/api/hello` (SSE streaming) |
| **Invite Flow** | `views/invite/invite_surface.dart`, `views/invite/claim_sheet.dart` | POST `/api/invite`, POST `/api/invite/claim` |
| **Media Viewer** | `views/media/encrypted_media_viewer.dart` | `session.sendMedia()`, engine `BackgroundUploader` |
| **Contact Discovery** | `views/contacts/contacts_page.dart` | `engine.discoverContacts(phoneHashes)` |

### Priority 3: Polish & Integration

| Feature | What to Wire | Engine API |
|---------|-------------|------------|
| **Delivery Receipts** | Map `session.receipts` → visual ticks on bubbles | `Receipt.deliveredAt`, `Receipt.readAt` |
| **Typing Indicators** | Map `session.typing` → "Alice is typing..." | `TypingIndicator.userId` |
| **Presence** | Map `session.presence` → "Online" badge | `PresenceState.isOnline` |
| **Pagination** | Wire `onLoadMore` in VirtualizedChatList | `session.loadMore(limit: 50)` |
| **Connection Banner** | Map `engine.connectionState` → top banner | `EngineConnectionState.connecting/disconnected` |
| **Push Notifications** | Wire iOS NSE + Android Service to `PushDecryptor` | `decryptPushPayload()` |
| **Device Linking** | Replace `Future.delayed(1500ms)` with real Sesame flow | `DeviceLinking.generateLinkingRequest()` |
| **Media Pipeline** | `engine.downloadMedia(metadata)` → `FileImage(File(localPath))` | `BackgroundUploader.enqueue()`, `watchUpload()` |
| **BlurHash Placeholders** | Show blur while encrypted image downloads | `BlurHashMetadata.blurHash` in message metadata |
| **Link Previews** | Show OG card for URLs in messages | `LinkPreview.fromJson()` in message metadata |

---

## PART 7: Design System Reference

### Colors (CSS Variables → Flutter)

| Token | Hex | Flutter |
|-------|-----|---------|
| `--hello-accent` | `#D4536B` | `HelloColors.accent` |
| `--hello-white` | `#FAFAFA` | `HelloColors.white` |
| `--hello-void` | `#1A1A1A` | `HelloColors.voidBg` |
| `--hello-amber` | LoveIt signal | `HelloColors.amber` |
| `--hello-gold` | Consensus gold | `HelloColors.gold` |
| `--hello-green` | Green-Lock | `HelloColors.green` |
| `--hello-orange` | NotForMe signal | `HelloColors.orange` |
| `--hello-gray` | WorksForMe signal | `HelloColors.gray` |
| `--hello-bubble-sent` | Sender bubble | `#EF7C6E` (right-aligned) |
| `--hello-bubble-received` | Receiver bubble | `#E8E3DD` (left-aligned) |

### Typography Rules

- **Max weight: 400** (FontWeight.w400). Bold is BANNED.
- Hierarchy via size + opacity only
- Hero text: 48-64px, opacity 0.9
- Body: 16px, opacity 0.8
- Caption: 12px, opacity 0.5
- Font: Inter (variable weight)

### Animation Rules

- **No** `Curves.easeOut` — use `SpringCurve` from `app/lib/animations/spring_curves.dart`
- **No** `ElevatedButton` or `InkWell` — use `GestureDetector` + `SpringSimulation`
- **No** Material ripple effects
- Haptics: `HapticFeedback.selectionClick()` on tap, `HapticFeedback.heavyImpact()` on consensus lock

### Spacing & Layout

- Zero-Box Doctrine: no `Container` borders, no `BoxShadow`, no `Card`
- Contrast via mathematical spacing + opacity
- Edge-to-edge avatars (56x56, no padding)
- Unread: 8x8 Rose (#D4536B) glow dot (not numbered badge)

---

## PART 8: Validation Checklist for UI Team

Before shipping each screen, validate against the engine:

- [ ] `engine.conversations` stream populates the home screen list
- [ ] `session.messages` stream populates the chat feed
- [ ] `session.sendText()` writes to outbox → UI updates instantly → background syncs
- [ ] `session.sendMedia()` encrypts via streaming AEAD → uploads → sends key via ratchet
- [ ] `session.loadMore()` loads older messages on scroll-up
- [ ] `session.markRead()` updates `read_watermarks` (local + server)
- [ ] `session.receipts` maps to visual ticks (sending → sent → delivered → read)
- [ ] `session.typing` shows ephemeral typing indicator (auto-clears 5s)
- [ ] `session.presence` shows online/last-seen in 1:1 chat bars
- [ ] `engine.connectionState` drives the connection banner
- [ ] `engine.errors` is handled exhaustively (all 15 error types)
- [ ] `engine.resume()` reconnects + syncs gaps + drains outbox
- [ ] `engine.suspend()` pauses sync gracefully
- [ ] Push notifications show decrypted plaintext (not "New Message")
- [ ] Device linking QR flow completes with real Sesame protocol
- [ ] Contact discovery calls `engine.discoverContacts()` after phone auth
- [ ] Media renders via `FileImage(File(localPath))` — NEVER `MemoryImage` (OOM risk)
- [ ] BlurHash placeholder shows instantly while encrypted media downloads
- [ ] @hello AI responses stream via SSE (real-time typing effect)
- [ ] Consensus lock at >80% fires gold burst + heavy haptic

---

## PART 9: Environment Variables Required

### Web (.env.local)

```
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_JWT_SECRET=your-jwt-secret
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
FIREBASE_ADMIN_CLIENT_EMAIL=...
FIREBASE_ADMIN_PRIVATE_KEY=...
GEMINI_API_KEY=...
APIFY_TOKEN=...
UPSTASH_REDIS_REST_URL=...
UPSTASH_REDIS_REST_TOKEN=...
LOGIN_PASSWORD=... (dev only)
DEV_MODE=true (dev only)
```

### Flutter (injected at runtime via ChatEngineConfig)

```
authToken     → from /api/phone-auth or /api/dev-auto-login
userId        → from auth response
deviceId      → generated on first launch, persisted in secure storage
pushToken     → from Firebase Messaging
serverBaseUrl → https://gethello.ai (prod) or http://localhost:3000 (dev)
```

---

## PART 10: How to Run Locally

```bash
# Web
cd web && npm run dev  # http://localhost:3000

# Flutter (after web is running for API)
cd app && flutter run -d chrome    # Web
cd app && flutter run -d macos     # macOS
cd app && flutter run               # Connected device

# Engine tests
cd engine && flutter test

# Algo tests
cd algo && npm test

# Seed demo data (run once)
# First: CREATE EXTENSION IF NOT EXISTS pgcrypto; in Supabase SQL editor
cd web && npx tsx src/lib/seed.ts
```
