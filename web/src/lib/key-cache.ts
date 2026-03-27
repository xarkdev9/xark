import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

const TTL_SECONDS = 300;
const KEY_PREFIX = 'kb';

function cacheKey(userId: string, deviceId: number): string {
  return `${KEY_PREFIX}:${userId}:${deviceId}`;
}

export interface CachedKeyBundle {
  identityKey: string;
  signedPreKey: string;
  signedPreKeyId: number;
  preKeySig: string;
  cachedAt: number;
}

export async function getCachedBundle(
  userId: string,
  deviceId: number,
): Promise<CachedKeyBundle | null> {
  try {
    const data = await redis.get<CachedKeyBundle>(cacheKey(userId, deviceId));
    return data;
  } catch {
    return null;
  }
}

export async function cacheBundle(
  userId: string,
  deviceId: number,
  bundle: CachedKeyBundle,
): Promise<void> {
  try {
    await redis.set(cacheKey(userId, deviceId), bundle, { nx: true, ex: TTL_SECONDS });
  } catch {
    // non-fatal
  }
}

export async function forceUpdateBundle(
  userId: string,
  deviceId: number,
  bundle: CachedKeyBundle,
): Promise<void> {
  try {
    await redis.del(cacheKey(userId, deviceId));
    await redis.set(cacheKey(userId, deviceId), bundle, { ex: TTL_SECONDS });
  } catch {
    // non-fatal
  }
}

export async function invalidateBundle(
  userId: string,
  deviceId: number,
): Promise<void> {
  try {
    await redis.del(cacheKey(userId, deviceId));
  } catch {
    // non-fatal
  }
}
