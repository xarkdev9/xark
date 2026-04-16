// hello OS v2.0 — PQXDH Hybrid Key Agreement
// Hybrid X25519 + Kyber-1024 post-quantum key exchange.
// Sits on top of X3DH: combines DH secret with KEM secret via HKDF.
// Backward compatible — falls back to pure X3DH if peer has no Kyber keys.

import { hkdf, randomBytes } from './primitives';

const PQXDH_INFO = 'XarkE2EE-pqxdh';

// ── KEM Interface ──

/** Abstract KEM (Key Encapsulation Mechanism) interface. */
export interface KemAlgorithm {
  /** Generate a KEM key pair. */
  generateKeyPair(): Promise<KemKeyPair>;

  /** Encapsulate: given a public key, produce (sharedSecret, ciphertext). */
  encapsulate(publicKey: Uint8Array): Promise<KemEncapsulation>;

  /** Decapsulate: given own secret key + ciphertext, recover sharedSecret. */
  decapsulate(secretKey: Uint8Array, ciphertext: Uint8Array): Promise<Uint8Array>;
}

/** KEM key pair (public + secret). */
export interface KemKeyPair {
  publicKey: Uint8Array;
  secretKey: Uint8Array;
}

/** Result of KEM encapsulation: shared secret + ciphertext. */
export interface KemEncapsulation {
  sharedSecret: Uint8Array;
  ciphertext: Uint8Array;
}

/** Result of a PQXDH key agreement. */
export interface PqxdhResult {
  /** The derived shared secret (32 bytes). */
  sharedSecret: Uint8Array;
  /** KEM ciphertext to send to responder (null if pure X3DH). */
  kemCiphertext: Uint8Array | null;
  /** Whether this result used hybrid PQXDH (true) or pure X3DH (false). */
  isHybrid: boolean;
}

// ── Stub Kyber-1024 ──

/**
 * Stub Kyber-1024 implementation for protocol testing.
 * Uses random bytes as a placeholder — replace with real Kyber in production.
 *
 * Real Kyber-1024 key sizes: 1568B public, 3168B secret, 1568B ciphertext.
 * This stub uses 32-byte keys for simplicity.
 */
export class StubKyber implements KemAlgorithm {
  async generateKeyPair(): Promise<KemKeyPair> {
    return {
      publicKey: randomBytes(32),
      secretKey: randomBytes(32),
    };
  }

  async encapsulate(publicKey: Uint8Array): Promise<KemEncapsulation> {
    return {
      sharedSecret: randomBytes(32),
      ciphertext: randomBytes(32),
    };
  }

  async decapsulate(secretKey: Uint8Array, ciphertext: Uint8Array): Promise<Uint8Array> {
    // Stub: return zeros (will not match encapsulate in non-test usage)
    return new Uint8Array(32);
  }
}

/**
 * Deterministic stub for testing where encapsulate and decapsulate
 * produce identical shared secrets.
 *
 * Encapsulate stores a random seed in the ciphertext.
 * Decapsulate re-derives the shared secret from that seed.
 * Both use HKDF with a fixed info string for determinism.
 */
export class DeterministicStubKyber implements KemAlgorithm {
  async generateKeyPair(): Promise<KemKeyPair> {
    return {
      publicKey: randomBytes(32),
      secretKey: randomBytes(32),
    };
  }

  async encapsulate(publicKey: Uint8Array): Promise<KemEncapsulation> {
    const seed = randomBytes(32);
    const sharedSecret = this._deriveFromSeed(seed);
    return { sharedSecret, ciphertext: seed };
  }

  async decapsulate(secretKey: Uint8Array, ciphertext: Uint8Array): Promise<Uint8Array> {
    // ciphertext == seed from encapsulate
    return this._deriveFromSeed(ciphertext);
  }

  /** Derive shared secret deterministically from a seed. */
  private _deriveFromSeed(seed: Uint8Array): Uint8Array {
    return hkdf(seed, new Uint8Array(32), 'pqxdh-deterministic-stub', 32);
  }
}

// ── PQXDH Protocol Functions ──

/**
 * Initiator side of PQXDH: combine X3DH DH secret with Kyber KEM secret.
 *
 * If peerKyberPreKey is null/undefined, returns the DH secret unchanged
 * (backward compatible with peers that have no Kyber keys).
 */
export async function pqxdhInitiator(
  dhSharedSecret: Uint8Array,
  peerKyberPreKey: Uint8Array | null | undefined,
  kem: KemAlgorithm = new StubKyber()
): Promise<PqxdhResult> {
  if (!peerKyberPreKey) {
    return {
      sharedSecret: dhSharedSecret,
      kemCiphertext: null,
      isHybrid: false,
    };
  }

  // Encapsulate against peer's Kyber pre-key
  const encap = await kem.encapsulate(peerKyberPreKey);

  // Combine: HKDF(dh_secret || kem_secret, info="XarkE2EE-pqxdh")
  const combined = concatBytes(dhSharedSecret, encap.sharedSecret);
  const sharedSecret = hkdf(combined, new Uint8Array(32), PQXDH_INFO, 32);

  return {
    sharedSecret,
    kemCiphertext: encap.ciphertext,
    isHybrid: true,
  };
}

/**
 * Responder side of PQXDH: combine X3DH DH secret with Kyber decapsulation.
 *
 * If kemCiphertext or ownKyberSecretKey is null/undefined, returns the
 * DH secret unchanged (backward compatible).
 */
export async function pqxdhResponder(
  dhSharedSecret: Uint8Array,
  kemCiphertext: Uint8Array | null | undefined,
  ownKyberSecretKey: Uint8Array | null | undefined,
  kem: KemAlgorithm = new StubKyber()
): Promise<PqxdhResult> {
  if (!kemCiphertext || !ownKyberSecretKey) {
    return {
      sharedSecret: dhSharedSecret,
      kemCiphertext: null,
      isHybrid: false,
    };
  }

  const kemSecret = await kem.decapsulate(ownKyberSecretKey, kemCiphertext);

  // Combine: HKDF(dh_secret || kem_secret, info="XarkE2EE-pqxdh")
  const combined = concatBytes(dhSharedSecret, kemSecret);
  const sharedSecret = hkdf(combined, new Uint8Array(32), PQXDH_INFO, 32);

  return {
    sharedSecret,
    kemCiphertext,
    isHybrid: true,
  };
}

/** Concatenate two Uint8Arrays. */
function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result = new Uint8Array(a.length + b.length);
  result.set(a, 0);
  result.set(b, a.length);
  return result;
}
