// XARK OS v2.0 — Offline Message Outbox Queue
// Encrypts locally, retries on reconnect.
// Prevents message loss on network drops without falling back to plaintext.

import { getSupabaseToken } from '../supabase';

export interface OutboxEntry {
  id: string;
  spaceId: string;
  envelope: {
    ciphertext: string;
    ratchetHeader?: string;
    recipientId: string;
    recipientDeviceId: number;
  };
  senderDeviceId: number;
  createdAt: number;
  attempts: number;
}

const DB_NAME = 'xark-outbox';
const STORE_NAME = 'pending';

function openOutboxDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onerror = () => reject(req.error);
    req.onsuccess = () => resolve(req.result);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id' });
      }
    };
  });
}

/** Add a failed message to the outbox for retry */
export async function enqueueMessage(entry: OutboxEntry): Promise<void> {
  const db = await openOutboxDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const req = store.put(entry);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

/** Get all pending outbox entries */
export async function getPendingMessages(): Promise<OutboxEntry[]> {
  const db = await openOutboxDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const req = store.getAll();
    req.onsuccess = () => resolve(req.result ?? []);
    req.onerror = () => reject(req.error);
  });
}

/** Remove a successfully sent message from the outbox */
export async function dequeueMessage(id: string): Promise<void> {
  const db = await openOutboxDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const req = store.delete(id);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });
}

/** Drain the outbox — retry all pending messages.
 *  Called on: navigator.onLine, visibilitychange (visible), app boot. */
export async function drainOutbox(
  onSent?: (id: string) => void,
  onFailed?: (id: string, err: string) => void
): Promise<number> {
  const pending = await getPendingMessages();
  if (pending.length === 0) return 0;

  const token = getSupabaseToken();
  if (!token) return 0;  // No JWT yet — can't send

  let sent = 0;
  for (const entry of pending) {
    if (entry.attempts >= 5) {
      // Max retries exceeded — remove from outbox, log as permanent failure
      await dequeueMessage(entry.id);
      onFailed?.(entry.id, 'max retries exceeded');
      continue;
    }

    try {
      const res = await fetch('/api/message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          space_id: entry.spaceId,
          sender_device_id: entry.senderDeviceId,
          ciphertext: entry.envelope.ciphertext,
          ratchet_header: entry.envelope.ratchetHeader ?? null,
          recipient_id: entry.envelope.recipientId,
          recipient_device_id: entry.envelope.recipientDeviceId,
        }),
      });

      if (res.ok) {
        await dequeueMessage(entry.id);
        onSent?.(entry.id);
        sent++;
      } else {
        // Increment attempts
        entry.attempts++;
        await enqueueMessage(entry);
      }
    } catch {
      entry.attempts++;
      await enqueueMessage(entry);
    }
  }

  return sent;
}

/** Start background outbox drain listeners */
export function startOutboxSync(
  onSent?: (id: string) => void,
  onFailed?: (id: string, err: string) => void
): () => void {
  const drain = () => { drainOutbox(onSent, onFailed); };

  // Drain on reconnect
  window.addEventListener('online', drain);

  // Drain when tab becomes visible
  const onVisChange = () => {
    if (document.visibilityState === 'visible') drain();
  };
  document.addEventListener('visibilitychange', onVisChange);

  // Drain on boot
  drain();

  return () => {
    window.removeEventListener('online', drain);
    document.removeEventListener('visibilitychange', onVisChange);
  };
}
