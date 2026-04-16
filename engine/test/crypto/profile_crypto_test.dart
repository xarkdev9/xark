// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileCrypto', () {
    test('generateProfileKey returns 32 bytes', () async {
      final key = await ProfileCrypto.generateProfileKey();
      expect(key.length, 32);
    });

    test('encrypt then decrypt round-trip', () async {
      final key = await ProfileCrypto.generateProfileKey();
      final plaintext = Uint8List.fromList(
        utf8.encode('John Doe'),
      );

      final ct = await ProfileCrypto.encrypt(plaintext, key);
      final decrypted = await ProfileCrypto.decrypt(ct, key);

      expect(utf8.decode(decrypted), 'John Doe');
    });

    test('different profile keys produce different ciphertext', () async {
      final key1 = await ProfileCrypto.generateProfileKey();
      final key2 = await ProfileCrypto.generateProfileKey();
      final plaintext = Uint8List.fromList(
        utf8.encode('Same name'),
      );

      final ct1 = await ProfileCrypto.encrypt(plaintext, key1);
      final ct2 = await ProfileCrypto.encrypt(plaintext, key2);

      // Different keys produce different ciphertext.
      expect(ct1, isNot(equals(ct2)));
    });

    test('wrong profile key fails decryption', () async {
      final key1 = await ProfileCrypto.generateProfileKey();
      final key2 = await ProfileCrypto.generateProfileKey();
      final plaintext = Uint8List.fromList(utf8.encode('Secret name'));

      final ct = await ProfileCrypto.encrypt(plaintext, key1);

      expect(
        () => ProfileCrypto.decrypt(ct, key2),
        throwsA(anything),
      );
    });

    test('two profile keys are different', () async {
      final key1 = await ProfileCrypto.generateProfileKey();
      final key2 = await ProfileCrypto.generateProfileKey();

      expect(key1, isNot(equals(key2)));
    });

    test(
      'ciphertext format is nonce(12) + ciphertext + mac(16)',
      () async {
        final key = await ProfileCrypto.generateProfileKey();
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

        final ct = await ProfileCrypto.encrypt(plaintext, key);

        // Expected length: 12 (nonce) + 5 (plaintext) + 16 (mac) = 33.
        expect(ct.length, 12 + 5 + 16);
      },
    );

    test('tampered ciphertext fails decryption', () async {
      final key = await ProfileCrypto.generateProfileKey();
      final plaintext = Uint8List.fromList(utf8.encode('Intact'));

      final ct = await ProfileCrypto.encrypt(plaintext, key);

      // Tamper with the ciphertext portion (after the 12-byte nonce).
      final tampered = Uint8List.fromList(ct);
      tampered[13] ^= 0xFF;

      expect(
        () => ProfileCrypto.decrypt(tampered, key),
        throwsA(anything),
      );
    });

    test('empty plaintext encrypts and decrypts', () async {
      final key = await ProfileCrypto.generateProfileKey();
      final plaintext = Uint8List(0);

      final ct = await ProfileCrypto.encrypt(plaintext, key);
      final decrypted = await ProfileCrypto.decrypt(ct, key);

      expect(decrypted, plaintext);
    });
  });
}
