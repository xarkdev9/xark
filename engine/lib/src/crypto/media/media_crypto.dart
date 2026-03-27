import 'dart:math';
import 'dart:typed_data';

import 'package:hello_engine/src/crypto/keys/key_types.dart';
import 'package:cryptography/cryptography.dart';

/// AES-256-GCM encryption for media files (images, video, documents).
///
/// Media files are encrypted with a one-time random key, uploaded as
/// ciphertext, and the key material is sent through the Double Ratchet
/// as a normal E2EE message. The server never sees the plaintext.
class MediaCrypto {
  MediaCrypto._();

  /// Generates a random [MediaKey] (32-byte AES key + 12-byte IV).
  static Future<MediaKey> generateMediaKey() async {
    final rng = Random.secure();
    final key = Uint8List(32);
    final iv = Uint8List(12);
    for (var i = 0; i < 32; i++) {
      key[i] = rng.nextInt(256);
    }
    for (var i = 0; i < 12; i++) {
      iv[i] = rng.nextInt(256);
    }
    return MediaKey(key: key, iv: iv);
  }

  /// Encrypts [plaintext] with AES-256-GCM using the given [key].
  ///
  /// Returns the ciphertext with the GCM authentication tag appended.
  /// The IV is taken from [MediaKey.iv] (12 bytes) and is NOT
  /// prepended -- the caller transmits the IV via the E2EE channel.
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    MediaKey key,
  ) async {
    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKeyData(key.key),
      nonce: key.iv,
    );
    // Return ciphertext + mac (16 bytes).
    final ct = secretBox.cipherText;
    final mac = secretBox.mac.bytes;
    return Uint8List(ct.length + mac.length)
      ..setAll(0, ct)
      ..setAll(ct.length, mac);
  }

  /// Decrypts [ciphertext] (with appended GCM tag) using [key].
  static Future<Uint8List> decrypt(
    Uint8List ciphertext,
    MediaKey key,
  ) async {
    final cipher = AesGcm.with256bits();
    const macLen = 16;
    if (ciphertext.length < macLen) {
      throw ArgumentError('Ciphertext too short for GCM tag');
    }
    final ct = ciphertext.sublist(0, ciphertext.length - macLen);
    final mac = ciphertext.sublist(ciphertext.length - macLen);

    final secretBox = SecretBox(
      ct,
      nonce: key.iv,
      mac: Mac(mac),
    );
    final plaintext = await cipher.decrypt(
      secretBox,
      secretKey: SecretKeyData(key.key),
    );
    return Uint8List.fromList(plaintext);
  }

  /// Computes the SHA-256 hash of [data] for integrity verification.
  static Future<Uint8List> computeSha256(Uint8List data) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(data);
    return Uint8List.fromList(hash.bytes);
  }

  /// Verifies that [data] matches [expectedHash] (SHA-256).
  static Future<bool> verifySha256(
    Uint8List data,
    Uint8List expectedHash,
  ) async {
    final actual = await computeSha256(data);
    if (actual.length != expectedHash.length) return false;
    var result = 0;
    for (var i = 0; i < actual.length; i++) {
      result |= actual[i] ^ expectedHash[i];
    }
    return result == 0;
  }
}
