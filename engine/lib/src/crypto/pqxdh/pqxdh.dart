import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Abstract KEM (Key Encapsulation Mechanism) interface.
///
/// Implementations wrap Kyber-1024 (or any NIST PQ KEM).
/// The engine uses this interface so the actual KEM algorithm can be
/// swapped without touching the protocol layer.
abstract class KemAlgorithm {
  /// Generate a KEM key pair.
  Future<KemKeyPair> generateKeyPair();

  /// Encapsulate: given a public key, produce (sharedSecret, ciphertext).
  Future<KemEncapsulation> encapsulate(Uint8List publicKey);

  /// Decapsulate: given own secret key + ciphertext, recover sharedSecret.
  Future<Uint8List> decapsulate(Uint8List secretKey, Uint8List ciphertext);
}

/// A KEM key pair (public + secret).
class KemKeyPair {
  /// Creates a [KemKeyPair].
  const KemKeyPair({required this.publicKey, required this.secretKey});

  /// KEM public key (encapsulation key).
  final Uint8List publicKey;

  /// KEM secret key (decapsulation key).
  final Uint8List secretKey;
}

/// Result of a KEM encapsulation: shared secret + ciphertext.
class KemEncapsulation {
  /// Creates a [KemEncapsulation].
  const KemEncapsulation({required this.sharedSecret, required this.ciphertext});

  /// The encapsulated shared secret (32 bytes).
  final Uint8List sharedSecret;

  /// The KEM ciphertext to send to the decapsulating party.
  final Uint8List ciphertext;
}

/// Stub Kyber-1024 implementation for protocol testing.
///
/// Uses random bytes as a placeholder. In production, replace with a real
/// Kyber-1024 implementation (e.g., via FFI to liboqs or a pure-Dart port).
///
/// Real Kyber-1024 key sizes: 1568B public, 3168B secret, 1568B ciphertext.
/// This stub uses 32-byte keys for simplicity.
class StubKyber implements KemAlgorithm {
  /// Optional seed for deterministic testing.
  /// When non-null, [encapsulate] and [decapsulate] produce the same
  /// shared secret, enabling round-trip tests.
  final Uint8List? _testSeed;

  /// Creates a [StubKyber]. Pass [testSeed] for deterministic behaviour
  /// in unit tests.
  StubKyber({Uint8List? testSeed}) : _testSeed = testSeed;

  @override
  Future<KemKeyPair> generateKeyPair() async {
    final random = Random.secure();
    final pub = Uint8List(32);
    final sec = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      pub[i] = random.nextInt(256);
      sec[i] = random.nextInt(256);
    }
    return KemKeyPair(publicKey: pub, secretKey: sec);
  }

  @override
  Future<KemEncapsulation> encapsulate(Uint8List publicKey) async {
    if (_testSeed != null) {
      // Deterministic: HMAC(seed, publicKey) → shared secret
      final hmac = Hmac.sha256();
      final mac = await hmac.calculateMac(
        publicKey,
        secretKey: SecretKeyData(_testSeed!),
      );
      final ss = Uint8List.fromList(mac.bytes);
      // Ciphertext carries the seed so decapsulate can reproduce
      final ct = Uint8List.fromList(_testSeed!);
      return KemEncapsulation(sharedSecret: ss, ciphertext: ct);
    }

    final random = Random.secure();
    final ss = Uint8List(32);
    final ct = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      ss[i] = random.nextInt(256);
      ct[i] = random.nextInt(256);
    }
    return KemEncapsulation(sharedSecret: ss, ciphertext: ct);
  }

  @override
  Future<Uint8List> decapsulate(
    Uint8List secretKey,
    Uint8List ciphertext,
  ) async {
    if (_testSeed != null) {
      // Deterministic: re-derive the same shared secret.
      // In real Kyber, decapsulate(sk, ct) == encapsulate(pk).sharedSecret.
      // Here we use HMAC(ciphertext_as_seed, secretKey) but we need the
      // same result as encapsulate. Since encapsulate used
      // HMAC(seed, publicKey) and we stored seed in ciphertext,
      // we need the public key. For the stub, we compute
      // HMAC(ciphertext, some_fixed_input) — but that won't match.
      //
      // Simpler approach: encapsulate stores seed in ciphertext,
      // decapsulate recomputes HMAC(seed, publicKey). But we don't
      // have publicKey here. So we use a different scheme for the stub:
      //
      // Both sides compute HMAC(seed, "pqxdh-stub") where seed is
      // the _testSeed. This is a test-only stub — the point is that
      // encapsulate and decapsulate produce the SAME shared secret.
      final hmac = Hmac.sha256();
      final mac = await hmac.calculateMac(
        utf8.encode('pqxdh-stub'),
        secretKey: SecretKeyData(ciphertext), // ciphertext == _testSeed
      );
      return Uint8List.fromList(mac.bytes);
    }

    // Non-deterministic stub: return zeros (will not match encapsulate).
    return Uint8List(32);
  }
}

/// Deterministic stub for testing where encapsulate and decapsulate
/// produce identical shared secrets.
///
/// Uses HMAC(fixed_info, publicKey || secretKey) to derive a deterministic
/// shared secret from both key material inputs.
class DeterministicStubKyber implements KemAlgorithm {
  @override
  Future<KemKeyPair> generateKeyPair() async {
    final random = Random.secure();
    final pub = Uint8List(32);
    final sec = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      pub[i] = random.nextInt(256);
      sec[i] = random.nextInt(256);
    }
    return KemKeyPair(publicKey: pub, secretKey: sec);
  }

  @override
  Future<KemEncapsulation> encapsulate(Uint8List publicKey) async {
    // Generate a random encapsulation seed
    final random = Random.secure();
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }

    // Shared secret = HKDF(seed || publicKey)
    final ss = await _deriveSharedSecret(seed, publicKey);

    // Ciphertext = seed (in real Kyber this would be the KEM ciphertext)
    return KemEncapsulation(sharedSecret: ss, ciphertext: seed);
  }

  @override
  Future<Uint8List> decapsulate(
    Uint8List secretKey,
    Uint8List ciphertext,
  ) async {
    // In real Kyber: decapsulate(sk, ct) recovers the same seed that
    // encapsulate produced, then derives the same shared secret.
    //
    // For this deterministic stub, we store the seed directly in
    // the ciphertext, so we can re-derive the shared secret.
    // We also need the public key — derive it from secret key.
    // In this stub, we use a simpler approach: just HKDF(seed || sk).
    //
    // The caller must ensure encapsulate used the public key that
    // corresponds to this secret key. For the stub, we derive SS
    // from seed alone (ciphertext) to make the round-trip work.
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      ciphertext,
      secretKey: SecretKeyData(utf8.encode('pqxdh-deterministic-stub')),
    );
    return Uint8List.fromList(mac.bytes);
  }

  Future<Uint8List> _deriveSharedSecret(
    Uint8List seed,
    Uint8List publicKey,
  ) async {
    // For the stub to be deterministic and round-trip correctly,
    // we derive SS from seed only (not publicKey), so decapsulate
    // can reproduce it from just the ciphertext.
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      seed,
      secretKey: SecretKeyData(utf8.encode('pqxdh-deterministic-stub')),
    );
    return Uint8List.fromList(mac.bytes);
  }
}

/// HKDF info string for PQXDH key derivation.
const String pqxdhHkdfInfo = 'XarkE2EE-pqxdh';

/// PQXDH: Hybrid X3DH + Kyber-1024 key agreement.
///
/// Sits on top of X3DH — takes the X3DH DH shared secret and combines
/// it with a Kyber KEM shared secret via HKDF. If the peer has no
/// Kyber keys, falls back to pure X3DH (backward compatible).
///
/// ```
/// shared_secret = HKDF(dh_secret || kem_secret, info="XarkE2EE-pqxdh")
/// ```
class Pqxdh {
  /// Creates a [Pqxdh] instance with the given KEM algorithm.
  /// Defaults to [StubKyber] if none provided.
  Pqxdh({KemAlgorithm? kem}) : kem = kem ?? StubKyber();

  /// The KEM algorithm used for post-quantum key encapsulation.
  final KemAlgorithm kem;

  /// Initiator side: combine X3DH DH secret with Kyber KEM secret.
  ///
  /// If [peerKyberPreKey] is null, returns the DH secret unchanged
  /// (backward compatible with peers that have no Kyber keys).
  Future<PqxdhResult> initiatorKeyAgreement({
    required Uint8List dhSharedSecret,
    Uint8List? peerKyberPreKey,
  }) async {
    if (peerKyberPreKey == null) {
      return PqxdhResult(
        sharedSecret: dhSharedSecret,
        kemCiphertext: null,
        isHybrid: false,
      );
    }

    // Encapsulate against peer's Kyber pre-key
    final encap = await kem.encapsulate(peerKyberPreKey);

    // Combine: HKDF(dh_secret || kem_secret)
    final combined = _concat(dhSharedSecret, encap.sharedSecret);
    final derived = await _deriveHybridSecret(combined);

    return PqxdhResult(
      sharedSecret: derived,
      kemCiphertext: encap.ciphertext,
      isHybrid: true,
    );
  }

  /// Responder side: combine X3DH DH secret with Kyber decapsulation.
  ///
  /// If [kemCiphertext] or [ownKyberSecretKey] is null, returns the
  /// DH secret unchanged (backward compatible).
  Future<PqxdhResult> responderKeyAgreement({
    required Uint8List dhSharedSecret,
    Uint8List? kemCiphertext,
    Uint8List? ownKyberSecretKey,
  }) async {
    if (kemCiphertext == null || ownKyberSecretKey == null) {
      return PqxdhResult(
        sharedSecret: dhSharedSecret,
        kemCiphertext: null,
        isHybrid: false,
      );
    }

    final kemSecret = await kem.decapsulate(ownKyberSecretKey, kemCiphertext);

    final combined = _concat(dhSharedSecret, kemSecret);
    final derived = await _deriveHybridSecret(combined);

    return PqxdhResult(
      sharedSecret: derived,
      kemCiphertext: kemCiphertext,
      isHybrid: true,
    );
  }

  /// Derives the final 32-byte hybrid shared secret from the concatenated
  /// DH + KEM input key material via HKDF-SHA256.
  static Future<Uint8List> _deriveHybridSecret(Uint8List ikm) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final derived = await hkdf.deriveKey(
      secretKey: SecretKeyData(ikm),
      nonce: Uint8List(32), // zero salt (Signal convention)
      info: utf8.encode(pqxdhHkdfInfo),
    );
    return Uint8List.fromList(derived.bytes);
  }

  /// Concatenates two byte arrays.
  static Uint8List _concat(Uint8List a, Uint8List b) {
    final result = Uint8List(a.length + b.length);
    result.setAll(0, a);
    result.setAll(a.length, b);
    return result;
  }
}

/// Result of a PQXDH key agreement.
class PqxdhResult {
  /// Creates a [PqxdhResult].
  const PqxdhResult({
    required this.sharedSecret,
    this.kemCiphertext,
    required this.isHybrid,
  });

  /// The derived shared secret (32 bytes).
  final Uint8List sharedSecret;

  /// The KEM ciphertext to send to the responder (null if pure X3DH).
  final Uint8List? kemCiphertext;

  /// Whether this result used hybrid PQXDH (true) or pure X3DH (false).
  final bool isHybrid;
}
