/// Ephemeral delivery/read receipts via Supabase Realtime Broadcast
/// (crypto.md #33).
///
/// Receipts are **never written to the database** — they flow
/// exclusively through Supabase Realtime Broadcast channels as
/// transient signals. This prevents millions of receipt rows from
/// accumulating in Postgres.
///
/// If the recipient is offline when a receipt is broadcast, it is
/// lost. The app reconciles on next sync via message status queries.
///
/// This is an abstract class — the concrete Supabase implementation
/// is wired via the [RealtimeGateway] port so the engine remains
/// transport-agnostic.
library;

/// The type of delivery receipt.
enum ReceiptType {
  /// Message has been delivered to the recipient's device.
  delivered,

  /// Message has been read (opened/viewed) by the recipient.
  read,
}

/// An ephemeral receipt event received via Realtime Broadcast.
class ReceiptEvent {
  /// Creates a [ReceiptEvent].
  const ReceiptEvent({
    required this.messageId,
    required this.userId,
    required this.deviceId,
    required this.type,
    required this.timestamp,
  });

  /// Constructs from a Realtime broadcast payload map.
  factory ReceiptEvent.fromBroadcastPayload(Map<String, dynamic> payload) {
    return ReceiptEvent(
      messageId: payload['messageId'] as String,
      userId: payload['userId'] as String,
      deviceId: payload['deviceId'] as int,
      type: payload['type'] == 'read' ? ReceiptType.read : ReceiptType.delivered,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        payload['timestamp'] as int,
      ),
    );
  }

  /// The message this receipt refers to.
  final String messageId;

  /// The user who generated this receipt.
  final String userId;

  /// The device that generated this receipt.
  final int deviceId;

  /// Whether this is a delivered or read receipt.
  final ReceiptType type;

  /// When the receipt was generated (client-side timestamp).
  final DateTime timestamp;

  /// Serialises to a broadcast-compatible map.
  Map<String, dynamic> toBroadcastPayload() => <String, dynamic>{
        'messageId': messageId,
        'userId': userId,
        'deviceId': deviceId,
        'type': type == ReceiptType.read ? 'read' : 'delivered',
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  @override
  String toString() =>
      'ReceiptEvent(messageId: $messageId, userId: $userId, '
      'type: $type)';
}

/// Abstract interface for ephemeral delivery/read receipts.
///
/// Implementations must use Supabase Realtime Broadcast (or equivalent
/// ephemeral pubsub) — never write receipts to the database.
abstract class RealtimeReceipts {
  /// Subscribe to receipt broadcasts for a group.
  ///
  /// Returns a broadcast stream of [ReceiptEvent]s. The stream emits
  /// events as they arrive; no historical receipts are replayed.
  ///
  /// Call the returned stream's subscription `.cancel()` to unsubscribe.
  Stream<ReceiptEvent> subscribeReceipts(String groupId);

  /// Send a delivered receipt (broadcast only — no DB write).
  ///
  /// Fire-and-forget: implementations should log but not throw on failure.
  Future<void> sendDelivered({
    required String groupId,
    required String messageId,
    required String userId,
    required int deviceId,
  });

  /// Send a read receipt (broadcast only — no DB write).
  ///
  /// Fire-and-forget: implementations should log but not throw on failure.
  Future<void> sendRead({
    required String groupId,
    required String messageId,
    required String userId,
    required int deviceId,
  });

  /// Tear down all active receipt channels.
  ///
  /// Call on logout or engine dispose.
  Future<void> dispose();
}
