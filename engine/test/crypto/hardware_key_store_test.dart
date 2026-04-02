import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/hardware_key_store.dart';
import 'dart:typed_data';

void main() {
  group('SoftwareKeyStore', () {
    late SoftwareKeyStore store;

    setUp(() async {
      store = SoftwareKeyStore();
      await store.initialize();
    });

    test('wrap and unwrap round-trips correctly', () async {
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final wrapped = await store.wrap(plaintext);
      final unwrapped = await store.unwrap(wrapped);
      expect(unwrapped, equals(plaintext));
    });

    test('wrapped data differs from plaintext', () async {
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final wrapped = await store.wrap(plaintext);
      expect(wrapped, isNot(equals(plaintext)));
      expect(wrapped.length, greaterThan(plaintext.length)); // nonce + mac overhead
    });

    test('different plaintexts produce different wrapped outputs', () async {
      final a = await store.wrap(Uint8List.fromList([1, 2, 3]));
      final b = await store.wrap(Uint8List.fromList([4, 5, 6]));
      expect(a, isNot(equals(b)));
    });

    test('unwrap with wrong data throws', () async {
      expect(
        () => store.unwrap(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(anything),
      );
    });

    test('isHardwareAvailable returns false for software store', () async {
      expect(await store.isHardwareAvailable(), false);
    });

    test('deleteWrappingKey clears state', () async {
      final plaintext = Uint8List.fromList([1, 2, 3]);
      await store.wrap(plaintext); // works
      await store.deleteWrappingKey();
      expect(
        () => store.wrap(plaintext),
        throwsA(isA<StateError>()),
      );
    });
  });
}
