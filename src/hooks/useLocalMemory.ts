// XARK OS v2.0 — Tier 2: E2EE Memory Engine React Hook
// Initializes Worker on space open, bridges postMessage/onmessage,
// exposes search() and indexMessage(). Encrypted blob persistence via IndexedDB.

"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import type { RecallResult } from "@/lib/local-recall";

const IDB_STORE = "xark-memory";
const IDB_VERSION = 1;
const MAX_CONTENT_LENGTH = 2000;

// ── IndexedDB helpers ──
function openIDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(IDB_STORE, IDB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("blobs")) {
        db.createObjectStore("blobs");
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function getBlob(spaceId: string): Promise<string | null> {
  try {
    const db = await openIDB();
    return new Promise((resolve) => {
      const tx = db.transaction("blobs", "readonly");
      const req = tx.objectStore("blobs").get(spaceId);
      req.onsuccess = () => resolve(req.result ?? null);
      req.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}

async function setBlob(spaceId: string, data: string): Promise<void> {
  try {
    const db = await openIDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction("blobs", "readwrite");
      tx.objectStore("blobs").put(data, spaceId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // Silent — blob persistence is best-effort
  }
}

async function deleteBlobEntry(spaceId: string): Promise<void> {
  try {
    const db = await openIDB();
    return new Promise((resolve) => {
      const tx = db.transaction("blobs", "readwrite");
      tx.objectStore("blobs").delete(spaceId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    });
  } catch {
    // Silent
  }
}

export function useLocalMemory(spaceId: string | null) {
  const workerRef = useRef<Worker | null>(null);
  const [ready, setReady] = useState(false);
  const [watermark, setWatermark] = useState<number | null>(null);
  const resolveSearch = useRef<((results: RecallResult[]) => void) | null>(null);

  // ── Initialize Worker when spaceId changes ──
  useEffect(() => {
    if (!spaceId) return;
    if (typeof window === "undefined") return; // SSR guard

    let worker: Worker;
    try {
      worker = new Worker(
        new URL("../workers/memory-worker.ts", import.meta.url),
        { type: "module" }
      );
    } catch (err) {
      console.warn("[local-memory] Worker creation failed:", err);
      return;
    }
    workerRef.current = worker;

    worker.onmessage = (event: MessageEvent) => {
      const { type } = event.data;

      if (type === "READY") {
        setReady(true);
        setWatermark(event.data.watermarkTime ?? null);
      }

      if (type === "RESULTS") {
        resolveSearch.current?.(event.data.matches ?? []);
        resolveSearch.current = null;
      }

      if (type === "PERSIST") {
        // Write serialized index to IndexedDB
        // NOTE: For v1 this stores plaintext. Phase 2b will add XChaCha20-Poly1305 encryption
        // using crypto_secretbox from libsodium, key derived from identity key via HKDF.
        setBlob(spaceId, event.data.payload).catch(() => {});
      }
    };

    worker.onerror = (err) => {
      console.warn("[local-memory] Worker error:", err);
    };

    // Load existing blob and init worker
    getBlob(spaceId).then((blob) => {
      worker.postMessage({
        type: "INIT",
        spaceId,
        serializedIndex: blob ?? undefined,
        deviceTier: "low", // lexical only in Phase 2
      });
    });

    return () => {
      worker.terminate();
      workerRef.current = null;
      setReady(false);
      setWatermark(null);
    };
  }, [spaceId]);

  const indexMessage = useCallback(
    (message: { id: string; content: string; senderName?: string; timestamp: number }) => {
      if (!workerRef.current || !ready) return;
      workerRef.current.postMessage({
        type: "INDEX_MESSAGE",
        message: {
          id: message.id,
          content: message.content.slice(0, MAX_CONTENT_LENGTH),
          senderName: message.senderName ?? "",
          timestamp: message.timestamp,
        },
      });
    },
    [ready]
  );

  const search = useCallback(
    (query: string): Promise<RecallResult[]> => {
      if (!workerRef.current || !ready) return Promise.resolve([]);
      return new Promise((resolve) => {
        resolveSearch.current = resolve;
        workerRef.current!.postMessage({ type: "SEARCH", query });
        setTimeout(() => {
          if (resolveSearch.current === resolve) {
            resolveSearch.current = null;
            resolve([]);
          }
        }, 2000);
      });
    },
    [ready]
  );

  const deleteBlob = useCallback(() => {
    if (spaceId) return deleteBlobEntry(spaceId);
    return Promise.resolve();
  }, [spaceId]);

  return { ready, watermark, indexMessage, search, deleteBlob };
}
