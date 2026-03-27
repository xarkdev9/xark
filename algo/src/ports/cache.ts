/**
 * Cache Port
 *
 * Contract for caching computed results (ranked lists, agreement scores).
 * Implement this for any cache: Redis, Memcached, in-memory LRU,
 * Cloudflare KV, browser localStorage, etc.
 *
 * Cache is OPTIONAL — the service works without it, just slower
 * on read-heavy workloads. Invalidation happens on every write.
 */

export interface CachePort {
  /**
   * Gets a cached value. Returns null on miss.
   */
  get<T>(key: string): Promise<T | null>;

  /**
   * Sets a value with optional TTL in milliseconds.
   * No TTL = lives until explicitly deleted or evicted.
   */
  set<T>(key: string, value: T, ttlMs?: number): Promise<void>;

  /**
   * Deletes a single key.
   */
  delete(key: string): Promise<void>;

  /**
   * Deletes all keys matching a prefix.
   * Used for bulk invalidation: e.g., deleteByPrefix("space:xyz:")
   * clears all cached data for that space.
   */
  deleteByPrefix(prefix: string): Promise<void>;
}
