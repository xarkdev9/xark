# Agent 07 — Sync Engine

## Your Role
You are the **Sync Agent**. You implement the outbox queue (send retry), gap detection (missed messages on reconnect), message ordering, and deduplication. This is the glue between transport and persistence.

## Files to Create

### lib/src/sync/outbox_processor.dart
```dart
// OutboxProcessor — drains the outbox queue
// On connect: call drainOutbox()
// drainOutbox():
//   1. Load pending OutboxItems from OutboxRepository (ordered by createdAt)
//   2. For each item: call WebSocketClient.send(item.encryptedEnvelope)
//   3. On ACK from server (within 5s): markSent(id)
//   4. On timeout: markFailed(id, retryAfter: exponentialBackoff(item.retryCount))
//   5. Call `observer?.onOutboxDrained(messagesSent, messagesFailed)` when the drain cycle completes
// 
// maxRetries: 10. After 10 failures: delete item, emit OutboxFull if count > 500.
// Process items in parallel batches of 5 (not one at a time, not all at once)
```

### lib/src/sync/gap_detector.dart
```dart
// GapDetector — detects missed messages on reconnect
// On reconnect: 
//   1. Query local DB for max serverSeq per conversation
//   2. Call ApiClient.fetchMessageHistory(afterSeq: maxLocalSeq) for each active conversation
//   3. Pipe returned EncryptedEnvelopes to MessageProcessor
//   4. Call `observer?.onSyncCompleted(messagesPulled, elapsed)` when gap fill is complete
```

### lib/src/sync/message_processor.dart
```dart
// MessageProcessor — decrypts incoming envelopes and saves to DB
// Input: EncryptedEnvelope (from WebSocket or gap fill)
// Steps:
//   1. Receive message notification from Realtime (metadata only — no ciphertext yet)
//   1a. Check deduplication: is this messageId in the seen set? → drop if yes
//   1b. Fetch ciphertexts: call SupabaseClientWrapper.fetchCiphertexts(messageId)
//   1c. Find OUR ciphertext: filter by recipientId = myUserId AND recipientDeviceId = myDeviceId
//        (or recipientId = '_group_' for group messages)
//   2. Load RatchetSession for sender device
//   3. Decrypt via DoubleRatchet.decrypt (runs in Isolate)
//   4. Parse decrypted JSON → domain Message
//   5. Save Message to MessageRepository
//   5a. Check ProcessedDistributionRepository: if messageType = 'sender_key_dist', mark processed
//   5b. Cache plaintext via DecryptedMessageRepository (for instant re-display without re-decrypt)
//   6. Save updated RatchetSession to RatchetSessionRepository
//   7. Emit receipt (delivered) back to server
//   8. Update Conversation.unreadCount + lastMessage in ConversationRepository
//
// DeduplicationSet: maintain last 1000 message IDs per conversation in memory (LRU)
// Isolate: use compute() for decrypt step
```

### lib/src/sync/sync_coordinator.dart
```dart
// SyncCoordinator — orchestrates OutboxProcessor + GapDetector + MessageProcessor
// Listens to WebSocketClient.incomingFrames
// On connect: → GapDetector.fillGaps() then OutboxProcessor.drainOutbox()
// On frame received: → MessageProcessor.process(frame)
// On typing frame: → emit on typing stream (do NOT persist)
// On receipt frame: → ReceiptRepository.saveReceipt()
// On presence frame: → emit on presence stream (do NOT persist)
// SK Recovery:
// - Subscribe to RealtimeListener.subscribeToSKRecovery(spaceId, myUserId)
// - On sk_request received: verify requester is space member (via SupabaseClientWrapper)
// - If verified: re-distribute own Sender Key to requester via pairwise ratchet session
// - On Sender Key decrypt failure in MessageProcessor: call RealtimeListener.broadcastSKRequest()
// - Wait up to 10s for SK arrival via notifySenderKeyArrived() callback
// - If arrived: retry decrypt. If timeout: emit DecryptionFailed error.
// Tombstone check: Before encrypting a group message, SyncCoordinator checks
// SupabaseClientWrapper for space_tombstones newer than the current Sender Key's createdAt.
// If tombstone found: generate new Sender Key, re-distribute, then encrypt.
// This is called by Agent 08's SendMessageUseCase before encryptForSpace().
```

### lib/src/sync/sync.dart — Internal barrel

## Tests
`test/sync/` — mock OutboxRepository, WebSocketClient, MessageProcessor:
- Outbox drains on connect (10+ items sent)
- Failed items are retried with backoff
- Items exceeding maxRetries are deleted
- Gap detection fetches correct afterSeq
- Deduplication drops duplicate envelope IDs (15+ tests total)

```bash
flutter test test/sync/ --reporter=compact 2>&1
```

## Output JSON
```json
{
  "agent": "sync",
  "step": "07",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Sync engine complete. Key classes: OutboxProcessor (batched drain, retry backoff), GapDetector (per-conversation afterSeq fetch), MessageProcessor (decrypt in Isolate, dedup via LRU set), SyncCoordinator (orchestrates all three). MessageProcessor uses compute() for DoubleRatchet.decrypt. Typing/presence frames are NOT persisted — emitted to streams only. Receipt events ARE persisted via ReceiptRepository."
}
```

---

