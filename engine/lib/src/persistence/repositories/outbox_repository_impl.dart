import 'package:chat_engine/src/persistence/database/app_database.dart';
import 'package:chat_engine/src/persistence/repositories/outbox_repository.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [OutboxRepository].
///
/// Items are ordered by creation time and filtered by `nextRetryAt` to
/// implement exponential back-off retry.
class OutboxRepositoryImpl implements OutboxRepository {
  /// Creates an [OutboxRepositoryImpl] backed by the given database.
  OutboxRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<void> enqueue(OutboxItemRow item) async {
    await _db.into(_db.outboxItems).insertOnConflictUpdate(item);
  }

  @override
  Future<List<OutboxItemRow>> getPending({int limit = 20}) async {
    final now = DateTime.now();
    final query = _db.select(_db.outboxItems)
      ..where((t) => t.nextRetryAt.isSmallerOrEqualValue(now))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(limit);
    return query.get();
  }

  @override
  Future<void> markSent(String id) async {
    await (_db.delete(_db.outboxItems)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<void> markFailed(
    String id, {
    required Duration retryAfter,
  }) async {
    final nextRetry = DateTime.now().add(retryAfter);

    // Read current retry count, increment, and write back.
    final current = await (_db.select(_db.outboxItems)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (current == null) return;

    await (_db.update(_db.outboxItems)
          ..where((t) => t.id.equals(id)))
        .write(
      OutboxItemsCompanion(
        retryCount: Value(current.retryCount + 1),
        nextRetryAt: Value(nextRetry),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.outboxItems)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<int> getPendingCount() async {
    final count = _db.outboxItems.id.count();
    final query = _db.selectOnly(_db.outboxItems)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
