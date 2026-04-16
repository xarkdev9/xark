import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/processed_distribution_repository.dart';

/// Drift-backed implementation of [ProcessedDistributionRepository].
///
/// Prevents duplicate processing of sender key distribution messages
/// that may arrive multiple times during sync or reconnection.
class ProcessedDistributionRepositoryImpl
    implements ProcessedDistributionRepository {
  /// Creates a [ProcessedDistributionRepositoryImpl] backed by the given
  /// database.
  ProcessedDistributionRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<bool> isProcessed(String messageId) async {
    final query = _db.select(_db.processedDistributions)
      ..where((t) => t.messageId.equals(messageId));
    final row = await query.getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> markProcessed(String messageId) async {
    await _db.into(_db.processedDistributions).insertOnConflictUpdate(
          ProcessedDistributionRow(
            messageId: messageId,
            processedAt: DateTime.now(),
          ),
        );
  }
}
