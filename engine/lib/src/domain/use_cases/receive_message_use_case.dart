import 'dart:convert';
import 'dart:typed_data';

import 'package:chat_engine/src/crypto/keys/key_store.dart';
import 'package:chat_engine/src/crypto/keys/key_types.dart';
import 'package:chat_engine/src/crypto/ratchet/double_ratchet.dart';
import 'package:chat_engine/src/crypto/sender_keys/group_cipher.dart';
import 'package:chat_engine/src/domain/models/decrypted_message.dart';
import 'package:chat_engine/src/domain/models/message.dart';
import 'package:chat_engine/src/domain/repositories/conversation_repository.dart';
import 'package:chat_engine/src/domain/repositories/message_repository.dart';
import 'package:chat_engine/src/observer/chat_engine_observer.dart';
import 'package:chat_engine/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:chat_engine/src/persistence/repositories/processed_distribution_repository.dart';
import 'package:chat_engine/src/transport/dto/message_envelope.dart';

/// Decrypts and processes incoming messages.
///
/// Called by the sync layer when a new message arrives. Handles
/// both 1:1 (Double Ratchet) and group (Sender Keys) messages, as
/// well as sender key distribution messages.
class ReceiveMessageUseCase {
  /// Creates a [ReceiveMessageUseCase].
  ReceiveMessageUseCase({
    required KeyStore keyStore,
    required MessageRepository messageRepo,
    required ConversationRepository conversationRepo,
    required DecryptedMessageRepository decryptedCache,
    required ProcessedDistributionRepository processedDistRepo,
    required GroupCipher groupCipher,
    required String myUserId,
    required int myDeviceId,
    this.observer,
  })  : _keyStore = keyStore,
        _messageRepo = messageRepo,
        _conversationRepo = conversationRepo,
        _decryptedCache = decryptedCache,
        _processedDistRepo = processedDistRepo,
        _groupCipher = groupCipher,
        _myUserId = myUserId,
        _myDeviceId = myDeviceId;

  final KeyStore _keyStore;
  final MessageRepository _messageRepo;
  final ConversationRepository _conversationRepo;
  final DecryptedMessageRepository _decryptedCache;
  final ProcessedDistributionRepository _processedDistRepo;
  final GroupCipher _groupCipher;
  final String _myUserId;
  final int _myDeviceId;

  /// Optional observer for diagnostic callbacks.
  final ChatEngineObserver? observer;

  /// Decrypts and processes a received message.
  ///
  /// Returns the created [Message] domain object, or `null` if the
  /// message was a sender key distribution (no user-visible content).
  ///
  /// Parameters:
  /// - [messageId]: Server-assigned message row ID.
  /// - [spaceId]: Conversation (space) this message belongs to.
  /// - [senderId]: User ID of the sender.
  /// - [senderDeviceId]: Device ID of the sender.
  /// - [messageType]: Wire-level type (`e2ee`, `sender_key_dist`).
  /// - [createdAt]: Server-side creation timestamp.
  /// - [ciphertextData]: Map containing `ciphertext`, `ratchet_header`,
  ///   and `recipient_id`.
  Future<Message?> processReceivedMessage({
    required String messageId,
    required String spaceId,
    required String senderId,
    required int? senderDeviceId,
    required String messageType,
    required DateTime createdAt,
    required Map<String, dynamic> ciphertextData,
  }) async {
    // 1. Skip our own messages.
    if (senderId == _myUserId &&
        senderDeviceId == _myDeviceId) {
      return null;
    }

    // 2. Check plaintext cache.
    final cached = await _decryptedCache.getCachedPlaintext(messageId);
    if (cached != null) {
      return null;
    }

    final ciphertextB64 = ciphertextData['ciphertext'] as String;
    final ratchetHeaderB64 = ciphertextData['ratchet_header'] as String?;
    final recipientId = ciphertextData['recipient_id'] as String? ?? '';
    final isGroupMessage = recipientId == groupRecipientSentinel;

    // 2. Handle sender key distribution.
    if (messageType == 'sender_key_dist') {
      return _processSenderKeyDistribution(
        messageId: messageId,
        spaceId: spaceId,
        senderId: senderId,
        senderDeviceId: senderDeviceId ?? 1,
        ciphertextB64: ciphertextB64,
        ratchetHeaderB64: ratchetHeaderB64,
      );
    }

    // 3. Decrypt based on message type.
    Uint8List plainBytes;

    if (isGroupMessage) {
      // Group: decrypt with GroupCipher.
      final ciphertextBytes = base64Decode(ciphertextB64);
      plainBytes = await _groupCipher.decrypt(
        spaceId,
        senderId,
        Uint8List.fromList(ciphertextBytes),
      );
    } else {
      // 1:1: decrypt with Double Ratchet.
      final deviceId = senderDeviceId ?? 1;
      final sessionId = '$senderId:$deviceId';

      var ratchetState = await _keyStore.loadSession(sessionId);
      if (ratchetState == null) {
        throw StateError('No ratchet session found for $sessionId');
      }

      final ciphertextBytes = base64Decode(ciphertextB64);
      final headerBytes = ratchetHeaderB64 != null
          ? base64Decode(ratchetHeaderB64)
          : Uint8List(0);

      final decryptResult = await DoubleRatchet.decrypt(
        ratchetState,
        Uint8List.fromList(ciphertextBytes),
        Uint8List.fromList(headerBytes),
      );

      plainBytes = decryptResult.plaintext;
      ratchetState = decryptResult.newState;

      // Persist updated ratchet state.
      await _keyStore.storeSession(sessionId, ratchetState);

      observer?.onRatchetAdvanced(
        sessionId,
        ratchetState.recvMessageNumber,
      );
    }

    // 4. Parse DecryptedMessage from JSON.
    final plainJson =
        jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
    final decrypted = DecryptedMessage.fromJson(plainJson);

    // 5. Determine MessageType from decrypted content type.
    final domainType =
        decrypted.type == 'media' ? MessageType.media : MessageType.e2ee;

    // 6. Create Message domain object.
    final message = Message(
      id: messageId,
      conversationId: spaceId,
      senderId: senderId,
      senderDeviceId: (senderDeviceId ?? 1).toString(),
      type: domainType,
      status: MessageStatus.delivered,
      timestamp: createdAt,
      text: decrypted.text,
      replyToMessageId: decrypted.replyTo,
    );

    // 7. Save to MessageRepository.
    await _messageRepo.saveMessage(message);

    // 8. Cache plaintext.
    await _decryptedCache.cachePlaintext(messageId, decrypted.text);

    // 9. Update conversation unread count.
    final conversation = await _conversationRepo.getConversation(spaceId);
    if (conversation != null) {
      final updated = conversation.copyWith(
        lastMessageId: messageId,
        lastMessageText: decrypted.text,
        lastMessageTimestamp: createdAt,
        updatedAt: createdAt,
        unreadCount: conversation.unreadCount + 1,
      );
      await _conversationRepo.saveConversation(updated);
    }

    return message;
  }

  /// Processes a sender key distribution message.
  ///
  /// Decrypts the distribution via the 1:1 Double Ratchet channel,
  /// then stores the Sender Key for the sender. Returns `null` since
  /// distribution messages have no user-visible content.
  Future<Message?> _processSenderKeyDistribution({
    required String messageId,
    required String spaceId,
    required String senderId,
    required int senderDeviceId,
    required String ciphertextB64,
    required String? ratchetHeaderB64,
  }) async {
    // Check if already processed.
    if (await _processedDistRepo.isProcessed(messageId)) {
      return null;
    }

    // Decrypt via 1:1 Double Ratchet.
    final sessionId = '$senderId:$senderDeviceId';
    var ratchetState = await _keyStore.loadSession(sessionId);
    if (ratchetState == null) {
      throw StateError(
        'No ratchet session for distribution from $sessionId',
      );
    }

    final ciphertextBytes = base64Decode(ciphertextB64);
    final headerBytes = ratchetHeaderB64 != null
        ? base64Decode(ratchetHeaderB64)
        : Uint8List(0);

    final decryptResult = await DoubleRatchet.decrypt(
      ratchetState,
      Uint8List.fromList(ciphertextBytes),
      Uint8List.fromList(headerBytes),
    );

    ratchetState = decryptResult.newState;
    await _keyStore.storeSession(sessionId, ratchetState);

    // Parse the SenderKeyDistribution from the decrypted payload.
    final distJson = jsonDecode(utf8.decode(decryptResult.plaintext))
        as Map<String, dynamic>;
    final distribution = SenderKeyDistribution.fromJson(distJson);

    // Store the sender key.
    await _groupCipher.processSenderKeyDistribution(
      spaceId,
      senderId,
      distribution,
    );

    // Mark as processed to avoid reprocessing.
    await _processedDistRepo.markProcessed(messageId);

    return null;
  }
}
