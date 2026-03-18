// XARK OS v2.0 — Centralized Rate Limiter
// Supabase Postgres-backed sliding window. Works across all serverless instances.
// Synchronous signature preserved for backward compat with existing callers.
// Fire-and-forget Postgres RPC builds centralized state across Lambda instances.
// Falls back to in-memory if Supabase is unreachable (defense in depth).

import { supabaseAdmin } from './supabase-admin';

// In-memory fallback — per-instance, but catches rapid-fire from the same Lambda
const fallbackStore = new Map<string, number[]>();
let lastCleanup = Date.now();
const CLEANUP_INTERVAL = 5 * 60_000;

/**
 * Check and record a rate limit hit (SYNCHRONOUS — backward compat).
 * Does both:
 *   1. Immediate in-memory check (same-instance protection)
 *   2. Fire-and-forget Postgres RPC (cross-instance centralized tracking)
 *
 * Existing callers use `if (!checkRateLimit(...))` — this signature is preserved.
 * New callers should prefer `checkRateLimitAsync()` for true cross-instance enforcement.
 *
 * @returns true if allowed, false if rate limited.
 */
export function checkRateLimit(
  key: string,
  maxRequests: number,
  windowMs: number = 60_000
): boolean {
  // Fire-and-forget: record this hit in Postgres for cross-instance visibility
  const windowSeconds = Math.max(1, Math.floor(windowMs / 1000));
  checkRateLimitPostgres(key, maxRequests, windowSeconds).catch(() => {});

  // Synchronous in-memory check (immediate response)
  return checkRateLimitFallback(key, maxRequests, windowMs);
}

/**
 * Async rate limit check using Supabase Postgres RPC.
 * True cross-instance enforcement — every Lambda checks the same centralized state.
 * Falls back to in-memory if RPC fails.
 *
 * New callers should use: `if (!(await checkRateLimitAsync(...))) return 429`
 *
 * @returns true if allowed, false if rate limited.
 */
export async function checkRateLimitAsync(
  key: string,
  maxRequests: number,
  windowSeconds: number = 60
): Promise<boolean> {
  const allowed = await checkRateLimitPostgres(key, maxRequests, windowSeconds);
  if (allowed !== null) return allowed;

  // Postgres unreachable — fall back to in-memory
  return checkRateLimitFallback(key, maxRequests, windowSeconds * 1000);
}

/**
 * Postgres RPC call. Returns true/false, or null if unreachable.
 */
async function checkRateLimitPostgres(
  key: string,
  maxRequests: number,
  windowSeconds: number
): Promise<boolean | null> {
  try {
    const { data, error } = await supabaseAdmin.rpc('check_rate_limit', {
      p_key: key,
      p_max_requests: maxRequests,
      p_window_seconds: windowSeconds,
    });

    if (error) {
      console.warn('[xark-rate-limit] RPC failed, using fallback:', error.message);
      return null;
    }

    return data === true;
  } catch (err) {
    console.warn('[xark-rate-limit] RPC unreachable, using fallback:', err);
    return null;
  }
}

/** In-memory fallback with periodic cleanup */
function checkRateLimitFallback(
  key: string,
  maxRequests: number,
  windowMs: number
): boolean {
  cleanup(windowMs);
  const now = Date.now();
  const timestamps = (fallbackStore.get(key) ?? []).filter(t => now - t < windowMs);
  if (timestamps.length >= maxRequests) return false;
  timestamps.push(now);
  fallbackStore.set(key, timestamps);
  return true;
}

function cleanup(windowMs: number) {
  const now = Date.now();
  if (now - lastCleanup < CLEANUP_INTERVAL) return;
  lastCleanup = now;
  for (const [key, timestamps] of fallbackStore) {
    const fresh = timestamps.filter(t => now - t < windowMs);
    if (fresh.length === 0) {
      fallbackStore.delete(key);
    } else {
      fallbackStore.set(key, fresh);
    }
  }
}
