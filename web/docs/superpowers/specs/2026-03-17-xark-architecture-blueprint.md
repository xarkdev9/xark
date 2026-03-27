# Xark OS v2.0 — Architecture Blueprint

**Date**: 2026-03-17
**Phase**: E2EE_HARDENED (6 audits passed, 54 tests, 44 security commits)
**Scope**: Solo + Small Group (up to 15 members)
**Stack**: Next.js 15 + React 19 + Tailwind CSS 4 + TypeScript 5 + Framer Motion
**Repo**: /Users/ramchitturi/xark9

---

## 1. System Identity

Xark OS is a biocompatible Group Operating System — a Human Companion, not a dashboard. It enables small groups (1-15 people) to plan trips, dinners, and shared decisions through end-to-end encrypted messaging, AI-assisted search, and a consensus-driven commitment protocol.

**Core thesis**: People. Plans. Memories. All private, effortlessly in sync.

---

## 2. Infrastructure Lock (Hybrid Stack)

The backend is a locked hybrid of Firebase and Supabase. No substitutions. No Supabase Auth. Ever.

| Component | Provider | Why |
|-----------|----------|-----|
| Phone OTP | Firebase Auth | Flawless SMS delivery + session management |
| Decision Engine | Supabase Postgres | SQL for heart-sort ranking, RLS, Realtime |
| E2EE Key Distribution | Supabase Postgres | key_bundles, one_time_pre_keys with atomic RPCs |
| Encrypted Message Storage | Supabase Postgres | message_ciphertexts (server stores ciphertext only) |
| Multimedia (E2EE) | Firebase Storage | High-performance binary delivery + bucket security |
| Encrypted Key Backups | Firebase Storage | Argon2id-encrypted blobs (server cannot decrypt) |
| Push Alerts | Firebase Cloud Messaging | Native iOS/Android push via FCM |
| Intelligence | Gemini 2.5 Flash | Three-tier @xark routing (Layer 3 only) |
| Realtime | Supabase Realtime | Postgres NOTIFY/LISTEN -> WebSocket channels |

**BANNED**: Supabase Auth, Firestore, Firebase Realtime Database.

---

## 3. Service Boundaries

9 domain services. Each owns its data. Communication via Supabase Realtime events or API calls. All stateless where possible — state lives in Postgres.

| Service | Owns | Key Files |
|---------|------|-----------|
| **Auth** | `users`, `user_devices` | `firebase.ts`, `useAuth.ts`, `/api/phone-auth`, `/api/dev-auth`, `/api/dev-auto-login` |
| **Space** | `spaces`, `space_members` | `spaces.ts`, `space-data.ts`, `space-state.ts`, `space-templates.ts` |
| **Intelligence** | Stateless orchestrator | `intelligence/orchestrator.ts`, `intelligence/tool-registry.ts`, `intelligence/apify-client.ts`, `intelligence/sanitize.ts`, `ai-grounding.ts`, `/api/xark` |
| **Decision Engine** | `decision_items`, `reactions` | `heart-sort.ts`, `state-flows.ts`, `handshake.ts`, `claims.ts`, `useHandshake.ts`, `useReactions.ts` |
| **Messaging** | `messages`, `message_ciphertexts` | `messages.ts`, `crypto/*`, `useE2EE.ts`, `/api/message`, `/api/keys/*` |
| **Media** | `media` | `media.ts`, `unsplash.ts` |
| **Notification** | reads `user_devices` | `notifications.ts`, `/api/notify` |
| **Settlement** | reads `decision_items` + `space_members` | `ledger.ts` |
| **Itinerary** | Computed from purchased items + media | `ItineraryView.tsx`, `MemoriesView.tsx` |

**Design decisions**:
- Commitment (handshake, claims, ownership) is a sub-domain of Decision Engine — not a separate service — because it writes to `decision_items`.
- Intelligence is stateless — orchestrates Gemini + Apify, feeds results into Decision Engine as proposed items.
- Settlement reads `space_members` for true member count (not just payers) when calculating fair share.

---

## 4. End-to-End Encryption (Signal Protocol)

Full spec: `SECURITY.md`. 54 tests passing. 6 security audits passed.

### Three-Layer Architecture

```
LAYER 1: KEY MANAGEMENT
  Identity keys (Ed25519 -> Curve25519 birational pair)
  Signed pre-keys (rotated 30 days)
  One-time pre-keys (batch of 100, atomic consumption)
  Encrypted IndexedDB store (Argon2id-wrapped AES-GCM)
  Stored on device only — server holds PUBLIC keys exclusively

LAYER 2: MESSAGE ENCRYPTION (zero-knowledge)
  Signal Protocol: Double Ratchet (1:1 sanctuaries), Sender Keys (groups 2-15)
  XChaCha20-Poly1305 AEAD (hardware-independent, 192-bit nonce)
  Server stores ciphertext only — mathematically cannot decrypt
  Encrypted ratchet headers (HKDF-derived header key)
  Two-phase ratchet commit (crash safety)
  Encrypt/decrypt mutexes (nonce reuse + ratchet desync prevention)

LAYER 3: STRUCTURED INTELLIGENCE
  Decision items, reactions, constraints, space metadata
  @xark reads ONLY this layer — never Layer 2
  Unencrypted — functional data for group decisions
```

### Crypto Module Map (`src/lib/crypto/`)

| Module | Purpose |
|--------|---------|
| `types.ts` | All E2EE types (key pairs, sessions, payloads, message types) |
| `primitives.ts` | libsodium-wrappers-sumo wrapper (XChaCha20, Ed25519, Curve25519, HKDF, Argon2id) |
| `keystore.ts` | IndexedDB-backed persistent key storage, two-phase commit, shredding on logout |
| `encrypted-store.ts` | Argon2id-wrapped IndexedDB encryption for key material at rest |
| `x3dh.ts` | X3DH key agreement (4 DH operations), input validation |
| `double-ratchet.ts` | Per-message forward secrecy (1:1), encrypted headers, skipped-key dictionary (max 1000) |
| `sender-keys.ts` | Group encryption with chain advancement, ForStorage/ForDistribution split (private key never leaks) |
| `key-manager.ts` | Registration, key fetch, OTK replenishment (count query), backup/restore |
| `encryption-service.ts` | High-level encrypt/decrypt, encrypt/decrypt mutexes, SK recovery, message type guard |
| `sk-recovery.ts` | P2P Sender Key re-request protocol (ask peers for missing keys) |
| `outbox.ts` | Offline message queue with auto-retry on reconnect |
| `dm-routing.ts` | Deterministic 1:1 space ID generation (canonical pair ordering) |
| `CryptoProvider.ts` | React context for E2EE state |

### Key Security Properties

- **Fail-closed**: No legacy plaintext fallback. If encryption fails, message does not send.
- **Forward secrecy**: Double Ratchet = per-message. Sender Keys = per-sender-chain.
- **Anti-injection**: `resolveMessageContent()` — E2EE messages rendered ONLY from decrypted ciphertext, never from `messages.content`.
- **No backdoors**: No master key, no key escrow, no admin decryption, no recovery that bypasses user password.
- **Sender Key split**: `serializeSenderKeyForStorage` (includes private) vs `serializeSenderKeyForDistribution` (public only). Private key can never leak over the wire.
- **Encrypt mutex**: Serializes all encrypt ops per session/space (prevents nonce reuse).
- **Decrypt mutex**: Serializes all decrypt ops per sender (prevents ratchet desync).
- **Two-phase ratchet commit**: Ratchet state written as "unacked" before network send. Committed only after server ACK.

### Key Distribution Flow

```
Registration:
  1. Generate Identity Key (Ed25519)
  2. Generate Signed Pre-Key (Curve25519, signed by Identity Key)
  3. Generate 100 One-Time Pre-Keys (Curve25519)
  4. Upload public halves to Supabase (key_bundles + one_time_pre_keys)

First message (X3DH):
  1. Fetch recipient's key bundle (identity + signed pre-key + OTK)
  2. X3DH computes shared secret from 4 DH operations
  3. Double Ratchet session initialized from shared secret
  4. OTK atomically consumed (FOR UPDATE SKIP LOCKED)

Group join:
  1. Generate Sender Key (symmetric chain key + Ed25519 signing key)
  2. Distribute to each member via pairwise E2EE sessions
  3. Server never sees Sender Keys
```

---

## 5. Intelligence Service — @xark + Gemini + Apify

### Privacy Rule (non-negotiable)
@xark is deaf until invoked. No passive listening. @xark reads ONLY Layer 3 structured data — NEVER Layer 2 encrypted messages. @xark is DISABLED in sanctuaries (1:1).

### Current Status
**@xark is DISCONNECTED from the chat pipeline.** Extracted during E2EE sprint (Spotlight Extraction). `/api/xark` exists but is not wired into `/api/message`. Next: build `XarkSpotlight.tsx`.

### Three-Tier Intelligence Routing

```
Tier 1: gemini-local (FAST, ~7-10s)
  geminiLocalSearch() — direct Gemini knowledge
  Tools: local_restaurant, local_activity, local_general
  For: coffee, brunch, sunset spots, bars, casual queries
  No Google Search API. JSON array of real places.

Tier 2: gemini-search (~40-50s)
  geminiSearchGrounded() — Google Search grounding
  Tool: general
  For: travel tips, weather, "what to pack", knowledge queries

Tier 3: apify (SLOW, 15-50s)
  runActor(actorId, input) — Apify actors for booking
  Tools: hotel, flight, restaurant, activity
  For: specific booking queries with prices, ratings, URLs
```

### Orchestrator (`src/lib/intelligence/orchestrator.ts`)

- Gemini 2.5 Flash with native JSON mode (`responseMimeType: "application/json"`)
- `buildStaticPrompt()` / `buildDynamicPrompt()` split for context caching readiness
- `_thought_process` chain of thought for routing decisions
- Anti-cringe voice rules in synthesis
- Implicit context extraction from grounding (budget, dietary)
- Conflict resolution for split groups
- Flash model guard warns if pro model detected
- PII sanitized before all Gemini calls (`sanitize.ts` — Luhn-validated credit cards, SSN, CVV, bank accounts)

### Tool Registry (`src/lib/intelligence/tool-registry.ts`)

8 tools across 2 tiers:
- **apify tier**: hotel, flight, activity, restaurant, general
- **gemini-search tier**: local_restaurant, local_activity, local_general
- `registerTool(name, { actorId, description, paramMap, tier })`

### Grounding Engine (`src/lib/ai-grounding.ts`)

STATE MAP APPROACH — replaces rigid "forbidden category" bans:
- `buildGroundingContext(spaceId)`: Fetches all items grouped by state (Locked -> Voting -> Proposed -> Empty). Includes reaction counts per item, locked items with ownership, currentFavorites, topIgnitedTitle.
- `generateGroundingPrompt(context)`: Full state map for system prompt. Appends WEIGHTING RULES (-3/+1/+5). Lets Gemini reason about scope.
- `checkSuggestionConflicts(items, category)`: Pre-call guard. Returns locked decisions in same category before AI generates.
- Test: "Hotel" locked does NOT ban "Airbnb for different city" if different need. "Italian restaurant" locked DOES ban "let's try Italian" for same meal.

### @xark Behavior

- Silent by default — only speaks when "@xark" is in message
- Cool friend persona: brief, lowercase, punchy, max 20 words
- BANNED vocabulary: OMG, epic, vibes, dive in, delve, legendary, bestie
- Max ONE contextual emoji (zero is usually better)
- Social reasoning: names for advocacy, counts for opposition, never assume why someone voted
- One exception: handshake whisper at >80% consensus (automated)

### Local Intelligence (PARKED — needs browser debugging)

Three-tier client-side routing in `sendMessage()`:
- **Tier 1**: `local-agent.ts` — regex admin commands (dates, rename, status). <1ms.
- **Tier 2**: DELETED (Memory Worker stored plaintext — violated zero-knowledge).
- **Tier 3**: Gemini cloud (via `/api/xark`)
- `/api/local-action` — Tier 1 mutation endpoint with `space_ledger` audit trail.

---

## 6. Decision Engine

### Signal System (Reaction Vocabulary)

| Signal | Label | Weight | Color |
|--------|-------|--------|-------|
| LoveIt | "Love it" | +5 | Amber (#F5A623) |
| WorksForMe | "Works for me" | +1 | Neutral Gray (#8888a0) |
| NotForMe | "Not for me" | -3 | Action Orange (#e8590c) |

- One reaction per user per item. Last reaction wins.
- Score can go negative (items sink).
- Two LoveIt overcome one NotForMe (5+5-3=7).
- Passionate minority wins: 3 LoveIt (15) beats 4 WorksForMe (4).

### Heart-Sort Algorithm (`src/lib/heart-sort.ts`)

SSOT for all decision ranking. Source of truth: `/Users/ramchitturi/algo` (198 tests).
- `heartSort()`: Descending by `weightedScore`. Tie-break by `proposedAt` ascending.
- `calculateWeightedScore()`: Sum of deduplicated reaction weights.
- `calculateAgreementScore()`: ALL reactors / totalMembers. `isGroupFavorite` = strictly > 80%.
- All functions are pure: no mutation, no side effects.

### State Machine — 4 Preset Flows (`src/lib/state-flows.ts`)

```
BOOKING_FLOW (default):
  proposed -> ranked -> locked -> claimed -> purchased
  locked = consensus reached, no owner
  claimed = someone stepped up, owner stamped
  purchased = proof + amount submitted (terminal, feeds settlement)

PURCHASE_FLOW:
  researching -> shortlisted -> negotiating -> purchased

SIMPLE_VOTE_FLOW:
  nominated -> ranked -> chosen

SOLO_DECISION_FLOW:
  considering -> leaning -> decided
```

- States are open strings (not enum) for custom flows.
- `resolveTerminalState(state, flow?)` disambiguates across flows.
- Solo spaces: no consensus threshold. React = decide.

### Two-Step Commitment Protocol

```
Step 1 — Consensus Lock (automated via handshake.ts):
  agreementScore > 0.80
  -> @xark: "consensus on [title]. lock it in?"
  -> Group confirms
  -> state: "locked", is_locked: true, no owner
  -> CommitmentProof: { type: "verbal", value: "group consensus via @xark handshake" }

Step 2 — Claim + Purchase (manual via claims.ts + ClaimSheet + PurchaseSheet):
  -> Someone taps "i'll handle this" on locked item
  -> state: "claimed", owner stamped { ownerId, assignedAt, reason: "booker" }
  -> They book/buy in the real world
  -> Return with proof + amount
  -> state: "purchased" (terminal)
  -> Amount feeds settlement ledger
```

### Green-Lock Commitment Protocol (`src/lib/claims.ts`)

- Lock = real-world commitment (booking, purchase), NOT a vote
- Cannot double-lock (`GreenLockError`)
- Proof types: confirmation_number, screenshot, receipt, contract, verbal
- `ownershipHistory[]`: append-only audit trail
- Optimistic concurrency via `version` field

---

## 7. Emergent Space State

Spaces have no explicit phase field. State is computed from items via a pure function.

`computeSpaceState(items[], tripDates?, expiresAt?)` → one of:

| State | Condition | UI Behavior |
|-------|-----------|-------------|
| **empty** | Zero items | Hero prompt, @xark ready |
| **exploring** | All items proposed/voting | PossibilityHorizon active |
| **converging** | Some locked + some open | Mixed — settled + open |
| **ready** | All core categories locked/purchased | Itinerary preparation |
| **active** | Purchased items + dates in range | Itinerary view, photo uploads |
| **settled** | Trip dates passed + settlement calculated | Memory mode |

- `expiresAt` enables auto-settle for micro-space templates (dinner_tonight = 8h, weekend_plan = 72h).
- Categories are open strings. @xark reasons about the state map.

---

## 8. Messaging Service

### Message Flow (`/api/message`)

Unified E2EE message endpoint. 132 lines (purged from 325 during Spotlight Extraction).
- Atomic: encrypt -> persist ciphertext -> broadcast via Realtime
- Two-phase ratchet commit (crash safety)
- DM routing: detects sanctuary (1:1) spaces -> Double Ratchet instead of Sender Keys
- Rate limited (10 @xark calls/min per user via Postgres-backed rate limiter)
- Outbox pattern for retry on network failure

### Message Types

| Type | Description |
|------|-------------|
| `e2ee` | Encrypted user message (ciphertext in `message_ciphertexts`) |
| `xark` | @xark AI response (server-generated plaintext, TTL auto-purge) |
| `system` | Lifecycle events (joined, locked, purchased) |
| `legacy` | Pre-E2EE plaintext messages |
| `sender_key_dist` | Sender Key distribution control messages |

### Message Persistence (`src/lib/messages.ts`)

- Paginated: `fetchMessages(spaceId, { limit?, before? })` — default 50, DESC reversed client-side
- Realtime sync via Supabase INSERT subscription
- Deduplication via messageId
- Dedicated SK distribution fetch path (no pagination limit on control messages)
- Device AND filter in `fetchCiphertexts` (fetches only this device's ciphertexts)

### Chat Interface (`XarkChat.tsx`)

- Display-only. Receives messages + isThinking as props from Space page.
- No bubbles, no boxes, no containers. Text floats on atmospheric mesh.
- WhatsApp-precision spacing: 20px different sender, 2px same sender, 4px name-to-message.
- Foveal opacity: newest @xark 0.9 -> floor 0.2. Newest user 0.6 -> floor 0.2.
- Sender names: 13px amber (humans) / cyan (@xark).
- Handshake integration via `useHandshake(spaceId)`.
- Inline card previews (`InlineCardPreview.tsx`) for decision items in chat.
- Inline invite prompt when solo.
- LedgerPill interleaved for space_ledger events.

---

## 9. Event Bus

Supabase Realtime (Postgres NOTIFY/LISTEN -> WebSocket channels).

Channel pattern: `space:{spaceId}` — all events for a space flow through one channel.

**Published tables** (migration 012): `messages`, `decision_items`, `space_members`, `message_ciphertexts`, `key_bundles`, `constraint_prompts`.

**Presence**: Supabase Realtime Presence on the same channel. Heartbeat drives Presence Ember (4px cyan dot on avatars). Limited to top 5 most-recent spaces.

No external message queue needed at this scale. The event bus is an interface (`EventBusPort` in hexagonal architecture) — swappable to Redis/WebSocket without touching business logic.

---

## 10. Navigation & UI Architecture

### Page Flow

```
Login (/login) -> Galaxy (/galaxy?name=) -> Space (/space/[id]?name=)
                                          -> Join (/j/[token])
                                          -> Share (/share)
                                          -> Demo (/demo)
```

### Login Page

- Cinematic video background (4 Pexels videos, phase-based choreography)
- WelcomeScreen.tsx transparent overlay
- Phases: spark -> collision -> reveal -> idle
- Firebase Auth (phone OTP) or dev-auto-login (DEV_MODE=true only)
- Fallback: URL name parameter (`?name=ram`)

### Galaxy Page (`/galaxy`)

- Thin layout shell composing GalaxyLayout + AwarenessStream + PeopleDock
- Layout registry: stream (default, vertical) + split (side-by-side)
- Tab-aware dream input (People tab: contact reveal + autocomplete; Plans tab: trip/dinner)
- Ghost Playground for first-time users (4 sandbox spaces, choreography engine)
- Spectrum Wash + Mesh Pulse backgrounds
- UserMenu visible via GlobalUserMenu
- Unread badges (brand orange pill #FF6B35)

### Space Page (`/space/[id]`)

- View toggle: discuss / decide (+ itinerary / memories for ready/active/settled)
- Swipe gesture between discuss and decide
- Share options: native share -> WhatsApp/SMS/Copy fallback
- Chat state (messages, input, isThinking, sendMessage) lifted to Space page — persists across view switches
- ChatInput always visible at bottom
- discuss -> XarkChat (display-only)
- decide -> PossibilityHorizon (snap-center card rails)
- Default to Discuss (chat) for groups

### Key Components

| Component | Purpose |
|-----------|---------|
| `ControlCaret.tsx` | Living Brand Anchor. "xark" text (18px, weight 300, #FF6B35). Breathing 0.7->0.9. Global via `GlobalCaret.tsx`. Context-aware tap. Slide-up panel for space navigation. |
| `PossibilityHorizon.tsx` | Decide view. Netflix-style horizontal card rails with snap-center scroll. 10-image hero pool (deterministic hash per spaceId). Editorial headers. Category vitals. Self-resolving (locked categories collapse to green dot). Items capped at 100. |
| `DecisionCard.tsx` | 82% viewport x clamp(320px, 50dvh, 440px). Full-bleed photo + cinematic gradient. 56px/300 amber score. 28px radius. Snap-center scroll. Glowing pill reactions. |
| `ChatInput.tsx` | Magnetic Input. Gradient floor. 18px/300 text. @xark cyan detection (currently disabled). Attach/camera inline. Mic<->send crossfade. |
| `AwarenessStream.tsx` | Cross-space events, priority-sorted with time decay. Independent data fetching + Realtime. Space creation flow. |
| `PeopleDock.tsx` | Personal chats list. Contact picker. Independent data fetching + Realtime. |
| `PlaygroundSpace.tsx` | Complete playground view. Mock reactions, mock @xark, choreography engine, swipe. No Supabase. |
| `UserMenu.tsx` | Settings: 4-view drill-down (main -> profile/notifications/about). Theme toggles. FCM registration. |
| `Blueprint.tsx` | Vertical timeline of Green-Lock settled decisions + Settlement Ledger. |
| `ClaimSheet.tsx` | Slide-up for claiming locked items. |
| `PurchaseSheet.tsx` | Slide-up for purchase confirmation + amount entry. |
| `WelcomeScreen.tsx` | Cinematic login entrance with phase choreography. |
| `LedgerPill.tsx` | Interactive system pill for space_ledger events in chat timeline. |

---

## 11. Theme System (4 Themes)

2 axes: style (flat/depth) x mode (light/dark).

| Theme | Style | Mode | Text | Background | Accent |
|-------|-------|------|------|------------|--------|
| hearth (default) | flat | light | #111111 | #F8F7F4 | #FF6B35 (Action Orange) |
| hearth_dark | flat | dark | #E8E6E1 | #0A0A0F | #40E0FF (Cyan) |
| vibe | depth | light | #0F0F0F | #FAF9F6 | #E87040 (warm orange) |
| vibe_dark | depth | dark | #ECE8E2 | #08080C | #50E8C0 (warm teal) |

### Token Systems

- **CSS Variables**: `--xark-white`, `--xark-void`, `--xark-accent`, `--xark-amber`, `--xark-gold`, `--xark-green`, `--xark-orange`, `--xark-gray` (+ `-rgb` variants)
- **Ink system**: Solid text colors for readable content. `ink.primary`, `ink.secondary`, `ink.tertiary`, `ink.sender`. Never opacity-based.
- **Surface system**: 3-tone depth. `surface.chrome` (elevated UI), `surface.canvas` (content areas), `surface.recessed` (wells). Depth without borders.
- **Helpers**: `textColor(alpha)`, `accentColor(alpha)`, `amberWash(score)`, `goldBloom(score)`, `fovealOpacity(index, total, role)`
- **Type scale** (`text` object): hero, spaceTitle, listTitle, body, subtitle, label, recency, timestamp, input, hint. All sizes via `style={{ ...text.body }}` — no Tailwind text-size classes.

### Visual Constitution

- **NO BOLD**: Weight 300/400 only. 500+ is banned.
- **ZERO BOX**: No borders, no bg-white, no rounded-lg for feed items. Information floats.
- **NO BLUR**: No `backdrop-filter`. Overlays use `#000` at opacity 0.8.
- **THEME-AWARE ONLY**: No hardcoded hex in components. Use `colors.*` or `textColor()`.
- **Brand color**: Action Orange #FF6B35 (Living Brand Anchor, vibe_dark accent, hearth accent).
- **Fonts**: Inter (variable, body 400, wordmark 300), Syne (variable, display/fallback 400).

---

## 12. Settlement & Payments

### Settlement Ledger (`src/lib/ledger.ts`)

- `fetchSettlement(spaceId)`: Sums purchased item amounts per owner.
- `parsePrice()`: Handles "$450/nt", "$95/person", "Free".
- `DebtDelta`: `{ fromUser, fromName, toUser, toName, amount }` — who owes whom.
- `memberCount` from `space_members` (true group size, not just payer count).
- `generateVenmoLink()` and `generateUPILink()` — payment deep links.

### Amount Entry Flow (PurchaseSheet)

1. "how much?" input with accent underline
2. Unit toggle: "total" / "per night" / "per person"
3. Proof input: link to confirmation or receipt
4. Stored in `decision_items.metadata.price`
5. Settlement math recalculates

---

## 13. Media Service

| Feature | Path | Storage |
|---------|------|---------|
| Profile photos | `profiles/{userId}/avatar` | Firebase Storage |
| Hero images (spaces) | Pexels API -> `spaces.metadata.imageUrl` | Supabase metadata |
| Trip photos | `spaces/{spaceId}/media/{mediaId}` | Firebase Storage + Supabase metadata |
| OG previews | `/api/og` | Server-side extraction |

- `src/lib/media.ts`: `uploadMedia()` + `fetchMedia()`. Firebase Storage blob + Supabase metadata.
- `src/lib/unsplash.ts`: Pexels API primary (200/hr) -> Unsplash fallback. `fetchDestinationPhoto(query)`.
- **Known issue**: Pexels API key is client-side (`NEXT_PUBLIC`). Should be proxied through server-side route.

---

## 14. Notification Service

### FCM Registration

On login: request notification permission -> get FCM token -> store in `user_devices`. Master toggle in UserMenu. Per-space mute list in `users.preferences.muted_spaces`.

### Trigger Points

| Event | Recipients |
|-------|-----------|
| Consensus reached | All space members |
| Item locked | All space members |
| Item purchased | All space members |
| @xark results ready | Requesting user |
| Member joined | Existing members |
| Settlement ready | Individual debtor/creditor |

### Not Notified (too noisy)

Individual reactions, regular chat messages, @xark silence.

### Infrastructure

- `src/lib/notifications.ts`: Firebase Admin SDK, `sendPush()`, lazy init from `FIREBASE_SERVICE_ACCOUNT_JSON`.
- `/api/notify`: Uses `get_push_tokens_for_space` RPC (single query).
- `public/firebase-messaging-sw.js`: Background notification handler.
- `public/sw.js`: Offline service worker. Caches app shell.

---

## 15. Security Hardening

### Authentication

- Firebase Auth (phone OTP) primary
- Dev-auto-login: JWT signed with jose. Gated by `DEV_MODE=true`. Blocked in production.
- JWT `sub` claim = user ID (text format: `name_ram`, `phone_xxxxx`)
- E2EE enabled only for phone-authenticated users (`phone_` prefix). Dev users (`name_` prefix) get legacy plaintext.

### Rate Limiting

Postgres-backed centralized rate limiter (`src/lib/rate-limit.ts`, migration 025):
- `check_rate_limit` RPC with sliding window
- Applied to: `/api/message` (10/min), `/api/xark` (10/min), `/api/phone-auth`, `/api/local-action`, `/api/notify`
- Keyed on verified JWT userId (after auth), not IP

### Row-Level Security (RLS)

All tables enforce RLS via shared `auth_user_space_ids()` SECURITY DEFINER function:
- Returns space_ids where `user_id = auth.jwt()->>'sub'`
- Bypasses RLS on inner query (prevents infinite recursion)
- `auth.jwt()->>'sub'` instead of `auth.uid()` (text IDs, not UUID)

### Content Security Policy

- Nonce-based CSP (no `unsafe-eval`/`unsafe-inline`)
- Pinned Supabase URL
- Request + response headers in middleware

### Input Validation

- `message_type_override` allowlist: e2ee, sender_key_dist
- `spaceTitle` sanitized before Gemini prompt injection
- Invite token entropy: 16 bytes (128-bit, migration 018)
- `window.open` URL protocol validation (https/http only)
- `tel:` scheme phone number sanitization
- Prototype pollution defense on decrypted payloads

### Privacy Cascades (migration 026)

- FK `ON DELETE CASCADE` for all user-owned data
- PII scrub trigger on soft delete (clears display_name, phone)
- IndexedDB shredding on logout (crypto keys, sessions, outbox)

### SECURITY DEFINER Lockdown (migration 024)

- `REVOKE PUBLIC` on all dangerous RPCs
- `fetch_key_bundle`, `revoke_device`, `purge_expired_xark_messages` require authenticated caller

---

## 16. Database Schema

### Foundation Tables (migration 001-013)

| Table | Purpose |
|-------|---------|
| `users` | id, display_name, phone, photo_url, preferences, created_at |
| `spaces` | id, title, atmosphere, owner_id, trip_dates, metadata, created_at |
| `space_members` | space_id, user_id, joined_at, last_read_at |
| `decision_items` | id, title, category, description, state, space_id, is_locked, weighted_score, agreement_score, ownership, commitment_proof, version, metadata, locked_at |
| `reactions` | id, item_id, user_id, signal, created_at |
| `messages` | id, space_id, role, content, user_id, sender_name, message_type, created_at |
| `media` | id, space_id, uploaded_by, storage_path, thumbnail_url, caption |
| `user_devices` | user_id, fcm_token, platform |
| `tasks` | id, title, assignee_id, space_id |
| `space_dates` | space_id, start_date, end_date |
| `space_ledger` | id, space_id, actor_id, action, payload, revert_target_id, created_at |

### E2EE Tables (migration 014-015)

| Table | Purpose |
|-------|---------|
| `key_bundles` | (user_id, device_id) -> identity_key, signed_pre_key, pre_key_sig |
| `one_time_pre_keys` | id, user_id, device_id, public_key |
| `message_ciphertexts` | message_id, recipient_id, device_id, ciphertext, nonce |
| `user_constraints` | id, user_id, type, value, dismissed |
| `space_constraints` | id, space_id, type, value, source_user_id |
| `constraint_prompts` | id, space_id, user_id, type, value, dismissed |

### Security Tables (migrations 016-026)

| Table | Purpose |
|-------|---------|
| `rate_limits` | key, window_start, count |

### Key RPCs

| RPC | Purpose |
|-----|---------|
| `fetch_key_bundle` | Atomic OTK consumption (FOR UPDATE SKIP LOCKED) |
| `revoke_device` | Device removal + pg_notify broadcast |
| `purge_expired_xark_messages` | TTL enforcement (30d post-trip, 90d open) |
| `get_latest_messages_per_space` | Single query for personal chat list |
| `get_push_tokens_for_space` | Single query for FCM tokens |
| `get_unread_counts` | Unread count per space (excludes own + system) |
| `mark_space_read` | Update last_read_at timestamp |
| `auth_user_space_ids` | Shared RLS helper (SECURITY DEFINER) |
| `check_rate_limit` | Sliding window rate limiter |
| `react_to_item` | Atomic upsert + score recalculation |

### Performance Optimizations (migration 012)

- Indexes: reactions.user_id, messages.space+created_at DESC
- Batched space-data queries: 4 total (members, users, items, messages via RPC) instead of 60+ N+1
- Awareness parallelized via Promise.all
- CategoryRail memoized with React.memo
- Lazy card images after first 3 per rail
- ControlCaret limited to 5 Presence channels

---

## 17. API Routes

| Route | Method | Service | Purpose |
|-------|--------|---------|---------|
| `/api/message` | POST | Messaging | Unified E2EE message endpoint (atomic ciphertext + broadcast) |
| `/api/xark` | POST | Intelligence | @xark invocation (Gemini + Apify orchestration). DISCONNECTED. |
| `/api/keys/bundle` | POST | Messaging | Key bundle upload (identity + signed pre-key + signature) |
| `/api/keys/otk` | POST | Messaging | OTK batch upload (100 per batch) |
| `/api/keys/fetch` | POST | Messaging | Atomic key bundle fetch via RPC |
| `/api/phone-auth` | POST | Auth | Firebase phone OTP verification |
| `/api/dev-auth` | POST | Auth | Dev login with password |
| `/api/dev-auto-login` | POST | Auth | Dev auto-login (DEV_MODE only) |
| `/api/join` | POST | Space | Invite join (validates token, creates user, signs JWT) |
| `/api/notify` | POST | Notification | Server-side FCM push trigger |
| `/api/og` | POST | Media | OG metadata extraction + optional insertAsItem |
| `/api/share` | POST | Space | PWA share target handler |
| `/api/local-action` | POST | Intelligence | Tier 1 mutation endpoint (dates, rename, revert) |
| `/api/cron/*` | GET | Platform | Scheduled tasks (CRON_SECRET verified) |

All other operations go through Supabase client directly with RLS enforcement via JWT.

---

## 18. Ghost Playground

Zero-Supabase sandbox for first-time users.

### Data (`src/lib/playground.ts`)

- 5 friends: leo, kai, ava, zoe, sam (with avatars + bios)
- 4 spaces: tokyo neon nights, dinner tonight, maya's birthday, weekend hike
- Detection: `isPlaygroundMode(spaces)` — true when no real spaces exist
- Client-side only, zero DB. Vanishes when first real space created.

### Choreography (`src/hooks/usePlaygroundChoreography.ts`)

- Timer-based whisper/message/typing choreography per space
- Diegetic whispers with breathing opacity 30->60% over 4s
- Trigger callbacks: postVote, postXark, postClaim, postPurchase
- All timers cleaned on unmount

### Components

- `PlaygroundSpace.tsx`: Complete playground view with mock reactions, mock @xark, swipe discuss<->decide
- `PlaygroundWhisper.tsx`: Breathing opacity dismissable hint
- `InlineCardPreview.tsx`: Miniature decision card for chat timeline

---

## 19. Invite & Join System

### Space Creation (`src/lib/spaces.ts`)

- `createSpace(dream, ownerId)`: Optimistic creation with `getOptimisticSpaceId(dream)` for instant navigation
- Seed item: "sunset at [destination]" or "explore [dream]"
- `createInviteLink(spaceId)`: Generates `/j/{token}` URL

### Join Flow (`/api/join`)

1. Validate invite token
2. Create user (or find existing by name)
3. Sign JWT (sub: user.id, role: authenticated)
4. Add to space_members
5. Redirect to space

### Share Flow

- PWA `share_target` in manifest.json
- `/api/share` -> `/share` page -> SpacePicker -> `/api/og` with insertAsItem
- Share Options Sheet: native share -> WhatsApp/SMS/Copy fallback

---

## 20. Dependency Graph

```
Infrastructure Layer
  firebase.ts (auth + storage)
  supabase.ts (database, anon key, Proxy pattern)
  supabase-admin.ts (service role, server only)

Crypto Layer (client-side only)
  crypto/primitives.ts (libsodium-wrappers-sumo)
  crypto/keystore.ts (IndexedDB + two-phase commit)
  crypto/encrypted-store.ts (Argon2id-wrapped AES-GCM)
  crypto/x3dh.ts (key agreement)
  crypto/double-ratchet.ts (1:1 forward secrecy)
  crypto/sender-keys.ts (group forward secrecy)
  crypto/key-manager.ts (registration, backup/restore)
  crypto/encryption-service.ts (high-level API + mutexes)
  crypto/sk-recovery.ts (Sender Key re-request)
  crypto/outbox.ts (offline message queue)
  crypto/dm-routing.ts (deterministic 1:1 IDs)

Business Logic Layer (zero coupling between services)
  Decision Engine domain:
    heart-sort.ts (ranking — pure functions, SSOT)
    state-flows.ts (FLOW_TERMINAL_STATES, resolveTerminalState)
    handshake.ts (consensus lock — Step 1)
    claims.ts (claim + purchase — Step 2)
  ai-grounding.ts (state map for @xark constraints)
  messages.ts (persistence + realtime + E2EE message types)
  ledger.ts (settlement math + payment deep links)
  spaces.ts (creation + optimistic routing + invite links)
  awareness.ts (cross-space events + time decay)
  intelligence/orchestrator.ts (Gemini + Apify three-tier)
  intelligence/tool-registry.ts (8 tools, 2 tiers)
  intelligence/apify-client.ts (actor runner)
  intelligence/sanitize.ts (PII redaction)
  media.ts (Firebase Storage upload/download)
  notifications.ts (FCM push)
  constraints.ts (on-device detection)
  unread.ts (WhatsApp-style counts)
  rate-limit.ts (Postgres-backed sliding window)

Data Enrichment Layer
  space-data.ts (space list, batched queries, RPCs)
  space-state.ts (emergent state computation)
  space-templates.ts (6 micro-space templates)
  playground.ts (Ghost Playground data)
  theme.ts (visual tokens, SSOT)

React Hooks Layer
  useAuth.ts (Firebase -> React)
  useE2EE.ts (E2EE lifecycle, encrypt/decrypt, graceful degradation)
  useHandshake.ts (consensus -> commitment -> React)
  useReactions.ts (JWT guard, per-item debounce)
  useKeyboard.ts (virtual keyboard height, Android/iOS)
  useVoiceInput.ts (SpeechRecognition, mic -> @xark)
  useDeviceTier.ts (low-end device detection)
  usePlaygroundChoreography.ts (timer-based sandbox)

UI Components Layer (src/components/os/)
  XarkChat.tsx (display-only chat stream)
  ChatInput.tsx (Magnetic Input, E2EE-first)
  PossibilityHorizon.tsx (Decide: snap-center card rails)
  DecisionCard.tsx (immersive decision card)
  ControlCaret.tsx (Living Brand Anchor, global nav)
  AwarenessStream.tsx (cross-space awareness)
  PeopleDock.tsx (personal chats)
  PlaygroundSpace.tsx (sandbox space)
  Blueprint.tsx (settled decisions + settlement)
  UserMenu.tsx (settings, theme, profile)
  ClaimSheet.tsx / PurchaseSheet.tsx (commitment UI)
  ConsensusMark.tsx (SVG consensus indicator)
  WelcomeScreen.tsx (cinematic login)
  InlineCardPreview.tsx / LedgerPill.tsx (chat embeds)
  ThemeProvider.tsx (CSS variable injection)
  GalaxyLayout.tsx (layout registry)

Pages Layer (thin orchestrators)
  /login (OTP or dev auth)
  /galaxy (awareness + people + playground)
  /space/[id] (discuss / decide / itinerary / memories)
  /j/[token] (invite join)
  /share (PWA share target)
  /demo (playground demo)
```

---

## 21. Hexagonal Architecture (Ports & Adapters)

Full source: `/Users/ramchitturi/algo` (198 tests, 0 type errors).

| Port | Interface | Production Adapter |
|------|-----------|-------------------|
| Persistence | `PersistencePort` | Supabase Postgres |
| Event Bus | `EventBusPort` | Supabase Realtime |
| Auth | `AuthPort` | Firebase Auth (OTP) |
| Cache | `CachePort` (optional) | Redis (future) |
| Messaging | `MessagingPort` | E2EE Signal Protocol |

- `DecisionService`: Stateless orchestrator. Load -> Compute (pure) -> Save -> Broadcast -> Invalidate.
- Optimistic concurrency: `version` field on every item. `VersionConflictError` (HTTP 409) on stale writes.

---

## 22. Known Issues & Next Steps

### Active Issues

| ID | Issue | Severity |
|----|-------|----------|
| K1 | @xark disconnected from UI — XarkSpotlight.tsx not built | High |
| K2 | WebAuthn PRF not implemented — encrypted store uses Argon2id password prompt | Medium |
| K3 | Unacked ratchet reconciliation on boot not wired | Medium |
| K4 | Pexels API key client-side (NEXT_PUBLIC) — needs server-side proxy | Low |
| K5 | Key rotation on member leave deferred to v2 | Low |
| K6 | geminiSearchGrounded uses regex JSON extraction (not responseMimeType) | Low |
| K7 | Local Intelligence (Tier 1/2) parked — needs browser debugging | Low |

### Next Steps (Priority Order)

1. **XarkSpotlight.tsx** — Dedicated @xark UI surface (separate from E2EE chat pipeline)
2. **Simplify /api/xark** for Spotlight — return structured JSON only
3. **WebAuthn PRF** — biometric unlock for encrypted store (replace password prompt)
4. **Unacked ratchet reconciliation** — retry pending sends or rollback state on boot
5. **Pexels API proxy** — move to server-side `/api/photos` route
6. **Guest Mode** — web view for invitees without app (existential for growth)
7. **First real users** — dinner use case

---

## 23. Deployment

| Target | Config |
|--------|--------|
| GitHub | `git@github.com:xarkdev9/xark.git` (remote: `new-origin`) |
| Vercel | project "xark" under scope "xarks-projects-700da30e" |
| Production URL | https://xark.vercel.app |
| Port | 3000 (locked, kill if occupied) |
| PWA | manifest.json, standalone display, safe-area padding, offline SW |

Push: `GH_TOKEN=$(gh auth token) git -c "http.https://github.com/.extraheader=Authorization: basic $(echo -n "x-access-token:$(gh auth token)" | base64)" push new-origin main`

Deploy: `vercel deploy --prod --scope xarks-projects-700da30e --yes`

### Environment Variables

All set on Vercel production:
- `NEXT_PUBLIC_FIREBASE_*` (6 vars) — Firebase client config
- `FIREBASE_SERVICE_ACCOUNT_JSON` — Server-side FCM + admin
- `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` — Supabase client
- `SUPABASE_SERVICE_ROLE_KEY` — Server-side admin (bypasses RLS)
- `GEMINI_API_KEY` — Gemini 2.5 Flash
- `APIFY_API_TOKEN` — Apify actors
- `PEXELS_API_KEY` — Hero images (currently client-side, needs proxy)
- `JWT_SECRET` — Dev-auto-login JWT signing
- `DEV_MODE` — Enables dev login (false in production)
- `CRON_SECRET` — Cron job verification

---

## 24. Migration History

| Migration | Purpose |
|-----------|---------|
| 001 | Foundation schema (users, spaces, space_members, decision_items, reactions, messages) |
| 002 | Functions + triggers (react_to_item, auto-add space owner) |
| 003 | RLS policies |
| 004-013 | Dev auth, media, system messages, invites, dates, logistics, reactions fix, perf, daily use |
| 014 | E2EE tables (key_bundles, one_time_pre_keys, message_ciphertexts, constraints) |
| 015 | E2EE wiring (fetch_key_bundle with otk_id, get_space_member_devices) |
| 016 | Security hardening (rate limiting, input validation) |
| 017 | Hybrid brain (space_ledger for Tier 1 local intelligence) |
| 018 | Security v2 (invite token 16 bytes) |
| 019 | Unread counts (last_read_at, get_unread_counts, mark_space_read) |
| 020-021 | Self-join fix, proposed_by trigger |
| 022 | Lane four wiring |
| 023 | E2EE RLS perf (direct column check for message_ciphertexts) |
| 024 | SECURITY DEFINER lockdown (REVOKE PUBLIC on dangerous RPCs) |
| 025 | Postgres-backed rate limiter |
| 026 | Privacy cascades (FK cascades, PII scrub trigger) |
