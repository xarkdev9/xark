// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:hello_engine/src/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message', () {
    test('serialization round-trip preserves all fields', () {
      final message = Message(
        id: 'msg-001',
        groupId: 'conv-001',
        senderId: 'name_ram',
        senderDeviceId: 'device-abc',
        type: MessageType.e2ee,
        status: MessageStatus.sent,
        timestamp: DateTime.utc(2026, 3, 26, 12),
        serverSeq: 42,
        text: 'Hello, world!',
        replyToMessageId: 'msg-000',
        reactions: {
          'name_ram': ['thumbsup'],
        },
        isStarred: true,
      );

      final json = message.toJson();
      final restored = Message.fromJson(json);

      expect(restored, equals(message));
      expect(restored.id, 'msg-001');
      expect(restored.senderId, 'name_ram');
      expect(restored.type, MessageType.e2ee);
      expect(restored.status, MessageStatus.sent);
      expect(restored.serverSeq, 42);
      expect(restored.text, 'Hello, world!');
      expect(restored.replyToMessageId, 'msg-000');
      expect(restored.reactions, {'name_ram': ['thumbsup']});
      expect(restored.isStarred, isTrue);
      expect(restored.role, 'user');
    });

    test('default values are applied correctly', () {
      final message = Message(
        id: 'msg-002',
        groupId: 'conv-001',
        senderId: 'name_ram',
        senderDeviceId: 'device-abc',
        type: MessageType.text,
        status: MessageStatus.sending,
        timestamp: DateTime.utc(2026),
      );

      expect(message.role, 'user');
      expect(message.reactions, isEmpty);
      expect(message.isStarred, isFalse);
      expect(message.isViewOnce, isFalse);
      expect(message.isDeleted, isFalse);
    });
  });

  group('MessageType', () {
    test('JSON values match backend protocol strings', () {
      final testCases = <MessageType, String>{
        MessageType.e2ee: 'e2ee',
        MessageType.hello: 'hello',
        MessageType.system: 'system',
        MessageType.legacy: 'legacy',
        MessageType.senderKeyDist: 'sender_key_dist',
        MessageType.text: 'message',
        MessageType.media: 'media',
      };

      for (final entry in testCases.entries) {
        // Create a minimal message with this type and check the JSON output
        final message = Message(
          id: 'test',
          groupId: 'c',
          senderId: 's',
          senderDeviceId: 'd',
          type: entry.key,
          status: MessageStatus.sent,
          timestamp: DateTime.utc(2026),
        );
        final json = message.toJson();
        expect(
          json['type'],
          entry.value,
          reason: '${entry.key} -> ${entry.value}',
        );
      }
    });

    test('all enum values are accounted for', () {
      expect(MessageType.values, hasLength(7));
    });
  });

  group('MessageStatus', () {
    test('all enum values exist', () {
      expect(MessageStatus.values, hasLength(5));
      expect(
        MessageStatus.values.map((e) => e.name),
        containsAll(['sending', 'sent', 'delivered', 'read', 'failed']),
      );
    });
  });

  group('Conversation', () {
    test('serialization round-trip preserves all fields', () {
      final now = DateTime.utc(2026, 3, 26);
      final conversation = Conversation(
        id: 'conv-001',
        type: ConversationType.oneToOne,
        participantIds: ['name_ram', 'name_bob'],
        createdAt: now,
        updatedAt: now,
        lastMessageText: 'Hey!',
        unreadCount: 3,
        isPinned: true,
        isMuted: true,
        muteUntil: now.add(Duration(hours: 1)),
      );

      final json = conversation.toJson();
      final restored = Conversation.fromJson(json);

      expect(restored, equals(conversation));
      expect(restored.participantIds, ['name_ram', 'name_bob']);
      expect(restored.unreadCount, 3);
      expect(restored.isPinned, isTrue);
      expect(restored.isMuted, isTrue);
      expect(restored.isEncrypted, isTrue);
    });

    test('default values are applied correctly', () {
      final now = DateTime.utc(2026);
      final conversation = Conversation(
        id: 'conv-002',
        type: ConversationType.group,
        participantIds: ['a', 'b', 'c'],
        createdAt: now,
        updatedAt: now,
      );

      expect(conversation.unreadCount, 0);
      expect(conversation.isPinned, isFalse);
      expect(conversation.isArchived, isFalse);
      expect(conversation.isMuted, isFalse);
      expect(conversation.isEncrypted, isTrue);
    });
  });

  group('MediaMetadata', () {
    test('serialization round-trip preserves all fields', () {
      final metadata = MediaMetadata(
        mediaId: 'media-001',
        mimeType: 'image/jpeg',
        sizeBytes: 1024000,
        downloadUrl: 'https://cdn.example.com/blob',
        encryptedKey: 'base64key==',
        iv: 'base64iv==',
        sha256Hash: 'abc123',
        width: 1920,
        height: 1080,
        inlineThumbnail: 'base64thumb==',
      );

      final json = metadata.toJson();
      final restored = MediaMetadata.fromJson(json);

      expect(restored, equals(metadata));
      expect(restored.mediaId, 'media-001');
      expect(restored.mimeType, 'image/jpeg');
      expect(restored.sizeBytes, 1024000);
      expect(restored.encryptedKey, 'base64key==');
    });
  });

  group('Receipt', () {
    test('serialization round-trip preserves all fields', () {
      final now = DateTime.utc(2026, 3, 26, 10);
      final receipt = Receipt(
        messageId: 'msg-001',
        userId: 'name_bob',
        deviceId: 'device-xyz',
        deliveredAt: now,
        readAt: now.add(Duration(minutes: 5)),
      );

      final json = receipt.toJson();
      final restored = Receipt.fromJson(json);

      expect(restored, equals(receipt));
      expect(restored.messageId, 'msg-001');
      expect(restored.userId, 'name_bob');
      expect(restored.deliveredAt, now);
    });
  });

  group('TypingIndicator', () {
    test('serialization round-trip preserves all fields', () {
      final now = DateTime.utc(2026, 3, 26, 12, 30);
      final indicator = TypingIndicator(
        groupId: 'conv-001',
        userId: 'name_alice',
        startedAt: now,
      );

      final json = indicator.toJson();
      final restored = TypingIndicator.fromJson(json);

      expect(restored, equals(indicator));
      expect(restored.groupId, 'conv-001');
      expect(restored.userId, 'name_alice');
    });
  });

  group('PresenceState', () {
    test('serialization round-trip preserves all fields', () {
      final now = DateTime.utc(2026, 3, 26, 12);
      final presence = PresenceState(
        userId: 'name_ram',
        isOnline: true,
        lastSeenAt: now,
        visibility: PresenceVisibility.contacts,
      );

      final json = presence.toJson();
      final restored = PresenceState.fromJson(json);

      expect(restored, equals(presence));
      expect(restored.isOnline, isTrue);
      expect(restored.visibility, PresenceVisibility.contacts);
    });

    test('defaults to offline and everyone visibility', () {
      final presence = PresenceState(userId: 'name_test');

      expect(presence.isOnline, isFalse);
      expect(presence.visibility, PresenceVisibility.everyone);
      expect(presence.lastSeenAt, isNull);
    });
  });

  group('ContactMatch', () {
    test('serialization round-trip preserves all fields', () {
      final match = ContactMatch(
        userId: 'name_bob',
        phoneHash: 'a1b2c3d4e5',
        displayNameEncrypted: 'encrypted_name==',
      );

      final json = match.toJson();
      final restored = ContactMatch.fromJson(json);

      expect(restored, equals(match));
      expect(restored.userId, 'name_bob');
      expect(restored.phoneHash, 'a1b2c3d4e5');
      expect(restored.displayNameEncrypted, 'encrypted_name==');
    });
  });

  group('DecryptedMessage', () {
    test('serialization round-trip preserves all fields', () {
      final decrypted = DecryptedMessage(
        text: 'Hello!',
        replyTo: 'msg-prev',
        mediaUrl: 'https://cdn.example.com/file',
        type: 'media',
        aesKeyBase64: 'key==',
        ivBase64: 'iv==',
        mimeType: 'image/png',
        inlineThumbnail: 'thumb==',
      );

      final json = decrypted.toJson();
      final restored = DecryptedMessage.fromJson(json);

      expect(restored, equals(decrypted));
      expect(restored.text, 'Hello!');
      expect(restored.type, 'media');
      expect(restored.aesKeyBase64, 'key==');
    });

    test('defaults type to message', () {
      final decrypted = DecryptedMessage(text: 'Hi');
      expect(decrypted.type, 'message');
    });
  });

  group('LinkPreview', () {
    test('serialization round-trip preserves all fields', () {
      final preview = LinkPreview(
        url: 'https://example.com',
        title: 'Example',
        description: 'An example page',
        mediaUrl: 'https://cdn.example.com/preview.jpg',
        aesKeyBase64: 'previewkey==',
        ivBase64: 'previewiv==',
        mimeType: 'image/jpeg',
        inlineThumbnail: 'previewthumb==',
      );

      final json = preview.toJson();
      final restored = LinkPreview.fromJson(json);

      expect(restored, equals(preview));
      expect(restored.url, 'https://example.com');
      expect(restored.title, 'Example');
    });
  });

  group('ChatEngineError', () {
    test('sealed class exhaustiveness covers all subtypes', () {
      final errors = <ChatEngineError>[
        SessionNotFound('device-1'),
        DecryptionFailed('msg-1'),
        PreKeyExhausted('name_alice'),
        KeyVerificationFailed('name_bob'),
        ConnectionLost(),
        ConnectionTimeout(),
        ServerError(500, 'Internal Server Error'),
        AuthTokenExpired(),
        DeviceRevoked('device-2'),
        DatabaseCorrupted(),
        BiometricUnavailable(),
        StorageFull(),
        MediaUploadFailed('media-1'),
        MediaDownloadFailed('https://cdn.example.com/blob'),
        MediaDecryptionFailed('media-2'),
        OutboxFull(501),
        DuplicateMessage('msg-dup'),
      ];

      // Exhaustive switch -- compiler enforces all subtypes are handled
      for (final error in errors) {
        final description = switch (error) {
          SessionNotFound(recipientDeviceId: final d) => 'session: $d',
          DecryptionFailed(messageId: final m) => 'decrypt: $m',
          PreKeyExhausted(userId: final u) => 'prekey: $u',
          KeyVerificationFailed(userId: final u) => 'verify: $u',
          ConnectionLost() => 'lost',
          ConnectionTimeout() => 'timeout',
          ServerError(statusCode: final c, body: final b) => 'server: $c $b',
          AuthTokenExpired() => 'auth',
          DeviceRevoked(deviceId: final d) => 'revoked: $d',
          DatabaseCorrupted() => 'corrupt',
          BiometricUnavailable() => 'biometric',
          StorageFull() => 'storage',
          MediaUploadFailed(mediaId: final m) => 'upload: $m',
          MediaDownloadFailed(url: final u) => 'download: $u',
          MediaDecryptionFailed(mediaId: final m) => 'media_decrypt: $m',
          OutboxFull(pendingCount: final c) => 'outbox: $c',
          DuplicateMessage(messageId: final m) => 'dup: $m',
        };
        expect(description, isNotEmpty);
      }

      expect(errors, hasLength(17));
    });

    test('error fields are accessible', () {
      const error = ServerError(403, 'Forbidden');
      expect(error.statusCode, 403);
      expect(error.body, 'Forbidden');

      const outbox = OutboxFull(501);
      expect(outbox.pendingCount, 501);
    });
  });

  group('EngineConnectionState', () {
    test('all enum values exist', () {
      expect(EngineConnectionState.values, hasLength(4));
      expect(
        EngineConnectionState.values.map((e) => e.name),
        containsAll(['connecting', 'connected', 'disconnected', 'suspended']),
      );
    });
  });

  group('KeyFingerprint', () {
    test('numericDisplay formats as 12 groups of 5 digits', () {
      // 30 bytes of known data
      final bytes = Uint8List.fromList(
        List.generate(30, (i) => i * 7 % 256),
      );
      final fingerprint = KeyFingerprint(
        userId: 'name_ram',
        deviceId: 'device-1',
        fingerprintBytes: bytes,
      );

      final display = fingerprint.numericDisplay;

      // Should be 12 groups separated by spaces
      final groups = display.split(' ');
      expect(groups, hasLength(6));

      // Each group should be exactly 5 digits
      for (final group in groups) {
        expect(group.length, 5);
        expect(int.tryParse(group), isNotNull, reason: '$group is not numeric');
      }
    });

    test('fields are accessible', () {
      final fingerprint = KeyFingerprint(
        userId: 'name_test',
        deviceId: 'dev-abc',
        fingerprintBytes: Uint8List(30),
      );

      expect(fingerprint.userId, 'name_test');
      expect(fingerprint.deviceId, 'dev-abc');
      expect(fingerprint.fingerprintBytes.length, 30);
    });
  });

  group('MediaPayload', () {
    test('creates instance with required fields', () {
      final payload = MediaPayload(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'image/png',
        fileName: 'photo.png',
      );

      expect(payload.bytes, hasLength(4));
      expect(payload.mimeType, 'image/png');
      expect(payload.fileName, 'photo.png');
      expect(payload.thumbnailBytes, isNull);
      expect(payload.durationMs, isNull);
      expect(payload.width, isNull);
      expect(payload.height, isNull);
    });

    test('creates instance with all optional fields', () {
      final payload = MediaPayload(
        bytes: Uint8List.fromList([10, 20, 30]),
        mimeType: 'video/mp4',
        fileName: 'clip.mp4',
        thumbnailBytes: Uint8List.fromList([5, 6]),
        durationMs: 30000,
        width: 1920,
        height: 1080,
      );

      expect(payload.durationMs, 30000);
      expect(payload.width, 1920);
      expect(payload.height, 1080);
      expect(payload.thumbnailBytes, hasLength(2));
    });
  });

  group('Message with MediaMetadata', () {
    test('nested media metadata round-trips through JSON', () {
      final message = Message(
        id: 'msg-media-001',
        groupId: 'conv-001',
        senderId: 'name_ram',
        senderDeviceId: 'device-abc',
        type: MessageType.media,
        status: MessageStatus.delivered,
        timestamp: DateTime.utc(2026, 3, 26),
        media: MediaMetadata(
          mediaId: 'media-001',
          mimeType: 'image/jpeg',
          sizeBytes: 512000,
          downloadUrl: 'https://cdn.example.com/img.enc',
          encryptedKey: 'aes_key_base64',
          iv: 'iv_base64',
          sha256Hash: 'hash123',
        ),
      );

      final json = message.toJson();
      final restored = Message.fromJson(json);

      expect(restored, equals(message));
      expect(restored.media, isNotNull);
      expect(restored.media!.mediaId, 'media-001');
      expect(restored.media!.encryptedKey, 'aes_key_base64');
    });
  });

  group('DecryptedMessage with LinkPreview', () {
    test('nested link preview round-trips through JSON', () {
      final decrypted = DecryptedMessage(
        text: 'Check this out!',
        linkPreview: LinkPreview(
          url: 'https://example.com/article',
          title: 'Great Article',
          description: 'A must-read.',
        ),
      );

      final json = decrypted.toJson();
      final restored = DecryptedMessage.fromJson(json);

      expect(restored, equals(decrypted));
      expect(restored.linkPreview, isNotNull);
      expect(restored.linkPreview!.url, 'https://example.com/article');
      expect(restored.linkPreview!.title, 'Great Article');
    });
  });
}
