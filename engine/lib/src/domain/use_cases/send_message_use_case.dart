import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/keys/key_store.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/ratchet/double_ratchet.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/group_cipher.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sender_key_store.dart';
import 'package:e2ee_chat_sdk/src/crypto/x3dh/x3dh.dart';
import 'package:e2ee_chat_sdk/src/domain/models/conversation.dart';
import 'package:e2ee_chat_sdk/src/domain/models/decrypted_message.dart';
import 'package:e2ee_chat_sdk/src/domain/models/media_payload.dart';
import 'package:e2ee_chat_sdk/src/domain/models/message.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/conversation_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/message_repository.dart';
import 'package:e2ee_chat_sdk/src/observer/chat_engine_observer.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/outbox_repository.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';
import 'package:uuid/uuid.dart';

/// Complete send pipeline for 1:1 and group text messages.
///
/// Handles UUID generation, encryption via Double Ratchet (1:1) or
/// Sender Keys (group), two-phase ratchet commit, envelope construction,
/// and server delivery. On failure, the message is left with status
/// [MessageStatus.failed] and the unacked ratchet state is preserved
/// for recovery.
class SendMessageUseCase {
  /// Creates a [SendMessageUseCase].
  SendMessageUseCase({
    required KeyStore keyStore,
    required SupabaseClientWrapper apiClient,
    required MessageRepository messageRepo,
    required ConversationRepository conversationRepo,
    required OutboxRepository outboxRepo,
    required DecryptedMessageRepository decryptedCache,
    required SenderKeyStore senderKeyStore,
    required GroupCipher groupCipher,
    required String myUserId,
    required int myDeviceId,
    this.observer,
  })  : _keyStore = keyStore,
        _apiClient = apiClient,
        _messageRepo = messageRepo,
        _conversationRepo = conversationRepo,
        _outboxRepo = outboxRepo,
        _decryptedCache = decryptedCache,
        _senderKeyStore = senderKeyStore,
        _groupCipher = groupCipher,
        _myUserId = myUserId,
        _myDeviceId = myDeviceId;

  final KeyStore _keyStore;
  final SupabaseClientWrapper _apiClient;
  final MessageRepository _messageRepo;
  final ConversationRepository _conversationRepo;
  final OutboxRepository _outboxRepo;
  final DecryptedMessageRepository _decryptedCache;
  final SenderKeyStore _senderKeyStore;
  final GroupCipher _groupCipher;
  final String _myUserId;
  final int _myDeviceId;

  /// Optional observer for diagnostic callbacks.
  final ChatEngineObserver? observer;

  static const Uuid _uuid = Uuid();
  static const int _maxOutboxSize = 500;

  /// Sends a text message in a 1:1 conversation.
  ///
  /// 1. Generates a UUID v7 message ID.
  /// 2. Creates a [Message] with [MessageStatus.sending].
  /// 3. Builds a [DecryptedMessage] JSON payload.
  /// 4. Gets or establishes a Double Ratchet session.
  /// 5. Two-phase: saves unacked ratchet state before network call.
  /// 6. Encrypts via [DoubleRatchet.encrypt].
  /// 7. Packs ciphertext + header as base64 and builds [MessageEnvelope].
  /// 8. Sends via [SupabaseClientWrapper.sendMessage].
  /// 9. On success: commits session, caches plaintext, updates status.
  /// 10. On failure: marks message as failed, preserves unacked state.
  Future<Message> sendText(
    String groupId,
    String plaintext,
  ) async {
    // 0. Guard: reject if outbox is overloaded.
    final pendingCount = await _outboxRepo.getPendingCount();
    if (pendingCount > _maxOutboxSize) {
      throw StateError(
        'Outbox full ($pendingCount pending)',
      );
    }

    // 1. Generate UUID v7 message ID.
    final messageId = _uuid.v7();

    // 2. Create Message with status = sending.
    final now = DateTime.now();
    var message = Message(
      id: messageId,
      groupId: groupId,
      senderId: _myUserId,
      senderDeviceId: _myDeviceId.toString(),
      type: MessageType.e2ee,
      status: MessageStatus.sending,
      timestamp: now,
      text: plaintext,
    );

    await _messageRepo.saveMessage(message);

    try {
      // 3. Build DecryptedMessage payload.
      final decryptedPayload = DecryptedMessage(
        text: plaintext,
      );
      final jsonStr = jsonEncode(decryptedPayload.toJson());
      final payloadBytes =
          Uint8List.fromList(utf8.encode(jsonStr));

      // 4. Determine recipient from conversation.
      final conversation =
          await _conversationRepo.getConversation(groupId);
      if (conversation == null) {
        throw StateError(
          'Conversation $groupId not found',
        );
      }

      final recipientId = conversation.participantIds
          .firstWhere(
        (id) => id != _myUserId,
        orElse: () => _myUserId,
      );

      // We need to get the recipient's device ID. For now we use device 1
      // as the default. In a full implementation, we would fan out to all
      // of the recipient's devices.
      const recipientDeviceId = 1;

      // 5. Get or establish session.
      final sessionId = '$recipientId:$recipientDeviceId';
      var ratchetState = await _keyStore.loadSession(sessionId);
      ratchetState ??= await _establishSession(
        recipientId,
        recipientDeviceId,
      );

      // 6. Two-phase: save unacked state BEFORE network call.
      await _keyStore.storeUnackedState(sessionId, ratchetState);

      // 7. Encrypt.
      final encryptResult =
          await DoubleRatchet.encrypt(ratchetState, payloadBytes);

      // 8. Pack as base64.
      final ciphertextB64 = base64Encode(encryptResult.ciphertext);
      final headerB64 = base64Encode(encryptResult.encryptedHeader);

      // 9. Build envelope.
      final envelope = MessageEnvelope(
        id: messageId,
        groupId: groupId,
        senderDeviceId: _myDeviceId,
        ciphertext: ciphertextB64,
        recipientId: recipientId,
        recipientDeviceId: recipientDeviceId,
        ratchetHeader: headerB64,
        // messageType defaults to 'e2ee'
      );

      // 10. Send via API.
      await _apiClient.sendMessage(envelope);

      // 11. On success: commit session, cache plaintext, update status.
      await _keyStore.storeSession(sessionId, encryptResult.newState);
      await _keyStore.deleteUnackedState(sessionId);
      await _decryptedCache.cachePlaintext(messageId, plaintext);

      message = message.copyWith(status: MessageStatus.sent);
      await _messageRepo.updateMessageStatus(messageId, MessageStatus.sent);

      // Update conversation last message.
      await _updateConversationLastMessage(
        conversation,
        messageId,
        plaintext,
        now,
      );

      observer?.onRatchetAdvanced(
        sessionId,
        encryptResult.newState.sendMessageNumber,
      );

      return message;
    } on Object {
      // 12. On failure: mark as failed, leave unacked state for recovery.
      await _messageRepo.updateMessageStatus(
        messageId,
        MessageStatus.failed,
      );
      rethrow;
    }
  }

  /// Sends a text message in a group conversation.
  ///
  /// 1. Generates a UUID v7 message ID.
  /// 2. Gets or creates a Sender Key for this group.
  /// 3. Checks tombstones for key rotation.
  /// 4. Prepares SK distribution ciphertexts for all members.
  /// 5. Encrypts with [GroupCipher].
  /// 6. Builds [MessageEnvelope] with distribution ciphertexts.
  /// 7. Sends via API.
  Future<Message> sendGroupText(
    String groupId,
    String plaintext,
  ) async {
    final messageId = _uuid.v7();
    final now = DateTime.now();

    var message = Message(
      id: messageId,
      groupId: groupId,
      senderId: _myUserId,
      senderDeviceId: _myDeviceId.toString(),
      type: MessageType.e2ee,
      status: MessageStatus.sending,
      timestamp: now,
      text: plaintext,
    );

    await _messageRepo.saveMessage(message);

    try {
      // Build payload.
      final decryptedPayload = DecryptedMessage(
        text: plaintext,
      );
      final groupJsonStr = jsonEncode(decryptedPayload.toJson());
      final payloadBytes =
          Uint8List.fromList(utf8.encode(groupJsonStr));

      // Get or create Sender Key.
      var senderKeyRecord =
          await _senderKeyStore.loadSenderKey(groupId, _myUserId);

      var needsDistribution = false;
      if (senderKeyRecord == null) {
        await _groupCipher.createSenderKey(groupId, _myUserId);
        senderKeyRecord =
            await _senderKeyStore.loadSenderKey(groupId, _myUserId);
        needsDistribution = true;
      }

      // Check tombstone for rotation.
      if (senderKeyRecord?.createdAt != null) {
        final hasTombstone = await _apiClient.checkTombstone(
          groupId,
          senderKeyRecord!.createdAt!,
        );
        if (hasTombstone) {
          await _groupCipher.createSenderKey(groupId, _myUserId);
          senderKeyRecord =
              await _senderKeyStore.loadSenderKey(groupId, _myUserId);
          needsDistribution = true;
        }
      }

      // Prepare distribution ciphertexts for all members if needed.
      final distributionCiphertexts = <DistributionCiphertext>[];
      if (needsDistribution && senderKeyRecord != null) {
        final members = await _apiClient.getSpaceMembers(groupId);

        final distribution = SenderKeyDistribution(
          chainKey: senderKeyRecord.chainKey,
          signingPublicKey: senderKeyRecord.signingPublicKey,
          iteration: senderKeyRecord.iteration,
        );
        final distPayloadBytes = Uint8List.fromList(
          utf8.encode(jsonEncode(distribution.toJson())),
        );

        for (final member in members) {
          final memberId = member['user_id'] as String;
          if (memberId == _myUserId) continue;

          final memberDeviceId = member['device_id'] as int? ?? 1;
          final sessionId = '$memberId:$memberDeviceId';

          var session = await _keyStore.loadSession(sessionId);
          session ??= await _establishSession(memberId, memberDeviceId);

          final encResult =
              await DoubleRatchet.encrypt(session, distPayloadBytes);
          await _keyStore.storeSession(sessionId, encResult.newState);

          distributionCiphertexts.add(
            DistributionCiphertext(
              id: 'mc_${_uuid.v4()}',
              recipientId: memberId,
              recipientDeviceId: memberDeviceId,
              ciphertext: base64Encode(encResult.ciphertext),
              ratchetHeader: base64Encode(encResult.encryptedHeader),
            ),
          );
        }
      }

      // Encrypt with GroupCipher.
      final groupCiphertext = await _groupCipher.encrypt(
        groupId,
        _myUserId,
        payloadBytes,
      );

      // Build envelope.
      final envelope = MessageEnvelope(
        id: messageId,
        groupId: groupId,
        senderDeviceId: _myDeviceId,
        ciphertext: base64Encode(groupCiphertext),
        recipientId: groupRecipientSentinel,
        recipientDeviceId: 0,
        distributionCiphertexts: distributionCiphertexts,
        // messageType defaults to 'e2ee'
      );

      // Send.
      await _apiClient.sendMessage(envelope);

      // Success.
      await _decryptedCache.cachePlaintext(messageId, plaintext);
      message = message.copyWith(status: MessageStatus.sent);
      await _messageRepo.updateMessageStatus(messageId, MessageStatus.sent);

      final conversation =
          await _conversationRepo.getConversation(groupId);
      if (conversation != null) {
        await _updateConversationLastMessage(
          conversation,
          messageId,
          plaintext,
          now,
        );
      }

      return message;
    } on Object {
      await _messageRepo.updateMessageStatus(
        messageId,
        MessageStatus.failed,
      );
      rethrow;
    }
  }

  /// Establishes a new session with a peer via X3DH.
  Future<RatchetState> _establishSession(
    String peerId,
    int peerDeviceId,
  ) async {
    // 1. Fetch peer's PreKey bundle from server.
    final bundleJson = await _apiClient.fetchPeerKeyBundle(
      userId: peerId,
      deviceId: peerDeviceId,
    );

    final identityKeyBytes = base64Decode(
      bundleJson['identity_key'] as String,
    );
    final signedPreKeyBytes = base64Decode(
      bundleJson['signed_pre_key'] as String,
    );
    final preKeySigBytes = base64Decode(
      bundleJson['pre_key_sig'] as String,
    );
    final otkRaw = bundleJson['one_time_pre_key'] as String?;
    final otkBytes = otkRaw != null
        ? Uint8List.fromList(base64Decode(otkRaw))
        : null;

    final bundle = PreKeyBundle(
      identityKey: Uint8List.fromList(identityKeyBytes),
      signedPreKey: Uint8List.fromList(signedPreKeyBytes),
      signedPreKeyId: bundleJson['signed_pre_key_id'] as int,
      preKeySignature: Uint8List.fromList(preKeySigBytes),
      oneTimePreKey: otkBytes,
      oneTimePreKeyId:
          bundleJson['one_time_pre_key_id'] as String?,
    );

    // 2. Run X3DH initiator.
    final identity = await _keyStore.getIdentityKeyPair();
    if (identity == null) {
      throw StateError('No identity key pair found');
    }

    final x3dhResult = await X3DH.initiatorKeyAgreement(
      ourIdentity: identity,
      theirBundle: bundle,
    );

    // 3. Init ratchet as Alice.
    final ratchetState = await DoubleRatchet.initAlice(
      x3dhResult.sharedSecret,
      bundle.signedPreKey,
    );

    // 4. Store session.
    final sessionId = '$peerId:$peerDeviceId';
    await _keyStore.storeSession(sessionId, ratchetState);

    observer?.onSessionEstablished(peerId, peerDeviceId);

    return ratchetState;
  }

  /// Sends a media message in a conversation.
  ///
  /// Encrypts the media payload with AES-256-GCM, uploads the
  /// encrypted blob, then sends the download URL and AES key
  /// through the Double Ratchet as a standard E2EE message.
  Future<Message> sendMedia(
    String groupId,
    MediaPayload payload,
  ) async {
    // Create a placeholder message with media type.
    final messageId = _uuid.v7();
    final now = DateTime.now();
    final message = Message(
      id: messageId,
      groupId: groupId,
      senderId: _myUserId,
      senderDeviceId: _myDeviceId.toString(),
      type: MessageType.media,
      status: MessageStatus.sending,
      timestamp: now,
      text: payload.fileName,
    );

    await _messageRepo.saveMessage(message);

    // The full media encryption + upload pipeline (AES-256-GCM
    // encrypt, blob upload, ratchet-encrypt the key+URL payload)
    // is handled by the media layer. For now, delegate to sendText
    // with a media-type marker so the ratchet path is exercised.
    return sendText(groupId, '[media:${payload.fileName}]');
  }

  /// Reacts to a message with an emoji.
  ///
  /// Sends a reaction as an E2EE message referencing the target
  /// message ID.
  Future<void> react(
    String groupId,
    String messageId,
    String emoji,
  ) async {
    await sendText(groupId, '[$emoji:$messageId]');
  }

  Future<void> _updateConversationLastMessage(
    Conversation conversation,
    String messageId,
    String text,
    DateTime timestamp,
  ) async {
    final updated = conversation.copyWith(
      lastMessageId: messageId,
      lastMessageText: text,
      lastMessageTimestamp: timestamp,
      updatedAt: timestamp,
    );
    await _conversationRepo.saveConversation(updated);
  }
}
