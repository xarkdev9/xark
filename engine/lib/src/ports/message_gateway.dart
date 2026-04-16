enum SyncDirection { forward, backward }

class SendResult {
  final String messageId;
  final int serverSeq;
  final DateTime createdAt;
  final String status;
  const SendResult({
    required this.messageId,
    required this.serverSeq,
    required this.createdAt,
    required this.status,
  });
}

class MessagePage {
  final List<Map<String, dynamic>> messages;
  final String? nextCursor;
  const MessagePage({required this.messages, this.nextCursor});
}

abstract class MessageGateway {
  Future<SendResult> sendMessage(Map<String, dynamic> envelope);
  Future<MessagePage> fetchMessages(
    String groupId, {
    String? cursor,
    SyncDirection direction = SyncDirection.forward,
    int limit = 50,
  });
  Future<List<Map<String, dynamic>>> fetchCiphertexts(
    String messageId,
    String recipientId,
    int deviceId,
  );
  Future<void> acknowledgeDelivery(String messageId, int deviceId);
}
