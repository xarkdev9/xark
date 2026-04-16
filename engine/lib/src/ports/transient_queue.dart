class QueuedMessage {
  final String messageId;
  final Map<String, dynamic> payload;
  final int enqueuedAt;
  const QueuedMessage({
    required this.messageId,
    required this.payload,
    required this.enqueuedAt,
  });
}

abstract class TransientQueue {
  Future<void> enqueue(String recipientDeviceId, Map<String, dynamic> payload);
  Future<List<QueuedMessage>> dequeue(String deviceId, {int limit = 100});
  Future<void> acknowledge(String deviceId, List<String> messageIds);
  Future<int> getQueueDepth(String deviceId);
}
