// hello OS v2.0 — Encrypted IndexedDB Store
// Encrypts all IndexedDB values with a non-extractable AES-GCM-256 CryptoKey.
// Key stored in a separate 'hello-vault' IndexedDB — XSS-resistant (attacker
// cannot export the key via crypto.subtle). Zero user friction.
// Replaces the old Argon2id PIN-based flow that was never called.

import { toBase64, fromBase64 } from './primitives';

// ── Module-level cache (lives for tab lifetime) ──
let masterKey: CryptoKey | null = null;

// ── hello-vault IndexedDB helpers ──

const VAULT_DB_NAME = 'hello-vault';
const VAULT_DB_VERSION = 1;
const VAULT_STORE = 'keys';
const VAULT_KEY_ID = 'master';

function openVaultDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(VAULT_DB_NAME, VAULT_DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(VAULT_STORE)) {
        db.createObjectStore(VAULT_STORE);
      }
    };
  });
}

function vaultGet(db: IDBDatabase, key: string): Promise<CryptoKey | undefined> {
  return new Promise((resolve, reject) => {
    const txn = db.transaction(VAULT_STORE, 'readonly');
    const store = txn.objectStore(VAULT_STORE);
    const req = store.get(key);
    req.onsuccess = () => resolve(req.result as CryptoKey | undefined);
    req.onerror = () => reject(req.error);
  });
}

function vaultPut(db: IDBDatabase, key: string, value: CryptoKey): Promise<void> {
  return new Promise((resolve, reject) => {
    const txn = db.transaction(VAULT_STORE, 'readwrite');
    const store = txn.objectStore(VAULT_STORE);
    const req = store.put(value, key);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

// ── Master key management ──

async function getOrCreateMasterKey(): Promise<CryptoKey> {
  if (masterKey) return masterKey;

  const db = await openVaultDB();
  const existing = await vaultGet(db, VAULT_KEY_ID);
  if (existing) {
    masterKey = existing;
    db.close();
    return existing;
  }

  const key = await crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    false, // NON-EXTRACTABLE — XSS cannot export this key
    ['encrypt', 'decrypt']
  );
  await vaultPut(db, VAULT_KEY_ID, key);
  db.close();
  masterKey = key;
  return key;
}

// ── Helpers ──

function concat(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result = new Uint8Array(a.length + b.length);
  result.set(a, 0);
  result.set(b, a.length);
  return result;
}

// ── Public API (same signatures as before — drop-in replacement) ──

/**
 * Encrypt a value before writing to IndexedDB.
 * Returns prefixed string: "wcrypt:" + base64(iv ‖ ciphertext).
 */
export async function encryptForStorage(plaintext: Uint8Array): Promise<string> {
  const key = await getOrCreateMasterKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    plaintext as BufferSource
  ));
  return `wcrypt:${toBase64(concat(iv, ct))}`;
}

/**
 * Decrypt a value after reading from IndexedDB.
 * Handles three formats:
 *   "wcrypt:..." — WebCrypto encrypted (current format)
 *   "plain:..."  — explicit plaintext (legacy fallback)
 *   raw string   — legacy unencrypted format (oldest data)
 */
export async function decryptFromStorage(stored: string): Promise<Uint8Array> {
  // Legacy plaintext format (before encryption was enabled)
  if (stored.startsWith('plain:')) {
    return fromBase64(stored.slice(6));
  }

  // WebCrypto encrypted format
  if (stored.startsWith('wcrypt:')) {
    const blob = fromBase64(stored.slice(7));
    const iv = blob.slice(0, 12);
    const ct = blob.slice(12);
    const key = await getOrCreateMasterKey();
    return new Uint8Array(await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv },
      key,
      ct
    ));
  }

  // Legacy: old 'enc:' format from Argon2id era — treat as plaintext since
  // the wrapping key was never actually initialized (unlockStore was never called).
  // These entries were never truly encrypted; the enc: path would have thrown.
  // Fall through to raw handling.
  if (stored.startsWith('enc:')) {
    // This should not exist in practice (unlockStore was never called, so
    // nothing was ever written with 'enc:' prefix). If encountered, the data
    // is unrecoverable without the Argon2id key. Return empty to avoid crash.
    console.warn('[hello-e2ee] Found legacy enc: entry — unrecoverable without Argon2id key');
    return new Uint8Array(0);
  }

  // Legacy unencrypted format (raw base64 or raw text — oldest data)
  try {
    return fromBase64(stored);
  } catch {
    return new TextEncoder().encode(stored);
  }
}

/**
 * Encrypt a JSON-serializable object for IndexedDB storage.
 */
export async function encryptObjectForStorage(obj: unknown): Promise<string> {
  const json = JSON.stringify(obj);
  const bytes = new TextEncoder().encode(json);
  return encryptForStorage(bytes);
}

/**
 * Decrypt a JSON object from IndexedDB storage.
 * Handles both encrypted and legacy plaintext formats.
 */
export async function decryptObjectFromStorage<T>(stored: string): Promise<T> {
  const bytes = await decryptFromStorage(stored);
  return JSON.parse(new TextDecoder().decode(bytes)) as T;
}
