import 'package:chat_engine/src/domain/models/receipt.dart';
import 'package:chat_engine/src/domain/repositories/receipt_repository.dart';
import 'package:chat_engine/src/persistence/database/app_database.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [ReceiptRepository].
///
/// Each receipt is uniquely identified by (messageId, userId, deviceId).
class ReceiptRepositoryImpl implements ReceiptRepository {
  /// Creates a [ReceiptRepositoryImpl] backed by the given database.
  ReceiptRepositoryImpl(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  ReceiptRow _toRow(Receipt r) {
    return ReceiptRow(
      messageId: r.messageId,
      userId: r.userId,
      deviceId: r.deviceId,
      deliveredAt: r.deliveredAt,
      readAt: r.readAt,
    );
  }

  Receipt _fromRow(ReceiptRow row) {
    return Receipt(
      messageId: row.messageId,
      userId: row.userId,
      deviceId: row.deviceId,
      deliveredAt: row.deliveredAt,
      readAt: row.readAt,
    );
  }

  // ---------------------------------------------------------------------------
  // ReceiptRepository interface
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveReceipt(Receipt receipt) async {
    await _db.into(_db.receipts).insertOnConflictUpdate(_toRow(receipt));
  }

  @override
  Future<List<Receipt>> getReceipts(String messageId) async {
    final query = _db.select(_db.receipts)
      ..where((t) => t.messageId.equals(messageId));
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Stream<List<Receipt>> watchReceipts(String conversationId) {
    // Join receipts with messages to filter by conversation.
    final query = _db.select(_db.receipts).join([
      innerJoin(
        _db.messages,
        _db.messages.id.equalsExp(_db.receipts.messageId),
      ),
    ])
      ..where(_db.messages.spaceId.equals(conversationId));

    return query.watch().map(
          (rows) => rows
              .map((row) => _fromRow(row.readTable(_db.receipts)))
              .toList(),
        );
  }
}
