// hello OS v2.0 — Web Locks API Mutex (CRYPTO-05)
// Cross-tab exclusive locks for E2EE ratchet and sender key operations.
// Falls back to in-tab promise-queue mutex when Web Locks API is unavailable.

const HAS_WEB_LOCKS = typeof navigator !== 'undefined' && 'locks' in navigator;

const inTabQueues = new Map<string, Promise<void>>();

async function inTabLock<T>(name: string, fn: () => Promise<T>): Promise<T> {
  // Chain on the previous lock holder's promise
  const prev = inTabQueues.get(name) ?? Promise.resolve();
  let release: () => void;
  const next = new Promise<void>((r) => { release = r; });
  inTabQueues.set(name, next);

  await prev; // Wait for previous holder to finish
  try {
    return await fn();
  } finally {
    release!();
    // Clean up if no one else is queued
    if (inTabQueues.get(name) === next) {
      inTabQueues.delete(name);
    }
  }
}

export async function acquireRatchetLock<T>(
  sessionId: string,
  fn: () => Promise<T>,
  timeoutMs: number = 5000,
): Promise<T> {
  const lockName = `ratchet:${sessionId}`;
  if (!HAS_WEB_LOCKS) {
    console.warn('Web Locks API unavailable — single-tab crypto safety only');
    return inTabLock(lockName, fn);
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await navigator.locks.request(
      lockName,
      { mode: 'exclusive', signal: controller.signal },
      () => fn(),
    );
  } finally {
    clearTimeout(timeout);
  }
}

export async function acquireSenderKeyLock<T>(
  groupId: string,
  fn: () => Promise<T>,
  timeoutMs: number = 5000,
): Promise<T> {
  const lockName = `sk:${groupId}`;
  if (!HAS_WEB_LOCKS) {
    console.warn('Web Locks API unavailable — single-tab crypto safety only');
    return inTabLock(lockName, fn);
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await navigator.locks.request(
      lockName,
      { mode: 'exclusive', signal: controller.signal },
      () => fn(),
    );
  } finally {
    clearTimeout(timeout);
  }
}
