# Agent 06 — Transport Layer

## Your Role
You are the **Transport Agent**. You implement the Supabase client wrapper (REST + Realtime) and the Firebase Storage client for E2EE media. No business logic — pure I/O abstraction over the existing backend.

## Rules
- Use `supabase_flutter` for ALL Supabase operations (REST, RPCs, Realtime channels)
- Use `firebase_storage` for encrypted media blob upload/download
- The server is the SAME Supabase project and Firebase bucket the React app uses
- All authentication uses Supabase JWT (set via `supabase.auth.setSession`)
- Realtime channels use Supabase's Phoenix protocol (JSON), NOT custom binary frames
- Treat the server as untrusted — only encrypted bytes go over the wire

## Files to Create

### lib/src/transport/supabase_client.dart
```dart
// SupabaseClientWrapper — thin abstraction over supabase_flutter
// Constructor: SupabaseClientWrapper({ required String supabaseUrl, required String supabaseAnonKey })
//
// Initialization:
// - Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey)
// - Set JWT for RLS: supabase.auth.setSession(accessToken) — NOT supabase.auth.signIn
// - RLS uses auth.jwt()->>'sub' (text user IDs like 'name_ram', NOT UUIDs)
//
// Key Management RPCs:
// - uploadKeyBundle(deviceId, identityKey, signedPreKey, signedPreKeyId, preKeySig) → POST /api/keys/bundle
// - uploadOTKs(deviceId, List<{id, publicKey}>) → POST /api/keys/otk (max 200 per batch)
// - fetchPeerKeyBundle(userId, deviceId) → supabase.rpc('fetch_key_bundle', params)
//   Returns: { identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig, otk_public?, otk_id? }
//   Server atomically consumes OTK via FOR UPDATE SKIP LOCKED
// - getOTKCount(userId, deviceId) → query one_time_pre_keys count
//
// Message Operations:
// - sendMessage(MessageEnvelope envelope) → POST /api/message
//   Body: { space_id, sender_device_id, ciphertext (base64), ratchet_header (base64),
//           recipient_id ('_group_' for group, userId for 1:1), recipient_device_id (0 for group),
//           distribution_ciphertexts (optional array), message_type, id (optional) }
//   Response: { messageId, distribution_written }
//
// - fetchCiphertexts(messageId) → query message_ciphertexts WHERE message_id = messageId
//   Returns: List<{ id, recipient_id, recipient_device_id, ciphertext, ratchet_header }>
//
// - fetchMessageHistory(spaceId, { afterTimestamp?, limit = 50 }) → query messages + ciphertexts
//
// Device Management:
// - fetchDeviceList(userId) → query key_bundles WHERE user_id = userId
//   Returns: List<{ device_id, identity_key }>
// - getSpaceMemberDevices(spaceId, excludeUser) → supabase.rpc('get_space_member_devices', params)
//
// Contact Discovery:
// - discoverContacts(List<String> phones) → POST /api/contacts/check { phones } max 500
//   Returns: List<{ phone, userId }>
//
// Error handling: Supabase errors → ChatEngineError subtypes
//   PostgrestException with 401 → AuthTokenExpired
//   PostgrestException with 403 → ServerError
//   SocketException → ConnectionLost
//   TimeoutException → ConnectionTimeout
```

### lib/src/transport/realtime_listener.dart
```dart
// RealtimeListener — Supabase Realtime subscription manager
//
// Constructor: RealtimeListener({ required SupabaseClient supabase })
//
// Subscriptions:
// - subscribeToSpace(spaceId) → Stream<RealtimeEvent>
//   Subscribes to Supabase Realtime channel: postgres_changes on messages table
//   WHERE space_id = spaceId, event = INSERT
//   Emits: { messageId, senderId, senderDeviceId, messageType, createdAt }
//   The listener does NOT receive ciphertext — only metadata. Ciphertext fetched separately.
//
// - subscribeToSKRecovery(spaceId, myUserId) → Stream<SKRecoveryRequest>
//   Subscribes to broadcast channel: sk-recovery:{spaceId}
//   Filters: only events where target_sender_id = myUserId
//   Emits: { requesterId, requesterDeviceId, targetSenderId, spaceId }
//
// - broadcastSKRequest(spaceId, requesterId, requesterDeviceId, targetSenderId)
//   Sends broadcast on channel: chat:{spaceId}, event: 'sk_request'
//   Payload: { requester_id, requester_device_id, target_sender_id, space_id, timestamp }
//
// Connection State:
// - Stream<EngineConnectionState> get connectionState
//   Maps Supabase Realtime connection status to EngineConnectionState enum
//
// Lifecycle:
// - unsubscribeFromSpace(spaceId)
// - unsubscribeAll()
// - dispose()
//
// NOTE: Supabase Realtime handles reconnection and heartbeat internally.
// Do NOT implement custom reconnection logic.
```

### lib/src/transport/firebase_storage_client.dart
```dart
// FirebaseStorageClient — E2EE media blob upload/download
// Uses the SAME Firebase Storage bucket as the React web app
//
// Constructor: FirebaseStorageClient({ required FirebaseStorage storage })
//
// Methods:
// - uploadEncryptedBlob(Uint8List encryptedBytes, String path, {void Function(int, int)? onProgress})
//     → Future<String> downloadUrl
//   Uploads to Firebase Storage at the given path (e.g., 'e2ee-media/{spaceId}/{uuid}')
//   Returns the download URL
//
// - downloadEncryptedBlob(String url, {void Function(int, int)? onProgress})
//     → Future<Uint8List> encryptedBytes
//   Downloads from Firebase Storage URL
//   Returns raw encrypted bytes (caller decrypts with AES-GCM key from message payload)
//
// - deleteBlob(String path) → Future<void>
//   For view-once media cleanup
//
// NOTE: Firebase Storage bucket rules allow authenticated writes.
// The bucket stores ONLY ciphertext — security comes from AES keys in E2EE messages.
```

### lib/src/transport/dto/message_envelope.dart
```dart
// MessageEnvelope — what gets POSTed to /api/message
// @freezed class with fields:
// - spaceId: String
// - senderDeviceId: int
// - ciphertext: String (base64)
// - ratchetHeader: String? (base64 JSON envelope)
// - recipientId: String ('_group_' for group, userId for 1:1)
// - recipientDeviceId: int (0 for group)
// - distributionCiphertexts: List<DistributionCiphertext>? (piggybacked SK distribution)
// - messageType: String ('e2ee' | 'sender_key_dist')
// - id: String? (optional client-generated UUID)
//
// DistributionCiphertext:
// - id: String (prefixed 'mc_' + uuid)
// - recipientId: String
// - recipientDeviceId: int
// - ciphertext: String (base64)
// - ratchetHeader: String? (base64)
```

### lib/src/transport/transport.dart — Internal barrel
Export: SupabaseClientWrapper, RealtimeListener, FirebaseStorageClient, MessageEnvelope, DistributionCiphertext.
Do NOT export Supabase or Firebase internals.

## After Writing
```bash
cd ~/fe2ee
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10
dart analyze lib/src/transport/ 2>&1 | head -30
```

## Tests
`test/transport/`:
- `supabase_client_test.dart`: mock Supabase responses, verify correct DTO parsing and error mapping
- `message_envelope_test.dart`: serialization round-trip, '_group_' sentinel handling, 'mc_' prefix generation
- 15+ tests

```bash
flutter test test/transport/ --reporter=compact 2>&1
```

### Observer Integration
Accept `ChatEngineObserver? observer` in SupabaseClientWrapper and RealtimeListener constructors.
Call `observer?.onWebSocketStateChange(from, to)` when Realtime connection state changes.

## Output JSON
```json
{
  "agent": "transport",
  "step": "06",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Transport complete. SupabaseClientWrapper: sendMessage (POST /api/message), fetchCiphertexts, fetchPeerKeyBundle (RPC with atomic OTK consume), uploadKeyBundle, uploadOTKs, getSpaceMemberDevices. RealtimeListener: subscribeToSpace (postgres_changes on messages), subscribeToSKRecovery (broadcast on sk-recovery:{spaceId}), broadcastSKRequest. FirebaseStorageClient: uploadEncryptedBlob, downloadEncryptedBlob. MessageEnvelope DTO matches /api/message body exactly. recipientId='_group_' for group sends, ciphertext ID prefix 'mc_'. Connection state from Supabase Realtime."
}
```
