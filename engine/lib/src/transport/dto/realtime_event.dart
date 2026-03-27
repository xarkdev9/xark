/// A Supabase Realtime notification for a new message row.
///
/// Realtime delivers only the notification; the actual ciphertext is
/// fetched separately via PostgREST.
class RealtimeMessageEvent {
  /// Creates a [RealtimeMessageEvent].
  const RealtimeMessageEvent({
    required this.messageId,
    required this.groupId,
    required this.senderId,
    required this.messageType,
    required this.createdAt,
    this.senderDeviceId,
  });

  /// Constructs from a Postgres change payload's `newRecord` map.
  factory RealtimeMessageEvent.fromPostgresPayload(
    Map<String, dynamic> record,
  ) {
    return RealtimeMessageEvent(
      messageId: record['id'] as String,
      groupId: record['group_id'] as String,
      senderId: record['user_id'] as String,
      senderDeviceId: record['sender_device_id'] as int?,
      messageType: record['message_type'] as String? ?? 'e2ee',
      createdAt: DateTime.parse(record['created_at'] as String),
    );
  }

  /// Server-assigned message row ID.
  final String messageId;

  /// Conversation (space) this message belongs to.
  final String groupId;

  /// User ID of the sender.
  final String senderId;

  /// Device ID of the sender, nullable for system messages.
  final int? senderDeviceId;

  /// Wire-level message type (`e2ee`, `xark`, `system`, etc.).
  final String messageType;

  /// Server-side creation timestamp.
  final DateTime createdAt;

  @override
  String toString() =>
      'RealtimeMessageEvent(messageId: $messageId, '
      'groupId: $groupId, senderId: $senderId, '
      'messageType: $messageType)';
}

/// A Sender Key recovery request received via Realtime broadcast.
class SKRecoveryRequest {
  /// Creates a [SKRecoveryRequest].
  const SKRecoveryRequest({
    required this.requesterId,
    required this.requesterDeviceId,
    required this.targetSenderId,
    required this.groupId,
  });

  /// Constructs from a Realtime broadcast payload map.
  factory SKRecoveryRequest.fromBroadcastPayload(
    Map<String, dynamic> payload,
  ) {
    return SKRecoveryRequest(
      requesterId: payload['requester_id'] as String,
      requesterDeviceId: payload['requester_device_id'] as int,
      targetSenderId: payload['target_sender_id'] as String,
      groupId: payload['group_id'] as String,
    );
  }

  /// User ID requesting the Sender Key.
  final String requesterId;

  /// Device ID of the requester.
  final int requesterDeviceId;

  /// The sender whose Sender Key is needed.
  final String targetSenderId;

  /// Space (group conversation) the key is for.
  final String groupId;

  /// Serialises to a broadcast-compatible map.
  Map<String, dynamic> toBroadcastPayload() => <String, dynamic>{
        'requester_id': requesterId,
        'requester_device_id': requesterDeviceId,
        'target_sender_id': targetSenderId,
        'group_id': groupId,
      };

  @override
  String toString() =>
      'SKRecoveryRequest(requesterId: $requesterId, '
      'requesterDeviceId: $requesterDeviceId, '
      'targetSenderId: $targetSenderId, groupId: $groupId)';
}
