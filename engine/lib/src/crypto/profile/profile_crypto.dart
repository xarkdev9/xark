import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Profile metadata encryption using AES-256-GCM.
///
/// Each user has a Profile Key (random 32-byte symmetric key) that is
/// shared only with verified contacts via E2EE messages. Profile data
/// (display name, status, avatar) is encrypted before upload so the
/// server never sees it in plaintext.
class ProfileCrypto {
  ProfileCrypto._();

  /// Generates a random 32-byte Profile Key.
  static Future<Uint8List> generateProfileKey() async {
    final rng = Random.secure();
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = rng.nextInt(256);
    }
    return key;
  }

  /// Encrypts [plaintext] with AES-256-GCM using [profileKey].
  ///
  /// A random 12-byte IV is generated and prepended to the output.
  /// Returns: `iv(12) + ciphertext + mac(16)`.
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    Uint8List profileKey,
  ) async {
    assert(profileKey.length == 32, 'Profile key must be 32 bytes');

    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKeyData(profileKey),
    );
    // The cipher generates a random nonce automatically.
    return secretBox.concatenation();
  }

  /// Decrypts profile data encrypted with [encrypt].
  ///
  /// Expects the format: `iv(12) + ciphertext + mac(16)`.
  static Future<Uint8List> decrypt(
    Uint8List ciphertext,
    Uint8List profileKey,
  ) async {
    assert(profileKey.length == 32, 'Profile key must be 32 bytes');

    final cipher = AesGcm.with256bits();
    const nonceLen = 12;
    const macLen = 16;

    if (ciphertext.length < nonceLen + macLen) {
      throw ArgumentError('Ciphertext too short for profile decryption');
    }

    final secretBox = SecretBox.fromConcatenation(
      ciphertext,
      nonceLength: nonceLen,
      macLength: macLen,
      copy: false,
    );
    final plaintext = await cipher.decrypt(
      secretBox,
      secretKey: SecretKeyData(profileKey),
    );
    return Uint8List.fromList(plaintext);
  }
}
