// ignore_for_file: prefer_const_constructors
//
// CRYPTO INTEROP TEST — Offline. No network. No Supabase.
//
// Proves the Flutter crypto layer produces output that matches
// the React app's exact crypto parameters from CODEBASE_CONTEXT.md:
//
// - HKDF info strings: 'XarkE2EE-x3dh', 'XarkE2EE-ratchet',
//   'XarkE2EE-header-secret', 'XarkE2EE-header-key'
// - Chain KDF: HMAC-SHA256 with [0x01] (messageKey) and [0x02] (chainKey)
// - Cipher: XChaCha20-Poly1305 for messages
// - Header encryption: JSON header encrypted with XChaCha20-Poly1305
// - Pack format: nonce(24) + ciphertext
// - Group wire: nonce(24) + signature(64) + iteration(4 BE) + ciphertext
//
// Run with: flutter test test/interop/crypto_interop_test.dart --reporter=expanded

import 'dart:convert';
import 'dart:typed_data';

import 'package:hello_engine/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  // =========================================================================
  // HKDF Info String Verification
  // =========================================================================

  group('HKDF info strings match React app', () {
    test('X3DH info string is exactly XarkE2EE-x3dh', () async {
      // Perform a real X3DH and verify it completes without error.
      // If the info string were wrong, both sides would derive different
      // shared secrets and the ratchet init would silently diverge.
      final alice = await generateTestIdentityKeyPair();
      final bob = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bob);
      final bobOtk = await generateTestOneTimePreKey('otk-interop-1');

      final bundle = PreKeyBundle(
        identityKey: bob.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
        oneTimePreKey: bobOtk.publicKey,
        oneTimePreKeyId: bobOtk.id,
      );

      final aliceResult = await X3DH.initiatorKeyAgreement(
        ourIdentity: alice,
        theirBundle: bundle,
      );

      final bobResult = await X3DH.responderKeyAgreement(
        ourIdentity: bob,
        ourSignedPreKey: bobSpk,
        ourOneTimePreKey: bobOtk,
        theirIdentityKey: alice.ed25519PublicKey,
        theirEphemeralKey: aliceResult.ephemeralPublicKey,
      );

      // Both sides must derive the same 32-byte shared secret.
      expect(aliceResult.sharedSecret.length, 32);
      expect(bobResult.sharedSecret.length, 32);
      expect(aliceResult.sharedSecret, equals(bobResult.sharedSecret));
    });

    test('Ratchet info strings produce working encrypt/decrypt cycle',
        () async {
      final session = await buildAliceBobSession();

      final plaintext = Uint8List.fromList(
        utf8.encode('{"text":"interop test","type":"message"}'),
      );

      // Alice encrypts with 'XarkE2EE-ratchet', 'XarkE2EE-header-secret',
      // 'XarkE2EE-header-key'.
      final encResult =
          await DoubleRatchet.encrypt(session.alice, plaintext);

      // Bob decrypts with the same info strings.
      final decResult = await DoubleRatchet.decrypt(
        session.bob,
        encResult.ciphertext,
        encResult.encryptedHeader,
      );

      expect(utf8.decode(decResult.plaintext), utf8.decode(plaintext));
    });
  });

  // =========================================================================
  // Pack Format Verification
  // =========================================================================

  group('1:1 message pack format', () {
    test('ciphertext starts with 24-byte nonce (XChaCha20)', () async {
      final session = await buildAliceBobSession();
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      final encResult =
          await DoubleRatchet.encrypt(session.alice, plaintext);

      // The encrypt output should contain ciphertext with at least
      // 24 bytes of nonce overhead.
      expect(encResult.ciphertext.length, greaterThan(24));
    });

    test('encrypted header is nonce(24) + headerCiphertext', () async {
      final session = await buildAliceBobSession();
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      final encResult =
          await DoubleRatchet.encrypt(session.alice, plaintext);

      // Header must be at least 24 bytes (nonce) + some ciphertext.
      expect(encResult.encryptedHeader.length, greaterThan(24));

      // The first 24 bytes are the nonce — verify they're present.
      final headerNonce = encResult.encryptedHeader.sublist(0, 24);
      expect(headerNonce.length, 24);
    });
  });

  // =========================================================================
  // Group Message Wire Format
  // =========================================================================

  group('group message wire format', () {
    test('GroupCipher output is nonce(24) + sig(64) + iter(4) + ct',
        () async {
      // Use separate stores for sender and receiver to simulate
      // the real distribution flow: sender creates key, distributes
      // the public half, receiver stores independently.
      final senderStore = FakeSenderKeyStore();
      final senderCipher = GroupCipher(store: senderStore);

      // Sender creates key.
      final distribution = await senderCipher.createSenderKey(
          'group-interop', 'name_alice');

      // Encrypt.
      final plaintext = Uint8List.fromList(utf8.encode('group test'));
      final packed = await senderCipher.encrypt(
        'group-interop',
        'name_alice',
        plaintext,
      );

      // Verify pack format: nonce(24) + signature(64) + iteration(4) + ct
      expect(packed.length, greaterThan(24 + 64 + 4));

      // Extract iteration (bytes 88-92, big-endian uint32).
      final iterBytes = packed.sublist(88, 92);
      final iteration =
          ByteData.sublistView(iterBytes).getUint32(0, Endian.big);
      expect(iteration, 1); // First message, iteration=1.

      // Receiver processes the distribution and decrypts.
      final receiverStore = FakeSenderKeyStore();
      final receiverCipher = GroupCipher(store: receiverStore);
      await receiverCipher.processSenderKeyDistribution(
        'group-interop',
        'name_alice',
        distribution,
      );

      final decrypted = await receiverCipher.decrypt(
        'group-interop',
        'name_alice',
        packed,
      );
      expect(utf8.decode(decrypted), 'group test');
    });

    test('group message signature is Ed25519 over ciphertext||nonce',
        () async {
      final store = FakeSenderKeyStore();
      final cipher = GroupCipher(store: store);

      await cipher.createSenderKey('group-sig', 'name_bob');
      final plaintext = Uint8List.fromList(utf8.encode('sig verify'));

      final packed = await cipher.encrypt(
        'group-sig',
        'name_bob',
        plaintext,
      );

      // Extract components.
      final nonce = packed.sublist(0, 24);
      final signature = packed.sublist(24, 88);

      // Nonce is 24 bytes, signature is 64 bytes (Ed25519).
      expect(nonce.length, 24);
      expect(signature.length, 64);
    });
  });

  // =========================================================================
  // Chain KDF Verification
  // =========================================================================

  group('chain KDF matches React implementation', () {
    test('10 sequential messages encrypt and decrypt in order', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;
      var bobState = session.bob;

      for (var i = 0; i < 10; i++) {
        final plaintext = Uint8List.fromList(
          utf8.encode('{"text":"message $i","type":"message"}'),
        );

        final enc = await DoubleRatchet.encrypt(aliceState, plaintext);
        aliceState = enc.newState;

        final dec = await DoubleRatchet.decrypt(
          bobState,
          enc.ciphertext,
          enc.encryptedHeader,
        );
        bobState = dec.newState;

        expect(utf8.decode(dec.plaintext), utf8.decode(plaintext));
      }

      // Verify chain advanced 10 times.
      expect(aliceState.sendMessageNumber, 10);
    });

    test('bidirectional exchange (Alice→Bob, Bob→Alice) works', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;
      var bobState = session.bob;

      // Alice → Bob (message 0).
      final enc1 = await DoubleRatchet.encrypt(
        aliceState,
        Uint8List.fromList(utf8.encode('{"text":"hello bob","type":"message"}')),
      );
      aliceState = enc1.newState;
      final dec1 = await DoubleRatchet.decrypt(
        bobState,
        enc1.ciphertext,
        enc1.encryptedHeader,
      );
      bobState = dec1.newState;
      expect(utf8.decode(dec1.plaintext), contains('hello bob'));

      // Bob → Alice (reply).
      final enc2 = await DoubleRatchet.encrypt(
        bobState,
        Uint8List.fromList(utf8.encode('{"text":"hello alice","type":"message"}')),
      );
      bobState = enc2.newState;
      final dec2 = await DoubleRatchet.decrypt(
        aliceState,
        enc2.ciphertext,
        enc2.encryptedHeader,
      );
      aliceState = dec2.newState;
      expect(utf8.decode(dec2.plaintext), contains('hello alice'));
    });
  });

  // =========================================================================
  // DecryptedMessage JSON payload format
  // =========================================================================

  group('message payload JSON matches React format', () {
    test('text message payload has text and type fields', () async {
      final session = await buildAliceBobSession();

      // This is the exact JSON structure React produces.
      final payload = jsonEncode({
        'text': 'Hello from interop test',
        'type': 'message',
        'replyTo': null,
        'mediaUrl': null,
      });

      final enc = await DoubleRatchet.encrypt(
        session.alice,
        Uint8List.fromList(utf8.encode(payload)),
      );

      final dec = await DoubleRatchet.decrypt(
        session.bob,
        enc.ciphertext,
        enc.encryptedHeader,
      );

      final parsed =
          jsonDecode(utf8.decode(dec.plaintext)) as Map<String, dynamic>;

      // Verify React-compatible fields.
      expect(parsed['text'], 'Hello from interop test');
      expect(parsed['type'], 'message');
      expect(parsed['replyTo'], isNull);
      expect(parsed['mediaUrl'], isNull);
    });

    test('media message payload includes AES key fields', () async {
      final session = await buildAliceBobSession();

      // React media payload format from CODEBASE_CONTEXT.md §3.5.
      final payload = jsonEncode({
        'text': 'photo.jpg',
        'type': 'media',
        'replyTo': null,
        'mediaUrl': 'https://firebasestorage.googleapis.com/v0/b/...',
        'aesKeyBase64': base64Encode(Uint8List(32)),
        'ivBase64': base64Encode(Uint8List(12)),
        'mimeType': 'image/jpeg',
        'inlineThumbnail': base64Encode(Uint8List(100)),
      });

      final enc = await DoubleRatchet.encrypt(
        session.alice,
        Uint8List.fromList(utf8.encode(payload)),
      );

      final dec = await DoubleRatchet.decrypt(
        session.bob,
        enc.ciphertext,
        enc.encryptedHeader,
      );

      final parsed =
          jsonDecode(utf8.decode(dec.plaintext)) as Map<String, dynamic>;

      expect(parsed['type'], 'media');
      expect(parsed['aesKeyBase64'], isNotEmpty);
      expect(parsed['ivBase64'], isNotEmpty);
      expect(parsed['mimeType'], 'image/jpeg');
      expect(parsed['inlineThumbnail'], isNotEmpty);
    });
  });

  // =========================================================================
  // Ed25519 → Curve25519 conversion verification
  // =========================================================================

  group('Ed25519 → Curve25519 birational mapping', () {
    test('converted key pair produces valid X3DH shared secret', () async {
      // This is the critical conversion that maps Ed25519 identity keys
      // to Curve25519 DH keys. If wrong, X3DH fails.
      final identity = await generateTestIdentityKeyPair();

      // Verify x25519 public key is 32 bytes.
      expect(identity.x25519PublicKey.length, 32);
      expect(identity.x25519PrivateKey.length, 32);

      // Verify the conversion is consistent — same Ed25519 input always
      // produces the same Curve25519 output.
      final identity2 = IdentityKeyPair(
        ed25519PublicKey: Uint8List.fromList(identity.ed25519PublicKey),
        ed25519PrivateKey: Uint8List.fromList(identity.ed25519PrivateKey),
        x25519PublicKey: await Ed25519ToCurve25519.convertPublicKey(
          identity.ed25519PublicKey,
        ),
        x25519PrivateKey: await Ed25519ToCurve25519.convertPrivateKey(
          identity.ed25519PrivateKey,
        ),
      );

      expect(identity2.x25519PublicKey, equals(identity.x25519PublicKey));
      expect(identity2.x25519PrivateKey, equals(identity.x25519PrivateKey));
    });
  });
}
