import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Abstract interface for hardware-backed key wrapping.
/// Implementations delegate to platform-specific secure hardware.
abstract class HardwareKeyStore {
  /// Generate or retrieve the hardware-backed wrapping key.
  /// The wrapping key NEVER leaves the secure hardware.
  Future<void> initialize();

  /// Encrypt data with the hardware-backed wrapping key.
  Future<Uint8List> wrap(Uint8List plaintext);

  /// Decrypt data with the hardware-backed wrapping key.
  Future<Uint8List> unwrap(Uint8List ciphertext);

  /// Check if hardware-backed storage is available on this device.
  Future<bool> isHardwareAvailable();

  /// Delete the wrapping key (device wipe / logout).
  Future<void> deleteWrappingKey();
}

/// Software fallback for platforms without hardware security modules.
/// Uses a random AES-256 key stored in flutter_secure_storage.
/// This is NOT hardware-backed — it's the fallback for testing/web.
class SoftwareKeyStore implements HardwareKeyStore {
  Uint8List? _wrappingKey;

  @override
  Future<void> initialize() async {
    // In real implementation, load from flutter_secure_storage.
    // For now, generate a random key.
    if (_wrappingKey == null) {
      final random = Random.secure();
      _wrappingKey = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        _wrappingKey![i] = random.nextInt(256);
      }
    }
  }

  @override
  Future<Uint8List> wrap(Uint8List plaintext) async {
    if (_wrappingKey == null) {
      throw StateError('Not initialized');
    }
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(_wrappingKey!);
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    // Format: nonce(12) + ciphertext + mac(16)
    final result = BytesBuilder(copy: false)
      ..add(Uint8List.fromList(nonce))
      ..add(Uint8List.fromList(box.cipherText))
      ..add(box.mac.bytes);
    return result.toBytes();
  }

  @override
  Future<Uint8List> unwrap(Uint8List ciphertext) async {
    if (_wrappingKey == null) {
      throw StateError('Not initialized');
    }
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(_wrappingKey!);
    final nonce = ciphertext.sublist(0, 12);
    final ct = ciphertext.sublist(12, ciphertext.length - 16);
    final mac = Mac(ciphertext.sublist(ciphertext.length - 16));
    final box = SecretBox(ct, nonce: nonce, mac: mac);
    final plaintext = await algorithm.decrypt(box, secretKey: secretKey);
    return Uint8List.fromList(plaintext);
  }

  @override
  Future<bool> isHardwareAvailable() async => false;

  @override
  Future<void> deleteWrappingKey() async {
    _wrappingKey = null;
  }
}
