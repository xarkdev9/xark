// web/src/lib/intelligence/global-semaphore.ts
// Global Redis-based concurrency limiter for Gemini/SearchAPI calls.
// Prevents thundering herd: if >N calls are in-flight across ALL lambdas,
// new requests get a "busy" response instead of amplifying the load.

import { Redis } from "@upstash/redis";

const redis =
  process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN
    ? new Redis({
        url: process.env.UPSTASH_REDIS_REST_URL,
        token: process.env.UPSTASH_REDIS_REST_TOKEN,
      })
    : null;

const SEMAPHORE_KEY = "global:ai_concurrency";
const MAX_CONCURRENT = 25; // max concurrent Gemini calls across all lambdas
const SEMAPHORE_TTL = 60; // auto-expire after 60s (safety net for crashed lambdas)

export interface SemaphoreResult {
  acquired: boolean;
  currentCount: number;
}

/**
 * Try to acquire a slot in the global concurrency pool.
 * Returns { acquired: true } if under the limit, { acquired: false } if overloaded.
 */
export async function acquireSlot(): Promise<SemaphoreResult> {
  if (!redis) return { acquired: true, currentCount: 0 }; // no Redis = no limiting

  try {
    const count = await redis.incr(SEMAPHORE_KEY);

    // Set TTL on first increment (safety net — if a lambda crashes, the counter auto-resets)
    if (count === 1) {
      await redis.expire(SEMAPHORE_KEY, SEMAPHORE_TTL);
    }

    if (count > MAX_CONCURRENT) {
      // Over limit — release immediately and return busy
      await redis.decr(SEMAPHORE_KEY);
      console.warn(`[semaphore] Rejected: ${count}/${MAX_CONCURRENT} concurrent calls`);
      return { acquired: false, currentCount: count - 1 };
    }

    return { acquired: true, currentCount: count };
  } catch (err) {
    console.warn("[semaphore] Acquire failed, allowing through:", err instanceof Error ? err.message : String(err));
    return { acquired: true, currentCount: 0 }; // fail-open
  }
}

/**
 * Release a slot after the AI call completes (success or failure).
 * Always call this in a finally block.
 */
export async function releaseSlot(): Promise<void> {
  if (!redis) return;

  try {
    const count = await redis.decr(SEMAPHORE_KEY);
    // Prevent negative counter (edge case: TTL expired between acquire and release)
    if (count < 0) {
      await redis.set(SEMAPHORE_KEY, 0, { ex: SEMAPHORE_TTL });
    }
  } catch (err) {
    console.warn("[semaphore] Release failed:", err instanceof Error ? err.message : String(err));
  }
}

/**
 * Check current concurrency without acquiring a slot.
 * Useful for monitoring / health checks.
 */
export async function getCurrentConcurrency(): Promise<number> {
  if (!redis) return 0;
  try {
    const count = await redis.get<number>(SEMAPHORE_KEY);
    return count ?? 0;
  } catch {
    return 0;
  }
}
