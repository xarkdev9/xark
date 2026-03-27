// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:hello_engine/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaCrypto', () {
    test('encrypt then decrypt returns original plaintext', () async {
      final key = await MediaCrypto.generateMediaKey();
      final plaintext = Uint8List.fromList(
        List.generate(256, (i) => i % 256),
      );

      final ciphertext = await MediaCrypto.encrypt(plaintext, key);
      final decrypted = await MediaCrypto.decrypt(ciphertext, key);

      expect(decrypted, plaintext);
    });

    test('generated media key has 32-byte key and 12-byte IV', () async {
      final key = await MediaCrypto.generateMediaKey();
      expect(key.key.length, 32);
      expect(key.iv.length, 12);
    });

    test('SHA-256 hash verifies correctly', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final hash = await MediaCrypto.computeSha256(data);

      expect(hash.length, 32);

      final valid = await MediaCrypto.verifySha256(data, hash);
      expect(valid, isTrue);
    });

    test('tampered ciphertext fails decryption', () async {
      final key = await MediaCrypto.generateMediaKey();
      final plaintext = Uint8List.fromList([10, 20, 30, 40, 50]);

      final ciphertext = await MediaCrypto.encrypt(plaintext, key);

      // Tamper with the ciphertext.
      final tampered = Uint8List.fromList(ciphertext);
      tampered[0] ^= 0xFF;

      expect(
        () => MediaCrypto.decrypt(tampered, key),
        throwsA(anything),
      );
    });

    test('wrong key fails decryption', () async {
      final key1 = await MediaCrypto.generateMediaKey();
      final key2 = await MediaCrypto.generateMediaKey();
      final plaintext = Uint8List.fromList([1, 2, 3, 4]);

      final ciphertext = await MediaCrypto.encrypt(plaintext, key1);

      // Use the wrong key's key but right IV.
      final wrongKey = MediaKey(key: key2.key, iv: key1.iv);
      expect(
        () => MediaCrypto.decrypt(ciphertext, wrongKey),
        throwsA(anything),
      );
    });

    test('SHA-256 mismatch is detected', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash = await MediaCrypto.computeSha256(data);

      // Modify the data.
      final modified = Uint8List.fromList([1, 2, 3, 4, 6]);
      final valid = await MediaCrypto.verifySha256(modified, hash);
      expect(valid, isFalse);
    });

    test(
      'two encryptions of same plaintext with same key produce '
      'same ciphertext (deterministic IV)',
      () async {
        final key = await MediaCrypto.generateMediaKey();
        final plaintext = Uint8List.fromList([42, 43, 44, 45]);

        final ct1 = await MediaCrypto.encrypt(plaintext, key);
        final ct2 = await MediaCrypto.encrypt(plaintext, key);

        // Since MediaCrypto uses a fixed IV from the key (not random
        // nonce), the ciphertext should be identical.
        expect(ct1, ct2);
      },
    );

    test(
      'large payload (1MB) encrypts and decrypts correctly',
      () async {
        final key = await MediaCrypto.generateMediaKey();
        final largeData = Uint8List.fromList(
          List.generate(1024 * 1024, (i) => i % 256),
        );

        final ct = await MediaCrypto.encrypt(largeData, key);
        final decrypted = await MediaCrypto.decrypt(ct, key);

        expect(decrypted.length, largeData.length);
        expect(decrypted, largeData);
      },
    );

    test('ciphertext is longer than plaintext (includes GCM tag)', () async {
      final key = await MediaCrypto.generateMediaKey();
      final plaintext = Uint8List.fromList([1, 2, 3]);

      final ct = await MediaCrypto.encrypt(plaintext, key);

      // Ciphertext should be plaintext length + 16 bytes MAC.
      expect(ct.length, plaintext.length + 16);
    });

    test('SHA-256 produces consistent results for same input', () async {
      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);

      final hash1 = await MediaCrypto.computeSha256(data);
      final hash2 = await MediaCrypto.computeSha256(data);

      expect(hash1, hash2);
    });

    test('different data produces different SHA-256 hashes', () async {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([1, 2, 4]);

      final hash1 = await MediaCrypto.computeSha256(data1);
      final hash2 = await MediaCrypto.computeSha256(data2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('wrong IV fails decryption', () async {
      final key = await MediaCrypto.generateMediaKey();
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

      final ct = await MediaCrypto.encrypt(plaintext, key);

      // Use same key but different IV.
      final wrongIv = Uint8List(12);
      for (var i = 0; i < 12; i++) {
        wrongIv[i] = key.iv[i] ^ 0xFF;
      }
      final wrongKey = MediaKey(key: key.key, iv: wrongIv);

      expect(
        () => MediaCrypto.decrypt(ct, wrongKey),
        throwsA(anything),
      );
    });
  });
}
