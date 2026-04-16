import 'package:drift/drift.dart';

import '../persistence/database/app_database.dart';

/// Reconciles local optimistic messages with server-authoritative state.
///
/// Called after outbox drain (to update server_seq) and after watermark
/// sync (to merge messages from other devices).
class ConflictResolver {
  /// Creates a [ConflictResolver] backed by [db].
  ConflictResolver({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// After outbox drain succeeds, update local message with server-assigned
  /// sequence number and authoritative timestamp.
  Future<void> reconcileOutboxMessage({
    required String messageId,
    required int serverSeq,
    required DateTime createdAt,
  }) async {
    await (_db.update(_db.messages)
          ..where((m) => m.id.equals(messageId)))
        .write(
      MessagesCompanion(
        serverSeq: Value(serverSeq),
        createdAt: Value(createdAt),
        status: const Value('sent'),
      ),
    );
  }

  /// After watermark sync, merge server messages into local DB.
  ///
  /// Handles:
  /// - New messages from other devices (insert).
  /// - Updated sequences for optimistic messages (replace).
  /// - Tombstones for deleted messages (soft-delete).
  ///
  /// Returns the number of messages reconciled.
  Future<int> reconcileGap(
    String groupId,
    List<Map<String, dynamic>> serverMessages,
  ) async {
    var reconciled = 0;

    await _db.batch((batch) {
      for (final msg in serverMessages) {
        final messageId = msg['id'] as String;
        final messageType = msg['message_type'] as String? ?? 'e2ee';

        if (messageType == 'tombstone') {
          // Server says this message was deleted — mark locally.
          batch.update(
            _db.messages,
            const MessagesCompanion(
              messageType: Value('tombstone'),
              isDeleted: Value(true),
            ),
            where: (m) => m.id.equals(messageId),
          );
        } else {
          // Upsert: update if exists (optimistic), insert if new (other
          // device).
          batch.insert(
            _db.messages,
            MessagesCompanion(
              id: Value(messageId),
              groupId: Value(groupId),
              senderId: Value(msg['user_id'] as String? ?? ''),
              senderDeviceId:
                  Value(msg['sender_device_id'] as String?),
              messageType: Value(messageType),
              serverSeq: Value(msg['server_seq'] as int),
              role: Value(msg['role'] as String? ?? 'user'),
              serverContent: Value(msg['server_content'] as String?),
              createdAt:
                  Value(DateTime.parse(msg['created_at'] as String)),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        reconciled++;
      }
    });

    return reconciled;
  }

  /// Clean up stale optimistic messages that never received a server_seq.
  ///
  /// Called periodically to mark messages stuck in `sending` for longer than
  /// [threshold] as `failed`, so the UI can surface retry affordances.
  ///
  /// Returns the number of messages marked as failed.
  Future<int> cleanupStaleMessages({
    Duration threshold = const Duration(hours: 24),
  }) async {
    final cutoff = DateTime.now().subtract(threshold);

    final stale = await (_db.select(_db.messages)
          ..where(
            (m) =>
                m.serverSeq.isNull() &
                m.createdAt.isSmallerThanValue(cutoff),
          ))
        .get();

    for (final msg in stale) {
      await (_db.update(_db.messages)
            ..where((m) => m.id.equals(msg.id)))
          .write(const MessagesCompanion(status: Value('failed')));
    }

    return stale.length;
  }
}
