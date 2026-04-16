import 'package:drift/drift.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';

/// Pure local-first repository that provides reactive Drift streams for
/// all main screens.
///
/// The UI subscribes to these streams and **never** awaits a network call
/// in the render path. Data flows in via the sync layer writing to the
/// local DB; this repository simply projects reactive views over that data.
///
/// MOBILE-01: Zero-network render path.
class LocalFeedRepository {
  /// Creates a [LocalFeedRepository] backed by the given database.
  LocalFeedRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Conversation list (home screen)
  // ---------------------------------------------------------------------------

  /// Watches all conversations ordered by most-recent activity.
  ///
  /// Returns a reactive stream that re-emits whenever any conversation row
  /// changes (new message, read status update, pin/archive toggle, etc.).
  /// Archived conversations are excluded by default.
  Stream<List<ConversationRow>> watchConversations() {
    final query = _db.select(_db.conversations)
      ..where((c) => c.isArchived.equals(false))
      ..orderBy([
        // Pinned conversations float to the top within their timestamp order.
        (c) => OrderingTerm.desc(c.isPinned),
        (c) => OrderingTerm.desc(c.lastMessageTimestamp),
      ]);
    return query.watch();
  }

  // ---------------------------------------------------------------------------
  // Message list (chat screen)
  // ---------------------------------------------------------------------------

  /// Watches messages for a single conversation, newest first.
  ///
  /// [limit] controls the initial page size (default 50). The UI calls
  /// [loadOlderMessages] when the user scrolls up past the loaded window.
  Stream<List<MessageRow>> watchMessages(
    String groupId, {
    int limit = 50,
  }) {
    final query = _db.select(_db.messages)
      ..where((m) => m.groupId.equals(groupId))
      ..orderBy([(m) => OrderingTerm.desc(m.serverSeq)])
      ..limit(limit);
    return query.watch();
  }

  // ---------------------------------------------------------------------------
  // Unread count (badge / per-conversation indicator)
  // ---------------------------------------------------------------------------

  /// Watches the number of messages in [groupId] whose `serverSeq` is
  /// strictly greater than [lastReadSeq].
  ///
  /// The watermark ([lastReadSeq]) is the highest sequence number the local
  /// user has read. Messages with `serverSeq == null` (outbox, not yet
  /// acknowledged by the server) are excluded from the count.
  Stream<int> watchUnreadCount(String groupId, int lastReadSeq) {
    final countExpr = _db.messages.id.count();

    final query = _db.selectOnly(_db.messages)
      ..addColumns([countExpr])
      ..where(_db.messages.groupId.equals(groupId))
      ..where(_db.messages.serverSeq.isBiggerThanValue(lastReadSeq))
      ..where(_db.messages.serverSeq.isNotNull());

    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  // ---------------------------------------------------------------------------
  // Pagination (scroll-up to load history)
  // ---------------------------------------------------------------------------

  /// Loads a page of messages older than [beforeSeq] for backwards pagination.
  ///
  /// Returns messages ordered newest-first (same as [watchMessages]) so the
  /// UI can simply prepend them to the existing list.
  Future<List<MessageRow>> loadOlderMessages(
    String groupId,
    int beforeSeq, {
    int limit = 50,
  }) {
    final query = _db.select(_db.messages)
      ..where((m) => m.groupId.equals(groupId))
      ..where((m) => m.serverSeq.isSmallerThanValue(beforeSeq))
      ..orderBy([(m) => OrderingTerm.desc(m.serverSeq)])
      ..limit(limit);
    return query.get();
  }
}
