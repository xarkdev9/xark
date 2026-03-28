// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/chat_session_impl.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_store.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/ratchet/double_ratchet.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/group_cipher.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sender_key_store.dart';
import 'package:e2ee_chat_sdk/src/domain/models/conversation.dart';
import 'package:e2ee_chat_sdk/src/domain/models/message.dart';
import 'package:e2ee_chat_sdk/src/domain/models/receipt.dart';
import 'package:e2ee_chat_sdk/src/domain/models/typing_indicator.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/conversation_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/message_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/receipt_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/delete_message_use_case.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/mark_read_use_case.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/receive_message_use_case.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/send_message_use_case.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/outbox_repository.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/processed_distribution_repository.dart';
import 'package:e2ee_chat_sdk/src/public_api/chat_engine_config.dart';
import 'package:e2ee_chat_sdk/src/sync/sync_coordinator.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockKeyStore extends Mock implements KeyStore {}

class MockSupabaseClientWrapper extends Mock
    implements SupabaseClientWrapper {}

class MockMessageRepository extends Mock implements MessageRepository {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

class MockReceiptRepository extends Mock implements ReceiptRepository {}

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockDecryptedMessageRepository extends Mock
    implements DecryptedMessageRepository {}

class MockSenderKeyStore extends Mock implements SenderKeyStore {}

class MockGroupCipher extends Mock implements GroupCipher {}

class MockSyncCoordinator extends Mock implements SyncCoordinator {}

class MockProcessedDistributionRepository extends Mock
    implements ProcessedDistributionRepository {}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeMessage extends Fake implements Message {}

class FakeMessageEnvelope extends Fake implements MessageEnvelope {}

class FakeRatchetState extends Fake implements RatchetState {}

class FakeConversation extends Fake implements Conversation {}

class FakeSenderKeyDistribution extends Fake
    implements SenderKeyDistribution {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _myUserId = 'user_alice';
const _myDeviceId = 1;
const _peerId = 'user_bob';
const _groupId = 'conv-001';

Conversation _makeConversation({
  String id = _groupId,
  ConversationType type = ConversationType.oneToOne,
  List<String> participants = const [_myUserId, _peerId],
}) {
  final now = DateTime.utc(2026, 3, 26);
  return Conversation(
    id: id,
    type: type,
    participantIds: participants,
    createdAt: now,
    updatedAt: now,
  );
}

Message _makeMessage({
  String id = 'msg-001',
  String groupId = _groupId,
  String senderId = _peerId,
  MessageStatus status = MessageStatus.delivered,
  DateTime? timestamp,
}) {
  return Message(
    id: id,
    groupId: groupId,
    senderId: senderId,
    senderDeviceId: '1',
    type: MessageType.e2ee,
    status: status,
    timestamp: timestamp ?? DateTime.now(),
    text: 'Hello',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockKeyStore keyStore;
  late MockSupabaseClientWrapper apiClient;
  late MockMessageRepository messageRepo;
  late MockConversationRepository conversationRepo;
  late MockOutboxRepository outboxRepo;
  late MockDecryptedMessageRepository decryptedCache;
  late MockSenderKeyStore senderKeyStore;
  late MockGroupCipher groupCipher;
  late MockProcessedDistributionRepository processedDistRepo;

  setUpAll(() {
    registerFallbackValue(FakeMessage());
    registerFallbackValue(FakeMessageEnvelope());
    registerFallbackValue(FakeRatchetState());
    registerFallbackValue(FakeConversation());
    registerFallbackValue(FakeSenderKeyDistribution());
    registerFallbackValue(MessageStatus.sending);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    keyStore = MockKeyStore();
    apiClient = MockSupabaseClientWrapper();
    messageRepo = MockMessageRepository();
    conversationRepo = MockConversationRepository();
    outboxRepo = MockOutboxRepository();
    decryptedCache = MockDecryptedMessageRepository();
    senderKeyStore = MockSenderKeyStore();
    groupCipher = MockGroupCipher();
    processedDistRepo = MockProcessedDistributionRepository();
  });

  // =========================================================================
  // SendMessageUseCase
  // =========================================================================

  group('SendMessageUseCase', () {
    late SendMessageUseCase sendUseCase;

    setUp(() {
      sendUseCase = SendMessageUseCase(
        keyStore: keyStore,
        apiClient: apiClient,
        messageRepo: messageRepo,
        conversationRepo: conversationRepo,
        outboxRepo: outboxRepo,
        decryptedCache: decryptedCache,
        senderKeyStore: senderKeyStore,
        groupCipher: groupCipher,
        myUserId: _myUserId,
        myDeviceId: _myDeviceId,
      );
    });

    test(
        'sendText creates Message with status=sending '
        'and saves it', () async {
      // Arrange: outbox not full.
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);

      // Conversation lookup.
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      // Session lookup: existing session.
      final sharedSecret = Uint8List(32);
      final bobPub = Uint8List(32);
      final ratchetState = await _createDummyRatchetState(
        sharedSecret,
        bobPub,
      );
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => ratchetState);
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.deleteUnackedState(any()))
          .thenAnswer((_) async {});

      // Save message.
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(
        () => messageRepo.updateMessageStatus(any(), any()),
      ).thenAnswer((_) async {});

      // Send message.
      when(() => apiClient.sendMessage(any()))
          .thenAnswer((_) async => <String, dynamic>{});

      // Cache plaintext.
      when(
        () => decryptedCache.cachePlaintext(any(), any()),
      ).thenAnswer((_) async {});

      // Save conversation.
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      // Act.
      final result = await sendUseCase.sendText(
        _groupId,
        'Hello Bob!',
      );

      // Assert: message was saved with status=sending initially.
      final captured = verify(
        () => messageRepo.saveMessage(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final savedMsg = captured.first as Message;
      expect(savedMsg.status, MessageStatus.sending);
      expect(savedMsg.senderId, _myUserId);
      expect(savedMsg.text, 'Hello Bob!');
      expect(savedMsg.groupId, _groupId);

      // Assert: final result has status=sent.
      expect(result.status, MessageStatus.sent);
    });

    test('sendText generates a valid UUID v7', () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      final sharedSecret = Uint8List(32);
      final bobPub = Uint8List(32);
      final ratchetState = await _createDummyRatchetState(
        sharedSecret,
        bobPub,
      );
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => ratchetState);
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.deleteUnackedState(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(
        () => messageRepo.updateMessageStatus(any(), any()),
      ).thenAnswer((_) async {});
      when(() => apiClient.sendMessage(any()))
          .thenAnswer((_) async => <String, dynamic>{});
      when(
        () => decryptedCache.cachePlaintext(any(), any()),
      ).thenAnswer((_) async {});
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      final result = await sendUseCase.sendText(
        _groupId,
        'Test',
      );

      // UUID v7 format: 8-4-4-4-12 hexadecimal characters.
      expect(
        result.id,
        matches(
          RegExp(
            '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}'
            r'-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test(
        'sendText handles encryption failure gracefully '
        'by marking message as failed', () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      // Return a broken ratchet state that will fail to encrypt
      // (no send chain key).
      when(() => keyStore.loadSession(any())).thenAnswer(
        (_) async => RatchetState(
          rootKey: Uint8List(32),
          headerSecret: Uint8List(32),
          // No sendChainKey -- encrypt will fail.
        ),
      );
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(
        () => messageRepo.updateMessageStatus(any(), any()),
      ).thenAnswer((_) async {});

      // Act & Assert.
      await expectLater(
        sendUseCase.sendText(_groupId, 'Will fail'),
        throwsA(isA<StateError>()),
      );

      // Verify status was set to failed.
      verify(
        () => messageRepo.updateMessageStatus(
          any(),
          MessageStatus.failed,
        ),
      ).called(1);
    });

    test(
        'sendText throws when outbox is full '
        '(> 500 pending)', () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 501);

      await expectLater(
        sendUseCase.sendText(_groupId, 'Will fail'),
        throwsA(isA<StateError>()),
      );

      // Verify no message was saved.
      verifyNever(() => messageRepo.saveMessage(any()));
    });

    test(
        'sendText caches plaintext and updates '
        'conversation on success', () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      final sharedSecret = Uint8List(32);
      final bobPub = Uint8List(32);
      final ratchetState = await _createDummyRatchetState(
        sharedSecret,
        bobPub,
      );
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => ratchetState);
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.deleteUnackedState(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(
        () => messageRepo.updateMessageStatus(any(), any()),
      ).thenAnswer((_) async {});
      when(() => apiClient.sendMessage(any()))
          .thenAnswer((_) async => <String, dynamic>{});
      when(
        () => decryptedCache.cachePlaintext(any(), any()),
      ).thenAnswer((_) async {});
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      await sendUseCase.sendText(_groupId, 'Cached text');

      verify(
        () => decryptedCache.cachePlaintext(any(), 'Cached text'),
      ).called(1);
      verify(
        () => conversationRepo.saveConversation(any()),
      ).called(1);
    });
  });

  // =========================================================================
  // ReceiveMessageUseCase
  // =========================================================================

  group('ReceiveMessageUseCase', () {
    late ReceiveMessageUseCase receiveUseCase;

    setUp(() {
      receiveUseCase = ReceiveMessageUseCase(
        keyStore: keyStore,
        messageRepo: messageRepo,
        conversationRepo: conversationRepo,
        decryptedCache: decryptedCache,
        processedDistRepo: processedDistRepo,
        groupCipher: groupCipher,
        myUserId: _myUserId,
        myDeviceId: _myDeviceId,
      );
    });

    test(
        'processReceivedMessage creates domain Message '
        'from ciphertext data', () async {
      // Arrange: no cache hit.
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);

      // Build the decrypted payload that the ratchet will produce.
      final decryptedJson = jsonEncode({
        'text': 'Hello Alice!',
        'type': 'message',
      });
      final plainBytes = Uint8List.fromList(
        utf8.encode(decryptedJson),
      );

      // Create a proper Alice/Bob ratchet pair via X3DH.
      final session = await buildAliceBobSession();

      // Alice (sender) encrypts the payload.
      final encResult = await DoubleRatchet.encrypt(
        session.alice,
        plainBytes,
      );

      final ciphertextB64 = base64Encode(encResult.ciphertext);
      final headerB64 = base64Encode(
        encResult.encryptedHeader,
      );

      // Return Bob's state as the session for decryption.
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => session.bob);
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});

      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(
        () => decryptedCache.cachePlaintext(any(), any()),
      ).thenAnswer((_) async {});
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      // Act.
      final result =
          await receiveUseCase.processReceivedMessage(
        messageId: 'msg-in-001',
        groupId: _groupId,
        senderId: _peerId,
        senderDeviceId: 1,
        messageType: 'e2ee',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': ciphertextB64,
          'ratchet_header': headerB64,
          'recipient_id': _myUserId,
        },
      );

      // Assert.
      expect(result, isNotNull);
      expect(result!.id, 'msg-in-001');
      expect(result.text, 'Hello Alice!');
      expect(result.senderId, _peerId);
      expect(result.status, MessageStatus.delivered);
      expect(result.groupId, _groupId);
    });

    test(
        'processReceivedMessage returns null for '
        'own messages', () async {
      final result = await receiveUseCase.processReceivedMessage(
        messageId: 'msg-own',
        groupId: _groupId,
        senderId: _myUserId,
        senderDeviceId: _myDeviceId,
        messageType: 'e2ee',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': 'abc',
          'recipient_id': _peerId,
        },
      );

      expect(result, isNull);
    });

    test(
        'processReceivedMessage returns null when '
        'plaintext is cached', () async {
      when(() => decryptedCache.getCachedPlaintext('msg-cached'))
          .thenAnswer((_) async => 'already decrypted');

      final result = await receiveUseCase.processReceivedMessage(
        messageId: 'msg-cached',
        groupId: _groupId,
        senderId: _peerId,
        senderDeviceId: 2,
        messageType: 'e2ee',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': 'abc',
          'recipient_id': _myUserId,
        },
      );

      expect(result, isNull);
    });

    test(
        'processReceivedMessage increments '
        'conversation unread count', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);

      final decryptedJson = jsonEncode({
        'text': 'Bump unread!',
        'type': 'message',
      });
      final plainBytes = Uint8List.fromList(
        utf8.encode(decryptedJson),
      );

      // Proper Alice/Bob session via X3DH.
      final ratchetSession = await buildAliceBobSession();

      final encResult = await DoubleRatchet.encrypt(
        ratchetSession.alice,
        plainBytes,
      );

      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => ratchetSession.bob);
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(
        () => decryptedCache.cachePlaintext(any(), any()),
      ).thenAnswer((_) async {});

      final existingConv = _makeConversation();
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => existingConv);
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      await receiveUseCase.processReceivedMessage(
        messageId: 'msg-unread',
        groupId: _groupId,
        senderId: _peerId,
        senderDeviceId: 1,
        messageType: 'e2ee',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': base64Encode(
            encResult.ciphertext,
          ),
          'ratchet_header': base64Encode(
            encResult.encryptedHeader,
          ),
          'recipient_id': _myUserId,
        },
      );

      final captured = verify(
        () => conversationRepo.saveConversation(captureAny()),
      ).captured;
      final updatedConv = captured.first as Conversation;
      expect(updatedConv.unreadCount, 1);
    });
  });

  // =========================================================================
  // MarkReadUseCase
  // =========================================================================

  group('MarkReadUseCase', () {
    late MarkReadUseCase markReadUseCase;

    setUp(() {
      markReadUseCase = MarkReadUseCase(
        messageRepo: messageRepo,
        conversationRepo: conversationRepo,
      );
    });

    test('markRead updates message status to read', () async {
      when(
        () => messageRepo.updateMessageStatus(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => conversationRepo.updateUnreadCount(any(), any()),
      ).thenAnswer((_) async {});

      await markReadUseCase.markRead('msg-001', _groupId);

      verify(
        () => messageRepo.updateMessageStatus(
          'msg-001',
          MessageStatus.read,
        ),
      ).called(1);
    });

    test(
        'markRead resets conversation unread count '
        'to zero', () async {
      when(
        () => messageRepo.updateMessageStatus(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => conversationRepo.updateUnreadCount(any(), any()),
      ).thenAnswer((_) async {});

      await markReadUseCase.markRead('msg-001', _groupId);

      verify(
        () => conversationRepo.updateUnreadCount(
          _groupId,
          0,
        ),
      ).called(1);
    });
  });

  // =========================================================================
  // DeleteMessageUseCase
  // =========================================================================

  group('DeleteMessageUseCase', () {
    late DeleteMessageUseCase deleteUseCase;

    setUp(() {
      deleteUseCase = DeleteMessageUseCase(
        messageRepo: messageRepo,
      );
    });

    test(
        'deleteForMe marks message deleted locally', () async {
      when(
        () => messageRepo.markDeleted(
          any(),
          forEveryone: any(named: 'forEveryone'),
        ),
      ).thenAnswer((_) async {});

      await deleteUseCase.deleteForMe('msg-001');

      verify(
        () => messageRepo.markDeleted(
          'msg-001',
          forEveryone: false,
        ),
      ).called(1);
    });

    test(
        'deleteForEveryone rejects messages older '
        'than 1h8m', () async {
      final oldMessage = _makeMessage(
        timestamp: DateTime.now().subtract(
          Duration(hours: 2),
        ),
      );
      when(() => messageRepo.getMessageById('msg-001'))
          .thenAnswer((_) async => oldMessage);

      await expectLater(
        deleteUseCase.deleteForEveryone('msg-001'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('too old'),
          ),
        ),
      );
    });

    test(
        'deleteForEveryone succeeds for recent '
        'messages', () async {
      final recentMessage = _makeMessage(
        timestamp: DateTime.now().subtract(
          Duration(minutes: 5),
        ),
      );
      when(() => messageRepo.getMessageById('msg-recent'))
          .thenAnswer((_) async => recentMessage);
      when(
        () => messageRepo.markDeleted(
          any(),
          forEveryone: any(named: 'forEveryone'),
        ),
      ).thenAnswer((_) async {});

      await deleteUseCase.deleteForEveryone('msg-recent');

      verify(
        () => messageRepo.markDeleted(
          'msg-recent',
          forEveryone: true,
        ),
      ).called(1);
    });

    test(
        'deleteForEveryone throws when message '
        'not found', () async {
      when(() => messageRepo.getMessageById('msg-missing'))
          .thenAnswer((_) async => null);

      await expectLater(
        deleteUseCase.deleteForEveryone('msg-missing'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // ChatSessionImpl
  // =========================================================================

  group('ChatSessionImpl', () {
    late MockMessageRepository sessionMsgRepo;
    late MockConversationRepository sessionConvRepo;
    late MockReceiptRepository sessionReceiptRepo;
    late MockOutboxRepository sessionOutboxRepo;
    late MockDecryptedMessageRepository sessionDecCache;
    late MockKeyStore sessionKeyStore;
    late MockSenderKeyStore sessionSkStore;
    late MockGroupCipher sessionGroupCipher;
    late MockSupabaseClientWrapper sessionApiClient;
    late MockSyncCoordinator sessionSyncCoord;
    late ChatSessionImpl session;

    setUp(() {
      sessionMsgRepo = MockMessageRepository();
      sessionConvRepo = MockConversationRepository();
      sessionReceiptRepo = MockReceiptRepository();
      sessionOutboxRepo = MockOutboxRepository();
      sessionDecCache = MockDecryptedMessageRepository();
      sessionKeyStore = MockKeyStore();
      sessionSkStore = MockSenderKeyStore();
      sessionGroupCipher = MockGroupCipher();
      sessionApiClient = MockSupabaseClientWrapper();
      sessionSyncCoord = MockSyncCoordinator();

      final sendUseCase = SendMessageUseCase(
        keyStore: sessionKeyStore,
        apiClient: sessionApiClient,
        messageRepo: sessionMsgRepo,
        conversationRepo: sessionConvRepo,
        outboxRepo: sessionOutboxRepo,
        decryptedCache: sessionDecCache,
        senderKeyStore: sessionSkStore,
        groupCipher: sessionGroupCipher,
        myUserId: _myUserId,
        myDeviceId: _myDeviceId,
      );

      final markReadUseCase = MarkReadUseCase(
        messageRepo: sessionMsgRepo,
        conversationRepo: sessionConvRepo,
      );

      final deleteUseCase = DeleteMessageUseCase(
        messageRepo: sessionMsgRepo,
      );

      session = ChatSessionImpl(
        groupId: _groupId,
        sendUseCase: sendUseCase,
        markReadUseCase: markReadUseCase,
        deleteUseCase: deleteUseCase,
        messageRepo: sessionMsgRepo,
        receiptRepo: sessionReceiptRepo,
        syncCoordinator: sessionSyncCoord,
      );
    });

    test('groupId returns correct value', () {
      expect(session.groupId, _groupId);
    });

    test(
        'messages returns watchMessages stream', () {
      final controller =
          StreamController<List<Message>>.broadcast();
      when(
        () => sessionMsgRepo.watchMessages(_groupId),
      ).thenAnswer((_) => controller.stream);

      final stream = session.messages;
      expect(stream, isA<Stream<List<Message>>>());

      controller.close();
    });

    test(
        'receipts returns watchReceipts stream', () {
      final controller =
          StreamController<List<Receipt>>.broadcast();
      when(
        () => sessionReceiptRepo.watchReceipts(
          _groupId,
        ),
      ).thenAnswer((_) => controller.stream);

      final stream = session.receipts;
      expect(stream, isA<Stream<List<Receipt>>>());

      controller.close();
    });

    test(
        'typing filters events by groupId',
        () async {
      final controller =
          StreamController<TypingIndicator>.broadcast();
      when(() => sessionSyncCoord.typingEvents)
          .thenAnswer((_) => controller.stream);

      final events = <List<TypingIndicator>>[];
      final sub = session.typing.listen(events.add);

      // Add matching + non-matching events.
      controller
        ..add(
          TypingIndicator(
            groupId: _groupId,
            userId: _peerId,
            startedAt: DateTime.now(),
          ),
        )
        ..add(
          TypingIndicator(
            groupId: 'other-conv',
            userId: 'other-user',
            startedAt: DateTime.now(),
          ),
        );

      // Give stream time to process.
      await Future<void>.delayed(
        Duration(milliseconds: 10),
      );

      expect(events, hasLength(1));
      expect(events.first.first.userId, _peerId);

      await sub.cancel();
      await controller.close();
    });

    test(
        'markRead delegates to MarkReadUseCase',
        () async {
      when(
        () => sessionMsgRepo.updateMessageStatus(
          any(),
          any(),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sessionConvRepo.updateUnreadCount(
          any(),
          any(),
        ),
      ).thenAnswer((_) async {});

      await session.markRead('msg-001');

      verify(
        () => sessionMsgRepo.updateMessageStatus(
          'msg-001',
          MessageStatus.read,
        ),
      ).called(1);
      verify(
        () => sessionConvRepo.updateUnreadCount(
          _groupId,
          0,
        ),
      ).called(1);
    });

    test(
        'deleteForMe delegates to '
        'DeleteMessageUseCase', () async {
      when(
        () => sessionMsgRepo.markDeleted(
          any(),
          forEveryone: any(named: 'forEveryone'),
        ),
      ).thenAnswer((_) async {});

      await session.deleteForMe('msg-001');

      verify(
        () => sessionMsgRepo.markDeleted(
          'msg-001',
          forEveryone: false,
        ),
      ).called(1);
    });

    test(
        'loadMore delegates to '
        'messageRepo.getMessages', () async {
      when(
        () => sessionMsgRepo.getMessages(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <Message>[]);

      await session.loadMore(limit: 25);

      verify(
        () => sessionMsgRepo.getMessages(
          _groupId,
          limit: 25,
        ),
      ).called(1);
    });
  });

  // =========================================================================
  // ChatEngineConfig
  // =========================================================================

  group('ChatEngineConfig', () {
    test('stores all required fields', () {
      final config = ChatEngineConfig(
        authToken: 'test-token',
        userId: 'user_alice',
        deviceId: 1,
        pushToken: 'push-token',
        serverBaseUrl: Uri.parse('https://api.example.com'),
      );

      expect(config.authToken, 'test-token');
      expect(config.userId, 'user_alice');
      expect(config.deviceId, 1);
      expect(config.pushToken, 'push-token');
      expect(
        config.serverBaseUrl.toString(),
        'https://api.example.com',
      );
      expect(config.supabaseAnonKey, '');
      expect(config.observer, isNull);
    });
  });

  // =========================================================================
  // SendMessageUseCase — uncovered paths
  // =========================================================================

  group('SendMessageUseCase (uncovered paths)', () {
    late SendMessageUseCase sendUseCase;

    setUp(() {
      sendUseCase = SendMessageUseCase(
        keyStore: keyStore,
        apiClient: apiClient,
        messageRepo: messageRepo,
        conversationRepo: conversationRepo,
        outboxRepo: outboxRepo,
        decryptedCache: decryptedCache,
        senderKeyStore: senderKeyStore,
        groupCipher: groupCipher,
        myUserId: _myUserId,
        myDeviceId: _myDeviceId,
      );
    });

    test('sendText two-phase: saves unacked state BEFORE API call, '
        'then commits on success', () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      final session = await buildAliceBobSession();
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => session.alice);
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.deleteUnackedState(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.updateMessageStatus(any(), any()))
          .thenAnswer((_) async {});
      when(() => apiClient.sendMessage(any()))
          .thenAnswer((_) async => <String, dynamic>{});
      when(() => decryptedCache.cachePlaintext(any(), any()))
          .thenAnswer((_) async {});
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      await sendUseCase.sendText(_groupId, 'Two-phase test');

      // Verify ordering: storeUnackedState called before sendMessage
      verifyInOrder([
        () => keyStore.storeUnackedState(any(), any()),
        () => apiClient.sendMessage(any()),
        () => keyStore.storeSession(any(), any()),
        () => keyStore.deleteUnackedState(any()),
      ]);
    });

    test('sendText marks message failed on API error, '
        'preserves unacked state', () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      final session = await buildAliceBobSession();
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => session.alice);
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.updateMessageStatus(any(), any()))
          .thenAnswer((_) async {});

      // API call throws
      when(() => apiClient.sendMessage(any()))
          .thenThrow(Exception('network error'));

      await expectLater(
        sendUseCase.sendText(_groupId, 'Will fail at API'),
        throwsA(isA<Exception>()),
      );

      // Message marked failed
      verify(() => messageRepo.updateMessageStatus(
            any(), MessageStatus.failed)).called(1);

      // Unacked state NOT deleted (preserved for recovery)
      verifyNever(() => keyStore.deleteUnackedState(any()));
    });

    test('sendText establishes X3DH session when no session exists',
        () async {
      when(() => outboxRepo.getPendingCount())
          .thenAnswer((_) async => 0);
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation());

      // No existing session
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => null);

      // Identity key pair for X3DH
      final aliceId = await generateTestIdentityKeyPair();
      when(() => keyStore.getIdentityKeyPair())
          .thenAnswer((_) async => aliceId);

      // Peer key bundle from server
      final bobId = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobId);
      final bobOtk = await generateTestOneTimePreKey('otk-99');

      when(() => apiClient.fetchPeerKeyBundle(
            userId: any(named: 'userId'),
            deviceId: any(named: 'deviceId'),
          )).thenAnswer((_) async => <String, dynamic>{
            'identity_key': base64Encode(bobId.ed25519PublicKey),
            'signed_pre_key': base64Encode(bobSpk.publicKey),
            'signed_pre_key_id': bobSpk.id,
            'pre_key_sig': base64Encode(bobSpk.signature),
            'one_time_pre_key': base64Encode(bobOtk.publicKey),
            'one_time_pre_key_id': bobOtk.id,
          });

      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.storeUnackedState(any(), any()))
          .thenAnswer((_) async {});
      when(() => keyStore.deleteUnackedState(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.updateMessageStatus(any(), any()))
          .thenAnswer((_) async {});
      when(() => apiClient.sendMessage(any()))
          .thenAnswer((_) async => <String, dynamic>{});
      when(() => decryptedCache.cachePlaintext(any(), any()))
          .thenAnswer((_) async {});
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      final result = await sendUseCase.sendText(
        _groupId, 'First message to Bob');

      expect(result.status, MessageStatus.sent);

      // Verify fetchPeerKeyBundle was called (X3DH)
      verify(() => apiClient.fetchPeerKeyBundle(
            userId: any(named: 'userId'),
            deviceId: any(named: 'deviceId'),
          )).called(1);

      // Session stored (at least twice: once in _establishSession, once in commit)
      verify(() => keyStore.storeSession(any(), any()))
          .called(greaterThanOrEqualTo(2));
    });

    test('sendGroupText encrypts with GroupCipher and uses _group_ sentinel',
        () async {
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.updateMessageStatus(any(), any()))
          .thenAnswer((_) async {});

      // Existing sender key
      when(() => senderKeyStore.loadSenderKey(any(), any()))
          .thenAnswer((_) async => SenderKeyRecord(
                chainKey: Uint8List(32),
                signingPublicKey: Uint8List(32),
                signingPrivateKey: Uint8List(64),
                iteration: 5,
                createdAt: DateTime.now(),
              ));

      // No tombstone
      when(() => apiClient.checkTombstone(any(), any()))
          .thenAnswer((_) async => false);

      // GroupCipher encrypt
      when(() => groupCipher.encrypt(any(), any(), any()))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      // Capture the envelope
      MessageEnvelope? capturedEnvelope;
      when(() => apiClient.sendMessage(any())).thenAnswer((inv) async {
        capturedEnvelope = inv.positionalArguments.first as MessageEnvelope;
        return <String, dynamic>{};
      });

      when(() => decryptedCache.cachePlaintext(any(), any()))
          .thenAnswer((_) async {});
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => null);

      await sendUseCase.sendGroupText(_groupId, 'Group hello');

      expect(capturedEnvelope, isNotNull);
      expect(capturedEnvelope!.recipientId, '_group_');
      expect(capturedEnvelope!.recipientDeviceId, 0);
    });

    test('sendGroupText checks tombstone and rotates Sender Key', () async {
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.updateMessageStatus(any(), any()))
          .thenAnswer((_) async {});

      // Existing sender key
      final existingKey = SenderKeyRecord(
        chainKey: Uint8List(32),
        signingPublicKey: Uint8List(32),
        signingPrivateKey: Uint8List(64),
        iteration: 10,
        createdAt: DateTime.now().subtract(Duration(hours: 1)),
      );
      var loadCallCount = 0;
      when(() => senderKeyStore.loadSenderKey(any(), any()))
          .thenAnswer((_) async {
        loadCallCount++;
        // First call returns old key, second returns "rotated" key
        return loadCallCount == 1 ? existingKey : SenderKeyRecord(
          chainKey: Uint8List(32),
          signingPublicKey: Uint8List(32),
          signingPrivateKey: Uint8List(64),
          iteration: 0,
          createdAt: DateTime.now(),
        );
      });

      // Tombstone found → rotation triggered
      when(() => apiClient.checkTombstone(any(), any()))
          .thenAnswer((_) async => true);

      // createSenderKey should be called
      when(() => groupCipher.createSenderKey(any(), any()))
          .thenAnswer((_) async => SenderKeyDistribution(
                chainKey: Uint8List(32),
                signingPublicKey: Uint8List(32),
                iteration: 0,
              ));

      // Members for distribution
      when(() => apiClient.getSpaceMembers(any()))
          .thenAnswer((_) async => <Map<String, dynamic>>[]);

      when(() => groupCipher.encrypt(any(), any(), any()))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(() => apiClient.sendMessage(any()))
          .thenAnswer((_) async => <String, dynamic>{});
      when(() => decryptedCache.cachePlaintext(any(), any()))
          .thenAnswer((_) async {});
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => null);

      await sendUseCase.sendGroupText(_groupId, 'After tombstone');

      // createSenderKey was called (rotation)
      verify(() => groupCipher.createSenderKey(any(), any())).called(1);
    });

    test('sendGroupText distributes SK to members when new key created',
        () async {
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => messageRepo.updateMessageStatus(any(), any()))
          .thenAnswer((_) async {});

      // No existing sender key → creates new
      when(() => senderKeyStore.loadSenderKey(any(), any()))
          .thenAnswer((_) async => null);

      when(() => groupCipher.createSenderKey(any(), any()))
          .thenAnswer((_) async {
        // Store the key so the second load finds it
        return SenderKeyDistribution(
          chainKey: Uint8List(32),
          signingPublicKey: Uint8List(32),
          iteration: 0,
        );
      });

      // After creation, loadSenderKey returns the key
      var created = false;
      when(() => senderKeyStore.loadSenderKey(any(), any()))
          .thenAnswer((_) async {
        if (!created) {
          created = true;
          return null;
        }
        return SenderKeyRecord(
          chainKey: Uint8List(32),
          signingPublicKey: Uint8List(32),
          signingPrivateKey: Uint8List(64),
          iteration: 0,
          createdAt: DateTime.now(),
        );
      });

      // No tombstone (key is brand new)
      when(() => apiClient.checkTombstone(any(), any()))
          .thenAnswer((_) async => false);

      // Members to distribute to
      when(() => apiClient.getSpaceMembers(any()))
          .thenAnswer((_) async => <Map<String, dynamic>>[
                {'user_id': 'name_bob', 'device_id': 1},
                {'user_id': _myUserId, 'device_id': _myDeviceId},
              ]);

      // Establish session for Bob
      final bobSession = await buildAliceBobSession();
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => bobSession.alice);
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});

      when(() => groupCipher.encrypt(any(), any(), any()))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      MessageEnvelope? capturedEnvelope;
      when(() => apiClient.sendMessage(any())).thenAnswer((inv) async {
        capturedEnvelope = inv.positionalArguments.first as MessageEnvelope;
        return <String, dynamic>{};
      });
      when(() => decryptedCache.cachePlaintext(any(), any()))
          .thenAnswer((_) async {});
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => null);

      await sendUseCase.sendGroupText(_groupId, 'New key');

      // Distribution ciphertexts should be present (for Bob, not for self)
      expect(capturedEnvelope!.distributionCiphertexts, hasLength(1));
      expect(capturedEnvelope!.distributionCiphertexts.first.recipientId,
          'name_bob');
      expect(capturedEnvelope!.distributionCiphertexts.first.id,
          startsWith('mc_'));
    });
  });

  // =========================================================================
  // ReceiveMessageUseCase — uncovered paths
  // =========================================================================

  group('ReceiveMessageUseCase (uncovered paths)', () {
    late ReceiveMessageUseCase receiveUseCase;

    setUp(() {
      receiveUseCase = ReceiveMessageUseCase(
        keyStore: keyStore,
        messageRepo: messageRepo,
        conversationRepo: conversationRepo,
        decryptedCache: decryptedCache,
        processedDistRepo: processedDistRepo,
        groupCipher: groupCipher,
        myUserId: _myUserId,
        myDeviceId: _myDeviceId,
      );
    });

    test('group decrypt: decrypts _group_ message via GroupCipher',
        () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);

      final decryptedJson = jsonEncode({
        'text': 'Group hello!',
        'type': 'message',
      });
      final plainBytes = Uint8List.fromList(utf8.encode(decryptedJson));

      when(() => groupCipher.decrypt(any(), any(), any()))
          .thenAnswer((_) async => plainBytes);
      when(() => messageRepo.saveMessage(any()))
          .thenAnswer((_) async {});
      when(() => decryptedCache.cachePlaintext(any(), any()))
          .thenAnswer((_) async {});
      when(() => conversationRepo.getConversation(any()))
          .thenAnswer((_) async => _makeConversation(
                type: ConversationType.group,
                participants: [_myUserId, _peerId, 'name_carol'],
              ));
      when(() => conversationRepo.saveConversation(any()))
          .thenAnswer((_) async {});

      final result = await receiveUseCase.processReceivedMessage(
        messageId: 'group-msg-1',
        groupId: _groupId,
        senderId: _peerId,
        senderDeviceId: 1,
        messageType: 'e2ee',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': base64Encode([1, 2, 3]),
          'recipient_id': '_group_',
        },
      );

      expect(result, isNotNull);
      expect(result!.text, 'Group hello!');

      verify(() => groupCipher.decrypt(
            _groupId, _peerId, any())).called(1);
    });

    test('sender_key_dist: processes SK distribution message', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);

      // Not already processed
      when(() => processedDistRepo.isProcessed(any()))
          .thenAnswer((_) async => false);

      // Build encrypted SK distribution via real ratchet
      final session = await buildAliceBobSession();

      final distPayload = jsonEncode({
        'chainKey': base64Encode(Uint8List(32)),
        'signingPublicKey': base64Encode(Uint8List(32)),
        'iteration': 0,
      });
      final distBytes = Uint8List.fromList(utf8.encode(distPayload));

      final encResult = await DoubleRatchet.encrypt(
        session.alice, distBytes);

      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => session.bob);
      when(() => keyStore.storeSession(any(), any()))
          .thenAnswer((_) async {});
      when(() => groupCipher.processSenderKeyDistribution(
            any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => processedDistRepo.markProcessed(any()))
          .thenAnswer((_) async {});

      final result = await receiveUseCase.processReceivedMessage(
        messageId: 'sk-dist-1',
        groupId: _groupId,
        senderId: _peerId,
        senderDeviceId: 1,
        messageType: 'sender_key_dist',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': base64Encode(encResult.ciphertext),
          'ratchet_header': base64Encode(encResult.encryptedHeader),
          'recipient_id': _myUserId,
        },
      );

      // SK dist returns null (no user-visible message)
      expect(result, isNull);

      // Verify SK was processed and marked
      verify(() => groupCipher.processSenderKeyDistribution(
            _groupId, _peerId, any())).called(1);
      verify(() => processedDistRepo.markProcessed('sk-dist-1')).called(1);
    });

    test('sender_key_dist: skips already-processed distribution', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);

      // Already processed
      when(() => processedDistRepo.isProcessed('sk-dup'))
          .thenAnswer((_) async => true);

      final result = await receiveUseCase.processReceivedMessage(
        messageId: 'sk-dup',
        groupId: _groupId,
        senderId: _peerId,
        senderDeviceId: 1,
        messageType: 'sender_key_dist',
        createdAt: DateTime.utc(2026, 3, 26),
        ciphertextData: {
          'ciphertext': 'abc',
          'recipient_id': _myUserId,
        },
      );

      expect(result, isNull);
      verifyNever(() => groupCipher.processSenderKeyDistribution(
            any(), any(), any()));
    });

    test('1:1 decrypt: throws when no ratchet session exists', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);
      when(() => keyStore.loadSession(any()))
          .thenAnswer((_) async => null);

      await expectLater(
        receiveUseCase.processReceivedMessage(
          messageId: 'msg-no-session',
          groupId: _groupId,
          senderId: _peerId,
          senderDeviceId: 1,
          messageType: 'e2ee',
          createdAt: DateTime.utc(2026, 3, 26),
          ciphertextData: {
            'ciphertext': base64Encode([1, 2, 3]),
            'ratchet_header': base64Encode([4, 5, 6]),
            'recipient_id': _myUserId,
          },
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No ratchet session'),
        )),
      );
    });
  });
}

/// Creates a valid ratchet state for testing by running
/// DoubleRatchet.initAlice.
Future<RatchetState> _createDummyRatchetState(
  Uint8List sharedSecret,
  Uint8List bobPublicKey,
) async {
  return DoubleRatchet.initAlice(sharedSecret, bobPublicKey);
}
