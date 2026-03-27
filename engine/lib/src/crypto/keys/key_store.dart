import 'package:chat_engine/src/crypto/keys/key_types.dart';

/// Abstract interface for secure key material storage.
///
/// Implementations persist identity keys, pre-keys, and ratchet session
/// state. All stored data must be encrypted at rest via platform keychain
/// or equivalent.
abstract class KeyStore {
  /// Generates a fresh Ed25519 + X25519 identity key pair and persists it.
  Future<IdentityKeyPair> generateIdentityKeyPair();

  /// Generates a signed pre-key, signed with the given identity key pair.
  Future<SignedPreKey> generateSignedPreKey(
    IdentityKeyPair identityKeyPair,
  );

  /// Generates [count] one-time pre-keys.
  Future<List<OneTimePreKey>> generateOneTimePreKeys({int count = 100});

  /// Retrieves the persisted identity key pair, or null if none exists.
  Future<IdentityKeyPair?> getIdentityKeyPair();

  /// Retrieves the current signed pre-key, or null if none exists.
  Future<SignedPreKey?> getSignedPreKey();

  /// Persists a Double Ratchet session state for the given session ID.
  Future<void> storeSession(String sessionId, RatchetState state);

  /// Loads a previously stored ratchet session, or null if not found.
  Future<RatchetState?> loadSession(String sessionId);

  /// Deletes a stored ratchet session.
  Future<void> deleteSession(String sessionId);

  /// Stores an unacknowledged (pending) ratchet state used during the
  /// X3DH handshake before the responder has confirmed.
  Future<void> storeUnackedState(String sessionId, RatchetState state);

  /// Loads an unacknowledged ratchet state, or null if not found.
  Future<RatchetState?> loadUnackedState(String sessionId);

  /// Deletes an unacknowledged ratchet state.
  Future<void> deleteUnackedState(String sessionId);

  /// Promotes an unacknowledged session to the confirmed session store
  /// (moves from unacked to acked).
  Future<void> commitSession(String sessionId);
}
