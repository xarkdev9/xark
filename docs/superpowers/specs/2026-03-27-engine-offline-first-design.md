# Spec 3: "Engine" — Offline-First Mobile Architecture

**Date:** 2026-03-27
**Scope:** Local-first UI, watermark sync, persistent outbox, server-authoritative offline queue, background media uploads, sync coordinator
**Platform:** Primarily Engine (Flutter/Dart), some Web (Next.js) parity
**Target:** App opens in <50ms, works perfectly offline, syncs seamlessly on reconnect
**Depends on:** Fortress (atomic RPC, partitioning, ports) + Vault (crypto isolate, multi-device, streaming AEAD)

---

## Decisions Already Made

- Server-authoritative with offline queue (no CRDTs)
- Group-scoped `server_seq` for ordering (from Fortress)
- `read_watermarks` table for unread tracking (from Fortress)
- Crypto isolate handles all encrypt/decrypt (from Vault)
- Drift ORM with SQLCipher for encrypted local storage (existing)

---

## 1. Pure Local-First UI — Drift (MOBILE-01)

### Problem

The Flutter UI currently `await`s network calls to render screens. On a subway with no signal, the app shows spinners forever.

### Solution

The UI renders entirely from local Drift SQLite streams. The network syncs the DB; the DB drives the UI. Zero network calls in the render path.

### Architecture

```
User Action → Write to Drift → UI updates instantly (reactive stream)
                 ↓
           Outbox queue → Background worker → Server
                                                ↓
Server push/poll → Write to Drift → UI updates reactively
```

### Changes

**Engine — New file: `engine/lib/src/persistence/repositories/local_feed_repository.dart`**

Reactive queries for all main screens:

```dart
/// Conversations list (home screen) — purely from local DB
Stream<List<Conversation>> watchConversations() =>
  (select(conversations)
    ..orderBy([(c) => OrderingTerm.desc(c.lastMessageTimestamp)]))
  .watch();

/// Messages for a conversation — purely from local DB
Stream<List<Message>> watchMessages(String groupId, {int limit = 50}) =>
  (select(messages)
    ..where((m) => m.groupId.equals(groupId))
    ..orderBy([(m) => OrderingTerm.desc(m.serverSeq)])
    ..limit(limit))
  .watch();

/// Unread count — purely from local DB using read_watermarks
Stream<int> watchUnreadCount(String groupId, int lastReadSeq) =>
  (select(messages)
    ..where((m) => m.groupId.equals(groupId) & m.serverSeq.isBiggerThanValue(lastReadSeq)))
  .watch()
  .map((rows) => rows.length);

/// Total unread across all groups
Stream<int> watchTotalUnread();
```

**Engine — Modify: `engine/lib/src/chat_engine_impl.dart`**
- Expose `LocalFeedRepository` through the public API
- `ChatEngine.conversations` stream comes from Drift, not network
- `ChatSession.messages` stream comes from Drift, not network

---

## 2. Watermark-Based Gap Sync (MOBILE-02)

### Problem

When the app regains connection after being offline, it needs to fetch all missed messages efficiently without re-downloading everything.

### Solution

Track `last_received_server_seq` per group (the watermark). On reconnect, fetch `messages WHERE server_seq > watermark` for each group.

### Changes

**Engine — New file: `engine/lib/src/sync/watermark_sync.dart`**

```dart
class WatermarkSync {
  final AppDatabase _db;
  final MessageGateway _gateway;

  /// Get the current watermark for a group (highest server_seq we have locally)
  Future<int> getWatermark(String groupId) async {
    final result = await (_db.select(_db.messages)
      ..where((m) => m.groupId.equals(groupId))
      ..orderBy([(m) => OrderingTerm.desc(m.serverSeq)])
      ..limit(1))
    .getSingleOrNull();
    return result?.serverSeq ?? 0;
  }

  /// Sync a group: fetch all messages after the watermark
  Future<int> syncGroup(String groupId) async {
    final watermark = await getWatermark(groupId);
    final page = await _gateway.fetchMessages(
      groupId,
      watermark.toString(),  // cursor = watermark
      SyncDirection.forward,
      limit: 500,
    );

    // Insert into local DB (Drift handles dedup via primary key)
    for (final msg in page.messages) {
      await _db.into(_db.messages).insertOnConflictUpdate(
        MessagesCompanion.fromJson(msg),
      );
    }

    return page.messages.length;
  }

  /// Sync all groups the user is a member of
  Future<Map<String, int>> syncAll() async {
    final groups = await (_db.select(_db.conversations)).get();
    final results = <String, int>{};
    for (final group in groups) {
      results[group.id] = await syncGroup(group.id);
    }
    return results;
  }
}
```

**Engine — New Drift table: `sync_watermarks`**
```dart
class SyncWatermarks extends Table {
  TextColumn get groupId => text()();
  IntColumn get lastReceivedSeq => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {groupId};
}
```

---

## 3. Optimistic UI + Persistent Outbox (MOBILE-03)

### Problem

When a user sends a message offline, the UI must show it immediately (optimistic). The message queues locally and syncs when connectivity returns. Retries must handle network failures gracefully.

### Solution

Every send writes to a local `outbox` table first. The UI updates instantly from the local DB. A background worker drains the outbox to the server with exponential backoff.

### Changes

**Engine — New file: `engine/lib/src/sync/outbox_worker.dart`**

```dart
class OutboxWorker {
  final AppDatabase _db;
  final MessageGateway _gateway;
  Timer? _drainTimer;
  bool _isDraining = false;

  static const _maxRetries = 10;
  static const _baseBackoffMs = 2000; // 2s, 4s, 8s, 16s...

  /// Start the outbox drain loop
  void start() {
    _drainTimer = Timer.periodic(const Duration(seconds: 2), (_) => drain());
  }

  /// Stop the outbox drain loop
  void stop() {
    _drainTimer?.cancel();
    _drainTimer = null;
  }

  /// Drain all pending outbox items, serially per group
  Future<void> drain() async {
    if (_isDraining) return; // Prevent concurrent drains
    _isDraining = true;

    try {
      final items = await (_db.select(_db.outboxItems)
        ..where((o) => o.nextRetryAt.isSmallerOrEqualValue(DateTime.now()))
        ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
        ..limit(50))
      .get();

      // Group by groupId and drain serially within each group
      // (prevents scrambling Double Ratchet chain indices)
      final byGroup = <String, List<OutboxItem>>{};
      for (final item in items) {
        byGroup.putIfAbsent(item.groupId, () => []).add(item);
      }

      for (final entry in byGroup.entries) {
        for (final item in entry.value) {
          await _drainItem(item);
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _drainItem(OutboxItem item) async {
    try {
      final envelope = jsonDecode(item.encryptedEnvelope);
      await _gateway.sendMessage(envelope);
      // Success — remove from outbox
      await (_db.delete(_db.outboxItems)..where((o) => o.id.equals(item.id))).go();
    } catch (e) {
      // Failure — increment retry count, calculate next retry
      final newRetryCount = item.retryCount + 1;
      if (newRetryCount >= _maxRetries) {
        // Max retries — mark as failed
        await (_db.update(_db.outboxItems)..where((o) => o.id.equals(item.id)))
          .write(OutboxItemsCompanion(
            retryCount: Value(newRetryCount),
            nextRetryAt: Value(DateTime.now().add(const Duration(days: 365))), // effectively dead
          ));
        return;
      }
      final backoff = Duration(milliseconds: _baseBackoffMs * (1 << newRetryCount));
      await (_db.update(_db.outboxItems)..where((o) => o.id.equals(item.id)))
        .write(OutboxItemsCompanion(
          retryCount: Value(newRetryCount),
          nextRetryAt: Value(DateTime.now().add(backoff)),
        ));
    }
  }
}
```

**Key constraint:** Outbox items for the same `group_id` MUST drain serially (not in parallel). Concurrent sending scrambles Double Ratchet chain indices.

---

## 4. Server-Authoritative Offline Queue (MOBILE-04)

### Problem

Multiple devices may be offline simultaneously. When they come back, the server resolves conflicts by ordering. The server is the source of truth.

### Solution

The pattern is simple because the server already handles this:
1. Each device sends via the outbox (MOBILE-03)
2. The atomic RPC assigns `server_seq` (from Fortress)
3. On reconnect, watermark sync (MOBILE-02) fetches the authoritative order
4. Local messages get their `server_seq` updated from the server response
5. UI re-renders in server-authoritative order

### Changes

**Engine — New file: `engine/lib/src/sync/conflict_resolver.dart`**

```dart
class ConflictResolver {
  final AppDatabase _db;

  /// After outbox drain succeeds, update local message with server-assigned seq
  Future<void> reconcileMessage(String messageId, int serverSeq, DateTime createdAt) async {
    await (_db.update(_db.messages)..where((m) => m.id.equals(messageId)))
      .write(MessagesCompanion(
        serverSeq: Value(serverSeq),
        status: const Value(MessageStatus.sent),
        createdAt: Value(createdAt),
      ));
  }

  /// After watermark sync, detect if any local optimistic messages
  /// were superseded by server-ordered versions
  Future<void> reconcileGap(String groupId, List<Map<String, dynamic>> serverMessages) async {
    for (final msg in serverMessages) {
      final messageId = msg['id'] as String;
      final serverSeq = msg['server_seq'] as int;

      // Upsert: update if exists (optimistic), insert if new (from another device)
      await _db.into(_db.messages).insertOnConflictUpdate(
        MessagesCompanion(
          id: Value(messageId),
          groupId: Value(groupId),
          serverSeq: Value(serverSeq),
          status: const Value(MessageStatus.delivered),
          // ... other fields from server
        ),
      );
    }
  }
}
```

---

## 5. Resumable Background Media Uploads (MOBILE-05)

### Problem

Encrypted media uploads can be large (up to 2GB with streaming AEAD from Vault). If the user force-quits the app mid-upload, the upload should resume from where it left off.

### Solution

Use OS-level background task schedulers (`WorkManager` on Android, `BGTaskScheduler` on iOS) to continue uploads even after the app is killed.

### Changes

**Engine — New file: `engine/lib/src/media/background_uploader.dart`**

```dart
/// Background media upload manager.
/// Encrypts media via streaming AEAD, uploads in chunks,
/// persists progress to Drift for resumability.

class UploadTask {
  final String mediaId;
  final String groupId;
  final String localPath;
  final String mimeType;
  final int totalBytes;
  int uploadedBytes;
  String? downloadUrl;
  UploadStatus status;

  UploadTask({
    required this.mediaId,
    required this.groupId,
    required this.localPath,
    required this.mimeType,
    required this.totalBytes,
    this.uploadedBytes = 0,
    this.downloadUrl,
    this.status = UploadStatus.pending,
  });
}

enum UploadStatus { pending, encrypting, uploading, complete, failed }

abstract class BackgroundUploader {
  /// Queue a media file for background upload
  Future<String> enqueueUpload({
    required String groupId,
    required String localPath,
    required String mimeType,
  });

  /// Get upload progress stream
  Stream<UploadTask> watchUpload(String mediaId);

  /// Get all pending/active uploads
  Stream<List<UploadTask>> watchAllUploads();

  /// Resume a failed upload
  Future<void> retryUpload(String mediaId);

  /// Cancel an upload
  Future<void> cancelUpload(String mediaId);
}
```

**Engine — New Drift table: `upload_tasks`**
```dart
class UploadTasks extends Table {
  TextColumn get mediaId => text()();
  TextColumn get groupId => text()();
  TextColumn get localPath => text()();
  TextColumn get mimeType => text()();
  IntColumn get totalBytes => integer()();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get downloadUrl => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get encryptionKeyJson => text().nullable()(); // StreamingAeadKey
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {mediaId};
}
```

---

## 6. Background Sync Coordinator (MOBILE-06)

### Problem

Multiple background processes need coordination: outbox drain, watermark sync, media uploads, push decryption, typing indicators, presence. Without a coordinator, these compete for resources and can interfere with each other.

### Solution

A single `SyncCoordinator` orchestrates all background sync activities. It manages the lifecycle of sub-workers and coordinates their execution.

### Changes

**Engine — New file: `engine/lib/src/sync/sync_coordinator.dart`**

```dart
/// Central coordinator for all background sync operations.
/// Manages lifecycle of: outbox worker, watermark sync, media uploads,
/// realtime subscriptions, typing/presence.

enum SyncState { idle, syncing, error }

class SyncCoordinator {
  final AppDatabase _db;
  final MessageGateway _messageGateway;
  final RealtimeGateway _realtimeGateway;
  final BackgroundUploader _uploader;
  final OutboxWorker _outboxWorker;
  final WatermarkSync _watermarkSync;
  final ConflictResolver _conflictResolver;

  final _stateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get state => _stateController.stream;

  bool _isRunning = false;

  SyncCoordinator({
    required AppDatabase db,
    required MessageGateway messageGateway,
    required RealtimeGateway realtimeGateway,
    required BackgroundUploader uploader,
  }) : _db = db,
       _messageGateway = messageGateway,
       _realtimeGateway = realtimeGateway,
       _uploader = uploader,
       _outboxWorker = OutboxWorker(db: db, gateway: messageGateway),
       _watermarkSync = WatermarkSync(db: db, gateway: messageGateway),
       _conflictResolver = ConflictResolver(db: db);

  /// Start all sync workers (called on app foreground / engine.resume())
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _stateController.add(SyncState.syncing);

    // 1. Drain outbox first (send pending messages)
    _outboxWorker.start();

    // 2. Sync missed messages via watermarks
    try {
      final results = await _watermarkSync.syncAll();
      final totalSynced = results.values.fold<int>(0, (a, b) => a + b);
      if (totalSynced > 0) {
        // Reconcile any conflicts
        for (final entry in results.entries) {
          if (entry.value > 0) {
            // Messages were synced — UI updates reactively via Drift streams
          }
        }
      }
    } catch (e) {
      _stateController.add(SyncState.error);
    }

    // 3. Subscribe to realtime for ongoing updates
    final groups = await (_db.select(_db.conversations)).get();
    for (final group in groups) {
      _realtimeGateway.subscribe(group.id).listen((event) {
        _handleRealtimeEvent(group.id, event);
      });
    }

    _stateController.add(SyncState.idle);
  }

  /// Stop all sync workers (called on app background / engine.suspend())
  Future<void> stop() async {
    _isRunning = false;
    _outboxWorker.stop();
    // Unsubscribe from realtime
    final groups = await (_db.select(_db.conversations)).get();
    for (final group in groups) {
      await _realtimeGateway.unsubscribe(group.id);
    }
    _stateController.add(SyncState.idle);
  }

  /// Handle incoming realtime event
  Future<void> _handleRealtimeEvent(String groupId, Map<String, dynamic> event) async {
    // Insert into local DB — UI updates reactively
    final messageId = event['id'] as String?;
    if (messageId != null) {
      await _db.into(_db.messages).insertOnConflictUpdate(
        MessagesCompanion.fromJson(event),
      );
    }
  }

  /// Force a full resync (e.g., after device linking)
  Future<void> forceResync() async {
    await stop();
    await start();
  }
}
```

**Engine — Modify: `engine/lib/src/chat_engine_impl.dart`**
- Replace ad-hoc sync logic with `SyncCoordinator`
- `engine.resume()` calls `syncCoordinator.start()`
- `engine.suspend()` calls `syncCoordinator.stop()`
- `engine.dispose()` calls `syncCoordinator.stop()` + cleanup

---

## Build Order & Parallelism

```
PARALLEL (all independent):
  Task 1: MOBILE-01 — Local-first Drift feeds (LocalFeedRepository)
  Task 2: MOBILE-02 — Watermark sync (WatermarkSync + SyncWatermarks table)
  Task 3: MOBILE-03 — Outbox worker (OutboxWorker, serial per-group drain)

SEQUENTIAL (after above):
  Task 4: MOBILE-04 — Conflict resolver (depends on watermark + outbox)
  Task 5: MOBILE-05 — Background media uploads (UploadTasks table + BackgroundUploader)

FINAL:
  Task 6: MOBILE-06 — Sync coordinator (orchestrates all of the above)
```

Tasks 1-3 can run in parallel (no shared files). Task 4 depends on 2+3. Task 5 is independent but logically follows. Task 6 wires everything together.

---

## Success Criteria

| Metric | Target |
|--------|--------|
| App cold start to rendered UI | < 50ms (local DB only, zero network) |
| Offline message send (write to outbox) | < 10ms |
| Reconnect sync (50 missed messages) | < 3 seconds |
| Outbox drain (100 queued messages) | < 10 seconds |
| Background media upload survives force-quit | Yes (OS scheduler) |
| Concurrent group outbox drain | Serial per group (no ratchet scramble) |
| Duplicate message on reconnect | 0 (idempotent via UUIDv7) |
