// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PQXDH', () {
    group('backward compatibility (no Kyber keys)', () {
      test('initiator returns DH secret unchanged when peer has no Kyber key',
          () async {
        final pqxdh = Pqxdh();
        final dhSecret = _randomBytes(32);

        final result = await pqxdh.initiatorKeyAgreement(
          dhSharedSecret: dhSecret,
          peerKyberPreKey: null,
        );

        expect(result.sharedSecret, dhSecret);
        expect(result.kemCiphertext, isNull);
        expect(result.isHybrid, isFalse);
      });

      test('responder returns DH secret unchanged when no KEM ciphertext',
          () async {
        final pqxdh = Pqxdh();
        final dhSecret = _randomBytes(32);

        final result = await pqxdh.responderKeyAgreement(
          dhSharedSecret: dhSecret,
          kemCiphertext: null,
          ownKyberSecretKey: null,
        );

        expect(result.sharedSecret, dhSecret);
        expect(result.kemCiphertext, isNull);
        expect(result.isHybrid, isFalse);
      });

      test(
          'responder returns DH secret unchanged when ciphertext present '
          'but no secret key', () async {
        final pqxdh = Pqxdh();
        final dhSecret = _randomBytes(32);

        final result = await pqxdh.responderKeyAgreement(
          dhSharedSecret: dhSecret,
          kemCiphertext: _randomBytes(32),
          ownKyberSecretKey: null,
        );

        expect(result.sharedSecret, dhSecret);
        expect(result.isHybrid, isFalse);
      });
    });

    group('hybrid key agreement (with Kyber)', () {
      test('initiator produces a 32-byte hybrid shared secret', () async {
        final pqxdh = Pqxdh();
        final dhSecret = _randomBytes(32);
        final peerKyberPk = _randomBytes(32);

        final result = await pqxdh.initiatorKeyAgreement(
          dhSharedSecret: dhSecret,
          peerKyberPreKey: peerKyberPk,
        );

        expect(result.sharedSecret.length, 32);
        expect(result.kemCiphertext, isNotNull);
        expect(result.isHybrid, isTrue);
      });

      test('hybrid secret differs from pure DH secret (Kyber adds entropy)',
          () async {
        final pqxdh = Pqxdh();
        final dhSecret = _randomBytes(32);
        final peerKyberPk = _randomBytes(32);

        final result = await pqxdh.initiatorKeyAgreement(
          dhSharedSecret: dhSecret,
          peerKyberPreKey: peerKyberPk,
        );

        // Hybrid secret must NOT be the same as the raw DH secret
        expect(
          _bytesEqual(result.sharedSecret, dhSecret),
          isFalse,
          reason: 'Hybrid PQXDH secret must differ from raw DH secret',
        );
      });

      test(
          'initiator and responder produce the same shared secret '
          'with DeterministicStubKyber', () async {
        final kem = DeterministicStubKyber();
        final pqxdh = Pqxdh(kem: kem);
        final dhSecret = _randomBytes(32);

        // Generate Kyber key pair for the responder
        final kyberKp = await kem.generateKeyPair();

        // Initiator encapsulates against responder's public key
        final initiatorResult = await pqxdh.initiatorKeyAgreement(
          dhSharedSecret: dhSecret,
          peerKyberPreKey: kyberKp.publicKey,
        );

        expect(initiatorResult.isHybrid, isTrue);
        expect(initiatorResult.kemCiphertext, isNotNull);

        // Responder decapsulates with their secret key
        final responderResult = await pqxdh.responderKeyAgreement(
          dhSharedSecret: dhSecret,
          kemCiphertext: initiatorResult.kemCiphertext,
          ownKyberSecretKey: kyberKp.secretKey,
        );

        expect(responderResult.isHybrid, isTrue);

        // Both sides must derive the same shared secret
        expect(
          _bytesEqual(
            initiatorResult.sharedSecret,
            responderResult.sharedSecret,
          ),
          isTrue,
          reason: 'Initiator and responder must derive the same hybrid secret',
        );
      });

      test('isHybrid flag is true when Kyber keys are used', () async {
        final kem = DeterministicStubKyber();
        final pqxdh = Pqxdh(kem: kem);
        final dhSecret = _randomBytes(32);
        final kyberKp = await kem.generateKeyPair();

        final initiatorResult = await pqxdh.initiatorKeyAgreement(
          dhSharedSecret: dhSecret,
          peerKyberPreKey: kyberKp.publicKey,
        );

        final responderResult = await pqxdh.responderKeyAgreement(
          dhSharedSecret: dhSecret,
          kemCiphertext: initiatorResult.kemCiphertext,
          ownKyberSecretKey: kyberKp.secretKey,
        );

        expect(initiatorResult.isHybrid, isTrue);
        expect(responderResult.isHybrid, isTrue);
      });

      test('isHybrid flag is false when no Kyber keys', () async {
        final pqxdh = Pqxdh();
        final dhSecret = _randomBytes(32);

        final initiatorResult = await pqxdh.initiatorKeyAgreement(
          dhSharedSecret: dhSecret,
          peerKyberPreKey: null,
        );

        final responderResult = await pqxdh.responderKeyAgreement(
          dhSharedSecret: dhSecret,
          kemCiphertext: null,
          ownKyberSecretKey: null,
        );

        expect(initiatorResult.isHybrid, isFalse);
        expect(responderResult.isHybrid, isFalse);
      });
    });

    group('KemAlgorithm implementations', () {
      test('StubKyber generates 32-byte key pairs', () async {
        final kem = StubKyber();
        final kp = await kem.generateKeyPair();

        expect(kp.publicKey.length, 32);
        expect(kp.secretKey.length, 32);
      });

      test('StubKyber encapsulate returns 32-byte values', () async {
        final kem = StubKyber();
        final kp = await kem.generateKeyPair();
        final encap = await kem.encapsulate(kp.publicKey);

        expect(encap.sharedSecret.length, 32);
        expect(encap.ciphertext.length, 32);
      });

      test('DeterministicStubKyber generates 32-byte key pairs', () async {
        final kem = DeterministicStubKyber();
        final kp = await kem.generateKeyPair();

        expect(kp.publicKey.length, 32);
        expect(kp.secretKey.length, 32);
      });

      test('DeterministicStubKyber round-trips correctly', () async {
        final kem = DeterministicStubKyber();
        final kp = await kem.generateKeyPair();
        final encap = await kem.encapsulate(kp.publicKey);
        final decap = await kem.decapsulate(kp.secretKey, encap.ciphertext);

        expect(
          _bytesEqual(encap.sharedSecret, decap),
          isTrue,
          reason:
              'DeterministicStubKyber encapsulate and decapsulate must '
              'produce the same shared secret',
        );
      });
    });

    group('KyberPreKey type', () {
      test('KyberPreKey holds public key, secret key, and signature', () {
        final preKey = KyberPreKey(
          publicKey: _randomBytes(32),
          secretKey: _randomBytes(32),
          signature: _randomBytes(64),
        );

        expect(preKey.publicKey.length, 32);
        expect(preKey.secretKey.length, 32);
        expect(preKey.signature.length, 64);
      });
    });
  });
}

/// Generates random bytes for testing.
Uint8List _randomBytes(int length) {
  final random = DateTime.now().microsecondsSinceEpoch;
  // Simple PRNG for test determinism — NOT cryptographically secure.
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = (random + i * 37) % 256;
  }
  return bytes;
}

/// Constant-time-ish byte comparison for tests.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}
