# Agent 05 — Persistence Layer

## Your Role
You are the **Persistence Agent**. You implement the encrypted local database using drift + SQLCipher, all repository implementations, and the secure key storage wrapper.

## Rules
- Database encryption is non-negotiable. Every table is inside the SQLCipher-encrypted file.
- No plaintext writes. Ever. Including logs.
- Repository implementations are the ONLY classes that touch the DB directly
- Migrations must be versioned and tested
- Streams from drift are used for reactive UI updates

## Files to Create

### lib/src/persistence/database/app_database.dart
```dart
// drift database definition
// @DriftDatabase(tables: [Messages, Conversations, Receipts, OutboxItems, MediaItems, RatchetSessions])
// class AppDatabase extends _$AppDatabase {
//   AppDatabase(QueryExecutor e) : super(e);
//   @override int get schemaVersion => 1;
//   @override MigrationStrategy get migration => ...
// }

// Table definitions (as drift Tables):

// Messages table (metadata only — mirrors Postgres messages table):
// - id TEXT PRIMARY KEY (UUID)
// - spaceId TEXT NOT NULL (was conversationId)
// - senderId TEXT NOT NULL (text format e.g. 'name_ram')
// - senderDeviceId INTEGER nullable
// - messageType TEXT NOT NULL ('e2ee' | 'xark' | 'system' | 'legacy' | 'sender_key_dist')
// - role TEXT NOT NULL DEFAULT 'user' ('user' | 'assistant')
// - createdAt INTEGER NOT NULL (unix ms)
// - serverContent TEXT nullable (always null for E2EE messages)
// Index: (spaceId, createdAt)

// MessageCiphertexts table (actual E2EE payload — mirrors Postgres message_ciphertexts):
// - id TEXT PRIMARY KEY (prefixed 'mc_' + UUID)
// - messageId TEXT NOT NULL FK → Messages
// - recipientId TEXT NOT NULL ('_group_' for group, userId for 1:1)
// - recipientDeviceId INTEGER NOT NULL (0 for group)
// - ciphertext TEXT NOT NULL (base64)
// - ratchetHeader TEXT nullable (base64 JSON envelope)
// Index: (messageId)

// Conversations table:
// - id TEXT PRIMARY KEY
// - type TEXT NOT NULL
// - participantIdsJson TEXT NOT NULL
// - lastMessageId TEXT nullable
// - unreadCount INTEGER NOT NULL DEFAULT 0
// - isPinned INTEGER NOT NULL DEFAULT 0
// - isArchived INTEGER NOT NULL DEFAULT 0
// - isMuted INTEGER NOT NULL DEFAULT 0
// - muteUntil INTEGER nullable
// - disappearingTimerSeconds INTEGER nullable
// - createdAt INTEGER NOT NULL
// - updatedAt INTEGER NOT NULL

// OutboxItems table (for offline queue):
// - id TEXT PRIMARY KEY (UUID v7)
// - conversationId TEXT NOT NULL
// - encryptedEnvelope BLOB NOT NULL  ← ready to send over wire
// - recipientDeviceIds TEXT NOT NULL  ← JSON array
// - retryCount INTEGER NOT NULL DEFAULT 0
// - createdAt INTEGER NOT NULL
// - nextRetryAt INTEGER NOT NULL

// RatchetSessions table:
// - sessionId TEXT PRIMARY KEY  (format: "userId:deviceId")
// - encryptedState BLOB NOT NULL  ← RatchetState encrypted with local key
// - updatedAt INTEGER NOT NULL

// MediaItems table:
// - mediaId TEXT PRIMARY KEY
// - conversationId TEXT NOT NULL
// - messageId TEXT NOT NULL
// - mimeType TEXT NOT NULL
// - localPath TEXT nullable
// - downloadUrl TEXT NOT NULL
// - encryptedKeyJson TEXT NOT NULL  ← { key, iv, sha256 } encrypted with local key
// - sizeBytes INTEGER NOT NULL
// - isDownloaded INTEGER NOT NULL DEFAULT 0

// UnackedRatchets table (two-phase commit crash recovery):
// - id TEXT PRIMARY KEY ('pending_' + UUID)
// - sessionKey TEXT NOT NULL (format: 'userId:deviceId' or 'spaceId')
// - sessionType TEXT NOT NULL ('ratchet' | 'senderKey')
// - serializedState TEXT NOT NULL (base64 of encrypted session state)
// - createdAt INTEGER NOT NULL (unix ms)
// On app restart: recover all rows, replay commit or rollback

// DecryptedMessages table (plaintext cache — encrypted at rest by SQLCipher):
// - messageId TEXT PRIMARY KEY
// - plaintext TEXT NOT NULL (decrypted text, for instant re-display)
// - mediaJson TEXT nullable (decrypted media metadata JSON, for media messages)
// - cachedAt INTEGER NOT NULL (unix ms, for TTL expiry)
// Index: (cachedAt) for TTL cleanup

// ProcessedDistributions table (SK distribution idempotency guard):
// - messageId TEXT PRIMARY KEY
// - processedAt INTEGER NOT NULL (unix ms)
// Prevents replay of Sender Key distribution messages

// NOTE: space_tombstones is a SERVER-SIDE Postgres table (not local).
// Agent 06's SupabaseClientWrapper queries it via:
//   supabase.from('space_tombstones').select('id').eq('space_id', spaceId).gt('created_at', senderKeyCreatedAt)
// No local drift table needed — just document that the transport layer provides this check.
```

### lib/src/persistence/database/database_factory.dart
```dart
// Constructs AppDatabase with SQLCipher encryption
// Uses flutter_secure_storage to generate/retrieve the DB encryption key
// Key derivation: PBKDF2(user_pin + device_id_salt) or biometric-protected key
// On first run: generate 32-byte random key, store in Keychain/Keystore
// On subsequent runs: load key from Keychain/Keystore, open DB with it
```

### lib/src/persistence/repositories/ — Implementations

**message_repository_impl.dart**
Implement `MessageRepository` from domain layer (two-table schema: Messages + MessageCiphertexts):
- saveMessage: insert/replace into Messages table (metadata only)
- saveCiphertext(MessageCiphertext ct): insert into MessageCiphertexts table
- getCiphertexts(String messageId) → Future<List<MessageCiphertext>>: fetch all ciphertexts for a message
- getMessages: paginated query joining Messages + MessageCiphertexts filtered to the local device's ciphertexts (recipientId = myUserId AND recipientDeviceId = myDeviceId, or recipientId = '_group_'), ordered by createdAt
- search: Phase 1 approach — load candidate messages from DB (filtered by spaceId and date range), look up cached plaintext from DecryptedMessageRepository, then filter client-side by whether the decrypted text contains the query string (case-insensitive). Cap at 500 messages per search call to bound memory use. Do NOT attempt FTS5 on the encrypted blob — it is a ciphertext and contains no searchable tokens. FTS5 integration is a Phase 3 hardening target (requires a separately maintained plaintext token index inside the encrypted DB).
- watchMessages: returns drift watch stream

**conversation_repository_impl.dart**
Implement `ConversationRepository`:
- watchConversations: ordered by isPinned DESC, updatedAt DESC

**outbox_repository.dart** (new interface + impl):
```dart
abstract class OutboxRepository {
  Future<void> enqueue(OutboxItem item);
  Future<List<OutboxItem>> getPending({int limit = 20});
  Future<void> markSent(String id);
  Future<void> markFailed(String id, {required Duration retryAfter});
  Future<void> delete(String id);
  Future<int> getPendingCount();
}
```

**unacked_ratchet_repository.dart** (new interface + impl):
```dart
abstract class UnackedRatchetRepository {
  Future<void> saveUnacked(String id, UnackedRatchet ratchet);
  Future<List<UnackedRatchet>> getAllUnacked();
  Future<void> ackRatchet(String id);
  Future<void> deleteExpired(Duration maxAge);
}
```

**decrypted_message_repository.dart** (new interface + impl):
```dart
abstract class DecryptedMessageRepository {
  Future<void> cachePlaintext(String messageId, String plaintext);
  Future<void> cacheMedia(String messageId, Map<String, dynamic> mediaJson);
  Future<String?> getCachedPlaintext(String messageId);
  Future<Map<String, dynamic>?> getCachedMedia(String messageId);
  Future<void> expireOlderThan(Duration maxAge);
}
```

**processed_distribution_repository.dart** (new interface + impl):
```dart
abstract class ProcessedDistributionRepository {
  Future<bool> isProcessed(String messageId);
  Future<void> markProcessed(String messageId);
}
```

**ratchet_session_repository.dart** (new interface + impl):
```dart
abstract class RatchetSessionRepository {
  Future<void> saveSession(String sessionId, RatchetState state);
  Future<RatchetState?> loadSession(String sessionId);
  Future<void> deleteSession(String sessionId);
}
// Impl encrypts RatchetState JSON with local symmetric key before writing to DB
```

**media_repository.dart** (new interface + impl):
```dart
abstract class MediaRepository {
  Future<void> saveMediaItem(MediaItem item);
  Future<MediaItem?> getMediaItem(String mediaId);
  Future<List<MediaItem>> getMediaForConversation(String conversationId, {int limit = 50});
  Future<void> markDownloaded(String mediaId, String localPath);
}
```

### lib/src/persistence/persistence.dart — Internal barrel
Export implementations and the database factory. Do NOT export drift internals.

## After Writing
```bash
cd ~/fe2ee
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10
dart analyze lib/src/persistence/ 2>&1 | head -30
```

Write tests in `test/persistence/`:
- repository_test.dart: test each repository CRUD operation using an in-memory SQLite DB (not SQLCipher — use NativeDatabase.memory() for tests)
- migration_test.dart: verify schema version 1 creates all expected tables
- At minimum 20 tests

```bash
flutter test test/persistence/ --reporter=compact 2>&1
```

## Output JSON
```json
{
  "agent": "persistence",
  "step": "05",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Persistence layer complete. AppDatabase uses drift with SQLCipher. Two-table message schema: Messages (metadata) + MessageCiphertexts (E2EE payload per recipient device). Key repositories: MessageRepositoryImpl (two-table join), ConversationRepositoryImpl, OutboxRepositoryImpl, RatchetSessionRepositoryImpl, MediaRepositoryImpl, UnackedRatchetRepositoryImpl (two-phase commit crash recovery), DecryptedMessageRepositoryImpl (plaintext cache for instant re-display), ProcessedDistributionRepositoryImpl (SK distribution idempotency). DatabaseFactory handles key generation and DB open. For tests, use NativeDatabase.memory(). space_tombstones is queried server-side via SupabaseClientWrapper (not a local table)."
}
```
