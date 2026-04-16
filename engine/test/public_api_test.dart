// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/chat_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concrete no-op observer for testing.
class _TestObserver extends ChatEngineObserver {}

void main() {
  group('ChatEngineConfig', () {
    test('stores all required fields', () {
      final config = ChatEngineConfig(
        authToken: 'tok-123',
        userId: 'user_alice',
        deviceId: 42,
        pushToken: 'fcm-token-abc',
        serverBaseUrl: Uri.parse('https://api.example.com'),
      );

      expect(config.authToken, 'tok-123');
      expect(config.userId, 'user_alice');
      expect(config.deviceId, 42);
      expect(config.pushToken, 'fcm-token-abc');
      expect(
        config.serverBaseUrl.toString(),
        'https://api.example.com',
      );
    });

    test('defaults supabaseAnonKey to empty string', () {
      final config = ChatEngineConfig(
        authToken: 'tok',
        userId: 'u1',
        deviceId: 1,
        pushToken: 'pt',
        serverBaseUrl: Uri.parse('https://example.com'),
      );

      expect(config.supabaseAnonKey, '');
    });

    test('defaults observer to null', () {
      final config = ChatEngineConfig(
        authToken: 'tok',
        userId: 'u1',
        deviceId: 1,
        pushToken: 'pt',
        serverBaseUrl: Uri.parse('https://example.com'),
      );

      expect(config.observer, isNull);
    });

    test('accepts all optional fields', () {
      final observer = _TestObserver();
      final config = ChatEngineConfig(
        authToken: 'tok-full',
        userId: 'user_bob',
        deviceId: 7,
        pushToken: 'apns-token',
        serverBaseUrl: Uri.parse('wss://chat.example.com'),
        supabaseAnonKey: 'anon-key-xyz',
        observer: observer,
      );

      expect(config.authToken, 'tok-full');
      expect(config.userId, 'user_bob');
      expect(config.deviceId, 7);
      expect(config.pushToken, 'apns-token');
      expect(
        config.serverBaseUrl.toString(),
        'wss://chat.example.com',
      );
      expect(config.supabaseAnonKey, 'anon-key-xyz');
      expect(config.observer, same(observer));
    });

    test('supports different serverBaseUrl schemes', () {
      final httpConfig = ChatEngineConfig(
        authToken: 'a',
        userId: 'u',
        deviceId: 1,
        pushToken: 'p',
        serverBaseUrl: Uri.parse('http://localhost:3000'),
      );

      final wssConfig = ChatEngineConfig(
        authToken: 'a',
        userId: 'u',
        deviceId: 1,
        pushToken: 'p',
        serverBaseUrl: Uri.parse('wss://prod.example.com/ws'),
      );

      expect(httpConfig.serverBaseUrl.scheme, 'http');
      expect(wssConfig.serverBaseUrl.scheme, 'wss');
    });
  });

  group('ChatEngineObserver', () {
    test('all no-op methods execute without throwing', () {
      final observer = _TestObserver();

      // Crypto events
      expect(
        () => observer.onSessionEstablished('u1', 1),
        returnsNormally,
      );
      expect(
        () => observer.onSessionFailed(
          'u1',
          1,
          SessionNotFound('d1'),
        ),
        returnsNormally,
      );

      // Key management events
      expect(
        () => observer.onPreKeyReplenishment(50, 100),
        returnsNormally,
      );

      // Sync events
      expect(
        () => observer.onSyncCompleted(
          10,
          Duration(milliseconds: 500),
        ),
        returnsNormally,
      );
      expect(
        () => observer.onOutboxDrained(5, 0),
        returnsNormally,
      );
      expect(
        () => observer.onRatchetAdvanced('session-1', 42),
        returnsNormally,
      );

      // Media events
      expect(
        () => observer.onMediaUpload(
          'media-1',
          1024,
          Duration(seconds: 2),
        ),
        returnsNormally,
      );
      expect(
        () => observer.onMediaDownload(
          'media-2',
          2048,
          Duration(seconds: 1),
        ),
        returnsNormally,
      );

      // Transport events
      expect(
        () => observer.onWebSocketStateChange(
          EngineConnectionState.disconnected,
          EngineConnectionState.connected,
        ),
        returnsNormally,
      );

      // Contact discovery
      expect(
        () => observer.onContactDiscovery(100, 15),
        returnsNormally,
      );

      // Profile key rotation
      expect(
        () => observer.onProfileKeyRotation('u1'),
        returnsNormally,
      );

      // Device management
      expect(
        () => observer.onDeviceLinked('device-2'),
        returnsNormally,
      );
      expect(
        () => observer.onDeviceRevoked('device-3'),
        returnsNormally,
      );
    });
  });

  group('Public type availability', () {
    test('domain models are accessible from barrel export', () {
      // Verify all public domain types are importable and constructible
      // from the barrel file.
      final conversation = Conversation(
        id: 'conv-1',
        type: ConversationType.oneToOne,
        participantIds: const ['alice', 'bob'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(conversation.id, 'conv-1');

      final message = Message(
        id: 'msg-1',
        groupId: 'conv-1',
        senderId: 'alice',
        senderDeviceId: '1',
        type: MessageType.e2ee,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
      );
      expect(message.id, 'msg-1');

      final receipt = Receipt(
        messageId: 'msg-1',
        userId: 'bob',
        deviceId: '1',
      );
      expect(receipt.messageId, 'msg-1');

      final typing = TypingIndicator(
        groupId: 'conv-1',
        userId: 'bob',
        startedAt: DateTime.now(),
      );
      expect(typing.userId, 'bob');

      final presence = PresenceState(userId: 'bob', isOnline: true);
      expect(presence.isOnline, isTrue);

      final contact = ContactMatch(
        userId: 'u1',
        phoneHash: 'abc123',
      );
      expect(contact.phoneHash, 'abc123');

      const connState = EngineConnectionState.connected;
      expect(connState, EngineConnectionState.connected);
    });

    test('error types are accessible from barrel export', () {
      const sessionErr = SessionNotFound('d1');
      expect(sessionErr, isA<ChatEngineError>());

      const decryptErr = DecryptionFailed('m1');
      expect(decryptErr, isA<ChatEngineError>());

      const preKeyErr = PreKeyExhausted('u1');
      expect(preKeyErr, isA<ChatEngineError>());

      const keyVerifyErr = KeyVerificationFailed('u1');
      expect(keyVerifyErr, isA<ChatEngineError>());

      const connLost = ConnectionLost();
      expect(connLost, isA<ChatEngineError>());

      const connTimeout = ConnectionTimeout();
      expect(connTimeout, isA<ChatEngineError>());

      const serverErr = ServerError(500, 'internal');
      expect(serverErr, isA<ChatEngineError>());

      const authErr = AuthTokenExpired();
      expect(authErr, isA<ChatEngineError>());

      const revokedErr = DeviceRevoked('d1');
      expect(revokedErr, isA<ChatEngineError>());

      const dbErr = DatabaseCorrupted();
      expect(dbErr, isA<ChatEngineError>());

      const bioErr = BiometricUnavailable();
      expect(bioErr, isA<ChatEngineError>());

      const storageErr = StorageFull();
      expect(storageErr, isA<ChatEngineError>());

      const uploadErr = MediaUploadFailed('m1');
      expect(uploadErr, isA<ChatEngineError>());

      const downloadErr = MediaDownloadFailed('url');
      expect(downloadErr, isA<ChatEngineError>());

      const mediaDecErr = MediaDecryptionFailed('m1');
      expect(mediaDecErr, isA<ChatEngineError>());

      const outboxErr = OutboxFull(501);
      expect(outboxErr, isA<ChatEngineError>());

      const dupErr = DuplicateMessage('m1');
      expect(dupErr, isA<ChatEngineError>());
    });

    test('media progress types are accessible from barrel export', () {
      const upload = UploadProgress(
        mediaId: 'media-1',
        phase: UploadPhase.uploading,
        bytesProcessed: 512,
        totalBytes: 1024,
      );
      expect(upload.mediaId, 'media-1');
      expect(upload.phase, UploadPhase.uploading);

      const download = DownloadProgress(
        mediaId: 'media-2',
        phase: DownloadPhase.decrypting,
      );
      expect(download.mediaId, 'media-2');
      expect(download.phase, DownloadPhase.decrypting);
    });

    test('abstract interfaces are accessible from barrel export', () {
      // ChatEngine and ChatSession are abstract -- verify their types
      // are importable and can be used as type annotations.
      ChatEngine castEngine(Object o) => o as ChatEngine;
      expect(castEngine, isA<Function>());

      ChatSession castSession(Object o) => o as ChatSession;
      expect(castSession, isA<Function>());
    });
  });
}
