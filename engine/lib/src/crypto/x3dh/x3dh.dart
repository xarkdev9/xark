import 'dart:typed_data';

import 'package:hello_engine/src/crypto/keys/ed25519_to_curve25519.dart';
import 'package:hello_engine/src/crypto/keys/key_types.dart';
import 'package:cryptography/cryptography.dart';

/// Base exception for X3DH protocol errors.
class X3dhException implements Exception {
  /// Creates an [X3dhException] with the given [message].
  X3dhException(this.message);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => 'X3dhException: $message';
}

/// Thrown when no one-time pre-keys are available.
///
/// This is informational — the protocol falls back to 3-DH
/// (which is valid Signal behavior).
class OtkExhaustedException extends X3dhException {
  /// Creates an [OtkExhaustedException].
  OtkExhaustedException()
      : super('No one-time pre-keys available — falling back to 3-DH');
}

/// Thrown when the signed pre-key signature fails verification.
///
/// This may indicate a man-in-the-middle attack.
class SignatureVerificationFailed extends X3dhException {
  /// Creates a [SignatureVerificationFailed].
  SignatureVerificationFailed()
      : super(
          'Signed pre-key signature verification failed — potential MITM',
        );
}

/// Thrown when identity key in the bundle does not match expectations.
///
/// Typically means the cached bundle is stale or has been tampered with.
class KeyMismatchError extends X3dhException {
  /// Creates a [KeyMismatchError].
  KeyMismatchError()
      : super('Key bundle mismatch — cached bundle may be stale');
}

/// Warning exception for stale signed pre-keys (older than 7 days).
///
/// The protocol proceeds, but callers should log this condition.
class StalePreKeyWarning extends X3dhException {
  /// Creates a [StalePreKeyWarning].
  StalePreKeyWarning()
      : super(
          'Signed pre-key is older than 7 days — proceeding with warning',
        );
}

/// Extended Triple Diffie-Hellman (X3DH) key agreement.
///
/// Implements the X3DH protocol for establishing shared secrets
/// between two parties. Uses Ed25519 identity keys converted to
/// X25519 for DH, with the HKDF info string `'XarkE2EE-x3dh'`
/// and 32-byte zero salt.
class X3DH {
  X3DH._();

  /// HKDF info string for X3DH key derivation.
  static const String _hkdfInfo = 'XarkE2EE-x3dh';

  /// Performs the X3DH key agreement as the initiator (Alice).
  ///
  /// 1. Verifies the signed pre-key signature.
  /// 2. Converts Ed25519 identity keys to X25519.
  /// 3. Generates an ephemeral X25519 key pair.
  /// 4. Computes DH1..DH4 and derives a 32-byte shared secret.
  static Future<X3DHResult> initiatorKeyAgreement({
    required IdentityKeyPair ourIdentity,
    required PreKeyBundle theirBundle,
  }) async {
    // 1. Verify the signed pre-key signature.
    final ed = Ed25519();
    final sigValid = await ed.verify(
      theirBundle.signedPreKey,
      signature: Signature(
        theirBundle.preKeySignature,
        publicKey: SimplePublicKey(
          theirBundle.identityKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!sigValid) {
      throw SignatureVerificationFailed();
    }

    // 2. Convert their Ed25519 identity key to X25519.
    final theirX25519Pub = Ed25519ToCurve25519.convertPublicKey(
      theirBundle.identityKey,
    );

    // 3. Generate ephemeral X25519 key pair.
    final x = X25519();
    final ephKp = await x.newKeyPair();
    final ephEx = await ephKp.extract();
    final ephPub = Uint8List.fromList(ephEx.publicKey.bytes);
    final ephPriv = Uint8List.fromList(ephEx.bytes);

    // 4. Compute the four DH operations.
    final dh1 = await _dh(
      x,
      ourIdentity.x25519PrivateKey,
      ourIdentity.x25519PublicKey,
      theirBundle.signedPreKey,
    );
    final dh2 = await _dh(
      x,
      ephPriv,
      ephPub,
      theirX25519Pub,
    );
    final dh3 = await _dh(
      x,
      ephPriv,
      ephPub,
      theirBundle.signedPreKey,
    );

    Uint8List? dh4;
    if (theirBundle.oneTimePreKey != null) {
      dh4 = await _dh(
        x,
        ephPriv,
        ephPub,
        theirBundle.oneTimePreKey!,
      );
    }

    // 5. Concatenate all DH outputs.
    final ikmLen = 32 * 3 + (dh4 != null ? 32 : 0);
    final ikm = Uint8List(ikmLen)
      ..setAll(0, dh1)
      ..setAll(32, dh2)
      ..setAll(64, dh3);
    if (dh4 != null) {
      ikm.setAll(96, dh4);
    }

    // 6. HKDF to derive the 32-byte shared secret.
    final sharedSecret = await _deriveSecret(ikm);

    return X3DHResult(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: ephPub,
      usedOneTimePreKeyId: theirBundle.oneTimePreKeyId,
    );
  }

  /// Performs the X3DH key agreement as the responder (Bob).
  ///
  /// Mirror of [initiatorKeyAgreement] with swapped roles.
  static Future<X3DHResult> responderKeyAgreement({
    required IdentityKeyPair ourIdentity,
    required SignedPreKey ourSignedPreKey,
    required OneTimePreKey? ourOneTimePreKey,
    required Uint8List theirIdentityKey,
    required Uint8List theirEphemeralKey,
  }) async {
    final theirX25519Pub = Ed25519ToCurve25519.convertPublicKey(
      theirIdentityKey,
    );
    final x = X25519();

    final dh1 = await _dh(
      x,
      ourSignedPreKey.privateKey,
      ourSignedPreKey.publicKey,
      theirX25519Pub,
    );
    final dh2 = await _dh(
      x,
      ourIdentity.x25519PrivateKey,
      ourIdentity.x25519PublicKey,
      theirEphemeralKey,
    );
    final dh3 = await _dh(
      x,
      ourSignedPreKey.privateKey,
      ourSignedPreKey.publicKey,
      theirEphemeralKey,
    );

    Uint8List? dh4;
    if (ourOneTimePreKey != null) {
      dh4 = await _dh(
        x,
        ourOneTimePreKey.privateKey,
        ourOneTimePreKey.publicKey,
        theirEphemeralKey,
      );
    }

    final ikmLen = 32 * 3 + (dh4 != null ? 32 : 0);
    final ikm = Uint8List(ikmLen)
      ..setAll(0, dh1)
      ..setAll(32, dh2)
      ..setAll(64, dh3);
    if (dh4 != null) {
      ikm.setAll(96, dh4);
    }

    final sharedSecret = await _deriveSecret(ikm);

    return X3DHResult(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: theirEphemeralKey,
      usedOneTimePreKeyId: ourOneTimePreKey?.id,
    );
  }

  /// Performs an X25519 Diffie-Hellman operation.
  static Future<Uint8List> _dh(
    X25519 algorithm,
    Uint8List ourPrivate,
    Uint8List ourPublic,
    Uint8List theirPublic,
  ) async {
    final keyPair = SimpleKeyPairData(
      ourPrivate,
      publicKey: SimplePublicKey(
        ourPublic,
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
    final remotePublic = SimplePublicKey(
      theirPublic,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublic,
    );
    final bytes = await sharedSecret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Derives a 32-byte secret from IKM via HKDF-SHA256.
  static Future<Uint8List> _deriveSecret(Uint8List ikm) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final derived = await hkdf.deriveKey(
      secretKey: SecretKeyData(ikm),
      nonce: Uint8List(32),
      info: _hkdfInfo.codeUnits,
    );
    return Uint8List.fromList(derived.bytes);
  }
}
