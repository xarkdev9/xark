import 'dart:async';

/// Ephemeral typing indicators via Realtime Broadcast.
/// Never written to the database -- transient signals only.
/// Auto-clear after 5 seconds to prevent "ghost typing".

class TypingIndicatorManager {
  final Map<String, Timer> _clearTimers = {};
  final Map<String, Set<String>> _typingUsers = {};
  final _controller = StreamController<TypingEvent>.broadcast();

  static const Duration autoClearDuration = Duration(seconds: 5);

  Stream<TypingEvent> get events => _controller.stream;

  /// Get currently typing users for a group
  Set<String> getTypingUsers(String groupId) {
    return _typingUsers[groupId] ?? {};
  }

  /// Watch typing users for a group reactively
  Stream<Set<String>> watchTypingUsers(String groupId) {
    return events
      .where((e) => e.groupId == groupId)
      .map((_) => getTypingUsers(groupId));
  }

  /// Handle incoming typing broadcast from a remote user
  void onRemoteTyping(String groupId, String userId) {
    _typingUsers.putIfAbsent(groupId, () => {}).add(userId);
    _controller.add(TypingEvent(groupId: groupId, userId: userId, isTyping: true));

    // Auto-clear after 5 seconds
    final key = '$groupId:$userId';
    _clearTimers[key]?.cancel();
    _clearTimers[key] = Timer(autoClearDuration, () {
      _typingUsers[groupId]?.remove(userId);
      if (_typingUsers[groupId]?.isEmpty ?? false) {
        _typingUsers.remove(groupId);
      }
      _controller.add(TypingEvent(groupId: groupId, userId: userId, isTyping: false));
      _clearTimers.remove(key);
    });
  }

  /// Send our own typing indicator (called when user types in input)
  /// The actual broadcast is handled by RealtimeGateway.publishTyping()
  void onLocalTyping(String groupId) {
    // Debounce: don't send more than once every 3 seconds
    // The RealtimeGateway handles the actual broadcast
  }

  /// Clear all typing state (on disconnect or group leave)
  void clearAll() {
    for (final timer in _clearTimers.values) {
      timer.cancel();
    }
    _clearTimers.clear();
    _typingUsers.clear();
  }

  void dispose() {
    clearAll();
    _controller.close();
  }
}

class TypingEvent {
  final String groupId;
  final String userId;
  final bool isTyping;

  const TypingEvent({
    required this.groupId,
    required this.userId,
    required this.isTyping,
  });
}
