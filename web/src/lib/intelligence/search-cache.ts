// web/src/lib/intelligence/search-cache.ts
// General-purpose search result cache. Wraps Upstash Redis.
// Tiered TTLs by source type. LLM-generated normalized cache keys.

import { Redis } from "@upstash/redis";

const redis =
  process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN
    ? new Redis({
        url: process.env.UPSTASH_REDIS_REST_URL,
        token: process.env.UPSTASH_REDIS_REST_TOKEN,
      })
    : null;

const KEY_PREFIX = "search";

// Tiered TTLs by content type
const TTL_MAP: Record<string, number> = {
  flight: 4 * 3600,        // 4 hours (high price volatility)
  hotel: 6 * 3600,         // 6 hours (medium volatility)
  restaurant: 24 * 3600,   // 24 hours (low volatility)
  local_restaurant: 24 * 3600,
  activity: 24 * 3600,
  local_activity: 24 * 3600,
  general: 7 * 24 * 3600,  // 7 days (knowledge queries)
  default: 4 * 3600,       // 4 hours fallback
};

export interface CachedSearchResult {
  results: Array<{
    title: string;
    price?: string;
    imageUrl?: string;
    description?: string;
    externalUrl?: string;
    rating?: number;
    source?: string;
  }>;
  cachedAt: number;
  tool: string;
  cacheKey: string;
}

function getTTL(tool: string): number {
  return TTL_MAP[tool] || TTL_MAP.default;
}

/**
 * Get cached search results.
 * @param cacheKey - LLM-generated normalized key (e.g., "hotels:bali:beachfront")
 * @param tool - Tool name for TTL lookup
 */
export async function getCachedSearch(
  cacheKey: string,
  tool: string
): Promise<CachedSearchResult | null> {
  if (!redis) return null;
  try {
    const key = `${KEY_PREFIX}:${tool}:${cacheKey}`;
    const cached = await redis.get<CachedSearchResult>(key);
    return cached ?? null;
  } catch (err) {
    console.warn("[search-cache] Read failed:", err instanceof Error ? err.message : String(err));
    return null;
  }
}

/**
 * Cache search results.
 * @param cacheKey - LLM-generated normalized key
 * @param tool - Tool name for TTL lookup
 * @param results - Search results to cache
 */
export async function setCachedSearch(
  cacheKey: string,
  tool: string,
  results: CachedSearchResult["results"]
): Promise<void> {
  if (!redis || results.length === 0) return;
  try {
    const key = `${KEY_PREFIX}:${tool}:${cacheKey}`;
    const ttl = getTTL(tool);
    const value: CachedSearchResult = {
      results: results.slice(0, 20), // cap at 20
      cachedAt: Date.now(),
      tool,
      cacheKey,
    };
    await redis.set(key, value, { ex: ttl });
    console.log(`[search-cache] Cached ${results.length} results for ${key} (TTL: ${ttl}s)`);
  } catch (err) {
    console.warn("[search-cache] Write failed:", err instanceof Error ? err.message : String(err));
  }
}
