/// Interactive notification actions for lock-screen voting.
/// When a consensus-ready notification arrives, the user can
/// vote directly from the notification banner without opening the app.

class NotificationAction {
  final String actionId;
  final String label;
  final String messageId;
  final String groupId;

  const NotificationAction({
    required this.actionId,
    required this.label,
    required this.messageId,
    required this.groupId,
  });
}

/// Register notification action categories with the OS.
/// Called once during app initialization.
abstract class InteractiveNotificationHandler {
  /// Register action categories (e.g., "VOTE" with "Love it" / "Not for me" buttons)
  Future<void> registerCategories();

  /// Handle an action tap from a notification
  Future<void> handleAction(NotificationAction action);

  /// Build notification actions for a consensus-ready decision
  List<NotificationAction> buildVoteActions({
    required String messageId,
    required String groupId,
    required List<String> options,
  });
}

/// Default implementation that uses the crypto isolate for decryption
/// and the outbox for sending the vote.
class DefaultInteractiveHandler implements InteractiveNotificationHandler {
  @override
  Future<void> registerCategories() async {
    // iOS: UNNotificationCategory with UNNotificationAction
    // Android: NotificationCompat.Action with PendingIntent
    // This is wired via platform method channel
  }

  @override
  Future<void> handleAction(NotificationAction action) async {
    // 1. Decrypt the message payload (via crypto isolate or headless)
    // 2. Parse the decision options
    // 3. Register the vote locally in Drift
    // 4. Queue the vote in outbox for server sync
  }

  @override
  List<NotificationAction> buildVoteActions({
    required String messageId,
    required String groupId,
    required List<String> options,
  }) {
    return options.map((option) => NotificationAction(
      actionId: 'vote_${option.toLowerCase().replaceAll(' ', '_')}',
      label: option,
      messageId: messageId,
      groupId: groupId,
    )).toList();
  }
}
