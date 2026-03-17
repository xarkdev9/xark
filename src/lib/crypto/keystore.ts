// XARK OS v2.0 — KeyStore (IndexedDB)
// Persistent key storage for E2EE. IndexedDB for PWA.
// Interface is abstract — swap for native Keychain on iOS/Android.

import type { RawKeyPair } from './types';
import { toBase64, fromBase64 } from './primitives';

const DB_NAME = 'xark-keystore';
const DB_VERSION = 1;

const STORES = {
  identity: 'identity',
  signedPreKeys: 'signed-pre-keys',
  oneTimePreKeys: 'one-time-pre-keys',
  senderKeys: 'sender-keys',
  sessions: 'sessions',
  meta: 'meta',
} as const;

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const name of Object.values(STORES)) {
        if (!db.objectStoreNames.contains(name)) {
          db.createObjectStore(name);
        }
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

  async saveIdentityKey(
    publicKeyRaw: Uint8Array,
    privateKeyCryptoKey: CryptoKey,
    publicKeyCryptoKey: CryptoKey
  ): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.identity, 'readwrite');
    // CryptoKey objects are stored natively by IndexedDB (structured clone algorithm)
    await idbPut(store, 'identity', {
      publicKeyRaw: toBase64(publicKeyRaw),
      privateKeyCryptoKey,  // non-extractable CryptoKey — IndexedDB stores natively
      publicKeyCryptoKey,   // CryptoKey for verification
    });
  }

  async getIdentityKey(): Promise<{
    publicKeyRaw: Uint8Array;
    privateKeyCryptoKey: CryptoKey;
    publicKeyCryptoKey: CryptoKey;
  } | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.identity, 'readonly');
    const data = await idbGet<{
      publicKeyRaw: string;
      privateKeyCryptoKey: CryptoKey;
      publicKeyCryptoKey: CryptoKey;
    }>(store, 'identity');
    if (!data) return null;
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
    const data = await idbGet<{ pub?: string; priv?: string }>(store, 'identity');
    if (!data || !data.pub || !data.priv) return null;
    return { publicKey: fromBase64(data.pub), privateKey: fromBase64(data.priv) };
  }

  // ── Signed Pre-Key ──

  async saveSignedPreKey(id: number, keyPair: RawKeyPair): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.signedPreKeys, 'readwrite');
    await idbPut(store, `spk_${id}`, serializeKeyPair(keyPair));
  }

  async getSignedPreKey(id: number): Promise<RawKeyPair | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.signedPreKeys, 'readonly');
    const data = await idbGet<{ pub: string; priv: string }>(store, `spk_${id}`);
    if (!data) return null;
    return deserializeKeyPair(data);
  }

  // ── One-Time Pre-Keys ──

  async saveOneTimePreKeys(keys: Array<{ id: string; keyPair: RawKeyPair }>): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.oneTimePreKeys, 'readwrite');
    for (const k of keys) {
      await idbPut(store, k.id, serializeKeyPair(k.keyPair));
    }
  }

  async getOneTimePreKey(id: string): Promise<RawKeyPair | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.oneTimePreKeys, 'readonly');
    const data = await idbGet<{ pub: string; priv: string }>(store, id);
    if (!data) return null;
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

  async saveSenderKey(spaceId: string, state: Uint8Array): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readwrite');
    await idbPut(store, `active_${spaceId}`, toBase64(state));
  }

  async getSenderKey(spaceId: string): Promise<Uint8Array | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readonly');
    const data = await idbGet<string>(store, `active_${spaceId}`);
    if (!data) return null;
    return fromBase64(data);
  }

  async deleteSenderKey(spaceId: string): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readwrite');
    await idbDelete(store, `active_${spaceId}`);
  }

  async saveHistoricalSenderKey(spaceId: string, state: Uint8Array): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.senderKeys, 'readwrite');
    const existing = await idbGet<string[]>(store, `hist_${spaceId}`) ?? [];
    existing.push(toBase64(state));
    await idbPut(store, `hist_${spaceId}`, existing);
  }

  // ── Sessions (Double Ratchet state per peer device) ──

  async saveSession(userId: string, deviceId: number, state: Uint8Array): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.sessions, 'readwrite');
    await idbPut(store, `${userId}:${deviceId}`, toBase64(state));
  }

  async getSession(userId: string, deviceId: number): Promise<Uint8Array | null> {
    const db = await this.getDB();
    const store = tx(db, STORES.sessions, 'readonly');
    const data = await idbGet<string>(store, `${userId}:${deviceId}`);
    if (!data) return null;
    return fromBase64(data);
  }

  async deleteSession(userId: string, deviceId: number): Promise<void> {
    const db = await this.getDB();
    const store = tx(db, STORES.sessions, 'readwrite');
    await idbDelete(store, `${userId}:${deviceId}`);
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
}

/** Singleton keystore instance */
export const keyStore = new IndexedDBKeyStore();
