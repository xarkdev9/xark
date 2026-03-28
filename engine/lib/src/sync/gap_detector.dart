import 'package:e2ee_chat_sdk/src/domain/repositories/message_repository.dart';
import 'package:e2ee_chat_sdk/src/sync/sync_observer.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';

/// Fills message gaps after a reconnect or cold start.
///
/// For each active conversation, determines the latest message we have
/// locally and fetches any newer messages from the server. Results are
/// returned as raw server rows for the caller to decrypt and persist.
class GapDetector {
  /// Creates a [GapDetector].
  GapDetector({
    required SupabaseClientWrapper apiClient,
    required MessageRepository messageRepo,
    this.observer,
  })  : _apiClient = apiClient,
        _messageRepo = messageRepo;

  final SupabaseClientWrapper _apiClient;
  final MessageRepository _messageRepo;

  /// Optional observer for diagnostic callbacks.
  final SyncObserver? observer;

  /// Fetches messages missed while offline for the given [groupIds].
  ///
  /// For each space, looks up the latest local message timestamp and
  /// pulls any server messages created after that point.
  ///
  /// Returns a flat list of raw server row maps. The caller is
  /// responsible for decrypting, deduplicating, and persisting them.
  Future<List<Map<String, dynamic>>> fillGaps(
    List<String> groupIds,
  ) async {
    final stopwatch = Stopwatch()..start();
    final allMissed = <Map<String, dynamic>>[];

    for (final groupId in groupIds) {
      // Get the latest message we have locally for this space.
      final messages = await _messageRepo.getMessages(groupId, limit: 1);

      final after =
          messages.isNotEmpty ? messages.first.timestamp : null;

      // Fetch from server anything newer than our latest.
      final serverMessages = await _apiClient.fetchMessageHistory(
        groupId,
        after: after,
      );

      allMissed.addAll(serverMessages);
    }

    stopwatch.stop();
    observer?.onSyncCompleted(allMissed.length, stopwatch.elapsed);

    return allMissed;
  }
}
