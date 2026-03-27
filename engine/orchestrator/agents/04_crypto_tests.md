# Agent 04 — Crypto Tests

## Your Role
You are the **Crypto Test Agent**. You write exhaustive unit tests for the entire crypto layer. This is the most security-critical test suite in the project. Incomplete tests here are a production liability.

## Rules
- Minimum 40 tests. Aim for 50+.
- Use `flutter_test` and `mocktail`
- Test vectors: where the Signal spec provides known-good test vectors, use them
- Every test must have a descriptive name that states what it proves
- Tests must be deterministic — seed RNGs where needed, or test properties not exact values
- Test both happy path AND failure/edge cases for every function

## Files to Create

### test/helpers/test_helpers.dart
```dart
// Shared test utilities:
// - generateTestIdentityKeyPair() → IdentityKeyPair (deterministic for tests)
// - generateTestPreKeyBundle() → PreKeyBundle
// - buildAliceBobSession() → Future<(RatchetState alice, RatchetState bob)>
//   (performs full X3DH + ratchet init between Alice and Bob)
// - randomBytes(int length) → Uint8List
//
// FakeKeyStore — in-memory implementation of the abstract KeyStore interface.
// Stores keys in plain Maps (no flutter_secure_storage — no platform channel in tests).
// class FakeKeyStore implements KeyStore { ... }
// Used by ALL crypto tests and integration tests. Do NOT use MockKeyStore via mocktail
// for crypto tests — use this real in-memory implementation so crypto logic is exercised end-to-end.
```

### test/crypto/x3dh_test.dart
Tests to write:
1. X3DH initiator produces a shared secret
2. X3DH responder produces the SAME shared secret as initiator
3. X3DH with one-time pre-key produces different secret than without
4. X3DH fails if signed pre-key signature is invalid
5. X3DH associated data is deterministic for same key inputs
6. Two different initiators produce different shared secrets
7. X3DH shared secret is 32 bytes

### test/crypto/ratchet_test.dart
Tests to write:
1. Alice can encrypt, Bob can decrypt (single message)
2. Bob can encrypt a reply, Alice can decrypt (full exchange)
3. 100 sequential messages in each direction decrypt correctly
4. Out-of-order messages decrypt correctly (skipped message keys)
5. Messages skipped by up to 50 decrypt correctly
6. Message from old ratchet epoch decrypts correctly
7. Decrypting a tampered ciphertext throws DecryptionFailedException
8. Decrypting with wrong header throws DecryptionFailedException
9. Ratchet state is immutable — encrypt returns new state, old state unchanged
10. Chain keys advance after each message (chainKey N ≠ chainKey N+1)
11. Message keys are unique per message
12. Two sessions initialized from same shared secret are independent
13. Replayed message (same ciphertext twice) throws or returns duplicate error
14. RatchetState serializes and deserializes correctly (for persistence)

### test/crypto/group_cipher_test.dart
Tests:
1. Alice creates a group, distributes SenderKey to Bob
2. Bob processes distribution message, can decrypt Alice's group message
3. Alice sends 10 group messages, Bob decrypts all in order
4. Carol joins group, Bob distributes new SenderKey, Carol can decrypt new messages
5. Carol cannot decrypt messages sent before she received the SenderKey
6. Two senders in the same group use independent sender chains

### test/crypto/media_crypto_test.dart
Tests:
1. Encrypt then decrypt returns original plaintext
2. Generated media key is 32 bytes
3. SHA-256 hash verifies correctly after decrypt
4. Tampered ciphertext fails decryption
5. Wrong key fails decryption
6. Hash mismatch is detected before decrypt
7. Large payload (10MB zeros) encrypts and decrypts correctly
8. Two encryptions of same plaintext produce different ciphertext (random IV)

### test/crypto/key_store_test.dart
Tests:
1. generateIdentityKeyPair produces Ed25519 + X25519 pair
2. generateSignedPreKey produces valid signature verifiable by identity key
3. generateOneTimePreKeys(100) returns 100 unique keys
4. consumeOneTimePreKey returns null when exhausted
5. storeSession and loadSession round-trip
6. deleteSession removes the session
7. loadSession returns null for unknown sessionId

### test/crypto/profile_crypto_test.dart
Tests:
1. generateProfileKey returns 32 bytes
2. encryptProfile → decryptProfile round-trip
3. Different profile keys produce different ciphertext

## Run Tests
```bash
cd ~/fe2ee
flutter test test/crypto/ --reporter=expanded 2>&1
```

All tests must pass. If any test reveals a bug in the crypto implementation, fix the implementation (in lib/src/crypto/) before reporting success. You have authority to fix crypto code if tests reveal bugs.

## Output JSON
```json
{
  "agent": "crypto_tests",
  "step": "04",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "bugs_fixed_in_crypto": [],
  "context_for_next": "Crypto layer fully tested and verified. N tests passing. Any bugs found and fixed: [list]. Key finding: [any important notes about the crypto implementation that downstream agents should know, e.g. RatchetState requires deepCopy before persistence]"
}
```
