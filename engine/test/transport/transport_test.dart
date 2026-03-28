// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/realtime_event.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageEnvelope', () {
    test('serialises to snake_case JSON', () {
      final envelope = MessageEnvelope(
        groupId: 'space-123',
        senderDeviceId: 1,
        ciphertext: 'Y2lwaGVydGV4dA==',
        recipientId: 'name_bob',
        recipientDeviceId: 2,
        ratchetHeader: 'aGVhZGVy',
        id: 'msg-uuid-1',
      );

      final json = envelope.toJson();

      expect(json['group_id'], 'space-123');
      expect(json['sender_device_id'], 1);
      expect(json['ciphertext'], 'Y2lwaGVydGV4dA==');
      expect(json['ratchet_header'], 'aGVhZGVy');
      expect(json['recipient_id'], 'name_bob');
      expect(json['recipient_device_id'], 2);
      expect(json['distribution_ciphertexts'], isEmpty);
      expect(json['message_type'], 'e2ee');
      expect(json['id'], 'msg-uuid-1');
    });

    test('round-trips through JSON', () {
      final original = MessageEnvelope(
        groupId: 'space-abc',
        senderDeviceId: 3,
        ciphertext: 'dGVzdA==',
        recipientId: '_group_',
        recipientDeviceId: 0,
        distributionCiphertexts: [
          DistributionCiphertext(
            id: 'mc_uuid-1',
            recipientId: 'name_alice',
            recipientDeviceId: 1,
            ciphertext: 'ZGlzdA==',
            ratchetHeader: 'cmF0Y2hldA==',
          ),
        ],
        messageType: 'sender_key_dist',
      );

      final json = original.toJson();
      final restored = MessageEnvelope.fromJson(json);

      expect(restored.groupId, original.groupId);
      expect(restored.senderDeviceId, original.senderDeviceId);
      expect(restored.ciphertext, original.ciphertext);
      expect(restored.ratchetHeader, isNull);
      expect(restored.recipientId, '_group_');
      expect(restored.recipientDeviceId, 0);
      expect(restored.distributionCiphertexts, hasLength(1));
      expect(restored.messageType, 'sender_key_dist');
      expect(restored.id, isNull);
    });

    test('defaults messageType to e2ee', () {
      final json = <String, dynamic>{
        'group_id': 's1',
        'sender_device_id': 1,
        'ciphertext': 'ct',
        'recipient_id': 'u1',
        'recipient_device_id': 1,
      };

      final envelope = MessageEnvelope.fromJson(json);
      expect(envelope.messageType, 'e2ee');
    });

    test('defaults distributionCiphertexts to empty list', () {
      final envelope = MessageEnvelope(
        groupId: 's1',
        senderDeviceId: 1,
        ciphertext: 'ct',
        recipientId: 'u1',
        recipientDeviceId: 1,
      );

      expect(envelope.distributionCiphertexts, isEmpty);
    });
  });

  group('DistributionCiphertext', () {
    test('serialises to snake_case JSON', () {
      final dc = DistributionCiphertext(
        id: 'mc_abc-123',
        recipientId: 'name_carol',
        recipientDeviceId: 2,
        ciphertext: 'ZW5jcnlwdGVk',
        ratchetHeader: 'aGRy',
      );

      final json = dc.toJson();

      expect(json['id'], 'mc_abc-123');
      expect(json['recipient_id'], 'name_carol');
      expect(json['recipient_device_id'], 2);
      expect(json['ciphertext'], 'ZW5jcnlwdGVk');
      expect(json['ratchet_header'], 'aGRy');
    });

    test('round-trips through JSON', () {
      final original = DistributionCiphertext(
        id: 'mc_xyz',
        recipientId: 'name_dave',
        recipientDeviceId: 5,
        ciphertext: 'Y3Q=',
      );

      final restored =
          DistributionCiphertext.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.recipientId, original.recipientId);
      expect(restored.recipientDeviceId, original.recipientDeviceId);
      expect(restored.ciphertext, original.ciphertext);
      expect(restored.ratchetHeader, isNull);
    });

    test('mc_ prefix convention', () {
      final dc = DistributionCiphertext(
        id: 'mc_550e8400-e29b-41d4-a716-446655440000',
        recipientId: 'u1',
        recipientDeviceId: 1,
        ciphertext: 'ct',
      );

      expect(dc.id, startsWith('mc_'));
    });
  });

  group('groupRecipientSentinel', () {
    test('equals _group_', () {
      expect(groupRecipientSentinel, '_group_');
    });

    test('group envelope uses _group_ as recipientId', () {
      final envelope = MessageEnvelope(
        groupId: 'space-grp',
        senderDeviceId: 1,
        ciphertext: 'ct',
        recipientId: groupRecipientSentinel,
        recipientDeviceId: 0,
      );

      expect(envelope.recipientId, '_group_');
      expect(envelope.recipientDeviceId, 0);
    });
  });

  group('RealtimeMessageEvent', () {
    test('constructs from Postgres payload', () {
      final record = <String, dynamic>{
        'id': 'msg-1',
        'group_id': 'space-abc',
        'user_id': 'name_alice',
        'sender_device_id': 1,
        'message_type': 'e2ee',
        'created_at': '2026-03-26T10:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);

      expect(event.messageId, 'msg-1');
      expect(event.groupId, 'space-abc');
      expect(event.senderId, 'name_alice');
      expect(event.senderDeviceId, 1);
      expect(event.messageType, 'e2ee');
      expect(event.createdAt, DateTime.utc(2026, 3, 26, 10));
    });

    test('handles null sender_device_id for system messages', () {
      final record = <String, dynamic>{
        'id': 'sys-msg',
        'group_id': 'space-abc',
        'user_id': 'system',
        'sender_device_id': null,
        'message_type': 'system',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);

      expect(event.senderDeviceId, isNull);
      expect(event.messageType, 'system');
    });

    test('defaults message_type to e2ee when missing', () {
      final record = <String, dynamic>{
        'id': 'msg-2',
        'group_id': 'sp',
        'user_id': 'u1',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);
      expect(event.messageType, 'e2ee');
    });

    test('toString includes key fields', () {
      final event = RealtimeMessageEvent(
        messageId: 'm1',
        groupId: 's1',
        senderId: 'u1',
        messageType: 'e2ee',
        createdAt: DateTime.utc(2026),
      );

      final str = event.toString();
      expect(str, contains('m1'));
      expect(str, contains('s1'));
      expect(str, contains('u1'));
    });
  });

  group('SKRecoveryRequest', () {
    test('constructs from broadcast payload', () {
      final payload = <String, dynamic>{
        'requester_id': 'name_bob',
        'requester_device_id': 2,
        'target_sender_id': 'name_alice',
        'group_id': 'group-xyz',
      };

      final request = SKRecoveryRequest.fromBroadcastPayload(payload);

      expect(request.requesterId, 'name_bob');
      expect(request.requesterDeviceId, 2);
      expect(request.targetSenderId, 'name_alice');
      expect(request.groupId, 'group-xyz');
    });

    test('round-trips through broadcast payload', () {
      final original = SKRecoveryRequest(
        requesterId: 'name_carol',
        requesterDeviceId: 3,
        targetSenderId: 'name_dave',
        groupId: 'grp-1',
      );

      final payload = original.toBroadcastPayload();
      final restored = SKRecoveryRequest.fromBroadcastPayload(payload);

      expect(restored.requesterId, original.requesterId);
      expect(restored.requesterDeviceId, original.requesterDeviceId);
      expect(restored.targetSenderId, original.targetSenderId);
      expect(restored.groupId, original.groupId);
    });

    test('toBroadcastPayload uses snake_case keys', () {
      final request = SKRecoveryRequest(
        requesterId: 'u1',
        requesterDeviceId: 1,
        targetSenderId: 'u2',
        groupId: 's1',
      );

      final payload = request.toBroadcastPayload();
      expect(payload.containsKey('requester_id'), isTrue);
      expect(payload.containsKey('requester_device_id'), isTrue);
      expect(payload.containsKey('target_sender_id'), isTrue);
      expect(payload.containsKey('group_id'), isTrue);
    });

    test('toString includes key fields', () {
      final request = SKRecoveryRequest(
        requesterId: 'u1',
        requesterDeviceId: 1,
        targetSenderId: 'u2',
        groupId: 's1',
      );

      final str = request.toString();
      expect(str, contains('u1'));
      expect(str, contains('u2'));
      expect(str, contains('s1'));
    });
  });

  group('ApiException', () {
    test('toString includes status code and body', () {
      final ex = ApiException(401, '{"error":"unauthorized"}');
      expect(ex.toString(), contains('401'));
      expect(ex.toString(), contains('unauthorized'));
    });

    test('exposes statusCode and body', () {
      final ex = ApiException(500, 'internal error');
      expect(ex.statusCode, 500);
      expect(ex.body, 'internal error');
    });
  });

  group('MessageEnvelope wire format', () {
    test('matches server-expected JSON structure', () {
      final envelope = MessageEnvelope(
        groupId: 'space-1',
        senderDeviceId: 1,
        ciphertext: base64Encode([1, 2, 3]),
        recipientId: 'name_peer',
        recipientDeviceId: 1,
        ratchetHeader: base64Encode([4, 5, 6]),
        distributionCiphertexts: [
          DistributionCiphertext(
            id: 'mc_d1',
            recipientId: 'name_peer',
            recipientDeviceId: 1,
            ciphertext: base64Encode([7, 8, 9]),
          ),
        ],
      );

      final json = envelope.toJson();

      // Verify all expected keys are snake_case.
      expect(json.containsKey('group_id'), isTrue);
      expect(json.containsKey('sender_device_id'), isTrue);
      expect(json.containsKey('recipient_id'), isTrue);
      expect(json.containsKey('recipient_device_id'), isTrue);
      expect(json.containsKey('ratchet_header'), isTrue);
      expect(json.containsKey('distribution_ciphertexts'), isTrue);
      expect(json.containsKey('message_type'), isTrue);

      // Verify no camelCase keys leaked through.
      expect(json.containsKey('groupId'), isFalse);
      expect(json.containsKey('senderDeviceId'), isFalse);
      expect(json.containsKey('recipientId'), isFalse);
      expect(json.containsKey('recipientDeviceId'), isFalse);
      expect(json.containsKey('ratchetHeader'), isFalse);
      expect(json.containsKey('distributionCiphertexts'), isFalse);
      expect(json.containsKey('messageType'), isFalse);

      // Verify nested distribution ciphertext also uses snake_case.
      final dcList = json['distribution_ciphertexts'] as List<dynamic>;
      final dc = dcList.first as Map<String, dynamic>;
      expect(dc.containsKey('recipient_id'), isTrue);
      expect(dc.containsKey('recipient_device_id'), isTrue);
      expect(dc.containsKey('ratchet_header'), isTrue);
    });

    test('can be JSON-encoded and decoded for HTTP body', () {
      final envelope = MessageEnvelope(
        groupId: 's1',
        senderDeviceId: 1,
        ciphertext: 'ct',
        recipientId: 'u1',
        recipientDeviceId: 1,
      );

      final jsonString = jsonEncode(envelope.toJson());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = MessageEnvelope.fromJson(decoded);

      expect(restored.groupId, 's1');
      expect(restored.senderDeviceId, 1);
      expect(restored.ciphertext, 'ct');
    });
  });
}
