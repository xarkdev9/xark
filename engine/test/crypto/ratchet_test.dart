// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DoubleRatchet', () {
    test('Alice can encrypt, Bob can decrypt (single message)', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;
      var bobState = session.bob;

      final plaintext = Uint8List.fromList(utf8.encode('Hello, Bob!'));

      final encrypted = await DoubleRatchet.encrypt(aliceState, plaintext);
      aliceState = encrypted.newState;

      final decrypted = await DoubleRatchet.decrypt(
        bobState,
        encrypted.ciphertext,
        encrypted.encryptedHeader,
      );
      bobState = decrypted.newState;

      expect(utf8.decode(decrypted.plaintext), 'Hello, Bob!');
    });

    test(
      'Bob can encrypt a reply, Alice can decrypt (full exchange)',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice sends first.
        final msg1 = Uint8List.fromList(utf8.encode('Hey Bob'));
        final enc1 = await DoubleRatchet.encrypt(aliceState, msg1);
        aliceState = enc1.newState;

        final dec1 = await DoubleRatchet.decrypt(
          bobState,
          enc1.ciphertext,
          enc1.encryptedHeader,
        );
        bobState = dec1.newState;
        expect(utf8.decode(dec1.plaintext), 'Hey Bob');

        // Bob replies.
        final msg2 = Uint8List.fromList(utf8.encode('Hey Alice'));
        final enc2 = await DoubleRatchet.encrypt(bobState, msg2);
        bobState = enc2.newState;

        final dec2 = await DoubleRatchet.decrypt(
          aliceState,
          enc2.ciphertext,
          enc2.encryptedHeader,
        );
        aliceState = dec2.newState;
        expect(utf8.decode(dec2.plaintext), 'Hey Alice');
      },
    );

    test(
      '20 sequential messages in each direction decrypt correctly',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice sends 20 messages.
        for (var i = 0; i < 20; i++) {
          final msg = Uint8List.fromList(utf8.encode('Alice msg $i'));
          final enc = await DoubleRatchet.encrypt(aliceState, msg);
          aliceState = enc.newState;

          final dec = await DoubleRatchet.decrypt(
            bobState,
            enc.ciphertext,
            enc.encryptedHeader,
          );
          bobState = dec.newState;
          expect(utf8.decode(dec.plaintext), 'Alice msg $i');
        }

        // Bob sends 20 messages.
        for (var i = 0; i < 20; i++) {
          final msg = Uint8List.fromList(utf8.encode('Bob msg $i'));
          final enc = await DoubleRatchet.encrypt(bobState, msg);
          bobState = enc.newState;

          final dec = await DoubleRatchet.decrypt(
            aliceState,
            enc.ciphertext,
            enc.encryptedHeader,
          );
          aliceState = dec.newState;
          expect(utf8.decode(dec.plaintext), 'Bob msg $i');
        }
      },
    );

    test(
      'out-of-order messages decrypt correctly (skip 1)',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice sends two messages.
        final msg0 = Uint8List.fromList(utf8.encode('Message 0'));
        final enc0 = await DoubleRatchet.encrypt(aliceState, msg0);
        aliceState = enc0.newState;

        final msg1 = Uint8List.fromList(utf8.encode('Message 1'));
        final enc1 = await DoubleRatchet.encrypt(aliceState, msg1);
        aliceState = enc1.newState;

        // Bob receives message 1 first (skipping message 0).
        final dec1 = await DoubleRatchet.decrypt(
          bobState,
          enc1.ciphertext,
          enc1.encryptedHeader,
        );
        bobState = dec1.newState;
        expect(utf8.decode(dec1.plaintext), 'Message 1');

        // Now Bob receives message 0 (out of order).
        final dec0 = await DoubleRatchet.decrypt(
          bobState,
          enc0.ciphertext,
          enc0.encryptedHeader,
        );
        bobState = dec0.newState;
        expect(utf8.decode(dec0.plaintext), 'Message 0');
      },
    );

    test(
      'messages skipped by up to 5 decrypt correctly',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice sends 6 messages.
        final encrypted = <EncryptResult>[];
        for (var i = 0; i < 6; i++) {
          final msg = Uint8List.fromList(utf8.encode('Msg $i'));
          final enc = await DoubleRatchet.encrypt(aliceState, msg);
          aliceState = enc.newState;
          encrypted.add(enc);
        }

        // Bob receives only the last one first (skipping 5).
        final dec5 = await DoubleRatchet.decrypt(
          bobState,
          encrypted[5].ciphertext,
          encrypted[5].encryptedHeader,
        );
        bobState = dec5.newState;
        expect(utf8.decode(dec5.plaintext), 'Msg 5');

        // Now receive all the skipped ones in reverse order.
        for (var i = 4; i >= 0; i--) {
          final dec = await DoubleRatchet.decrypt(
            bobState,
            encrypted[i].ciphertext,
            encrypted[i].encryptedHeader,
          );
          bobState = dec.newState;
          expect(utf8.decode(dec.plaintext), 'Msg $i');
        }
      },
    );

    test('decrypting a tampered ciphertext throws', () async {
      final session = await buildAliceBobSession();
      final aliceState = session.alice;
      final bobState = session.bob;

      final msg = Uint8List.fromList(utf8.encode('Secure message'));
      final enc = await DoubleRatchet.encrypt(aliceState, msg);

      // Tamper with the ciphertext.
      final tampered = Uint8List.fromList(enc.ciphertext);
      tampered[tampered.length - 5] ^= 0xFF;

      expect(
        () => DoubleRatchet.decrypt(
          bobState,
          tampered,
          enc.encryptedHeader,
        ),
        throwsA(anything),
      );
    });

    test(
      'ratchet state is immutable -- encrypt returns new state',
      () async {
        final session = await buildAliceBobSession();
        final originalState = session.alice;

        final msg = Uint8List.fromList(utf8.encode('Test'));
        final enc = await DoubleRatchet.encrypt(originalState, msg);

        // The original state must not have changed.
        expect(originalState.sendMessageNumber, 0);
        expect(enc.newState.sendMessageNumber, 1);
      },
    );

    test('chain keys advance after each message', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;

      final chainKey0 = aliceState.sendChainKey;

      final msg = Uint8List.fromList(utf8.encode('Advance'));
      final enc = await DoubleRatchet.encrypt(aliceState, msg);
      aliceState = enc.newState;

      final chainKey1 = aliceState.sendChainKey;

      // Chain keys must differ after sending a message.
      expect(chainKey1, isNot(equals(chainKey0)));
    });

    test('message keys are unique per message', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;
      var bobState = session.bob;

      // Send two messages and collect ciphertexts.
      final msg1 = Uint8List.fromList(utf8.encode('Same text'));
      final enc1 = await DoubleRatchet.encrypt(aliceState, msg1);
      aliceState = enc1.newState;

      final msg2 = Uint8List.fromList(utf8.encode('Same text'));
      final enc2 = await DoubleRatchet.encrypt(aliceState, msg2);
      aliceState = enc2.newState;

      // Even though plaintext is the same, ciphertexts are different
      // because message keys are unique.
      expect(enc1.ciphertext, isNot(equals(enc2.ciphertext)));

      // But both decrypt to the same plaintext.
      final dec1 = await DoubleRatchet.decrypt(
        bobState,
        enc1.ciphertext,
        enc1.encryptedHeader,
      );
      bobState = dec1.newState;

      final dec2 = await DoubleRatchet.decrypt(
        bobState,
        enc2.ciphertext,
        enc2.encryptedHeader,
      );
      bobState = dec2.newState;

      expect(utf8.decode(dec1.plaintext), 'Same text');
      expect(utf8.decode(dec2.plaintext), 'Same text');
    });

    test(
      'Bob cannot encrypt until first message received (no send chain)',
      () async {
        final session = await buildAliceBobSession();
        final bobState = session.bob;

        // Bob's initial state has no send chain key.
        expect(bobState.sendChainKey, isNull);

        final msg = Uint8List.fromList(utf8.encode('Premature'));
        expect(
          () => DoubleRatchet.encrypt(bobState, msg),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('ratchet header contains correct message number', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;

      expect(aliceState.sendMessageNumber, 0);

      final enc1 = await DoubleRatchet.encrypt(
        aliceState,
        Uint8List.fromList(utf8.encode('First')),
      );
      aliceState = enc1.newState;
      expect(aliceState.sendMessageNumber, 1);

      final enc2 = await DoubleRatchet.encrypt(
        aliceState,
        Uint8List.fromList(utf8.encode('Second')),
      );
      aliceState = enc2.newState;
      expect(aliceState.sendMessageNumber, 2);
    });

    test(
      'multiple DH ratchet steps work correctly '
      '(Alice sends, Bob sends, Alice sends)',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Step 1: Alice -> Bob.
        final msg1 = Uint8List.fromList(utf8.encode('A->B'));
        final enc1 = await DoubleRatchet.encrypt(aliceState, msg1);
        aliceState = enc1.newState;

        final dec1 = await DoubleRatchet.decrypt(
          bobState,
          enc1.ciphertext,
          enc1.encryptedHeader,
        );
        bobState = dec1.newState;
        expect(utf8.decode(dec1.plaintext), 'A->B');

        // Step 2: Bob -> Alice (triggers DH ratchet on Bob's side).
        final msg2 = Uint8List.fromList(utf8.encode('B->A'));
        final enc2 = await DoubleRatchet.encrypt(bobState, msg2);
        bobState = enc2.newState;

        final dec2 = await DoubleRatchet.decrypt(
          aliceState,
          enc2.ciphertext,
          enc2.encryptedHeader,
        );
        aliceState = dec2.newState;
        expect(utf8.decode(dec2.plaintext), 'B->A');

        // Step 3: Alice -> Bob (triggers another DH ratchet).
        final msg3 = Uint8List.fromList(utf8.encode('A->B again'));
        final enc3 = await DoubleRatchet.encrypt(aliceState, msg3);
        aliceState = enc3.newState;

        final dec3 = await DoubleRatchet.decrypt(
          bobState,
          enc3.ciphertext,
          enc3.encryptedHeader,
        );
        bobState = dec3.newState;
        expect(utf8.decode(dec3.plaintext), 'A->B again');
      },
    );

    test(
      'skipped message keys persist across DH ratchet steps',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice sends two messages.
        final msg0 = Uint8List.fromList(utf8.encode('Early msg'));
        final enc0 = await DoubleRatchet.encrypt(aliceState, msg0);
        aliceState = enc0.newState;

        final msg1 = Uint8List.fromList(utf8.encode('Later msg'));
        final enc1 = await DoubleRatchet.encrypt(aliceState, msg1);
        aliceState = enc1.newState;

        // Bob only receives the second message.
        final dec1 = await DoubleRatchet.decrypt(
          bobState,
          enc1.ciphertext,
          enc1.encryptedHeader,
        );
        bobState = dec1.newState;
        expect(utf8.decode(dec1.plaintext), 'Later msg');

        // Bob replies (triggers DH ratchet step).
        final reply = Uint8List.fromList(utf8.encode('Bob reply'));
        final encReply = await DoubleRatchet.encrypt(bobState, reply);
        bobState = encReply.newState;

        final decReply = await DoubleRatchet.decrypt(
          aliceState,
          encReply.ciphertext,
          encReply.encryptedHeader,
        );
        aliceState = decReply.newState;
        expect(utf8.decode(decReply.plaintext), 'Bob reply');

        // Now Bob can still decrypt the skipped first message.
        final dec0 = await DoubleRatchet.decrypt(
          bobState,
          enc0.ciphertext,
          enc0.encryptedHeader,
        );
        bobState = dec0.newState;
        expect(utf8.decode(dec0.plaintext), 'Early msg');
      },
    );

    test('RatchetHeader toJson/fromJson round-trip', () {
      final header = RatchetHeader(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        previousCount: 7,
        messageNumber: 42,
      );

      final json = header.toJson();
      final restored = RatchetHeader.fromJson(json);

      expect(restored.publicKey, header.publicKey);
      expect(restored.previousCount, 7);
      expect(restored.messageNumber, 42);
    });

    test('RatchetState copyWith preserves unmodified fields', () {
      final state = RatchetState(
        rootKey: Uint8List(32),
        headerSecret: Uint8List(32),
        sendMessageNumber: 5,
        recvMessageNumber: 3,
        previousSendCount: 2,
      );

      final updated = state.copyWith(sendMessageNumber: 6);

      expect(updated.sendMessageNumber, 6);
      expect(updated.recvMessageNumber, 3);
      expect(updated.previousSendCount, 2);
      expect(updated.rootKey, state.rootKey);
    });

    test(
      'decrypting with tampered encrypted header throws',
      () async {
        final session = await buildAliceBobSession();
        final aliceState = session.alice;
        final bobState = session.bob;

        final msg = Uint8List.fromList(utf8.encode('Protected'));
        final enc = await DoubleRatchet.encrypt(aliceState, msg);

        // Tamper with the encrypted header.
        final tamperedHeader = Uint8List.fromList(enc.encryptedHeader);
        tamperedHeader[0] ^= 0xFF;

        expect(
          () => DoubleRatchet.decrypt(
            bobState,
            enc.ciphertext,
            tamperedHeader,
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'large message (10KB) encrypts and decrypts correctly',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        final largeMsg = Uint8List.fromList(
          List.generate(10240, (i) => i % 256),
        );

        final enc = await DoubleRatchet.encrypt(aliceState, largeMsg);
        aliceState = enc.newState;

        final dec = await DoubleRatchet.decrypt(
          bobState,
          enc.ciphertext,
          enc.encryptedHeader,
        );
        bobState = dec.newState;

        expect(dec.plaintext, largeMsg);
      },
    );

    test('empty message encrypts and decrypts correctly', () async {
      final session = await buildAliceBobSession();
      var aliceState = session.alice;
      var bobState = session.bob;

      final emptyMsg = Uint8List(0);

      final enc = await DoubleRatchet.encrypt(aliceState, emptyMsg);
      aliceState = enc.newState;

      final dec = await DoubleRatchet.decrypt(
        bobState,
        enc.ciphertext,
        enc.encryptedHeader,
      );
      bobState = dec.newState;

      expect(dec.plaintext, emptyMsg);
    });
  });
}
