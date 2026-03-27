# XARK OS — Glossary

> Every term a new developer needs to understand the codebase.
> Organized by domain. Each entry: **Term** — what it means, where it lives, and the conventional equivalent.

---

## Navigation & Pages

| Term | Meaning | Where | Conventional Equivalent |
|------|---------|-------|------------------------|
| **Galaxy** | Home page (`/galaxy`). Tabs: People, Plans, Memories. | `src/app/galaxy/page.tsx` | Home, Dashboard |
| **Space** | A chat room for 1-15 people. Contains messages, decision items, and members. | `spaces` table, `/space/[id]` | Room, Channel, Group |
| **Sanctuary** | A 1:1 private chat. `spaces.atmosphere = 'sanctuary'`. Hides decide/itinerary tabs. Shows other person's name as title. | `awareness.ts`, space page | DM, Direct Message |
| **Spotlight** | Half-sheet overlay for invoking @xark. Opens from ControlCaret tap. Contains GhostInput with whisper pre-fill. | `SpotlightSheet.tsx`, `useSpotlight.ts` | Command palette, AI prompt |
| **discuss** | Chat view mode inside a space. Default for groups. | Space page | Chat view |
| **decide** | Horizontal card carousel view mode. Voting and reactions happen here. | Space page, `PossibilityHorizon.tsx` | Vote view, Poll view |

---

## Decision Engine

| Term | Meaning | Where | Conventional Equivalent |
|------|---------|-------|------------------------|
| **heartSort** | Ranking algorithm. Sorts items by `weightedScore` descending, locked items sink to end. | `src/lib/heart-sort.ts` | Priority sort, Rank algorithm |
| **weightedScore** | Numeric score derived from reactions: love_it (+5), works_for_me (+1), not_for_me (-3). Drives amber signal intensity. | `decision_items.weighted_score` | Vote score, Popularity |
| **agreementScore** | Fraction of group members who have reacted to an item (0.0 - 1.0). Triggers gold bloom at > 0.8. | `decision_items.agreement_score` | Consensus %, Engagement rate |
| **DecisionItem** | A proposal under group deliberation. Has title, category, state, reactions, ownership, and commitment data. | `decision_items` table | Item, Proposal, Option |
| **Possibility** | Simplified DecisionItem for UI rendering: id, title, imageUrl, weightedScore, agreementScore, isLocked. | `src/lib/heart-sort.ts` | Card data |
| **PossibilityHorizon** | Immersive snap-center horizontal card rails. Groups items by `search_label` or category. | `PossibilityHorizon.tsx` | Carousel, Card rail |
| **CategoryRail** | One horizontal scrollable section within PossibilityHorizon for a single category. | `PossibilityHorizon.tsx` | Carousel section |
| **DecisionCard** | Full-bleed card: 82% viewport width, clamp(320px, 50dvh, 440px) height, hero photo, cinematic gradient, 56px score. | `DecisionCard.tsx` | Option card |
| **isLocked / is_locked** | Boolean: item reached 80%+ consensus and is committed. | `decision_items.is_locked` | Finalized, Confirmed |
| **lock_deadline** | ISO timestamp. When countdown expires, auto-lock cron fires. | `decision_items.lock_deadline` | Deadline, Expiration |

---

## Reaction Signals

| Signal | Weight | Color | Meaning |
|--------|--------|-------|---------|
| **love_it** | +5 | Amber (`--xark-amber`) | Strong preference |
| **works_for_me** | +1 | Gray (`--xark-gray`) | Neutral acceptance |
| **not_for_me** | -3 | Orange (`--xark-orange`) | Rejection |

One reaction per user per item. Last reaction wins. Score can go negative.

---

## Consensus & Commitment

| Term | Meaning | Where | Conventional Equivalent |
|------|---------|-------|------------------------|
| **ConsensusState** | "seeking" (0-30%), "steady" (30-80%), "ignited" (>80%). Visual state of the ConsensusMark ring. | `heart-sort.ts`, `ConsensusMark` | Consensus level |
| **handshake** | Automated commitment at agreementScore > 80%. Step 1: lock item (no owner). Step 2: user claims it (owner stamped). | `src/lib/handshake.ts`, `useHandshake.ts` | Auto-commit, Consensus lock |
| **confirmHandshake()** | Executes lock step 1: `is_locked = true`, `state = "locked"`, no owner yet. | `handshake.ts` | Confirm consensus |
| **claim / claimItem()** | Manual lock step 2: stamps owner + optional proof (receipt, verbal). For BOOKING_FLOW, locked is intermediate. | `src/lib/claims.ts`, `ClaimSheet.tsx` | Assign owner |
| **Green-Lock** | The 2-step commitment protocol: consensus lock → claim with proof. | `claims.ts`, `handshake.ts` | Commitment protocol |
| **ownership** | Current owner: `{ ownerId, assignedAt, reason: "booker" | "transfer" }`. | `decision_items.ownership` | Assignment |
| **ownershipHistory** | Append-only audit trail of all ownership changes. | `decision_items.ownership_history` | Ownership log |
| **settlement** | Bill-splitting math. Groups locked items by owner, calculates who owes whom, generates Venmo/UPI deep links. | `src/lib/ledger.ts` | Bill split, Expense calculation |
| **DebtDelta** | One-way payment obligation: fromUser owes toUser a specific amount. | `ledger.ts` | Payment flow |
| **fairShare** | `totalSpent / memberCount`. The per-person equal split. | `ledger.ts` | Equal split |
| **LedgerPill** | Interactive system pill in the chat timeline for `space_ledger` events. Icon + actor + verb + undo. | `LedgerPill.tsx` | Activity message |

---

## Space Lifecycle (`SpaceState`)

Computed by `computeSpaceState(items[], tripDates?, expiresAt?)` in `src/lib/space-state.ts`. Pure function.

| State | Meaning | Conventional Equivalent |
|-------|---------|------------------------|
| **empty** | No decision items exist | Blank |
| **exploring** | All items proposed/voting, nothing locked | Brainstorming |
| **converging** | Mixed: some locked, some still voting | Partial consensus |
| **ready** | All items locked, no open voting | Finalized |
| **active** | Within trip dates AND has locked items | Live, In progress |
| **settled** | All items terminal AND dates past | Completed, Archived |

---

## State Flows

Defined in `src/lib/state-flows.ts`. Each flow maps states to terminal states.

| Flow | Path | Use Case |
|------|------|----------|
| **BOOKING_FLOW** | proposed → ranked → locked → claimed → purchased | Default. Group travel/booking. |
| **SIMPLE_VOTE_FLOW** | nominated → ranked → chosen | Simple poll. |
| **PURCHASE_FLOW** | researching → shortlisted → negotiating → purchased | Group shopping. |
| **SOLO_DECISION_FLOW** | considering → leaning → decided | Personal choice. |

`resolveTerminalState(state, flow?)` disambiguates shared states: "ranked" → "locked" (BOOKING) vs "chosen" (SIMPLE_VOTE).

---

## @xark AI System

| Term | Meaning | Where | Conventional Equivalent |
|------|---------|-------|------------------------|
| **@xark** | AI assistant (Gemini 2.5 Flash). Silent by default. Only responds when invoked with "@xark" prefix. | Throughout | AI bot, Assistant |
| **GroundingContext** | State map passed to @xark: locked items, votes, constraints, taste profiles, last 15 messages. | `src/lib/ai-grounding.ts` | Prompt context |
| **buildGroundingContext()** | Assembles full state map for @xark reasoning (Layer 3, non-encrypted). | `ai-grounding.ts` | Context builder |
| **generateGroundingPrompt()** | Formats GroundingContext into English for Gemini. | `ai-grounding.ts` | Prompt builder |
| **Whisper** | Proactive, deterministic suggestion from @xark (no LLM call). Priority queue: P0 consensus_ready, P1 missing_category, P2 onboarding/nudge. | `src/lib/whispers.ts`, `useWhispers.ts` | Hint, Nudge, Suggestion |
| **ghostText** | Pre-fill text in SpotlightSheet input. User can type to override or send to accept. | `whispers.ts`, `GhostInput.tsx` | Placeholder, Autocomplete |
| **three-tier intelligence** | Tier 1: regex (<1ms, `local-agent.ts`). Tier 2: lexical search (parked). Tier 3: Gemini cloud (7-50s). | `orchestrator.ts` | Routing hierarchy |
| **Constraint / DetectedConstraint** | On-device preference detection: dietary, budget, accessibility, alcohol. Conservative allowlists. Sender's device only. | `src/lib/constraints.ts` | User preference |
| **Taste Graph** | User's hard vetoes (union of constraints) + implicit weights (sum from reactions). Injected into Gemini prompt at search time. | `src/lib/taste.ts` | Preference model |
| **gemini-local** | Fast tier (~7-10s): direct Gemini knowledge for casual queries (coffee, bars, sunset spots). No Google Search. | `orchestrator.ts` | Fast AI path |
| **gemini-search** | Knowledge tier (~40-50s): Google Search grounding for factual queries. | `orchestrator.ts` | Search-augmented AI |
| **apify** | Booking tier (15-50s): Apify actors for hotels, flights, restaurants, activities. | `orchestrator.ts`, `apify-client.ts` | External data source |

---

## Visual Engine Signals

The Engine-to-Pixel Map. Each signal maps a decision metric to a visual effect.

| Term | Trigger | Effect | Conventional Equivalent |
|------|---------|--------|------------------------|
| **Amber** (`#F5A623`) | weightedScore > 0 | Gradient wash on DecisionCard. Intensity = score magnitude. | Score highlight |
| **Gold** (`#FFD700`) | agreementScore > 80% | Radial bloom on card. Gold pulsing border. | Celebration glow |
| **Green** (`#10B981`) | isLocked = true | Finality signal. Settles to Cloud Dancer. | Confirmed indicator |
| **Cyan** (`#40E0FF`) | @xark response | 4.5s ambient breathing. @xark sender name color. | AI indicator |
| **ConsensusMark** | agreementScore value | SVG ring: seeking (dashed amber) → steady (amber + cyan dot) → ignited (gold + gold dot) | Progress ring |
| **amberWash()** | weightedScore | Returns gradient overlay opacity (0-1 scale). | Score opacity |
| **goldBloom()** | agreementScore > 0.8 | Returns radial glow effect params. | Celebration effect |
| **goldBurst** | handshake confirmation | Rotating gold ring + particle spray animation. | Lock celebration |
| **breathe** | Always (idle state) | Infinite opacity cycle 0.7 ↔ 0.9 over 4.5s. Used by ControlCaret, whispers. | Pulse animation |

---

## Theme & Design Tokens

All defined in `src/lib/theme.ts`. Applied via `ThemeProvider.tsx` which sets CSS variables on `:root`.

### Themes

| Name | Mode | Style | Accent |
|------|------|-------|--------|
| **hearth** | Light | Flat (clean, WhatsApp-like) | Action Orange `#FF6B35` |
| **hearth_dark** | Dark | Flat | Cyan `#40E0FF` |
| **vibe** | Light | Depth (shadows, immersive) | Warm Orange `#E87040` |
| **vibe_dark** | Dark | Depth | Action Orange `#FF6B35` |

### Color System

| Token | What it is | Conventional Equivalent |
|-------|-----------|------------------------|
| **void** (`--xark-void`) | Background canvas color | Background color |
| **white** (`--xark-white`) | Primary text color (theme-aware: dark in light mode, light in dark mode) | Text color |
| **accent** (`--xark-accent`) | Brand identity color (per-theme) | Accent color |
| **ink.primary** | Solid text: names, titles | Primary text |
| **ink.secondary** | Solid text: message preview, descriptions | Secondary text |
| **ink.tertiary** | Solid text: metadata, timestamps, labels | Tertiary text |
| **ink.sender** | Solid text: sender name in chat | Sender name color |
| **surface.chrome** | Elevated UI: headers, input areas, modals | Toolbar background |
| **surface.canvas** | Content areas: chat, feed | Content background |
| **surface.recessed** | Wells: avatar backgrounds, input fields | Inset background |

### Utilities

| Function | What it does | Example |
|----------|-------------|---------|
| **textColor(alpha)** | `rgba(var(--xark-white-rgb), alpha)` — theme-aware text with opacity | `textColor(0.6)` for secondary |
| **accentColor(alpha)** | `rgba(var(--xark-accent-rgb), alpha)` — accent with opacity | `accentColor(0.3)` for wash |

### Type Scale

Source of truth: `text` object in `src/lib/theme.ts`. Applied via `style={{ ...text.body }}`. No Tailwind text-size classes.

| Token | Size | Use |
|-------|------|-----|
| **text.hero** | 1.5rem | Page titles |
| **text.spaceTitle** | clamp | Space headers |
| **text.listTitle** | 1rem | List item names |
| **text.body** | 0.75rem | Message body, descriptions |
| **text.subtitle** | 0.65rem | Secondary content |
| **text.label** | 0.6rem | Tab labels, section headers |
| **text.recency** | 0.5rem | Time ago labels |
| **text.timestamp** | 0.45rem | Inline timestamps |
| **text.input** | clamp | Input fields |
| **text.hint** | 0.6rem | Help text, onboarding |

### Special Tokens

| Token | What it is |
|-------|-----------|
| **foveal** | Opacity decay for older messages in chat. xark: [0.95, 0.90, 0.85, 0.80, 0.75]. user: [0.95, 0.90, 0.85, 0.78]. Floor: 0.70. |
| **Ember** | 4px glowing dot for presence indicator. `layout.emberSize`. |
| **timing.breath** | 4.5s — ControlCaret breathing cycle. |
| **timing.meshPulse** | 15s — GlobalMesh ambient cycle. |
| **timing.goldBurst** | 3s — Lock celebration duration. |
| **layout.maxWidth** | 640px — Content max-width. |

---

## Components

| Component | What it does | Conventional Equivalent |
|-----------|-------------|------------------------|
| **ControlCaret** | "xark" text (18px, weight 300, #FF6B35) floating at bottom-center. Breathing 0.7→0.9. Tap = Spotlight, long-press = space panel. Cyan aura when whispers pending. | Brand anchor, FAB |
| **GhostInput** | Input with ghost text pre-fill. Type = shatter ghost. Send = accept. | Autocomplete input |
| **ChatInput** | "Magnetic Input": gradient floor (transparent→canvas), 18px/300, @xark cyan detection, attach/camera animate out when typing, mic↔send crossfade. | Message composer |
| **XarkChat** | Display-only chat stream. WhatsApp-precision spacing: 20px different sender, 2px same sender, 4px name-to-message. Sender names 13px amber (humans) / cyan (@xark). Opacity floor 0.55. | Message list |
| **PeopleDock** | Sanctuary (DM) list on Galaxy People tab. Independent data fetching + Realtime subscription. | Chat list, DM list |
| **AwarenessStream** | Space summary list on Galaxy Plans tab. Priority-sorted cross-space events with time decay. | Activity feed |
| **GalaxyLayout** | Layout registry: "stream" (vertical default) vs "split" (chats left, awareness right). | Layout switcher |
| **ClaimSheet** | Slide-up for claiming a locked item. "i'll handle this" stamps owner. | Assignment modal |
| **PurchaseSheet** | Slide-up for purchase confirmation + amount entry. claimed → purchased. | Checkout modal |
| **InlineCardPreview** | Miniature decision card for chat timeline: 100px tall, photo left, score+title right. | Embedded card |
| **ConsensusTimer** | Live countdown timer on DecisionCard when `lock_deadline` is set. | Countdown timer |
| **ConsensusBanner** | Pinned banner above chat during consensus countdown. | Alert banner |
| **InviteSurface** | People tab empty state. Mesh gradient with "Invite someone" CTA. | Empty state |
| **PlaygroundSpace** | Ghost demo space: mock reactions, mock @xark, choreography engine. No Supabase. | Demo mode |
| **Avatar** | Reusable avatar component. Letter fallback on `surface.recessed`. | Avatar |
| **UserMenu** | Settings sheet: profile, notifications, theme toggles (flat/vibe + light/dark), about. | Settings menu |
| **GlobalMesh** | Ambient mesh gradient background, mounted in `layout.tsx`. | Background effect |

---

## E2EE Cryptography

All modules in `src/lib/crypto/`. Client-side only — never import on server.

| Term | Meaning | Conventional Equivalent |
|------|---------|------------------------|
| **Double Ratchet** | Per-message forward secrecy for 1:1 (sanctuary) chats. Root key → chain key → message key. | Key ratchet protocol |
| **Sender Keys** | Group encryption for 2-15 members. Sender signs messages with Ed25519. | Group session key |
| **X3DH** | Extended Triple Diffie-Hellman. 4-DH key agreement to establish shared secret between two devices. | Key exchange |
| **OTK** | One-Time Pre-Key. Curve25519. Consumed after use. Uploaded in batches of 100. | Ephemeral key |
| **SignedPreKey** | Medium-term Curve25519 key signed by Ed25519 identity key. | Signed pre-key |
| **IdentityKeyPair** | Ed25519 long-term signing key pair. Never ratcheted. | Identity key |
| **PublicKeyBundle** | User's public key material: identity + signed pre-key + OTK (optional). Fetched via `fetch_key_bundle` RPC. | Key bundle |
| **SessionState** | Double Ratchet state: rootKey, sendChainKey, recvChainKey, ratchet keys, message counters, skipped keys. | Session state |
| **SenderKeyState** | Group key state: chainKey + signingKey + iteration counter. | Group session |
| **EncryptedPayload** | `{ ciphertext, header?, senderKeyId? }` — encrypted message packet. | Ciphertext |
| **RatchetHeader** | Metadata with encrypted message: sender's ratchet public key + message counters. Now encrypted (was cleartext before Mar 17 fix). | Message header |
| **keystore** | IndexedDB-backed persistent key storage. Identity keys, sessions, sender keys, device ID. | Local key store |
| **MessageType** | `e2ee` (sanctuary), `xark` (@xark system), `system` (join/create events), `legacy` (plaintext, deprecated). | Message classification |

---

## Database Tables

| Table | Purpose | Conventional Equivalent |
|-------|---------|------------------------|
| **spaces** | Group/chat rooms. Columns: id, title, owner_id, atmosphere, metadata, last_activity_at. | rooms, channels |
| **space_members** | Membership join table: space_id + user_id + role. | members, participants |
| **decision_items** | Proposals under deliberation: title, category, state, ownership, scores. | items, proposals |
| **reactions** | Votes: item_id + user_id + signal + weight. PK = (item_id, user_id). | votes |
| **messages** | Chat messages: space_id, content, user_id, message_type. | messages |
| **message_ciphertexts** | E2EE encrypted payloads: message_id + ciphertext + device_id. | encrypted_messages |
| **key_bundles** | Public key material for E2EE key agreement. | public_keys |
| **one_time_pre_keys** | Single-use Curve25519 keys for X3DH. | ephemeral_keys |
| **space_ledger** | Audit trail: actor + verb + payload. Unencrypted Layer 3. | audit_log |
| **space_dates** | Trip dates: start, end, destination. | dates, schedule |
| **member_logistics** | Per-user trip logistics: flight, ground, visa status. | checklist |
| **summon_links** | Cryptographic invite links: code, creator, claimed boolean. | invite_links |
| **user_taste_profiles** | Constraint JSON + implicit weights from reactions. | preferences |
| **rate_limits** | Sliding-window rate limiting: key + timestamps. | rate_limits |

---

## Routes

### Pages

| Route | Purpose | Conventional Equivalent |
|-------|---------|------------------------|
| `/galaxy` | Home. People / Plans / Memories tabs. | `/home` |
| `/space/[id]` | Space detail: discuss + decide views. | `/room/[id]` |
| `/login` | Phone OTP authentication. | `/login` |
| `/s/[code]` | Summon landing: invitation + phone auth + claim. | `/invite/[code]` |
| `/j/[token]` | Quick join: name-only invite accept. | `/join/[token]` |
| `/share` | PWA share target: OG extraction + space picker. | `/share` |

### API

| Route | Purpose | Conventional Equivalent |
|-------|---------|------------------------|
| `POST /api/xark` | @xark AI: grounding → Gemini → response. | `/api/assistant` |
| `POST /api/message` | Unified E2EE message send. Atomic: ciphertext + insert. | `/api/messages` |
| `POST /api/chat/start` | WhatsApp-style find-or-create 1:1 chat. | `/api/dm/create` |
| `POST /api/contacts/check` | Phone number registration lookup. Returns userId, never display_name. | `/api/contacts/lookup` |
| `POST /api/local-action` | Tier 1 mutations: dates, rename, revert. Space ledger audit. | `/api/actions` |
| `POST /api/summon` | Generate 128-bit cryptographic invite link. | `/api/invite/create` |
| `GET /api/summon/validate` | Public: check invite code validity, return creator name. | `/api/invite/check` |
| `POST /api/summon/claim` | Firebase auth → atomic claim → space creation → JWT. | `/api/invite/accept` |
| `POST /api/join` | Name-only join: validate token → create user → JWT. | `/api/join` |
| `POST /api/notify` | FCM push notification to space members. | `/api/push` |
| `GET /api/og` | Server-side OG metadata extraction. | `/api/metadata` |
| `POST /api/taste` | Day 1 onboarding: Gemini parses natural language → JSONB constraints. | `/api/preferences` |
| `POST /api/cron/consensus` | Auto-lock expired countdowns. Daily cron. | `/api/cron/autolock` |
| `POST /api/keys/bundle` | Upload key bundle (identity + signed pre-key). | `/api/keys/upload` |
| `POST /api/keys/otk` | Upload OTK batch (100 keys). | `/api/keys/otk` |
| `GET /api/keys/fetch` | Atomic key bundle fetch (FOR UPDATE SKIP LOCKED). | `/api/keys/get` |

---

## Architecture Doctrines

| Doctrine | Rule |
|----------|------|
| **ZERO-BOX** | No borders, no `bg-white`, no `rounded-lg` on content. Information floats in atmospheric space. Separation = vertical distance. |
| **NO-BOLD** | `font-weight: 300` (secondary) and `400` (primary) only. 500+ is banned. Emphasis via size or opacity. |
| **E2EE Absolute Law** | NEVER bypass E2EE. Solo spaces encrypt to self. If encryption fails, message does not send. No exceptions. |
| **Hybrid Stack** | Firebase Auth (OTP) + Supabase Postgres (DB) + Firebase Storage (E2EE media) + FCM (push) + Gemini (AI). Supabase Auth is banned. |
| **Manifestation Loop** | Optimistic creation: navigate immediately, sync to DB in background. |
| **Port 3000** | Run ONLY on port 3000. If occupied, kill the process. Never jump to 3001. |
| **Theme tokens only** | All colors from `src/lib/theme.ts` CSS variables. No hardcoded hex in components. |
| **Type scale from theme.ts** | `style={{ ...text.body }}`. No Tailwind text-size classes. |
| **No backdrop-filter** | No blur anywhere. Overlays use `#000` at `opacity: 0.8`. |

---

## Specialized Patterns

| Term | Meaning |
|------|---------|
| **Manifestation Loop** | `createSpace()` navigates instantly, DB write happens in parallel. |
| **Playground** | Client-only demo data: 5 fake friends, 4 spaces, choreography engine. No Supabase. Vanishes when first real space is created. |
| **PlaygroundChoreography** | Timer-based animation sequencer: whispers → messages → typing → reactions per demo space. |
| **search_label** | Grouping key for @xark search results in PossibilityHorizon. Each query gets its own rail. |
| **search_batch** | Batch ID linking search results to the same @xark query. |
| **fovealOpacity** | Opacity decay function for chat messages. More recent = more visible. Floor = 0.70. |
| **DeviceTier** | "high" (3GB+ RAM, 4+ cores) or "low" (resource-constrained). From `useDeviceTier.ts`. |
| **PII sanitizer** | Redacts credit cards (Luhn), SSN, CVV, bank accounts before Gemini calls. `src/lib/intelligence/sanitize.ts`. |
