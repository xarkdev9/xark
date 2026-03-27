/// Abstract repository for tracking processed sender key distribution messages.
///
/// Prevents duplicate processing of distribution messages that may be
/// received multiple times during sync.
abstract class ProcessedDistributionRepository {
  /// Returns whether a distribution message has already been processed.
  Future<bool> isProcessed(String messageId);

  /// Marks a distribution message as processed.
  Future<void> markProcessed(String messageId);
}
