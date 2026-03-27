import 'package:hello_engine/src/domain/models/conversation.dart';

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
  Future<void> updateUnreadCount(String groupId, int count);

  /// Pins or unpins a conversation.
  Future<void> setPin(String groupId, {required bool pinned});

  /// Archives or unarchives a conversation.
  Future<void> setArchive(String groupId, {required bool archived});

  /// Mutes or unmutes a conversation, optionally until a specific time.
  Future<void> setMute(
    String groupId, {
    required bool muted,
    DateTime? until,
  });

  /// Returns a reactive stream of all conversations.
  Stream<List<Conversation>> watchConversations();
}
