import 'package:e2ee_chat_sdk/src/domain/models/message.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/conversation_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/message_repository.dart';

/// Marks a message as read and resets the conversation unread count.
///
/// The caller (ChatSessionImpl) is responsible for sending the read
/// receipt to the server via the transport layer.
class MarkReadUseCase {
  /// Creates a [MarkReadUseCase].
  MarkReadUseCase({
    required MessageRepository messageRepo,
    required ConversationRepository conversationRepo,
  })  : _messageRepo = messageRepo,
        _conversationRepo = conversationRepo;

  final MessageRepository _messageRepo;
  final ConversationRepository _conversationRepo;

  /// Marks [messageId] as read and resets unread count for
  /// [groupId] to zero.
  Future<void> markRead(String messageId, String groupId) async {
    await _messageRepo.updateMessageStatus(messageId, MessageStatus.read);
    await _conversationRepo.updateUnreadCount(groupId, 0);
  }
}
