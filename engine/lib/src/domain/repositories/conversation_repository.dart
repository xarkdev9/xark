import 'package:chat_engine/src/domain/models/conversation.dart';

/// Abstract repository for conversation persistence.
///
/// Implementations handle encrypted storage via SQLCipher/drift.
abstract class ConversationRepository {
  /// Persists or updates a conversation.
  Future<void> saveConversation(Conversation conversation);

  /// Retrieves a conversation by its ID.
  Future<Conversation?> getConversation(String id);

  /// Retrieves all conversations, sorted by last message timestamp.
  Future<List<Conversation>> getAllConversations();

  /// Updates the unread message count for a conversation.
  Future<void> updateUnreadCount(String conversationId, int count);

  /// Pins or unpins a conversation.
  Future<void> setPin(String conversationId, {required bool pinned});

  /// Archives or unarchives a conversation.
  Future<void> setArchive(String conversationId, {required bool archived});

  /// Mutes or unmutes a conversation, optionally until a specific time.
  Future<void> setMute(
    String conversationId, {
    required bool muted,
    DateTime? until,
  });

  /// Returns a reactive stream of all conversations.
  Stream<List<Conversation>> watchConversations();
}
