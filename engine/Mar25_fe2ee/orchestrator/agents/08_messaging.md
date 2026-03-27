# Agent 08 — 1:1 Messaging

## Your Role
You are the **Messaging Agent**. You wire everything together for 1:1 message send and receive. You implement the `ChatSession` logic, the send pipeline, and the `ChatEngine` top-level class — minus the public API barrel (that's Agent 10).

## Key Constants
- `recipient_id = '_group_'` for group (Sender Key) messages, actual userId for 1:1 (Double Ratchet)
- `recipient_device_id = 0` for group messages
- Ciphertext IDs are prefixed with `'mc_'` + UUID
- message_type = `'e2ee'` for regular messages, `'sender_key_dist'` for SK distribution

## Files to Create

### lib/src/domain/use_cases/send_message_use_case.dart
```dart
// SendMessageUseCase — complete send pipeline
// sendText(conversationId, plaintext):
//   1. Generate UUID v7 message ID
//   2. Create Message{status: sending} → save to MessageRepository
//   3. Fetch recipient's device list from SupabaseClientWrapper
//   4. For EACH recipient device:
//        a. Get/establish Double Ratchet session (X3DH if first message)
//        b. Encrypt payload via ratchetEncrypt (in Isolate)
//        c. TWO-PHASE COMMIT: Save unacked ratchet state to UnackedRatchetRepository BEFORE send
//        d. Pack: nonce(24) + ciphertext → base64
//   5. Build MessageEnvelope with all device ciphertexts
//   6. POST via SupabaseClientWrapper.sendMessage(envelope)
//   7. On 200 OK: call commit() → persist sessions to main store, delete unacked entries
//   8. On failure: unacked ratchet state survives for crash recovery
// Total time budget: < 50ms perceived (crypto in isolate, DB write, then return)
```

### lib/src/domain/use_cases/send_media_use_case.dart
```dart
// SendMediaUseCase — media send pipeline
// sendMedia(conversationId, MediaPayload):
//   1. Generate UUID v7 message ID
//   2. Generate MediaKey (AES-256-GCM)
//   3. Compress media in Isolate (images: JPEG 85%, video: not yet)
//   4. Encrypt bytes in Isolate using MediaCrypto
//   5. Compute SHA-256 of encrypted bytes
//   6. Upload encrypted blob via ApiClient.uploadMedia (with progress callback)
//   7. Package { downloadUrl, key, iv, sha256 } as MediaMetadata
//   8. Save MediaItem to MediaRepository
//   9. Send MediaMetadata JSON through ratchet (same as text send from step 3 above)

// Group send (encryptForSpace) two-phase commit:
//   1. Get/generate Sender Key (check space_tombstones via SupabaseClientWrapper for rotation)
//   2. prepareSenderKeyDistribution() → encrypt SK via pairwise ratchet for each member device
//   3. senderKeyEncrypt(senderKey, payload) → ciphertext + nonce + signature + iteration
//   4. EAGER PERSIST: save advanced Sender Key state to SenderKey store immediately
//   5. Save unacked ratchet to UnackedRatchetRepository
//   6. Pack: nonce(24) + signature(64) + iteration(4 bytes big-endian) + ciphertext → base64
//   7. Build MessageEnvelope with ciphertext + distribution_ciphertexts
//   8. POST via SupabaseClientWrapper.sendMessage(envelope)
//   9. On 200 OK: delete unacked entry
```

### lib/src/domain/use_cases/receive_message_use_case.dart
```dart
// ReceiveMessageUseCase — invoked by SyncCoordinator.MessageProcessor
// Already partially in MessageProcessor — extract the decrypt + save logic here
// Also handles: receipt emission, unread count update, disappearing message scheduling
```

### lib/src/domain/use_cases/mark_read_use_case.dart
```dart
// MarkReadUseCase:
// 1. Update Message.status = read in DB
// 2. Decrement conversation.unreadCount
// 3. Send read receipt to server via WebSocket
```

### lib/src/domain/use_cases/delete_message_use_case.dart
```dart
// DeleteMessageUseCase:
// deleteForMe(messageId): mark deleted locally, do not broadcast
// deleteForEveryone(messageId, withinWindow: Duration(minutes: 15)):
//   - Check timestamp (must be within window)
//   - Send delete event to server via WebSocket
//   - Server broadcasts to all recipient devices
//   - On receive: mark deleted in DB
```

### lib/src/chat_session_impl.dart
```dart
// ChatSessionImpl — implements ChatSession interface from public API
// Wraps: SendMessageUseCase, SendMediaUseCase, MarkReadUseCase, DeleteMessageUseCase
// Exposes streams by forwarding from repositories:
//   - messages: MessageRepository.watchMessages(conversationId)
//   - typing: from SyncCoordinator ephemeral stream (filtered by conversationId)
//   - receipts: ReceiptRepository.watchReceipts(conversationId)
//   - presence: from SyncCoordinator presence stream
```

### lib/src/chat_engine_impl.dart
```dart
// ChatEngineImpl — top-level engine handle
// initialize(ChatEngineConfig):
//   - Open DB (DatabaseFactory)
//   - Load identity keys (KeyStore)
//   - Connect WebSocket
//   - Start SyncCoordinator
//   - Recover unacked ratchets: load all from UnackedRatchetRepository
//   - For each unacked entry: check if message was actually delivered (query server)
//   - If delivered: commit (persist session, delete unacked)
//   - If not delivered: rollback (restore previous session state)
//   - This prevents ratchet desync after crash between encrypt and ACK
//   - Drain outbox + fill gaps
//
// getSession(conversationId) → ChatSessionImpl (cached)
// conversations: ConversationRepository.watchConversations()
// connectionState: WebSocketClient.connectionState
// totalUnreadCount: computed stream from conversations
// suspend() / resume() / dispose() — per lifecycle spec in CLAUDE.md
```

## Tests
`test/domain/messaging_test.dart`:
- Send text message → appears in MessageRepository with status=sending
- Send text → OutboxItem enqueued
- Receive encrypted envelope → decrypted message saved
- Read receipt sent on markRead
- deleteForEveryone fails after 15min window
- deleteForMe marks local only (15+ tests)

```bash
flutter test test/domain/ --reporter=compact 2>&1
```

## Output JSON
```json
{
  "agent": "messaging",
  "step": "08",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "1:1 messaging wired end-to-end. ChatEngineImpl and ChatSessionImpl are internal impls. Use cases: SendMessageUseCase, SendMediaUseCase, ReceiveMessageUseCase, MarkReadUseCase, DeleteMessageUseCase. ChatEngineImpl.initialize() opens DB, loads keys, connects WS, starts SyncCoordinator. Sessions are cached by conversationId. Agent 10 will create the public API barrel that wraps these impls."
}
```

---

