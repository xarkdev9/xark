/**
 * In-Memory Cache Adapter
 *
 * Simple Map-based cache with TTL support. Good for:
 * - Development and testing
 * - Single-process deployments
 *
 * For distributed caching, replace with:
 * - RedisCacheAdapter
 * - MemcachedCacheAdapter
 * - CloudflareKvCacheAdapter
 */

import type { CachePort } from "../ports/cache.js";

interface CacheEntry<T> {
  value: T;
  expiresAt: number | null; // null = no expiry
}

export class MemoryCacheAdapter implements CachePort {
  private store = new Map<string, CacheEntry<unknown>>();

  async get<T>(key: string): Promise<T | null> {
    const entry = this.store.get(key);
    if (!entry) return null;

    if (entry.expiresAt !== null && Date.now() > entry.expiresAt) {
      this.store.delete(key);
      return null;
    }

    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlMs?: number): Promise<void> {
    this.store.set(key, {
      value,
      expiresAt: ttlMs ? Date.now() + ttlMs : null,
    });
  }

  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  async deleteByPrefix(prefix: string): Promise<void> {
    for (const key of this.store.keys()) {
      if (key.startsWith(prefix)) {
        this.store.delete(key);
      }
    }
  }

  /** Returns the number of entries (including expired). */
  get size(): number {
    return this.store.size;
  }

  /** Removes all entries. */
  clear(): void {
    this.store.clear();
  }
}
