import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hello_engine/src/crypto/keys/ed25519_to_curve25519.dart';
import 'package:hello_engine/src/crypto/keys/key_store.dart';
import 'package:hello_engine/src/crypto/keys/key_types.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Concrete [KeyStore] backed by [FlutterSecureStorage].
///
/// Identity keys and pre-keys are persisted in the platform keychain.
/// Ratchet sessions are serialised as JSON and stored under namespaced
/// keys so they survive app restarts.
class KeyStoreImpl implements KeyStore {
  /// Creates a [KeyStoreImpl].
  ///
  /// Accepts an optional [FlutterSecureStorage] for dependency injection
  /// (useful in integration tests with real storage).
  KeyStoreImpl({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // Key prefixes for namespacing in secure storage.
  static const _identityKeyPrefix = 'e2ee_identity_';
  static const _signedPreKeyPrefix = 'e2ee_spk_';
  static const _sessionPrefix = 'e2ee_session_';
  static const _unackedPrefix = 'e2ee_unacked_';

  @override
  Future<IdentityKeyPair> generateIdentityKeyPair() async {
    final ed = Ed25519();
    final keyPair = await ed.newKeyPair();
    final extracted = await keyPair.extract();
    final seed = Uint8List.fromList(extracted.bytes);
    final pubKey = Uint8List.fromList(extracted.publicKey.bytes);

    // Derive X25519 keys from the Ed25519 seed.
    final x25519Priv = await Ed25519ToCurve25519.convertPrivateKey(seed);
    final x = X25519();
    final xKeyPair = await x.newKeyPairFromSeed(x25519Priv);
    final xExtracted = await xKeyPair.extract();
    final x25519Pub = Uint8List.fromList(xExtracted.publicKey.bytes);

    final identity = IdentityKeyPair(
      ed25519PublicKey: pubKey,
      ed25519PrivateKey: seed,
      x25519PublicKey: x25519Pub,
      x25519PrivateKey: x25519Priv,
    );

    // Persist.
    await _storage.write(
      key: '${_identityKeyPrefix}ed_pub',
      value: base64Encode(pubKey),
    );
    await _storage.write(
      key: '${_identityKeyPrefix}ed_priv',
      value: base64Encode(seed),
    );
    await _storage.write(
      key: '${_identityKeyPrefix}x_pub',
      value: base64Encode(x25519Pub),
    );
    await _storage.write(
      key: '${_identityKeyPrefix}x_priv',
      value: base64Encode(x25519Priv),
    );

    return identity;
  }

  @override
  Future<SignedPreKey> generateSignedPreKey(
    IdentityKeyPair identityKeyPair,
  ) async {
    // Generate an X25519 key pair for the signed pre-key.
    final x = X25519();
    final keyPair = await x.newKeyPair();
    final extracted = await keyPair.extract();
    final pubKey = Uint8List.fromList(extracted.publicKey.bytes);
    final privKey = Uint8List.fromList(extracted.bytes);

    // Sign the public key with our Ed25519 identity key.
    final ed = Ed25519();
    final sigKeyPair = await ed.newKeyPairFromSeed(
      identityKeyPair.ed25519PrivateKey,
    );
    final signature = await ed.sign(pubKey, keyPair: sigKeyPair);
    final sigBytes = Uint8List.fromList(signature.bytes);

    final id = Random.secure().nextInt(1 << 31);
    final now = DateTime.now();

    final spk = SignedPreKey(
      id: id,
      publicKey: pubKey,
      privateKey: privKey,
      signature: sigBytes,
      timestamp: now,
    );

    // Persist.
    await _storage.write(
      key: '${_signedPreKeyPrefix}id',
      value: id.toString(),
    );
    await _storage.write(
      key: '${_signedPreKeyPrefix}pub',
      value: base64Encode(pubKey),
    );
    await _storage.write(
      key: '${_signedPreKeyPrefix}priv',
      value: base64Encode(privKey),
    );
    await _storage.write(
      key: '${_signedPreKeyPrefix}sig',
      value: base64Encode(sigBytes),
    );
    await _storage.write(
      key: '${_signedPreKeyPrefix}ts',
      value: now.toIso8601String(),
    );

    return spk;
  }

  @override
  Future<List<OneTimePreKey>> generateOneTimePreKeys({int count = 100}) async {
    final x = X25519();
    final keys = <OneTimePreKey>[];

    for (var i = 0; i < count; i++) {
      final keyPair = await x.newKeyPair();
      final extracted = await keyPair.extract();
      final pubKey = Uint8List.fromList(extracted.publicKey.bytes);
      final privKey = Uint8List.fromList(extracted.bytes);

      // Generate a unique ID.
      final id = _generateOtkId();

      keys.add(
        OneTimePreKey(id: id, publicKey: pubKey, privateKey: privKey),
      );

      // Persist each OTK.
      await _storage.write(
        key: 'e2ee_otk_pub_$id',
        value: base64Encode(pubKey),
      );
      await _storage.write(
        key: 'e2ee_otk_priv_$id',
        value: base64Encode(privKey),
      );
    }

    return keys;
  }

  @override
  Future<IdentityKeyPair?> getIdentityKeyPair() async {
    final edPub = await _storage.read(key: '${_identityKeyPrefix}ed_pub');
    final edPriv = await _storage.read(key: '${_identityKeyPrefix}ed_priv');
    final xPub = await _storage.read(key: '${_identityKeyPrefix}x_pub');
    final xPriv = await _storage.read(key: '${_identityKeyPrefix}x_priv');

    if (edPub == null || edPriv == null || xPub == null || xPriv == null) {
      return null;
    }

    return IdentityKeyPair(
      ed25519PublicKey: Uint8List.fromList(base64Decode(edPub)),
      ed25519PrivateKey: Uint8List.fromList(base64Decode(edPriv)),
      x25519PublicKey: Uint8List.fromList(base64Decode(xPub)),
      x25519PrivateKey: Uint8List.fromList(base64Decode(xPriv)),
    );
  }

  @override
  Future<SignedPreKey?> getSignedPreKey() async {
    final idStr = await _storage.read(key: '${_signedPreKeyPrefix}id');
    final pub = await _storage.read(key: '${_signedPreKeyPrefix}pub');
    final priv = await _storage.read(key: '${_signedPreKeyPrefix}priv');
    final sig = await _storage.read(key: '${_signedPreKeyPrefix}sig');
    final ts = await _storage.read(key: '${_signedPreKeyPrefix}ts');

    if (idStr == null ||
        pub == null ||
        priv == null ||
        sig == null ||
        ts == null) {
      return null;
    }

    return SignedPreKey(
      id: int.parse(idStr),
      publicKey: Uint8List.fromList(base64Decode(pub)),
      privateKey: Uint8List.fromList(base64Decode(priv)),
      signature: Uint8List.fromList(base64Decode(sig)),
      timestamp: DateTime.parse(ts),
    );
  }

  @override
  Future<void> storeSession(String sessionId, RatchetState state) async {
    final json = _serializeRatchetState(state);
    await _storage.write(
      key: '$_sessionPrefix$sessionId',
      value: jsonEncode(json),
    );
  }

  @override
  Future<RatchetState?> loadSession(String sessionId) async {
    final raw = await _storage.read(key: '$_sessionPrefix$sessionId');
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _deserializeRatchetState(json);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _storage.delete(key: '$_sessionPrefix$sessionId');
  }

  @override
  Future<void> storeUnackedState(String sessionId, RatchetState state) async {
    final json = _serializeRatchetState(state);
    await _storage.write(
      key: '$_unackedPrefix$sessionId',
      value: jsonEncode(json),
    );
  }

  @override
  Future<RatchetState?> loadUnackedState(String sessionId) async {
    final raw = await _storage.read(key: '$_unackedPrefix$sessionId');
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _deserializeRatchetState(json);
  }

  @override
  Future<void> deleteUnackedState(String sessionId) async {
    await _storage.delete(key: '$_unackedPrefix$sessionId');
  }

  @override
  Future<void> commitSession(String sessionId) async {
    final state = await loadUnackedState(sessionId);
    if (state != null) {
      await storeSession(sessionId, state);
      await deleteUnackedState(sessionId);
    }
  }

  // ---- Helpers ----

  String _generateOtkId() {
    final bytes = Uint8List(16);
    final rng = Random.secure();
    for (var i = 0; i < 16; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }

  Map<String, dynamic> _serializeRatchetState(RatchetState state) {
    return <String, dynamic>{
      'rootKey': base64Encode(state.rootKey),
      'sendChainKey': state.sendChainKey != null
          ? base64Encode(state.sendChainKey!)
          : null,
      'recvChainKey': state.recvChainKey != null
          ? base64Encode(state.recvChainKey!)
          : null,
      'sendRatchetKeyPair': state.sendRatchetKeyPair != null
          ? <String, String>{
              'publicKey':
                  base64Encode(state.sendRatchetKeyPair!.publicKey),
              'privateKey':
                  base64Encode(state.sendRatchetKeyPair!.privateKey),
            }
          : null,
      'recvRatchetPublicKey': state.recvRatchetPublicKey != null
          ? base64Encode(state.recvRatchetPublicKey!)
          : null,
      'sendMessageNumber': state.sendMessageNumber,
      'recvMessageNumber': state.recvMessageNumber,
      'previousSendCount': state.previousSendCount,
      'skippedKeys': state.skippedKeys.map(
        (key, value) => MapEntry(key, base64Encode(value)),
      ),
      'headerSecret': base64Encode(state.headerSecret),
    };
  }

  RatchetState _deserializeRatchetState(Map<String, dynamic> json) {
    final skippedRaw =
        json['skippedKeys'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final skipped = skippedRaw.map(
      (key, value) => MapEntry(
        key,
        Uint8List.fromList(base64Decode(value as String)),
      ),
    );

    final spkJson = json['sendRatchetKeyPair'] as Map<String, dynamic>?;
    RatchetKeyPair? sendKp;
    if (spkJson != null) {
      sendKp = RatchetKeyPair(
        publicKey:
            Uint8List.fromList(base64Decode(spkJson['publicKey'] as String)),
        privateKey: Uint8List.fromList(
          base64Decode(spkJson['privateKey'] as String),
        ),
      );
    }

    return RatchetState(
      rootKey:
          Uint8List.fromList(base64Decode(json['rootKey'] as String)),
      sendChainKey: json['sendChainKey'] != null
          ? Uint8List.fromList(
              base64Decode(json['sendChainKey'] as String),
            )
          : null,
      recvChainKey: json['recvChainKey'] != null
          ? Uint8List.fromList(
              base64Decode(json['recvChainKey'] as String),
            )
          : null,
      sendRatchetKeyPair: sendKp,
      recvRatchetPublicKey: json['recvRatchetPublicKey'] != null
          ? Uint8List.fromList(
              base64Decode(json['recvRatchetPublicKey'] as String),
            )
          : null,
      sendMessageNumber: json['sendMessageNumber'] as int,
      recvMessageNumber: json['recvMessageNumber'] as int,
      previousSendCount: json['previousSendCount'] as int,
      skippedKeys: skipped,
      headerSecret: Uint8List.fromList(
        base64Decode(json['headerSecret'] as String),
      ),
    );
  }
}
