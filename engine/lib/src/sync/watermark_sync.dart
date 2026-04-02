import 'package:drift/drift.dart';

import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/ports/message_gateway.dart';

/// Watermark-based gap sync for offline reconnection (MOBILE-02).
///
/// Tracks the highest `server_seq` received per group in the
/// [SyncWatermarks] table. On reconnect, fetches all messages
/// WHERE `server_seq > watermark` using paginated forward sync
/// via [MessageGateway]. Bulk-inserts with deduplication
/// (insertOrReplace keyed on message ID).
///
/// Depends on the `SyncWatermarks` table being defined in
/// `tables.dart` and registered in [AppDatabase] (MOBILE-01).
class WatermarkSync {
  /// Creates a [WatermarkSync].
  WatermarkSync({
    required AppDatabase db,
    required MessageGateway gateway,
  })  : _db = db,
        _gateway = gateway;

  final AppDatabase _db;
  final MessageGateway _gateway;

  /// Maximum number of messages to fetch per page.
  static const int _pageLimit = 100;

  /// Returns the last received server sequence number for [groupId].
  ///
  /// Returns `0` if no watermark has been recorded yet, meaning a
  /// full sync from the beginning is required.
  Future<int> getWatermark(String groupId) async {
    final result = await (_db.select(_db.syncWatermarks)
          ..where((w) => w.groupId.equals(groupId)))
        .getSingleOrNull();
    return result?.lastReceivedSeq ?? 0;
  }

  /// Persists the watermark for [groupId] to [seq].
  ///
  /// Uses upsert semantics — inserts a new row or updates the
  /// existing one on conflict (keyed by `groupId`).
  Future<void> updateWatermark(String groupId, int seq) async {
    await _db.into(_db.syncWatermarks).insertOnConflictUpdate(
          SyncWatermarksCompanion(
            groupId: Value(groupId),
            lastReceivedSeq: Value(seq),
            lastSyncAt: Value(DateTime.now()),
          ),
        );
  }

  /// Syncs a single group by fetching all messages after its watermark.
  ///
  /// Pages through the [MessageGateway] in forward order, bulk-inserting
  /// each page into the local database with deduplication. Updates the
  /// watermark after each page so progress is not lost on crash.
  ///
  /// Returns the total number of messages synced.
  Future<int> syncGroup(String groupId) async {
    final watermark = await getWatermark(groupId);
    var totalSynced = 0;
    String? cursor = watermark > 0 ? watermark.toString() : null;

    while (true) {
      final page = await _gateway.fetchMessages(
        groupId,
        cursor: cursor,
        direction: SyncDirection.forward,
        limit: _pageLimit,
      );

      if (page.messages.isEmpty) break;

      // Bulk insert with dedup (insertOrReplace keyed on message ID).
      await _db.batch((batch) {
        for (final msg in page.messages) {
          batch.insert(
            _db.messages,
            MessagesCompanion(
              id: Value(msg['id'] as String),
              groupId: Value(groupId),
              senderId: Value(msg['sender_id'] as String),
              senderDeviceId: Value(msg['sender_device_id'] as String?),
              messageType:
                  Value(msg['message_type'] as String? ?? 'e2ee'),
              serverSeq: Value(msg['server_seq'] as int?),
              serverContent: Value(msg['server_content'] as String?),
              createdAt: Value(
                DateTime.parse(msg['created_at'] as String),
              ),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      totalSynced += page.messages.length;

      // Advance the watermark to the highest seq in this page.
      final seqs = page.messages
          .map((m) => m['server_seq'] as int?)
          .whereType<int>()
          .toList();
      if (seqs.isEmpty) break;
      final maxSeq = seqs.reduce((a, b) => a > b ? a : b);
      await updateWatermark(groupId, maxSeq);

      cursor = page.nextCursor;
      if (cursor == null) break;
    }

    return totalSynced;
  }

  /// Syncs all known conversations.
  ///
  /// Returns a map of `groupId → messagesSynced`. A value of `-1`
  /// indicates that the sync failed for that group (the error is
  /// swallowed so other groups can still sync).
  Future<Map<String, int>> syncAll() async {
    final groups = await _db.select(_db.conversations).get();
    final results = <String, int>{};

    for (final group in groups) {
      try {
        results[group.id] = await syncGroup(group.id);
      } catch (_) {
        results[group.id] = -1;
      }
    }

    return results;
  }
}
