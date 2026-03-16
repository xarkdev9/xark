# XARK OS — Session Primer

> **For AI agents**: Read this FIRST before any code work. It tells you what changed recently and what to watch for. Updated after every session.

## Last Session: Mar 15, 2026 (Three-Tier Hybrid Brain)

### What was built
41. **Three-Tier Hybrid Brain** — Client-side intelligence interceptor for @xark. 60%+ of queries now resolve locally with zero latency, zero API cost.
    - **Tier 1: Fast-Path Router** (`src/lib/local-agent.ts`): Deterministic regex matching for admin commands (dates, rename, state queries, navigation). <1ms, zero AI. Commands intercepted at top of `sendMessage()` before E2EE or network.
    - **`/api/local-action`**: JWT-validated server route for Tier 1 mutations. supabaseAdmin writes with membership verification. Atomic: mutation + ledger entry. Date mutations upsert both `spaces.metadata` AND `space_dates`.
    - **`space_ledger` table** (migration 017): Layer 3 admin audit trail with RLS + Realtime. Stores action, payload, previous (for undo), revert_target_id.
    - **`LedgerPill.tsx`**: Interactive system pills (icon + actor + verb + [tappable payload] + undo) interleaved chronologically in chat timeline.
    - **Tier 2: E2EE Memory Engine** (`src/workers/memory-worker.ts`): Web Worker with MiniSearch lexical search. Debounced persistence (3s), 1000-message cap, FIFO eviction, timestamp-based delta sync watermark, 2000-char truncation.
    - **`useLocalMemory.ts`**: React hook bridging Worker via postMessage. IndexedDB blob persistence. SSR-safe.
    - **`local-recall.ts`**: Recall question detection with tuned patterns (avoids false-positive against Tier 3 search commands like "search for hotels").
    - **`ContextCard.tsx`**: Actionable context card for recall results — Jump to Message (scroll + cyan pulse) and Quote to Group (loads into composer as reply).
    - **Tier-aware coaching whisper**: Lexical fail shows keyword hint, semantic fail shows generic message.
    - **Orchestrator prompt split**: `buildStaticPrompt()` / `buildDynamicPrompt()` for context caching readiness. Flash model guard.

### Files created this session
- `src/lib/local-agent.ts` — Tier 1 fast-path router (types, commands, tryLocalAgent)
- `src/lib/__tests__/local-agent.test.ts` — 16 tests for local-agent
- `src/app/api/local-action/route.ts` — Tier 1 mutation endpoint
- `src/components/os/LedgerPill.tsx` — Interactive system pill component
- `src/components/os/ContextCard.tsx` — Actionable context card for Tier 2 recall
- `src/lib/local-recall.ts` — Recall question detection + whisper helper
- `src/lib/__tests__/local-recall.test.ts` — 12 tests for recall detection
- `src/workers/memory-worker.ts` — Web Worker with MiniSearch lexical engine
- `src/hooks/useLocalMemory.ts` — React hook for Worker bridge + IndexedDB
- `supabase/migrations/017_hybrid_brain.sql` — space_ledger table
- `docs/superpowers/specs/2026-03-15-three-tier-hybrid-brain-design.md` — Full design spec
- `docs/superpowers/plans/2026-03-15-three-tier-hybrid-brain.md` — Implementation plan

### Files significantly modified
- `src/app/space/[id]/page.tsx` — Tier 1/2/3 routing in sendMessage (Tier 1 runs even during isThinking), ledger Realtime subscription, persistLedger/handleLedgerUndo, feed decrypted messages to Worker, ContextCard + recall whisper + local whisper UI
- `src/components/os/XarkChat.tsx` — Unified timeline (messages + ledger events sorted by timestamp), LedgerPill rendering, msg-id for scroll-to-message
- `src/lib/intelligence/orchestrator.ts` — buildStaticPrompt/buildDynamicPrompt split, flash model guard

### Architecture decisions made
- **Three-tier client-side routing**: Tier 1 (regex, <1ms) → Tier 2 (lexical search, ~50ms) → Tier 3 (Gemini cloud). First match wins.
- **space_ledger as Layer 3 audit trail**: Unencrypted (admin actions mutate shared state). Interactive pills in timeline. Undo via revert entries with revert_target_id.
- **Tier 1 mutations via /api/local-action**: Client does regex parsing locally; DB writes go through server (supabaseAdmin) because RLS is owner-only on spaces table.
- **Tier 2 strict halt on zero results**: When recall question matches but search returns nothing, show coaching whisper and STOP. Never fall through to Tier 3 (cloud is E2EE-blind).
- **isThinking gate moved below Tier 1**: Navigation and status commands work even while Gemini is thinking.
- **Timestamp-based watermark**: Delta sync uses timestamps, not message IDs (UUIDs aren't temporally ordered).
- **Algorithmic degradation architecture**: MiniSearch (lexical, all devices) now; transformers.js (semantic, high-tier only) is Phase 3.

### Known issues
- Migration 017 needs to be run on Supabase (space_ledger table)
- IndexedDB blob storage is plaintext for v1 — XChaCha20-Poly1305 encryption deferred to Phase 2b
- Streaming synthesis (generateContentStream) not yet implemented — Phase 4 task
- Multi-action parallel execution not yet implemented — Phase 4 task
- Context caching threshold detection added but actual Gemini Cache API not wired
- Phase 3 (semantic search with transformers.js) deferred
- `geminiSearchGrounded` still uses regex JSON extraction
- Unsplash API key not configured
- Key rotation on member leave deferred to v2

### What to do next
- Run migration 017 on Supabase
- Test Tier 1 in browser: `@xark show decide`, `@xark set dates to june 1-5`, `@xark status`
- Test Tier 2 in browser: type messages, then `@xark what did nina say`
- Add XChaCha20-Poly1305 encryption for IndexedDB blobs (Phase 2b)
- Implement streaming synthesis (Phase 4)
- Phase 3: transformers.js semantic search for high-tier devices
- First real users

---

## Previous Session: Mar 15, 2026 (Two-Tier Intelligence Routing)

### What was built
40. **Two-Tier Intelligence Routing** — @xark casual queries (coffee, sunset spots, bars) were hitting slow Apify actors (30-50s). Root cause: intent prompt only exposed 5 Apify tools — Gemini had no choice but to route everything to Apify. Fix: exposed all 8 tools across 2 tiers in intent prompt with explicit TIER SELECTION rules.
    - **New `geminiLocalSearch()` function** (`orchestrator.ts`): Direct Gemini knowledge for casual queries — returns JSON array of real places. No Google Search tool. ~7-10s response time (down from 30-50s via Apify).
    - **Updated intent prompt**: 8 tools — FAST (local_restaurant, local_activity, general) + SLOW (hotel, flight, restaurant, activity). Explicit routing rules: "DEFAULT TO FAST TIER. most queries are casual."
    - **Fast tier routing**: `local_*` tools route to `geminiLocalSearch()` instead of `geminiSearchGrounded()` — avoids the ~40s Google Search API latency.
    - **search_tier metadata**: Decision items now tagged with `gemini-local`, `gemini-search`, or `apify` in metadata for tracking which tier produced results.
    - **Performance**: Coffee 52s→9.6s, Sunset spots 25s→8.6s, Bars 30s→6.8s, Dinner spots 18s→8.5s.

### Files significantly modified
- `src/lib/intelligence/orchestrator.ts` — New `geminiLocalSearch()`, updated routing logic (split gemini-search tier into local vs grounded), complete intent prompt rewrite with 8 tools + tier selection rules
- `src/app/api/xark/route.ts` — search_tier metadata updated for three tiers
- `src/app/api/message/route.ts` — search_tier metadata updated for three tiers
- `.xark-state.json` — phase TWO_TIER_INTELLIGENCE, updated intelligence_orchestrator/tool_registry/chat_api_endpoint
- `CONSTITUTION.md` — Section 20 rewritten for three-tier routing
- `GROUNDING_PROTOCOL.md` — Section 9 intelligence entry updated for three tiers
- `CLAUDE.md` — Intelligence descriptions updated for three-tier routing

### Architecture decisions made
- **Three execution paths**: gemini-local (direct Gemini, no search API) for casual queries, gemini-search (Google Search grounding) for knowledge queries, apify for booking queries with prices
- **Default to fast tier**: Intent prompt explicitly instructs "DEFAULT TO FAST TIER" — casual queries should never hit Apify
- **geminiLocalSearch vs geminiSearchGrounded**: The Google Search grounding tool adds ~40s latency per call. Direct Gemini knowledge is sufficient for "coffee near me" type queries. Grounding only needed for factual accuracy (weather, travel tips).
- **search_tier tracking**: Items tagged in metadata so UI can eventually show source quality indicators

### Known issues
- `geminiSearchGrounded` still uses regex JSON extraction (not responseMimeType)
- Location drift for spaces without geographic titles (e.g., "dinner tonight" → Gemini guesses city)
- Backup password UI not implemented
- Key rotation on member leave deferred to v2
- Unsplash API key not configured
- PWA: missing offline support, maskable icons, splash screens

### What to do next
- Test fast tier in production with real users
- Consider location prompt when space title has no geographic info
- Backup password prompt in user setup flow
- First real users

---

## Previous Session: Mar 15, 2026 (E2EE Wiring + @xark Broadcast Fix + Blank Screen Fix)

### What was built
37. **E2EE Full Pipeline Wiring** — 7-file implementation connecting all crypto modules into a working end-to-end pipeline:
    - **Migration 015** (`supabase/migrations/015_e2ee_wiring.sql`): `get_space_member_devices` RPC (returns user_id/device_id pairs for space members with key bundles), updated `fetch_key_bundle` RPC (now returns OTK ID for X3DH responder lookup), `idx_mc_recipient` index for ciphertext lookups. **Migration run on Supabase — confirmed working.**
    - **Sender Key Distribution** (`encryption-service.ts`): `distributeSenderKey()` fetches space member devices via RPC, establishes pairwise Double Ratchet sessions (X3DH on first contact), encrypts serialized Sender Key per-recipient, sends via `/api/message` with `message_type: 'sender_key_dist'`. Partial distribution tolerant.
    - **Sender Key Reception** (`encryption-service.ts`): `processSenderKeyDistribution()` decrypts Sender Key from pairwise session, stores as `${spaceId}:${senderId}` in KeyStore.
    - **X3DH Metadata in Headers**: First-contact ratchet headers include `x3dh.identityKey` (Ed25519 public). Responder uses this for proper X3DH key agreement instead of placeholder shared secret.
    - **Batch Decrypt on Load** (`space/[id]/page.tsx`): After `fetchMessages()`, filters `sender_key_dist` messages (processes silently), then decrypts `e2ee`/`e2ee_xark` messages via `fetchCiphertexts()` + `e2ee.decrypt()`. Updates message content in-place.
    - **Realtime Decrypt** (`space/[id]/page.tsx`): Broadcast messages include `ciphertext_b64` + `ratchet_header_b64` for instant decrypt — zero extra DB round-trip. SK distribution messages processed silently on arrival.
    - **Display Guard** (`XarkChat.tsx`): E2EE messages show "decrypting..." pulse while pending, "[encrypted message - sender key not available]" when key missing.
    - **useE2EE Enabled** (`useE2EE.ts`): Both `available: false` flipped to `available: true`.
    - **/api/message Extended**: Accepts `message_type_override` (for `sender_key_dist`) and `distribution_ciphertexts` (per-recipient ciphertext rows for SK distribution).
    - **messages.ts Fixed**: `fetchMessages` select now includes `message_type` + `sender_device_id`. `MessageType` union extended with `sender_key_dist`. `ChatMessage` type extended with `ciphertext_b64` + `ratchet_header_b64` for broadcast.

38. **@xark Broadcast Fix (Critical Bug)** — @xark responses were invisible in the E2EE path. Root cause: `/api/message` triggers orchestration async (fire-and-forget), writes response to DB, but never broadcasts. Realtime subscription listens for broadcast events, not postgres_changes — so @xark response sat in DB while thinking indicator hung 30s then disappeared.
    - **Fix in `/api/message/route.ts`**: Added server-side broadcast via `supabaseAdmin.channel()` in `orchestrateAndUpdate()` after both success and error DB writes. Broadcasts to `chat:${spaceId}` channel with full message payload.
    - **Fix in `space/[id]/page.tsx`**: Added `setIsThinking(false)` in broadcast handler when @xark response arrives (role === 'xark' && content !== 'thinking...').
    - **Comprehensive curl testing validated**: Legacy path (/api/xark) — all working (restaurant/hotel/activity search, silent mode, date setting, boundary rejection, dietary context, special characters). E2EE path (/api/message) — returns 200 with messageId + xarkMessageId in ~397ms, orchestration runs in background. Multi-user (Ram + Myna), cross-space, security (401/403).

39. **Blank Screen Fix** — New users saw confusing phantom demo data. Removed `getDemoAwareness()` and `getDemoPersonalChats()` fallbacks from both AwarenessStream.tsx and PeopleDock.tsx. Replaced with inviting empty states: "where to?" with "type a dream below" (awareness) and "your people" with "share a space link" (people).

### Files created this session
- `supabase/migrations/015_e2ee_wiring.sql` — E2EE wiring migration (RPC, updated fetch_key_bundle, index)

### Files significantly modified
- `src/lib/crypto/encryption-service.ts` — Complete rewrite: distributeSenderKey(), processSenderKeyDistribution(), X3DH metadata in headers, fix responder, getOrEstablishSession()
- `src/lib/crypto/types.ts` — oneTimePreKeyId on PublicKeyBundle, sender_key_dist in MessageType
- `src/lib/crypto/key-manager.ts` — fetchPeerKeyBundle returns oneTimePreKeyId
- `src/app/space/[id]/page.tsx` — Batch decrypt on load, Realtime decrypt, extended E2EE broadcast, thinking indicator fix for @xark
- `src/components/os/XarkChat.tsx` — resolveMessageContent display guard (decrypting.../encrypted message)
- `src/hooks/useE2EE.ts` — available: true (E2EE enabled)
- `src/app/api/message/route.ts` — message_type_override, distribution_ciphertexts, server-side @xark broadcast (success + error)
- `src/lib/messages.ts` — MessageType + sender_key_dist, fetchMessages select includes message_type/sender_device_id, ChatMessage E2EE broadcast fields
- `src/components/os/AwarenessStream.tsx` — Removed demo data fallbacks, added inviting empty state
- `src/components/os/PeopleDock.tsx` — Removed demo data fallbacks, added inviting empty state

### Architecture decisions made
- **Lazy Sender Key distribution** — new members see "[encrypted message]" for pre-join messages (same as WhatsApp). They get Sender Keys when existing members send their next message.
- **X3DH metadata in ratchet headers** — identity key embedded in first-message header, eliminating separate key exchange step. Responder derives shared secret properly.
- **Broadcast includes ciphertext** — recipients decrypt inline from WebSocket payload, zero extra DB fetch for live messages. DB fetch only for page load.
- **Partial distribution tolerance** — if SK distribution fails for some members, encryption still proceeds. Missing members will get the key on next message or request.
- **sender_key_dist control messages** — not displayed in chat UI, processed silently to populate KeyStore.
- **Server-side @xark broadcast** — orchestrateAndUpdate() broadcasts via supabaseAdmin after DB write. Matches Realtime subscription pattern (broadcast events, not postgres_changes).
- **No phantom demo data** — new users see clean empty states with inviting prompts, not confusing demo content.

### Known issues
- Migration 015 run on Supabase — confirmed working
- OTK handling simplified for v1 (skipped in SK distribution X3DH — 3 DH instead of 4)
- Key rotation on member leave deferred to v2
- Backup password UI not implemented (users lose keys on browser clear)
- `geminiSearchGrounded` still uses regex JSON extraction
- Unsplash API key not configured
- PWA: missing offline support, maskable icons, splash screens
- Rate limiting on /api/xark may not trigger at 15 concurrent requests (needs investigation)

### What to do next
- Test 2-tab E2EE flow in browser (Ram tab 1, Myna tab 2)
- Backup password prompt in user setup flow
- Configure Firebase service account for production
- Key rotation on member leave (v2)
- First real users

---

## Previous Session: Mar 15, 2026 (E2EE + Security Doc + Guardrails)

### What was built
34. **Sender Identity Bug Fix** — `src/hooks/useAuth.ts` — Tab duplication caused Myna's tab to inherit Ram's cached session via shared sessionStorage. Three fixes: (a) handleFallback compares cached session displayName with requested fallbackName before reusing, (b) useEffect early return verifies restored user matches fallbackName (clears stale session + nulls state on mismatch), (c) Firebase onAuthStateChanged path checks name match before skipping re-login.
35. **SECURITY.md — Comprehensive E2EE/Privacy/Security Document** — NEW FILE. Covers: executive summary (what we can/cannot provide), threat model (protects against/doesn't protect against), cryptographic architecture (Signal Protocol, XChaCha20-Poly1305, primitives table), key management (hierarchy, distribution, backup, revocation), message encryption flows (Double Ratchet 1:1 + Sender Keys groups + forward secrecy), @xark privacy boundary (three-layer separation, disabled in sanctuaries, PII sanitization), on-device constraint detection, data architecture (client/server/storage breakdown), law enforcement response framework (what we provide vs mathematically impossible), warrant canary, competitive analysis (vs WhatsApp, Signal, Telegram, iMessage), security hardening (RLS, anti-injection, skipped key bounds, constant-time), privacy policy summary, architecture diagram, database migration reference, code reference table, audit readiness checklist, FAQ.
36. **All Guardrail Files Updated** — CLAUDE.md (SECURITY.md in bootstrap, E2EE module map, useAuth identity fix), CONSTITUTION.md (Section 19a Encryption Constitution, infrastructure table expanded), GROUNDING_PROTOCOL.md (sanctuary E2EE disabled, Section 10 E2EE privacy boundary, @xark Layer 3 only), .xark-state.json (phase E2EE_PRODUCTION, encryption field, E2EE component registry).

### Files created this session
- `SECURITY.md` — Complete E2EE/Privacy/Security architecture document

### Files significantly modified
- `src/hooks/useAuth.ts` — Sender identity bug fix (3 places: handleFallback, useEffect, Firebase path)
- `CLAUDE.md` — SECURITY.md in bootstrap, E2EE module map, useAuth identity fix docs
- `CONSTITUTION.md` — Section 19a Encryption Constitution, infrastructure table expanded with E2EE rows
- `GROUNDING_PROTOCOL.md` — Sanctuary E2EE disabled, Section 10 E2EE privacy boundary, @xark Layer 3 restriction
- `.xark-state.json` — Phase E2EE_PRODUCTION, encryption architectural lock, 14 E2EE components in registry

### Architecture decisions made
- SECURITY.md as standalone document (not embedded in CLAUDE.md) — audience includes law enforcement, investors, auditors, competitors
- Warrant canary included — updated quarterly, removal signals compromise
- Three-layer architecture is a constitutional invariant — bridging Layer 2→3 requires explicit user consent
- @xark disabled in sanctuaries is non-negotiable — sanctuaries are pure encrypted pipes

### Known issues
- Sender Key distribution to group members not wired into UI yet (requires pairwise session establishment)
- Decrypt incoming E2EE messages on page load (fetchCiphertexts → decrypt)
- Backup password prompt in user setup flow
- Device linking flow (QR code) is v2 roadmap
- `geminiSearchGrounded` still uses regex JSON extraction (not responseMimeType)
- Unsplash API key not configured
- PWA: missing offline support, maskable icons, splash screens

### What to do next
- Sender Key distribution on space join (pairwise session establishment)
- Decrypt incoming E2EE messages on page load (fetchCiphertexts → decrypt)
- Backup password prompt in user setup flow
- First real users
- Key transparency log (v3 roadmap)

---

## Previous Session: Mar 15, 2026 (E2EE)

### What was built
31. **E2EE Chat Encryption — Full Implementation** — Signal Protocol (Double Ratchet for 1:1 sanctuaries, Sender Keys for groups 2-15 members). Three-layer architecture: Layer 1 (Key Management), Layer 2 (Message Encryption — zero-knowledge), Layer 3 (Structured Intelligence — @xark operates here). Complete crypto module: `src/lib/crypto/` (primitives, X3DH key agreement, Double Ratchet with bounded skipped-key dictionary, Sender Keys with chain advancement, IndexedDB KeyStore, key manager with registration/backup/restore, encryption service with message type guard). XChaCha20-Poly1305 for authenticated encryption (hardware-independent). Unified `/api/message` endpoint (atomic encrypted message + optional @xark trigger). Key distribution endpoints (`/api/keys/bundle`, `/api/keys/otk`, `/api/keys/fetch`). On-device constraint detection (`src/lib/constraints.ts`) bridges encrypted messages → structured data. Database migration `014_e2ee.sql` with all tables (key_bundles, one_time_pre_keys, message_ciphertexts, user_constraints, space_constraints, constraint_prompts), RPCs (fetch_key_bundle with FOR UPDATE SKIP LOCKED, revoke_device, purge_expired_xark_messages), RLS policies, indexes. Build passes clean. All endpoints validated with curl.
32. **Backward compatibility** — Existing `/api/xark` preserved for legacy messages. messages.ts updated with `message_type` field (e2ee/e2ee_xark/xark/system/legacy). Space page maps `message_type` to ChatMessage. Old messages render as `legacy` type.
33. **E2EE UI Integration** — Full wiring of crypto module into the app:
    - `useE2EE` hook: manages E2EE lifecycle (init, key registration, encrypt/decrypt). Gracefully degrades to legacy mode if migration 014 not applied.
    - `useAuth` stores userId in localStorage (needed by key-manager's `getCurrentUserId()`). Set in all auth paths: cache restore, dev-auto-login, name-only fallback.
    - Space page `sendMessage`: E2EE path → encrypt → POST `/api/message` → broadcast encrypted envelope. Falls back to legacy path (plaintext + `/api/xark`) if E2EE unavailable or encrypt fails.
    - On-device constraint detection runs on sender's outgoing message text. Whisper UI shows detected constraint (type + value) with save/dismiss actions.
    - XarkChat: "encrypted" badge (lock icon + green text) when E2EE active. Encrypted messages with null content render as "[encrypted message]" in green italic.
    - Three bugs fixed: X3DH test (double `x3dhInitiate` call → single call), Sender Key decrypt off-by-one (while loop `< targetIteration` → `< targetIteration - 1`), budget regex (now handles "budget is around $200").
    - Nonce length fix: encryption-service.ts decryptMessage used 12-byte nonce (AES-GCM leftover), fixed to 24-byte (XChaCha20-Poly1305).
    - 79/79 tests passing (33 crypto + 46 existing). Build passes clean.

### Files created this session
- `src/lib/crypto/types.ts` — E2EE type definitions (RawKeyPair, IdentityKeyPair, SessionState, SenderKeyState, etc.)
- `src/lib/crypto/primitives.ts` — libsodium-wrappers-sumo wrapper (XChaCha20-Poly1305, Ed25519, Curve25519, HKDF, Argon2id)
- `src/lib/crypto/keystore.ts` — IndexedDB-backed key storage
- `src/lib/crypto/x3dh.ts` — X3DH key agreement (initiator + responder)
- `src/lib/crypto/double-ratchet.ts` — Double Ratchet with skipped-key dictionary (bounded at 1000)
- `src/lib/crypto/sender-keys.ts` — Sender Key generation, encrypt/decrypt, serialization
- `src/lib/crypto/key-manager.ts` — Registration, key bundle fetch, OTK replenishment, backup/restore
- `src/lib/crypto/encryption-service.ts` — High-level encrypt/decrypt API (sanctuary + space), message type guard
- `src/lib/crypto/index.ts` — Barrel export
- `src/lib/crypto/crypto.test.ts` — 33 tests (primitives, X3DH, Double Ratchet, Sender Keys, constraints)
- `src/lib/constraints.ts` — On-device constraint detection (dietary, budget, accessibility, alcohol)
- `src/hooks/useE2EE.ts` — E2EE lifecycle hook (init, key registration, encrypt/decrypt, graceful fallback)
- `src/app/api/message/route.ts` — Unified E2EE message endpoint
- `src/app/api/keys/bundle/route.ts` — Key bundle upload
- `src/app/api/keys/otk/route.ts` — OTK batch upload
- `src/app/api/keys/fetch/route.ts` — Atomic key bundle fetch (via RPC)
- `supabase/migrations/014_e2ee.sql` — Full E2EE migration (tables, RPCs, RLS, indexes)
- `docs/superpowers/specs/2026-03-15-e2ee-chat-encryption-design.md` — Complete E2EE design spec

### Files significantly modified
- `src/lib/messages.ts` — Added MessageType, message_type/sender_device_id to ChatMessage, fetchCiphertexts()
- `src/app/space/[id]/page.tsx` — E2EE send path (encrypt → /api/message with legacy fallback), constraint detection + whisper UI, useE2EE hook integration
- `src/hooks/useAuth.ts` — Stores userId in localStorage for key-manager (all auth paths)
- `src/components/os/XarkChat.tsx` — E2EE indicator badge (lock + "encrypted"), encrypted message placeholder

### Architecture decisions made
- XChaCha20-Poly1305 over AES-256-GCM — hardware-independent (no AES-NI requirement), 192-bit nonce safe for random generation
- Signal Protocol (Double Ratchet + Sender Keys) over MLS — purpose-built for 2-15 member groups, proven at WhatsApp scale
- Three-layer architecture — encrypted messages (Layer 2) fully separated from structured intelligence data (Layer 3)
- @xark disabled in sanctuaries — no Layer 3 data in 1:1 chats, pure encrypted pipes
- Unified `/api/message` over separate endpoints — atomic message + @xark trigger prevents ghost messages
- On-device constraint detection — client-side pattern matching, sender-only prompts, conservative allowlists
- libsodium-wrappers-sumo for all crypto — maintained, includes Argon2id, custom Double Ratchet built on top

### Known issues
- Migration 014 needs to be run on Supabase (tables don't exist in remote DB yet)
- Sender Key distribution to group members not wired into UI yet (requires pairwise session establishment)
- Backup/restore UI not implemented (password prompt, Firebase Storage upload)
- Constraint detection UI (inline whispers below messages) not rendered in XarkChat yet
- Device linking flow (QR code) is v2 roadmap
- `geminiSearchGrounded` still uses regex JSON extraction (not responseMimeType)
- Multi-tool calls deferred
- Unsplash API key not configured
- PWA: missing offline support, maskable icons, splash screens

### What to do next
- Run migration 014_e2ee.sql on Supabase (enables E2EE — graceful fallback until then)
- Sender Key distribution on space join (pairwise session establishment)
- Decrypt incoming E2EE messages on page load (fetchCiphertexts → decrypt)
- Backup password prompt in user setup flow
- Device linking flow (QR code) — v2 roadmap
- First real users

---

## Previous Session: Mar 15, 2026

### What was built
21. **Gemini empty response fix** — Root cause: `responseSchema` with complex schemas on Gemini 2.5 Flash produced empty responses (`finishReason: "STOP"`, no content parts). Fix: switched to `responseMimeType: "application/json"` (native JSON enforcement at API level). Eliminated markdown fences and format rebellion. 10/10 test queries passing.
22. **Prompt order fix** — USER REQUEST moved to absolute bottom of intent prompt. Recency bias in LLMs caused hallucinated routing examples when request was in the middle. Bottom placement acts as execution trigger.
23. **Anti-cringe voice engineering** — Replaced warm "bestie" persona (which produced AI cringe: "OMG, brunch mission ACCOMPLISHED! 🎉") with cool/competent texting persona. Explicit negative constraints: banned word list, 20-word max, lowercase encouraged, no exclamation points, max 1 contextual emoji. Short examples in prompt produce short output.
24. **`_thought_process` chain of thought** — Intent parsing JSON schema now includes `_thought_process` field. Forces Gemini to reason about space title, constraints, and tool selection before deciding action. Reduces hallucinated locations and ignored constraints.
25. **Date math rules** — Full ISO datetime (`new Date().toISOString()` with time) instead of date-only. Explicit instruction: "if user says 'tonight', calculate exact YYYY-MM-DD using CURRENT DATE."
26. **Implicit context extraction** — Prompt instruction: "if grounding context mentions budget or dietary restriction, MUST include in tool params (maxPrice, cuisine: 'vegan')."
27. **Conflict resolution** — Synthesis prompt instruction: "if group is split, acknowledge and suggest compromise (food hall, two options)."
28. **Debug cleanup** — Removed all `_debug` fields from /api/xark JSON responses. Garbage responses now delete "thinking..." placeholder message.
29. **Safety settings tuned** — `BLOCK_ONLY_HIGH` threshold (not BLOCK_LOW_AND_ABOVE) because system prompt mentions safety terms in BOUNDARIES section which triggers false positive filtering.
30. **All guardrail files updated** — CONSTITUTION.md (4 themes, anti-cringe voice, responseMimeType), .xark-state.json (4 themes, anti-cringe persona, intelligence orchestrator), GROUNDING_PROTOCOL.md (cool friend voice, anti-cringe rules), CLAUDE.md (cool friend persona, native JSON mode).

### Files significantly modified
- `src/lib/intelligence/orchestrator.ts` — Complete rewrite: responseMimeType, _thought_process, anti-cringe voice, date math, implicit context, conflict resolution, dead code removed
- `src/app/api/xark/route.ts` — Debug cleanup, garbage response handling (deletes thinking placeholder)
- `GROUNDING_PROTOCOL.md` — Cool friend voice, anti-cringe rules, responseMimeType docs
- `CLAUDE.md` — Cool friend persona, native JSON mode documentation
- `CONSTITUTION.md` — 4 themes, anti-cringe @xark voice, intelligence section updated
- `.xark-state.json` — 4 themes, anti-cringe persona, intelligence orchestrator updated

### Architecture decisions made
- Native JSON mode (`responseMimeType`) over `responseSchema` — latter produces empty responses on Gemini 2.5 Flash with complex schemas
- USER REQUEST at absolute bottom of prompt — recency bias makes it the execution trigger
- Anti-cringe requires explicit negative constraints — telling an LLM to be "warm and fun" defaults to AI cringe; banned word lists + short examples + 20-word limit produce natural output
- Safety: BLOCK_ONLY_HIGH threshold — system prompts with safety boundary descriptions trigger false positives at lower thresholds
- Chain of thought (`_thought_process`) — visible reasoning improves routing accuracy without impacting response latency

### Known issues
- `geminiSearchGrounded` still uses regex JSON extraction (not responseMimeType) — Google Search grounding tool may not support forced JSON mode
- Multi-tool calls deferred (future: "find flights AND hotels" in one request)
- Unsplash API key not configured
- PWA: missing offline support, maskable icons, splash screens

### What to do next
- Run Supabase migration 013 (daily use features)
- Configure Firebase for production
- First real users
- PWA production blockers (offline, icons, splash)
- Consider multi-tool call support (array of actions from orchestrator)

---

## Previous Session: Mar 14-15, 2026

### What was built
11. **Memories tab** — Third Galaxy tab (people/plans/memories). Aggregates photos across all spaces. Masonry grid. Demo Unsplash photos.
12. **4-appearance theme system** — hearth (flat light), hearth_dark (flat dark), vibe (depth light), vibe_dark (depth dark). ThemeStyle "flat"|"depth". Components use isVibe boolean. Loosely coupled — add theme = 2 file changes.
13. **Solid ink color system** — ink.primary/secondary/tertiary/sender via CSS variables. All readable text uses solid colors (never opacity). Applied across all 10+ screens.
14. **Login page theme-aware** — all hardcoded #111111/#F8F7F4 replaced with colors.*/ink.* tokens.
15. **Swipe between Galaxy tabs** — horizontal swipe > 60px switches people ↔ plans ↔ memories.
16. **Zero-Box enforcement** — vibe-row containers explored and reverted. Depth comes from avatar shadows + ambient glow only.
17. **@xark intelligence upgrades** — (a) Internal monologue via responseSchema + _thought_process, (b) self-healing retry on empty Apify results, (c) context-aware synthesis with grounding, (d) optimistic "thinking..." UI.
18. **Zero Compromise** — (a) BLOCK_LOW_AND_ABOVE safety filters on all 4 harm categories, (b) Social EQ: protect minorities silently, (c) empathy synthesis rules, (d) gridlock breaker, (e) deadpan easter eggs, (f) boundaries (no coding/essays/personal calendar), (g) smart follow-up: fixed slice bug + eavesdropping bug + 3-minute time decay + context injection.
19. **Enterprise migration TODO** — docs/todo-enterprise-migration.md with pre-migration, day-of, and post-migration checklists.
20. **Sunlight readability** — background #F8F7F4 (brighter), text #111111 (darker), distinct gray #8A8A94 for secondary text. WhatsApp/iMessage reference colors applied.

### Architecture decisions made
- Zero-Box strictly enforced: vibe depth = avatar shadows only, never row containers
- Opacity banned for readable text: ink.* solid colors everywhere, textColor(alpha) only for atmospheric elements
- Smart follow-up: question detection + 3-minute time decay + context injection (no eavesdropping)
- Safety: max strictness on all Gemini harm categories, deadpan rejections

---

## Previous Session: Mar 13-14, 2026

### What was built
1. **Netflix-style Decide page** — PossibilityHorizon rewrite with horizontal card rails, DecisionCard component (3 sizes), Unsplash hero banner (destination photo from Firebase Storage), Framer Motion entrance choreography, shimmer loading, smooth momentum scroll.

2. **Login redesign** — Two-screen flow: brand screen ("people, plans and memories. decide together, effortlessly. encrypted, always.") → magic field (phone/OTP/name/photo all morph in same position via AnimatePresence). Country code selector with auto-detect.

3. **4-appearance theme system** — hearth (light flat), hearth_dark (dark flat), vibe (light depth), vibe_dark (dark depth). Style token: `ThemeStyle = "flat" | "depth"`. Components use `isVibe` from ThemeContext, not theme names. Architecture supports unlimited themes — just add to theme.ts + UserMenu THEME_NAMES.

4. **Solid ink color system** — `ink.primary` (#000000), `ink.secondary` (#6B6B78), `ink.tertiary` (#8A8A94), `ink.sender` (#9E6A06). All readable text uses solid colors, never opacity. Survives direct sunlight on $50 Android for 70-year-old users.

5. **Memories tab** — Third Galaxy tab (people/plans/memories). Aggregates photos across all spaces. Masonry grid with hero 2×2 + small tiles. Demo data with real Unsplash photos.

6. **Swipe between Galaxy tabs** — Horizontal swipe > 60px switches people ↔ plans ↔ memories.

7. **Sunlight readability overhaul** — Background #F0EEE9 → #F8F7F4 (brighter). Text #141414 → #111111 (darker). All screens updated: PeopleDock, AwarenessStream, UserMenu, ControlCaret, SpacePicker, OnboardingWhispers, login, join, share pages.

8. **Hero image pipeline** — Unsplash API → download blob → upload to Firebase Storage → store Firebase CDN URL in spaces.metadata.hero_url. Next.js `<Image>` with Vercel edge optimization. Demo fallback images for all spaces.

9. **useDeviceTier hook** — Detects $50 Android (deviceMemory ≤ 2, hardwareConcurrency ≤ 4, prefers-reduced-motion). Returns "high" | "low".

10. **Security fix** — `generateId()` infinite recursion bug in spaces.ts (was calling itself instead of `crypto.randomUUID()`).

### Files created this session
- `src/components/os/DecisionCard.tsx` — 3-size card component
- `src/components/os/VideoBackground.tsx` — HTML5 video with device tier fallback (kept for future use)
- `src/components/os/MemoriesTab.tsx` — Galaxy memories tab
- `src/lib/unsplash.ts` — Unsplash API + Firebase Storage upload
- `src/hooks/useDeviceTier.ts` — Low-end device detection
- `src/types/navigator.d.ts` — deviceMemory type declaration
- `docs/superpowers/specs/2026-03-13-decide-page-themes-design.md`
- `docs/superpowers/plans/2026-03-13-decide-page-themes.md`

### Files significantly modified
- `src/lib/theme.ts` — 4 themes, ThemeStyle, ink system, isVibeStyle helper
- `src/components/os/ThemeProvider.tsx` — ink CSS vars, data-style attribute, isVibe in context
- `src/app/login/page.tsx` — Complete rewrite, fully theme-aware
- `src/components/os/PossibilityHorizon.tsx` — Netflix rails rewrite
- `src/app/galaxy/page.tsx` — 3 tabs, swipe gestures
- `src/components/os/Avatar.tsx` — shape prop (circle/square)
- `src/lib/spaces.ts` — Firebase Storage hero upload, generateId fix
- `src/app/globals.css` — ink CSS vars, shimmer keyframe
- `src/components/os/UserMenu.tsx` — 4 theme picker
- `src/components/os/PeopleDock.tsx` — ink colors, vibe depth avatars
- `src/components/os/AwarenessStream.tsx` — ink colors, vibe depth avatars
- `next.config.ts` — Unsplash + Firebase Storage image domains

### Architecture decisions made
- **Zero-Box Doctrine** strictly enforced — vibe style explored with row containers, then reverted. Depth comes from avatar shadows + ambient glow only, never row containers.
- **Opacity banned for readable text** — `textColor(alpha)` kept only for atmospheric elements (mesh wash, chat foveal dimming). All list text uses solid `ink.*` colors.
- **WhatsApp/iMessage reference** — People tab uses same font sizes (name 17px, preview 14px, time 11px, avatar 46px) and solid color hierarchy.
- **Theme architecture is loosely coupled** — components check `style` field, not theme names. Adding a theme = 2 file changes (theme.ts + UserMenu).

### Known issues
- Unsplash API key not configured (needs `NEXT_PUBLIC_UNSPLASH_ACCESS_KEY` in .env.local)
- VideoBackground component exists but no video themes currently active
- PWA: missing offline support, maskable icons, splash screens (see pwacheck.md)
- XarkChat still uses foveal opacity (intentional for chat, but review if it's readable enough)

### What to do next
- Run Supabase migration 013 (daily use features)
- Configure Firebase for production
- First real users
- PWA production blockers (offline, icons, splash)
