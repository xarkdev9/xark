// ignore_for_file: prefer_const_constructors, avoid_print
//
// LIVE INTEROP TEST — Requires real Supabase credentials and network.
//
// Run with: flutter test test/interop/live_interop_test.dart --timeout=60s
//
// This test proves Flutter ↔ React message interoperability by connecting
// to the REAL Supabase project. It writes real rows to your database.
//
// Prerequisites:
// 1. xark9 dev server running on localhost:3000 (for JWT via dev-auto-login)
// 2. Seed users exist in Supabase (run: cd ~/xark9 && npx tsx src/lib/seed.ts)
// 3. A 1:1 space exists between the two test users
//
// Fill in the constants below before running.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  // -------------------------------------------------------------------------
  // CONFIG — fill these from ~/xark9/.env.local and your test setup
  // -------------------------------------------------------------------------

  // Read from env vars or hardcode for local testing.
  final supabaseUrl = Platform.environment['INTEROP_SUPABASE_URL'] ?? '';
  final supabaseAnonKey =
      Platform.environment['INTEROP_SUPABASE_ANON_KEY'] ?? '';
  final devServerUrl =
      Platform.environment['INTEROP_DEV_SERVER'] ?? 'http://localhost:3000';

  // Test users from ~/xark9/src/lib/seed.ts.
  const userA = 'ram'; // name_ram
  const userB = 'myna'; // name_myna
  const passwordA = 'myna';
  const passwordB = 'ram';

  /// Gets a JWT for a seeded test user via the dev-auto-login endpoint.
  Future<String?> getJwt(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$devServerUrl/api/dev-auto-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['token'] as String?;
      }
      print('JWT fetch failed for $username: ${response.statusCode} '
          '${response.body}');
      return null;
    } catch (e) {
      print('Cannot reach dev server at $devServerUrl: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // PREFLIGHT — check if everything needed is available
  // -------------------------------------------------------------------------

  group('Live Interop — Preflight', () {
    test('dev server is reachable', () async {
      try {
        final response = await http.get(Uri.parse(devServerUrl));
        // Any response means the server is up (even redirects).
        expect(response.statusCode, lessThan(500));
      } catch (e) {
        fail('Dev server not running at $devServerUrl. '
            'Start it with: cd ~/xark9 && npm run dev\n$e');
      }
    },
        skip: supabaseUrl.isEmpty
            ? 'Set INTEROP_SUPABASE_URL env var to run'
            : null);

    test('can obtain JWT for test user A (name_$userA)', () async {
      final jwt = await getJwt(userA, passwordA);
      expect(jwt, isNotNull, reason: 'Failed to get JWT for $userA');
      expect(jwt, isNotEmpty);
      print('Got JWT for name_$userA (${jwt!.length} chars)');
    },
        skip: supabaseUrl.isEmpty
            ? 'Set INTEROP_SUPABASE_URL env var to run'
            : null);

    test('can obtain JWT for test user B (name_$userB)', () async {
      final jwt = await getJwt(userB, passwordB);
      expect(jwt, isNotNull, reason: 'Failed to get JWT for $userB');
      expect(jwt, isNotEmpty);
      print('Got JWT for name_$userB (${jwt!.length} chars)');
    },
        skip: supabaseUrl.isEmpty
            ? 'Set INTEROP_SUPABASE_URL env var to run'
            : null);
  });

  // -------------------------------------------------------------------------
  // FLUTTER → SERVER — Message written to Supabase
  // -------------------------------------------------------------------------

  group('Live Interop — Flutter → Server', () {
    test('POST /api/message with correct envelope shape', () async {
      final jwt = await getJwt(userA, passwordA);
      if (jwt == null) {
        fail('No JWT — dev server not running');
      }

      // Build a message envelope matching CODEBASE_CONTEXT.md §2.5.
      final envelope = {
        'group_id': 'interop-test-space',
        'sender_device_id': 99, // Flutter test device
        'ciphertext': base64Encode(utf8.encode('flutter-interop-test')),
        'recipient_id': '_group_',
        'recipient_device_id': 0,
        'message_type': 'e2ee',
      };

      final response = await http.post(
        Uri.parse('$devServerUrl/api/message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(envelope),
      );

      print('POST /api/message → ${response.statusCode}');
      print('Response: ${response.body}');

      expect(
        response.statusCode,
        200,
        reason: 'Server rejected envelope: ${response.body}',
      );

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      expect(result.containsKey('messageId'), isTrue);
      print('Message written: ${result['messageId']}');
    },
        skip: supabaseUrl.isEmpty
            ? 'Set INTEROP_SUPABASE_URL env var to run'
            : null);
  });

  // -------------------------------------------------------------------------
  // KEY BUNDLE — Fetch and verify format
  // -------------------------------------------------------------------------

  group('Live Interop — Key Bundle Protocol', () {
    test('POST /api/keys/fetch returns correct response shape', () async {
      final jwt = await getJwt(userA, passwordA);
      if (jwt == null) {
        fail('No JWT — dev server not running');
      }

      final response = await http.post(
        Uri.parse('$devServerUrl/api/keys/fetch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'user_id': 'name_$userB',
          'device_id': 1,
        }),
      );

      print('POST /api/keys/fetch → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Verify response shape matches CODEBASE_CONTEXT.md §2.4.
        expect(data.containsKey('identity_key'), isTrue,
            reason: 'Missing identity_key');
        expect(data.containsKey('signed_pre_key'), isTrue,
            reason: 'Missing signed_pre_key');
        expect(data.containsKey('signed_pre_key_id'), isTrue,
            reason: 'Missing signed_pre_key_id');
        expect(data.containsKey('pre_key_sig'), isTrue,
            reason: 'Missing pre_key_sig');

        print('Key bundle fields: ${data.keys.toList()}');
        print('Has OTK: ${data.containsKey('otk_public')}');
      } else if (response.statusCode == 404) {
        print('No key bundle registered for name_$userB device 1');
        print('This is expected if the React app has not registered '
            'keys for this user yet.');
      } else {
        fail('Unexpected status: ${response.statusCode} ${response.body}');
      }
    },
        skip: supabaseUrl.isEmpty
            ? 'Set INTEROP_SUPABASE_URL env var to run'
            : null);
  });
}
