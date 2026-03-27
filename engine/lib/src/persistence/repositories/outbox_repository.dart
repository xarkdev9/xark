import 'package:hello_engine/src/persistence/database/app_database.dart';

/// Abstract repository for the offline outbox queue.
///
/// Manages messages that are pending network delivery.
abstract class OutboxRepository {
  /// Adds an item to the outbox queue.
  Future<void> enqueue(OutboxItemRow item);

  /// Returns pending items ready for send, ordered by creation time.
  ///
  /// Only returns items whose `nextRetryAt` is in the past.
  Future<List<OutboxItemRow>> getPending({int limit = 20});

  /// Removes a successfully sent item from the outbox.
  Future<void> markSent(String id);

  /// Increments the retry count and schedules the next retry.
  Future<void> markFailed(String id, {required Duration retryAfter});

  /// Removes an item from the outbox (e.g., user cancelled send).
  Future<void> delete(String id);

  /// Returns the total number of pending outbox items.
  Future<int> getPendingCount();
}
