# Xark OS v2.0 — Go-Live Security Tracker

> Created: 2026-03-15. Track all security fixes required before production deployment.

## Status Key
- [ ] Not started
- [x] Fixed

## CRITICAL - check API keys. make sure they are not over userd
---

## CRITICAL (block deployment)

- [x] **1. `message_ciphertexts` INSERT policy too permissive** — Changed `WITH CHECK (true)` to `WITH CHECK (false)`. Client-side inserts now blocked; only service role in `/api/message` can insert. File: `supabase/migrations/014_e2ee.sql:186`. **NOTE: Must re-run migration or apply ALTER on live DB.**

- [x] **2. `distribution_ciphertexts` unbounded + type injection** — Added array cap (100 max), whitelisted fields (id, message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header) with type validation. Spread operator removed. File: `src/app/api/message/route.ts:121-134`

- [x] **3. OTK batch unbounded** — Added 200-key cap, base64 format validation, id length limit (128), public_key length limit (256). Invalid keys return 400. File: `src/app/api/keys/otk/route.ts:19-38`

- [x] **4. No ciphertext size limit** — Added `ciphertext.length > 65536` guard returning 400. File: `src/app/api/message/route.ts:57-59`

- [x] **5. Dev-auto-login missing production guard** — Added `NODE_ENV === 'production' && DEV_MODE !== 'true'` hard block returning 404. Also added explicit `!password` check to prevent undefined comparison. File: `src/app/api/dev-auto-login/route.ts:31-38`

- [x] **6. Password in sessionStorage** — Replaced `sessionStorage.setItem("xark_pass", ...)` with transient module-level variable via `setDevPassword()` export from `useAuth.ts`. Password is never persisted to any browser storage. Files: `src/hooks/useAuth.ts:22,57`, `src/app/login/page.tsx:13,246`

## HIGH (fix before real users)

- [x] **7. Rate limiting is in-memory only** — Created shared `src/lib/rate-limit.ts` with periodic cleanup (purges stale entries every 5 min, prevents unbounded Map growth). Replaced per-file rate limit code in `/api/xark` and `/api/message` with shared `checkRateLimit()`. Still in-memory per-instance — upgrade to Upstash Redis when multi-instance scaling needed.

- [x] **8. No rate limit on key endpoints** — Added `checkRateLimit('keys:${userId}', 20)` (20 req/min per user) to `/api/keys/bundle`, `/api/keys/otk`, `/api/keys/fetch`. Returns 429 when exceeded.

- [x] **9. No rate limit on `/api/join`** — Added IP-based rate limit `checkRateLimit('join:${ip}', 10)` using `x-forwarded-for` header. 10 req/min per IP. Returns 429 when exceeded.

- [x] **10. `/api/keys/fetch` no input validation** — Added: `user_id` must match `/^[a-zA-Z0-9_-]+$/`, `device_id` must be integer 0-255. Returns 400 on invalid input.

- [x] **11. FCM service worker no origin check** — Added `event.origin` and `event.source` validation. Rejects postMessage from foreign origins.

- [x] **12. No CSP headers** — Created `src/middleware.ts` with: Content-Security-Policy (script/style/img/connect/media/worker/frame/object sources), X-Frame-Options DENY, X-Content-Type-Options nosniff, Referrer-Policy strict-origin-when-cross-origin, Permissions-Policy (camera/mic/geo self-only). Applied to all non-static routes.

- [x] **13. `member_logistics` uses `auth.uid()` instead of `auth.jwt()->>'sub'`** — Created `supabase/migrations/016_security_hardening.sql`. Drops and recreates all 4 member_logistics policies (ml_read, ml_update_own, ml_insert, ml_delete_own) with `auth.jwt()->>'sub'`. **Must run migration on live DB.**

- [x] **14. Missing explicit DELETE policy on `decision_items`** — Added `items_delete_blocked` policy with `USING (false)` in migration 016. Also re-creates `mc_insert` with `WITH CHECK (false)` (mirrors critical fix #1 for live DB). **Must run migration on live DB.**

## MEDIUM (production hardening)

- [x] **15. Key bundle field length validation** — Added type + length checks: `identity_key` ≤256, `signed_pre_key` ≤256, `pre_key_sig` ≤512. Returns 400 on invalid. File: `src/app/api/keys/bundle/route.ts:23-27`

- [x] **16. `/api/notify` input validation** — Added: `spaceId` required string, `title` string ≤200, `body` string ≤500. Returns 400 on invalid. File: `src/app/api/notify/route.ts:19-27`

- [x] **17. `/api/xark` payload validation** — Added type checks on `set_dates` payload: `start_date`, `end_date`, `label` must be strings if present. Returns 400 on invalid. File: `src/app/api/xark/route.ts:68-71`

- [x] **18. Error message leakage in `/api/dev-auth`** — RPC `error.message` no longer returned to client. Now returns generic "invalid credentials" (401) or "authentication failed" (500). File: `src/app/api/dev-auth/route.ts:50-56`

- [x] **19. Schedule `purge_expired_xark_messages()`** — Created `/api/cron/purge` endpoint protected by `CRON_SECRET` header. Added `vercel.json` with daily cron at 3 AM UTC. **TODO: Set `CRON_SECRET` env var in Vercel dashboard.** Files: `src/app/api/cron/purge/route.ts`, `vercel.json`

- [x] **20. `supabaseAdmin` null checks** — Added early `if (!supabaseAdmin)` guard returning 500 at top of both `/api/message` and `/api/xark` POST handlers. Removed 5 redundant `if (supabaseAdmin)` wrappers in `/api/xark` (now guaranteed non-null after early guard). Files: `src/app/api/message/route.ts:19-21`, `src/app/api/xark/route.ts:21-23`
