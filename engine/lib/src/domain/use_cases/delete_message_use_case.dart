import 'package:chat_engine/src/domain/repositories/message_repository.dart';

/// Deletes a message locally or for everyone.
///
/// Delete-for-everyone is constrained by a time window (1 hour 8 minutes,
/// matching WhatsApp). The server broadcast for remote deletion is handled
/// by the transport layer, not by this use case.
class DeleteMessageUseCase {
  /// Creates a [DeleteMessageUseCase].
  DeleteMessageUseCase({required MessageRepository messageRepo})
      : _messageRepo = messageRepo;

  final MessageRepository _messageRepo;

  /// Maximum time after sending during which delete-for-everyone is allowed.
  static const Duration deleteForEveryoneWindow =
      Duration(hours: 1, minutes: 8);

  /// Marks a message as deleted locally. The message remains in the
  /// database but is hidden from the UI.
  Future<void> deleteForMe(String messageId) async {
    await _messageRepo.markDeleted(messageId, forEveryone: false);
  }

  /// Marks a message as deleted for all participants.
  ///
  /// Throws [StateError] if the message is not found or if the
  /// delete-for-everyone time window has elapsed.
  Future<void> deleteForEveryone(String messageId) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message == null) {
      throw StateError('Message not found: $messageId');
    }

    final elapsed = DateTime.now().difference(message.timestamp);
    if (elapsed > deleteForEveryoneWindow) {
      throw StateError(
        'Cannot delete for everyone -- message is too old '
        '(${elapsed.inMinutes} minutes, limit is '
        '${deleteForEveryoneWindow.inMinutes} minutes)',
      );
    }

    await _messageRepo.markDeleted(messageId, forEveryone: true);
  }
}
