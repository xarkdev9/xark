import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the SQLCipher database encryption key.
/// Key is a random 256-bit value stored in the platform keychain
/// (iOS Keychain / Android Keystore). Generated on first launch,
/// persisted permanently. NOT tied to biometrics — biometric app
/// lock is a separate UI-layer concern.

class DatabaseKeyManager {
  static const _keyAlias = 'e2ee_chat_db_key';
  static const _storage = FlutterSecureStorage();

  /// Get or generate the database encryption key.
  /// Returns null on web (web uses browser-managed IndexedDB).
  static Future<Uint8List?> getOrCreateKey() async {
    try {
      final existing = await _storage.read(key: _keyAlias);
      if (existing != null) return base64Decode(existing);

      // Generate new 256-bit key
      final random = Random.secure();
      final key = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        key[i] = random.nextInt(256);
      }

      await _storage.write(key: _keyAlias, value: base64Encode(key));
      return key;
    } catch (_) {
      // Secure storage unavailable (web, test) — return null (no encryption)
      return null;
    }
  }

  /// Delete the database encryption key (factory reset).
  static Future<void> deleteKey() async {
    await _storage.delete(key: _keyAlias);
  }
}
