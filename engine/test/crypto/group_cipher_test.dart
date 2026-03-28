// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('GroupCipher', () {
    late FakeSenderKeyStore store;
    late GroupCipher cipher;

    setUp(() {
      store = FakeSenderKeyStore();
      cipher = GroupCipher(store: store);
    });

    test(
      'Alice creates sender key, distributes to Bob, Bob can decrypt',
      () async {
        const groupId = 'group-1';
        const aliceId = 'alice';

        // Alice creates her sender key.
        final dist = await cipher.createSenderKey(groupId, aliceId);

        // Bob processes the distribution (separate cipher with shared store).
        final bobStore = FakeSenderKeyStore();
        final bobCipher = GroupCipher(store: bobStore);
        await bobCipher.processSenderKeyDistribution(
          groupId,
          aliceId,
          dist,
        );

        // Alice encrypts.
        final plaintext = Uint8List.fromList(utf8.encode('Hello group!'));
        final ct = await cipher.encrypt(groupId, aliceId, plaintext);

        // Bob decrypts.
        final decrypted = await bobCipher.decrypt(groupId, aliceId, ct);
        expect(utf8.decode(decrypted), 'Hello group!');
      },
    );

    test('Alice sends 5 group messages, Bob decrypts all in order', () async {
      const groupId = 'group-2';
      const aliceId = 'alice';

      final dist = await cipher.createSenderKey(groupId, aliceId);

      final bobStore = FakeSenderKeyStore();
      final bobCipher = GroupCipher(store: bobStore);
      await bobCipher.processSenderKeyDistribution(
        groupId,
        aliceId,
        dist,
      );

      for (var i = 0; i < 5; i++) {
        final plaintext = Uint8List.fromList(utf8.encode('Group msg $i'));
        final ct = await cipher.encrypt(groupId, aliceId, plaintext);
        final decrypted = await bobCipher.decrypt(groupId, aliceId, ct);
        expect(utf8.decode(decrypted), 'Group msg $i');
      }
    });

    test(
      'two senders in the same group use independent chains',
      () async {
        const groupId = 'group-3';
        const aliceId = 'alice';
        const bobId = 'bob';

        // Alice creates her sender key using her own store.
        final aliceStore = FakeSenderKeyStore();
        final aliceCipher = GroupCipher(store: aliceStore);
        final aliceDist = await aliceCipher.createSenderKey(
          groupId,
          aliceId,
        );

        // Bob creates his sender key using his own store.
        final bobStore = FakeSenderKeyStore();
        final bobCipher = GroupCipher(store: bobStore);
        final bobDist = await bobCipher.createSenderKey(groupId, bobId);

        // Alice processes Bob's distribution.
        await aliceCipher.processSenderKeyDistribution(
          groupId,
          bobId,
          bobDist,
        );

        // Bob processes Alice's distribution.
        await bobCipher.processSenderKeyDistribution(
          groupId,
          aliceId,
          aliceDist,
        );

        // Alice sends.
        final aliceMsg = Uint8List.fromList(utf8.encode('From Alice'));
        final aliceCt = await aliceCipher.encrypt(
          groupId,
          aliceId,
          aliceMsg,
        );

        // Bob sends.
        final bobMsg = Uint8List.fromList(utf8.encode('From Bob'));
        final bobCt = await bobCipher.encrypt(groupId, bobId, bobMsg);

        // Cross-decrypt.
        final aliceDecBob = await aliceCipher.decrypt(
          groupId,
          bobId,
          bobCt,
        );
        expect(utf8.decode(aliceDecBob), 'From Bob');

        final bobDecAlice = await bobCipher.decrypt(
          groupId,
          aliceId,
          aliceCt,
        );
        expect(utf8.decode(bobDecAlice), 'From Alice');
      },
    );

    test('signature verification prevents tampering', () async {
      const groupId = 'group-4';
      const aliceId = 'alice';

      final dist = await cipher.createSenderKey(groupId, aliceId);

      final bobStore = FakeSenderKeyStore();
      final bobCipher = GroupCipher(store: bobStore);
      await bobCipher.processSenderKeyDistribution(
        groupId,
        aliceId,
        dist,
      );

      final plaintext = Uint8List.fromList(utf8.encode('Tamper-proof'));
      final ct = await cipher.encrypt(groupId, aliceId, plaintext);

      // Tamper with a byte in the ciphertext portion (after nonce+sig+iter).
      final tampered = Uint8List.fromList(ct);
      // Nonce(24) + sig(64) + iter(4) = 92 bytes header. Tamper past that.
      if (tampered.length > 93) {
        tampered[93] ^= 0xFF;
      }

      expect(
        () => bobCipher.decrypt(groupId, aliceId, tampered),
        throwsA(anything),
      );
    });

    test(
      'SenderKeyDistribution serializes/deserializes round-trip',
      () async {
        const groupId = 'group-5';
        const aliceId = 'alice';

        final dist = await cipher.createSenderKey(groupId, aliceId);

        final json = dist.toJson();
        final restored = SenderKeyDistribution.fromJson(json);

        expect(restored.chainKey, dist.chainKey);
        expect(restored.signingPublicKey, dist.signingPublicKey);
        expect(restored.iteration, dist.iteration);
      },
    );

    test('cannot decrypt with wrong sender ID', () async {
      const groupId = 'group-6';
      const aliceId = 'alice';
      const wrongSenderId = 'charlie';

      final dist = await cipher.createSenderKey(groupId, aliceId);

      final bobStore = FakeSenderKeyStore();
      final bobCipher = GroupCipher(store: bobStore);
      await bobCipher.processSenderKeyDistribution(
        groupId,
        aliceId,
        dist,
      );

      final plaintext = Uint8List.fromList(utf8.encode('For Alice'));
      final ct = await cipher.encrypt(groupId, aliceId, plaintext);

      // Try to decrypt with wrong sender ID.
      expect(
        () => bobCipher.decrypt(groupId, wrongSenderId, ct),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'encrypt fails if no sender key exists for group/sender',
      () async {
        const groupId = 'group-7';
        const aliceId = 'alice';

        final plaintext = Uint8List.fromList(utf8.encode('No key'));
        expect(
          () => cipher.encrypt(groupId, aliceId, plaintext),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('sender key iteration advances after each encryption', () async {
      const groupId = 'group-8';
      const aliceId = 'alice';

      await cipher.createSenderKey(groupId, aliceId);

      var record = await store.loadSenderKey(groupId, aliceId);
      expect(record!.iteration, 1);

      // Encrypt once.
      await cipher.encrypt(
        groupId,
        aliceId,
        Uint8List.fromList(utf8.encode('Message 1')),
      );

      record = await store.loadSenderKey(groupId, aliceId);
      expect(record!.iteration, 2);

      // Encrypt again.
      await cipher.encrypt(
        groupId,
        aliceId,
        Uint8List.fromList(utf8.encode('Message 2')),
      );

      record = await store.loadSenderKey(groupId, aliceId);
      expect(record!.iteration, 3);
    });

    test('deleteSenderKey removes the key from the store', () async {
      const groupId = 'group-9';
      const aliceId = 'alice';

      await cipher.createSenderKey(groupId, aliceId);
      expect(await store.loadSenderKey(groupId, aliceId), isNotNull);

      await store.deleteSenderKey(groupId, aliceId);
      expect(await store.loadSenderKey(groupId, aliceId), isNull);
    });
  });
}
