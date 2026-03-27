// hello OS v2.0 — Web Locks API Mutex (CRYPTO-05)
// Cross-tab exclusive locks for E2EE ratchet and sender key operations.
// Falls back to in-tab promise-queue mutex when Web Locks API is unavailable.

const HAS_WEB_LOCKS = typeof navigator !== 'undefined' && 'locks' in navigator;

const inTabLocks = new Map<string, Promise<void>>();

async function inTabLock<T>(name: string, fn: () => Promise<T>): Promise<T> {
  while (inTabLocks.has(name)) {
    await inTabLocks.get(name);
  }
  let resolve: () => void;
  const promise = new Promise<void>((r) => { resolve = r; });
  inTabLocks.set(name, promise);
  try {
    return await fn();
  } finally {
    inTabLocks.delete(name);
    resolve!();
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
