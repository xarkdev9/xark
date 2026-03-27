// XARK OS v2.0 — Encrypted IndexedDB Store
// Encrypts all IndexedDB values with a master wrapping key.
// Key derived from user PIN via Argon2id. Lives in RAM only.
// Signal Desktop approach: at-rest encryption for key material.

import { aesEncrypt, aesDecrypt, randomBytes, toBase64, fromBase64 } from './primitives';

// Module-level wrapping key — lives in RAM only, never persisted
let wrappingKey: Uint8Array | null = null;

// Salt storage key in localStorage (salt is not secret — prevents rainbow tables)
const SALT_STORAGE_KEY = 'xark_store_salt';

/**
 * Initialize the wrapping key from a user-provided PIN.
 * Must be called once per session (app start / unlock).
 * Uses Argon2id: 3 iterations, 64MB memory.
 */
export async function unlockStore(pin: string): Promise<void> {
  const { deriveBackupKey } = await import('./primitives');

  // Get or create salt
  let salt: Uint8Array;
  const storedSalt = localStorage.getItem(SALT_STORAGE_KEY);
  if (storedSalt) {
    salt = fromBase64(storedSalt);
  } else {
    salt = randomBytes(16);
    localStorage.setItem(SALT_STORAGE_KEY, toBase64(salt));
  }

  const { key } = deriveBackupKey(pin, salt);
  wrappingKey = key;
}

/**
 * Check if the store is unlocked (wrapping key in RAM).
 */
export function isStoreUnlocked(): boolean {
  return wrappingKey !== null;
}

/**
 * Lock the store — zero the wrapping key from RAM.
 * Call on app close/background (best-effort via beforeunload).
 */
export function lockStore(): void {
  if (wrappingKey) {
    // Best-effort zeroing (JS doesn't guarantee memory wiping, but we try)
    wrappingKey.fill(0);
    wrappingKey = null;
  }
}

/**
 * Encrypt a value before writing to IndexedDB.
 * Returns prefixed string: "enc:" + base64(nonce ‖ ciphertext).
 * Falls back to "plain:" prefix when store is not unlocked (backward compat).
 */
export function encryptForStorage(plaintext: Uint8Array): string {
  if (!wrappingKey) {
    // Fallback: store as plaintext if unlockStore hasn't been called.
    // This maintains backward compatibility during migration.
    return `plain:${toBase64(plaintext)}`;
  }
  const { ciphertext, nonce } = aesEncrypt(plaintext, wrappingKey);
  // Pack: nonce (24 bytes) + ciphertext
  const packed = new Uint8Array(nonce.length + ciphertext.length);
  packed.set(nonce, 0);
  packed.set(ciphertext, nonce.length);
  return `enc:${toBase64(packed)}`;
}

/**
 * Decrypt a value after reading from IndexedDB.
 * Handles three formats:
 *   "enc:..."  — encrypted (requires unlocked store)
 *   "plain:..." — explicit plaintext (migration/fallback)
 *   raw base64  — legacy format (no prefix, oldest data)
 */
export function decryptFromStorage(stored: string): Uint8Array {
  // Legacy plaintext format (before encryption was enabled)
  if (stored.startsWith('plain:')) {
    return fromBase64(stored.slice(6));
  }

  // Encrypted format
  if (stored.startsWith('enc:')) {
    if (!wrappingKey) {
      throw new Error('[xark-e2ee] Store is locked — call unlockStore() first');
    }
    const packed = fromBase64(stored.slice(4));
    const nonce = packed.slice(0, 24); // XChaCha20 uses 24-byte nonce
    const ciphertext = packed.slice(24);
    return aesDecrypt(ciphertext, nonce, wrappingKey);
  }

  // Raw base64 (oldest format — no prefix, pre-encryption data)
  return fromBase64(stored);
}

/**
 * Encrypt a JSON-serializable object for IndexedDB storage.
 */
export function encryptObjectForStorage(obj: unknown): string {
  const json = JSON.stringify(obj);
  const bytes = new TextEncoder().encode(json);
  return encryptForStorage(bytes);
}

/**
 * Decrypt a JSON object from IndexedDB storage.
 * Handles both encrypted and legacy plaintext formats.
 */
export function decryptObjectFromStorage<T>(stored: string): T {
  const bytes = decryptFromStorage(stored);
  return JSON.parse(new TextDecoder().decode(bytes)) as T;
}
