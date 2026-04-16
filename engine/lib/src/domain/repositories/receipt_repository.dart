import 'package:e2ee_chat_sdk/src/domain/models/receipt.dart';

/// Abstract repository for delivery/read receipt persistence.
///
/// Implementations handle encrypted storage via SQLCipher/drift.
abstract class ReceiptRepository {
  /// Persists a delivery or read receipt.
  Future<void> saveReceipt(Receipt receipt);

  /// Retrieves all receipts for a specific message.
  Future<List<Receipt>> getReceipts(String messageId);

  /// Returns a reactive stream of receipts for a conversation.
  Stream<List<Receipt>> watchReceipts(String groupId);
}
