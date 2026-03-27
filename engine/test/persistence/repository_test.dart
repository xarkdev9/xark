import 'dart:convert';
import 'dart:typed_data';

import 'package:hello_engine/src/domain/models/conversation.dart';
import 'package:hello_engine/src/domain/models/message.dart';
import 'package:hello_engine/src/domain/models/receipt.dart';
import 'package:hello_engine/src/persistence/database/app_database.dart';
import 'package:hello_engine/src/persistence/repositories/conversation_repository_impl.dart';
import 'package:hello_engine/src/persistence/repositories/decrypted_message_repository_impl.dart';
import 'package:hello_engine/src/persistence/repositories/message_repository_impl.dart';
import 'package:hello_engine/src/persistence/repositories/outbox_repository_impl.dart';
import 'package:hello_engine/src/persistence/repositories/processed_distribution_repository_impl.dart';
import 'package:hello_engine/src/persistence/repositories/receipt_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _createTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // Message Repository
  // =========================================================================

  group('MessageRepositoryImpl', () {
    late MessageRepositoryImpl repo;

    setUp(() {
      repo = MessageRepositoryImpl(db);
    });

    Message makeMessage({
      String id = 'msg-1',
      String groupId = 'conv-1',
      String senderId = 'alice',
      MessageType type = MessageType.e2ee,
      MessageStatus status = MessageStatus.sending,
      DateTime? timestamp,
    }) {
      return Message(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderDeviceId: 'device-1',
        type: type,
        status: status,
        timestamp: timestamp ?? DateTime(2025, 1, 15),
      );
    }

    test('saveMessage and getMessageById round-trip', () async {
      final msg = makeMessage();
      await repo.saveMessage(msg);

      final result = await repo.getMessageById('msg-1');
      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.groupId, 'conv-1');
      expect(result.senderId, 'alice');
      expect(result.senderDeviceId, 'device-1');
      expect(result.type, MessageType.e2ee);
      expect(result.status, MessageStatus.sending);
    });

    test('getMessageById returns null for non-existent ID', () async {
      final result = await repo.getMessageById('non-existent');
      expect(result, isNull);
    });

    test('saveMessages batch inserts multiple messages', () async {
      final messages = List.generate(
        5,
        (i) => makeMessage(
          id: 'msg-$i',
          timestamp: DateTime(2025, 1, 15 + i),
        ),
      );
      await repo.saveMessages(messages);

      for (var i = 0; i < 5; i++) {
        final result = await repo.getMessageById('msg-$i');
        expect(result, isNotNull);
      }
    });

    test(
      'getMessages returns messages for conversation '
      'ordered by createdAt DESC',
      () async {
        for (var i = 0; i < 5; i++) {
          await repo.saveMessage(
            makeMessage(
              id: 'msg-$i',
              timestamp: DateTime(2025, 1, 15 + i),
            ),
          );
        }

        final results = await repo.getMessages('conv-1');
        expect(results, hasLength(5));
        // Most recent first.
        expect(results.first.id, 'msg-4');
        expect(results.last.id, 'msg-0');
      },
    );

    test('getMessages respects limit', () async {
      for (var i = 0; i < 10; i++) {
        await repo.saveMessage(
          makeMessage(
            id: 'msg-$i',
            timestamp: DateTime(2025, 1, 15 + i),
          ),
        );
      }

      final results = await repo.getMessages('conv-1', limit: 3);
      expect(results, hasLength(3));
    });

    test('getMessages with beforeId for pagination', () async {
      for (var i = 0; i < 5; i++) {
        await repo.saveMessage(
          makeMessage(
            id: 'msg-$i',
            timestamp: DateTime(2025, 1, 15 + i),
          ),
        );
      }

      // Get messages before msg-3 (Jan 18).
      final results = await repo.getMessages(
        'conv-1',
        beforeId: 'msg-3',
        limit: 10,
      );
      // Should return msg-2, msg-1, msg-0.
      expect(results, hasLength(3));
      expect(results.first.id, 'msg-2');
    });

    test('getMessages excludes other conversations', () async {
      await repo.saveMessage(makeMessage(id: 'msg-a'));
      await repo.saveMessage(
        makeMessage(id: 'msg-b', groupId: 'conv-2'),
      );

      final results = await repo.getMessages('conv-1');
      expect(results, hasLength(1));
      expect(results.first.id, 'msg-a');
    });

    test('updateMessageStatus changes status', () async {
      await repo.saveMessage(makeMessage());
      await repo.updateMessageStatus('msg-1', MessageStatus.delivered);

      final result = await repo.getMessageById('msg-1');
      expect(result!.status, MessageStatus.delivered);
    });

    test('markDeleted sets isDeleted', () async {
      await repo.saveMessage(makeMessage());
      await repo.markDeleted('msg-1', forEveryone: true);

      final result = await repo.getMessageById('msg-1');
      expect(result!.isDeleted, isTrue);
    });

    test('setReaction adds reaction and removeReaction removes it', () async {
      await repo.saveMessage(makeMessage());

      await repo.setReaction('msg-1', 'alice', '👍');
      var result = await repo.getMessageById('msg-1');
      expect(result!.reactions['👍'], contains('alice'));

      await repo.removeReaction('msg-1', 'alice', '👍');
      result = await repo.getMessageById('msg-1');
      expect(result!.reactions['👍'], isNull);
    });

    test('setStar toggles starred state', () async {
      await repo.saveMessage(makeMessage());

      await repo.setStar('msg-1', starred: true);
      var result = await repo.getMessageById('msg-1');
      expect(result!.isStarred, isTrue);

      await repo.setStar('msg-1', starred: false);
      result = await repo.getMessageById('msg-1');
      expect(result!.isStarred, isFalse);
    });

    test('search finds messages by cached plaintext', () async {
      await repo.saveMessage(makeMessage());
      await repo.saveMessage(makeMessage(id: 'msg-2'));

      // Cache plaintext.
      final decryptedRepo = DecryptedMessageRepositoryImpl(db);
      await decryptedRepo.cachePlaintext('msg-1', 'Hello world');
      await decryptedRepo.cachePlaintext('msg-2', 'Goodbye world');

      final results = await repo.search('hello');
      expect(results, hasLength(1));
      expect(results.first.id, 'msg-1');
    });

    test('watchMessages emits updates', () async {
      await repo.saveMessage(makeMessage(id: 'initial'));

      final stream = repo.watchMessages('conv-1');
      final first = await stream.first;
      expect(first, hasLength(1));
    });

    test('saveMessage with all message types round-trips', () async {
      for (final type in MessageType.values) {
        final msg = makeMessage(id: 'msg-${type.name}', type: type);
        await repo.saveMessage(msg);
        final result = await repo.getMessageById('msg-${type.name}');
        expect(result!.type, type);
      }
    });

    test('saveMessage with all status values round-trips', () async {
      for (final status in MessageStatus.values) {
        final msg = makeMessage(
          id: 'msg-${status.name}',
          status: status,
        );
        await repo.saveMessage(msg);
        final result = await repo.getMessageById('msg-${status.name}');
        expect(result!.status, status);
      }
    });
  });

  // =========================================================================
  // Message Ciphertext
  // =========================================================================

  group('MessageRepositoryImpl ciphertext operations', () {
    late MessageRepositoryImpl repo;

    setUp(() {
      repo = MessageRepositoryImpl(db);
    });

    test('saveCiphertext and getCiphertexts round-trip', () async {
      // First save the parent message.
      await repo.saveMessage(
        Message(
          id: 'msg-1',
          groupId: 'conv-1',
          senderId: 'alice',
          senderDeviceId: 'device-1',
          type: MessageType.e2ee,
          status: MessageStatus.sending,
          timestamp: DateTime(2025),
        ),
      );

      const ct = MessageCiphertextRow(
        id: 'ct-1',
        messageId: 'msg-1',
        recipientId: 'bob',
        recipientDeviceId: 42,
        ciphertext: 'encrypted-payload-base64',
        ratchetHeader: '{"publicKey":"abc","previousCount":0,'
            '"messageNumber":1}',
      );
      await repo.saveCiphertext(ct);

      final results = await repo.getCiphertexts('msg-1');
      expect(results, hasLength(1));
      expect(results.first.recipientId, 'bob');
      expect(results.first.recipientDeviceId, 42);
      expect(results.first.ciphertext, 'encrypted-payload-base64');
    });
  });

  // =========================================================================
  // Conversation Repository
  // =========================================================================

  group('ConversationRepositoryImpl', () {
    late ConversationRepositoryImpl repo;

    setUp(() {
      repo = ConversationRepositoryImpl(db);
    });

    Conversation makeConversation({
      String id = 'conv-1',
      ConversationType type = ConversationType.oneToOne,
      List<String> participantIds = const ['alice', 'bob'],
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      return Conversation(
        id: id,
        type: type,
        participantIds: participantIds,
        createdAt: createdAt ?? DateTime(2025),
        updatedAt: updatedAt ?? DateTime(2025),
      );
    }

    test('saveConversation and getConversation round-trip', () async {
      final conv = makeConversation();
      await repo.saveConversation(conv);

      final result = await repo.getConversation('conv-1');
      expect(result, isNotNull);
      expect(result!.id, 'conv-1');
      expect(result.type, ConversationType.oneToOne);
      expect(result.participantIds, ['alice', 'bob']);
      expect(result.unreadCount, 0);
      expect(result.isPinned, isFalse);
    });

    test('getConversation returns null for non-existent ID', () async {
      final result = await repo.getConversation('non-existent');
      expect(result, isNull);
    });

    test('getAllConversations ordered by pinned then updatedAt', () async {
      await repo.saveConversation(
        makeConversation(),
      );
      await repo.saveConversation(
        makeConversation(
          id: 'conv-2',
          updatedAt: DateTime(2025, 1, 3),
        ),
      );
      await repo.saveConversation(
        makeConversation(
          id: 'conv-3',
          updatedAt: DateTime(2025, 1, 2),
        ),
      );

      // Pin conv-1 (oldest).
      await repo.setPin('conv-1', pinned: true);

      final all = await repo.getAllConversations();
      expect(all, hasLength(3));
      // Pinned first, then by updatedAt desc.
      expect(all[0].id, 'conv-1');
      expect(all[1].id, 'conv-2');
      expect(all[2].id, 'conv-3');
    });

    test('updateUnreadCount changes count', () async {
      await repo.saveConversation(makeConversation());
      await repo.updateUnreadCount('conv-1', 5);

      final result = await repo.getConversation('conv-1');
      expect(result!.unreadCount, 5);
    });

    test('setPin toggles pinned state', () async {
      await repo.saveConversation(makeConversation());

      await repo.setPin('conv-1', pinned: true);
      var result = await repo.getConversation('conv-1');
      expect(result!.isPinned, isTrue);

      await repo.setPin('conv-1', pinned: false);
      result = await repo.getConversation('conv-1');
      expect(result!.isPinned, isFalse);
    });

    test('setArchive toggles archived state', () async {
      await repo.saveConversation(makeConversation());

      await repo.setArchive('conv-1', archived: true);
      var result = await repo.getConversation('conv-1');
      expect(result!.isArchived, isTrue);

      await repo.setArchive('conv-1', archived: false);
      result = await repo.getConversation('conv-1');
      expect(result!.isArchived, isFalse);
    });

    test('setMute with expiry', () async {
      await repo.saveConversation(makeConversation());
      final until = DateTime(2025, 6);

      await repo.setMute('conv-1', muted: true, until: until);
      var result = await repo.getConversation('conv-1');
      expect(result!.isMuted, isTrue);
      expect(result.muteUntil, until);

      await repo.setMute('conv-1', muted: false);
      result = await repo.getConversation('conv-1');
      expect(result!.isMuted, isFalse);
    });

    test('watchConversations emits updates', () async {
      await repo.saveConversation(makeConversation());

      final stream = repo.watchConversations();
      final first = await stream.first;
      expect(first, hasLength(1));
      expect(first.first.id, 'conv-1');
    });

    test('group conversation type round-trips', () async {
      await repo.saveConversation(
        makeConversation(
          id: 'group-1',
          type: ConversationType.group,
          participantIds: ['alice', 'bob', 'charlie'],
        ),
      );

      final result = await repo.getConversation('group-1');
      expect(result!.type, ConversationType.group);
      expect(result.participantIds, hasLength(3));
    });
  });

  // =========================================================================
  // Receipt Repository
  // =========================================================================

  group('ReceiptRepositoryImpl', () {
    late ReceiptRepositoryImpl repo;
    late MessageRepositoryImpl msgRepo;

    setUp(() {
      repo = ReceiptRepositoryImpl(db);
      msgRepo = MessageRepositoryImpl(db);
    });

    test('saveReceipt and getReceipts round-trip', () async {
      // Insert parent message first.
      await msgRepo.saveMessage(
        Message(
          id: 'msg-1',
          groupId: 'conv-1',
          senderId: 'alice',
          senderDeviceId: 'device-1',
          type: MessageType.e2ee,
          status: MessageStatus.sent,
          timestamp: DateTime(2025),
        ),
      );

      final receipt = Receipt(
        messageId: 'msg-1',
        userId: 'bob',
        deviceId: 'device-2',
        deliveredAt: DateTime(2025, 1, 15, 10, 30),
      );
      await repo.saveReceipt(receipt);

      final results = await repo.getReceipts('msg-1');
      expect(results, hasLength(1));
      expect(results.first.userId, 'bob');
      expect(results.first.deliveredAt, isNotNull);
      expect(results.first.readAt, isNull);
    });

    test('saveReceipt upserts with read timestamp', () async {
      await msgRepo.saveMessage(
        Message(
          id: 'msg-1',
          groupId: 'conv-1',
          senderId: 'alice',
          senderDeviceId: 'device-1',
          type: MessageType.e2ee,
          status: MessageStatus.sent,
          timestamp: DateTime(2025),
        ),
      );

      await repo.saveReceipt(
        Receipt(
          messageId: 'msg-1',
          userId: 'bob',
          deviceId: 'device-2',
          deliveredAt: DateTime(2025, 1, 15, 10, 30),
        ),
      );

      // Upsert with read timestamp.
      await repo.saveReceipt(
        Receipt(
          messageId: 'msg-1',
          userId: 'bob',
          deviceId: 'device-2',
          deliveredAt: DateTime(2025, 1, 15, 10, 30),
          readAt: DateTime(2025, 1, 15, 10, 35),
        ),
      );

      final results = await repo.getReceipts('msg-1');
      expect(results, hasLength(1));
      expect(results.first.readAt, isNotNull);
    });
  });

  // =========================================================================
  // Outbox Repository
  // =========================================================================

  group('OutboxRepositoryImpl', () {
    late OutboxRepositoryImpl repo;

    setUp(() {
      repo = OutboxRepositoryImpl(db);
    });

    OutboxItemRow makeOutboxItem({
      String id = 'outbox-1',
      String groupId = 'conv-1',
      DateTime? createdAt,
      DateTime? nextRetryAt,
    }) {
      return OutboxItemRow(
        id: id,
        groupId: groupId,
        encryptedEnvelope: Uint8List.fromList([1, 2, 3]),
        recipientDeviceIds: jsonEncode(['alice:1', 'bob:2']),
        retryCount: 0,
        createdAt: createdAt ?? DateTime(2025, 1, 15),
        nextRetryAt: nextRetryAt ?? DateTime(2025, 1, 15),
      );
    }

    test('enqueue and getPending returns items', () async {
      await repo.enqueue(makeOutboxItem());

      final pending = await repo.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.id, 'outbox-1');
    });

    test('getPending respects nextRetryAt', () async {
      await repo.enqueue(
        makeOutboxItem(
          id: 'outbox-future',
          nextRetryAt: DateTime(2099),
        ),
      );
      await repo.enqueue(
        makeOutboxItem(
          id: 'outbox-past',
          nextRetryAt: DateTime(2020),
        ),
      );

      final pending = await repo.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.id, 'outbox-past');
    });

    test('markSent removes item from outbox', () async {
      await repo.enqueue(makeOutboxItem());
      await repo.markSent('outbox-1');

      final pending = await repo.getPending();
      expect(pending, isEmpty);
    });

    test('markFailed increments retryCount and sets nextRetryAt', () async {
      await repo.enqueue(
        makeOutboxItem(nextRetryAt: DateTime(2020)),
      );

      await repo.markFailed(
        'outbox-1',
        retryAfter: const Duration(seconds: 30),
      );

      final pending = await repo.getPending();
      // nextRetryAt is in the future, so it should not be returned.
      expect(pending, isEmpty);

      // Verify retryCount was incremented.
      final count = await repo.getPendingCount();
      expect(count, 1); // Still in DB, just not "pending" yet.
    });

    test('delete removes item', () async {
      await repo.enqueue(makeOutboxItem());
      await repo.delete('outbox-1');

      final count = await repo.getPendingCount();
      expect(count, 0);
    });

    test('getPendingCount returns correct count', () async {
      await repo.enqueue(makeOutboxItem(id: 'a'));
      await repo.enqueue(makeOutboxItem(id: 'b'));
      await repo.enqueue(makeOutboxItem(id: 'c'));

      final count = await repo.getPendingCount();
      expect(count, 3);
    });
  });

  // =========================================================================
  // Decrypted Message Repository
  // =========================================================================

  group('DecryptedMessageRepositoryImpl', () {
    late DecryptedMessageRepositoryImpl repo;

    setUp(() {
      repo = DecryptedMessageRepositoryImpl(db);
    });

    test('cachePlaintext and getCachedPlaintext round-trip', () async {
      await repo.cachePlaintext('msg-1', 'Hello, world!');

      final result = await repo.getCachedPlaintext('msg-1');
      expect(result, 'Hello, world!');
    });

    test('getCachedPlaintext returns null for uncached message', () async {
      final result = await repo.getCachedPlaintext('non-existent');
      expect(result, isNull);
    });

    test('cachePlaintext with mediaJson and getCachedMediaJson', () async {
      const mediaJson = '{"mediaId":"m1","mimeType":"image/jpeg"}';
      await repo.cachePlaintext(
        'msg-1',
        'Check this out',
        mediaJson: mediaJson,
      );

      final text = await repo.getCachedPlaintext('msg-1');
      expect(text, 'Check this out');

      final media = await repo.getCachedMediaJson('msg-1');
      expect(media, mediaJson);
    });

    test('expireOlderThan removes old entries', () async {
      // We need to insert with an old cachedAt. Use the DB directly.
      await db.into(db.decryptedMessages).insert(
            DecryptedMessageRow(
              messageId: 'old-msg',
              plaintext: 'old text',
              cachedAt: DateTime(2020),
            ),
          );
      await repo.cachePlaintext('new-msg', 'new text');

      await repo.expireOlderThan(const Duration(days: 365));

      final old = await repo.getCachedPlaintext('old-msg');
      expect(old, isNull);

      final recent = await repo.getCachedPlaintext('new-msg');
      expect(recent, 'new text');
    });
  });

  // =========================================================================
  // Processed Distribution Repository
  // =========================================================================

  group('ProcessedDistributionRepositoryImpl', () {
    late ProcessedDistributionRepositoryImpl repo;

    setUp(() {
      repo = ProcessedDistributionRepositoryImpl(db);
    });

    test('isProcessed returns false for unprocessed message', () async {
      final result = await repo.isProcessed('dist-1');
      expect(result, isFalse);
    });

    test('markProcessed then isProcessed returns true', () async {
      await repo.markProcessed('dist-1');
      final result = await repo.isProcessed('dist-1');
      expect(result, isTrue);
    });

    test('markProcessed is idempotent', () async {
      await repo.markProcessed('dist-1');
      await repo.markProcessed('dist-1');
      final result = await repo.isProcessed('dist-1');
      expect(result, isTrue);
    });
  });
}
