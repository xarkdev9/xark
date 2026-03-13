# Xark OS v2.0 — Architecture Blueprint

**Date**: 2026-03-13
**Scope**: Solo + Small Group (up to 15 members)
**Phase**: Post-Foundation (Phase 0 complete — schema, JWT, seed data, Realtime)

---

## 1. Service Boundaries

9 domain services. Each owns its data. No service reaches into another's tables. Communication via Supabase Realtime events or explicit API calls. All services are stateless where possible — state lives in Postgres.

| Service | Owns | Publishes | Consumes |
|---------|------|-----------|----------|
| **Auth** | `users`, `user_devices` | `user.created`, `user.updated` | — |
| **Space** | `spaces`, `space_members` | `member.joined`, `member.present` | `user.created`, `item.locked`, `item.purchased`, `message.created` (updates `last_activity_at`) |
| **Intelligence** | — (stateless orchestrator) | `search.results_ready` | `item.*`, `message.created` |
| **Decision Engine** | `decision_items`, `reactions` | `item.proposed`, `item.reacted`, `item.score_updated`, `item.locked`, `item.claimed`, `item.purchased`, `item.consensus_reached` | `search.results_ready` |
| **Messaging** | `messages` | `message.created` | — |
| **Media** | `media` | `media.uploaded` | — |
| **Notification** | reads `user_devices` | — | `item.locked`, `item.purchased`, `item.consensus_reached`, `message.created` |
| **Settlement** | reads `decision_items` + `space_members` (for true member count) | — | `item.purchased` |
| **Itinerary** | — (computed from purchased items + media) | `trip.completed` | `item.purchased`, `media.uploaded` |

**Key design decisions:**
- **Commitment is part of Decision Engine**, not a separate service. The commitment protocol (handshake, claims, ownership) writes to `decision_items` — the table the Decision Engine owns. Splitting it would create false boundaries. The existing `handshake.ts` and `claims.ts` are sub-modules of the Decision Engine domain.
- **Intelligence Service** is stateless — it orchestrates Gemini + Apify, then feeds results into Decision Engine as proposed items. Decision Engine doesn't know or care where items came from (user typed it, @xark proposed it, Apify fetched it — same `decision_items` row).
- **Space Service** consumes lifecycle events to keep `last_activity_at` current — this drives recency sorting in Galaxy and ControlCaret.
- **Settlement Service** reads `space_members` for true member count (not just payers) when calculating fair share.
- **Notification Service** consumes `item.consensus_reached` — the handshake proposal is a high-signal moment that deserves a push.

---

## 2. Emergent Space State

Spaces have no explicit phase field. State is computed from items:

| Computed state | Condition | UI behavior |
|---|---|---|
| **empty** | Zero items | Hero prompt, @xark ready |
| **exploring** | All items in proposed/voting | PossibilityHorizon active, voting open |
| **converging** | At least 1 locked/purchased, others still voting | Mixed — some settled, some open |
| **ready** | All core categories have a locked/purchased item | @xark can suggest "looks like you're set" |
| **active** | Purchased items have dates, current date is within range | Itinerary view, photo uploads, live expenses |
| **settled** | Trip dates passed, settlement calculated | Memory mode |

A single pure function `computeSpaceState(items[])` returns the current state. UI reacts accordingly.

For solo spaces: no consensus threshold. React = decide. "Ready to lock?" appears after any reaction.

Categories are open strings, not an enum. Hotel, Flight, Activity, Restaurant, Transport, Gift, Venue — whatever @xark or users create. @xark (Gemini) reasons about the state map and dynamically suggests new categories or adds to existing ones.

---

## 3. Intelligence Service — @xark + Gemini + Apify

### Privacy Rule (non-negotiable)
@xark is deaf until invoked. No passive listening. Ever.

### Context Model: "Read the Room When Called"
- **Tier 1 — Always available**: Grounding context from `ai-grounding.ts`. Items grouped by state, reaction counts, members. Decision data, not personal conversation.
- **Tier 2 — On invocation only**: Last 15 messages as conversational context. Only processed when someone types "@xark". Not stored by Gemini.
- **Tier 3 — Never**: Full chat history dump.

### Invocation Flow
```
User: "@xark find hotels near big bear under 200"
  1. API route /api/xark strips "@xark" prefix
  2. Build context: grounding state map + last 15 messages
  3. Gemini parses intent → { action: "search", tool: "hotel", params: { location, maxPrice } }
  4. Route to Apify actor via tool registry
  5. Apify returns results (name, price, image, rating, url)
  6. Gemini synthesizes response for user
  7. Results inserted as decision_items (state: "proposed", category: "Hotel")
  8. @xark responds: "found 4 hotels under $200. they're in your stream now."
  9. Realtime: PossibilityHorizon updates with new items
```

### Tool Registry
```
tools = {
  hotel:      { actorId: "apify/hotel-scraper",      paramMap: fn },
  flight:     { actorId: "apify/flight-scraper",      paramMap: fn },
  activity:   { actorId: "apify/activity-finder",     paramMap: fn },
  restaurant: { actorId: "apify/restaurant-search",   paramMap: fn },
  general:    { actorId: "apify/web-scraper",         paramMap: fn },
}
```
New Apify actors added by registering them. No code change to orchestration logic.

### Non-Search Invocations
- "@xark what does the group think?" → Gemini reads grounding context, summarizes reaction state. No Apify.
- "@xark who hasn't voted yet?" → Reads member list + reactions. Pure reasoning.
- "@xark add kayaking at la jolla" → Direct item insert, no search.

### Voice Input
Two paths based on interaction:

- **Tap mic** → Browser `SpeechRecognition` API (on-device, instant). Text result enters normal pipeline. If contains "@xark", Gemini is invoked.
- **Long-press mic** → @xark breathing pulse (4.5s cyan cycle), placeholder shifts to "@xark is listening..." Audio blob sent to Gemini multimodal (speech-to-understanding, one hop). @xark invocation is automatic.

99% of inputs take the on-device path. Long-press exists for thick accents, mixed languages, ambient noise.

---

## 4. Decision Engine — Items, Reactions, Consensus, Commitment

The Decision Engine owns the full item lifecycle: proposing, voting, locking, claiming, and purchasing. The commitment protocol (`handshake.ts`, `claims.ts`) is a sub-domain — not a separate service — because it writes to `decision_items`.

### Item Lifecycle (open string states)

The existing codebase defines four parallel flows with different terminal states. The new `claimed` and `purchased` states extend BOOKING_FLOW. Other flows retain their own terminals.

**BOOKING_FLOW** (default, extended):
```
proposed → [voting] → locked → claimed → purchased
```

**PURCHASE_FLOW** (research-heavy):
```
researching → shortlisted → negotiating → purchased
```

**SIMPLE_VOTE_FLOW** (no purchase needed):
```
nominated → ranked → chosen
```

**SOLO_DECISION_FLOW** (1 person):
```
considering → leaning → decided
```

All flows allow skipping to terminal state via direct commitment. States are open strings (not enum) for custom flows.

**New states added to FLOW_TERMINAL_STATES map:**
- `locked` is NO LONGER terminal in BOOKING_FLOW — it is an intermediate state (consensus reached, no owner)
- `claimed` is intermediate (owner stamped, going to purchase)
- `purchased` is the new terminal for BOOKING_FLOW
- `is_locked` boolean is set `true` at `locked` state and remains `true` through `claimed`/`purchased`

**Shared module required:** Extract `FLOW_TERMINAL_STATES` and `resolveTerminalState()` into `src/lib/state-flows.ts`. Both `handshake.ts` and `claims.ts` import from there. Eliminates current duplication.

### Item States Explained

- **proposed**: Item exists. Zero reactions. In PossibilityHorizon.
- **voting** (implicit): Has reactions, hasn't hit threshold. Scores updating via heart-sort.
- **locked**: agreementScore crossed 80%. Group confirmed. No owner. "the cabin is locked. waiting for someone to own it."
- **claimed**: Someone stepped up. Owner stamped. Going to buy/book.
- **purchased**: Proof + amount submitted. "the cabin is booked. [name] paid $450." Feeds settlement.

### Two Item Sources
1. **Apify results** — @xark fetches hotels/flights/activities. Each result becomes a `decision_item` with image, price, description, external URL. Batch insert.
2. **Manual propose** — user types "@xark add kayaking" or uses propose input. Single insert.

Both land in the same table, same lifecycle. PossibilityHorizon doesn't know the difference.

### Reaction Math (from constitution)
- Love It: +5 (amber)
- Works For Me: +1 (gray)
- Not For Me: -3 (orange)
- One reaction per user per item. Last wins.
- `agreementScore` = unique reactors / total members
- `weightedScore` = sum of all reaction weights
- heart-sort ranks by weightedScore descending

**Implementation note:** The reactions write path and score recalculation do not exist in the app yet. The `react_to_item` RPC exists in Postgres (002_functions_triggers.sql) and handles upsert + score recalculation atomically. The app-side `addReaction()` / `removeReaction()` functions need to be ported from `/Users/ramchitturi/algo`. This is a Phase 3 deliverable.

### Consensus Threshold
- Solo spaces: no threshold. React = decide. "Ready to lock?" after any reaction.
- Group spaces (2-15): 80%. Handshake fires automatically.

### Two-Step Commitment
```
Step 1 — Consensus Lock (automated):
  agreementScore > 0.80
  → @xark: "consensus reached on [title]. shall i lock this in?"
  → Group confirms
  → state: "locked", is_locked: true, no owner
  → @xark: "locked. waiting for someone to own it."

Step 2 — Claim + Purchase (manual):
  → Someone taps "i'll handle this" on the locked item
  → state: "claimed", owner stamped
  → They book/buy in the real world
  → Return with proof + amount ("how much?" input with cyan underline)
  → state: "purchased"
  → @xark: "[name] booked [title] for $450."
  → Amount feeds settlement ledger
```

---

## 5. Messaging Service

### Message Types
- `role: "user"` — human chat messages
- `role: "xark"` — @xark responses (only when invoked)
- `role: "system"` — lifecycle events, rendered at opacity 0.25, text.subtitle

### System Messages (new)
Events the group should see but nobody typed:
- "[name] joined the space"
- "[title] is locked. waiting for someone to own it."
- "[name] claimed [title]"
- "[name] booked [title] for $[amount]"

### Chat Contexts
- **Group chat** — all members. Left-aligned for others, right-aligned for you.
- **Sanctuary** — 1:1 private stream via Sanctuary Bridge (tap sender name).
- **@xark** — inline in group chat. Just another participant, not a separate channel.

### Realtime
Supabase Realtime subscription on INSERT to messages table. Already wired in `messages.ts`.

---

## 6. Media Service

### Profile Photos (auth-time)
- Upload on first login or skip.
- Firebase Storage: `profiles/{userId}/avatar`
- URL stored in `users.photo_url`
- Max 2MB, compressed client-side.

### Trip Photos (during active trip)

New table:
```sql
media (
  id text PK,
  space_id text references spaces(id),
  uploaded_by text references users(id),
  storage_path text,
  thumbnail_url text,
  caption text,
  created_at timestamptz
)
```

- Firebase Storage: `spaces/{spaceId}/media/{mediaId}`
- Upload via floating "add photo" hint (text.hint, opacity 0.35). No button. No box.
- Photos appear in horizontal scroll during active trip.
- No editing, no filters, no albums. Upload, caption, scroll. Raw memories.

---

## 7. Notification Service

### FCM Registration
On login success: request notification permission → get FCM token → store in `user_devices(user_id, fcm_token, platform, created_at)`.

### Trigger Points

| Event | Message | Recipients |
|---|---|---|
| Consensus reached | "the group is aligned on [title]" | All space members |
| Item locked | "[title] is locked. who's going to book it?" | All space members |
| Item purchased | "[name] booked [title] for $[amount]" | All space members |
| @xark results ready | "found N [category] options" | The person who asked |
| Member joined | "[name] joined [space title]" | All existing members |
| Settlement ready | "trip settled. [name] owes you $[amount]" | Individual debtor/creditor |

### Not Notified (too noisy)
- Individual reactions
- Regular chat messages
- @xark silence

### Service Worker
`public/firebase-messaging-sw.js` — background notifications. Tap → deep link to space.

---

## 8. Settlement Service

### Existing (ledger.ts)
- `fetchSettlement(spaceId)` — sums purchased item amounts per owner
- `DebtDelta` — who owes whom
- `generateVenmoLink()`, `generateUPILink()` — payment deep links

### Amount Entry Flow
After confirming purchase (Step 2 of commitment):
1. "how much?" input appears with cyan underline
2. User types amount (e.g., "450")
3. Optional floating text toggle: "per night" / "per person" / "total"
4. Stored in `decision_items.metadata.price`
5. Settlement math recalculates

### Settlement View
Lives in Blueprint. Per-user totals, debt deltas, venmo/upi floating cyan text links.

---

## 9. Itinerary + Memories

### During Planning
No itinerary view. Items live in PossibilityHorizon (proposed/voting) and Blueprint (locked/purchased).

### During Active Trip
Itinerary = purchased items ordered chronologically by `metadata.date`:
```
Mar 15  ✦ Hotel Del Coronado — 3 nights, $450/nt (ram)
Mar 16  ✦ Surf lessons at La Jolla — $95/person (myna)
Mar 17  ✦ Gaslamp Quarter dinner — $65/person (myna)
```
Each row: title, cost, owner. Tap to expand (proof, description, link). `✦` is ConsensusMark ignited (gold).

Photo uploads active. Photos interspersed with itinerary by date.

### Post-Trip (Memories)
Itinerary shrinks to a subtle "trip details" link (floating text, opacity 0.25). The view is purely photos flowing in horizontal scroll, grouped by date.

Tap "trip details" → expands itinerary + settlement + payment links.

Photos are the story. Logistics are the footnote.

---

## 10. Space Templates

| | Solo | Small Group (2-15) |
|---|---|---|
| Consensus threshold | None — react = decide | 80% |
| Handshake | "Ready to lock?" after any reaction | Auto at 80% |
| Chat | Journal mode (notes + @xark) | Group stream |
| Roles | Just you | owner / member |
| Reactions display | Your preference only | Individual names + signals |
| Settlement | N/A | Full — debt deltas + payment links |
| Notifications | @xark results only | Key lifecycle events |

Template is derived from member count, not explicitly set. 1 member = solo. 2+ = small group.

---

## 11. Event Bus

Supabase Realtime (Postgres NOTIFY/LISTEN → WebSocket channels).

Channel pattern: `space:{spaceId}` — all events for a space flow through one channel. Clients subscribe on space entry, unsubscribe on exit.

Presence: Supabase Realtime Presence on the same channel. Heartbeat drives Presence Ember (4px cyan dot on avatars).

No external message queue needed at this scale. Supabase Realtime handles solo + 15-member groups. If scaling beyond, the event bus is an interface (EventBusPort in hexagonal architecture) — swap to Redis/WebSocket without touching business logic.

---

## 12. Known Bugs & Required Fixes

These exist in the current codebase and must be fixed during implementation:

**B1. State string casing in ai-grounding.ts:**
`checkSuggestionConflicts()` filters on `"Locked"` / `"Finalized"` (capitalized) but the database stores lowercase (`"locked"`, `"purchased"`, etc.). The function currently matches nothing. Fix: use lowercase and include all terminal states.

**B2. generateGroundingPrompt still uses forbidden categories approach:**
The blueprint and GROUNDING_PROTOCOL.md describe the state map approach, but the implementation in `ai-grounding.ts` still uses rigid `"Do NOT suggest alternatives"` directives. Needs rewrite to group items by state and let Gemini reason about scope.

**B3. Settlement member count uses payer count, not true member count:**
`ledger.ts` sets `memberCount = entries.length` (only people who paid). Should query `space_members` for the actual group size to calculate fair share correctly.

**B4. Space creator not added to space_members:**
`spaces.ts` inserts into `spaces`, `decision_items`, and `messages` but never inserts the creator into `space_members`. The `trg_auto_add_space_owner` trigger handles this on INSERT but not on upsert conflict. Verify this path works for all creation flows.

---

## 13. New Database Objects

Beyond the existing schema (001_foundation_schema.sql):

```sql
-- Media table for trip photos
media (
  id text PK,
  space_id text references spaces(id),
  uploaded_by text references users(id),
  storage_path text NOT NULL,
  thumbnail_url text,
  mime_type text NOT NULL default 'image/jpeg',
  caption text,
  created_at timestamptz default now()
)

-- FCM device tokens
user_devices (
  user_id text references users(id),
  fcm_token text NOT NULL,
  platform text default 'web',
  created_at timestamptz default now(),
  PRIMARY KEY (user_id, fcm_token)
)
```

Existing `decision_items.metadata` gains:
- `price` (string, e.g., "$450/nt") — already used by seed data
- `date` or `check_in` / `check_out` (ISO string) — for itinerary ordering
- `image_url` (string) — Apify result photo for PossibilityHorizon
- `external_url` (string) — link to hotel/flight/activity booking page
- `source` (string) — "apify", "manual", "xark" — origin tracking

Existing `decision_items` state additions: `"claimed"`, `"purchased"` join the open string state field.

---

## 14. RLS Policies (Required)

Row Level Security enforces privacy at the database level. Minimum policies for v1:

- **messages**: SELECT/INSERT only for `space_members` of the message's `space_id`
- **decision_items**: SELECT for space members. INSERT (propose) for space members. UPDATE (claim/purchase) for space members.
- **reactions**: SELECT/INSERT/UPDATE for space members of the item's space. DELETE own reactions only.
- **spaces**: SELECT for members. INSERT for authenticated users. UPDATE for owner only.
- **space_members**: SELECT own memberships + co-members in shared spaces (via `get_visible_users()` RPC).
- **media**: SELECT/INSERT for space members.
- **users**: SELECT own row. Co-member names/photos via RPC.

Enforced via JWT `sub` claim matching `auth.uid()::text`. Service role bypasses RLS (for seed, @xark injection, notifications).

---

## 15. API Routes

| Route | Service | Purpose |
|---|---|---|
| `POST /api/xark` | Intelligence | @xark invocation — Gemini + Apify orchestration |
| `POST /api/dev-auth` | Auth | Dev login with password (exists) |
| `POST /api/dev-auto-login` | Auth | Dev auto-login (exists) |
| `POST /api/notify` | Notification | Server-side push trigger |
| `POST /api/media/upload` | Media | Signed URL generation for Firebase Storage |

All other operations go through Supabase client directly (reactions, messages, items, members) with RLS enforcement via JWT.

---

## 16. Dependency Graph

```
Infrastructure Layer
  firebase.ts (auth + storage)
  supabase.ts (database, anon key)
  supabase-admin.ts (service role, server only)

Business Logic Layer (zero coupling between services)
  Decision Engine domain:
    heart-sort.ts (ranking — pure functions)
    state-flows.ts (new — shared FLOW_TERMINAL_STATES, resolveTerminalState)
    handshake.ts (consensus lock — Step 1, imports state-flows)
    claims.ts (claim + purchase — Step 2, imports state-flows)
  ai-grounding.ts (constraints — reads from supabase)
  messages.ts (persistence + realtime)
  ledger.ts (settlement math)
  spaces.ts (creation + optimistic routing)
  awareness.ts (cross-space events)
  intelligence/ (new — Gemini + Apify orchestrator)
  media/ (new — Firebase Storage upload/download)
  notifications/ (new — FCM push)

Data Enrichment Layer
  space-data.ts (space list + computed state)
  theme.ts (visual tokens, zero dependencies)

React Hooks Layer
  useAuth.ts (Firebase → React)
  useHandshake.ts (consensus → commitment → React)

UI Components Layer
  XarkChat.tsx (messaging + handshake + @xark)
  ControlCaret.tsx (navigation + presence)
  PossibilityHorizon.tsx (voting surface — parallel session for design)
  Blueprint.tsx (settled decisions + settlement)
  ConsensusMark.tsx (visual indicator)

Pages Layer (thin orchestrators)
  /login (OTP or dev auth)
  /galaxy (awareness stream + space creation)
  /space/[id] (discuss / decide / itinerary toggle)
```

---

## 17. PossibilityHorizon Design (Parallel Session)

The reaction surface (Love It / Works For Me / Not For Me) on PossibilityHorizon is the most critical UX in the app. It requires dedicated visual design exploration.

**Prompt for parallel session:**

> Design the PossibilityHorizon reaction surface for Xark OS. This is an Airbnb-style horizontal scroll of edge-to-edge images (hotels, flights, activities) where users vote Love It (+5, amber), Works For Me (+1, gray), or Not For Me (-3, orange). One reaction per user per item. Constraints: Zero-Box doctrine (no borders, no buttons, no cards, no rounded containers). No AI-looking icons. No old-age thumbs up. The reactions must be woven into the image experience — almost invisible until needed, creatively placed to save screen space. The scroll must feel premium, tactile, and fast. Images snap-scroll (snap-x, snap-mandatory, snap-center). Each item shows: edge-to-edge image with bottom vignette, title, price, source. Reaction signals as floating text, not buttons. Tapped reaction glows to full opacity, others fade to 0.2. Constitutional rules: all sizes from theme.ts text tokens, all colors from theme.ts colors object, font-weight 300/400 only, no backdrop-filter. Read CLAUDE.md and CONSTITUTION.md for full visual law. Read src/lib/theme.ts for all available tokens.

---

## 18. Implementation Order

Recommended sequence (each is its own spec → plan → build cycle):

1. **Living Home Screen** (Galaxy + ControlCaret rewrite) — reads from existing seed data, all UI
2. **Intelligence Service** (/api/xark + Gemini + Apify tool registry + voice input)
3. **Decision Engine** (reactions write path + heart-sort port + propose UI)
4. **PossibilityHorizon** (parallel session — Airbnb scroll + reaction surface)
5. **Commitment Flow** (two-step: consensus lock → claim → purchase + amount entry)
6. **Sharing + Joining** (share link + guest join + auto-membership)
7. **Handshake Verification** (already built — verify with real reaction data)
8. **Media Service** (profile photos + trip photo uploads)
9. **Notification Service** (FCM registration + push triggers)
10. **Settlement + Itinerary** (amount entry UI + itinerary view + memories)
11. **Guardrail Sync** (update CLAUDE.md, CONSTITUTION.md, .xark-state.json)
