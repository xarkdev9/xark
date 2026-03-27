// XARK OS v2.0 — Cryptographic Primitives
// Wraps libsodium-wrappers-sumo for all E2EE operations.
// Client-side only — never import on server.

import _sodium from 'libsodium-wrappers-sumo';
import type { RawKeyPair, IdentityKeyPair } from './types';

let sodiumReady = false;

/** Initialize libsodium. Must be called before any crypto operation. */
export async function initCrypto(): Promise<void> {
  if (sodiumReady) return;
  await _sodium.ready;
  sodiumReady = true;
}

function ensureReady(): void {
  if (!sodiumReady) throw new Error('Crypto not initialized. Call initCrypto() first.');
}

// ── Ed25519 Signing ──

/** Generate Ed25519 key pair for signing + identity */
export function generateSigningKeyPair(): RawKeyPair {
  ensureReady();
  const kp = _sodium.crypto_sign_keypair();
  return { publicKey: new Uint8Array(kp.publicKey), privateKey: new Uint8Array(kp.privateKey) };
}

/** Sign a message with Ed25519 */
export function sign(message: Uint8Array, privateKey: Uint8Array): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.crypto_sign_detached(message, privateKey));
}

/** Verify an Ed25519 signature */
export function verify(signature: Uint8Array, message: Uint8Array, publicKey: Uint8Array): boolean {
  ensureReady();
  return _sodium.crypto_sign_verify_detached(signature, message, publicKey);
}

// ── Ed25519 ↔ Curve25519 Birational Mapping ──

/** Convert Ed25519 public key → Curve25519 public key */
export function ed25519PkToCurve25519(ed25519Pk: Uint8Array): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.crypto_sign_ed25519_pk_to_curve25519(ed25519Pk));
}

/** Convert Ed25519 secret key → Curve25519 secret key */
export function ed25519SkToCurve25519(ed25519Sk: Uint8Array): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.crypto_sign_ed25519_sk_to_curve25519(ed25519Sk));
}

/** Generate full identity key pair (Ed25519 + derived Curve25519) */
export function generateIdentityKeyPair(): IdentityKeyPair {
  ensureReady();
  const ed25519 = generateSigningKeyPair();
  const curve25519Public = ed25519PkToCurve25519(ed25519.publicKey);
  const curve25519Private = ed25519SkToCurve25519(ed25519.privateKey);
  return { ed25519, curve25519Public, curve25519Private };
}

// ── Curve25519 Key Exchange ──

/** Generate Curve25519 key pair for Diffie-Hellman */
export function generateDHKeyPair(): RawKeyPair {
  ensureReady();
  const kp = _sodium.crypto_box_keypair();
  return { publicKey: new Uint8Array(kp.publicKey), privateKey: new Uint8Array(kp.privateKey) };
}

/** Perform X25519 Diffie-Hellman key agreement */
export function dh(privateKey: Uint8Array, publicKey: Uint8Array): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.crypto_scalarmult(privateKey, publicKey));
}

// ── XChaCha20-Poly1305 Authenticated Encryption ──
// Used instead of AES-256-GCM: always available (no hardware AES-NI required),
// 192-bit nonce (safe for random generation), equally secure.

/** Encrypt with XChaCha20-Poly1305 */
export function aesEncrypt(
  plaintext: Uint8Array,
  key: Uint8Array,
  additionalData?: Uint8Array
): { ciphertext: Uint8Array; nonce: Uint8Array } {
  ensureReady();
  const nonce = new Uint8Array(_sodium.randombytes_buf(_sodium.crypto_aead_xchacha20poly1305_ietf_NPUBBYTES));
  const ciphertext = new Uint8Array(_sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(
    plaintext, additionalData ?? null, null, nonce, key
  ));
  return { ciphertext, nonce };
}

/** Decrypt with XChaCha20-Poly1305 */
export function aesDecrypt(
  ciphertext: Uint8Array,
  nonce: Uint8Array,
  key: Uint8Array,
  additionalData?: Uint8Array
): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(
    null, ciphertext, additionalData ?? null, nonce, key
  ));
}

// ── HKDF-SHA-256 Key Derivation ──

const HKDF_HASH_LEN = 32;

/** HKDF-Extract: PRK = HMAC-SHA256(salt, ikm) */
function hkdfExtract(salt: Uint8Array, ikm: Uint8Array): Uint8Array {
  ensureReady();
  const key = salt.length > 0 ? salt : new Uint8Array(HKDF_HASH_LEN);
  return new Uint8Array(_sodium.crypto_auth_hmacsha256(ikm, key));
}

/** HKDF-Expand: derive output key material */
function hkdfExpand(prk: Uint8Array, info: Uint8Array, length: number): Uint8Array {
  ensureReady();
  const n = Math.ceil(length / HKDF_HASH_LEN);
  const okm = new Uint8Array(n * HKDF_HASH_LEN);
  let prev = new Uint8Array(0);

  for (let i = 0; i < n; i++) {
    const input = new Uint8Array(prev.length + info.length + 1);
    input.set(prev, 0);
    input.set(info, prev.length);
    input[prev.length + info.length] = i + 1;
    prev = new Uint8Array(_sodium.crypto_auth_hmacsha256(input, prk));
    okm.set(prev, i * HKDF_HASH_LEN);
  }

  return okm.slice(0, length);
}

/** HKDF-SHA-256: derive key from input key material */
export function hkdf(
  ikm: Uint8Array,
  salt: Uint8Array,
  info: string,
  length: number = 32
): Uint8Array {
  const infoBytes = new TextEncoder().encode(info);
  const prk = hkdfExtract(salt, ikm);
  return hkdfExpand(prk, infoBytes, length);
}

/** KDF for Double Ratchet: derive root key + chain key from DH output */
export function kdfRatchet(
  rootKey: Uint8Array,
  dhOutput: Uint8Array
): { newRootKey: Uint8Array; chainKey: Uint8Array } {
  const derived = hkdf(dhOutput, rootKey, 'XarkE2EE-ratchet', 64);
  return {
    newRootKey: derived.slice(0, 32),
    chainKey: derived.slice(32, 64),
  };
}

/** KDF for chain key: advance chain and derive message key */
export function kdfChain(chainKey: Uint8Array): { nextChainKey: Uint8Array; messageKey: Uint8Array } {
  ensureReady();
  const msgKeyInput = new Uint8Array([0x01]);
  const chainKeyInput = new Uint8Array([0x02]);
  return {
    messageKey: new Uint8Array(_sodium.crypto_auth_hmacsha256(msgKeyInput, chainKey)),
    nextChainKey: new Uint8Array(_sodium.crypto_auth_hmacsha256(chainKeyInput, chainKey)),
  };
}

// ── Argon2id Key Derivation (for backups) ──

/** Derive encryption key from password using Argon2id */
export function deriveBackupKey(password: string, salt?: Uint8Array): { key: Uint8Array; salt: Uint8Array } {
  ensureReady();
  const actualSalt = salt ?? new Uint8Array(_sodium.randombytes_buf(_sodium.crypto_pwhash_SALTBYTES));
  const key = new Uint8Array(_sodium.crypto_pwhash(
    32,
    password,
    actualSalt,
    3,  // iterations
    67108864,  // 64MB memory
    _sodium.crypto_pwhash_ALG_ARGON2ID13
  ));
  return { key, salt: actualSalt };
}

// ── Utilities ──

/** Generate random bytes */
export function randomBytes(length: number): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.randombytes_buf(length));
}

/** Encode Uint8Array to base64 */
export function toBase64(data: Uint8Array): string {
  ensureReady();
  return _sodium.to_base64(data, _sodium.base64_variants.ORIGINAL);
}

/** Decode base64 to Uint8Array */
export function fromBase64(data: string): Uint8Array {
  ensureReady();
  return new Uint8Array(_sodium.from_base64(data, _sodium.base64_variants.ORIGINAL));
}

/** Encode string to Uint8Array */
export function toBytes(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

/** Decode Uint8Array to string */
export function fromBytes(data: Uint8Array): string {
  return new TextDecoder().decode(data);
}

/** Constant-time comparison */
export function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  ensureReady();
  if (a.length !== b.length) return false;
  return _sodium.memcmp(a, b);
}

// ── WebCrypto Non-Extractable Identity Keys (P0-1 fix) ──

/**
 * Generate Ed25519 identity key pair via WebCrypto with NON-EXTRACTABLE private key.
 * The private key cannot be exported — it lives only in the browser's crypto subsystem.
 * Requires: Chrome 113+, Safari 17+, Firefox 128+.
 */
export async function generateWebCryptoIdentityKey(): Promise<{
  publicKeyRaw: Uint8Array;
  privateKeyCryptoKey: CryptoKey;
  publicKeyCryptoKey: CryptoKey;
}> {
  if (typeof crypto === 'undefined' || !crypto.subtle) {
    throw new Error('WebCrypto not available — cannot generate non-extractable keys');
  }

  try {
    const keyPair = await crypto.subtle.generateKey(
      { name: 'Ed25519' } as EcKeyGenParams,
      false,  // extractable: false — CRITICAL for P0-1 fix
      ['sign', 'verify']
    ) as CryptoKeyPair;

    // Export public key raw bytes (public keys are always extractable)
    const publicKeyRaw = new Uint8Array(
      await crypto.subtle.exportKey('raw', keyPair.publicKey)
    );

    return {
      publicKeyRaw,
      privateKeyCryptoKey: keyPair.privateKey,
      publicKeyCryptoKey: keyPair.publicKey,
    };
  } catch (err) {
    // Ed25519 not supported in this browser — fall back to libsodium
    // This is acceptable but logs a warning since keys will be extractable
    console.warn('[xark-e2ee] WebCrypto Ed25519 not supported, falling back to libsodium (keys will be extractable)');
    throw err;  // Let caller handle fallback
  }
}

/**
 * Sign a message using a WebCrypto CryptoKey (non-extractable private key).
 */
export async function signWithCryptoKey(
  message: Uint8Array,
  privateKey: CryptoKey
): Promise<Uint8Array> {
  const signature = await crypto.subtle.sign('Ed25519', privateKey, message as unknown as BufferSource);
  return new Uint8Array(signature);
}

/**
 * Verify a signature using a WebCrypto CryptoKey.
 */
export async function verifyWithCryptoKey(
  signature: Uint8Array,
  message: Uint8Array,
  publicKey: CryptoKey
): Promise<boolean> {
  return crypto.subtle.verify('Ed25519', publicKey, signature as unknown as BufferSource, message as unknown as BufferSource);
}
