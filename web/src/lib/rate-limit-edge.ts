// hello OS v2.0 — Edge Rate Limiting (BACKEND-03)
// Upstash Redis-backed rate limiting in Next.js middleware.
// Blocks malicious traffic BEFORE serverless functions spin up.
//
// Fail-open: if Redis is down, allow the request (messaging must never go down).
// Fail-closed: if Redis is down, block with 503 (prevents $50k SMS/AI bills).
//
// If UPSTASH env vars are missing, rate limiting is skipped entirely (local dev).

import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

// ── Types ──

export type FailureMode = 'open' | 'closed';

export interface RouteRateConfig {
  /** Upstash Ratelimit instance for this route */
  limiter: Ratelimit;
  /** Key prefix for Redis (e.g. "rl:msg") */
  prefix: string;
  /** Whether to use IP instead of userId for keying */
  keyByIp?: boolean;
  /** Fail-open or fail-closed when Redis is unreachable */
  failureMode: FailureMode;
}

export interface RateLimitResult {
  allowed: boolean;
  /** Seconds until the limit resets (for Retry-After header) */
  retryAfter?: number;
  /** HTTP status to return if blocked (429 for rate limit, 503 for fail-closed) */
  status?: number;
}

// ── Redis Client ──

function createRedis(): Redis | null {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;
  return new Redis({ url, token });
}

const redis = createRedis();

// ── Limiter Factory ──

function tokenBucket(prefix: string, maxTokens: number, refillRate: number, interval: `${number} s` | `${number} m` | `${number} h` | `${number} d`): Ratelimit | null {
  if (!redis) return null;
  return new Ratelimit({
    redis,
    prefix,
    limiter: Ratelimit.tokenBucket(maxTokens, interval, refillRate),
    analytics: false,
  });
}

function slidingWindow(prefix: string, maxRequests: number, window: `${number} s` | `${number} m` | `${number} h` | `${number} d`): Ratelimit | null {
  if (!redis) return null;
  return new Ratelimit({
    redis,
    prefix,
    limiter: Ratelimit.slidingWindow(maxRequests, window),
    analytics: false,
  });
}

// ── Route Config ──

function buildRouteConfig(): Map<string, RouteRateConfig> | null {
  if (!redis) return null;

  const msgLimiter = tokenBucket('rl:msg', 200, 60, '1 m');
  const kfLimiter = slidingWindow('rl:kf', 30, '1 m');
  const otkLimiter = slidingWindow('rl:otk', 10, '1 m');
  const kbLimiter = slidingWindow('rl:kb', 5, '1 m');
  const aiLimiter = slidingWindow('rl:ai', 10, '1 m');
  const authLimiter = slidingWindow('rl:auth', 5, '1 m');
  const ccLimiter = slidingWindow('rl:cc', 5, '1 m');
  const csLimiter = slidingWindow('rl:cs', 20, '1 m');
  const invLimiter = slidingWindow('rl:inv', 10, '1 m');
  const laLimiter = slidingWindow('rl:la', 20, '1 m');
  const ntfLimiter = slidingWindow('rl:ntf', 30, '1 m');

  // If any limiter failed to create (shouldn't happen if redis exists), bail
  if (!msgLimiter || !kfLimiter || !otkLimiter || !kbLimiter || !aiLimiter ||
      !authLimiter || !ccLimiter || !csLimiter || !invLimiter || !laLimiter || !ntfLimiter) {
    return null;
  }

  const config = new Map<string, RouteRateConfig>();

  config.set('/api/message', {
    limiter: msgLimiter, prefix: 'rl:msg', failureMode: 'open',
  });
  config.set('/api/keys/fetch', {
    limiter: kfLimiter, prefix: 'rl:kf', failureMode: 'open',
  });
  config.set('/api/keys/otk', {
    limiter: otkLimiter, prefix: 'rl:otk', failureMode: 'open',
  });
  config.set('/api/keys/bundle', {
    limiter: kbLimiter, prefix: 'rl:kb', failureMode: 'open',
  });
  config.set('/api/hello', {
    limiter: aiLimiter, prefix: 'rl:ai', failureMode: 'closed',
  });
  config.set('/api/phone-auth', {
    limiter: authLimiter, prefix: 'rl:auth', keyByIp: true, failureMode: 'closed',
  });
  config.set('/api/contacts/check', {
    limiter: ccLimiter, prefix: 'rl:cc', failureMode: 'closed',
  });
  config.set('/api/chat/start', {
    limiter: csLimiter, prefix: 'rl:cs', failureMode: 'open',
  });
  config.set('/api/invite', {
    limiter: invLimiter, prefix: 'rl:inv', failureMode: 'open',
  });
  config.set('/api/local-action', {
    limiter: laLimiter, prefix: 'rl:la', failureMode: 'open',
  });
  config.set('/api/notify', {
    limiter: ntfLimiter, prefix: 'rl:ntf', failureMode: 'open',
  });

  return config;
}

export const ROUTE_RATE_CONFIG = buildRouteConfig();

// ── Core Check ──

/**
 * Check rate limit with 1-second timeout and fail-open/fail-closed semantics.
 *
 * @param limiter - Upstash Ratelimit instance
 * @param key - Rate limit key (userId or IP)
 * @param failureMode - 'open' = allow on Redis failure, 'closed' = block on Redis failure
 */
export async function checkLimit(
  limiter: Ratelimit,
  key: string,
  failureMode: FailureMode = 'open',
): Promise<RateLimitResult> {
  try {
    // 1-second hard timeout on Redis calls
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 1000);

    const result = await Promise.race([
      limiter.limit(key),
      new Promise<never>((_, reject) => {
        controller.signal.addEventListener('abort', () =>
          reject(new Error('rate-limit-timeout'))
        );
      }),
    ]);

    clearTimeout(timeout);

    if (!result.success) {
      const retryAfter = Math.ceil((result.reset - Date.now()) / 1000);
      return {
        allowed: false,
        retryAfter: Math.max(1, retryAfter),
        status: 429,
      };
    }

    return { allowed: true };
  } catch (err) {
    // Redis is down or timed out
    const isTimeout = err instanceof Error && err.message === 'rate-limit-timeout';
    console.warn(
      `[hello-rate-limit-edge] ${isTimeout ? 'timeout' : 'error'} for key=${key}, failureMode=${failureMode}`,
      isTimeout ? '' : err,
    );

    if (failureMode === 'open') {
      // Messaging must never go down
      return { allowed: true };
    } else {
      // Prevent runaway bills (SMS, AI)
      return { allowed: false, retryAfter: 5, status: 503 };
    }
  }
}
