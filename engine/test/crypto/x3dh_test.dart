// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:hello_engine/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('X3DH', () {
    test('initiator produces a 32-byte shared secret', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);
      final bobOtk = await generateTestOneTimePreKey('otk-1');

      final bobBundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
        oneTimePreKey: bobOtk.publicKey,
        oneTimePreKeyId: bobOtk.id,
      );

      final result = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bobBundle,
      );

      expect(result.sharedSecret.length, 32);
    });

    test('initiator and responder produce the same shared secret', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);
      final bobOtk = await generateTestOneTimePreKey('otk-1');

      final bobBundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
        oneTimePreKey: bobOtk.publicKey,
        oneTimePreKeyId: bobOtk.id,
      );

      final aliceResult = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bobBundle,
      );

      final bobResult = await X3DH.responderKeyAgreement(
        ourIdentity: bobIdentity,
        ourSignedPreKey: bobSpk,
        ourOneTimePreKey: bobOtk,
        theirIdentityKey: aliceIdentity.ed25519PublicKey,
        theirEphemeralKey: aliceResult.ephemeralPublicKey,
      );

      expect(aliceResult.sharedSecret, bobResult.sharedSecret);
    });

    test(
      'X3DH with one-time pre-key produces different secret than without',
      () async {
        final aliceIdentity = await generateTestIdentityKeyPair();
        final bobIdentity = await generateTestIdentityKeyPair();
        final bobSpk = await generateTestSignedPreKey(bobIdentity);
        final bobOtk = await generateTestOneTimePreKey('otk-1');

        // Bundle WITH one-time pre-key.
        final bundleWith = PreKeyBundle(
          identityKey: bobIdentity.ed25519PublicKey,
          signedPreKey: bobSpk.publicKey,
          signedPreKeyId: bobSpk.id,
          preKeySignature: bobSpk.signature,
          oneTimePreKey: bobOtk.publicKey,
          oneTimePreKeyId: bobOtk.id,
        );

        // Bundle WITHOUT one-time pre-key.
        final bundleWithout = PreKeyBundle(
          identityKey: bobIdentity.ed25519PublicKey,
          signedPreKey: bobSpk.publicKey,
          signedPreKeyId: bobSpk.id,
          preKeySignature: bobSpk.signature,
        );

        final resultWith = await X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: bundleWith,
        );

        final resultWithout = await X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: bundleWithout,
        );

        // Different DH4 inclusion means different secret.
        expect(
          resultWith.sharedSecret,
          isNot(equals(resultWithout.sharedSecret)),
        );
      },
    );

    test('X3DH fails if signed pre-key signature is invalid', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);

      // Forge a bad signature by flipping bits.
      final badSig = Uint8List.fromList(bobSpk.signature);
      badSig[0] ^= 0xFF;
      badSig[10] ^= 0xFF;

      final badBundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: badSig,
      );

      expect(
        () => X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: badBundle,
        ),
        throwsA(isA<SignatureVerificationFailed>()),
      );
    });

    test(
      'two different initiators produce different shared secrets',
      () async {
        final alice1 = await generateTestIdentityKeyPair();
        final alice2 = await generateTestIdentityKeyPair();
        final bobIdentity = await generateTestIdentityKeyPair();
        final bobSpk = await generateTestSignedPreKey(bobIdentity);

        final bundle = PreKeyBundle(
          identityKey: bobIdentity.ed25519PublicKey,
          signedPreKey: bobSpk.publicKey,
          signedPreKeyId: bobSpk.id,
          preKeySignature: bobSpk.signature,
        );

        final result1 = await X3DH.initiatorKeyAgreement(
          ourIdentity: alice1,
          theirBundle: bundle,
        );
        final result2 = await X3DH.initiatorKeyAgreement(
          ourIdentity: alice2,
          theirBundle: bundle,
        );

        // Different identity keys produce different secrets.
        expect(result1.sharedSecret, isNot(equals(result2.sharedSecret)));
      },
    );

    test('X3DH ephemeral key is a valid 32-byte X25519 public key', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);

      final bundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
      );

      final result = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bundle,
      );

      expect(result.ephemeralPublicKey.length, 32);
      // Should be usable in a DH operation (non-zero).
      expect(
        result.ephemeralPublicKey.any((b) => b != 0),
        isTrue,
        reason: 'Ephemeral key should not be all zeros',
      );
    });

    test(
      'X3DH without one-time pre-key still produces valid shared secret',
      () async {
        final aliceIdentity = await generateTestIdentityKeyPair();
        final bobIdentity = await generateTestIdentityKeyPair();
        final bobSpk = await generateTestSignedPreKey(bobIdentity);

        final bundle = PreKeyBundle(
          identityKey: bobIdentity.ed25519PublicKey,
          signedPreKey: bobSpk.publicKey,
          signedPreKeyId: bobSpk.id,
          preKeySignature: bobSpk.signature,
        );

        final aliceResult = await X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: bundle,
        );

        final bobResult = await X3DH.responderKeyAgreement(
          ourIdentity: bobIdentity,
          ourSignedPreKey: bobSpk,
          ourOneTimePreKey: null,
          theirIdentityKey: aliceIdentity.ed25519PublicKey,
          theirEphemeralKey: aliceResult.ephemeralPublicKey,
        );

        expect(aliceResult.sharedSecret, bobResult.sharedSecret);
        expect(aliceResult.sharedSecret.length, 32);
        expect(aliceResult.usedOneTimePreKeyId, isNull);
        expect(bobResult.usedOneTimePreKeyId, isNull);
      },
    );

    test('usedOneTimePreKeyId is set correctly when OTK is used', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);
      final bobOtk = await generateTestOneTimePreKey('my-otk-id');

      final bundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
        oneTimePreKey: bobOtk.publicKey,
        oneTimePreKeyId: bobOtk.id,
      );

      final result = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bundle,
      );

      expect(result.usedOneTimePreKeyId, 'my-otk-id');
    });

    test('falls back to 3-DH when no OTK available', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);

      // Bundle without OTK.
      final bundleNoOtk = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
      );

      final aliceResult = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bundleNoOtk,
      );

      // Shared secret is still computed (3-DH fallback).
      expect(aliceResult.sharedSecret.length, 32);
      expect(aliceResult.usedOneTimePreKeyId, isNull);

      // Responder matches with null OTK.
      final bobResult = await X3DH.responderKeyAgreement(
        ourIdentity: bobIdentity,
        ourSignedPreKey: bobSpk,
        ourOneTimePreKey: null,
        theirIdentityKey: aliceIdentity.ed25519PublicKey,
        theirEphemeralKey: aliceResult.ephemeralPublicKey,
      );

      expect(aliceResult.sharedSecret, bobResult.sharedSecret);
    });

    test('throws SignatureVerificationFailed on bad signature', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);

      // Corrupt the pre-key signature.
      final badSig = Uint8List.fromList(bobSpk.signature);
      for (var i = 0; i < badSig.length; i++) {
        badSig[i] ^= 0xFF;
      }

      final badBundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: badSig,
      );

      expect(
        () => X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: badBundle,
        ),
        throwsA(isA<SignatureVerificationFailed>()),
      );
    });

    test('throws SignatureVerificationFailed on wrong identity key',
        () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final imposter = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);

      // Bundle where identity key doesn't match the key that signed the SPK.
      final mismatchBundle = PreKeyBundle(
        identityKey: imposter.ed25519PublicKey, // wrong identity key
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature, // signed by bobIdentity, not imposter
      );

      expect(
        () => X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: mismatchBundle,
        ),
        throwsA(isA<SignatureVerificationFailed>()),
      );
    });

    test('3-DH and 4-DH produce different shared secrets', () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);
      final bobOtk = await generateTestOneTimePreKey('otk-diff');

      // With OTK (4-DH).
      final bundleWith = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
        oneTimePreKey: bobOtk.publicKey,
        oneTimePreKeyId: bobOtk.id,
      );

      // Without OTK (3-DH).
      final bundleWithout = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
      );

      final resultWith = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bundleWith,
      );
      final resultWithout = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bundleWithout,
      );

      // OTK adds entropy — secrets must differ.
      expect(
        resultWith.sharedSecret,
        isNot(equals(resultWithout.sharedSecret)),
      );
    });

    test(
      'X3DH with wrong identity key is rejected by responder SPK check',
      () async {
        final aliceIdentity = await generateTestIdentityKeyPair();
        final bobIdentity = await generateTestIdentityKeyPair();
        final bobSpk = await generateTestSignedPreKey(bobIdentity);
        final bobOtk = await generateTestOneTimePreKey('otk-1');

        final bundle = PreKeyBundle(
          identityKey: bobIdentity.ed25519PublicKey,
          signedPreKey: bobSpk.publicKey,
          signedPreKeyId: bobSpk.id,
          preKeySignature: bobSpk.signature,
          oneTimePreKey: bobOtk.publicKey,
          oneTimePreKeyId: bobOtk.id,
        );

        final aliceResult = await X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: bundle,
        );

        // Impersonator tries to respond with a different identity.
        // The SPK was signed by bobIdentity, so the imposter's identity
        // key won't match — the responder now catches this.
        final imposter = await generateTestIdentityKeyPair();

        expect(
          () => X3DH.responderKeyAgreement(
            ourIdentity: imposter,
            ourSignedPreKey: bobSpk,
            ourOneTimePreKey: bobOtk,
            theirIdentityKey: aliceIdentity.ed25519PublicKey,
            theirEphemeralKey: aliceResult.ephemeralPublicKey,
          ),
          throwsA(isA<SignatureVerificationFailed>()),
        );
      },
    );

    // ── CRYPTO-01: Edge case hardening tests ──

    test('responder throws KeyMismatchError on all-zero ephemeral key',
        () async {
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);
      final aliceIdentity = await generateTestIdentityKeyPair();

      // All-zero 32-byte ephemeral key — invalid X25519 point.
      final badEphemeral = Uint8List(32);

      expect(
        () => X3DH.responderKeyAgreement(
          ourIdentity: bobIdentity,
          ourSignedPreKey: bobSpk,
          ourOneTimePreKey: null,
          theirIdentityKey: aliceIdentity.ed25519PublicKey,
          theirEphemeralKey: badEphemeral,
        ),
        throwsA(isA<KeyMismatchError>()),
      );
    });

    test('responder throws KeyMismatchError on wrong-length ephemeral key',
        () async {
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);
      final aliceIdentity = await generateTestIdentityKeyPair();

      // 16-byte ephemeral key — wrong length for X25519.
      final shortEphemeral = Uint8List(16);
      shortEphemeral[0] = 0x42;

      expect(
        () => X3DH.responderKeyAgreement(
          ourIdentity: bobIdentity,
          ourSignedPreKey: bobSpk,
          ourOneTimePreKey: null,
          theirIdentityKey: aliceIdentity.ed25519PublicKey,
          theirEphemeralKey: shortEphemeral,
        ),
        throwsA(isA<KeyMismatchError>()),
      );
    });

    test('responder verifies own SPK signature — rejects corrupted SPK',
        () async {
      final aliceIdentity = await generateTestIdentityKeyPair();
      final bobIdentity = await generateTestIdentityKeyPair();
      final bobSpk = await generateTestSignedPreKey(bobIdentity);

      // Run a valid initiator exchange first to get an ephemeral key.
      final bundle = PreKeyBundle(
        identityKey: bobIdentity.ed25519PublicKey,
        signedPreKey: bobSpk.publicKey,
        signedPreKeyId: bobSpk.id,
        preKeySignature: bobSpk.signature,
      );
      final aliceResult = await X3DH.initiatorKeyAgreement(
        ourIdentity: aliceIdentity,
        theirBundle: bundle,
      );

      // Corrupt the SPK signature on the responder side.
      final badSig = Uint8List.fromList(bobSpk.signature);
      badSig[0] ^= 0xFF;
      final corruptedSpk = SignedPreKey(
        id: bobSpk.id,
        publicKey: bobSpk.publicKey,
        privateKey: bobSpk.privateKey,
        signature: badSig,
        timestamp: bobSpk.timestamp,
      );

      expect(
        () => X3DH.responderKeyAgreement(
          ourIdentity: bobIdentity,
          ourSignedPreKey: corruptedSpk,
          ourOneTimePreKey: null,
          theirIdentityKey: aliceIdentity.ed25519PublicKey,
          theirEphemeralKey: aliceResult.ephemeralPublicKey,
        ),
        throwsA(isA<SignatureVerificationFailed>()),
      );
    });

    test('StalePreKeyWarning stores age in days', () {
      final warning = StalePreKeyWarning(10);
      expect(warning.ageDays, 10);
      expect(warning.message, contains('10 days old'));
    });

    test(
      'X3DH full round-trip with 3-DH fallback (no OTK) — secrets match',
      () async {
        final aliceIdentity = await generateTestIdentityKeyPair();
        final bobIdentity = await generateTestIdentityKeyPair();
        final bobSpk = await generateTestSignedPreKey(bobIdentity);

        // Bundle without OTK — forces 3-DH.
        final bundle = PreKeyBundle(
          identityKey: bobIdentity.ed25519PublicKey,
          signedPreKey: bobSpk.publicKey,
          signedPreKeyId: bobSpk.id,
          preKeySignature: bobSpk.signature,
        );

        final aliceResult = await X3DH.initiatorKeyAgreement(
          ourIdentity: aliceIdentity,
          theirBundle: bundle,
        );

        final bobResult = await X3DH.responderKeyAgreement(
          ourIdentity: bobIdentity,
          ourSignedPreKey: bobSpk,
          ourOneTimePreKey: null,
          theirIdentityKey: aliceIdentity.ed25519PublicKey,
          theirEphemeralKey: aliceResult.ephemeralPublicKey,
        );

        // Both sides derive the same 32-byte shared secret.
        expect(aliceResult.sharedSecret, bobResult.sharedSecret);
        expect(aliceResult.sharedSecret.length, 32);
        expect(aliceResult.usedOneTimePreKeyId, isNull);
        expect(bobResult.usedOneTimePreKeyId, isNull);
      },
    );
  });
}
