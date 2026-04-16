// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/crypto.dart';
import 'package:e2ee_chat_sdk/src/domain/domain.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/message_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/outbox_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Creates an in-memory drift database for testing.
AppDatabase _createTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  // ===========================================================================
  // 1:1 E2EE Message Pipeline
  // ===========================================================================

  group('1:1 E2EE Message Pipeline', () {
    test(
      'Scenario 1: Alice encrypts text, Bob decrypts, matches original',
      () async {
        // 1. Establish a full X3DH + ratchet session between Alice and Bob.
        final session = await buildAliceBobSession();

        // 2. Alice encrypts a plaintext message.
        const plaintext = 'Hello Bob';
        final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

        final encResult = await DoubleRatchet.encrypt(
          session.alice,
          plaintextBytes,
        );

        // 3. Verify we got ciphertext and header bytes.
        expect(encResult.ciphertext, isNotEmpty);
        expect(encResult.encryptedHeader, isNotEmpty);
        expect(encResult.newState, isNotNull);

        // 4. The ciphertext should NOT contain the plaintext.
        final ctBase64 = base64Encode(encResult.ciphertext);
        expect(ctBase64, isNot(contains(plaintext)));

        // 5. Bob decrypts.
        final decResult = await DoubleRatchet.decrypt(
          session.bob,
          encResult.ciphertext,
          encResult.encryptedHeader,
        );

        // 6. Verify plaintext matches.
        final decryptedText = utf8.decode(decResult.plaintext);
        expect(decryptedText, equals(plaintext));
      },
    );

    test(
      'Scenario 2: Full exchange -- Alice sends, Bob replies, Alice reads',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice -> Bob: "Hello"
        final enc1 = await DoubleRatchet.encrypt(
          aliceState,
          Uint8List.fromList(utf8.encode('Hello')),
        );
        aliceState = enc1.newState;

        final dec1 = await DoubleRatchet.decrypt(
          bobState,
          enc1.ciphertext,
          enc1.encryptedHeader,
        );
        bobState = dec1.newState;
        expect(utf8.decode(dec1.plaintext), equals('Hello'));

        // Bob -> Alice: "Hi there"
        final enc2 = await DoubleRatchet.encrypt(
          bobState,
          Uint8List.fromList(utf8.encode('Hi there')),
        );
        bobState = enc2.newState;

        final dec2 = await DoubleRatchet.decrypt(
          aliceState,
          enc2.ciphertext,
          enc2.encryptedHeader,
        );
        aliceState = dec2.newState;
        expect(utf8.decode(dec2.plaintext), equals('Hi there'));

        // After the exchange, both ratchets have advanced.
        // Alice sent 1 message (msg 0), then received from Bob which
        // triggered a DH ratchet step resetting her send counter to 0.
        expect(aliceState.sendMessageNumber, equals(0));
        // Bob sent 1 message in his current sending chain.
        expect(bobState.sendMessageNumber, equals(1));
      },
    );

    test(
      'Scenario 3: Multiple sequential messages maintain ratchet integrity',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice sends 5 messages.
        final sentMessages = <String>[];
        for (var i = 0; i < 5; i++) {
          final text = 'Message $i from Alice';
          sentMessages.add(text);
          final enc = await DoubleRatchet.encrypt(
            aliceState,
            Uint8List.fromList(utf8.encode(text)),
          );
          aliceState = enc.newState;

          final dec = await DoubleRatchet.decrypt(
            bobState,
            enc.ciphertext,
            enc.encryptedHeader,
          );
          bobState = dec.newState;
          expect(utf8.decode(dec.plaintext), equals(text));
        }

        // Bob sends 3 replies.
        final replyMessages = <String>[];
        for (var i = 0; i < 3; i++) {
          final text = 'Reply $i from Bob';
          replyMessages.add(text);
          final enc = await DoubleRatchet.encrypt(
            bobState,
            Uint8List.fromList(utf8.encode(text)),
          );
          bobState = enc.newState;

          final dec = await DoubleRatchet.decrypt(
            aliceState,
            enc.ciphertext,
            enc.encryptedHeader,
          );
          aliceState = dec.newState;
          expect(utf8.decode(dec.plaintext), equals(text));
        }

        // All messages decrypted successfully -- ratchet integrity maintained.
        expect(sentMessages, hasLength(5));
        expect(replyMessages, hasLength(3));
      },
    );

    test(
      'Scenario 4: DecryptedMessage JSON payload round-trip through ratchet',
      () async {
        final session = await buildAliceBobSession();

        // Build a DecryptedMessage with all fields populated.
        final originalMessage = DecryptedMessage(
          text: 'Check out this photo!',
          type: 'media',
          replyTo: 'prev-msg-id-123',
          mediaUrl: 'https://storage.example.com/media/abc.enc',
          aesKeyBase64: base64Encode(Uint8List(32)),
          ivBase64: base64Encode(Uint8List(12)),
          mimeType: 'image/jpeg',
          inlineThumbnail: base64Encode(Uint8List.fromList([0xFF, 0xD8])),
          linkPreview: LinkPreview(
            url: 'https://example.com',
            title: 'Example Site',
            description: 'A sample link preview',
          ),
        );

        // Serialize to JSON bytes.
        final jsonBytes =
            Uint8List.fromList(utf8.encode(jsonEncode(originalMessage)));

        // Encrypt through ratchet.
        final enc = await DoubleRatchet.encrypt(session.alice, jsonBytes);

        // Decrypt.
        final dec = await DoubleRatchet.decrypt(
          session.bob,
          enc.ciphertext,
          enc.encryptedHeader,
        );

        // Parse back to DecryptedMessage.
        final parsed = DecryptedMessage.fromJson(
          jsonDecode(utf8.decode(dec.plaintext)) as Map<String, dynamic>,
        );

        // Verify all fields.
        expect(parsed.text, equals(originalMessage.text));
        expect(parsed.type, equals(originalMessage.type));
        expect(parsed.replyTo, equals(originalMessage.replyTo));
        expect(parsed.mediaUrl, equals(originalMessage.mediaUrl));
        expect(parsed.aesKeyBase64, equals(originalMessage.aesKeyBase64));
        expect(parsed.ivBase64, equals(originalMessage.ivBase64));
        expect(parsed.mimeType, equals(originalMessage.mimeType));
        expect(
          parsed.inlineThumbnail,
          equals(originalMessage.inlineThumbnail),
        );
        expect(parsed.linkPreview, isNotNull);
        expect(parsed.linkPreview!.url, equals('https://example.com'));
        expect(parsed.linkPreview!.title, equals('Example Site'));
      },
    );

    test(
      'Scenario 5: Persistence round-trip -- message saved and loaded from DB',
      () async {
        final db = _createTestDb();
        addTearDown(db.close);

        final repo = MessageRepositoryImpl(db);

        // Create a Message domain object.
        final message = Message(
          id: 'msg-integration-1',
          groupId: 'conv-alice-bob',
          senderId: 'alice',
          senderDeviceId: 'device-alice-1',
          type: MessageType.e2ee,
          status: MessageStatus.sent,
          timestamp: DateTime(2025, 3, 15, 10, 30),
          replyToMessageId: 'msg-prev',
          isStarred: true,
        );

        // Save to repository.
        await repo.saveMessage(message);

        // Load from repository.
        final loaded = await repo.getMessageById('msg-integration-1');

        // Verify all fields.
        expect(loaded, isNotNull);
        expect(loaded!.id, equals('msg-integration-1'));
        expect(loaded.groupId, equals('conv-alice-bob'));
        expect(loaded.senderId, equals('alice'));
        expect(loaded.senderDeviceId, equals('device-alice-1'));
        expect(loaded.type, equals(MessageType.e2ee));
        expect(loaded.status, equals(MessageStatus.sent));
        expect(loaded.replyToMessageId, equals('msg-prev'));
        expect(loaded.isStarred, isTrue);
      },
    );

    test(
      'Scenario 6: MessageEnvelope wire format has correct snake_case fields',
      () async {
        final envelope = MessageEnvelope(
          groupId: 'space-123',
          senderDeviceId: 42,
          ciphertext: base64Encode(Uint8List.fromList([1, 2, 3])),
          recipientId: 'bob-user-id',
          recipientDeviceId: 7,
          ratchetHeader: base64Encode(Uint8List.fromList([4, 5, 6])),
          id: 'msg-uuid-v7',
          distributionCiphertexts: [
            DistributionCiphertext(
              id: 'mc_dist-1',
              recipientId: 'charlie',
              recipientDeviceId: 3,
              ciphertext: base64Encode(Uint8List.fromList([7, 8, 9])),
              ratchetHeader: base64Encode(Uint8List.fromList([10, 11])),
            ),
          ],
        );

        final json = envelope.toJson();

        // Verify snake_case field names.
        expect(json.containsKey('group_id'), isTrue);
        expect(json.containsKey('sender_device_id'), isTrue);
        expect(json.containsKey('recipient_id'), isTrue);
        expect(json.containsKey('recipient_device_id'), isTrue);
        expect(json.containsKey('ratchet_header'), isTrue);
        expect(json.containsKey('message_type'), isTrue);
        expect(json.containsKey('distribution_ciphertexts'), isTrue);

        // Verify values.
        expect(json['group_id'], equals('space-123'));
        expect(json['sender_device_id'], equals(42));
        expect(json['recipient_id'], equals('bob-user-id'));
        expect(json['recipient_device_id'], equals(7));
        expect(json['message_type'], equals('e2ee'));

        // Verify distribution_ciphertexts structure.
        final dists = json['distribution_ciphertexts'] as List<dynamic>;
        expect(dists, hasLength(1));
        final dist = dists[0] as Map<String, dynamic>;
        expect(dist.containsKey('recipient_id'), isTrue);
        expect(dist.containsKey('recipient_device_id'), isTrue);
        expect(dist.containsKey('ratchet_header'), isTrue);
        expect(dist['recipient_id'], equals('charlie'));
        expect(dist['recipient_device_id'], equals(3));

        // Verify round-trip deserialization.
        final restored = MessageEnvelope.fromJson(json);
        expect(restored.groupId, equals(envelope.groupId));
        expect(restored.senderDeviceId, equals(envelope.senderDeviceId));
        expect(restored.recipientId, equals(envelope.recipientId));
        expect(
          restored.distributionCiphertexts,
          hasLength(1),
        );
      },
    );

    test(
      'Scenario 7: Out-of-order messages decrypt with skipped keys',
      () async {
        final session = await buildAliceBobSession();
        var aliceState = session.alice;
        var bobState = session.bob;

        // Alice encrypts 3 messages (msg0, msg1, msg2).
        final encResults = <EncryptResult>[];
        for (var i = 0; i < 3; i++) {
          final enc = await DoubleRatchet.encrypt(
            aliceState,
            Uint8List.fromList(utf8.encode('Message $i')),
          );
          aliceState = enc.newState;
          encResults.add(enc);
        }

        // Bob decrypts message 2 first (skipping 0 and 1).
        final dec2 = await DoubleRatchet.decrypt(
          bobState,
          encResults[2].ciphertext,
          encResults[2].encryptedHeader,
        );
        bobState = dec2.newState;
        expect(utf8.decode(dec2.plaintext), equals('Message 2'));

        // Skipped keys for messages 0 and 1 should be stored.
        expect(bobState.skippedKeys, isNotEmpty);

        // Bob now decrypts message 0.
        final dec0 = await DoubleRatchet.decrypt(
          bobState,
          encResults[0].ciphertext,
          encResults[0].encryptedHeader,
        );
        bobState = dec0.newState;
        expect(utf8.decode(dec0.plaintext), equals('Message 0'));

        // Bob now decrypts message 1.
        final dec1 = await DoubleRatchet.decrypt(
          bobState,
          encResults[1].ciphertext,
          encResults[1].encryptedHeader,
        );
        bobState = dec1.newState;
        expect(utf8.decode(dec1.plaintext), equals('Message 1'));

        // All skipped keys should be consumed now.
        expect(bobState.skippedKeys, isEmpty);
      },
    );
  });

  // ===========================================================================
  // Group E2EE Message Pipeline
  // ===========================================================================

  group('Group E2EE Message Pipeline', () {
    test(
      'Scenario 8: Sender Key distribution + group encrypt/decrypt',
      () async {
        const groupId = 'group-alpha';
        const aliceId = 'alice';

        // Create separate stores for Alice and Bob.
        final aliceStore = FakeSenderKeyStore();
        final bobStore = FakeSenderKeyStore();

        final aliceCipher = GroupCipher(store: aliceStore);
        final bobCipher = GroupCipher(store: bobStore);

        // Alice creates a Sender Key and gets the distribution message.
        final distribution =
            await aliceCipher.createSenderKey(groupId, aliceId);
        expect(distribution.chainKey, hasLength(32));
        expect(distribution.signingPublicKey, hasLength(32));
        expect(distribution.iteration, equals(1));

        // Bob processes the distribution (stores Alice's Sender Key).
        await bobCipher.processSenderKeyDistribution(
          groupId,
          aliceId,
          distribution,
        );

        // Verify Bob's store has Alice's key.
        final storedKey =
            await bobStore.loadSenderKey(groupId, aliceId);
        expect(storedKey, isNotNull);

        // Alice encrypts a group message.
        const plaintext = 'Hello group!';
        final encrypted = await aliceCipher.encrypt(
          groupId,
          aliceId,
          Uint8List.fromList(utf8.encode(plaintext)),
        );

        // Verify wire format: nonce(24) + sig(64) + iter(4) + ct + mac(16).
        expect(encrypted.length, greaterThanOrEqualTo(24 + 64 + 4 + 16));

        // Parse wire format to verify structure.
        final nonce = encrypted.sublist(0, 24);
        expect(nonce, hasLength(24));
        final sig = encrypted.sublist(24, 88);
        expect(sig, hasLength(64));
        final iterBytes = encrypted.sublist(88, 92);
        final iteration = (iterBytes[0] << 24) |
            (iterBytes[1] << 16) |
            (iterBytes[2] << 8) |
            iterBytes[3];
        expect(iteration, equals(1));

        // Bob decrypts.
        final decrypted = await bobCipher.decrypt(
          groupId,
          aliceId,
          encrypted,
        );
        expect(utf8.decode(decrypted), equals(plaintext));
      },
    );

    test(
      'Scenario 9: Multiple group messages maintain chain',
      () async {
        const groupId = 'group-beta';
        const senderId = 'alice';

        final aliceStore = FakeSenderKeyStore();
        final bobStore = FakeSenderKeyStore();
        final aliceCipher = GroupCipher(store: aliceStore);
        final bobCipher = GroupCipher(store: bobStore);

        // Distribute Sender Key.
        final dist = await aliceCipher.createSenderKey(groupId, senderId);
        await bobCipher.processSenderKeyDistribution(
          groupId,
          senderId,
          dist,
        );

        // Alice sends 5 group messages.
        for (var i = 0; i < 5; i++) {
          final text = 'Group msg $i';
          final encrypted = await aliceCipher.encrypt(
            groupId,
            senderId,
            Uint8List.fromList(utf8.encode(text)),
          );

          // Verify iteration advances in wire format.
          final iterBytes = encrypted.sublist(88, 92);
          final wireIteration = (iterBytes[0] << 24) |
              (iterBytes[1] << 16) |
              (iterBytes[2] << 8) |
              iterBytes[3];
          expect(wireIteration, equals(i + 1));

          final decrypted = await bobCipher.decrypt(
            groupId,
            senderId,
            encrypted,
          );
          expect(utf8.decode(decrypted), equals(text));
        }

        // Verify the chain state advanced: Alice's iteration should be 6.
        final aliceRecord =
            await aliceStore.loadSenderKey(groupId, senderId);
        expect(aliceRecord!.iteration, equals(6));

        // Bob's stored iteration should also be 6 (next expected).
        final bobRecord =
            await bobStore.loadSenderKey(groupId, senderId);
        expect(bobRecord!.iteration, equals(6));
      },
    );
  });

  // ===========================================================================
  // Media Pipeline
  // ===========================================================================

  group('Media Pipeline', () {
    test(
      'Scenario 10: Media encrypt -> upload -> download -> decrypt -> verify',
      () async {
        // 1. Generate test plaintext bytes (1KB random).
        final rng = Random.secure();
        final originalBytes = Uint8List(1024);
        for (var i = 0; i < originalBytes.length; i++) {
          originalBytes[i] = rng.nextInt(256);
        }

        // 2. Generate MediaKey.
        final mediaKey = await MediaCrypto.generateMediaKey();
        expect(mediaKey.key, hasLength(32));
        expect(mediaKey.iv, hasLength(12));

        // 3. Encrypt with MediaCrypto.
        final encryptedBlob =
            await MediaCrypto.encrypt(originalBytes, mediaKey);
        expect(encryptedBlob.length, greaterThan(originalBytes.length));

        // 4. Compute SHA-256 of encrypted blob.
        final sha256Hash = await MediaCrypto.computeSha256(encryptedBlob);
        expect(sha256Hash, hasLength(32));

        // 5. "Upload" (store in memory map -- simulates server storage).
        final storageBlob = Uint8List.fromList(encryptedBlob);

        // 6. "Download" (retrieve from memory).
        final downloadedBlob = storageBlob;

        // 7. Verify SHA-256 of downloaded blob.
        final hashValid =
            await MediaCrypto.verifySha256(downloadedBlob, sha256Hash);
        expect(hashValid, isTrue);

        // 8. Decrypt.
        final decryptedBytes =
            await MediaCrypto.decrypt(downloadedBlob, mediaKey);

        // 9. Verify plaintext matches original.
        expect(decryptedBytes, equals(originalBytes));
      },
    );

    test(
      'Scenario 11: Media key transport through ratchet',
      () async {
        final session = await buildAliceBobSession();

        // Generate a media key and encrypt some test data.
        final mediaKey = await MediaCrypto.generateMediaKey();
        final testMedia = Uint8List.fromList(List.filled(256, 0xAB));
        final encryptedMedia =
            await MediaCrypto.encrypt(testMedia, mediaKey);
        final mediaHash = await MediaCrypto.computeSha256(encryptedMedia);

        // Create a DecryptedMessage with media info.
        final mediaMessage = DecryptedMessage(
          text: 'Here is a file',
          type: 'media',
          mediaUrl: 'https://storage.example.com/media/test-file.enc',
          aesKeyBase64: base64Encode(mediaKey.key),
          ivBase64: base64Encode(mediaKey.iv),
          mimeType: 'application/octet-stream',
        );

        // Encrypt the media message through the ratchet.
        final jsonPayload =
            Uint8List.fromList(utf8.encode(jsonEncode(mediaMessage)));
        final enc = await DoubleRatchet.encrypt(session.alice, jsonPayload);

        // Decrypt on the other side.
        final dec = await DoubleRatchet.decrypt(
          session.bob,
          enc.ciphertext,
          enc.encryptedHeader,
        );

        // Parse the DecryptedMessage.
        final parsed = DecryptedMessage.fromJson(
          jsonDecode(utf8.decode(dec.plaintext)) as Map<String, dynamic>,
        );

        // Reconstruct the MediaKey from the transported key material.
        final recoveredKey = MediaKey(
          key: Uint8List.fromList(base64Decode(parsed.aesKeyBase64!)),
          iv: Uint8List.fromList(base64Decode(parsed.ivBase64!)),
        );

        // Use the recovered key to decrypt the media blob.
        final decryptedMedia =
            await MediaCrypto.decrypt(encryptedMedia, recoveredKey);
        expect(decryptedMedia, equals(testMedia));

        // Verify hash.
        final hashValid =
            await MediaCrypto.verifySha256(encryptedMedia, mediaHash);
        expect(hashValid, isTrue);
      },
    );
  });

  // ===========================================================================
  // Plaintext Cache
  // ===========================================================================

  group('Plaintext Cache', () {
    test(
      'Scenario 12: Plaintext cached after decrypt, re-read from cache',
      () async {
        final db = _createTestDb();
        addTearDown(db.close);

        final decryptedRepo = DecryptedMessageRepositoryImpl(db);

        // Simulate decrypting a message via ratchet.
        final session = await buildAliceBobSession();
        const originalText = 'Cached message content';
        final enc = await DoubleRatchet.encrypt(
          session.alice,
          Uint8List.fromList(utf8.encode(originalText)),
        );
        final dec = await DoubleRatchet.decrypt(
          session.bob,
          enc.ciphertext,
          enc.encryptedHeader,
        );
        final decryptedText = utf8.decode(dec.plaintext);

        // Cache the decrypted plaintext.
        await decryptedRepo.cachePlaintext('msg-cached-1', decryptedText);

        // Retrieve from cache.
        final cached = await decryptedRepo.getCachedPlaintext('msg-cached-1');
        expect(cached, equals(originalText));

        // Cache with media JSON.
        const mediaJson =
            '{"mediaId":"m1","mimeType":"image/png","sizeBytes":1024}';
        await decryptedRepo.cachePlaintext(
          'msg-cached-2',
          'Photo caption',
          mediaJson: mediaJson,
        );

        final cachedText =
            await decryptedRepo.getCachedPlaintext('msg-cached-2');
        final cachedMedia =
            await decryptedRepo.getCachedMediaJson('msg-cached-2');
        expect(cachedText, equals('Photo caption'));
        expect(cachedMedia, equals(mediaJson));
      },
    );
  });

  // ===========================================================================
  // Outbox
  // ===========================================================================

  group('Outbox', () {
    test(
      'Scenario 13: Message enqueued in outbox, drained on connect',
      () async {
        final db = _createTestDb();
        addTearDown(db.close);

        final outboxRepo = OutboxRepositoryImpl(db);

        // Enqueue an item (simulating offline message send).
        final now = DateTime.now();
        final item = OutboxItemRow(
          id: 'outbox-integration-1',
          groupId: 'conv-alice-bob',
          encryptedEnvelope:
              Uint8List.fromList(utf8.encode('{"ciphertext":"abc"}')),
          recipientDeviceIds: jsonEncode(['bob:1', 'bob:2']),
          retryCount: 0,
          createdAt: now,
          nextRetryAt: now,
        );
        await outboxRepo.enqueue(item);

        // Verify getPending returns the item.
        var pending = await outboxRepo.getPending();
        expect(pending, hasLength(1));
        expect(pending.first.id, equals('outbox-integration-1'));
        expect(pending.first.groupId, equals('conv-alice-bob'));

        // Verify getPendingCount.
        final count = await outboxRepo.getPendingCount();
        expect(count, equals(1));

        // Mark as sent (simulating successful network delivery).
        await outboxRepo.markSent('outbox-integration-1');

        // Verify outbox is drained.
        pending = await outboxRepo.getPending();
        expect(pending, isEmpty);

        final countAfter = await outboxRepo.getPendingCount();
        expect(countAfter, equals(0));
      },
    );

    test(
      'Scenario 13b: Multiple outbox items ordered by creation time',
      () async {
        final db = _createTestDb();
        addTearDown(db.close);

        final outboxRepo = OutboxRepositoryImpl(db);

        // Enqueue 3 items in order.
        for (var i = 0; i < 3; i++) {
          final ts = DateTime(2025, 1, 15, 10, i);
          await outboxRepo.enqueue(
            OutboxItemRow(
              id: 'outbox-$i',
              groupId: 'conv-1',
              encryptedEnvelope: Uint8List.fromList([i]),
              recipientDeviceIds: jsonEncode(['bob:1']),
              retryCount: 0,
              createdAt: ts,
              nextRetryAt: ts,
            ),
          );
        }

        final pending = await outboxRepo.getPending();
        expect(pending, hasLength(3));
        // Verify ordering by creation time (ascending).
        expect(pending[0].id, equals('outbox-0'));
        expect(pending[1].id, equals('outbox-1'));
        expect(pending[2].id, equals('outbox-2'));
      },
    );
  });

  // ===========================================================================
  // Two-Phase Ratchet Commit
  // ===========================================================================

  group('Two-Phase Ratchet Commit', () {
    test(
      'Scenario 14: Unacked ratchet state persists across crash simulation',
      () async {
        final keyStore = FakeKeyStore();
        const sessionId = 'alice:bob-device-1';

        // 1. Establish session.
        final session = await buildAliceBobSession();

        // 2. Store the initial session state as committed.
        await keyStore.storeSession(sessionId, session.alice);

        // 3. Encrypt a message (produces a new ratchet state).
        final enc = await DoubleRatchet.encrypt(
          session.alice,
          Uint8List.fromList(utf8.encode('Pre-crash message')),
        );
        final newState = enc.newState;

        // 4. Store the new state as "unacked" (pre-send, before network).
        await keyStore.storeUnackedState(sessionId, newState);

        // 5. Verify unacked state exists.
        final unacked = await keyStore.loadUnackedState(sessionId);
        expect(unacked, isNotNull);
        expect(unacked!.sendMessageNumber, equals(newState.sendMessageNumber));

        // 6. Simulate crash: do NOT commit.
        //    On "restart", load unacked state.
        final recoveredState = await keyStore.loadUnackedState(sessionId);
        expect(recoveredState, isNotNull);

        // 7. Verify it can encrypt another message (ratchet continues).
        final enc2 = await DoubleRatchet.encrypt(
          recoveredState!,
          Uint8List.fromList(utf8.encode('Post-crash message')),
        );
        expect(enc2.ciphertext, isNotEmpty);
        expect(
          enc2.newState.sendMessageNumber,
          equals(recoveredState.sendMessageNumber + 1),
        );

        // 8. Commit the session (after network confirms delivery).
        await keyStore.commitSession(sessionId);

        // 9. Verify unacked is gone and committed session is updated.
        final unackedAfterCommit =
            await keyStore.loadUnackedState(sessionId);
        expect(unackedAfterCommit, isNull);

        final committed = await keyStore.loadSession(sessionId);
        expect(committed, isNotNull);
      },
    );
  });

  // ===========================================================================
  // End-to-End: Crypto + Persistence + Serialization
  // ===========================================================================

  group('End-to-End: Crypto + Persistence + Serialization', () {
    test(
      'Scenario 15: Full send pipeline -- encrypt, persist, '
      'create envelope, deserialize, decrypt',
      () async {
        final db = _createTestDb();
        addTearDown(db.close);

        final msgRepo = MessageRepositoryImpl(db);
        final decryptedRepo = DecryptedMessageRepositoryImpl(db);
        final session = await buildAliceBobSession();

        // Alice creates a message.
        const messageId = 'msg-e2e-pipeline';
        const groupId = 'conv-alice-bob';
        const originalText = 'End-to-end pipeline test!';

        // 1. Create the DecryptedMessage payload.
        final payload = DecryptedMessage(text: originalText);
        final payloadBytes =
            Uint8List.fromList(utf8.encode(jsonEncode(payload)));

        // 2. Encrypt through ratchet.
        final enc = await DoubleRatchet.encrypt(session.alice, payloadBytes);

        // 3. Persist the message metadata to DB.
        final message = Message(
          id: messageId,
          groupId: groupId,
          senderId: 'alice',
          senderDeviceId: 'device-1',
          type: MessageType.e2ee,
          status: MessageStatus.sending,
          timestamp: DateTime.now(),
        );
        await msgRepo.saveMessage(message);

        // 4. Create a wire-format envelope.
        final envelope = MessageEnvelope(
          groupId: groupId,
          senderDeviceId: 1,
          ciphertext: base64Encode(enc.ciphertext),
          recipientId: 'bob',
          recipientDeviceId: 2,
          ratchetHeader: base64Encode(enc.encryptedHeader),
          id: messageId,
        );

        // 5. Serialize and deserialize the envelope (simulate network).
        final wireJson = jsonEncode(envelope.toJson());
        final receivedJson =
            jsonDecode(wireJson) as Map<String, dynamic>;
        final receivedEnvelope = MessageEnvelope.fromJson(receivedJson);

        // 6. Bob decrypts.
        final ctBytes =
            Uint8List.fromList(base64Decode(receivedEnvelope.ciphertext));
        final headerBytes = Uint8List.fromList(
          base64Decode(receivedEnvelope.ratchetHeader!),
        );
        final dec = await DoubleRatchet.decrypt(
          session.bob,
          ctBytes,
          headerBytes,
        );

        // 7. Parse DecryptedMessage.
        final decryptedPayload = DecryptedMessage.fromJson(
          jsonDecode(utf8.decode(dec.plaintext)) as Map<String, dynamic>,
        );
        expect(decryptedPayload.text, equals(originalText));

        // 8. Cache the plaintext.
        await decryptedRepo.cachePlaintext(messageId, decryptedPayload.text);

        // 9. Verify we can retrieve from cache.
        final cached = await decryptedRepo.getCachedPlaintext(messageId);
        expect(cached, equals(originalText));

        // 10. Verify the message metadata was persisted.
        final loadedMsg = await msgRepo.getMessageById(messageId);
        expect(loadedMsg, isNotNull);
        expect(loadedMsg!.groupId, equals(groupId));
      },
    );

    test(
      'Scenario 16: SenderKeyDistribution serialization round-trip',
      () async {
        final aliceStore = FakeSenderKeyStore();
        final cipher = GroupCipher(store: aliceStore);

        // Create a Sender Key.
        final dist = await cipher.createSenderKey('group-1', 'alice');

        // Serialize to JSON (as would be sent via ratchet).
        final jsonStr = jsonEncode(dist.toJson());

        // Deserialize (as received on the other side).
        final parsed = SenderKeyDistribution.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>,
        );

        expect(parsed.chainKey, equals(dist.chainKey));
        expect(parsed.signingPublicKey, equals(dist.signingPublicKey));
        expect(parsed.iteration, equals(dist.iteration));
      },
    );

    test(
      'Scenario 17: X3DH handshake produces identical shared secrets',
      () async {
        // This verifies the crypto integration of the full X3DH protocol.
        final aliceIdentity = await generateTestIdentityKeyPair();
        final bobIdentity = await generateTestIdentityKeyPair();
        final bobSpk = await generateTestSignedPreKey(bobIdentity);
        final bobOtk = await generateTestOneTimePreKey('otk-x3dh-test');

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

        // Both sides must derive the same shared secret.
        expect(aliceResult.sharedSecret, equals(bobResult.sharedSecret));
        expect(aliceResult.sharedSecret, hasLength(32));

        // The ephemeral key should be 32 bytes (X25519 public key).
        expect(aliceResult.ephemeralPublicKey, hasLength(32));

        // The used OTK ID should match.
        expect(aliceResult.usedOneTimePreKeyId, equals('otk-x3dh-test'));
      },
    );

    test(
      'Scenario 18: KeyStore session lifecycle -- '
      'store, load, delete, commit',
      () async {
        final keyStore = FakeKeyStore();

        // Generate identity.
        final identity = await keyStore.generateIdentityKeyPair();
        expect(identity.ed25519PublicKey, hasLength(32));
        expect(identity.x25519PublicKey, hasLength(32));

        // Retrieve it.
        final loaded = await keyStore.getIdentityKeyPair();
        expect(loaded, isNotNull);
        expect(loaded!.ed25519PublicKey, equals(identity.ed25519PublicKey));

        // Generate signed pre-key.
        final spk = await keyStore.generateSignedPreKey(identity);
        expect(spk.publicKey, hasLength(32));
        expect(spk.signature, hasLength(64));

        // Generate OTKs.
        final otks = await keyStore.generateOneTimePreKeys(count: 5);
        expect(otks, hasLength(5));
        for (final otk in otks) {
          expect(otk.publicKey, hasLength(32));
          expect(otk.privateKey, hasLength(32));
        }

        // Session store/load/delete lifecycle.
        final session = await buildAliceBobSession();
        await keyStore.storeSession('test-session', session.alice);

        final loadedSession = await keyStore.loadSession('test-session');
        expect(loadedSession, isNotNull);
        expect(
          loadedSession!.rootKey,
          equals(session.alice.rootKey),
        );

        await keyStore.deleteSession('test-session');
        final deletedSession = await keyStore.loadSession('test-session');
        expect(deletedSession, isNull);
      },
    );
  });
}
