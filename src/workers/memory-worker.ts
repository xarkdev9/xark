/// <reference lib="webworker" />
// XARK OS v2.0 — Tier 2: E2EE Memory Engine — Web Worker
// Manages in-memory search index, debounced persistence, delta sync watermark.
// Main thread handles encryption/decryption; Worker operates on plaintext in RAM only.

import MiniSearch from "minisearch";

interface IndexedMessage {
  id: string;
  content: string;
  senderName: string;
  timestamp: number;
}

let index: MiniSearch<IndexedMessage> | null = null;
const messages: Map<string, IndexedMessage> = new Map();
let lastIndexedTimestamp: number = 0;
let persistTimer: ReturnType<typeof setTimeout> | null = null;
const MAX_MESSAGES = 1000;
const PERSIST_DEBOUNCE_MS = 3000;
const MAX_CONTENT_LENGTH = 2000;

function initIndex() {
  index = new MiniSearch<IndexedMessage>({
    fields: ["content", "senderName"],
    storeFields: ["content", "senderName", "timestamp"],
    searchOptions: {
      fuzzy: 0.2,
      prefix: true,
    },
  });
}

function evictOldest() {
  if (messages.size <= MAX_MESSAGES) return;
  const sorted = [...messages.values()].sort((a, b) => a.timestamp - b.timestamp);
  while (messages.size > MAX_MESSAGES) {
    const oldest = sorted.shift();
    if (oldest) {
      messages.delete(oldest.id);
      index?.discard(oldest.id);
    }
  }
}

function schedulePersist() {
  if (persistTimer) clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    const serialized = JSON.stringify({
      messages: [...messages.values()],
      lastIndexedTimestamp,
    });
    self.postMessage({ type: "PERSIST", payload: serialized });
    persistTimer = null;
  }, PERSIST_DEBOUNCE_MS);
}

// ── Message handler ──
self.onmessage = (event: MessageEvent) => {
  const { type } = event.data;

  if (type === "INIT") {
    initIndex();
    messages.clear();
    lastIndexedTimestamp = 0;

    const { serializedIndex } = event.data;
    if (serializedIndex) {
      try {
        const parsed = JSON.parse(serializedIndex);
        if (Array.isArray(parsed.messages)) {
          for (const msg of parsed.messages) {
            messages.set(msg.id, msg);
          }
          index!.addAll([...messages.values()]);
          lastIndexedTimestamp = parsed.lastIndexedTimestamp ?? 0;
        }
      } catch {
        initIndex();
        messages.clear();
      }
    }

    self.postMessage({ type: "READY", watermarkTime: lastIndexedTimestamp });
  }

  if (type === "INDEX_MESSAGE") {
    const { message } = event.data;
    if (!message?.id || !message?.content) return;
    if (messages.has(message.id)) return;

    const truncated: IndexedMessage = {
      id: message.id,
      content: message.content.slice(0, MAX_CONTENT_LENGTH),
      senderName: message.senderName ?? "",
      timestamp: message.timestamp ?? Date.now(),
    };

    messages.set(truncated.id, truncated);
    index?.add(truncated);
    lastIndexedTimestamp = Math.max(lastIndexedTimestamp, truncated.timestamp);

    evictOldest();
    schedulePersist();
  }

  if (type === "SEARCH") {
    const { query } = event.data;
    if (!index || !query) {
      self.postMessage({ type: "RESULTS", matches: [] });
      return;
    }

    const cleaned = query.replace(/@xark\s*/i, "").trim();
    const results = index.search(cleaned).slice(0, 5);

    const matches = results
      .map((r) => {
        const msg = messages.get(String(r.id));
        return msg
          ? { messageId: msg.id, content: msg.content, senderName: msg.senderName, timestamp: msg.timestamp }
          : null;
      })
      .filter(Boolean);

    self.postMessage({ type: "RESULTS", matches });
  }
};
