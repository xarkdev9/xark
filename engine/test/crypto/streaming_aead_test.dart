// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_chat_sdk/src/crypto/media/streaming_aead.dart';

void main() {
  group('StreamingAead', () {
    group('deriveChunkNonce', () {
      test('produces unique nonces for different chunk indices', () {
        final baseNonce = Uint8List(12);
        for (var i = 0; i < 12; i++) {
          baseNonce[i] = i;
        }

        final nonce0 = deriveChunkNonce(baseNonce, 0);
        final nonce1 = deriveChunkNonce(baseNonce, 1);
        final nonce2 = deriveChunkNonce(baseNonce, 2);

        expect(nonce0, isNot(equals(nonce1)));
        expect(nonce1, isNot(equals(nonce2)));
        expect(nonce0, isNot(equals(nonce2)));
      });

      test('chunk index 0 returns base nonce unchanged', () {
        final baseNonce = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
        final nonce = deriveChunkNonce(baseNonce, 0);
        expect(nonce, baseNonce);
      });

      test('does not mutate the original base nonce', () {
        final baseNonce = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
        final original = Uint8List.fromList(baseNonce);
        deriveChunkNonce(baseNonce, 42);
        expect(baseNonce, original);
      });

      test('XOR with chunk index affects only last 4 bytes', () {
        final baseNonce = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
        final nonce = deriveChunkNonce(baseNonce, 1);

        // First 8 bytes should be unchanged.
        for (var i = 0; i < 8; i++) {
          expect(nonce[i], baseNonce[i]);
        }
        // Last 4 bytes should differ (at least one byte).
        var diffCount = 0;
        for (var i = 8; i < 12; i++) {
          if (nonce[i] != baseNonce[i]) diffCount++;
        }
        expect(diffCount, greaterThan(0));
      });
    });

    group('round-trip encrypt/decrypt', () {
      test('empty file (0 bytes)', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List(0);

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        final decrypted = await decryptStream(
          Stream.fromIterable(encrypted),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        final result = _concat(decrypted);
        expect(result, plaintext);
      });

      test('single byte file', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList([42]);

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        expect(encrypted.length, 1); // One chunk.

        final decrypted = await decryptStream(
          Stream.fromIterable(encrypted),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        expect(_concat(decrypted), plaintext);
      });

      test('exactly 64KB (one full chunk)', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList(
          List.generate(chunkSize, (i) => i % 256),
        );

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        expect(encrypted.length, 1);

        final decrypted = await decryptStream(
          Stream.fromIterable(encrypted),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        expect(_concat(decrypted), plaintext);
      });

      test('64KB + 1 byte (two chunks)', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList(
          List.generate(chunkSize + 1, (i) => i % 256),
        );

        // Split into two chunks: 64KB + 1 byte.
        final chunk1 = plaintext.sublist(0, chunkSize);
        final chunk2 = plaintext.sublist(chunkSize);

        final encrypted = await encryptStream(
          Stream.fromIterable([chunk1, chunk2]),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        expect(encrypted.length, 2);

        final decrypted = await decryptStream(
          Stream.fromIterable(encrypted),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        expect(_concat(decrypted), plaintext);
      });

      test('1MB file (multiple chunks)', () async {
        final keyPair = generateStreamingKeySync();
        const size = 1024 * 1024; // 1MB
        final plaintext = Uint8List.fromList(
          List.generate(size, (i) => i % 256),
        );

        // Split into 64KB chunks.
        final chunks = <Uint8List>[];
        for (var i = 0; i < plaintext.length; i += chunkSize) {
          final end =
              (i + chunkSize < plaintext.length) ? i + chunkSize : plaintext.length;
          chunks.add(plaintext.sublist(i, end));
        }

        final encrypted = await encryptStream(
          Stream.fromIterable(chunks),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        // 1MB / 64KB = 16 chunks.
        expect(encrypted.length, 16);

        final decrypted = await decryptStream(
          Stream.fromIterable(encrypted),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        final result = _concat(decrypted);
        expect(result.length, plaintext.length);
        expect(result, plaintext);
      });
    });

    group('security', () {
      test('decrypt with wrong key fails', () async {
        final keyPair1 = generateStreamingKeySync();
        final keyPair2 = generateStreamingKeySync();
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair1.key,
          keyPair1.nonce,
        ).toList();

        expect(
          () async => await decryptStream(
            Stream.fromIterable(encrypted),
            keyPair2.key,
            keyPair1.nonce,
          ).toList(),
          throwsA(anything),
        );
      });

      test('tampering with auth tag causes decryption failure', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList([10, 20, 30, 40, 50]);

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        // Tamper with the last byte (part of the GCM auth tag).
        final tampered = Uint8List.fromList(encrypted[0]);
        tampered[tampered.length - 1] ^= 0xFF;

        expect(
          () async => await decryptStream(
            Stream.value(tampered),
            keyPair.key,
            keyPair.nonce,
          ).toList(),
          throwsA(anything),
        );
      });

      test('tampering with ciphertext causes decryption failure', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList(
          List.generate(100, (i) => i),
        );

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        // Tamper with a byte in the ciphertext body (after the 4-byte index).
        final tampered = Uint8List.fromList(encrypted[0]);
        tampered[5] ^= 0xFF;

        expect(
          () async => await decryptStream(
            Stream.value(tampered),
            keyPair.key,
            keyPair.nonce,
          ).toList(),
          throwsA(anything),
        );
      });
    });

    group('wire format', () {
      test('encrypted chunk starts with 4-byte big-endian index', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList([1, 2, 3]);

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        final chunk = encrypted[0];
        final index =
            ByteData.sublistView(chunk, 0, 4).getUint32(0, Endian.big);
        expect(index, 0);
      });

      test('encrypted chunk length = 4 + plaintext.length + 16', () async {
        final keyPair = generateStreamingKeySync();
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

        final encrypted = await encryptStream(
          Stream.value(plaintext),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        // 4 (index) + 5 (ciphertext, same length as plaintext) + 16 (GCM tag)
        expect(encrypted[0].length, 4 + 5 + 16);
      });

      test('multi-chunk indices are sequential', () async {
        final keyPair = generateStreamingKeySync();
        final chunk1 = Uint8List.fromList(List.generate(10, (i) => i));
        final chunk2 = Uint8List.fromList(List.generate(10, (i) => i + 10));
        final chunk3 = Uint8List.fromList(List.generate(10, (i) => i + 20));

        final encrypted = await encryptStream(
          Stream.fromIterable([chunk1, chunk2, chunk3]),
          keyPair.key,
          keyPair.nonce,
        ).toList();

        for (var i = 0; i < encrypted.length; i++) {
          final index = ByteData.sublistView(encrypted[i], 0, 4)
              .getUint32(0, Endian.big);
          expect(index, i);
        }
      });
    });

    group('StreamingAeadKey serialisation', () {
      test('toJson / fromJson round-trip', () {
        final key = StreamingAeadKey(
          key: Uint8List.fromList(List.generate(32, (i) => i)),
          baseNonce: Uint8List.fromList(List.generate(12, (i) => i + 32)),
          totalChunks: 42,
          sha256Hash: Uint8List.fromList(List.generate(32, (i) => i + 64)),
        );

        final json = key.toJson();
        final restored = StreamingAeadKey.fromJson(json);

        expect(restored.key, key.key);
        expect(restored.baseNonce, key.baseNonce);
        expect(restored.totalChunks, key.totalChunks);
        expect(restored.sha256Hash, key.sha256Hash);
      });
    });

    group('generateStreamingKeySync', () {
      test('produces 32-byte key and 12-byte nonce', () {
        final keyPair = generateStreamingKeySync();
        expect(keyPair.key.length, 32);
        expect(keyPair.nonce.length, 12);
      });

      test('produces different keys on each call', () {
        final a = generateStreamingKeySync();
        final b = generateStreamingKeySync();
        expect(a.key, isNot(equals(b.key)));
      });
    });
  });
}

/// Concatenate a list of [Uint8List] into a single [Uint8List].
Uint8List _concat(List<Uint8List> parts) {
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.toBytes();
}
