import 'dart:math';
import 'dart:typed_data';

import 'package:hello_engine/src/crypto/keys/key_types.dart';
import 'package:hello_engine/src/crypto/sender_keys/sender_key_store.dart';
import 'package:cryptography/cryptography.dart';

/// Group cipher using the Sender Keys protocol.
///
/// Each group member has a Sender Key consisting of a chain key
/// and an Ed25519 signing key pair. Messages are encrypted with
/// XChaCha20-Poly1305 using keys derived from the chain, and
/// signed with Ed25519 for sender authentication.
///
/// Wire format:
/// ```text
/// nonce(24) + signature(64) + iteration(4 BE) + ct + mac(16)
/// ```
class GroupCipher {
  /// Creates a [GroupCipher] backed by [store].
  GroupCipher({required SenderKeyStore store}) : _store = store;

  final SenderKeyStore _store;

  /// Creates a new Sender Key record for the current user.
  ///
  /// Returns a [SenderKeyDistribution] that must be sent to all
  /// group members via their 1:1 E2EE channels.
  Future<SenderKeyDistribution> createSenderKey(
    String groupId,
    String senderId,
  ) async {
    final ed = Ed25519();
    final keyPair = await ed.newKeyPair();
    final extracted = await keyPair.extract();

    // Random 32-byte chain key.
    final chainKey = Uint8List(32);
    final rng = Random.secure();
    for (var i = 0; i < 32; i++) {
      chainKey[i] = rng.nextInt(256);
    }

    final pubKey = Uint8List.fromList(extracted.publicKey.bytes);
    final privKey = Uint8List.fromList(extracted.bytes);

    final record = SenderKeyRecord(
      chainKey: chainKey,
      signingPublicKey: pubKey,
      signingPrivateKey: privKey,
      iteration: 1,
      createdAt: DateTime.now(),
    );

    await _store.storeSenderKey(groupId, senderId, record);

    return SenderKeyDistribution(
      chainKey: chainKey,
      signingPublicKey: pubKey,
      iteration: 1,
    );
  }

  /// Processes a received [SenderKeyDistribution].
  ///
  /// Stores the Sender Key record so we can decrypt future
  /// messages from this member.
  Future<void> processSenderKeyDistribution(
    String groupId,
    String senderId,
    SenderKeyDistribution distribution,
  ) async {
    final record = SenderKeyRecord(
      chainKey: distribution.chainKey,
      signingPublicKey: distribution.signingPublicKey,
      // Private signing key not available for received keys.
      signingPrivateKey: Uint8List(32),
      iteration: distribution.iteration,
      createdAt: DateTime.now(),
    );

    await _store.storeSenderKey(groupId, senderId, record);
  }

  /// Encrypts a plaintext message for the group.
  ///
  /// Advances the sender's chain key and signs the ciphertext.
  Future<Uint8List> encrypt(
    String groupId,
    String senderId,
    Uint8List plaintext,
  ) async {
    final record = await _store.loadSenderKey(groupId, senderId);
    if (record == null) {
      throw StateError(
        'No Sender Key for group=$groupId, sender=$senderId',
      );
    }

    final messageKey = await _deriveMessageKey(record.chainKey);
    final nextChainKey =
        await _deriveNextChainKey(record.chainKey);
    final iteration = record.iteration;

    // Encrypt with XChaCha20-Poly1305.
    final cipher = Xchacha20.poly1305Aead();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKeyData(messageKey),
    );

    final nonce = Uint8List.fromList(secretBox.nonce);
    final ct = Uint8List.fromList(secretBox.cipherText);
    final mac = Uint8List.fromList(secretBox.mac.bytes);

    // Iteration as 4 bytes big-endian.
    final iterBytes = Uint8List(4)
      ..[0] = (iteration >> 24) & 0xFF
      ..[1] = (iteration >> 16) & 0xFF
      ..[2] = (iteration >> 8) & 0xFF
      ..[3] = iteration & 0xFF;

    // Data to sign: ciphertext || mac || nonce.
    final signData = Uint8List(ct.length + mac.length + nonce.length)
      ..setAll(0, ct)
      ..setAll(ct.length, mac)
      ..setAll(ct.length + mac.length, nonce);

    // Sign with Ed25519.
    final ed = Ed25519();
    final sigKeyPair = await ed.newKeyPairFromSeed(
      record.signingPrivateKey,
    );
    final signature = await ed.sign(
      signData,
      keyPair: sigKeyPair,
    );
    final sigBytes = Uint8List.fromList(signature.bytes);

    // Wire format: nonce(24) + sig(64) + iter(4) + ct + mac(16).
    final totalLen = nonce.length +
        sigBytes.length +
        iterBytes.length +
        ct.length +
        mac.length;
    final result = Uint8List(totalLen);
    var offset = 0;
    result.setAll(offset, nonce);
    offset += nonce.length;
    result.setAll(offset, sigBytes);
    offset += sigBytes.length;
    result.setAll(offset, iterBytes);
    offset += iterBytes.length;
    result.setAll(offset, ct);
    offset += ct.length;
    result.setAll(offset, mac);

    // Advance the chain.
    final newRecord = record.copyWith(
      chainKey: nextChainKey,
      iteration: iteration + 1,
    );
    await _store.storeSenderKey(groupId, senderId, newRecord);

    return result;
  }

  /// Decrypts a group message from [senderId].
  ///
  /// Verifies the Ed25519 signature, advances the chain to the
  /// target iteration, and decrypts the ciphertext.
  Future<Uint8List> decrypt(
    String groupId,
    String senderId,
    Uint8List data,
  ) async {
    // Parse wire format.
    const nonceLen = 24;
    const sigLen = 64;
    const iterLen = 4;
    const macLen = 16;
    const minLen = nonceLen + sigLen + iterLen + macLen;

    if (data.length < minLen) {
      throw ArgumentError(
        'Data too short for group cipher wire format',
      );
    }

    var offset = 0;
    final nonce = data.sublist(offset, offset + nonceLen);
    offset += nonceLen;
    final sigBytes = data.sublist(offset, offset + sigLen);
    offset += sigLen;
    final iterBytes = data.sublist(offset, offset + iterLen);
    offset += iterLen;
    final ct = data.sublist(offset, data.length - macLen);
    final mac = data.sublist(data.length - macLen);

    final targetIteration = (iterBytes[0] << 24) |
        (iterBytes[1] << 16) |
        (iterBytes[2] << 8) |
        iterBytes[3];

    final record = await _store.loadSenderKey(
      groupId,
      senderId,
    );
    if (record == null) {
      throw StateError(
        'No Sender Key for group=$groupId, sender=$senderId',
      );
    }

    // Verify the signature.
    final signData = Uint8List(ct.length + mac.length + nonce.length)
      ..setAll(0, ct)
      ..setAll(ct.length, mac)
      ..setAll(ct.length + mac.length, nonce);

    final ed = Ed25519();
    final sigValid = await ed.verify(
      signData,
      signature: Signature(
        sigBytes,
        publicKey: SimplePublicKey(
          record.signingPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!sigValid) {
      throw StateError(
        'Group message signature verification failed',
      );
    }

    if (targetIteration < record.iteration) {
      throw StateError(
        'Target iteration $targetIteration < '
        'current ${record.iteration}',
      );
    }

    // Advance chain to the target iteration.
    var currentChainKey = record.chainKey;
    for (var i = record.iteration; i < targetIteration; i++) {
      currentChainKey = await _deriveNextChainKey(currentChainKey);
    }

    final messageKey = await _deriveMessageKey(currentChainKey);
    final nextChainKey =
        await _deriveNextChainKey(currentChainKey);

    // Decrypt.
    final cipher = Xchacha20.poly1305Aead();
    final secretBox = SecretBox(ct, nonce: nonce, mac: Mac(mac));
    final plaintext = await cipher.decrypt(
      secretBox,
      secretKey: SecretKeyData(messageKey),
    );

    final newRecord = record.copyWith(
      chainKey: nextChainKey,
      iteration: targetIteration + 1,
    );
    await _store.storeSenderKey(groupId, senderId, newRecord);

    return Uint8List.fromList(plaintext);
  }

  /// HMAC-SHA256(chainKey, [0x01]) -> message key.
  Future<Uint8List> _deriveMessageKey(Uint8List chainKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      const [0x01],
      secretKey: SecretKeyData(chainKey),
    );
    return Uint8List.fromList(mac.bytes);
  }

  /// HMAC-SHA256(chainKey, [0x02]) -> next chain key.
  Future<Uint8List> _deriveNextChainKey(
    Uint8List chainKey,
  ) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      const [0x02],
      secretKey: SecretKeyData(chainKey),
    );
    return Uint8List.fromList(mac.bytes);
  }
}
