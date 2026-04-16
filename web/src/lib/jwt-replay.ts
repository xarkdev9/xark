import { Redis } from '@upstash/redis';

const redis = process.env.UPSTASH_REDIS_REST_URL
  ? new Redis({
      url: process.env.UPSTASH_REDIS_REST_URL!,
      token: process.env.UPSTASH_REDIS_REST_TOKEN!,
    })
  : null;

const JTI_PREFIX = 'jti';
const JTI_TTL_SECONDS = 3600; // 1 hour (matches typical JWT expiry)

/**
 * Check if a JWT ID has been seen before (replay detection).
 * Returns true if the jti is fresh (not replayed).
 * Returns false if the jti was already consumed (replay attack).
 *
 * Uses Redis SETNX — if the key already exists, it's a replay.
 * TTL auto-expires consumed jti entries after the JWT would have expired anyway.
 */
export async function checkJtiReplay(jti: string | undefined): Promise<{ fresh: boolean }> {
  // No jti claim — skip check (backward compat with old JWTs)
  if (!jti) return { fresh: true };

  // No Redis — skip check (local dev)
  if (!redis) return { fresh: true };

  try {
    // SETNX: returns true if key was SET (first time seen = fresh)
    // returns false if key already EXISTS (replay)
    const wasSet = await redis.set(`${JTI_PREFIX}:${jti}`, '1', {
      nx: true,
      ex: JTI_TTL_SECONDS,
    });

    return { fresh: wasSet !== null };
  } catch {
    // Redis failure — fail open (don't block legitimate requests)
    return { fresh: true };
  }
}

/**
 * Extract jti from a JWT token without full verification.
 * The JWT is already verified by Supabase — we just need the jti claim.
 */
export function extractJti(token: string): string | undefined {
  try {
    const payload = JSON.parse(
      Buffer.from(token.split('.')[1], 'base64').toString()
    );
    return payload.jti;
  } catch {
    return undefined;
  }
}
