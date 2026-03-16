# Three-Tier Hybrid Brain — Parked (Mar 17, 2026)

## Status: PARKED — Not working in production. Core app testing takes priority.

## What was built

### Files created (all committed, can be resumed later)

**Tier 1 — Fast-Path Router:**
- `src/lib/local-agent.ts` — Deterministic regex router. Commands: dates, rename, state queries. `tryLocalAgent()` entry point.
- `src/lib/__tests__/local-agent.test.ts` — 13 tests (104 total passing)
- `src/app/api/local-action/route.ts` — Server mutation endpoint. JWT + membership check + supabaseAdmin writes. Atomic: mutation + ledger entry. Upserts spaces.metadata + space_dates.
- `src/components/os/LedgerPill.tsx` — Interactive system pills (icon + actor + verb + [tappable payload] + undo)
- `supabase/migrations/017_hybrid_brain.sql` — space_ledger table (applied to Supabase, confirmed working)

**Tier 2 — E2EE Memory Engine:**
- `src/lib/local-recall.ts` — Recall question detection (`isRecallQuestion()`) + tier-aware coaching whisper
- `src/lib/__tests__/local-recall.test.ts` — 12 tests
- `src/workers/memory-worker.ts` — Web Worker with MiniSearch lexical search, 3s debounce, 1000-msg cap, FIFO eviction, timestamp watermark
- `src/hooks/useLocalMemory.ts` — React hook bridging Worker + IndexedDB blob persistence
- `src/components/os/ContextCard.tsx` — Actionable recall card (Jump to Message + Quote to Group)

**Tier 3 — Cloud Optimizations (partial):**
- `src/lib/intelligence/orchestrator.ts` — `buildStaticPrompt()` / `buildDynamicPrompt()` split. Flash model guard.

### Files modified
- `src/app/space/[id]/page.tsx` — Tier 1/2/3 routing in sendMessage(), ledger Realtime subscription, persistLedger/handleLedgerUndo, feed decrypted messages to Worker, ContextCard + whisper UIs
- `src/components/os/XarkChat.tsx` — Unified timeline (messages + ledger events sorted by timestamp), LedgerPill rendering, msg-id attributes
- `package.json` — Added `minisearch` dependency

### What's NOT working
- Tier 1 commands (`@xark set dates to june 1-5`) — not intercepting properly in production. The sendMessage flow may have integration issues.
- Navigation commands were removed (users swipe instead).

### Design docs (complete, reviewed, approved)
- `docs/superpowers/specs/2026-03-15-three-tier-hybrid-brain-design.md` — Full spec (11 sections, 2 review rounds)
- `docs/superpowers/plans/2026-03-15-three-tier-hybrid-brain.md` — Implementation plan (21 tasks, 4 phases)

### What remains to implement (when resumed)
- Debug why Tier 1 intercept doesn't fire in browser (likely sendMessage flow issue)
- Phase 2b: XChaCha20-Poly1305 encryption for IndexedDB blobs
- Phase 3: transformers.js semantic search (high-tier devices)
- Phase 4: streaming synthesis, multi-action parallel execution, context caching

### Database
- `space_ledger` table exists on Supabase (migration 017 applied successfully)
- All curl tests against `/api/local-action` pass (rename, dates, revert, auth, membership)

### Dependencies
- `minisearch` added to package.json (lexical search library, ~15KB)
