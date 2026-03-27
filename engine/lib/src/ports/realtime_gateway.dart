abstract class RealtimeGateway {
  Stream<Map<String, dynamic>> subscribe(String groupId);
  Future<void> unsubscribe(String groupId);
  Future<void> publishPresence(String groupId, String userId, String state);
  Future<void> publishTyping(String groupId, String userId);
}
