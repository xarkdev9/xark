import 'package:chat_engine/src/domain/models/key_fingerprint.dart';
import 'package:chat_engine/src/domain/models/media_payload.dart';
import 'package:chat_engine/src/domain/models/message.dart';
import 'package:chat_engine/src/domain/models/presence_state.dart';
import 'package:chat_engine/src/domain/models/receipt.dart';
import 'package:chat_engine/src/domain/models/typing_indicator.dart';

/// Per-conversation session handle.
///
/// Provides streams for observing messages, typing indicators,
/// receipts, and presence. Provides methods for sending messages,
/// marking read, reacting, and deleting.
///
/// Obtain an instance via `ChatEngine.getSession`.
// ignore: one_member_abstracts
abstract class ChatSession {
  /// Decrypted messages for this conversation, ordered by timestamp.
  Stream<List<Message>> get messages;

  /// Current typing indicators for this conversation.
  Stream<List<TypingIndicator>> get typing;

  /// Delivery and read receipts for this conversation.
  Stream<List<Receipt>> get receipts;

  /// Presence state (1:1 only).
  Stream<PresenceState> get presence;

  /// Send a text message.
  Future<Message> sendText(String plaintext);

  /// Send a media message.
  Future<Message> sendMedia(MediaPayload payload);

  /// Send a typing indicator.
  Future<void> sendTyping();

  /// Mark a message as read.
  Future<void> markRead(String messageId);

  /// React to a message with an emoji.
  Future<void> react(String messageId, String emoji);

  /// Delete a message locally only.
  Future<void> deleteForMe(String messageId);

  /// Delete a message for all participants.
  Future<void> deleteForEveryone(String messageId);

  /// Load more (older) messages for pagination.
  Future<List<Message>> loadMore({int limit = 50});

  /// Get the key fingerprint for safety number verification.
  Future<KeyFingerprint> getKeyFingerprint();
}
