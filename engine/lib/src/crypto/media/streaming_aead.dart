import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Streaming AEAD encryption/decryption for large media files.
/// Processes files in 64KB chunks to prevent OOM on large videos.
///
/// Wire format per chunk:
///   [4 bytes: chunk_index (big-endian)] [ciphertext (up to 64KB)] [16 bytes: GCM auth tag]
///
/// Nonce derivation: base_nonce XOR chunk_index (prevents nonce reuse)

/// Chunk size in bytes (64KB).
const int chunkSize = 65536;

/// Key material for streaming AEAD encryption/decryption.
///
/// Contains the AES-256 key, base nonce, total chunk count, and a SHA-256
/// hash of the original plaintext for integrity verification after decryption.
class StreamingAeadKey {
  /// Creates a [StreamingAeadKey].
  const StreamingAeadKey({
    required this.key,
    required this.baseNonce,
    required this.totalChunks,
    required this.sha256Hash,
  });

  /// Deserialises from a JSON map.
  factory StreamingAeadKey.fromJson(Map<String, dynamic> json) =>
      StreamingAeadKey(
        key: base64Decode(json['key'] as String),
        baseNonce: base64Decode(json['baseNonce'] as String),
        totalChunks: int.parse(json['totalChunks'] as String),
        sha256Hash: base64Decode(json['sha256Hash'] as String),
      );

  /// AES-256 key (32 bytes).
  final Uint8List key;

  /// Base nonce (12 bytes). Per-chunk nonces are derived by XOR with index.
  final Uint8List baseNonce;

  /// Total number of encrypted chunks.
  final int totalChunks;

  /// SHA-256 hash of the original plaintext file.
  final Uint8List sha256Hash;

  /// Serialises to a JSON-compatible map (values are strings/base64).
  Map<String, String> toJson() => {
        'key': base64Encode(key),
        'baseNonce': base64Encode(baseNonce),
        'totalChunks': totalChunks.toString(),
        'sha256Hash': base64Encode(sha256Hash),
      };
}

/// Derive a per-chunk nonce by XORing [baseNonce] with [chunkIndex].
///
/// The chunk index is encoded as a 4-byte big-endian integer and XORed into
/// the last 4 bytes of the 12-byte nonce. This guarantees a unique nonce for
/// every chunk while keeping the derivation deterministic and reversible.
Uint8List deriveChunkNonce(Uint8List baseNonce, int chunkIndex) {
  final nonce = Uint8List.fromList(baseNonce);
  final indexBytes = ByteData(4)..setUint32(0, chunkIndex, Endian.big);
  for (var i = 0; i < 4; i++) {
    nonce[nonce.length - 4 + i] ^= indexBytes.getUint8(i);
  }
  return nonce;
}

/// Encrypt a stream of plaintext chunks into encrypted chunks.
///
/// Each emitted [Uint8List] follows the wire format:
///   `[4B chunk_index][ciphertext][16B GCM tag]`
///
/// The caller is responsible for chunking the source file into pieces of
/// at most [chunkSize] bytes and feeding them into [plaintextChunks].
Stream<Uint8List> encryptStream(
  Stream<Uint8List> plaintextChunks,
  Uint8List key,
  Uint8List baseNonce,
) async* {
  final algorithm = AesGcm.with256bits();
  final secretKey = SecretKeyData(key);
  var chunkIndex = 0;

  await for (final chunk in plaintextChunks) {
    final nonce = deriveChunkNonce(baseNonce, chunkIndex);
    final secretBox = await algorithm.encrypt(
      chunk,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Wire format: [4 bytes index] [ciphertext] [16 bytes mac]
    final output = BytesBuilder(copy: false)
      ..add(
        (ByteData(4)..setUint32(0, chunkIndex, Endian.big))
            .buffer
            .asUint8List(),
      )
      ..add(Uint8List.fromList(secretBox.cipherText))
      ..add(Uint8List.fromList(secretBox.mac.bytes));
    yield output.toBytes();

    chunkIndex++;
  }
}

/// Decrypt a stream of encrypted chunks back into plaintext.
///
/// Each element of [encryptedChunks] must follow the wire format produced
/// by [encryptStream].
Stream<Uint8List> decryptStream(
  Stream<Uint8List> encryptedChunks,
  Uint8List key,
  Uint8List baseNonce,
) async* {
  final algorithm = AesGcm.with256bits();
  final secretKey = SecretKeyData(key);

  await for (final chunk in encryptedChunks) {
    // Parse wire format.
    final chunkIndex =
        ByteData.sublistView(chunk, 0, 4).getUint32(0, Endian.big);
    final ciphertext = chunk.sublist(4, chunk.length - 16);
    final mac = Mac(chunk.sublist(chunk.length - 16));
    final nonce = deriveChunkNonce(baseNonce, chunkIndex);

    final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);
    final plaintext = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    yield Uint8List.fromList(plaintext);
  }
}

/// Generate a fresh random AES-256 key and 12-byte base nonce for streaming.
({Uint8List key, Uint8List nonce}) generateStreamingKeySync() {
  final rng = Random.secure();
  final key = Uint8List(32);
  final nonce = Uint8List(12);
  for (var i = 0; i < 32; i++) {
    key[i] = rng.nextInt(256);
  }
  for (var i = 0; i < 12; i++) {
    nonce[i] = rng.nextInt(256);
  }
  return (key: key, nonce: nonce);
}
