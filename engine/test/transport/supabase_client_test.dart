// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

void main() {
  const apiBase = 'https://api.example.com';
  const authToken = 'test-jwt-token';

  /// Creates a [SupabaseClientWrapper] backed by a mock HTTP client.
  SupabaseClientWrapper buildWrapper(
    MockClient mockHttp,
  ) {
    final wrapper = SupabaseClientWrapper(
      // We pass a real SupabaseClient reference only for PostgREST calls
      // which we don't exercise in these HTTP-focused tests. The mock
      // HTTP client handles /api/* routes.
      client: _FakeSupabaseClient(),
      apiBaseUrl: apiBase,
      httpClient: mockHttp,
    );
    wrapper.authToken = authToken;
    return wrapper;
  }

  // -------------------------------------------------------------------------
  // sendMessage
  // -------------------------------------------------------------------------
  group('sendMessage', () {
    test('serialises MessageEnvelope to correct JSON body', () async {
      Map<String, dynamic>? capturedBody;

      final mock = MockClient((request) async {
        expect(request.url.toString(), '$apiBase/api/message');
        expect(request.method, 'POST');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'messageId': 'msg-1', 'distribution_written': true}),
          200,
        );
      });

      final wrapper = buildWrapper(mock);
      final envelope = MessageEnvelope(
        groupId: 'space-abc',
        senderDeviceId: 1,
        ciphertext: 'Y2lwaGVydGV4dA==',
        recipientId: 'name_bob',
        recipientDeviceId: 2,
        ratchetHeader: 'aGVhZGVy',
        id: 'client-uuid-1',
      );

      final result = await wrapper.sendMessage(envelope);

      expect(capturedBody, isNotNull);
      expect(capturedBody!['group_id'], 'space-abc');
      expect(capturedBody!['sender_device_id'], 1);
      expect(capturedBody!['ciphertext'], 'Y2lwaGVydGV4dA==');
      expect(capturedBody!['recipient_id'], 'name_bob');
      expect(capturedBody!['recipient_device_id'], 2);
      expect(capturedBody!['ratchet_header'], 'aGVhZGVy');
      expect(capturedBody!['message_type'], 'e2ee');
      expect(capturedBody!['id'], 'client-uuid-1');
      expect(result['messageId'], 'msg-1');
      expect(result['distribution_written'], true);
    });

    test('serialises group envelope with _group_ sentinel and '
        'distribution_ciphertexts', () async {
      Map<String, dynamic>? capturedBody;

      final mock = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'messageId': 'msg-2', 'distribution_written': true}),
          200,
        );
      });

      final wrapper = buildWrapper(mock);
      final envelope = MessageEnvelope(
        groupId: 'group-space',
        senderDeviceId: 3,
        ciphertext: 'Z3JvdXBfY3Q=',
        recipientId: '_group_',
        recipientDeviceId: 0,
        messageType: 'e2ee',
        distributionCiphertexts: [
          DistributionCiphertext(
            id: 'mc_dist-1',
            recipientId: 'name_alice',
            recipientDeviceId: 1,
            ciphertext: 'ZGlzdF9jdA==',
            ratchetHeader: 'ZGlzdF9oZHI=',
          ),
        ],
      );

      await wrapper.sendMessage(envelope);

      expect(capturedBody!['recipient_id'], '_group_');
      expect(capturedBody!['recipient_device_id'], 0);

      final dcs =
          capturedBody!['distribution_ciphertexts'] as List<dynamic>;
      expect(dcs, hasLength(1));
      final dc = dcs.first as Map<String, dynamic>;
      expect(dc['id'], startsWith('mc_'));
      expect(dc['recipient_id'], 'name_alice');
      expect(dc['recipient_device_id'], 1);
    });

    test('includes Authorization Bearer header', () async {
      final mock = MockClient((request) async {
        expect(
          request.headers['Authorization'],
          'Bearer $authToken',
        );
        expect(request.headers['Content-Type'], 'application/json');
        return http.Response(jsonEncode({'messageId': 'm'}), 200);
      });

      final wrapper = buildWrapper(mock);
      await wrapper.sendMessage(MessageEnvelope(
        groupId: 's',
        senderDeviceId: 1,
        ciphertext: 'ct',
        recipientId: 'u',
        recipientDeviceId: 1,
      ));
    });

    test('throws ApiException on non-2xx response', () async {
      final mock = MockClient((_) async {
        return http.Response('{"error":"rate limited"}', 429);
      });

      final wrapper = buildWrapper(mock);

      expect(
        () => wrapper.sendMessage(MessageEnvelope(
          groupId: 's',
          senderDeviceId: 1,
          ciphertext: 'ct',
          recipientId: 'u',
          recipientDeviceId: 1,
        )),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          429,
        )),
      );
    });
  });

  // -------------------------------------------------------------------------
  // fetchPeerKeyBundle
  // -------------------------------------------------------------------------
  group('fetchPeerKeyBundle', () {
    test('sends correct request and parses response per §2.4', () async {
      Map<String, dynamic>? capturedBody;

      final mock = MockClient((request) async {
        expect(request.url.toString(), '$apiBase/api/keys/fetch');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'identity_key': 'aWRlbnRpdHk=',
            'signed_pre_key': 'c3Br',
            'signed_pre_key_id': 1,
            'pre_key_sig': 'c2ln',
            'otk_public': 'b3RrcHVi',
            'otk_id': 'otk-42',
          }),
          200,
        );
      });

      final wrapper = buildWrapper(mock);
      final bundle = await wrapper.fetchPeerKeyBundle(
        userId: 'name_bob',
        deviceId: 1,
      );

      // Verify request body matches CODEBASE_CONTEXT.md §2.4
      expect(capturedBody!['user_id'], 'name_bob');
      expect(capturedBody!['device_id'], 1);

      // Verify response parsing per §2.4 response shape
      expect(bundle['identity_key'], 'aWRlbnRpdHk=');
      expect(bundle['signed_pre_key'], 'c3Br');
      expect(bundle['signed_pre_key_id'], 1);
      expect(bundle['pre_key_sig'], 'c2ln');
      expect(bundle['otk_public'], 'b3RrcHVi');
      expect(bundle['otk_id'], 'otk-42');
    });

    test('parses response without OTK (exhausted keys)', () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'identity_key': 'aWQ=',
            'signed_pre_key': 'c3Br',
            'signed_pre_key_id': 1,
            'pre_key_sig': 'c2ln',
          }),
          200,
        );
      });

      final wrapper = buildWrapper(mock);
      final bundle = await wrapper.fetchPeerKeyBundle(
        userId: 'name_carol',
        deviceId: 2,
      );

      expect(bundle['identity_key'], 'aWQ=');
      expect(bundle.containsKey('otk_public'), isFalse);
      expect(bundle.containsKey('otk_id'), isFalse);
    });

    test('throws ApiException on 401 (expired token)', () async {
      final mock = MockClient((_) async {
        return http.Response('{"error":"unauthorized"}', 401);
      });

      final wrapper = buildWrapper(mock);

      expect(
        () => wrapper.fetchPeerKeyBundle(userId: 'u', deviceId: 1),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );
    });
  });

  // -------------------------------------------------------------------------
  // uploadKeyBundle
  // -------------------------------------------------------------------------
  group('uploadKeyBundle', () {
    test('sends correct body to /api/keys/bundle', () async {
      Map<String, dynamic>? capturedBody;

      final mock = MockClient((request) async {
        expect(request.url.path, '/api/keys/bundle');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final wrapper = buildWrapper(mock);
      await wrapper.uploadKeyBundle(
        deviceId: 1,
        identityKey: 'id_key_b64',
        signedPreKey: 'spk_b64',
        signedPreKeyId: 1,
        preKeySig: 'sig_b64',
      );

      expect(capturedBody!['device_id'], 1);
      expect(capturedBody!['identity_key'], 'id_key_b64');
      expect(capturedBody!['signed_pre_key'], 'spk_b64');
      expect(capturedBody!['signed_pre_key_id'], 1);
      expect(capturedBody!['pre_key_sig'], 'sig_b64');
    });
  });

  // -------------------------------------------------------------------------
  // uploadOTKs
  // -------------------------------------------------------------------------
  group('uploadOTKs', () {
    test('sends batch of OTKs to /api/keys/otk', () async {
      Map<String, dynamic>? capturedBody;

      final mock = MockClient((request) async {
        expect(request.url.path, '/api/keys/otk');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true, 'count': 3}), 200);
      });

      final wrapper = buildWrapper(mock);
      final result = await wrapper.uploadOTKs(
        deviceId: 1,
        keys: [
          {'id': 'otk-1', 'public_key': 'pk1'},
          {'id': 'otk-2', 'public_key': 'pk2'},
          {'id': 'otk-3', 'public_key': 'pk3'},
        ],
      );

      expect(capturedBody!['device_id'], 1);
      expect((capturedBody!['keys'] as List).length, 3);
      expect(result['count'], 3);
    });
  });

  // -------------------------------------------------------------------------
  // discoverContacts
  // -------------------------------------------------------------------------
  group('discoverContacts', () {
    test('sends phones to /api/contacts/check and parses response', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/contacts/check');
        return http.Response(
          jsonEncode({
            'registered': [
              {'phone': '+1234', 'userId': 'name_alice'},
            ],
          }),
          200,
        );
      });

      final wrapper = buildWrapper(mock);
      final contacts = await wrapper.discoverContacts(['+1234', '+5678']);

      expect(contacts, hasLength(1));
      expect(contacts.first['phone'], '+1234');
      expect(contacts.first['userId'], 'name_alice');
    });

    test('returns empty list when no registered contacts', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'registered': []}), 200);
      });

      final wrapper = buildWrapper(mock);
      final contacts = await wrapper.discoverContacts(['+9999']);
      expect(contacts, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // findOrCreateChat
  // -------------------------------------------------------------------------
  group('findOrCreateChat', () {
    test('sends peer_id and returns group_id', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/chat/start');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['peer_id'], 'name_bob');
        return http.Response(
          jsonEncode({'group_id': 'dm-space-123'}),
          200,
        );
      });

      final wrapper = buildWrapper(mock);
      final groupId = await wrapper.findOrCreateChat('name_bob');
      expect(groupId, 'dm-space-123');
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------
  group('edge cases', () {
    test('strips trailing slash from apiBaseUrl', () async {
      final mock = MockClient((request) async {
        expect(
          request.url.toString(),
          '$apiBase/api/keys/bundle',
        );
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      // Pass URL with trailing slash
      final wrapper = SupabaseClientWrapper(
        client: _FakeSupabaseClient(),
        apiBaseUrl: '$apiBase/',
        httpClient: mock,
      )..authToken = authToken;

      await wrapper.uploadKeyBundle(
        deviceId: 1,
        identityKey: 'k',
        signedPreKey: 'k',
        signedPreKeyId: 1,
        preKeySig: 'k',
      );
    });

    test('handles empty response body', () async {
      final mock = MockClient((_) async {
        return http.Response('', 204);
      });

      final wrapper = buildWrapper(mock);
      // uploadKeyBundle calls _post which returns {} for empty body
      await wrapper.uploadKeyBundle(
        deviceId: 1,
        identityKey: 'k',
        signedPreKey: 'k',
        signedPreKeyId: 1,
        preKeySig: 'k',
      );
    });
  });
}

/// Minimal fake to satisfy the SupabaseClient parameter.
/// PostgREST-dependent methods (fetchCiphertexts, getOTKCount, etc.)
/// are not exercised in these HTTP-focused tests.
class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
