import 'package:e2ee_chat_sdk/src/domain/models/message.dart';

/// Abstract repository for message persistence.
///
/// Implementations handle encrypted storage via SQLCipher/drift.
abstract class MessageRepository {
  /// Persists a single message.
  Future<void> saveMessage(Message message);

  /// Persists multiple messages in a single batch.
  Future<void> saveMessages(List<Message> messages);

  /// Retrieves a message by its client-generated UUID.
  Future<Message?> getMessageById(String id);

  /// Retrieves messages for a conversation with cursor-based pagination.
  ///
  /// Returns up to [limit] messages, optionally before the message with
  /// ID [beforeId] (for backward pagination).
  Future<List<Message>> getMessages(
    String groupId, {
    int limit = 50,
    String? beforeId,
  });

  /// Updates the delivery status of a message.
  Future<void> updateMessageStatus(String id, MessageStatus status);

  /// Marks a message as deleted.
  Future<void> markDeleted(String id, {required bool forEveryone});

  /// Adds a reaction emoji from a user to a message.
  Future<void> setReaction(String messageId, String userId, String emoji);

  /// Removes a reaction emoji from a user on a message.
  Future<void> removeReaction(String messageId, String userId, String emoji);

  /// Toggles the starred state of a message.
  Future<void> setStar(String messageId, {required bool starred});

  /// Searches messages by text content, optionally scoped to a conversation.
  Future<List<Message>> search(String query, {String? groupId});

  /// Returns a reactive stream of messages for a conversation.
  Stream<List<Message>> watchMessages(String groupId);
}
