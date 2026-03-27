// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hello_engine/src/domain/models/message.dart';
import 'package:hello_engine/src/domain/models/presence_state.dart';
import 'package:hello_engine/src/domain/models/typing_indicator.dart';
import 'package:hello_engine/src/domain/repositories/message_repository.dart';
import 'package:hello_engine/src/domain/repositories/receipt_repository.dart';
import 'package:hello_engine/src/persistence/database/app_database.dart';
import 'package:hello_engine/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:hello_engine/src/persistence/repositories/outbox_repository.dart';
import 'package:hello_engine/src/sync/deduplication_set.dart';
import 'package:hello_engine/src/sync/gap_detector.dart';
import 'package:hello_engine/src/sync/message_processor.dart';
import 'package:hello_engine/src/sync/outbox_processor.dart';
import 'package:hello_engine/src/sync/sync_coordinator.dart';
import 'package:hello_engine/src/sync/sync_observer.dart';
import 'package:hello_engine/src/transport/dto/message_envelope.dart';
import 'package:hello_engine/src/transport/dto/realtime_event.dart';
import 'package:hello_engine/src/transport/realtime_listener.dart';
import 'package:hello_engine/src/transport/supabase_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockSupabaseClientWrapper extends Mock
    implements SupabaseClientWrapper {}

class MockMessageRepository extends Mock implements MessageRepository {}

class MockReceiptRepository extends Mock implements ReceiptRepository {}

class MockDecryptedMessageRepository extends Mock
    implements DecryptedMessageRepository {}

class MockRealtimeListener extends Mock implements RealtimeListener {}

// ---------------------------------------------------------------------------
// Fakes for registerFallbackValue
// ---------------------------------------------------------------------------

class FakeMessageEnvelope extends Fake implements MessageEnvelope {}

class FakeDuration extends Fake implements Duration {}

// ---------------------------------------------------------------------------
// Test observer to capture callbacks
// ---------------------------------------------------------------------------

class TestSyncObserver with SyncObserver {
  int? lastSent;
  int? lastFailed;
  int? lastPulled;
  Duration? lastElapsed;

  @override
  void onOutboxDrained(int messagesSent, int messagesFailed) {
    lastSent = messagesSent;
    lastFailed = messagesFailed;
  }

  @override
  void onSyncCompleted(int messagesPulled, Duration elapsed) {
    lastPulled = messagesPulled;
    lastElapsed = elapsed;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a valid serialised MessageEnvelope as Uint8List bytes.
Uint8List _makeEnvelopeBytes({String groupId = 'space-1'}) {
  final json = jsonEncode(<String, dynamic>{
    'group_id': groupId,
    'sender_device_id': 1,
    'ciphertext': 'dGVzdA==',
    'recipient_id': 'bob',
    'recipient_device_id': 2,
    'message_type': 'e2ee',
    'distribution_ciphertexts': <dynamic>[],
  });
  return Uint8List.fromList(utf8.encode(json));
}

/// Creates a test OutboxItemRow via drift's constructor.
OutboxItemRow _makeOutboxItem({
  required String id,
  int retryCount = 0,
  Uint8List? envelope,
}) {
  return OutboxItemRow(
    id: id,
    groupId: 'conv-1',
    encryptedEnvelope: envelope ?? _makeEnvelopeBytes(),
    recipientDeviceIds: '["bob:2"]',
    retryCount: retryCount,
    createdAt: DateTime(2025, 6),
    nextRetryAt: DateTime(2025, 6),
  );
}

RealtimeMessageEvent _makeEvent({
  String messageId = 'msg-1',
  String senderId = 'bob',
}) {
  return RealtimeMessageEvent(
    messageId: messageId,
    groupId: 'space-1',
    senderId: senderId,
    messageType: 'e2ee',
    createdAt: DateTime(2025, 6),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMessageEnvelope());
    registerFallbackValue(FakeDuration());
  });

  // =========================================================================
  // DeduplicationSet
  // =========================================================================

  group('DeduplicationSet', () {
    late DeduplicationSet dedup;

    setUp(() {
      dedup = DeduplicationSet();
    });

    test('tryAdd returns true for new items', () {
      expect(dedup.tryAdd('msg-1'), isTrue);
      expect(dedup.tryAdd('msg-2'), isTrue);
    });

    test('tryAdd returns false for duplicate items', () {
      dedup.tryAdd('msg-1');
      expect(dedup.tryAdd('msg-1'), isFalse);
    });

    test('evicts oldest entry when over maxSize', () {
      final small = DeduplicationSet(maxSize: 3)
        ..tryAdd('a')
        ..tryAdd('b')
        ..tryAdd('c')
        // Adding a 4th should evict 'a'.
        ..tryAdd('d');

      expect(small.contains('a'), isFalse);
      expect(small.contains('b'), isTrue);
      expect(small.contains('c'), isTrue);
      expect(small.contains('d'), isTrue);
      expect(small.length, 3);
    });

    test('clear removes all items', () {
      dedup
        ..tryAdd('msg-1')
        ..tryAdd('msg-2');
      expect(dedup.length, 2);

      dedup.clear();
      expect(dedup.length, 0);
      // Previously seen IDs are now considered new.
      expect(dedup.tryAdd('msg-1'), isTrue);
    });

    test('duplicate after eviction is treated as new', () {
      final small = DeduplicationSet(maxSize: 2)
        ..tryAdd('a')
        ..tryAdd('b')
        ..tryAdd('c'); // Evicts 'a'.

      // 'a' was evicted, so it's treated as new again.
      expect(small.tryAdd('a'), isTrue);
    });

    test('contains returns false for items not in the set', () {
      expect(dedup.contains('never-added'), isFalse);
    });
  });

  // =========================================================================
  // OutboxProcessor
  // =========================================================================

  group('OutboxProcessor', () {
    late MockOutboxRepository outboxRepo;
    late MockSupabaseClientWrapper api;
    late TestSyncObserver observer;
    late OutboxProcessor processor;

    setUp(() {
      outboxRepo = MockOutboxRepository();
      api = MockSupabaseClientWrapper();
      observer = TestSyncObserver();
      processor = OutboxProcessor(
        outboxRepository: outboxRepo,
        apiClient: api,
        observer: observer,
      );
    });

    test('drains pending items successfully', () async {
      final item1 = _makeOutboxItem(id: 'item-1');
      final item2 = _makeOutboxItem(id: 'item-2');

      // First call returns items, second call returns empty.
      var callCount = 0;
      when(() => outboxRepo.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return [item1, item2];
        return <OutboxItemRow>[];
      });

      when(() => api.sendMessage(any())).thenAnswer(
        (_) async => <String, dynamic>{'id': 'server-1'},
      );
      when(() => outboxRepo.markSent(any())).thenAnswer((_) async {});

      await processor.drainOutbox();

      verify(() => api.sendMessage(any())).called(2);
      verify(() => outboxRepo.markSent('item-1')).called(1);
      verify(() => outboxRepo.markSent('item-2')).called(1);
      expect(observer.lastSent, 2);
      expect(observer.lastFailed, 0);
    });

    test('handles empty outbox gracefully', () async {
      when(() => outboxRepo.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await processor.drainOutbox();

      verifyNever(() => api.sendMessage(any()));
      expect(observer.lastSent, 0);
      expect(observer.lastFailed, 0);
    });

    test('failed items get exponential backoff', () async {
      final item = _makeOutboxItem(id: 'item-1', retryCount: 3);

      var callCount = 0;
      when(() => outboxRepo.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return [item];
        return [];
      });

      when(() => api.sendMessage(any())).thenThrow(
        ApiException(500, 'Server error'),
      );
      when(
        () => outboxRepo.markFailed(
          any(),
          retryAfter: any(named: 'retryAfter'),
        ),
      ).thenAnswer((_) async {});

      await processor.drainOutbox();

      final captured = verify(
        () => outboxRepo.markFailed(
          'item-1',
          retryAfter: captureAny(named: 'retryAfter'),
        ),
      ).captured;

      // retryCount=3 -> 2^3 = 8 seconds.
      final backoff = captured.first as Duration;
      expect(backoff.inSeconds, 8);
      expect(observer.lastFailed, 1);
    });

    test('items exceeding maxRetries are deleted', () async {
      final item = _makeOutboxItem(id: 'item-1', retryCount: 10);

      var callCount = 0;
      when(() => outboxRepo.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return [item];
        return [];
      });

      when(() => api.sendMessage(any())).thenThrow(
        ApiException(500, 'Server error'),
      );
      when(() => outboxRepo.delete(any())).thenAnswer((_) async {});

      await processor.drainOutbox();

      verify(() => outboxRepo.delete('item-1')).called(1);
      verifyNever(
        () => outboxRepo.markFailed(
          any(),
          retryAfter: any(named: 'retryAfter'),
        ),
      );
      expect(observer.lastFailed, 1);
    });

    test('mixed success and failure reports correct counts', () async {
      final good = _makeOutboxItem(id: 'good');
      final bad = _makeOutboxItem(id: 'bad', retryCount: 1);

      var callCount = 0;
      when(() => outboxRepo.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return [good, bad];
        return [];
      });

      var sendCount = 0;
      when(() => api.sendMessage(any())).thenAnswer((_) async {
        sendCount++;
        if (sendCount == 2) {
          throw ApiException(500, 'fail');
        }
        return <String, dynamic>{'id': 'ok'};
      });

      when(() => outboxRepo.markSent(any())).thenAnswer((_) async {});
      when(
        () => outboxRepo.markFailed(
          any(),
          retryAfter: any(named: 'retryAfter'),
        ),
      ).thenAnswer((_) async {});

      await processor.drainOutbox();

      expect(observer.lastSent, 1);
      expect(observer.lastFailed, 1);
    });

    test('backoff clamps at 60 seconds', () async {
      final item = _makeOutboxItem(id: 'item-1', retryCount: 9);

      var callCount = 0;
      when(() => outboxRepo.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return [item];
        return [];
      });

      when(() => api.sendMessage(any())).thenThrow(Exception('fail'));
      when(
        () => outboxRepo.markFailed(
          any(),
          retryAfter: any(named: 'retryAfter'),
        ),
      ).thenAnswer((_) async {});

      await processor.drainOutbox();

      final captured = verify(
        () => outboxRepo.markFailed(
          'item-1',
          retryAfter: captureAny(named: 'retryAfter'),
        ),
      ).captured;

      // retryCount=9 -> 2^9 = 512 -> clamped to 60.
      final backoff = captured.first as Duration;
      expect(backoff.inSeconds, 60);
    });
  });

  // =========================================================================
  // GapDetector
  // =========================================================================

  group('GapDetector', () {
    late MockSupabaseClientWrapper api;
    late MockMessageRepository messageRepo;
    late TestSyncObserver observer;
    late GapDetector detector;

    setUp(() {
      api = MockSupabaseClientWrapper();
      messageRepo = MockMessageRepository();
      observer = TestSyncObserver();
      detector = GapDetector(
        apiClient: api,
        messageRepo: messageRepo,
        observer: observer,
      );
    });

    test('fetches messages after latest local timestamp', () async {
      final latestMessage = Message(
        id: 'msg-latest',
        groupId: 'space-1',
        senderId: 'alice',
        senderDeviceId: 'device-1',
        type: MessageType.e2ee,
        status: MessageStatus.delivered,
        timestamp: DateTime(2025, 6, 1, 12),
      );

      when(
        () => messageRepo.getMessages('space-1', limit: 1),
      ).thenAnswer((_) async => [latestMessage]);

      when(
        () => api.fetchMessageHistory(
          'space-1',
          after: DateTime(2025, 6, 1, 12),
        ),
      ).thenAnswer(
        (_) async => [
          <String, dynamic>{'id': 'msg-new-1'},
          <String, dynamic>{'id': 'msg-new-2'},
        ],
      );

      final missed = await detector.fillGaps(['space-1']);

      expect(missed, hasLength(2));
      expect(missed[0]['id'], 'msg-new-1');
      expect(observer.lastPulled, 2);
      expect(observer.lastElapsed, isNotNull);
    });

    test('handles empty conversation list', () async {
      final missed = await detector.fillGaps([]);

      expect(missed, isEmpty);
      expect(observer.lastPulled, 0);
    });

    test('fetches all history when no local messages exist', () async {
      when(
        () => messageRepo.getMessages('space-1', limit: 1),
      ).thenAnswer((_) async => []);

      when(
        () => api.fetchMessageHistory('space-1'),
      ).thenAnswer(
        (_) async => [
          <String, dynamic>{'id': 'msg-1'},
        ],
      );

      final missed = await detector.fillGaps(['space-1']);

      expect(missed, hasLength(1));
    });

    test('reports sync completed via observer', () async {
      when(
        () => messageRepo.getMessages(any(), limit: 1),
      ).thenAnswer((_) async => []);

      when(
        () => api.fetchMessageHistory(any()),
      ).thenAnswer((_) async => []);

      await detector.fillGaps(['space-1', 'space-2']);

      expect(observer.lastPulled, 0);
      expect(observer.lastElapsed, isNotNull);
      expect(observer.lastElapsed!.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('aggregates missed messages from multiple spaces', () async {
      when(
        () => messageRepo.getMessages(any(), limit: 1),
      ).thenAnswer((_) async => []);

      when(
        () => api.fetchMessageHistory('space-1'),
      ).thenAnswer(
        (_) async => [<String, dynamic>{'id': 'a'}],
      );
      when(
        () => api.fetchMessageHistory('space-2'),
      ).thenAnswer(
        (_) async => [
          <String, dynamic>{'id': 'b'},
          <String, dynamic>{'id': 'c'},
        ],
      );

      final missed = await detector.fillGaps(['space-1', 'space-2']);

      expect(missed, hasLength(3));
      expect(observer.lastPulled, 3);
    });
  });

  // =========================================================================
  // MessageProcessor
  // =========================================================================

  group('MessageProcessor', () {
    late MockSupabaseClientWrapper api;
    late MockDecryptedMessageRepository decryptedCache;
    late MessageProcessor processor;

    setUp(() {
      api = MockSupabaseClientWrapper();
      decryptedCache = MockDecryptedMessageRepository();
      processor = MessageProcessor(
        apiClient: api,
        decryptedCache: decryptedCache,
        myUserId: 'alice',
        myDeviceId: 1,
      );
    });

    test('deduplicates messages with same ID', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);
      when(() => api.fetchCiphertexts(any())).thenAnswer(
        (_) async => [
          <String, dynamic>{
            'recipient_id': 'alice',
            'recipient_device_id': 1,
            'ciphertext': 'dGVzdA==',
          },
        ],
      );

      final event = _makeEvent();

      // First call should succeed.
      final result1 = await processor.processIncomingMessage(event);
      expect(result1, isNotNull);

      // Second call with same ID should be deduplicated.
      final result2 = await processor.processIncomingMessage(event);
      expect(result2, isNull);
    });

    test('finds correct ciphertext for 1:1 recipient', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);
      when(() => api.fetchCiphertexts('msg-1')).thenAnswer(
        (_) async => [
          // Ciphertext for another device.
          <String, dynamic>{
            'recipient_id': 'alice',
            'recipient_device_id': 99,
            'ciphertext': 'b3RoZXI=',
          },
          // Ciphertext for our device.
          <String, dynamic>{
            'recipient_id': 'alice',
            'recipient_device_id': 1,
            'ciphertext': 'b3Vycw==',
            'ratchet_header': 'aGVhZGVy',
          },
        ],
      );

      final result = await processor.processIncomingMessage(
        _makeEvent(),
      );

      expect(result, isNotNull);
      expect(result!.ciphertext, 'b3Vycw==');
      expect(result.ratchetHeader, 'aGVhZGVy');
      expect(result.isGroupMessage, isFalse);
    });

    test('finds group ciphertext', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);
      when(() => api.fetchCiphertexts('msg-group')).thenAnswer(
        (_) async => [
          <String, dynamic>{
            'recipient_id': '_group_',
            'recipient_device_id': 0,
            'ciphertext': 'Z3JvdXA=',
          },
        ],
      );

      final result = await processor.processIncomingMessage(
        _makeEvent(messageId: 'msg-group'),
      );

      expect(result, isNotNull);
      expect(result!.ciphertext, 'Z3JvdXA=');
      expect(result.isGroupMessage, isTrue);
    });

    test('returns null for own messages', () async {
      final result = await processor.processIncomingMessage(
        _makeEvent(senderId: 'alice'), // myUserId is 'alice'
      );

      expect(result, isNull);
    });

    test('returns null when no ciphertext targets our device', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);
      when(() => api.fetchCiphertexts(any())).thenAnswer(
        (_) async => [
          <String, dynamic>{
            'recipient_id': 'charlie',
            'recipient_device_id': 5,
            'ciphertext': 'bm90Zm9ydXM=',
          },
        ],
      );

      final result = await processor.processIncomingMessage(
        _makeEvent(messageId: 'msg-other'),
      );

      expect(result, isNull);
    });

    test('skips already cached plaintext', () async {
      when(() => decryptedCache.getCachedPlaintext('msg-cached'))
          .thenAnswer((_) async => 'Hello, world!');

      final result = await processor.processIncomingMessage(
        _makeEvent(messageId: 'msg-cached'),
      );

      expect(result, isNull);
      // Should never fetch ciphertexts for cached messages.
      verifyNever(() => api.fetchCiphertexts(any()));
    });

    test('clearDedup resets all dedup state', () async {
      when(() => decryptedCache.getCachedPlaintext(any()))
          .thenAnswer((_) async => null);
      when(() => api.fetchCiphertexts(any())).thenAnswer(
        (_) async => [
          <String, dynamic>{
            'recipient_id': 'alice',
            'recipient_device_id': 1,
            'ciphertext': 'dGVzdA==',
          },
        ],
      );

      final event = _makeEvent(messageId: 'msg-reset');

      // Process once.
      await processor.processIncomingMessage(event);

      // Clear dedup.
      processor.clearDedup();

      // Should be processable again.
      final result = await processor.processIncomingMessage(event);
      expect(result, isNotNull);
    });
  });

  // =========================================================================
  // SyncCoordinator
  // =========================================================================

  group('SyncCoordinator', () {
    late OutboxProcessor outboxProcessor;
    late GapDetector gapDetector;
    late MockRealtimeListener realtimeListener;
    late MockReceiptRepository receiptRepo;
    late SyncCoordinator coordinator;

    // We need real OutboxProcessor and GapDetector with mocked deps.
    late MockOutboxRepository outboxRepo;
    late MockSupabaseClientWrapper api;
    late MockMessageRepository messageRepo;

    setUp(() {
      outboxRepo = MockOutboxRepository();
      api = MockSupabaseClientWrapper();
      messageRepo = MockMessageRepository();
      receiptRepo = MockReceiptRepository();
      realtimeListener = MockRealtimeListener();

      outboxProcessor = OutboxProcessor(
        outboxRepository: outboxRepo,
        apiClient: api,
      );
      gapDetector = GapDetector(
        apiClient: api,
        messageRepo: messageRepo,
      );

      coordinator = SyncCoordinator(
        outboxProcessor: outboxProcessor,
        gapDetector: gapDetector,
        realtimeListener: realtimeListener,
        receiptRepo: receiptRepo,
      );
    });

    test('onConnected calls gap detector then outbox processor', () async {
      when(
        () => messageRepo.getMessages(any(), limit: 1),
      ).thenAnswer((_) async => []);
      when(
        () => api.fetchMessageHistory(any()),
      ).thenAnswer((_) async => []);
      when(
        () => outboxRepo.getPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      final missed = await coordinator.onConnected(['space-1']);

      expect(missed, isEmpty);
      verify(
        () => messageRepo.getMessages('space-1', limit: 1),
      ).called(1);
      verify(
        () => outboxRepo.getPending(limit: any(named: 'limit')),
      ).called(1);
    });

    test('emits incoming message events from subscriptions', () async {
      final controller =
          StreamController<RealtimeMessageEvent>.broadcast();

      when(() => realtimeListener.subscribeToSpace('space-1'))
          .thenAnswer((_) => controller.stream);

      coordinator.subscribeToSpace('space-1');

      final events = <RealtimeMessageEvent>[];
      final sub = coordinator.incomingMessages.listen(events.add);

      controller.add(_makeEvent());

      // Allow the stream to propagate.
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.messageId, 'msg-1');

      await sub.cancel();
      await controller.close();
    });

    test('subscribeToSpace is idempotent', () async {
      final controller =
          StreamController<RealtimeMessageEvent>.broadcast();

      when(() => realtimeListener.subscribeToSpace('space-1'))
          .thenAnswer((_) => controller.stream);

      coordinator
        ..subscribeToSpace('space-1')
        ..subscribeToSpace('space-1');

      // Should only subscribe once.
      verify(() => realtimeListener.subscribeToSpace('space-1'))
          .called(1);

      await controller.close();
    });

    test('emitTyping forwards to typingEvents stream', () async {
      final events = <TypingIndicator>[];
      final sub = coordinator.typingEvents.listen(events.add);

      coordinator.emitTyping(
        TypingIndicator(
          groupId: 'space-1',
          userId: 'bob',
          startedAt: DateTime(2025, 6),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.userId, 'bob');

      await sub.cancel();
    });

    test('emitPresence forwards to presenceEvents stream', () async {
      final events = <PresenceState>[];
      final sub = coordinator.presenceEvents.listen(events.add);

      coordinator.emitPresence(
        PresenceState(userId: 'bob', isOnline: true),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.isOnline, isTrue);

      await sub.cancel();
    });

    test('unsubscribeFromSpace cancels subscription', () async {
      final controller =
          StreamController<RealtimeMessageEvent>.broadcast();

      when(() => realtimeListener.subscribeToSpace('space-1'))
          .thenAnswer((_) => controller.stream);
      when(() => realtimeListener.unsubscribeFromSpace('space-1'))
          .thenAnswer((_) async {});

      coordinator.subscribeToSpace('space-1');
      await coordinator.unsubscribeFromSpace('space-1');

      verify(() => realtimeListener.unsubscribeFromSpace('space-1'))
          .called(1);

      await controller.close();
    });

    test('dispose closes all streams', () async {
      when(() => realtimeListener.dispose()).thenAnswer((_) async {});

      await coordinator.dispose();

      // After dispose, streams should be closed.
      // Adding events should not throw, just be silently ignored.
      coordinator.emitTyping(
        TypingIndicator(
          groupId: 'x',
          userId: 'y',
          startedAt: DateTime.now(),
        ),
      );
    });
  });
}
