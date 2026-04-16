// hello OS v2.0 — Local-First Message Cache
// Separate IndexedDB from xark-keystore to avoid version contention.
// Stores already-decrypted plaintext for instant rendering on app open.
// Same security model as decrypted-messages in keystore — device-local only.

const DB_NAME = 'hello-message-cache';
const DB_VERSION = 1;
const STORE_NAME = 'messages';
const MAX_PER_SPACE = 200;

interface CachedMessage {
  id: string;
  groupId: string;
  content: string;
  role: string;
  timestamp: number;
  senderName?: string;
  userId?: string;
  senderDeviceId?: number;
  messageType?: string;
  deliveryStatus?: string;
  cachedAt: number;
}

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onblocked = () => {
      // Fallback: open at whatever version is available
      const fallback = indexedDB.open(DB_NAME);
      fallback.onsuccess = () => resolve(fallback.result);
      fallback.onerror = () => reject(new Error('message-cache DB blocked'));
    };
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: 'id' });
        store.createIndex('bySpace', 'groupId', { unique: false });
        store.createIndex('bySpaceTime', ['groupId', 'timestamp'], { unique: false });
      }
    };
  });
}

let dbPromise: Promise<IDBDatabase> | null = null;
function getDB(): Promise<IDBDatabase> {
  if (!dbPromise) dbPromise = openDB();
  return dbPromise;
}

/**
 * Cache a batch of decrypted messages for a space.
 * Deduplicates by id — safe to call multiple times with overlapping data.
 */
export async function cacheBatchMessages(
  groupId: string,
  messages: Array<{
    id: string;
    content: string;
    role: string;
    timestamp: number;
    senderName?: string;
    userId?: string;
    senderDeviceId?: number;
    messageType?: string;
    deliveryStatus?: string;
  }>
): Promise<void> {
  if (messages.length === 0) return;
  try {
    const db = await getDB();
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const now = Date.now();

    for (const msg of messages) {
      // Skip messages with no real content
      if (!msg.content || msg.content === '[decryption pending]' || msg.content === '[Error: Decryption Failed]') continue;

      const entry: CachedMessage = {
        id: msg.id,
        groupId,
        content: msg.content,
        role: msg.role,
        timestamp: msg.timestamp,
        senderName: msg.senderName,
        userId: msg.userId,
        senderDeviceId: msg.senderDeviceId,
        messageType: msg.messageType,
        deliveryStatus: msg.deliveryStatus,
        cachedAt: now,
      };
      store.put(entry); // put = upsert by keyPath
    }

    await new Promise<void>((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // Silent — cache is UX acceleration, not critical path
  }
}

/**
 * Get cached messages for a space, sorted by timestamp ascending.
 */
export async function getCachedMessages(
  groupId: string,
  limit: number = 50
): Promise<CachedMessage[]> {
  try {
    const db = await getDB();
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const index = store.index('bySpace');
    const range = IDBKeyRange.only(groupId);

    return new Promise((resolve, reject) => {
      const results: CachedMessage[] = [];
      const request = index.openCursor(range, 'prev'); // newest first
      request.onsuccess = () => {
        const cursor = request.result;
        if (cursor && results.length < limit) {
          results.push(cursor.value);
          cursor.continue();
        } else {
          // Reverse to ascending order (oldest first, like chat display)
          resolve(results.reverse());
        }
      };
      request.onerror = () => reject(request.error);
    });
  } catch {
    return [];
  }
}

/**
 * Get the newest cached timestamp for a space (for delta sync).
 * Returns null if no cache exists — triggers full fetch.
 */
export async function getCacheWatermark(groupId: string): Promise<string | null> {
  try {
    const db = await getDB();
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const index = store.index('bySpace');
    const range = IDBKeyRange.only(groupId);

    return new Promise((resolve, reject) => {
      const request = index.openCursor(range, 'prev'); // newest first
      request.onsuccess = () => {
        const cursor = request.result;
        if (cursor) {
          const msg = cursor.value as CachedMessage;
          // Return ISO string for Supabase .gt() filter
          resolve(new Date(msg.timestamp).toISOString());
        } else {
          resolve(null); // no cache
        }
      };
      request.onerror = () => reject(request.error);
    });
  } catch {
    return null;
  }
}

/**
 * Evict old messages beyond the cap per space.
 */
export async function evictOldMessages(groupId: string, keepCount: number = MAX_PER_SPACE): Promise<void> {
  try {
    const db = await getDB();
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const index = store.index('bySpace');
    const range = IDBKeyRange.only(groupId);

    const allKeys: IDBValidKey[] = [];
    const request = index.openCursor(range, 'prev'); // newest first

    await new Promise<void>((resolve, reject) => {
      request.onsuccess = () => {
        const cursor = request.result;
        if (cursor) {
          allKeys.push(cursor.primaryKey);
          cursor.continue();
        } else {
          resolve();
        }
      };
      request.onerror = () => reject(request.error);
    });

    // Delete everything beyond keepCount (oldest messages)
    if (allKeys.length > keepCount) {
      const toDelete = allKeys.slice(keepCount);
      for (const key of toDelete) {
        store.delete(key);
      }
    }

    await new Promise<void>((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // Silent
  }
}

/**
 * Clear all cached messages for a space (logout, crypto shred, member leave).
 */
export async function clearSpaceCache(groupId: string): Promise<void> {
  try {
    const db = await getDB();
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const index = store.index('bySpace');
    const range = IDBKeyRange.only(groupId);

    const request = index.openCursor(range);
    await new Promise<void>((resolve, reject) => {
      request.onsuccess = () => {
        const cursor = request.result;
        if (cursor) {
          cursor.delete();
          cursor.continue();
        } else {
          resolve();
        }
      };
      request.onerror = () => reject(request.error);
    });
  } catch {
    // Silent
  }
}

/**
 * Clear ALL cached messages (full logout).
 */
export async function clearAllCache(): Promise<void> {
  try {
    const db = await getDB();
    const tx = db.transaction(STORE_NAME, 'readwrite');
    tx.objectStore(STORE_NAME).clear();
    await new Promise<void>((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // Silent
  }
}
