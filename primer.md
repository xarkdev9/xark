# XARK OS — Session Primer

> For AI agents: Read this FIRST before any code work. It tells you what changed recently and what to watch for. Updated after every session.

## Last Session: Mar 17, 2026 (E2EE Security Sprint — 44 commits, 6 audits)

### What was built

70. **E2EE Protocol Hardening (26 fixes)** — 20 bugs + 6 audit findings fixed across the entire crypto pipeline:
    - P0-1: WebCrypto non-extractable identity key architecture (transitional — raw bytes with encrypted IndexedDB store via Argon2id).
    - P0-2: Memory Worker DELETED — stored decrypted plaintext in IndexedDB. All Tier 2 local recall removed.
    - P1-1: Ratchet headers now encrypted (XChaCha20-Poly1305 via HKDF-derived header key). Previously sent in cleartext.
    - FATAL BUG 15: `serializeSenderKey` split into `ForStorage` (includes private key) and `ForDistribution` (public only). Private key can never leak over the wire.
    - BUG 1: JWT race condition — exponential backoff in useE2EE initialization.
    - BUG 3/19: OTK lifecycle — consumed after use, server-side count query for replenishment.
    - BUG 5/20: Await DB write before Realtime broadcast in Sender Key distribution (race condition).
    - BUG 7/8: Device matching AND filter in fetchCiphertexts (was fetching other devices' ciphertexts).
    - BUG 9: Dedicated `sender_key_dist` fetch path (no pagination limit applied to control messages).
    - BUG 11/13: X3DH input validation (reject malformed keys before DH).
    - BUG 16: Skipped-key dictionary for out-of-order group messages.
    - X3DH OTK 4-DH asymmetry: Responder now reads `otkId` from header, loads OTK, achieves true 4-DH (was 3-DH).
    - Encrypt mutex (`withEncryptLock`) — serializes all encrypt ops per session/space (prevents nonce reuse).
    - Decrypt mutex (`withDecryptLock`) — serializes all decrypt ops per sender (prevents ratchet desync).
    - Stale closure fix — member leave callback queries fresh DB instead of closed-over snapshot.
    - Silent SK drop — distribution failure aborts send (fail-closed, no silent data loss).
    - Two-phase ratchet commit — durable unacked state in IndexedDB, commit only after network ACK.
    - Stable header key derivation — both sides derive identical key from `HKDF(sharedSecret)`.
    - Stable SK cache key — uses signing key public (immutable) not chainKey (mutable).

71. **Spotlight Extraction** — @xark completely removed from ChatInput and Space page sendMessage:
    - No cyan text detection, no voice @xark mode, no `XARK_HINTS` in ChatInput.
    - No `hasXark` detection, no `xark_trigger`, no `e2ee_xark` message type in sendMessage.
    - `/api/message` purged from 325 to 132 lines — pure E2EE message endpoint now.
    - MessageType cleaned: removed `e2ee_xark` and `e2ee_crdt`.
    - **@xark is currently disconnected from UI. XarkSpotlight.tsx needs to be built.**

72. **Security Hardening (12 fixes)** — Defense-in-depth across the full stack:
    - CSP: nonce-based, no `unsafe-eval`/`unsafe-inline`, pinned Supabase URL, request + response headers.
    - Fail-closed E2EE: no legacy plaintext fallback. Send fails visibly if encryption fails.
    - Cross-tenant fix: `insert` not `upsert` for `create_space`, random UUID suffix.
    - SECURITY DEFINER lockdown: `REVOKE PUBLIC` on all dangerous RPCs.
    - Centralized rate limiter: Supabase Postgres-backed (replaces per-Lambda in-memory Map).
    - Privacy cascades: FK `ON DELETE CASCADE`, PII scrub trigger, IndexedDB shredding on logout.
    - `window.open` XSS: URL protocol validation (https/http only).
    - `tel:` scheme: phone number sanitization.
    - Dev mode gated behind `NODE_ENV !== "production"`.
    - Debug banner removed from production.
    - EnclaveTunnel deleted (fake encryption facade).
    - Guest-vote route deleted (no auth required — security hole).
    - Prototype pollution defense on decrypted payloads.

73. **Dead Code Purge** — Removed modules that stored plaintext or had no auth:
    - `src/workers/memory-worker.ts` (plaintext IndexedDB)
    - `src/hooks/useLocalMemory.ts` (Tier 2 hook)
    - `src/lib/local-recall.ts` (Tier 2 recall detection)
    - `src/components/os/ContextCard.tsx` (recall context card)
    - `src/lib/agent/EnclaveTunnel.ts` (fake encryption)
    - `src/lib/agent/LocalIntentParser.ts` (moved to dump)
    - `src/lib/store/useCrdtStore.ts` (moved to dump)
    - `src/lib/store/crdt-types.ts` (moved to dump)
    - `src/lib/crypto/DeviceLinker.ts` (moved to dump)
    - `src/lib/crypto/GuestLinker.ts` (moved to dump)
    - `src/lib/crypto/LazyRotator.ts` (moved to dump)
    - `src/app/api/guest-vote/route.ts` (deleted — no auth)
    - `src/app/api/device-link/route.ts` (moved to dump)
    - Dead deps removed from package.json: minisearch, capacitor, zustand.

74. **New E2EE Modules** — 4 new crypto modules:
    - `src/lib/crypto/encrypted-store.ts` — Argon2id-wrapped IndexedDB encryption for key material at rest.
    - `src/lib/crypto/sk-recovery.ts` — P2P Sender Key re-request protocol (ask peers for missing keys).
    - `src/lib/crypto/outbox.ts` — Offline message queue with auto-retry on reconnect.
    - `src/lib/crypto/dm-routing.ts` — Deterministic 1:1 space ID generation (canonical pair ordering).

75. **54 Tests Passing** — 33 existing crypto tests + 21 new tests for the security fixes.

### Files created
- `src/lib/crypto/encrypted-store.ts` — Argon2id-wrapped IndexedDB encryption
- `src/lib/crypto/sk-recovery.ts` — P2P Sender Key re-request protocol
- `src/lib/crypto/outbox.ts` — Offline message queue with auto-retry
- `src/lib/crypto/dm-routing.ts` — Deterministic 1:1 space ID generation

### Files significantly modified
- `src/lib/crypto/encryption-service.ts` — encrypt/decrypt mutexes, two-phase ratchet commit, fail-closed send, header encryption, stable SK cache key, stale closure fix
- `src/lib/crypto/sender-keys.ts` — `serializeSenderKeyForStorage` / `serializeSenderKeyForDistribution` split (FATAL BUG 15)
- `src/lib/crypto/double-ratchet.ts` — encrypted ratchet headers (P1-1), skipped-key dictionary fix (BUG 16), stable header key derivation
- `src/lib/crypto/x3dh.ts` — Input validation (BUG 11/13), OTK 4-DH asymmetry fix (responder reads otkId from header)
- `src/lib/crypto/key-manager.ts` — OTK consumption after use (BUG 3/19), server-side count query for replenishment
- `src/lib/crypto/keystore.ts` — Two-phase commit (unacked state), IndexedDB shredding on logout
- `src/hooks/useE2EE.ts` — JWT race exponential backoff (BUG 1), fail-closed (no legacy fallback)
- `src/app/api/message/route.ts` — Purged 325 to 132 lines, pure E2EE, no @xark trigger, await DB before broadcast (BUG 5/20)
- `src/lib/messages.ts` — Removed `e2ee_xark` and `e2ee_crdt` from MessageType, dedicated SK dist fetch (BUG 9), device AND filter (BUG 7/8)
- `src/components/os/ChatInput.tsx` — Removed @xark cyan detection, XARK_HINTS, voice @xark mode
- `src/app/space/[id]/page.tsx` — Removed hasXark/xark_trigger/e2ee_xark, fail-closed send, prototype pollution defense on decrypted payloads
- `src/app/layout.tsx` — CSP nonce-based headers
- `src/lib/rate-limit.ts` — Supabase Postgres-backed centralized rate limiter (replaces in-memory Map)
- `package.json` — Removed minisearch, capacitor, zustand

### Migrations applied (run on Supabase)
- `015_e2ee_wiring.sql` — fetch_key_bundle with otk_id, get_space_member_devices
- `023_e2ee_rls_perf.sql` — Direct column check RLS for message_ciphertexts
- `024_security_definer_lockdown.sql` — REVOKE PUBLIC on all dangerous RPCs
- `025_rate_limiter.sql` — Postgres-backed rate_limits table + check_rate_limit RPC
- `026_privacy_cascades.sql` — FK cascades + PII scrub trigger

### Architecture decisions made
- **Fail-closed E2EE** — no legacy plaintext fallback anywhere. If encryption fails, the message does not send. Users see an error. This is the correct behavior.
- **Encrypted ratchet headers** — header key derived via HKDF from shared secret. Both sides compute the same key deterministically. Headers were previously cleartext, leaking ratchet state.
- **Two-phase ratchet commit** — ratchet state written to IndexedDB as "unacked" before network send. Committed only after server ACK. Prevents state desync on network failure.
- **Encrypt/decrypt mutexes** — all crypto ops serialized per session/space (encrypt) and per sender (decrypt). Prevents nonce reuse and ratchet desync from concurrent operations.
- **serializeSenderKey split** — ForStorage includes private signing key (local IndexedDB only). ForDistribution includes only public signing key + chain key (sent to peers). FATAL: previous code sent private key to all group members.
- **Memory Worker deleted** — stored decrypted message plaintext in IndexedDB. Violated zero-knowledge server architecture. Tier 2 local recall removed entirely.
- **@xark extracted from chat pipeline** — ChatInput and sendMessage are now pure E2EE paths. @xark will be re-introduced via XarkSpotlight.tsx (separate UI surface, not inline in chat).
- **Centralized Postgres rate limiter** — replaces per-Lambda in-memory Maps that reset on cold start. Supabase RPC `check_rate_limit` with sliding window.
- **CSP nonce-based** — no unsafe-eval or unsafe-inline. Scripts must carry the nonce. Prevents XSS injection.
- **Privacy cascades** — deleting a user cascades to all their data (messages, keys, reactions, memberships). PII scrub trigger clears display_name and phone on soft delete.

### Known issues
- **@xark is disconnected** — XarkSpotlight.tsx not yet built. @xark has no UI entry point.
- **WebAuthn PRF not implemented** — encrypted store currently uses Argon2id password prompt. Biometric unlock via WebAuthn PRF is the target UX.
- **Unacked ratchet reconciliation** — on boot, unacked ratchet states exist in IndexedDB but reconciliation logic (retry or rollback) is not wired.
- **Pexels API key proxy** — key is client-side (NEXT_PUBLIC). Should be proxied through server-side route.
- **Key rotation on member leave** — deferred to v2. Members who leave still hold old Sender Keys.
- **geminiSearchGrounded** still uses regex JSON extraction (not responseMimeType).

### What to do next
- Build XarkSpotlight.tsx — @xark Spotlight UI (separate from chat, structured JSON from /api/xark)
- Simplify /api/xark for Spotlight — return structured JSON only, no message persistence
- WebAuthn PRF biometric prompt for encrypted store unlock
- Unacked ratchet reconciliation on boot (retry pending sends or rollback state)
- Pexels API key proxy (move NEXT_PUBLIC key to server-side /api/photos route)
- First real users

---

## Previous Session: Mar 16, 2026 (Ghost Playground + UX Polish + Strategy)

### What was built
61. **Ghost Playground** — 4 sandbox spaces for first-time users (tokyo neon nights, dinner tonight, maya's birthday, weekend hike). 5 fake friends (leo, kai, ava, zoe, sam). Diegetic whispers with breathing opacity. Timer-based choreography engine. Playground vanishes when first real space created. Files: playground.ts, usePlaygroundChoreography.ts, PlaygroundWhisper.tsx, InlineCardPreview.tsx, PlaygroundSpace.tsx.

62. **Tab-Aware Dream Input** — People tab: "type a name to start chatting..." with zero-state contact reveal (avatars on focus), actionable autocomplete ("start chat with myna ->"), persistent "chat:" ghost prefix, first-time training whisper. Plans tab: "a trip, a dinner, a plan...". Context-aware placeholder + contact suggestions.

63. **Share Options Sheet** — 3-tier share: native share sheet (HTTPS) -> WhatsApp/SMS/Copy fallback sheet (HTTP/LAN). Inline "invite someone to this space ->" prompt in chat stream when solo (within thumb arc).

64. **Android Keyboard Fix** — useKeyboard.ts: Android returns keyboardHeight=0 (viewport already resizes). Attach/camera/xark anchor hide when keyboard open, attach+camera move inline when keyboard up + no text.

65. **Swipe Discuss<->Decide** — Added horizontal swipe gesture to Space page and PlaygroundSpace (same pattern as Galaxy tabs).

66. **Chat Typography -> WhatsApp Parity** — text.subtitle: 15px/300/1.45 -> 16px/400/1.35. Weight 400 is the key -- 300 looked washed out.

67. **Extra "s" Bug Fix** — pluralizeCategory() fallback appended "s" to search labels. Now returns as-is for non-category keys.

68. **Default to Discuss** — Groups open to chat view, not Decide. Users switch deliberately.

69. **Strategic Assessment** — banger.md reviewed with brutally honest analysis. Key insight: "Start with dinner, earn the trip." Guest Mode web view identified as existential priority.

### Files created
- src/lib/playground.ts, src/hooks/usePlaygroundChoreography.ts, src/components/os/PlaygroundWhisper.tsx, src/components/os/InlineCardPreview.tsx, src/components/os/PlaygroundSpace.tsx

### Architecture decisions made
- Playground is client-side only (zero DB). Vanishes on first real space creation.
- Default to Discuss (chat) for groups. Decide is opt-in.
- Guest Mode identified as existential priority for growth.

---

## Previous Session: Mar 16, 2026 (Security + Voting + Unread + PWA)

### What was built
52. **Security Audit — All Critical/High/Medium Fixed** — C2: message_type_override allowlist. H2: phone-auth rate limited. H3: /api/og requires auth. H4: xark rate limit keyed on JWT. H5: xark_trigger length cap. H6: local-action + notify rate limited. M3: invite token 16 bytes. M5: dev-auto-login blocked in production. M6: spaceTitle sanitized.

53. **Voting Fix** — Per-item debounce (useRef Set replaces global isReacting). Signal colors: love=#FF6B35, okay=#A8B4C0, pass=#6B7280. Glowing pill buttons.

54. **Unread Message Badges** — WhatsApp-style. space_members.last_read_at, get_unread_counts() RPC, mark_space_read() RPC. Brand orange pill badge.

55. **E2EE Phone-Only Gate** — name_ prefix = legacy plaintext. phone_ prefix = E2EE.

56-60. Search grouping by query text, space name fix, chat spacing 20px/2px/4px, PWA offline SW + maskable icons, Pexels hero images.

---

## Previous Session: Mar 15, 2026 (UI Overhaul — Login, Galaxy, Decide, Chat)

### What was built
42. **Cinematic Login** — Phase-based video background (spark -> collision -> reveal -> idle). 4 Pexels videos. WelcomeScreen.tsx transparent overlay.

43. **3-Tone Surface System** — surface.chrome/canvas/recessed. 4 values per theme. CSS variables via ThemeProvider.

44. **Immersive Decision Cards** — 82% viewport x clamp(320px, 50dvh, 440px). Full-bleed photos, cinematic gradient. 56px/300 amber score.

45-51. PossibilityHorizon hero images, WhatsApp chat spacing, Magnetic Input, Living Brand Anchor, vibe_dark accent #FF6B35, card animation fix, lossless context plugin.

---

## Previous Session: Mar 15, 2026 (E2EE Wiring + Three-Tier Brain)

### What was built
37-41. E2EE full pipeline wiring (migration 015, SK distribution, X3DH metadata, batch/realtime decrypt, @xark broadcast fix, blank screen fix). Three-Tier Hybrid Brain (Tier 1 local-agent, Tier 2 memory worker [NOW DELETED], space_ledger, LedgerPill).

---

## Previous Session: Mar 15, 2026 (E2EE Implementation)

### What was built
31-36. Signal Protocol implementation (Double Ratchet + Sender Keys + X3DH). Full crypto module (src/lib/crypto/). Migration 014. useE2EE hook. /api/message endpoint. /api/keys/* endpoints. On-device constraints. SECURITY.md. Sender identity bug fix. All guardrails updated.

---

## Previous Session: Mar 15, 2026 (Intelligence + Voice)

### What was built
21-30. Gemini responseMimeType fix, prompt order fix, anti-cringe voice engineering, chain-of-thought, date math, implicit context, conflict resolution, safety tuning. Two-tier intelligence routing (gemini-local 7-10s vs gemini-search 40-50s).

---

## Previous Sessions: Mar 13-14, 2026 (Decide + Themes + Production)

### What was built
1-20. Netflix-style PossibilityHorizon, DecisionCard, 4-theme system, ink colors, memories tab, swipe tabs, Unsplash hero pipeline, useDeviceTier, login redesign, sunlight readability, production perf (N+1 fix, pagination, batched queries, RPCs), PII sanitizer, micro-space templates, instant invite system, people-first Galaxy refactor, share pipeline, booking bridge.
