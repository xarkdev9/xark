import 'package:hello_engine/src/domain/models/key_fingerprint.dart';
import 'package:hello_engine/src/domain/models/media_payload.dart';
import 'package:hello_engine/src/domain/models/message.dart';
import 'package:hello_engine/src/domain/models/presence_state.dart';
import 'package:hello_engine/src/domain/models/receipt.dart';
import 'package:hello_engine/src/domain/models/typing_indicator.dart';
import 'package:hello_engine/src/domain/repositories/message_repository.dart';
import 'package:hello_engine/src/domain/repositories/receipt_repository.dart';
import 'package:hello_engine/src/domain/use_cases/delete_message_use_case.dart';
import 'package:hello_engine/src/domain/use_cases/mark_read_use_case.dart';
import 'package:hello_engine/src/domain/use_cases/send_message_use_case.dart';
import 'package:hello_engine/src/public_api/chat_session.dart';
import 'package:hello_engine/src/sync/sync_coordinator.dart';

/// Internal implementation of a per-conversation session handle.
///
/// Exposes streams for messages, typing indicators, and receipts,
/// and delegates actions to the appropriate use cases. This class
/// is internal to the engine -- external code accesses it through
/// the public API types.
class ChatSessionImpl implements ChatSession {
  /// Creates a [ChatSessionImpl].
  ChatSessionImpl({
    required String groupId,
    required SendMessageUseCase sendUseCase,
    required MarkReadUseCase markReadUseCase,
    required DeleteMessageUseCase deleteUseCase,
    required MessageRepository messageRepo,
    required ReceiptRepository receiptRepo,
    required SyncCoordinator syncCoordinator,
  })  : _groupId = groupId,
        _sendUseCase = sendUseCase,
        _markReadUseCase = markReadUseCase,
        _deleteUseCase = deleteUseCase,
        _messageRepo = messageRepo,
        _receiptRepo = receiptRepo,
        _syncCoordinator = syncCoordinator;

  final String _groupId;
  final SendMessageUseCase _sendUseCase;
  final MarkReadUseCase _markReadUseCase;
  final DeleteMessageUseCase _deleteUseCase;
  final MessageRepository _messageRepo;
  final ReceiptRepository _receiptRepo;
  final SyncCoordinator _syncCoordinator;

  /// The conversation ID this session manages.
  String get groupId => _groupId;

  @override
  Stream<List<Message>> get messages =>
      _messageRepo.watchMessages(_groupId);

  @override
  Stream<List<TypingIndicator>> get typing => _syncCoordinator.typingEvents
      .where((e) => e.groupId == _groupId)
      .map((e) => [e]);

  @override
  Stream<List<Receipt>> get receipts =>
      _receiptRepo.watchReceipts(_groupId);

  @override
  Stream<PresenceState> get presence =>
      _syncCoordinator.presenceEvents.where(
        (e) => e.userId != _groupId,
      );

  @override
  Future<Message> sendText(String plaintext) =>
      _sendUseCase.sendText(_groupId, plaintext);

  /// Sends a text message in this group conversation.
  Future<Message> sendGroupText(String plaintext) =>
      _sendUseCase.sendGroupText(_groupId, plaintext);

  @override
  Future<Message> sendMedia(MediaPayload payload) =>
      _sendUseCase.sendMedia(_groupId, payload);

  @override
  Future<void> sendTyping() =>
      _syncCoordinator.sendTyping(_groupId);

  @override
  Future<void> markRead(String messageId) =>
      _markReadUseCase.markRead(messageId, _groupId);

  @override
  Future<void> react(String messageId, String emoji) =>
      _sendUseCase.react(_groupId, messageId, emoji);

  @override
  Future<void> deleteForMe(String messageId) =>
      _deleteUseCase.deleteForMe(messageId);

  @override
  Future<void> deleteForEveryone(String messageId) =>
      _deleteUseCase.deleteForEveryone(messageId);

  @override
  Future<List<Message>> loadMore({int limit = 50}) =>
      _messageRepo.getMessages(_groupId, limit: limit);

  @override
  Future<KeyFingerprint> getKeyFingerprint() async {
    // Compute a fingerprint from the local identity key material
    // for safety number verification.
    final identityKeyBytes = await _syncCoordinator
        .getIdentityKeyForConversation(_groupId);
    return KeyFingerprint(
      userId: _groupId,
      deviceId: _groupId,
      fingerprintBytes: identityKeyBytes,
    );
  }
}
