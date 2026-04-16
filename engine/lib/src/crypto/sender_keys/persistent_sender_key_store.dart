import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sender_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Concrete [SenderKeyStore] backed by [FlutterSecureStorage].
///
/// Ensures the active Double Ratchet SenderKeyRecords (chain keys,
/// iterations, and signing keys) survive app terminations, fixing
/// the catastrophic amnesia experienced during OS backgrounding.
class PersistentSenderKeyStore implements SenderKeyStore {
  /// Creates a [PersistentSenderKeyStore].
  ///
  /// Uses [FlutterSecureStorage] with a dedicated namespace
  /// to avoid key collisions.
  PersistentSenderKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'e2ee_sender_key_';

  String _buildKey(String groupId, String senderId) {
    return '$_prefix${groupId}_$senderId';
  }

  @override
  Future<void> storeSenderKey(
    String groupId,
    String senderId,
    SenderKeyRecord record,
  ) async {
    final json = <String, dynamic>{
      'chainKey': base64Encode(record.chainKey),
      'signingPublicKey': base64Encode(record.signingPublicKey),
      'signingPrivateKey': base64Encode(record.signingPrivateKey),
      'iteration': record.iteration,
      'createdAt': record.createdAt?.toIso8601String(),
    };

    final key = _buildKey(groupId, senderId);
    await _storage.write(key: key, value: jsonEncode(json));
  }

  @override
  Future<SenderKeyRecord?> loadSenderKey(
    String groupId,
    String senderId,
  ) async {
    final key = _buildKey(groupId, senderId);
    final raw = await _storage.read(key: key);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      return SenderKeyRecord(
        chainKey: Uint8List.fromList(base64Decode(json['chainKey'] as String)),
        signingPublicKey: Uint8List.fromList(
            base64Decode(json['signingPublicKey'] as String)),
        signingPrivateKey: Uint8List.fromList(
            base64Decode(json['signingPrivateKey'] as String)),
        iteration: json['iteration'] as int,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );
    } catch (_) {
      // In case of parsing error, return null to force a new Sender Key distribution
      return null;
    }
  }

  @override
  Future<void> deleteSenderKey(String groupId, String senderId) async {
    final key = _buildKey(groupId, senderId);
    await _storage.delete(key: key);
  }
}
