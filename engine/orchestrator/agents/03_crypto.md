# Agent 03 — Crypto Layer

## Your Role
You are the **Crypto Agent**. You implement the full Signal Protocol stack: X3DH key agreement, Double Ratchet, Sender Keys for groups, and key management. This is the most critical code in the project. Write it correctly, not quickly.

## Non-Negotiable Rules
- Use `package:cryptography` (pure Dart — WASM compatible). No FFI.
- Every function you write will get a test in Agent 04. Write with testability in mind.
- Session keys are NEVER written to disk in plaintext
- All state objects are immutable (`@freezed` or `final` fields with `const` constructors)
- Crypto operations are designed to run in an Isolate — no global mutable state
- Use `Uint8List` for all raw byte operations. Never `List<int>` in the public interface of these classes.

## Package imports
```dart
import 'package:cryptography/cryptography.dart';
```

## Files to Create

### lib/src/crypto/keys/key_types.dart
Define internal (non-exported) key types:
```dart
// IdentityKeyPair: { publicKey: SimplePublicKey, privateKey: SimpleKeyPair } for Ed25519 + X25519
// PreKeyBundle: { identityKey, signedPreKey, signedPreKeySignature, oneTimePreKey? }
// SessionKey: { chainKey: Uint8List, messageKey: Uint8List, index: int }
// RatchetState: full Double Ratchet state (see below)
// Use @freezed where possible, copyWith is critical for ratchet state updates
```

### lib/src/crypto/keys/ed25519_to_curve25519.dart
```dart
// Ed25519 ↔ Curve25519 birational mapping
// The `cryptography` package does NOT have built-in conversion functions.
// You MUST implement these manually in pure Dart:
//
// ed25519PkToCurve25519(Uint8List ed25519PublicKey) → Uint8List curve25519PublicKey
//   Formula: Given Ed25519 point (x, y), Curve25519 u = (1 + y) / (1 - y) mod p
//   where p = 2^255 - 19
//   Input: 32-byte Ed25519 compressed point (y-coordinate + sign bit)
//   Output: 32-byte Curve25519 u-coordinate
//
// ed25519SkToCurve25519(Uint8List ed25519PrivateKey) → Uint8List curve25519PrivateKey
//   The Ed25519 private key is hashed with SHA-512. The first 32 bytes (clamped) are the
//   Curve25519 scalar. Clamping: clear bits 0,1,2 of first byte, clear bit 7 of last byte, set bit 6 of last byte.
//
// These conversions are mathematically well-defined and used by libsodium internally.
// React calls: crypto_sign_ed25519_pk_to_curve25519() and crypto_sign_ed25519_sk_to_curve25519()
// Flutter must produce identical output for X3DH to work against the same Supabase key_bundles table.
//
// Test vectors: generate an Ed25519 keypair, convert both ways, verify DH(converted_private, peer_public)
// produces the same shared secret as libsodium would.
//
// If implementing from scratch is too error-prone, consider using the `pinenacl` Dart package
// which wraps TweetNaCl and includes these conversions. Add to pubspec if needed.
```

### lib/src/crypto/keys/key_store.dart
```dart
// KeyStore — manages key lifecycle
// abstract class with methods:
//
// CRITICAL FOR TESTABILITY:
// KeyStore MUST be an abstract class (interface only — zero implementation).
// KeyStoreImpl MUST be the only concrete class and must live in a separate file: key_store_impl.dart
// All other classes in src/crypto/ and src/sync/ accept KeyStore (abstract), never KeyStoreImpl.
// This allows Agent 04 and integration tests to inject a FakeKeyStore or MockKeyStore via mocktail.
// No static methods on KeyStore. No factory constructors on KeyStore.
// KeyStoreImpl is only ever instantiated in ChatEngineImpl.initialize() (Agent 08).
//
// - generateIdentityKeyPair() → Future<IdentityKeyPair>
// - generateSignedPreKey(identityKeyPair) → Future<SignedPreKey>
// - generateOneTimePreKeys(count: 100) → Future<List<OneTimePreKey>>
// - getIdentityKeyPair() → Future<IdentityKeyPair>  (loads from secure storage)
// - consumeOneTimePreKey() → Future<OneTimePreKey?>  (returns null if exhausted)
// - storeSession(sessionId, RatchetState) → Future<void>
// - loadSession(sessionId) → Future<RatchetState?>
// - deleteSession(sessionId) → Future<void>
// Implementation: KeyStoreImpl uses flutter_secure_storage for key material
```

### lib/src/crypto/x3dh/x3dh.dart
Implement X3DH key agreement (Signal spec):
```dart
class X3DH {
  // initiatorKeyAgreement:
  // Input: our IdentityKeyPair, their PreKeyBundle
  // Output: { sharedSecret: Uint8List, associatedData: Uint8List, usedOneTimePreKey: bool }
  // Steps:
  //   DH1 = DH(IK_A, SPK_B)
  //   DH2 = DH(EK_A, IK_B)   (EK_A = ephemeral key generated here)
  //   DH3 = DH(EK_A, SPK_B)
  //   DH4 = DH(EK_A, OPK_B)  (if one-time pre-key available)
  //   masterSecret = HKDF(DH1 || DH2 || DH3 [|| DH4])
  static Future<X3DHResult> initiatorKeyAgreement({...})

  // responderKeyAgreement:
  // Input: our IdentityKeyPair, our SignedPreKey, our consumed OneTimePreKey,
  //        their IdentityKey, their EphemeralKey (from message header)
  // Output: { sharedSecret: Uint8List, associatedData: Uint8List }
  static Future<X3DHResult> responderKeyAgreement({...})
}
```

Use `X25519()` for DH key exchange (Curve25519 — Signal Protocol spec). Use `Ed25519()` for signing (identity key signatures and signed pre-key signatures). Use `Hkdf` with SHA-256 for key derivation. Follow the Signal spec exactly for the info/salt strings: `"WhisperText"` for X3DH root derivation, `"WhisperRatchet"` for ratchet steps.

### lib/src/crypto/ratchet/double_ratchet.dart
Full Double Ratchet implementation:
```dart
// RatchetState (immutable, @freezed):
// - DHRatchetKey: SimpleKeyPair (our current ratchet key)
// - DHRatchetRemote: SimplePublicKey (their current ratchet key)
// - rootKey: Uint8List (32 bytes)
// - sendingChainKey: Uint8List?
// - receivingChainKey: Uint8List?
// - sendCounter: int
// - receiveCounter: int
// - prevSendCounter: int
// - skippedMessageKeys: Map<String, Uint8List>  (key: "$dhKey:$counter")

class DoubleRatchet {
  // initAlice: initialize from X3DH shared secret (initiator side)
  static Future<RatchetState> initAlice(Uint8List sharedSecret, SimplePublicKey bobRatchetKey)

  // initBob: initialize from X3DH shared secret (responder side)
  static Future<RatchetState> initBob(Uint8List sharedSecret, SimpleKeyPair ourRatchetKey)

  // encrypt: 
  // - Advances sending chain
  // - Returns { ciphertext: Uint8List, header: RatchetHeader, newState: RatchetState }
  // - Header contains: { dhPublicKey, prevCounter, messageIndex }
  static Future<EncryptResult> encrypt(RatchetState state, Uint8List plaintext)

  // decrypt:
  // - Handles DH ratchet steps, skipped message keys
  // - Returns { plaintext: Uint8List, newState: RatchetState }
  // - Throws DecryptionFailedException on failure
  static Future<DecryptResult> decrypt(RatchetState state, Uint8List ciphertext, RatchetHeader header)

  // Internal helpers (private):
  // _dhRatchetStep, _advanceSendingChain, _advanceReceivingChain, _deriveMessageKey
  // Use HKDF-SHA256 for chain key derivation
  // Use AES-256-GCM for symmetric encryption
}
```

### lib/src/crypto/ratchet/ratchet_header.dart
```dart
// RatchetHeader — sent alongside each encrypted message (NOT encrypted itself)
// - dhPublicKey: Uint8List
// - prevCounter: int
// - messageIndex: int
// - serialize() → Uint8List
// - RatchetHeader.deserialize(Uint8List) → RatchetHeader
```

### lib/src/crypto/sender_keys/sender_key_store.dart
```dart
// Sender Keys for group messaging
// SenderKeyRecord: { senderKeyId, chainKey, iteration, publicKey, privateKey }
// SenderKeyDistributionMessage: { senderKeyId, iteration, chainKey, signingKey }

abstract class SenderKeyStore {
  Future<void> storeSenderKey(String groupId, String senderId, SenderKeyRecord record);
  Future<SenderKeyRecord?> loadSenderKey(String groupId, String senderId);
  Future<SenderKeyDistributionMessage> createDistributionMessage(String groupId);
  Future<void> processDistributionMessage(String senderId, SenderKeyDistributionMessage msg);
}
```

### lib/src/crypto/sender_keys/group_cipher.dart
```dart
// GroupCipher — encrypts/decrypts group messages using Sender Keys
class GroupCipher {
  static Future<Uint8List> encrypt(String groupId, String senderId, Uint8List plaintext, SenderKeyStore store)
  static Future<Uint8List> decrypt(String groupId, String senderId, Uint8List ciphertext, SenderKeyStore store)
}
```

### lib/src/crypto/media/media_crypto.dart
```dart
// Media encryption (standalone AES-256-GCM, not ratchet)
class MediaCrypto {
  // generateMediaKey() → Future<MediaKey> (random 32-byte AES key + 12-byte IV)
  // encrypt(Uint8List plaintext, MediaKey key) → Future<Uint8List> ciphertext
  // decrypt(Uint8List ciphertext, MediaKey key) → Future<Uint8List> plaintext
  // computeSha256(Uint8List data) → Future<Uint8List> (for integrity verification)
  // verify(Uint8List data, Uint8List expectedHash) → Future<bool>
}
```

### lib/src/crypto/profile/profile_crypto.dart
```dart
// Profile key encryption
class ProfileCrypto {
  // generateProfileKey() → Future<Uint8List> (32 random bytes)
  // encryptProfile(ProfileData data, Uint8List profileKey) → Future<Uint8List>
  // decryptProfile(Uint8List ciphertext, Uint8List profileKey) → Future<ProfileData>
}
```

### lib/src/crypto/crypto.dart — Internal barrel
Export only: X3DH, DoubleRatchet, GroupCipher, MediaCrypto, ProfileCrypto, KeyStore, and supporting types needed by other src/ layers. Keep RatchetState, SessionKey, etc. as internal types not re-exported from chat_engine.dart.

### Observer Callsites

The `ChatEngineObserver` (defined by Agent 10, injected via `ChatEngineConfig`) must be called at these points in your implementation. Accept the observer as a constructor parameter on `KeyStoreImpl` and `DoubleRatchet`-invoking classes. Use `observer?.onXxx()` (nullable call) so tests without an observer don't crash.

- After a new ratchet session is successfully established (X3DH complete): `observer.onSessionEstablished(userId, deviceId)`
- If X3DH or session init fails: `observer.onSessionFailed(userId, deviceId, error)`
- After each Double Ratchet chain advance (each encrypt/decrypt cycle): `observer.onRatchetAdvanced(sessionId, newChainIndex)`
- After PreKey replenishment upload completes: `observer.onPreKeyReplenishment(keysUploaded, keysRemaining)`

## After Writing

```bash
cd ~/fe2ee
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10
dart analyze lib/src/crypto/ 2>&1 | head -40
```

Fix all analysis errors before reporting success. Warnings are acceptable.

## Output JSON
```json
{
  "agent": "crypto",
  "step": "03",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Crypto layer complete. Key classes: X3DH (static methods), DoubleRatchet (static, immutable state), GroupCipher, MediaCrypto, ProfileCrypto. KeyStore is abstract — impl in KeyStoreImpl. RatchetState is @freezed immutable. All operations async Future. MediaCrypto uses AES-256-GCM standalone (not ratchet). Crypto test agent must import from lib/src/crypto/crypto.dart. Note: EncryptResult and DecryptResult are return types containing both the result and the new RatchetState."
}
```
