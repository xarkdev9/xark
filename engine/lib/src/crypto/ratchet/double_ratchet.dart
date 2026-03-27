import 'dart:convert';
import 'dart:typed_data';

import 'package:chat_engine/src/crypto/keys/key_types.dart';
import 'package:cryptography/cryptography.dart';

/// Double Ratchet algorithm with header encryption.
///
/// Implements the Signal Double Ratchet with:
/// - HKDF-SHA256 for root key derivation (info: `'XarkE2EE-ratchet'`)
/// - HMAC-SHA256 chain KDF with inputs `[0x01]` (message key) and
///   `[0x02]` (next chain key)
/// - XChaCha20-Poly1305 for message and header encryption
/// - Header secret derived via HKDF (info: `'XarkE2EE-header-secret'`)
/// - Header key derived via HKDF (info: `'XarkE2EE-header-key'`)
/// - Maximum 1000 skipped message keys with FIFO eviction
class DoubleRatchet {
  DoubleRatchet._();

  static const String _ratchetInfo = 'XarkE2EE-ratchet';
  static const String _headerSecretInfo = 'XarkE2EE-header-secret';
  static const String _headerKeyInfo = 'XarkE2EE-header-key';
  static const int _maxSkippedKeys = 1000;

  /// Initialises the ratchet as Alice (initiator).
  ///
  /// Alice has the shared secret from X3DH and Bob's signed pre-key
  /// (which serves as his initial ratchet public key).
  static Future<RatchetState> initAlice(
    Uint8List sharedSecret,
    Uint8List bobRatchetPublicKey,
  ) async {
    // Derive header secret from the shared secret.
    final headerSecret = await _deriveHeaderSecret(sharedSecret);

    // Generate our initial ratchet key pair.
    final x = X25519();
    final keyPair = await x.newKeyPair();
    final extracted = await keyPair.extract();
    final ourKp = RatchetKeyPair(
      publicKey: Uint8List.fromList(extracted.publicKey.bytes),
      privateKey: Uint8List.fromList(extracted.bytes),
    );

    // Perform the first DH ratchet step.
    final dhResult = await _dh(
      ourKp.privateKey,
      ourKp.publicKey,
      bobRatchetPublicKey,
    );
    final ratchetOut = await _kdfRk(sharedSecret, dhResult);
    final newRootKey = ratchetOut.item1;
    final sendChainKey = ratchetOut.item2;

    return RatchetState(
      rootKey: newRootKey,
      sendChainKey: sendChainKey,
      sendRatchetKeyPair: ourKp,
      recvRatchetPublicKey: bobRatchetPublicKey,
      headerSecret: headerSecret,
    );
  }

  /// Initialises the ratchet as Bob (responder).
  ///
  /// Bob provides his signed pre-key pair as the initial ratchet key pair.
  static Future<RatchetState> initBob(
    Uint8List sharedSecret,
    RatchetKeyPair ourRatchetKeyPair,
  ) async {
    // Derive header secret from the shared secret.
    final headerSecret = await _deriveHeaderSecret(sharedSecret);

    return RatchetState(
      rootKey: sharedSecret,
      sendRatchetKeyPair: ourRatchetKeyPair,
      headerSecret: headerSecret,
    );
  }

  /// Encrypts [plaintext] and advances the sending chain.
  ///
  /// Returns the ciphertext, the encrypted header, and the updated state.
  static Future<EncryptResult> encrypt(
    RatchetState state,
    Uint8List plaintext,
  ) async {
    final sendChainKey = state.sendChainKey;
    if (sendChainKey == null) {
      throw StateError(
        'Cannot encrypt: sending chain not initialised. '
        'Waiting for first incoming message to complete DH ratchet.',
      );
    }

    // Derive message key and next chain key.
    final messageKey = await _kdfCkMessage(sendChainKey);
    final nextChainKey = await _kdfCkChain(sendChainKey);

    // Create the header.
    final header = RatchetHeader(
      publicKey: state.sendRatchetKeyPair!.publicKey,
      previousCount: state.previousSendCount,
      messageNumber: state.sendMessageNumber,
    );

    // Encrypt the header.
    final encryptedHeader = await _encryptHeader(header, state.headerSecret);

    // Encrypt the plaintext with XChaCha20-Poly1305.
    final ciphertext = await _encryptMessage(plaintext, messageKey);

    final newState = state.copyWith(
      sendChainKey: () => nextChainKey,
      sendMessageNumber: state.sendMessageNumber + 1,
    );

    return EncryptResult(
      ciphertext: ciphertext,
      encryptedHeader: encryptedHeader,
      newState: newState,
    );
  }

  /// Decrypts a message. Handles DH ratchet steps, skipped keys, and
  /// out-of-order messages.
  static Future<DecryptResult> decrypt(
    RatchetState state,
    Uint8List ciphertext,
    Uint8List encryptedHeader,
  ) async {
    // 1. Decrypt the header.
    final header = await _decryptHeader(encryptedHeader, state.headerSecret);

    // 2. Try skipped keys first.
    final skippedResult =
        await _trySkippedKeys(state, header, ciphertext);
    if (skippedResult != null) {
      return skippedResult;
    }

    var currentState = state;

    // 3. Check if we need a DH ratchet step.
    if (currentState.recvRatchetPublicKey == null ||
        !_bytesEqual(header.publicKey, currentState.recvRatchetPublicKey!)) {
      // Skip any remaining messages in the current receiving chain.
      currentState = await _skipMessageKeys(
        currentState,
        currentState.previousSendCount,
        isReceiveChain: false,
      );
      currentState = await _skipMessageKeys(
        currentState,
        header.previousCount,
        isReceiveChain: true,
      );

      // Perform DH ratchet step.
      currentState = await _dhRatchetStep(currentState, header);
    }

    // 4. Skip to the correct message number.
    currentState = await _skipMessageKeys(
      currentState,
      header.messageNumber,
      isReceiveChain: true,
    );

    // 5. Derive the message key for this message.
    final recvChainKey = currentState.recvChainKey!;
    final messageKey = await _kdfCkMessage(recvChainKey);
    final nextChainKey = await _kdfCkChain(recvChainKey);

    // 6. Decrypt the message.
    final plaintext = await _decryptMessage(ciphertext, messageKey);

    final newState = currentState.copyWith(
      recvChainKey: () => nextChainKey,
      recvMessageNumber: currentState.recvMessageNumber + 1,
    );

    return DecryptResult(plaintext: plaintext, newState: newState);
  }

  // ---- Internal helpers ----

  /// Root key KDF: HKDF(ikm=dhOutput, salt=rootKey, info='XarkE2EE-ratchet',
  /// len=64). Returns (newRootKey[32], chainKey[32]).
  static Future<_Pair<Uint8List, Uint8List>> _kdfRk(
    Uint8List rootKey,
    Uint8List dhOutput,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKeyData(dhOutput),
      nonce: rootKey,
      info: _ratchetInfo.codeUnits,
    );
    final bytes = derived.bytes;
    return _Pair(
      Uint8List.fromList(bytes.sublist(0, 32)),
      Uint8List.fromList(bytes.sublist(32, 64)),
    );
  }

  /// Chain KDF for message key: HMAC-SHA256(chainKey, [0x01]).
  static Future<Uint8List> _kdfCkMessage(Uint8List chainKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      const [0x01],
      secretKey: SecretKeyData(chainKey),
    );
    return Uint8List.fromList(mac.bytes);
  }

  /// Chain KDF for next chain key: HMAC-SHA256(chainKey, [0x02]).
  static Future<Uint8List> _kdfCkChain(Uint8List chainKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      const [0x02],
      secretKey: SecretKeyData(chainKey),
    );
    return Uint8List.fromList(mac.bytes);
  }

  /// Derives the header secret: HKDF(sharedSecret, zeros(32),
  /// 'XarkE2EE-header-secret', 32).
  static Future<Uint8List> _deriveHeaderSecret(Uint8List sharedSecret) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKeyData(sharedSecret),
      nonce: Uint8List(32),
      info: _headerSecretInfo.codeUnits,
    );
    return Uint8List.fromList(derived.bytes);
  }

  /// Derives a header key: HKDF(headerSecret, zeros(32),
  /// 'XarkE2EE-header-key', 32).
  static Future<Uint8List> _deriveHeaderKey(Uint8List headerSecret) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKeyData(headerSecret),
      nonce: Uint8List(32),
      info: _headerKeyInfo.codeUnits,
    );
    return Uint8List.fromList(derived.bytes);
  }

  /// Encrypts a header with XChaCha20-Poly1305 using the header key.
  /// Returns: nonce(24) + ciphertext + mac(16).
  static Future<Uint8List> _encryptHeader(
    RatchetHeader header,
    Uint8List headerSecret,
  ) async {
    final headerKey = await _deriveHeaderKey(headerSecret);
    final headerBytes =
        Uint8List.fromList(utf8.encode(jsonEncode(header.toJson())));
    return _encryptMessage(headerBytes, headerKey);
  }

  /// Decrypts an encrypted header and returns the [RatchetHeader].
  static Future<RatchetHeader> _decryptHeader(
    Uint8List encryptedHeader,
    Uint8List headerSecret,
  ) async {
    final headerKey = await _deriveHeaderKey(headerSecret);
    final headerBytes = await _decryptMessage(encryptedHeader, headerKey);
    final json =
        jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    return RatchetHeader.fromJson(json);
  }

  /// Encrypts a plaintext with XChaCha20-Poly1305.
  /// Wire format: nonce(24) + ciphertext + mac(16).
  static Future<Uint8List> _encryptMessage(
    Uint8List plaintext,
    Uint8List key,
  ) async {
    final cipher = Xchacha20.poly1305Aead();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKeyData(key),
    );
    // Pack as: nonce || ciphertext || mac
    return secretBox.concatenation();
  }

  /// Decrypts ciphertext encrypted with XChaCha20-Poly1305.
  /// Expects wire format: nonce(24) + ciphertext + mac(16).
  static Future<Uint8List> _decryptMessage(
    Uint8List data,
    Uint8List key,
  ) async {
    final cipher = Xchacha20.poly1305Aead();
    const nonceLen = 24;
    const macLen = 16;
    final secretBox = SecretBox.fromConcatenation(
      data,
      nonceLength: nonceLen,
      macLength: macLen,
      copy: false,
    );
    final plaintext = await cipher.decrypt(
      secretBox,
      secretKey: SecretKeyData(key),
    );
    return Uint8List.fromList(plaintext);
  }

  /// Performs an X25519 DH and returns the 32-byte shared secret.
  static Future<Uint8List> _dh(
    Uint8List ourPrivate,
    Uint8List ourPublic,
    Uint8List theirPublic,
  ) async {
    final x = X25519();
    final keyPair = SimpleKeyPairData(
      ourPrivate,
      publicKey: SimplePublicKey(ourPublic, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    final remotePublic =
        SimplePublicKey(theirPublic, type: KeyPairType.x25519);
    final sharedSecret = await x.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublic,
    );
    final bytes = await sharedSecret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Tries to decrypt using a previously skipped message key.
  static Future<DecryptResult?> _trySkippedKeys(
    RatchetState state,
    RatchetHeader header,
    Uint8List ciphertext,
  ) async {
    final key = _skippedKeyId(header.publicKey, header.messageNumber);
    final messageKey = state.skippedKeys[key];
    if (messageKey == null) return null;

    final plaintext = await _decryptMessage(ciphertext, messageKey);
    final newSkipped = Map<String, Uint8List>.from(state.skippedKeys)
      ..remove(key);

    return DecryptResult(
      plaintext: plaintext,
      newState: state.copyWith(skippedKeys: newSkipped),
    );
  }

  /// Skips message keys up to [until], storing them for out-of-order
  /// decryption. Enforces the [_maxSkippedKeys] limit with FIFO eviction.
  static Future<RatchetState> _skipMessageKeys(
    RatchetState state,
    int until, {
    required bool isReceiveChain,
  }) async {
    if (isReceiveChain) {
      final chainKey = state.recvChainKey;
      if (chainKey == null) return state;

      var currentChainKey = chainKey;
      var currentNumber = state.recvMessageNumber;
      final skipped = Map<String, Uint8List>.from(state.skippedKeys);

      while (currentNumber < until) {
        final messageKey = await _kdfCkMessage(currentChainKey);
        final nextChainKey = await _kdfCkChain(currentChainKey);

        final pubKey = state.recvRatchetPublicKey;
        if (pubKey != null) {
          final id = _skippedKeyId(pubKey, currentNumber);
          skipped[id] = messageKey;
        }

        // FIFO eviction if over limit.
        while (skipped.length > _maxSkippedKeys) {
          skipped.remove(skipped.keys.first);
        }

        currentChainKey = nextChainKey;
        currentNumber++;
      }

      return state.copyWith(
        recvChainKey: () => currentChainKey,
        recvMessageNumber: currentNumber,
        skippedKeys: skipped,
      );
    }

    // For send chain skipping during DH ratchet, we skip the send chain.
    return state;
  }

  /// Performs a DH ratchet step when we receive a new ratchet public key.
  static Future<RatchetState> _dhRatchetStep(
    RatchetState state,
    RatchetHeader header,
  ) async {
    // Receive side: DH with our current key pair and their new public key.
    final dhRecv = await _dh(
      state.sendRatchetKeyPair!.privateKey,
      state.sendRatchetKeyPair!.publicKey,
      header.publicKey,
    );
    final recvRatchet = await _kdfRk(state.rootKey, dhRecv);

    // Generate a new ratchet key pair for our sending chain.
    final x = X25519();
    final newKp = await x.newKeyPair();
    final newExtracted = await newKp.extract();
    final newKeyPair = RatchetKeyPair(
      publicKey: Uint8List.fromList(newExtracted.publicKey.bytes),
      privateKey: Uint8List.fromList(newExtracted.bytes),
    );

    // Send side: DH with our new key pair and their public key.
    final dhSend = await _dh(
      newKeyPair.privateKey,
      newKeyPair.publicKey,
      header.publicKey,
    );
    final sendRatchet = await _kdfRk(recvRatchet.item1, dhSend);

    return state.copyWith(
      rootKey: sendRatchet.item1,
      recvChainKey: () => recvRatchet.item2,
      sendChainKey: () => sendRatchet.item2,
      sendRatchetKeyPair: () => newKeyPair,
      recvRatchetPublicKey: () => Uint8List.fromList(header.publicKey),
      previousSendCount: state.sendMessageNumber,
      sendMessageNumber: 0,
      recvMessageNumber: 0,
    );
  }

  /// Creates a string key for the skipped keys map.
  static String _skippedKeyId(Uint8List publicKey, int messageNumber) =>
      '${base64Encode(publicKey)}:$messageNumber';

  /// Constant-time-ish byte array comparison.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Simple pair type for returning two values.
class _Pair<A, B> {
  const _Pair(this.item1, this.item2);
  final A item1;
  final B item2;
}
