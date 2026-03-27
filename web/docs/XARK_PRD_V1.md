# Xark OS v1.0 — Product Requirements Document

**Version**: 1.0
**Date**: March 15, 2026
**Status**: Pre-Launch
**Target**: First 100 users, scaling to 10,000

---

## 1. Executive Summary

### What is Xark?

Xark is a **biocompatible Group Operating System** — a Human Companion that helps groups of people make decisions together. It is not a dashboard, not a project manager, not a chat app. It is the nervous system for group coordination: trips, dinners, events, purchases, and every moment where humans need to align.

### Core Philosophy

> "No gates. No votes. No clustering. Just signal, act, lock."

Traditional group coordination tools (WhatsApp polls, Google Sheets, Splitwise) fragment the decision process across multiple apps. Xark unifies the entire lifecycle — from "let's go somewhere" to "here's the Venmo link" — in a single atmospheric interface that feels like breathing, not clicking.

### Design Doctrine

- **Zero-Box**: No borders, no cards, no rounded containers on feed items. Information floats in atmospheric space. Separation is achieved through vertical distance, not lines.
- **No-Bold Mandate**: Hierarchy via scale, spacing, and opacity only. Font-weight 500+ is banned. Weight 400 (regular) and 300 (light) only.
- **Liquid Feed**: A vertical stream of information flowing in space, not boxes stacked in a grid.
- **Atmospheric Washes**: Background gradients driven by engine state replace static backgrounds.

### v1 Scope

| In Scope | Out of Scope |
|----------|-------------|
| Solo + Small Group (1-15 members) | Large groups (15+) |
| Trip, dinner, event, purchase coordination | Enterprise features |
| @xark AI research (hotels, flights, activities, restaurants) | Personal calendar integration |
| Real-time group chat + decision engine | E2E encryption at message level |
| Push notifications (FCM) | Email notifications |
| PWA (iOS + Android install) | Native app store distribution |
| Settlement ledger (Venmo/UPI links) | In-app payment processing |
| Photo memories | Video memories |
| 4-theme system (hearth, hearth_dark, vibe, vibe_dark) | Custom user themes |

---

## 2. Technology Stack

### Frontend

| Technology | Version | Purpose |
|-----------|---------|---------|
| Next.js | 16.1.6 | Full-stack React framework (App Router) |
| React | 19.2.3 | UI library |
| TypeScript | 5.x | Type safety |
| Tailwind CSS | 4.x | Utility-first CSS |
| Framer Motion | 12.35.2 | Animation library |

### Backend & Infrastructure (Hybrid Stack)

| Component | Provider | Why |
|-----------|----------|-----|
| **Phone OTP Auth** | Firebase Auth | Flawless SMS delivery, session management |
| **Database** | Supabase Postgres | SQL required for heart-sort ranking math, RLS policies |
| **Binary Storage** | Firebase Storage | High-performance CDN delivery, bucket-level security |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Native iOS/Android push |
| **AI Intelligence** | Gemini 2.5 Flash (`gemini-2.5-flash`) | @xark deep research, intent parsing, synthesis |
| **Search/Booking Data** | Apify Actors | Hotel, flight, activity, restaurant scraping |
| **Realtime Sync** | Supabase Realtime | WebSocket-based Postgres NOTIFY/LISTEN |
| **JWT Signing** | jose (v6.2.1) | Dev auth token generation |

**Architectural Lock**: This hybrid is non-negotiable. Firebase handles auth + storage + push. Supabase handles database + realtime. They do not overlap. Supabase Auth is **banned**.

### Deployment

| Component | Target |
|-----------|--------|
| Frontend + API Routes | Vercel (Next.js) |
| Database | Supabase Cloud |
| Firebase Services | Firebase Cloud |
| PWA Distribution | Web (installable via Add to Home Screen) |

---

## 3. Architecture

### 3.1 Service Boundaries

9 domain services, each owning its data. No service reaches into another's tables. Communication via Supabase Realtime events or explicit API calls.

```
                    ┌──────────────────────────────────────────────────┐
                    │                    CLIENT (PWA)                   │
                    │  Next.js App Router + React 19 + Framer Motion    │
                    └─────────────────────┬────────────────────────────┘
                                          │
                    ┌─────────────────────┼────────────────────────────┐
                    │              API Routes (Next.js)                 │
                    │  /api/xark  /api/notify  /api/join  /api/og       │
                    │  /api/share  /api/dev-auto-login  /api/phone-auth │
                    └─────────────────────┬────────────────────────────┘
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        │                                 │                                 │
  ┌─────┴─────┐                    ┌──────┴──────┐                  ┌───────┴───────┐
  │  Firebase  │                   │  Supabase   │                  │    Gemini     │
  │  Auth      │                   │  Postgres   │                  │  2.5 Flash    │
  │  Storage   │                   │  Realtime   │                  │  + Apify      │
  │  FCM       │                   │  RLS        │                  │  Actors       │
  └───────────┘                    └─────────────┘                  └───────────────┘
```

### Service Table

| Service | Owns | Publishes | Consumes |
|---------|------|-----------|----------|
| **Auth** | `users`, `user_devices` | `user.created` | — |
| **Space** | `spaces`, `space_members` | `member.joined`, `member.present` | `item.locked`, `message.created` |
| **Intelligence** | — (stateless) | `search.results_ready` | `item.*`, `message.created` |
| **Decision Engine** | `decision_items`, `reactions` | `item.proposed`, `item.reacted`, `item.locked`, `item.claimed`, `item.purchased`, `item.consensus_reached` | `search.results_ready` |
| **Messaging** | `messages` | `message.created` | — |
| **Media** | `media` | `media.uploaded` | — |
| **Notification** | reads `user_devices` | — | `item.locked`, `message.created` |
| **Settlement** | reads `decision_items` + `space_members` | — | `item.purchased` |
| **Itinerary** | — (computed) | `trip.completed` | `item.purchased`, `media.uploaded` |

### 3.2 Event Bus

Supabase Realtime (Postgres NOTIFY/LISTEN over WebSocket). Channel pattern: `space:{spaceId}`.

Published tables: `messages`, `decision_items`, `space_members` (via Supabase Realtime publication).

### 3.3 Data Flow: User Action to UI Update

```
User taps "Love it" on Hotel Del Coronado
  → Client: supabase.from("reactions").upsert(...)
  → Postgres: trigger recalculates weighted_score on decision_items
  → Supabase Realtime: broadcasts UPDATE on decision_items channel
  → All connected clients: PossibilityHorizon re-renders card with new score
  → If agreement_score > 80%: useHandshake fires HandshakeProposal
  → @xark whisper: "consensus reached on Hotel Del. shall i lock this in?"
  → User taps "confirm"
  → handshake.ts: confirmHandshake() → updates state to "locked"
  → Social Gold burst animation on all clients
  → Push notification to all members via /api/notify
```

---

## 4. Database Schema

### 4.1 Core Tables

```sql
-- Users (Firebase Auth is source of truth for authentication)
users (
  id text PRIMARY KEY,                    -- "name_ram", "phone_+1234567890"
  display_name text NOT NULL,
  photo_url text,
  phone text UNIQUE,
  password_hash text,                     -- dev auth only
  preferences jsonb DEFAULT '{}',         -- { theme, muted_spaces[] }
  created_at timestamptz DEFAULT now()
)

-- Spaces (a group decision context)
spaces (
  id text PRIMARY KEY,
  title text NOT NULL,
  owner_id text REFERENCES users(id),
  atmosphere text,                        -- computed space vibe
  is_public boolean DEFAULT false,
  photo_url text,
  metadata jsonb DEFAULT '{}',            -- { hero_url, template, expiresAt }
  last_activity_at timestamptz,
  invite_token text UNIQUE,               -- for invite links
  created_at timestamptz DEFAULT now()
)

-- Space Members (who is in which space)
space_members (
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  role text DEFAULT 'member',
  joined_at timestamptz DEFAULT now(),
  PRIMARY KEY (space_id, user_id)
)

-- Decision Items (things the group is deciding on)
decision_items (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  title text NOT NULL,
  category text,                          -- open string: hotel, flight, activity, etc.
  description text,
  state text DEFAULT 'proposed',          -- open string for custom flows
  proposed_by text REFERENCES users(id),
  proposed_at timestamptz DEFAULT now(),
  weighted_score float DEFAULT 0,
  agreement_score float DEFAULT 0,
  is_locked boolean DEFAULT false,
  locked_at timestamptz,
  commitment_proof jsonb,                 -- { type, value, submittedBy, submittedAt }
  ownership jsonb,                        -- { ownerId, assignedAt, reason }
  ownership_history jsonb DEFAULT '[]',   -- append-only audit trail
  version integer DEFAULT 0,             -- optimistic concurrency
  metadata jsonb DEFAULT '{}',            -- { price, url, image_url, search_batch, search_label, ... }
  created_at timestamptz DEFAULT now()
)

-- Reactions (user signals on decision items)
reactions (
  item_id text REFERENCES decision_items(id) ON DELETE CASCADE,
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  signal text NOT NULL,                   -- love_it, works_for_me, not_for_me
  weight integer NOT NULL,                -- +5, +1, -3
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (item_id, user_id)          -- one reaction per user per item
)

-- Messages (group chat)
messages (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  role text NOT NULL,                     -- user, assistant (@xark)
  content text NOT NULL,
  user_id text,
  sender_name text,
  created_at timestamptz DEFAULT now()
)

-- Tasks (non-decidable assignments)
tasks (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  title text NOT NULL,
  assignee_id text REFERENCES users(id),
  created_at timestamptz DEFAULT now()
)

-- Media (photos/files metadata — blobs in Firebase Storage)
media (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  user_id text REFERENCES users(id),
  file_path text NOT NULL,               -- Firebase Storage path
  file_type text,
  caption text,
  created_at timestamptz DEFAULT now()
)

-- User Devices (FCM push tokens)
user_devices (
  id text PRIMARY KEY,
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  created_at timestamptz DEFAULT now()
)

-- Member Logistics (per-member trip details)
member_logistics (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  arrival_date date,
  departure_date date,
  notes text,
  updated_at timestamptz DEFAULT now()
)
```

### 4.2 Row-Level Security (RLS)

All SELECT policies use a shared `SECURITY DEFINER` function to avoid infinite recursion:

```sql
-- Shared function: returns space_ids where user is a member
CREATE FUNCTION auth_user_space_ids()
RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT array_agg(space_id) FROM space_members
  WHERE user_id = auth.jwt()->>'sub'
$$;
```

User IDs are text (e.g., `"name_ram"`), not UUID, so policies use `auth.jwt()->>'sub'` instead of `auth.uid()`.

### 4.3 Performance RPCs

```sql
-- Single query replaces unbounded fetch for personal chats
get_latest_messages_per_space(p_space_ids text[])
  → Returns DISTINCT ON (space_id) last message per space

-- Single query replaces 2-query chain for push notifications
get_push_tokens_for_space(p_space_id text, p_exclude_user text)
  → Returns FCM tokens for eligible (non-muted) members
```

### 4.4 Indexes

```sql
idx_messages_space_created ON messages(space_id, created_at)
idx_messages_space_created_desc ON messages(space_id, created_at DESC)
idx_decision_items_space ON decision_items(space_id)
idx_decision_items_space_locked ON decision_items(space_id, is_locked)
idx_reactions_item ON reactions(item_id)
idx_reactions_user ON reactions(user_id)
idx_space_members_user ON space_members(user_id)
idx_tasks_space ON tasks(space_id)
```

### 4.5 Migrations

15 migration files in `supabase/migrations/`:

| Migration | Purpose |
|-----------|---------|
| 001 | Foundation schema (tables + indexes) |
| 002 | Functions and triggers |
| 003 | RLS policies (auth_user_space_ids) |
| 004 | Dev verify password |
| 005 | Media + user_devices tables |
| 007 | System messages RPC |
| 008 | Join via invite (invite_token) |
| 009 | Space dates (start_date, end_date) |
| 010 | Member logistics |
| 011 | Fix reaction RPCs |
| 012 | Performance: RPCs + indexes + Realtime publication |
| 013 | Daily use features |
| RLS JWT fix | Fix RLS to use jwt sub |
| Media/devices RLS | Fix media + devices RLS |

---

## 5. The Decision Engine (Heart-Sort)

### 5.1 Signal System

Three reaction types, asymmetric weights designed for human group dynamics:

| Signal | Label | Weight | Color | Meaning |
|--------|-------|--------|-------|---------|
| `love_it` | "Love it" | **+5** | Amber (#F5A623) | Strong positive. Passionate signal. |
| `works_for_me` | "Works for me" | **+1** | Gray (#8888a0) | Lukewarm acceptance. "I'm fine with this." |
| `not_for_me` | "Not for me" | **-3** | Orange (#e8590c) | Meaningful brake, not a veto. |

**Design intent**:
- One `NotForMe` cancels exactly three `WorksForMe` (-3 + 1 + 1 + 1 = 0)
- Two `LoveIt` overcome one `NotForMe` (5 + 5 - 3 = 7)
- Passionate minority wins: 3 `LoveIt` (15) beats 4 `WorksForMe` (4)
- Score can go negative (items sink to bottom)
- One reaction per user per item. Last reaction wins (deduplication).

### 5.2 Heart-Sort Algorithm

Source of truth: `/Users/ramchitturi/algo/src/engine/heart-sort.ts` (198 tests, 0 type errors, hexagonal architecture).

App implementation: `src/lib/heart-sort.ts`

**Ranking**: Descending by `weightedScore`. Tie-break by `proposedAt` ascending (first proposed wins). Locked items sink to end. O(n log n).

**Pure functions** (no mutation, no side effects):
- `heartSort(items)` — sort by score
- `calculateWeightedScore(reactions)` — sum deduplicated reaction weights
- `calculateAgreementScore(item, totalMembers)` — % of members who reacted
- `addReaction(item, userId, type)` — returns new item with updated score
- `removeReaction(item, userId)` — returns new item with updated score
- `getRankedSummary(items, totalMembers)` — full breakdown with positions

### 5.3 Agreement Score & Consensus

```
agreementScore = uniqueReactors / totalMembers
isGroupFavorite = agreementScore > 0.80 (strictly greater)
```

| Agreement Score | Consensus State | Visual |
|----------------|----------------|--------|
| 0 - 0.3 | **Seeking** | Amber dashed ring, slow pulse |
| 0.3 - 0.8 | **Steady** | Amber ring + cyan breathing dot |
| 0.8+ | **Ignited** | Gold ring + 6 radial flare particles |

### 5.4 State Machine (4 Preset Flows)

```
BOOKING_FLOW (default):
  proposed → ranked → locked → claimed → purchased (terminal)
                        ↑                    │
                        └── consensus ──────→│
                                             └── feeds settlement

PURCHASE_FLOW:
  researching → shortlisted → negotiating → purchased

SIMPLE_VOTE_FLOW:
  nominated → ranked → chosen

SOLO_DECISION_FLOW:
  considering → leaning → decided
```

- `DecisionItemState` is an open string for custom flows
- All flows allow skipping intermediate states via direct commitment
- Unknown transitions silently ignored (permissive design)
- Solo spaces: no consensus threshold. React = decide.

### 5.5 Emergent Space State

No explicit phase field. State computed from items via pure function:

```typescript
computeSpaceState(items[], tripDates?, expiresAt?) → SpaceState
```

| State | Condition | UI Behavior |
|-------|-----------|-------------|
| `empty` | No items | Hero prompt, @xark ready |
| `exploring` | All proposed/voting | PossibilityHorizon active |
| `converging` | Some locked + some open | Mixed view |
| `ready` | All items settled | @xark suggests "looks like you're set" |
| `active` | Dates within range + locked | Itinerary view, live expenses |
| `settled` | Dates passed, all terminal | Memory mode, settlement |

Template lifetime: `expiresAt` enables auto-settle for micro-space templates (dinner expires in 8h, weekend in 72h).

---

## 6. Green-Lock Commitment Protocol

The bridge between "the group likes this" and "someone actually booked it."

### 6.1 Two-Step Commitment

**Step 1 — Consensus Lock (automated)**:
When `agreementScore > 80%`, @xark proposes: *"consensus reached on [Title]. shall i lock this in for the group?"*
- User confirms → `confirmHandshake()` → state = `locked` (no owner yet in BOOKING_FLOW)
- User dismisses → @xark whispers: *"understood. keeping this open for now."*
- Visual reward: Social Gold burst (full-screen radial gold gradient, 3s)

**Step 2 — Claim + Purchase (manual)**:
- ClaimSheet: "i'll handle this" → stamps `ownership { ownerId, assignedAt, reason: "booker" }`
- PurchaseSheet: amount input + proof (confirmation link/receipt) → state = `purchased` (terminal)

### 6.2 Commitment Proof

```typescript
CommitmentProof {
  type: string    // "confirmation_number" | "screenshot" | "receipt" | "contract" | "verbal"
  value: string   // free-form text or URL
  submittedBy: string
  submittedAt: number
}
```

### 6.3 Ownership

```typescript
OwnershipRecord {
  ownerId: string
  assignedAt: number
  reason: "booker" | "transfer"
}
```

- `ownershipHistory[]`: append-only audit trail
- `transferOwnership()`: cannot self-transfer, cannot transfer non-locked item
- `GreenLockError`: thrown on double-lock, empty proof, or violation

---

## 7. @xark Intelligence Service

### 7.1 Personality & Behavior

@xark is a **tool**, not a character. Silent by default. No personality, no emoji, no sparkles, no robot icons. Intelligence is signaled via accent color (cyan) breathing at a 4.5s cycle.

**NEVER** (absolute rules):
- Respond to messages without "@xark" prefix
- React to messages, summarize unprompted, insert into banter
- Send proactive suggestions or observations
- Add emoji, exclamation marks, or personality

**ONE EXCEPTION**: Handshake whisper at >80% consensus (automated).

### 7.2 Intelligence Architecture

```
User: "@xark find hotels near coronado under 200"
  │
  ├── /api/xark (API Route)
  │     ├── Strip "@xark" prefix
  │     ├── Promise.all([
  │     │     fetchSpaceTitle(),
  │     │     buildGroundingContext(),        ← ai-grounding.ts
  │     │     fetchMessages(spaceId, { limit: 15 })
  │     │   ])
  │     ├── PII Sanitization                 ← sanitize.ts (Luhn validation)
  │     │
  │     └── Intelligence Orchestrator        ← orchestrator.ts
  │           ├── Gemini 2.5 Flash: parse intent
  │           │     → { action: "search", tool: "hotel", params: {...} }
  │           ├── Route to tool tier:
  │           │     ├── Tier 1: Gemini Search (local queries)
  │           │     └── Tier 2: Apify Actors (travel/booking)
  │           ├── Execute search
  │           ├── Gemini: synthesize response
  │           └── Return results
  │
  ├── Auto-upsert results as decision_items (state: "proposed")
  │     └── metadata: { search_batch, search_label, url, image_url, price }
  │
  ├── Persist @xark response message (server-side, bypasses RLS)
  │
  └── Realtime: PossibilityHorizon updates with new items
```

### 7.3 Two-Tier Tool System

| Tier | Tool | Provider | Use Case |
|------|------|----------|----------|
| `gemini-search` | `local_restaurant` | Gemini Search Grounding | "restaurants near me" |
| `gemini-search` | `local_activity` | Gemini Search Grounding | "things to do in LA" |
| `gemini-search` | `local_general` | Gemini Search Grounding | General local queries |
| `apify` | `hotel` | Apify Actor | Hotel search + pricing |
| `apify` | `flight` | Apify Actor | Flight search |
| `apify` | `activity` | Apify Actor | Activity/tour search |
| `apify` | `restaurant` | Apify Actor | Restaurant data |
| `apify` | `general` | Apify Actor | General web scraping |

Tool registry is extensible: `registerTool(name, { actorId, description, paramMap, tier })`.

### 7.4 AI Grounding (State Map Approach)

@xark receives a full state map of all items grouped by state before generating responses:

- **Locked**: Committed decisions. Do NOT reopen or suggest conflicting alternatives.
- **Voting**: Items with active reactions. Respect current signals.
- **Proposed**: New items, no reactions. Fair game.
- **Empty categories**: No items exist. Suggest freely.

The test: "Is this the SAME decision or a DIFFERENT decision?"
- "Hotel" locked does NOT ban "Airbnb for a different city" (different need)
- "Italian restaurant" locked DOES ban "let's try Italian" for same meal (same decision)

### 7.5 Social Reasoning Protocol

- **Use names for advocacy**: "nina and raj aren't feeling italian — want to explore other options?"
- **Use counts for opposition**: "3 people voted not for me" (never name opponents)
- **Never assume why** someone voted a certain way
- **The test**: Would the named person feel INCLUDED or EXPOSED?

### 7.6 PII Sanitization

Before any data reaches Gemini:
- Credit card numbers (with Luhn validation)
- Social Security Numbers
- CVV codes
- Bank account numbers

All redacted via `sanitize.ts` → `redactPII(text)`.

### 7.7 Non-Search Capabilities

- "@xark what does the group think?" → Summarize reaction state from grounding context
- "@xark who hasn't voted yet?" → Read member list + reactions
- "@xark add kayaking at la jolla" → Direct item insert, no search
- Handshake whisper at consensus → Automated, no invocation needed

---

## 8. User Interface

### 8.1 Design System

#### Typography (Single Source of Truth: `src/lib/theme.ts`)

| Token | Size | Use |
|-------|------|-----|
| `text.hero` | 1.5rem | Large display text |
| `text.spaceTitle` | clamp(1rem, 3vw, 1.25rem) | Space titles |
| `text.listTitle` | 1rem | List item titles |
| `text.body` | 0.75rem | Body text, chat messages |
| `text.subtitle` | 0.65rem | Secondary info |
| `text.label` | 0.6rem | Labels, uppercase |
| `text.recency` | 0.5rem | Timestamps |
| `text.timestamp` | 0.45rem | Inline timestamps |
| `text.input` | clamp(0.85rem, 2vw, 1rem) | Input fields |
| `text.hint` | 0.6rem | Hint text |

**Fonts**: Inter (variable, body primary) + Syne (variable, display/fallback). Inter weight 300 for wordmark.

#### 4-Theme System

Two axes: **style** (flat/depth) and **mode** (light/dark).

| Theme | Style | Mode | Text | Background | Accent |
|-------|-------|------|------|------------|--------|
| `hearth` | flat | light | #111111 | #F8F7F4 | #FF6B35 (Action Orange) |
| `hearth_dark` | flat | dark | #E8E6E1 | #0A0A0F | #40E0FF (Cyan) |
| `vibe` | depth | light | #0F0F0F | #FAF9F6 | #E87040 (Warm Orange) |
| `vibe_dark` | depth | dark | #ECE8E2 | #08080C | #50E8C0 (Warm Teal) |

**Flat**: Clean, WhatsApp-like. Minimal shadows.
**Depth**: Floating shadows, larger avatars, ambient glow. Immersive.

All colors are CSS variables (`--xark-white`, `--xark-void`, `--xark-accent`, etc.) set by ThemeProvider. No hardcoded hex in components.

#### Ink System (Solid Text Colors)

For high-readability contexts (chat lists, People tab, settings), solid colors replace opacity-based text:

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `ink.primary` | #000000 | #FFFFFF | Names, titles |
| `ink.secondary` | #6B6B78 | #9CA3AF | Preview text, subtitles |
| `ink.tertiary` | #8A8A94 | #6B7280 | Timestamps, metadata |
| `ink.sender` | #9E6A06 | #D4A017 | Sender names in chat |

#### Engine Signal Colors

| Signal | Color | Meaning |
|--------|-------|---------|
| Amber | var(--xark-amber) | Seeking / anticipation / "Love it" |
| Gold | var(--xark-gold) | Social reward / consensus / handshake |
| Green | var(--xark-green) | Finality / locked / committed |
| Orange | var(--xark-orange) | Rejection / "Not for me" |
| Cyan | var(--xark-accent) | @xark intelligence / system |
| Gray | var(--xark-gray) | Neutral / "Works for me" |

### 8.2 Navigation Architecture

```
Login (/login)
  │
  ├── Screen 1: Brand ("xark" wordmark + staggered taglines)
  │     └── "begin" → Screen 2
  │
  └── Screen 2: Magic Field (single-field morphing)
        ├── phone input (country code auto-detect)
        ├── OTP input (auto-submit on 6th digit)
        ├── name input ("your friends call you")
        └── photo input ("hey [name] — add a face?", optional)
              └── → Galaxy (/galaxy)

Galaxy (/galaxy?name=...)
  │
  ├── Tab: People (default) — PeopleDock (personal chats, contact picker)
  ├── Tab: Plans — AwarenessStream (priority-sorted cross-space events)
  ├── Tab: Memories — MemoriesTab (aggregated photos, masonry grid)
  │
  ├── UserMenu (top-right) — profile / theme / notifications / about
  ├── Dream Input (bottom) — "a trip, a dinner, a plan..." → creates space
  └── ControlCaret (global dot) — space list slide-up, presence indicators

Space (/space/[id]?name=...)
  │
  ├── View: Discuss — XarkChat (atmospheric chat, foveal opacity)
  ├── View: Decide — PossibilityHorizon (Netflix card rails)
  ├── View: Itinerary — ItineraryView (committed items timeline)
  ├── View: Memories — MemoriesView (photo stream)
  │
  ├── Share action — navigator.share() or clipboard
  ├── ChatInput (always visible) — textarea + mic + attach + camera
  └── ControlCaret (global) — back to Galaxy
```

### 8.3 Screen Inventory

#### Login (`src/app/login/page.tsx`)

Two-screen flow with Framer Motion `layoutId` transitions:

1. **Brand screen**: "xark" wordmark, staggered taglines ("people, plans and memories.", "decide together, effortlessly.", "encrypted, always."), "begin" entry point.
2. **Magic field**: Single input position, content cross-fades between phone → OTP → name → photo. Progressive accent wash. Country code selector with search. OTP auto-submits on 6th digit. Photo optional.

#### Galaxy (`src/app/galaxy/page.tsx`)

The home screen. Three tabs with horizontal swipe navigation:

- **People** (default): Personal chats list sorted by recency. Contact picker. Independent realtime subscription.
- **Plans**: Priority-sorted cross-space events (needs_vote, ignited, proposal, assigned, message, locked, joined). Time decay via exponential function.
- **Memories**: Aggregated photos across all spaces. Masonry grid with hero 2x2 tiles.

Spectrum Wash background (radial gradients). Mesh Pulse animation (15s breath).

**Dream Input**: Fixed above ControlCaret. Creates a space on Enter. Optimistic navigation via `getOptimisticSpaceId()`.

#### Space (`src/app/space/[id]/page.tsx`)

Individual decision space with 4 views:

**Discuss** — Atmospheric chat:
- No chat bubbles, no containers. Text floats.
- Foveal opacity: newest @xark message at 0.9, fading to 0.2 by 5th message back.
- WhatsApp-dense grouping: same-sender `mt-0.5`, different-sender `mt-3`.
- @xark greeting when empty: contextual hint based on space state.
- Handshake integration: whisper at consensus, "confirm"/"wait" floating text.
- Sanctuary bridge: tap sender name → slide-up 1:1 chat history.

**Decide** — Netflix-style card rails:
- Horizontal scroll rails per category (hotels, activities, flights, dining).
- DecisionCard: 3 sizes (hero 200x280, standard 165x240, mini 110x150). Photo top 40%, dark data zone bottom. Consensus % is brightest element.
- Unsplash hero image at top with Ken Burns zoom (1.1→1.0 over 2.2s).
- Reactions float at card bottom. Signal colors on active state.
- Items capped at 100, ordered by weighted_score DESC.
- Groups by `metadata.search_label` (search results get own rail) or `category`.
- Self-resolving: locked categories collapse to green dot + title.

**Itinerary** — Committed items timeline for ready/active spaces.

**Memories** — Photo stream for settled spaces.

**ChatInput**: Always visible across all views. Auto-expanding textarea, mic (tap=dictate, long-press=@xark), attach (paperclip), camera. URL detection with "add to decisions?" prompt. Keyboard-aware via `useKeyboard` hook (visualViewport API).

#### UserMenu (`src/components/os/UserMenu.tsx`)

4-view drill-down via `AnimatePresence`:

- **Main**: Avatar + name, inline theme toggles (Flat/Vibe + Light/Dark), Notifications, Invite, About, Log Out.
- **Profile**: 88px centered avatar with ambient glow ring, camera overlay for photo change, name input, phone display.
- **Notifications**: Master On/Off toggle (FCM token registration), per-space mute list.
- **About**: "xark os" + "v2.0" + feedback link.

Theme persistence: localStorage primary, Supabase `users.preferences.theme` fallback with fresh-fetch-before-write pattern.

#### ControlCaret (`src/components/os/ControlCaret.tsx`)

Global persistent element (rendered in `layout.tsx` via `GlobalCaret`):
- 10px cyan dot at bottom center, breathing at 4.5s.
- Context-aware tap: inside space → Galaxy, on Galaxy → toggle slide-up.
- Slide-up: avatar + name + members + decision state + recency timestamps per space.
- Presence Ember: 4px cyan dot on avatar when friend is online (Supabase Realtime Presence).
- Limited to top 5 most-recent spaces for channel efficiency.

### 8.4 Animations (Framer Motion)

| Element | Animation | Duration |
|---------|-----------|----------|
| Chat messages | `y: 8 → 0`, `opacity: 0 → 1` | 0.3s cubic-bezier |
| Decision cards | `whileInView` entrance | stagger 0.06s per card |
| Category rails | `whileInView` entrance | stagger 0.25s between rails |
| Hero image | `opacity: 0 → 1`, `scale: 1.1 → 1.0` | 1.2s, 2.2s |
| UserMenu | `x: ±60px` horizontal slide | 0.2s tween |
| ControlCaret | Breathing opacity | 4.5s ease-in-out |
| Consensus bar | `width: 0% → actual%` | 0.8s spring |
| Gold burst | Radial gradient pulse | 3s ease-out |
| Mesh Pulse | Background opacity | 15s ease-in-out |

**Performance rule**: No `layout` prop on message elements (eliminated layout thrashing). No `backdrop-filter` (60fps on $100 devices).

---

## 9. Authentication & Identity

### 9.1 Auth Flow

```
Firebase Phone OTP (production)
  └── onAuthStateChanged → user.uid
        └── Dev Auth fallback (DEV_MODE=true)
              └── POST /api/dev-auto-login { username }
                    └── Look up user by display_name
                    └── Sign JWT with jose (sub: user.id, role: authenticated)
                          └── setSupabaseToken(jwt) for RLS enforcement
                                └── Name-only fallback (no RLS, demo data)
```

### 9.2 User ID Format

Text-based IDs (not UUID):
- Phone auth: `phone_+15551234567`
- Name auth: `name_ram`
- Generated by: `makeUserId(type, value)` from `src/lib/user-id.ts`

### 9.3 Supabase RLS with Firebase JWT

```sql
-- Supabase RLS policies use jwt sub (text), not auth.uid() (UUID)
auth.jwt()->>'sub'  -- returns "name_ram" or "phone_+15551234567"
```

Dev auth signs JWTs compatible with Supabase's JWT verification, enabling RLS in development without Firebase.

---

## 10. Push Notifications

### 10.1 Architecture

```
Event occurs (message sent, item locked, consensus reached)
  → API route calls POST /api/notify
  → /api/notify:
      1. Get member user_ids from space_members
      2. Fetch preferences — filter out users who muted this space
      3. Get FCM tokens for eligible members from user_devices
      4. sendPush(tokens, title, body, { spaceId, event })
  → Firebase Cloud Messaging delivers to devices
```

### 10.2 Client Registration

1. User toggles "Notifications" ON in UserMenu
2. `getMessagingInstance()` lazily imports Firebase Messaging
3. `getToken()` requests notification permission + retrieves FCM token
4. Token saved to `user_devices` table
5. Service worker (`/firebase-messaging-sw.js`) handles background notifications

### 10.3 Per-Space Muting

Users can mute individual spaces via UserMenu → Notifications → per-space toggle.
Stored in `users.preferences.muted_spaces[]` (JSONB array).
`/api/notify` checks muted_spaces before sending.

---

## 11. Invite & Share System

### 11.1 Invite Flow

```
Creator: taps "Invite" in UserMenu
  → navigator.share() or clipboard copy
  → Link: https://xark.app/j/{token}

Invitee: opens link
  → /j/[token] page: enter name
  → POST /api/join { token, name }
      1. Validate invite_token → find space
      2. Create user (name_xxx)
      3. Add to space_members
      4. Sign JWT for RLS
  → Redirect to space
```

### 11.2 Share Target (PWA)

Xark is registered as a PWA share target:

```json
{
  "share_target": {
    "action": "/api/share",
    "method": "POST",
    "enctype": "multipart/form-data",
    "params": { "title": "title", "text": "text", "url": "url" }
  }
}
```

Share from any app → Xark intercepts → `/share` page → SpacePicker → OG metadata extracted → optionally inserted as decision item.

### 11.3 OG Extraction

`/api/og` endpoint extracts Open Graph metadata from shared URLs:
- `parseOGTags(html)` — parses og:title, og:description, og:image
- `fetchOGMetadata(url)` — fetches URL with 5s timeout, extracts OG tags
- Optional `insertAsItem` parameter creates a decision_item from the URL

---

## 12. Settlement & Payments

### 12.1 Settlement Calculation

```typescript
fetchSettlement(spaceId) → {
  entries: [{ userId, userName, items: [{title, price}], totalPaid }],
  deltas: [{ fromUser, fromName, toUser, toName, amount }],
  totalSpent: number,
  fairShare: number,        // totalSpent / memberCount
  memberCount: number       // from space_members (true group size)
}
```

`parsePrice()` handles: `"$450/nt"`, `"$95/person"`, `"Free"`, `"$1,234.56"`.

### 12.2 Payment Deep Links

No in-app payments. Xark generates deep links:

- **Venmo**: `venmo://paycharge?txn=pay&recipients={name}&amount={amount}&note={note}`
- **UPI**: `upi://pay?pa={upiId}&pn={name}&am={amount}&cu=INR&tn={note}`

Rendered as floating cyan text in Blueprint view (settlement section).

---

## 13. Space Templates

6 micro-space templates with built-in lifetimes:

| Template | Categories | Lifetime |
|----------|-----------|----------|
| `dinner_tonight` | restaurant, cuisine | 8 hours |
| `weekend_plan` | activity, food, transport | 72 hours |
| `trip` | hotel, flight, activity, restaurant | 720 hours (30 days) |
| `buy_together` | product, deal | 168 hours (7 days) |
| `watch_listen` | movie, show, music | 24 hours |
| `open` | (none) | No expiry |

After lifetime expires, empty spaces auto-settle. Spaces with items but no open decisions also settle.

---

## 14. Media & Photo Pipeline

### 14.1 Upload Flow

```
User taps camera/attach icon
  → File picker opens
  → uploadMedia(file, spaceId, userId, caption?)
      1. Upload blob to Firebase Storage: media/{spaceId}/{uuid}.{ext}
      2. Insert metadata row to Supabase: media table
  → Real-time update to photo stream
```

### 14.2 Hero Image Pipeline

At space creation:
1. Fetch destination photo metadata from Unsplash API
2. Download image as blob
3. Upload blob to Firebase Storage: `heroes/{spaceId}/hero.jpg`
4. Store Firebase CDN URL in `spaces.metadata.hero_url`
5. Next.js `<Image>` with Vercel edge optimization serves subsequent requests

Fallback chain: Firebase CDN → Unsplash direct URL → demo beach photo.

### 14.3 Profile Photos

Stored in Firebase Storage: `profiles/{userId}/avatar`.
Max 2MB. Displayed in UserMenu, chat, ControlCaret, People tab.

---

## 15. Voice Input

### 15.1 Two Interaction Modes

| Gesture | Mode | Behavior |
|---------|------|----------|
| Tap mic | Dictation | On-device `SpeechRecognition`. Text enters normal pipeline. |
| Long-press mic (500ms) | @xark mode | Auto-prefixes "@xark". Cyan breathing dot. Direct intelligence invocation. |

### 15.2 Implementation

`src/hooks/useVoiceInput.ts`:
- Uses browser `SpeechRecognition` API (on-device, no network required)
- Graceful fallback when API unavailable
- Visual: cyan dot (dictation), amber dot (@xark listening)
- Text responses always (searchable, scrollable)
- Works with any language supported by browser

---

## 16. Performance Optimizations

### 16.1 Query Optimization

| Pattern | Before | After |
|---------|--------|-------|
| Galaxy page load | 60+ queries (N+1) | 4 batched queries + RPC |
| Message fetch | All messages (unbounded) | 50 per page (cursor pagination) |
| Personal chats | Fetch all messages across all spaces | Single RPC (`get_latest_messages_per_space`) |
| /api/xark pre-Gemini | Sequential fetches | `Promise.all` (parallel) |
| /api/notify | 2-query chain | Single RPC |

### 16.2 Frontend Performance

- No `layout` prop on chat messages (eliminates layout thrashing)
- `CategoryRail` wrapped with `React.memo` + custom comparator
- Card images lazy-loaded after first 3 per rail (`loading="lazy"`)
- ControlCaret limited to 5 Realtime presence channels
- Galaxy subscription stabilized with `useRef` for space IDs
- No `backdrop-filter` (blur) — overlays use solid `#000` at opacity 0.8
- `useDeviceTier` hook scales animations for low-end devices (deviceMemory ≤ 2)

### 16.3 Message Pagination

| Context | Limit |
|---------|-------|
| Space chat | 50 messages |
| /api/xark context | 15 messages |
| Sanctuary bridge | 30 messages |

Cursor-based: `fetchMessages(spaceId, { limit, before })`. DESC order reversed client-side.

---

## 17. PWA Configuration

### manifest.json

```json
{
  "short_name": "xark",
  "name": "xark — group operating system",
  "display": "standalone",
  "orientation": "portrait",
  "start_url": "/login",
  "theme_color": "#F8F7F4",
  "background_color": "#F8F7F4",
  "share_target": { ... }
}
```

### Service Worker

`/firebase-messaging-sw.js` — handles background push notifications.
`ServiceWorkerRegistration` component registers SW and posts Firebase config.

### Production Blockers

- [ ] Offline support (service worker caching strategy)
- [ ] Maskable icons (192x192, 512x512)
- [ ] Splash screens
- [ ] App Store listing (TWA for Android)

---

## 18. API Routes

| Route | Method | Purpose | Auth |
|-------|--------|---------|------|
| `/api/xark` | POST | @xark intelligence endpoint | JWT |
| `/api/notify` | POST | Push notification trigger | Service role |
| `/api/join` | POST | Invite join (create user, add to space) | Public (token validated) |
| `/api/og` | POST | OG metadata extraction + optional item insert | JWT |
| `/api/share` | POST | PWA share target handler | JWT |
| `/api/dev-auto-login` | POST | Dev passwordless login | DEV_MODE only |
| `/api/phone-auth` | POST | Phone auth helper | Public |

---

## 19. Environment Variables

### Required for Production

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=            # Server-side only

# Firebase
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=        # Server-side only (FCM push)

# AI
GEMINI_API_KEY=                       # Gemini 2.5 Flash
APIFY_API_TOKEN=                      # Apify actors (hotel, flight, etc.)

# Media
NEXT_PUBLIC_UNSPLASH_ACCESS_KEY=      # Hero images at space creation
```

### Optional

```env
DEV_MODE=true                         # Enables /api/dev-auto-login
SUPABASE_JWT_SECRET=                  # For dev JWT signing
```

### Graceful Degradation

When env vars are missing, the system degrades gracefully:
- Firebase: `auth` and `storage` export `null`. Components null-check.
- Supabase: Placeholder client. Queries fail silently, components use demo data.
- Gemini: Orchestrator returns empty result.
- Apify: Returns empty array.
- Unsplash: Falls back to demo beach photo.

---

## 20. File Map

### App Routes

```
src/app/
├── layout.tsx              — Root layout (fonts, ThemeProvider, GlobalCaret, SW)
├── globals.css             — Global styles, CSS variables, ink system
├── login/page.tsx          — Two-screen login flow
├── galaxy/page.tsx         — Home (People/Plans/Memories tabs)
├── space/[id]/page.tsx     — Individual space (Discuss/Decide/Itinerary/Memories)
├── j/[token]/page.tsx      — Invite join page
├── share/page.tsx          — Share target landing page
└── api/
    ├── xark/route.ts       — @xark intelligence endpoint
    ├── notify/route.ts     — Push notification trigger
    ├── join/route.ts       — Invite join handler
    ├── og/route.ts         — OG metadata extraction
    ├── share/route.ts      — PWA share target handler
    ├── dev-auto-login/route.ts — Dev auth
    └── phone-auth/route.ts — Phone auth helper
```

### Components

```
src/components/os/
├── XarkChat.tsx            — Atmospheric chat (display-only)
├── ChatInput.tsx           — Textarea + mic + attach + camera
├── PossibilityHorizon.tsx  — Netflix-style Decide view
├── DecisionCard.tsx        — Card component (3 sizes)
├── ControlCaret.tsx        — Global dot with space list
├── UserMenu.tsx            — Settings (4-view drill-down)
├── AwarenessStream.tsx     — Plans tab content
├── PeopleDock.tsx          — People tab content
├── MemoriesTab.tsx         — Memories tab content
├── GalaxyLayout.tsx        — Layout registry (stream/split)
├── SpacePicker.tsx         — Space selection for share flow
├── ThemeProvider.tsx       — Theme context + CSS variable injection
├── ClaimSheet.tsx          — Claim locked item
├── PurchaseSheet.tsx       — Purchase confirmation
├── Avatar.tsx              — Reusable avatar
├── ConsensusMark.tsx       — Consensus indicator SVG
├── Blueprint.tsx           — Locked items timeline + settlement
├── ItineraryView.tsx       — Committed items timeline
├── MemoriesView.tsx        — Photo stream
├── OnboardingWhispers.tsx  — Onboarding hints
├── GlobalCaret.tsx         — ControlCaret portal wrapper
├── ServiceWorkerRegistration.tsx — SW registration
└── MediaUpload.tsx         — Photo upload
```

### Libraries

```
src/lib/
├── theme.ts                — SSOT: colors, text, opacity, timing, layout, ink
├── heart-sort.ts           — Decision ranking algorithm (full port)
├── messages.ts             — Chat persistence + Realtime sync (paginated)
├── awareness.ts            — Cross-space event aggregation
├── space-data.ts           — Space list (batched queries)
├── space-state.ts          — Emergent state computation (pure function)
├── space-templates.ts      — 6 micro-space templates
├── spaces.ts               — Space creation + invite links
├── ai-grounding.ts         — @xark grounding context + constraints
├── handshake.ts            — Consensus → commitment bridge
├── claims.ts               — Manual item claim/lock
├── ledger.ts               — Settlement math + payment links
├── media.ts                — Firebase Storage upload + Supabase metadata
├── notifications.ts        — FCM push (Firebase Admin)
├── supabase.ts             — Postgres client (Proxy pattern)
├── supabase-admin.ts       — Service-role client
├── firebase.ts             — Auth + Storage + FCM client
├── unsplash.ts             — Unsplash API client
├── og-extract.ts           — OG metadata extraction
├── user-id.ts              — User ID utilities
├── state-flows.ts          — State machine definitions
├── seed.ts                 — Demo data
└── intelligence/
    ├── orchestrator.ts     — Gemini 2.5 Flash orchestrator
    ├── tool-registry.ts    — Tool registry (2 tiers)
    ├── apify-client.ts     — Apify actor runner
    └── sanitize.ts         — PII redaction (Luhn validation)
```

### Hooks

```
src/hooks/
├── useAuth.ts              — Firebase Auth + dev fallback
├── useHandshake.ts         — Consensus detection + commitment
├── useVoiceInput.ts        — SpeechRecognition (tap + long-press)
├── useDeviceTier.ts        — Low-end device detection
└── useKeyboard.ts          — Virtual keyboard height (visualViewport)
```

---

## 21. Security Model

### Authentication

- **Production**: Firebase Phone OTP (SMS delivery)
- **Development**: Passwordless dev login via `/api/dev-auto-login` (gated by `DEV_MODE=true`, returns 404 in production)

### Authorization

- **Row-Level Security (RLS)**: All Supabase tables have RLS policies. Users can only read/write data in spaces they belong to.
- **Service Role**: Server-side API routes (`/api/xark`, `/api/notify`) use `supabaseAdmin` with service role key to bypass RLS for cross-user operations.
- **JWT**: Signed with Supabase JWT secret. Contains `sub` (user ID) and `role` (authenticated).

### Data Privacy

- @xark is **deaf until invoked**. No passive listening. Ever.
- Context model: grounding state map (decision data) always available. Last 15 messages loaded only on "@xark" invocation. Full chat history never sent to AI.
- PII sanitized before Gemini calls (credit cards, SSN, CVV, bank accounts).
- Firebase Storage for binary blobs (photos, files) — bucket-level security rules.

### Deployment Security

- `SUPABASE_SERVICE_ROLE_KEY` and `FIREBASE_SERVICE_ACCOUNT_JSON` are server-side only (never exposed to client).
- `NEXT_PUBLIC_*` variables are safe for client exposure (anon keys, API keys with restricted permissions).
- No secrets committed to repository.

---

## 22. Demo Data & Seed

`src/lib/seed.ts` populates Postgres with realistic demo content:

| Space | Items | Messages | Purpose |
|-------|-------|----------|---------|
| San Diego Trip | 4 (Hotel Del 92% locked, surf lessons 45%, balboa park 45%, gaslamp 92% locked) | 10 group messages | Full lifecycle demo |
| Ananya | 0 | 5 (sanctuary/1:1) | Sanctuary bridge demo |
| Tokyo Neon Nights | 2 | 0 | Minimal space |
| Summer 2026 | 0 | 0 | Empty space |

Run: `npx tsx src/lib/seed.ts`

---

## 23. v1 Launch Checklist

### Infrastructure

- [ ] Supabase Cloud project (run all 15 migrations)
- [ ] Firebase project (Auth + Storage + FCM enabled)
- [ ] Vercel deployment (Next.js 16)
- [ ] Environment variables configured
- [ ] Supabase Realtime publication enabled (messages, decision_items, space_members)
- [ ] Firebase Storage security rules configured

### APIs

- [ ] Gemini API key (gemini-2.5-flash access)
- [ ] Apify API token (actor subscriptions)
- [ ] Unsplash API key (hero images)

### PWA

- [ ] App icons (192x192, 512x512)
- [ ] Service worker caching strategy
- [ ] Offline fallback page
- [ ] iOS splash screens
- [ ] `apple-touch-icon` meta tag

### Testing

- [ ] Phone OTP flow (real SMS)
- [ ] @xark search → results appear in Decide view
- [ ] Consensus → handshake → Green-Lock → settlement
- [ ] Push notifications (foreground + background)
- [ ] Invite flow (share link → join → appear in space)
- [ ] Theme switching (4 themes persist across sessions)
- [ ] Per-space mute (muted user doesn't receive push)
- [ ] Share target (share URL from another app → Xark)
- [ ] Voice input (tap dictation + long-press @xark)
- [ ] Settlement ledger (Venmo/UPI links)
- [ ] Multiple concurrent users (Realtime sync)

### Performance Targets

| Metric | Target |
|--------|--------|
| Galaxy page load | < 300ms |
| Space page load | < 200ms |
| /api/xark pre-Gemini | < 100ms |
| Message delivery (send → appear on other device) | < 500ms |
| Push notification delivery | < 3s |
| Lighthouse Performance score | > 90 |
| First Contentful Paint | < 1.5s |

---

## 24. Known Limitations & Future Work

### v1 Known Limitations

1. **No offline support**: PWA requires network for all operations.
2. **No end-to-end encryption at message level**: Firebase Storage has bucket-level security, but messages in Supabase are encrypted in transit, not at rest per-user.
3. **No native app**: PWA only. No App Store/Play Store presence.
4. **Group size limited to 15**: Architecture and UX designed for small groups.
5. **No payment processing**: Settlement provides deep links only (Venmo, UPI).
6. **Simplified heart-sort in app**: Full algorithm (198 tests) lives in `/algo`. App has subset.
7. **No message editing/deletion**: Messages are immutable once sent.
8. **No read receipts**: No tracking of message read state.

### Post-v1 Roadmap

| Feature | Priority | Complexity |
|---------|----------|------------|
| Large group support (15-100) | High | High |
| Message-level E2E encryption | High | High |
| Native iOS/Android (React Native or Capacitor) | High | Medium |
| Offline support (service worker caching) | High | Medium |
| In-app payment processing | Medium | High |
| Message editing/deletion | Medium | Low |
| Read receipts | Medium | Low |
| Video memories | Medium | Medium |
| Calendar integration | Low | Medium |
| Custom themes | Low | Low |
| Email notifications | Low | Low |
| Enterprise/team features | Low | High |

---

## Appendix A: Algorithm Source of Truth

Full decision engine: `/Users/ramchitturi/algo`
- 198 tests, 0 type errors
- Hexagonal architecture (ports & adapters)
- `DecisionService`: stateless orchestrator
- `ConsensusEngine`: in-memory orchestrator
- `RequestHandler`: framework-agnostic HTTP router
- Optimistic concurrency via `version` field
- Reference adapters: memory-based (zero dependencies)

## Appendix B: Hexagonal Ports

| Port | Interface | Production Adapter |
|------|-----------|-------------------|
| Persistence | `PersistencePort` | Supabase Postgres |
| Event Bus | `EventBusPort` | Supabase Realtime |
| Auth | `AuthPort` | Firebase Auth |
| Cache | `CachePort` (optional) | Redis (future) |
| Messaging | `MessagingPort` | FCM |

## Appendix C: Error Taxonomy

| Error | When | HTTP | Recovery |
|-------|------|------|----------|
| `GreenLockError` | Double lock, empty proof, self-transfer | 422 | Fix input |
| `TaskAssignmentError` | Self-reassign, unassign non-assigned | 400 | Fix input |
| `VersionConflictError` | Stale version on save | 409 | Reload + retry |
| `AuthError` | Failed auth/authorization | 403 | Valid token |
| `NotFoundError` | Entity not in DB | 404 | Check ID |
