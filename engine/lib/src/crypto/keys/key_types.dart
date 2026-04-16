import 'dart:convert';
import 'dart:typed_data';

/// Identity key pair -- Ed25519 for signing, X25519 for DH.
///
/// Internal to the crypto layer. Never exported from chat_engine.dart.
class IdentityKeyPair {
  /// Creates an [IdentityKeyPair] from raw byte arrays.
  const IdentityKeyPair({
    required this.ed25519PublicKey,
    required this.ed25519PrivateKey,
    required this.x25519PublicKey,
    required this.x25519PrivateKey,
  });

  /// Ed25519 public key (32 bytes).
  final Uint8List ed25519PublicKey;

  /// Ed25519 private key seed (32 bytes).
  final Uint8List ed25519PrivateKey;

  /// X25519 public key (32 bytes), derived from the Ed25519 seed.
  final Uint8List x25519PublicKey;

  /// X25519 private key (32 bytes), derived from the Ed25519 seed.
  final Uint8List x25519PrivateKey;
}

/// Signed pre-key with Ed25519 signature over the X25519 public key.
class SignedPreKey {
  /// Creates a [SignedPreKey].
  const SignedPreKey({
    required this.id,
    required this.publicKey,
    required this.privateKey,
    required this.signature,
    required this.timestamp,
  });

  /// Numeric identifier for this signed pre-key.
  final int id;

  /// X25519 public key (32 bytes).
  final Uint8List publicKey;

  /// X25519 private key (32 bytes).
  final Uint8List privateKey;

  /// Ed25519 signature over [publicKey] (64 bytes).
  final Uint8List signature;

  /// When this key was generated.
  final DateTime timestamp;
}

/// One-time pre-key (ephemeral, consumed on first use).
class OneTimePreKey {
  /// Creates a [OneTimePreKey].
  const OneTimePreKey({
    required this.id,
    required this.publicKey,
    required this.privateKey,
  });

  /// String identifier for this one-time pre-key.
  final String id;

  /// X25519 public key (32 bytes).
  final Uint8List publicKey;

  /// X25519 private key (32 bytes).
  final Uint8List privateKey;
}

/// PreKey bundle fetched from the server for a peer device.
class PreKeyBundle {
  /// Creates a [PreKeyBundle].
  const PreKeyBundle({
    required this.identityKey,
    required this.signedPreKey,
    required this.signedPreKeyId,
    required this.preKeySignature,
    this.oneTimePreKey,
    this.oneTimePreKeyId,
  });

  /// Peer's Ed25519 identity public key (32 bytes).
  final Uint8List identityKey;

  /// Peer's signed X25519 pre-key (32 bytes).
  final Uint8List signedPreKey;

  /// Numeric ID of the signed pre-key.
  final int signedPreKeyId;

  /// Ed25519 signature over [signedPreKey] (64 bytes).
  final Uint8List preKeySignature;

  /// Peer's one-time X25519 pre-key (32 bytes), if available.
  final Uint8List? oneTimePreKey;

  /// String ID of the one-time pre-key, if [oneTimePreKey] is present.
  final String? oneTimePreKeyId;
}

/// Result of an X3DH key agreement.
class X3DHResult {
  /// Creates an [X3DHResult].
  const X3DHResult({
    required this.sharedSecret,
    required this.ephemeralPublicKey,
    this.usedOneTimePreKeyId,
  });

  /// The derived shared secret (32 bytes).
  final Uint8List sharedSecret;

  /// The ephemeral X25519 public key used in the exchange (32 bytes).
  final Uint8List ephemeralPublicKey;

  /// ID of the one-time pre-key consumed, if any.
  final String? usedOneTimePreKeyId;
}

/// Ratchet message header sent alongside each encrypted message.
class RatchetHeader {
  /// Creates a [RatchetHeader].
  const RatchetHeader({
    required this.publicKey,
    required this.previousCount,
    required this.messageNumber,
  });

  /// Deserialises a [RatchetHeader] from a JSON map.
  factory RatchetHeader.fromJson(Map<String, dynamic> json) => RatchetHeader(
        publicKey:
            Uint8List.fromList(base64Decode(json['publicKey'] as String)),
        previousCount: json['previousCount'] as int,
        messageNumber: json['messageNumber'] as int,
      );

  /// Current DH ratchet public key (X25519, 32 bytes).
  final Uint8List publicKey;

  /// Number of messages sent under the previous sending chain.
  final int previousCount;

  /// Message number within the current sending chain.
  final int messageNumber;

  /// Serialises this header to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'publicKey': base64Encode(publicKey),
        'previousCount': previousCount,
        'messageNumber': messageNumber,
      };
}

/// Plain data holder for an X25519 key pair (avoids leaking
/// `cryptography` package types into persisted state).
class RatchetKeyPair {
  /// Creates a [RatchetKeyPair].
  const RatchetKeyPair({required this.publicKey, required this.privateKey});

  /// X25519 public key (32 bytes).
  final Uint8List publicKey;

  /// X25519 private key (32 bytes).
  final Uint8List privateKey;
}

/// Immutable snapshot of the Double Ratchet session state.
class RatchetState {
  /// Creates a [RatchetState].
  const RatchetState({
    required this.rootKey,
    required this.headerSecret,
    this.sendChainKey,
    this.recvChainKey,
    this.sendRatchetKeyPair,
    this.recvRatchetPublicKey,
    this.sendMessageNumber = 0,
    this.recvMessageNumber = 0,
    this.previousSendCount = 0,
    this.skippedKeys = const {},
  });

  /// Root key (32 bytes).
  final Uint8List rootKey;

  /// Current sending chain key (32 bytes), or null if not yet initialised.
  final Uint8List? sendChainKey;

  /// Current receiving chain key (32 bytes), or null if not yet initialised.
  final Uint8List? recvChainKey;

  /// Our current DH ratchet key pair.
  final RatchetKeyPair? sendRatchetKeyPair;

  /// Their current DH ratchet public key (32 bytes).
  final Uint8List? recvRatchetPublicKey;

  /// Number of messages sent in the current sending chain.
  final int sendMessageNumber;

  /// Number of messages received in the current receiving chain.
  final int recvMessageNumber;

  /// Number of messages sent in the previous sending chain.
  final int previousSendCount;

  /// Skipped message keys, keyed by `"base64(publicKey):messageNumber"`.
  final Map<String, Uint8List> skippedKeys;

  /// Header encryption secret (32 bytes).
  final Uint8List headerSecret;

  /// Returns a copy with the given fields replaced.
  RatchetState copyWith({
    Uint8List? rootKey,
    Uint8List? Function()? sendChainKey,
    Uint8List? Function()? recvChainKey,
    RatchetKeyPair? Function()? sendRatchetKeyPair,
    Uint8List? Function()? recvRatchetPublicKey,
    int? sendMessageNumber,
    int? recvMessageNumber,
    int? previousSendCount,
    Map<String, Uint8List>? skippedKeys,
    Uint8List? headerSecret,
  }) {
    return RatchetState(
      rootKey: rootKey ?? this.rootKey,
      sendChainKey:
          sendChainKey != null ? sendChainKey() : this.sendChainKey,
      recvChainKey:
          recvChainKey != null ? recvChainKey() : this.recvChainKey,
      sendRatchetKeyPair: sendRatchetKeyPair != null
          ? sendRatchetKeyPair()
          : this.sendRatchetKeyPair,
      recvRatchetPublicKey: recvRatchetPublicKey != null
          ? recvRatchetPublicKey()
          : this.recvRatchetPublicKey,
      sendMessageNumber: sendMessageNumber ?? this.sendMessageNumber,
      recvMessageNumber: recvMessageNumber ?? this.recvMessageNumber,
      previousSendCount: previousSendCount ?? this.previousSendCount,
      skippedKeys: skippedKeys ?? this.skippedKeys,
      headerSecret: headerSecret ?? this.headerSecret,
    );
  }
}

/// Result of a Double Ratchet encrypt operation.
class EncryptResult {
  /// Creates an [EncryptResult].
  const EncryptResult({
    required this.ciphertext,
    required this.encryptedHeader,
    required this.newState,
  });

  /// Encrypted message payload: `nonce(24) + ciphertext + mac(16)`.
  final Uint8List ciphertext;

  /// Encrypted header: `nonce(24) + headerCiphertext + mac(16)`.
  final Uint8List encryptedHeader;

  /// The updated ratchet state after encryption.
  final RatchetState newState;
}

/// Result of a Double Ratchet decrypt operation.
class DecryptResult {
  /// Creates a [DecryptResult].
  const DecryptResult({
    required this.plaintext,
    required this.newState,
  });

  /// The decrypted plaintext bytes.
  final Uint8List plaintext;

  /// The updated ratchet state after decryption.
  final RatchetState newState;
}

/// Sender Key record for group messaging.
class SenderKeyRecord {
  /// Creates a [SenderKeyRecord].
  const SenderKeyRecord({
    required this.chainKey,
    required this.signingPublicKey,
    required this.signingPrivateKey,
    required this.iteration,
    this.createdAt,
  });

  /// Chain key (32 bytes) used to derive per-message encryption keys.
  final Uint8List chainKey;

  /// Ed25519 signing public key (32 bytes).
  final Uint8List signingPublicKey;

  /// Ed25519 signing private key seed (32 bytes).
  final Uint8List signingPrivateKey;

  /// Current iteration (1-indexed).
  final int iteration;

  /// When this record was created.
  final DateTime? createdAt;

  /// Returns a copy with the given fields replaced.
  SenderKeyRecord copyWith({
    Uint8List? chainKey,
    Uint8List? signingPublicKey,
    Uint8List? signingPrivateKey,
    int? iteration,
    DateTime? Function()? createdAt,
  }) {
    return SenderKeyRecord(
      chainKey: chainKey ?? this.chainKey,
      signingPublicKey: signingPublicKey ?? this.signingPublicKey,
      signingPrivateKey: signingPrivateKey ?? this.signingPrivateKey,
      iteration: iteration ?? this.iteration,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
    );
  }
}

/// Sender Key distribution message shared with group members via the
/// Double Ratchet (1:1 E2EE channel).
class SenderKeyDistribution {
  /// Creates a [SenderKeyDistribution].
  const SenderKeyDistribution({
    required this.chainKey,
    required this.signingPublicKey,
    required this.iteration,
  });

  /// Deserialises from a JSON map.
  factory SenderKeyDistribution.fromJson(Map<String, dynamic> json) {
    return SenderKeyDistribution(
      chainKey:
          Uint8List.fromList(base64Decode(json['chainKey'] as String)),
      signingPublicKey: Uint8List.fromList(
        base64Decode(json['signingPublicKey'] as String),
      ),
      iteration: json['iteration'] as int,
    );
  }

  /// Chain key (32 bytes).
  final Uint8List chainKey;

  /// Ed25519 signing public key (32 bytes). Never contains private material.
  final Uint8List signingPublicKey;

  /// Starting iteration for this distribution.
  final int iteration;

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'chainKey': base64Encode(chainKey),
        'signingPublicKey': base64Encode(signingPublicKey),
        'iteration': iteration,
      };
}

/// Kyber pre-key for PQXDH hybrid key exchange.
///
/// Contains the Kyber-1024 public/secret key pair and an Ed25519
/// signature over the public key for authentication.
class KyberPreKey {
  /// Creates a [KyberPreKey].
  const KyberPreKey({
    required this.publicKey,
    required this.secretKey,
    required this.signature,
  });

  /// Kyber-1024 public key (encapsulation key).
  /// Real Kyber-1024: 1568 bytes. Stub: 32 bytes.
  final Uint8List publicKey;

  /// Kyber-1024 secret key (decapsulation key).
  /// Real Kyber-1024: 3168 bytes. Stub: 32 bytes.
  final Uint8List secretKey;

  /// Ed25519 signature over [publicKey] (64 bytes).
  final Uint8List signature;
}

/// Symmetric key material for media encryption (AES-256-GCM).
class MediaKey {
  /// Creates a [MediaKey].
  const MediaKey({required this.key, required this.iv});

  /// AES-256 key (32 bytes).
  final Uint8List key;

  /// GCM initialisation vector (12 bytes).
  final Uint8List iv;
}
