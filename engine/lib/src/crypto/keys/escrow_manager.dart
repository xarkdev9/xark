import 'dart:convert';
import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';

/// Manages the highly secure "Dropped in the Ocean" Account Recovery Protocol.
/// 
/// Provides BIP39 12-word mnemonic generation, PBKDF2 key derivation,
/// and AES-256-GCM encryption for backing up the mathematical root
/// (IdentityKeyPair + Double Ratchet baseline states) securely to Supabase.
class EscrowManager {
  final SupabaseClient _supabase;

  EscrowManager(this._supabase);

  /// Generates a standard 12-word BIP39 mnemonic recovery phrase.
  /// This must be presented to the user with severe constraints (e.g., write on paper).
  String generateRecoveryPhrase() {
    return bip39.generateMnemonic(); // 128-bit entropy -> 12 words
  }

  /// Derives a completely deterministic 256-bit AES key using PBKDF2-HMAC-SHA256
  /// taking the 12-word phrase as the source entropy, and a static salt.
  Future<SecretKey> _deriveEncryptionKey(String mnemonic) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 200000, // High iteration count to prevent brute-forcing
      bits: 256,
    );

    // E2EE standard salt string to bind the derivation matrix natively to the logic.
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(mnemonic)),
      nonce: utf8.encode('xark_ocean_drop_salt_v1'),
    );

    return secretKey;
  }

  /// Symmetrically encrypts the root cryptographic identity of the device
  /// and pushes the locked ciphertext directly to `user_key_backups` on Postgres.
  Future<void> backupKeys({
    required String mnemonic,
    required String userId,
    required IdentityKeyPair identityKeyPair,
    required List<Map<String, dynamic>> serializedRatchetStates,
  }) async {
    final derivedKey = await _deriveEncryptionKey(mnemonic);

    // Bundle the highly-secret root key hierarchy
    final vaultPayload = {
      'identity': {
        'public': base64Encode(identityKeyPair.ed25519PublicKey),
        'private': base64Encode(identityKeyPair.ed25519PrivateKey),
        'x25519Public': base64Encode(identityKeyPair.x25519PublicKey),
        'x25519Private': base64Encode(identityKeyPair.x25519PrivateKey),
      },
      'ratchetRoots': serializedRatchetStates,
    };

    final payloadJson = jsonEncode(vaultPayload);
    final payloadBytes = utf8.encode(payloadJson);

    // Standard AES-256-GCM with authentication
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      payloadBytes,
      secretKey: derivedKey,
    );

    // Deconstruct for clean database persistence
    final ciphertext = base64Encode(secretBox.cipherText);
    final nonce = base64Encode(secretBox.nonce);
    final mac = base64Encode(secretBox.mac.bytes);

    // Atomic upsert for single-source-of-truth rollback
    await _supabase.from('user_key_backups').upsert({
      'user_id': userId,
      'escrow_blob': ciphertext,
      'nonce': nonce,
      'mac': mac,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Reverse recovery. User inputs 12 words. Derives key, pulls remote blob,
  /// unlocks, and reconstructs the engine identities.
  Future<Map<String, dynamic>> restoreKeys({
    required String mnemonic,
    required String userId,
  }) async {
    final cleanMnemonic = mnemonic.trim().toLowerCase();

    // Mathematically validate the BIP39 checksum before attempting network constraints
    if (!bip39.validateMnemonic(cleanMnemonic)) {
      throw Exception('BIP39 Checksum Failure: Invalid recovery phrase.');
    }

    final response = await _supabase
        .from('user_key_backups')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      throw Exception('Escrow Vault Not Found: No backup found for this account.');
    }

    final ciphertext = base64Decode(response['escrow_blob'] as String);
    final nonce = base64Decode(response['nonce'] as String);
    final mac = base64Decode(response['mac'] as String);

    final derivedKey = await _deriveEncryptionKey(cleanMnemonic);
    final aesGcm = AesGcm.with256bits();

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    try {
      final decryptedBytes = await aesGcm.decrypt(
        secretBox,
        secretKey: derivedKey,
      );

      final decodedJson = utf8.decode(decryptedBytes);
      final vaultPayload = jsonDecode(decodedJson) as Map<String, dynamic>;

      final identity = vaultPayload['identity'] as Map<String, dynamic>;
      return {
        'identityKeyPair': IdentityKeyPair(
          ed25519PublicKey: base64Decode(identity['public'] as String),
          ed25519PrivateKey: base64Decode(identity['private'] as String),
          x25519PublicKey: base64Decode(
            (identity['x25519Public'] as String?) ?? identity['public'] as String,
          ),
          x25519PrivateKey: base64Decode(
            (identity['x25519Private'] as String?) ?? identity['private'] as String,
          ),
        ),
        'ratchetRoots': vaultPayload['ratchetRoots'] as List<dynamic>,
      };
    } catch (e) {
      throw Exception('Vault Breach: Cryptographic authentication failed. Incorrect phrase. $e');
    }
  }
}
