// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// Generates a fresh Ed25519 + X25519 identity key pair for tests.
Future<IdentityKeyPair> generateTestIdentityKeyPair() async {
  final ed = Ed25519();
  final keyPair = await ed.newKeyPair();
  final extracted = await keyPair.extract();
  final edPub = Uint8List.fromList(extracted.publicKey.bytes);
  final edPriv = Uint8List.fromList(extracted.bytes);
  final x25519Priv = await Ed25519ToCurve25519.convertPrivateKey(edPriv);
  final x = X25519();
  final x25519Kp = await x.newKeyPairFromSeed(x25519Priv);
  final x25519Extracted = await x25519Kp.extract();
  final x25519Pub = Uint8List.fromList(x25519Extracted.publicKey.bytes);
  return IdentityKeyPair(
    ed25519PublicKey: edPub,
    ed25519PrivateKey: edPriv,
    x25519PublicKey: x25519Pub,
    x25519PrivateKey: x25519Priv,
  );
}

/// Generates a signed pre-key for the given identity.
Future<SignedPreKey> generateTestSignedPreKey(
  IdentityKeyPair identity,
) async {
  final x = X25519();
  final kp = await x.newKeyPair();
  final extracted = await kp.extract();
  final pubKey = Uint8List.fromList(extracted.publicKey.bytes);
  final privKey = Uint8List.fromList(extracted.bytes);

  final ed = Ed25519();
  final sigKp = await ed.newKeyPairFromSeed(identity.ed25519PrivateKey);
  final sig = await ed.sign(pubKey, keyPair: sigKp);

  return SignedPreKey(
    id: 1,
    publicKey: pubKey,
    privateKey: privKey,
    signature: Uint8List.fromList(sig.bytes),
    timestamp: DateTime.now(),
  );
}

/// Generates a one-time pre-key.
Future<OneTimePreKey> generateTestOneTimePreKey(String id) async {
  final x = X25519();
  final kp = await x.newKeyPair();
  final extracted = await kp.extract();
  return OneTimePreKey(
    id: id,
    publicKey: Uint8List.fromList(extracted.publicKey.bytes),
    privateKey: Uint8List.fromList(extracted.bytes),
  );
}

/// Builds a full X3DH session between Alice and Bob, returning both
/// ratchet states. Alice is the initiator, Bob is the responder.
Future<({RatchetState alice, RatchetState bob})>
    buildAliceBobSession() async {
  final aliceIdentity = await generateTestIdentityKeyPair();
  final bobIdentity = await generateTestIdentityKeyPair();
  final bobSpk = await generateTestSignedPreKey(bobIdentity);
  final bobOtk = await generateTestOneTimePreKey('otk-1');

  final bobBundle = PreKeyBundle(
    identityKey: bobIdentity.ed25519PublicKey,
    signedPreKey: bobSpk.publicKey,
    signedPreKeyId: bobSpk.id,
    preKeySignature: bobSpk.signature,
    oneTimePreKey: bobOtk.publicKey,
    oneTimePreKeyId: bobOtk.id,
  );

  // Alice initiates X3DH.
  final aliceX3dh = await X3DH.initiatorKeyAgreement(
    ourIdentity: aliceIdentity,
    theirBundle: bobBundle,
  );

  // Bob responds.
  final bobX3dh = await X3DH.responderKeyAgreement(
    ourIdentity: bobIdentity,
    ourSignedPreKey: bobSpk,
    ourOneTimePreKey: bobOtk,
    theirIdentityKey: aliceIdentity.ed25519PublicKey,
    theirEphemeralKey: aliceX3dh.ephemeralPublicKey,
  );

  // Initialize ratchet states.
  final aliceState = await DoubleRatchet.initAlice(
    aliceX3dh.sharedSecret,
    bobSpk.publicKey,
  );
  final bobState = await DoubleRatchet.initBob(
    bobX3dh.sharedSecret,
    RatchetKeyPair(
      publicKey: bobSpk.publicKey,
      privateKey: bobSpk.privateKey,
    ),
  );

  return (alice: aliceState, bob: bobState);
}

/// In-memory implementation of [SenderKeyStore] for tests.
class FakeSenderKeyStore implements SenderKeyStore {
  final _store = <String, SenderKeyRecord>{};

  String _key(String groupId, String senderId) => '$groupId:$senderId';

  @override
  Future<void> storeSenderKey(
    String groupId,
    String senderId,
    SenderKeyRecord record,
  ) async {
    _store[_key(groupId, senderId)] = record;
  }

  @override
  Future<SenderKeyRecord?> loadSenderKey(
    String groupId,
    String senderId,
  ) async {
    return _store[_key(groupId, senderId)];
  }

  @override
  Future<void> deleteSenderKey(
    String groupId,
    String senderId,
  ) async {
    _store.remove(_key(groupId, senderId));
  }

  /// Returns the number of stored records.
  int get length => _store.length;

  /// Clears all stored records.
  void clear() => _store.clear();
}

/// In-memory implementation of [KeyStore] for tests.
class FakeKeyStore implements KeyStore {
  IdentityKeyPair? _identityKeyPair;
  SignedPreKey? _signedPreKey;
  final _sessions = <String, RatchetState>{};
  final _unackedSessions = <String, RatchetState>{};

  @override
  Future<IdentityKeyPair> generateIdentityKeyPair() async {
    _identityKeyPair = await generateTestIdentityKeyPair();
    return _identityKeyPair!;
  }

  @override
  Future<SignedPreKey> generateSignedPreKey(
    IdentityKeyPair identityKeyPair,
  ) async {
    _signedPreKey = await generateTestSignedPreKey(identityKeyPair);
    return _signedPreKey!;
  }

  @override
  Future<List<OneTimePreKey>> generateOneTimePreKeys({int count = 100}) async {
    final keys = <OneTimePreKey>[];
    for (var i = 0; i < count; i++) {
      keys.add(await generateTestOneTimePreKey('otk-$i'));
    }
    return keys;
  }

  @override
  Future<IdentityKeyPair?> getIdentityKeyPair() async => _identityKeyPair;

  @override
  Future<SignedPreKey?> getSignedPreKey() async => _signedPreKey;

  @override
  Future<void> storeSession(String sessionId, RatchetState state) async {
    _sessions[sessionId] = state;
  }

  @override
  Future<RatchetState?> loadSession(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
  }

  @override
  Future<void> storeUnackedState(String sessionId, RatchetState state) async {
    _unackedSessions[sessionId] = state;
  }

  @override
  Future<RatchetState?> loadUnackedState(String sessionId) async {
    return _unackedSessions[sessionId];
  }

  @override
  Future<void> deleteUnackedState(String sessionId) async {
    _unackedSessions.remove(sessionId);
  }

  @override
  Future<void> commitSession(String sessionId) async {
    final state = _unackedSessions[sessionId];
    if (state != null) {
      _sessions[sessionId] = state;
      _unackedSessions.remove(sessionId);
    }
  }
}
