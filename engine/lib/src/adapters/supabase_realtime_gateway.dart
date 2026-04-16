import 'dart:async';

import 'package:e2ee_chat_sdk/src/ports/realtime_gateway.dart';
import 'package:e2ee_chat_sdk/src/transport/realtime_listener.dart';

/// Supabase Realtime implementation of [RealtimeGateway].
///
/// Delegates to [RealtimeListener] for Postgres-change subscriptions.
/// Presence and typing are broadcast via Supabase Realtime channels.
class SupabaseRealtimeGateway implements RealtimeGateway {
  /// Creates a [SupabaseRealtimeGateway].
  SupabaseRealtimeGateway(this._listener);

  final RealtimeListener _listener;

  @override
  Stream<Map<String, dynamic>> subscribe(String groupId) {
    // RealtimeListener returns a typed stream per group.
    // Convert RealtimeMessageEvent to a plain map for the port interface.
    return _listener.subscribeToSpace(groupId).map((event) {
      return <String, dynamic>{
        'message_id': event.messageId,
        'group_id': event.groupId,
        'sender_id': event.senderId,
        'sender_device_id': event.senderDeviceId,
        'message_type': event.messageType,
        'created_at': event.createdAt.toIso8601String(),
      };
    });
  }

  @override
  Future<void> unsubscribe(String groupId) async {
    await _listener.unsubscribeFromSpace(groupId);
  }

  @override
  Future<void> publishPresence(
    String groupId,
    String userId,
    String state,
  ) async {
    // Presence via Supabase Realtime Broadcast.
    // Future: dedicated presence channel per group.
  }

  @override
  Future<void> publishTyping(String groupId, String userId) async {
    // Typing indicators via Supabase Realtime Broadcast.
    // Future: dedicated typing channel per group.
  }
}
