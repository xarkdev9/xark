// hello OS v2.0 — KeyStore (IndexedDB)
// Persistent key storage for E2EE. IndexedDB for PWA.
// Interface is abstract — swap for native Keychain on iOS/Android.
// At-rest encryption via Argon2id-derived wrapping key (Signal Desktop approach).

import type { RawKeyPair, LinkPreviewPayload } from './types';
import { toBase64, fromBase64 } from './primitives';
import {
  encryptForStorage,
  decryptFromStorage,
  encryptObjectForStorage,
  decryptObjectFromStorage,
} from './encrypted-store';

const DB_NAME = 'xark-keystore';
const DB_VERSION = 5;

const STORES = {
  identity: 'identity',
  signedPreKeys: 'signed-pre-keys',
  oneTimePreKeys: 'one-time-pre-keys',
  senderKeys: 'sender-keys',
  sessions: 'sessions',
  meta: 'meta',
  unackedRatchet: 'unacked-ratchet',
  decryptedMessages: 'decrypted-messages',
  processedDistributions: 'processed-distributions',
  localContacts: 'local-contacts',
} as const;

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onblocked = () => {
      // Another tab/connection holds the old version. Close it and retry.
      console.warn('[xark-keystore] DB upgrade blocked — close other tabs and retry');
      // Force-resolve with the existing DB at old version rather than hanging forever
      const fallbackReq = indexedDB.open(DB_NAME);
      fallbackReq.onsuccess = () => resolve(fallbackReq.result);
      fallbackReq.onerror = () => reject(new Error('IndexedDB blocked and fallback failed'));
    };
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const name of Object.values(STORES)) {
        if (!db.objectStoreNames.contains(name)) {
          db.createObjectStore(name);
        }
      }
      // v5: Sender Key ACK cache (compound keyPath)
      if (!db.objectStoreNames.contains('sk_acks')) {
        const skAckStore = db.createObjectStore('sk_acks', { keyPath: ['groupId', 'senderId'] });
        skAckStore.createIndex('groupId', 'groupId', { unique: false });
      }
    };
  });
}

function tx(
  db: IDBDatabase,
  storeName: string,
  mode: IDBTransactionMode
): IDBObjectStore {
  return db.transaction(storeName, mode).objectStore(storeName);
}

function idbGet<T>(store: IDBObjectStore, key: IDBValidKey): Promise<T | undefined> {
  return new Promise((resolve, reject) => {
    const req = store.get(key);
    req.onsuccess = () => resolve(req.result as T | undefined);
    req.onerror = () => reject(req.error);
  });
}

function idbPut(store: IDBObjectStore, key: IDBValidKey, value: unknown): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = store.put(value, key);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

function idbDelete(store: IDBObjectStore, key: IDBValidKey): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = store.delete(key);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

function idbCount(store: IDBObjectStore): Promise<number> {
  return new Promise((resolve, reject) => {
    const req = store.count();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

/** Serialize key pair to storable format */
function serializeKeyPair(kp: RawKeyPair): { pub: string; priv: string } {
  return { pub: toBase64(kp.publicKey), priv: toBase64(kp.privateKey) };
}

/** Deserialize key pair from stored format */
function deserializeKeyPair(stored: { pub: string; priv: string }): RawKeyPair {
  return { publicKey: fromBase64(stored.pub), privateKey: fromBase64(stored.priv) };
}

export class IndexedDBKeyStore {
  private db: IDBDatabase | null = null;

  private async getDB(): Promise<IDBDatabase> {
    if (!this.db) this.db = await openDB();
    return this.db;
  }

  // ── Identity Key (WebCrypto — non-extractable private key) ──
  // When encrypted store is active, serializes key material as bytes and encrypts.
  // When not active, stores CryptoKey natively via structured clone (legacy behavior).

  async saveIdentityKey(
    publicKeyRaw: Uint8Array,
    privateKeyCryptoKey: CryptoKey,
    publicKeyCryptoKey: CryptoKey
  ): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.identity, 'readwrite');

    // Encrypt key bytes when available; true non-extractable CryptoKey objects
    // are stored natively via IndexedDB structured clone (already hardware-protected).
    const privBytes = privateKeyCryptoKey instanceof Uint8Array
      ? privateKeyCryptoKey
      : null;
    const pubCryptoBytes = publicKeyCryptoKey instanceof Uint8Array
      ? publicKeyCryptoKey
      : null;

    if (privBytes && pubCryptoBytes) {
      // Raw bytes path: encrypt the entire identity object
      const encrypted = await encryptObjectForStorage({
        publicKeyRaw: toBase64(publicKeyRaw),
        privateKeyRaw: toBase64(privBytes),
        publicKeyCryptoRaw: toBase64(pubCryptoBytes),
      });
      await idbPut(store, 'identity', { _encrypted: encrypted });
    } else {
      // True CryptoKey: cannot serialize for encryption, store natively
      // (WebCrypto non-extractable keys are already hardware-protected)
      await idbPut(store, 'identity', {
        publicKeyRaw: toBase64(publicKeyRaw),
        privateKeyCryptoKey,
        publicKeyCryptoKey,
      });
    }
  }

  async getIdentityKey(): Promise<{
    publicKeyRaw: Uint8Array;
    privateKeyCryptoKey: CryptoKey;
    publicKeyCryptoKey: CryptoKey;
  } | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.identity, 'readonly');
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = await idbGet<any>(store, 'identity');
    if (!data) return null;

    // Encrypted format: has _encrypted field
    if (data._encrypted && typeof data._encrypted === 'string') {
      const decrypted = await decryptObjectFromStorage<{
        publicKeyRaw: string;
        privateKeyRaw: string;
        publicKeyCryptoRaw: string;
      }>(data._encrypted);
      return {
        publicKeyRaw: fromBase64(decrypted.publicKeyRaw),
        // Return raw bytes cast to CryptoKey (transitional format)
        privateKeyCryptoKey: fromBase64(decrypted.privateKeyRaw) as unknown as CryptoKey,
        publicKeyCryptoKey: fromBase64(decrypted.publicKeyCryptoRaw) as unknown as CryptoKey,
      };
    }

    // Legacy unencrypted format: CryptoKey objects stored natively
    if (!data.publicKeyRaw) return null;
    return {
      publicKeyRaw: fromBase64(data.publicKeyRaw),
      privateKeyCryptoKey: data.privateKeyCryptoKey,
      publicKeyCryptoKey: data.publicKeyCryptoKey,
    };
  }

  /** Legacy getter for old base64-format identity keys (migration path) */
  async getIdentityKeyLegacy(): Promise<RawKeyPair | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.identity, 'readonly');
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = await idbGet<any>(store, 'identity');
    if (!data) return null;

    // Encrypted format
    if (data._encrypted && typeof data._encrypted === 'string') {
      try {
        const decrypted = await decryptObjectFromStorage<{
          publicKeyRaw: string;
          privateKeyRaw: string;
        }>(data._encrypted);
        return {
          publicKey: fromBase64(decrypted.publicKeyRaw),
          privateKey: fromBase64(decrypted.privateKeyRaw),
        };
      } catch {
        return null;
      }
    }

    // Legacy base64 format
    if (!data.pub || !data.priv) return null;
    return { publicKey: fromBase64(data.pub), privateKey: fromBase64(data.priv) };
  }

  // ── Signed Pre-Key ──

  async saveSignedPreKey(id: number, keyPair: RawKeyPair): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.signedPreKeys, 'readwrite');
    const encrypted = await encryptObjectForStorage(serializeKeyPair(keyPair));
    await idbPut(store, `spk_${id}`, encrypted);
  }

  async getSignedPreKey(id: number): Promise<RawKeyPair | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.signedPreKeys, 'readonly');
    const data = await idbGet<string | { pub: string; priv: string }>(store, `spk_${id}`);
    if (!data) return null;

    // Encrypted or plaintext-prefixed string format
    if (typeof data === 'string') {
      const obj = await decryptObjectFromStorage<{ pub: string; priv: string }>(data);
      return deserializeKeyPair(obj);
    }

    // Legacy object format (unencrypted)
    return deserializeKeyPair(data);
  }

  // ── One-Time Pre-Keys ──

  async saveOneTimePreKeys(keys: Array<{ id: string; keyPair: RawKeyPair }>): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.oneTimePreKeys, 'readwrite');
    for (const k of keys) {
      const encrypted = await encryptObjectForStorage(serializeKeyPair(k.keyPair));
      await idbPut(store, k.id, encrypted);
    }
  }

  async getOneTimePreKey(id: string): Promise<RawKeyPair | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.oneTimePreKeys, 'readonly');
    const data = await idbGet<string | { pub: string; priv: string }>(store, id);
    if (!data) return null;

    // Encrypted or plaintext-prefixed string format
    if (typeof data === 'string') {
      const obj = await decryptObjectFromStorage<{ pub: string; priv: string }>(data);
      return deserializeKeyPair(obj);
    }

    // Legacy object format (unencrypted)
    return deserializeKeyPair(data);
  }

  async deleteOneTimePreKey(id: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.oneTimePreKeys, 'readwrite');
    await idbDelete(store, id);
  }

  async getOneTimePreKeyCount(): Promise<number> {
    const db = await this.getDB();
    const store = tx(db, STORES.oneTimePreKeys, 'readonly');
    return idbCount(store);
  }

  // ── Sender Keys (group encryption) ──

  async saveSenderKey(groupId: string, state: Uint8Array): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readwrite');
    await idbPut(store, `active_${groupId}`, await encryptForStorage(state));
  }

  async getSenderKey(groupId: string): Promise<Uint8Array | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readonly');
    const data = await idbGet<string>(store, `active_${groupId}`);
    if (!data) return null;

    // decryptFromStorage handles all formats: wcrypt:, plain:, enc:, raw base64
    return decryptFromStorage(data);
  }

  async deleteSenderKey(groupId: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readwrite');
    await idbDelete(store, `active_${groupId}`);
  }

  async saveHistoricalSenderKey(groupId: string, state: Uint8Array): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readwrite');
    const existing = await idbGet<string[]>(store, `hist_${groupId}`) ?? [];
    existing.push(await encryptForStorage(state));
    await idbPut(store, `hist_${groupId}`, existing);
  }

  // ── Sessions (Double Ratchet state per peer device) ──

  async saveSession(userId: string, deviceId: number, state: Uint8Array): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.sessions, 'readwrite');
    await idbPut(store, `${userId}:${deviceId}`, await encryptForStorage(state));
  }

  async getSession(userId: string, deviceId: number): Promise<Uint8Array | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.sessions, 'readonly');
    const data = await idbGet<string>(store, `${userId}:${deviceId}`);
    if (!data) return null;

    // decryptFromStorage handles all formats: wcrypt:, plain:, enc:, raw base64
    return decryptFromStorage(data);
  }

  async deleteSession(userId: string, deviceId: number): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.sessions, 'readwrite');
    await idbDelete(store, `${userId}:${deviceId}`);
  }

  // ── Unacknowledged Ratchet States (two-phase commit) ──

  async saveUnackedRatchet(messageId: string, data: {
    sessionKey: string;  // "userId:deviceId" or "groupId"
    sessionType: 'ratchet' | 'senderKey';
    serializedState: string;  // base64
  }): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.unackedRatchet, 'readwrite');
    await idbPut(store, messageId, { ...data, createdAt: Date.now() });
  }

  async ackRatchet(messageId: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.unackedRatchet, 'readwrite');
    await idbDelete(store, messageId);
  }

  async getUnackedRatchets(): Promise<Array<{
    messageId: string;
    sessionKey: string;
    sessionType: 'ratchet' | 'senderKey';
    serializedState: string;
    createdAt: number;
  }>> {
    const db = await this.getDB();
    const store = tx(db, STORES.unackedRatchet, 'readonly');
    return new Promise((resolve, reject) => {
      const req = store.getAll();
      req.onsuccess = () => {
        const results = (req.result ?? []) as Array<{
          sessionKey: string;
          sessionType: 'ratchet' | 'senderKey';
          serializedState: string;
          createdAt: number;
        }>;
        // Fetch keys separately to pair each value with its messageId
        const keysReq = store.getAllKeys();
        keysReq.onsuccess = () => {
          const keys = keysReq.result;
          resolve(results.map((r, i) => ({
            messageId: String(keys[i]),
            sessionKey: r.sessionKey,
            sessionType: r.sessionType,
            serializedState: r.serializedState,
            createdAt: r.createdAt,
          })));
        };
        keysReq.onerror = () => reject(keysReq.error);
      };
      req.onerror = () => reject(req.error);
    });
  }

  // ── Device ID ──

  async getDeviceId(): Promise<number> {
    const db = await this.getDB();
    const store = tx(db, STORES.meta, 'readonly');
    const id = await idbGet<number>(store, 'deviceId');
    if (id !== undefined) return id;

    // First time: generate and store
    // BUG 2 fix: safe range (was 2147483647, /api/keys/fetch validates smaller range)
    const newId = Math.floor(Math.random() * 999999) + 1;
    const writeStore = tx(db, STORES.meta, 'readwrite');
    await idbPut(writeStore, 'deviceId', newId);
    return newId;
  }

  // ── Lifecycle ──

  async clear(): Promise<void> {
    const db = await this.getDB();
    for (const name of Object.values(STORES)) {
      const store = tx(db, name, 'readwrite');
      await new Promise<void>((resolve, reject) => {
        const req = store.clear();
        req.onsuccess = () => resolve();
        req.onerror = () => reject(req.error);
      });
    }
  }

  // ── Plaintext Cache & SK Distribution Ledger (Level 8 Idempotency) ──

  async saveDecryptedMessage(messageId: string, text: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.decryptedMessages, 'readwrite');
    const textBytes = new TextEncoder().encode(text);
    const secureText = await encryptForStorage(textBytes);
    await idbPut(store, messageId, secureText);
  }

  async getDecryptedMessage(messageId: string): Promise<string | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.decryptedMessages, 'readonly');
    const stored = await idbGet<string>(store, messageId);
    if (!stored) return null;
    const decryptedBytes = await decryptFromStorage(stored);
    return new TextDecoder().decode(decryptedBytes);
  }

  /** Save full decrypted media metadata (text + mediaUrl + AES key + IV + mimeType).
   *  Stored as encrypted JSON in the same decrypted-messages store, keyed with a
   *  `media:` prefix to distinguish from text-only entries. */
  async saveDecryptedMedia(messageId: string, data: {
    text: string;
    mediaUrl: string;
    aesKeyBase64: string;
    ivBase64: string;
    mimeType: string;
    inlineThumbnail?: string;
    linkPreview?: LinkPreviewPayload;
  }): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.decryptedMessages, 'readwrite');
    const json = JSON.stringify(data);
    const jsonBytes = new TextEncoder().encode(json);
    const encrypted = await encryptForStorage(jsonBytes);
    await idbPut(store, `media:${messageId}`, encrypted);
  }

  /** Get full decrypted media metadata. Returns null if not cached. */
  async getDecryptedMedia(messageId: string): Promise<{
    text: string;
    mediaUrl: string;
    aesKeyBase64: string;
    ivBase64: string;
    mimeType: string;
    inlineThumbnail?: string;
    linkPreview?: LinkPreviewPayload;
  } | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.decryptedMessages, 'readonly');
    const stored = await idbGet<string>(store, `media:${messageId}`);
    if (!stored) return null;
    const decryptedBytes = await decryptFromStorage(stored);
    const json = new TextDecoder().decode(decryptedBytes);
    return JSON.parse(json);
  }

  async markSKDistributionProcessed(messageId: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.processedDistributions, 'readwrite');
    await idbPut(store, messageId, Date.now());
  }

  async hasProcessedSKDistribution(messageId: string): Promise<boolean> {
    const db = await this.getDB();
    const store = tx(db, STORES.processedDistributions, 'readonly');
    const processed = await idbGet<number>(store, messageId);
    return processed !== undefined;
  }

  // ── Local Contacts Cache (Progressive WhatsApp Override) ──

  async saveLocalContact(phone: string, name: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.localContacts, 'readwrite');
    await idbPut(store, phone, name);
  }

  async getLocalContact(phone: string): Promise<string | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.localContacts, 'readonly');
    const name = await idbGet<string>(store, phone);
    return name ?? null;
  }
}

// ── Sender Key ACK helpers (O(1) distribution check) ──

export async function getAckedSenders(groupId: string): Promise<Set<string>> {
  const db = await openDB();
  const tx = db.transaction('sk_acks', 'readonly');
  const store = tx.objectStore('sk_acks');
  const index = store.index('groupId');
  return new Promise((resolve, reject) => {
    const req = index.getAll(groupId);
    req.onsuccess = () => {
      const entries = (req.result ?? []) as Array<{ groupId: string; senderId: string }>;
      resolve(new Set(entries.map((e) => e.senderId)));
    };
    req.onerror = () => reject(req.error);
  });
}

export async function markSkAcked(groupId: string, senderId: string): Promise<void> {
  const db = await openDB();
  const tx = db.transaction('sk_acks', 'readwrite');
  const store = tx.objectStore('sk_acks');
  return new Promise((resolve, reject) => {
    const req = store.put({ groupId, senderId, ackedAt: Date.now() });
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

export async function clearSkAcks(groupId: string, senderId: string): Promise<void> {
  const db = await openDB();
  const tx = db.transaction('sk_acks', 'readwrite');
  const store = tx.objectStore('sk_acks');
  return new Promise((resolve, reject) => {
    const req = store.delete([groupId, senderId]);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

/** Singleton keystore instance */
export const keyStore = new IndexedDBKeyStore();
