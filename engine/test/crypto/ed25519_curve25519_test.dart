// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:hello_engine/src/crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ed25519ToCurve25519', () {
    test('convertPrivateKey produces 32 bytes with correct clamping', () async {
      final ed = Ed25519();
      final kp = await ed.newKeyPair();
      final extracted = await kp.extract();
      final seed = Uint8List.fromList(extracted.bytes);

      final x25519Priv = await Ed25519ToCurve25519.convertPrivateKey(seed);

      expect(x25519Priv.length, 32);

      // Verify X25519 clamping bits:
      // bit 0,1,2 of byte[0] cleared -> byte[0] & 7 == 0
      expect(x25519Priv[0] & 7, 0, reason: 'Low 3 bits must be cleared');
      // bit 255 of byte[31] cleared -> byte[31] & 128 == 0
      expect(x25519Priv[31] & 128, 0, reason: 'Bit 255 must be cleared');
      // bit 254 of byte[31] set -> byte[31] & 64 == 64
      expect(x25519Priv[31] & 64, 64, reason: 'Bit 254 must be set');
    });

    test('convertPublicKey produces 32 bytes', () async {
      final ed = Ed25519();
      final kp = await ed.newKeyPair();
      final extracted = await kp.extract();
      final edPub = Uint8List.fromList(extracted.publicKey.bytes);

      final x25519Pub = Ed25519ToCurve25519.convertPublicKey(edPub);

      expect(x25519Pub.length, 32);
      // Should not be all zeros.
      expect(x25519Pub.any((b) => b != 0), isTrue);
    });

    test(
      'DH with converted keys works (X25519 shared secret derivable)',
      () async {
        // Generate two Ed25519 key pairs and convert both to X25519.
        final ed = Ed25519();

        final kpA = await ed.newKeyPair();
        final extractedA = await kpA.extract();
        final seedA = Uint8List.fromList(extractedA.bytes);
        final edPubA = Uint8List.fromList(extractedA.publicKey.bytes);

        final kpB = await ed.newKeyPair();
        final extractedB = await kpB.extract();
        final seedB = Uint8List.fromList(extractedB.bytes);
        final edPubB = Uint8List.fromList(extractedB.publicKey.bytes);

        final x25519PrivA =
            await Ed25519ToCurve25519.convertPrivateKey(seedA);
        final x25519PubA = Ed25519ToCurve25519.convertPublicKey(edPubA);

        final x25519PrivB =
            await Ed25519ToCurve25519.convertPrivateKey(seedB);
        final x25519PubB = Ed25519ToCurve25519.convertPublicKey(edPubB);

        // Perform DH in both directions.
        final x = X25519();

        final ssAB = await x.sharedSecretKey(
          keyPair: SimpleKeyPairData(
            x25519PrivA,
            publicKey:
                SimplePublicKey(x25519PubA, type: KeyPairType.x25519),
            type: KeyPairType.x25519,
          ),
          remotePublicKey:
              SimplePublicKey(x25519PubB, type: KeyPairType.x25519),
        );

        final ssBA = await x.sharedSecretKey(
          keyPair: SimpleKeyPairData(
            x25519PrivB,
            publicKey:
                SimplePublicKey(x25519PubB, type: KeyPairType.x25519),
            type: KeyPairType.x25519,
          ),
          remotePublicKey:
              SimplePublicKey(x25519PubA, type: KeyPairType.x25519),
        );

        final bytesAB = Uint8List.fromList(await ssAB.extractBytes());
        final bytesBA = Uint8List.fromList(await ssBA.extractBytes());

        // DH should be commutative: AB == BA.
        expect(bytesAB, bytesBA);
        expect(bytesAB.length, 32);
      },
    );

    test(
      'round-trip: generate Ed25519, convert both keys, verify DH '
      'consistency',
      () async {
        final ed = Ed25519();
        final kp = await ed.newKeyPair();
        final extracted = await kp.extract();
        final seed = Uint8List.fromList(extracted.bytes);
        final edPub = Uint8List.fromList(extracted.publicKey.bytes);

        // Convert private key.
        final x25519Priv =
            await Ed25519ToCurve25519.convertPrivateKey(seed);

        // Derive the X25519 public key from the converted private key
        // using the cryptography library.
        final x = X25519();
        final xKp = await x.newKeyPairFromSeed(x25519Priv);
        final xExtracted = await xKp.extract();
        final derivedPub =
            Uint8List.fromList(xExtracted.publicKey.bytes);

        // Also convert the Ed25519 public key directly.
        final convertedPub =
            Ed25519ToCurve25519.convertPublicKey(edPub);

        // The two X25519 public keys must match.
        expect(derivedPub, convertedPub);
      },
    );

    test('different Ed25519 seeds produce different X25519 keys', () async {
      final ed = Ed25519();

      final kp1 = await ed.newKeyPair();
      final extracted1 = await kp1.extract();
      final seed1 = Uint8List.fromList(extracted1.bytes);

      final kp2 = await ed.newKeyPair();
      final extracted2 = await kp2.extract();
      final seed2 = Uint8List.fromList(extracted2.bytes);

      final x25519Priv1 =
          await Ed25519ToCurve25519.convertPrivateKey(seed1);
      final x25519Priv2 =
          await Ed25519ToCurve25519.convertPrivateKey(seed2);

      expect(x25519Priv1, isNot(equals(x25519Priv2)));
    });

    test('convertPublicKey is deterministic', () async {
      final ed = Ed25519();
      final kp = await ed.newKeyPair();
      final extracted = await kp.extract();
      final edPub = Uint8List.fromList(extracted.publicKey.bytes);

      final x25519Pub1 = Ed25519ToCurve25519.convertPublicKey(edPub);
      final x25519Pub2 = Ed25519ToCurve25519.convertPublicKey(edPub);

      expect(x25519Pub1, x25519Pub2);
    });

    test('convertPrivateKey is deterministic', () async {
      final ed = Ed25519();
      final kp = await ed.newKeyPair();
      final extracted = await kp.extract();
      final seed = Uint8List.fromList(extracted.bytes);

      final x25519Priv1 =
          await Ed25519ToCurve25519.convertPrivateKey(seed);
      final x25519Priv2 =
          await Ed25519ToCurve25519.convertPrivateKey(seed);

      expect(x25519Priv1, x25519Priv2);
    });
  });
}
