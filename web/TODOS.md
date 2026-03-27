# XARK OS — TODOS

> Deferred work from CEO Plan Review (2026-03-18). Priority: P0 (ship-blocking), P1 (first-week), P2 (first-month).

## P0 — Ship-Blocking

### Deploy CSP Fix
- **What:** Push proxy.ts fix (commit 0f384e3) and verify production works.
- **Why:** Production app is completely broken. Zero users can access it.
- **Effort:** S (CC: 5 min)
- **Status:** Code committed, not deployed.

### Verify All Migrations Applied
- **What:** Confirm all 28 Supabase migrations are applied correctly in production.
- **Why:** Schema drift = silent data errors. Unknown if all migrations ran.
- **Effort:** S (CC: 10 min)

### Set CRON_SECRET
- **What:** Set CRON_SECRET environment variable in Vercel dashboard.
- **Why:** Without it, anyone can trigger /api/cron/purge and /api/cron/consensus.
- **Effort:** S (human: 2 min)

## P1 — First Week

### Error Tracking (Sentry)
- **What:** Install @sentry/nextjs. Configure DSN. Catch unhandled errors, crypto failures, API timeouts.
- **Why:** Zero observability means blind debugging. Custom crypto + 3-tier AI + external APIs = many silent failure modes.
- **Context:** The CSP disaster was invisible until QA tested manually. With Sentry, it would have been caught on first deploy.
- **Effort:** M → S with CC (~15 min)

### CI/CD Test Gate
- **What:** GitHub Actions workflow: run vitest on every push to main. Block Vercel deploy on test failure.
- **Why:** Prevents deploying broken code. The CSP issue was committed and deployed without any automated verification.
- **Context:** 119 tests exist but only run locally. Every push to main auto-deploys to production.
- **Effort:** S (CC: 5 min)

### E2EE Key Backup UX
- **What:** Build backup/restore UI using existing Argon2id crypto code. Prompt after first E2EE message.
- **Why:** Keys live only in IndexedDB. Clear browser data = permanent message loss. No recovery flow exists.
- **Context:** The Argon2id backup code exists in key-manager.ts. The missing piece is the UI (prompt, password input, restore flow).
- **Effort:** M → S with CC (~30 min)
- **Depends on:** WebAuthn PRF (optional enhancement — can ship with password prompt first)

### Firebase OTP Error UX
- **What:** Improve error messages when Firebase Auth fails. Show "Phone verification unavailable" instead of cryptic errors.
- **Why:** If Firebase is down or misconfigured, users get unhelpful "could not send code" errors.
- **Effort:** S (CC: 10 min)

### Non-Atomic DB Operations
- **What:** Wrap /api/message (message + ciphertext), /api/join (user + space_members + use_count) in Postgres transactions. Create RPCs like `atomic_insert_message` and `atomic_join_space`.
- **Why:** If ciphertext insert fails after message insert succeeds, rollback can also fail → orphaned message envelopes. In /api/join, if use_count update fails, invite can be replayed.
- **Context:** Architecture scan found 3 API routes with multi-step DB ops that aren't atomic. The message/route.ts rollback at L101 can itself fail silently.
- **Effort:** M → S with CC (~20 min)

### Apify Timeout Guard
- **What:** Add explicit 40s timeout wrapper on Apify actor calls. Reduce maxDuration from 60s to 50s on /api/xark.
- **Why:** Intent parse (45s) + Apify (40s) + retry (45s) = 130s possible, far exceeding 60s Lambda timeout. Hard timeout = 500 error to user.
- **Context:** apify-client.ts L29 has no timeout. Self-healing retry in orchestrator doubles the window.
- **Effort:** S (CC: 10 min)

## P2 — First Month

### Pexels API Key Proxy
- **What:** Move NEXT_PUBLIC_PEXELS_KEY to server-side /api/photos route.
- **Why:** API key is currently exposed in client bundle. Low risk (free API with rate limits) but bad practice.
- **Effort:** S (CC: 15 min)

### WebAuthn PRF Biometric Unlock
- **What:** Replace Argon2id password prompt with WebAuthn PRF for encrypted store unlock.
- **Why:** Password prompt on every session is friction. Biometric (Face ID/fingerprint) is the target UX.
- **Effort:** L → M with CC (~1 hour)
- **Depends on:** Browser support (Chrome 118+, Safari 18+)

### Key Rotation on Member Leave
- **What:** When a member leaves a space, rotate Sender Keys for remaining members.
- **Why:** Departed members retain old Sender Keys and could theoretically decrypt future messages.
- **Effort:** L → M with CC
- **Depends on:** E2EE key distribution pipeline working reliably first

### Integration Tests
- **What:** Add tests for: login flow, send/receive message, invite join, reaction voting, AI search.
- **Why:** 119 tests exist but all are unit tests for crypto/taste. Zero tests verify end-to-end flows.
- **Effort:** M → S with CC (~30 min)

### Cross-Space Awareness (Tier 3)
- **What:** Deterministic date overlap check for cross-space coordination.
- **Why:** Users planning multiple trips need to see conflicts.
- **Effort:** M → S with CC

### Structured Memory
- **What:** Save Gold Burst moments (finalized decisions) to user profile.
- **Why:** Users should be able to look back at past decisions.
- **Effort:** M → S with CC

### Whisper Engine Batching
- **What:** Batch whisper engine sequential queries into a single RPC.
- **Why:** Performance — currently makes multiple sequential Supabase queries.
- **Effort:** S (CC: 15 min)

### geminiSearchGrounded JSON Fix
- **What:** Switch from regex JSON extraction to responseMimeType: "application/json".
- **Why:** Regex parsing is fragile. Native JSON mode is more reliable.
- **Effort:** S (CC: 10 min)
