# Xark OS v2.0 — Full Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Xark OS trip lifecycle — dreaming → planning → active → memories — across 9 domain services with event-driven architecture.

**Architecture:** 9 loosely coupled domain services (Auth, Space, Intelligence, Decision Engine, Messaging, Media, Notification, Settlement, Itinerary) communicating via Supabase Realtime events. Hexagonal architecture. All state in Supabase Postgres. Stateless services where possible.

**Tech Stack:** Next.js 16 (App Router), React 19, TypeScript 5, Tailwind CSS 4, Framer Motion, Supabase (Postgres + Realtime), Firebase (Auth + Storage + FCM), Gemini 2.0 Flash (gemini-2.0-flash), Apify, jose (JWT)

**Spec:** `docs/superpowers/specs/2026-03-13-xark-architecture-blueprint.md`

---

## Agent Bootstrap (REQUIRED before every task)

Every agent MUST read these 4 files before writing any code:

1. `CLAUDE.md` — Primary directives, architectural locks, forbidden patterns
2. `CONSTITUTION.md` — Visual and architectural law
3. `.xark-state.json` — Current phase, foveal focus, component registry
4. `GROUNDING_PROTOCOL.md` — @xark AI behavior, grounding constraints

### Constitutional Non-Negotiables (always enforced)

- NO `font-weight` above 400. Bold is banned. Hierarchy via scale + opacity.
- NO borders, cards, `rounded-lg` containers (Zero-Box Doctrine).
- ALL colors from `src/lib/theme.ts` CSS variables (`colors.*`, `textColor()`, `accentColor()`). No hardcoded hex in components.
- ALL text sizes from `src/lib/theme.ts` `text` object tokens. No Tailwind text-size classes.
- NO Supabase Auth imports. Auth = Firebase only.
- NO `backdrop-filter` / `backdropFilter`. Overlays = `#000` at `opacity: 0.8`.
- Port 3000 only. If occupied, kill and reclaim.
- `textColor(alpha)` and `accentColor(alpha)` are the APPROVED opacity methods.

### Tier 3 Audit (before every commit)

Scan diff for: `border-1`, `font-bold`, `font-semibold`, `font-weight` above 400, `rgba(240,238,233)`, `supabase/auth`, `@supabase/auth`, `backdrop-filter`, `backdropFilter`. If found, PURGE.

### Existing Infrastructure

| Layer | Files | Status |
|-------|-------|--------|
| Auth (dev) | `src/app/api/dev-auth/route.ts`, `src/app/api/dev-auto-login/route.ts` | Working (jose JWT) |
| Auth hook | `src/hooks/useAuth.ts` | Working (Firebase + URL fallback) |
| Supabase clients | `src/lib/supabase.ts` (anon), `src/lib/supabase-admin.ts` (service role) | Working |
| Firebase client | `src/lib/firebase.ts` | Working (safe init) |
| Messages | `src/lib/messages.ts` | Working (Supabase + Realtime) |
| Theme | `src/lib/theme.ts`, `src/components/os/ThemeProvider.tsx` | Working (3 themes) |
| Heart-sort | `src/lib/heart-sort.ts` | Simplified (Possibility type, 2 functions) |
| AI Grounding | `src/lib/ai-grounding.ts` | Working but has bugs B1, B2 |
| Handshake | `src/lib/handshake.ts`, `src/hooks/useHandshake.ts` | Working |
| Claims | `src/lib/claims.ts` | Working |
| Ledger | `src/lib/ledger.ts` | Working but has bug B3 |
| Spaces | `src/lib/spaces.ts` | Working but has bug B4 |
| Awareness | `src/lib/awareness.ts` | Working (demo fallback) |
| Space data | `src/lib/space-data.ts` | Working (demo fallback) |
| Seed | `src/lib/seed.ts` | Working (5 users, 4 spaces, 6 items, 15 messages) |
| UI components | `XarkChat`, `ControlCaret`, `GlobalCaret`, `Blueprint`, `ConsensusMark`, `PossibilityHorizon`, `UserMenu`, `ThemeProvider` | All verified |
| Pages | `/login`, `/galaxy`, `/space/[id]` | All verified |
| DB schema | `supabase/migrations/001-003` + `004_dev_verify_password.sql` | Deployed |

### File Structure Overview

```
src/
  app/
    api/
      dev-auth/route.ts          (exists)
      dev-auto-login/route.ts    (exists)
      xark/route.ts              (Phase 2 — create)
      notify/route.ts            (Phase 9 — create)
      media/upload/route.ts      (Phase 8 — create)
    login/page.tsx               (exists)
    galaxy/page.tsx              (exists)
    space/[id]/page.tsx          (exists)
    layout.tsx                   (exists — modify for PWA meta)
    globals.css                  (exists — modify for PWA CSS)
  lib/
    theme.ts                     (exists)
    supabase.ts                  (exists)
    supabase-admin.ts            (exists)
    firebase.ts                  (exists)
    heart-sort.ts                (exists — rewrite Phase 3)
    state-flows.ts               (Phase 0 — create)
    ai-grounding.ts              (exists — fix Phase 2)
    handshake.ts                 (exists — refactor Phase 0)
    claims.ts                    (exists — refactor Phase 0)
    messages.ts                  (exists)
    ledger.ts                    (exists — fix Phase 10)
    spaces.ts                    (exists — fix Phase 0)
    awareness.ts                 (exists — enhance Phase 1)
    space-data.ts                (exists — enhance Phase 1)
    space-state.ts               (Phase 0 — create)
    intelligence/
      orchestrator.ts            (Phase 2 — create)
      tool-registry.ts           (Phase 2 — create)
      apify-client.ts            (Phase 2 — create)
    media.ts                     (Phase 8 — create)
    notifications.ts             (Phase 9 — create)
  hooks/
    useAuth.ts                   (exists)
    useHandshake.ts              (exists)
    useReactions.ts              (Phase 3 — create)
    useVoiceInput.ts             (Phase 2 — create)
  components/os/
    XarkChat.tsx                 (exists — modify Phases 2, 5)
    ControlCaret.tsx             (exists — enhance Phase 1)
    GlobalCaret.tsx              (exists)
    Blueprint.tsx                (exists — enhance Phase 10)
    ConsensusMark.tsx            (exists)
    PossibilityHorizon.tsx       (exists — rewrite Phase 4)
    ThemeProvider.tsx             (exists)
    UserMenu.tsx                 (exists)
    ClaimSheet.tsx               (Phase 5 — create)
    PurchaseSheet.tsx            (Phase 5 — create)
    MediaUpload.tsx              (Phase 8 — create)
    ItineraryView.tsx            (Phase 10 — create)
    MemoriesView.tsx             (Phase 10 — create)
public/
    manifest.json                (Phase 0 — create)
    firebase-messaging-sw.js     (Phase 9 — create)
    icons/                       (Phase 0 — create)
supabase/
    migrations/
      005_media_devices.sql      (Phase 8 — create, includes RLS policies)
      006_unreact_and_realtime.sql (Phase 3 — create)
      007_system_messages_rpc.sql (Phase 5 — create)
      008_join_via_invite.sql    (Phase 6 — create)
```

---

## Chunk 0: Foundation & Cross-Cutting

### Task 0.1: PWA Manifest + Meta Tags

**Files:**
- Create: `public/manifest.json`
- Create: `public/icons/` (placeholder icons)
- Modify: `src/app/layout.tsx`
- Modify: `src/app/globals.css`

**Depends on:** Nothing (independent)

- [ ] **Step 1: Create manifest.json**

```json
{
  "short_name": "xark",
  "name": "xark — group operating system",
  "icons": [
    { "src": "/icons/icon-192.png", "type": "image/png", "sizes": "192x192" },
    { "src": "/icons/icon-512.png", "type": "image/png", "sizes": "512x512" }
  ],
  "start_url": "/login",
  "display": "standalone",
  "orientation": "portrait",
  "theme_color": "#0A0A0A",
  "background_color": "#0A0A0A"
}
```

- [ ] **Step 2: Create placeholder icons**

Generate 192x192 and 512x512 PNG icons. Solid `#0A0A0A` background with "x" lettermark in `#40E0FF` (cyan). Place in `public/icons/`.

- [ ] **Step 3: Add PWA meta tags to layout.tsx**

In `src/app/layout.tsx`, add `metadata` and a **separate** `viewport` export (Next.js 14+ requires viewport as its own export, NOT nested inside metadata):

```typescript
import type { Metadata, Viewport } from "next";

export const metadata: Metadata = {
  title: "XARK OS",
  description: "Privacy focussed group operating system",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "xark",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
  themeColor: "#0A0A0A",
};
```

**IMPORTANT:** `viewport` MUST be a separate export. Nesting it inside `metadata` is invalid in Next.js 14+ and will silently break `env(safe-area-inset-*)` CSS on iOS.

- [ ] **Step 4: Add PWA CSS to globals.css**

Append to `src/app/globals.css`:

```css
/* PWA: disable web behaviors for native feel */
body {
  -webkit-touch-callout: none;
  -webkit-user-select: none;
  user-select: none;
  overscroll-behavior-y: contain;
}

/* PWA: safe area padding for notch devices */
.safe-top { padding-top: env(safe-area-inset-top); }
.safe-bottom { padding-bottom: env(safe-area-inset-bottom); }
```

Note: `user-select: none` applies globally. Input fields should override with `user-select: text` where text entry is needed.

- [ ] **Step 5: Verify**

Run: `npm run build && npm run dev`
Open Chrome DevTools → Application → Manifest. Confirm manifest loads. Test "Add to Home Screen" on mobile.

- [ ] **Step 6: Commit**

```bash
git add public/manifest.json public/icons/ src/app/layout.tsx src/app/globals.css
git commit -m "feat: add PWA manifest, meta tags, and safe-area CSS"
```

---

### Task 0.2: Extract Shared State Flows Module

**Files:**
- Create: `src/lib/state-flows.ts`
- Modify: `src/lib/handshake.ts` (import from state-flows)
- Modify: `src/lib/claims.ts` (import from state-flows)

**Depends on:** Nothing (independent)

**Why:** Both `handshake.ts` and `claims.ts` duplicate the flow terminal state map. Blueprint Section 4 requires extracting to `state-flows.ts`. Both files import from there.

- [ ] **Step 1: Create state-flows.ts**

```typescript
// src/lib/state-flows.ts
// XARK OS v2.0 — Shared state flow definitions
// Single source of truth for flow terminal states.
// Imported by handshake.ts, claims.ts, and future commitment modules.

export const FLOW_TERMINAL_STATES: Record<string, string> = {
  // BOOKING_FLOW (extended)
  proposed: "locked",
  // NOTE: "ranked" is intentionally omitted — it appears in both BOOKING_FLOW (→ locked)
  // and SIMPLE_VOTE_FLOW (→ chosen). Use resolveTerminalState(state, flow) to disambiguate.
  locked: "claimed",    // locked is intermediate in BOOKING_FLOW
  claimed: "purchased", // claimed is intermediate
  // PURCHASE_FLOW
  researching: "purchased",
  shortlisted: "purchased",
  negotiating: "purchased",
  // SIMPLE_VOTE_FLOW
  nominated: "chosen",
  // SOLO_DECISION_FLOW
  considering: "decided",
  leaning: "decided",
};

export function resolveTerminalState(currentState: string, flow?: string): string {
  if (currentState === "ranked") {
    return flow === "SIMPLE_VOTE_FLOW" ? "chosen" : "locked";
  }
  return FLOW_TERMINAL_STATES[currentState] ?? "locked";
}

export function isTerminalState(state: string): boolean {
  const terminals = new Set(["purchased", "chosen", "decided"]);
  return terminals.has(state);
}
```

- [ ] **Step 2: Refactor handshake.ts to import from state-flows**

In `src/lib/handshake.ts`, remove the inline flow map and replace with:

```typescript
import { resolveTerminalState } from "./state-flows";
```

Replace any inline terminal state resolution logic with `resolveTerminalState(currentState)`.

- [ ] **Step 3: Refactor claims.ts to import from state-flows**

Same pattern as Step 2. Remove duplicated flow map, import from `state-flows.ts`.

- [ ] **Step 4: Verify**

Run: `npx tsc --noEmit` — zero type errors.
Run: `npm run build` — clean build.

- [ ] **Step 5: Commit**

```bash
git add src/lib/state-flows.ts src/lib/handshake.ts src/lib/claims.ts
git commit -m "refactor: extract shared state-flows module from handshake + claims"
```

---

### Task 0.3: Compute Emergent Space State

**Files:**
- Create: `src/lib/space-state.ts`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 2 — spaces have no explicit phase field. State is computed from items via a pure function.

- [ ] **Step 1: Create space-state.ts**

```typescript
// src/lib/space-state.ts
// XARK OS v2.0 — Emergent Space State
// Pure function. No DB calls. Computed from items array.

export type SpaceState =
  | "empty"
  | "exploring"
  | "converging"
  | "ready"
  | "active"
  | "settled";

export interface SpaceStateItem {
  state: string;
  is_locked: boolean;
  category?: string;
  metadata?: {
    date?: string;
    check_in?: string;
    check_out?: string;
    price?: string;
  };
}

export function computeSpaceState(items: SpaceStateItem[]): SpaceState {
  if (items.length === 0) return "empty";

  const hasLocked = items.some(
    (i) => i.state === "locked" || i.state === "claimed" || i.state === "purchased"
  );
  const allSettled = items.every(
    (i) => i.state === "purchased" || i.state === "chosen" || i.state === "decided"
  );
  const hasOpenItems = items.some(
    (i) => !i.is_locked && i.state !== "purchased" && i.state !== "chosen" && i.state !== "decided"
  );

  // Check if trip dates have passed (settled)
  if (allSettled) {
    const now = new Date();
    const hasPastDates = items.some((i) => {
      const dateStr = i.metadata?.check_out || i.metadata?.date;
      if (!dateStr) return false;
      return new Date(dateStr) < now;
    });
    if (hasPastDates) return "settled";
  }

  // Check if in active trip (dates within range)
  const now = new Date();
  const hasActiveDates = items.some((i) => {
    const checkIn = i.metadata?.check_in || i.metadata?.date;
    const checkOut = i.metadata?.check_out || i.metadata?.date;
    if (!checkIn) return false;
    return new Date(checkIn) <= now && (!checkOut || new Date(checkOut) >= now);
  });
  if (hasActiveDates && hasLocked) return "active";

  // v1 heuristic: "ready" when all items are settled. Full category coverage check is Gemini's job (blueprint Section 2 note).
  if (hasLocked && !hasOpenItems) return "ready";

  // Mixed: some locked, some still voting
  if (hasLocked && hasOpenItems) return "converging";

  // All items are proposed/voting, nothing locked
  return "exploring";
}
```

- [ ] **Step 2: Verify**

Run: `npx tsc --noEmit` — zero type errors.

- [ ] **Step 3: Commit**

```bash
git add src/lib/space-state.ts
git commit -m "feat: add computeSpaceState pure function for emergent space state"
```

---

### Task 0.4: Fix Known Bug B4 — Space Creator Membership

**Files:**
- Modify: `src/lib/spaces.ts`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 12, Bug B4 — `spaces.ts` never inserts creator into `space_members`. The trigger handles it on INSERT but we should be explicit.

- [ ] **Step 1: Read current spaces.ts**

Read `src/lib/spaces.ts` to understand the current `createSpace()` implementation.

- [ ] **Step 2: Add space_members insert after space creation**

After the `spaces` insert, add:

```typescript
// Explicitly add creator as owner in space_members
await supabase.from("space_members").upsert(
  { space_id: spaceId, user_id: ownerId, role: "owner" },
  { onConflict: "space_id,user_id" }
);
```

- [ ] **Step 3: Verify**

Run: `npx tsc --noEmit` — zero type errors.
Run: `npm run build` — clean build.

- [ ] **Step 4: Commit**

```bash
git add src/lib/spaces.ts
git commit -m "fix: explicitly add space creator to space_members (bug B4)"
```

---

## Chunk 1: Living Home Screen

**Phase Goal:** Galaxy + ControlCaret read from real Supabase data (not demo fallback). The first thing a logged-in user sees should be live, seeded data.

### Task 1.1: Wire Awareness Stream to Real Supabase Data

**Files:**
- Modify: `src/lib/awareness.ts`

**Depends on:** Seed data deployed (`npx tsx src/lib/seed.ts`)

**Why:** `awareness.ts` currently has `getDemoAwareness()` fallback. Need to wire `fetchAwareness(userId)` to query real Supabase data across all the user's spaces.

- [ ] **Step 1: Read current awareness.ts**

Read `src/lib/awareness.ts` to understand the current implementation — specifically `fetchAwareness()` and which Supabase queries it makes.

- [ ] **Step 2: Ensure fetchAwareness queries real tables**

`fetchAwareness(userId)` should:
1. Query `space_members` to get all spaces the user belongs to
2. For each space, fetch recent `decision_items` (needs_vote, ignited, locked) and `messages`
3. Build `AwarenessEvent[]` with priority weights from the `AwarenessKind` type
4. Apply time decay via exponential function
5. Sort by scored priority via `sortAwareness()`

Verify the Supabase queries use the correct table/column names from `001_foundation_schema.sql`:
- `space_members`: `space_id`, `user_id`
- `decision_items`: `space_id`, `agreement_score`, `is_locked`, `state`
- `messages`: `space_id`, `created_at`
- `spaces`: `id`, `title`

- [ ] **Step 3: Ensure graceful fallback**

If any Supabase query fails (env vars missing, network error), fall back to `getDemoAwareness()`. Never crash. Never show a blank screen.

- [ ] **Step 4: Verify**

Run: `npm run dev`
Log in as "ram". Galaxy should show awareness events from seeded spaces (san diego trip, ananya, tokyo, summer).

- [ ] **Step 5: Commit**

```bash
git add src/lib/awareness.ts
git commit -m "feat: wire awareness stream to real Supabase queries with demo fallback"
```

---

### Task 1.2: Wire Space Data to Real Supabase Queries

**Files:**
- Modify: `src/lib/space-data.ts`

**Depends on:** Seed data deployed

**Why:** `space-data.ts` has `DEMO_SPACES` fallback. `fetchSpaceList()` needs to query real `spaces`, `space_members`, `decision_items`, and `messages` tables.

- [ ] **Step 1: Read current space-data.ts**

Understand the `SpaceListItem` type and `fetchSpaceList()` implementation.

- [ ] **Step 2: Ensure fetchSpaceList queries real tables**

`fetchSpaceList(userId)` should:
1. Query `space_members` WHERE `user_id = userId` to get space IDs
2. Fetch `spaces` with those IDs
3. For each space, enrich with:
   - Member names (from `space_members` JOIN `users` — note: may need `get_visible_users()` RPC for RLS)
   - Decision summary via `decisionStateLabel()` (count of locked, needs_vote, exploring items)
   - Last message content + timestamp
4. Sort by `lastActivityAt` descending

**Important:** The `users` table has RLS (`users_select_self` only returns own row). Co-member name lookups need to go through a service that bypasses RLS, OR use an RPC like `get_visible_users()`. For dev mode, queries via the JWT token from `dev-auto-login` should work since the token has the user's ID as `sub`.

- [ ] **Step 3: Verify**

Run: `npm run dev`
Open ControlCaret slide-up. Should show seeded spaces with real member names and decision state labels.

- [ ] **Step 4: Commit**

```bash
git add src/lib/space-data.ts
git commit -m "feat: wire space data to real Supabase queries with demo fallback"
```

---

### Task 1.3: Galaxy Page — Real Awareness Feed

**Files:**
- Modify: `src/app/galaxy/page.tsx`

**Depends on:** Task 1.1 (awareness.ts wired)

**Why:** Galaxy page calls `fetchAwareness()` or uses demo fallback. Ensure it passes the authenticated user's ID and renders real events.

- [ ] **Step 1: Read current galaxy/page.tsx**

Understand how it calls awareness functions and renders events.

- [ ] **Step 2: Pass authenticated userId to fetchAwareness**

The Galaxy page needs the logged-in user's ID (from URL param `?name=` or auth hook) to fetch their specific awareness events. Ensure `useAuth()` hook provides the `uid` and it's passed to `fetchAwareness(uid)`.

- [ ] **Step 3: Verify end-to-end**

Run: `npm run dev`
1. Navigate to `/login`, enter "ram"
2. Redirected to `/galaxy?name=ram`
3. Galaxy shows awareness events from san diego trip, ananya, tokyo, summer
4. Each event has whisper text + space context + recency label
5. Tap an event → navigates to that space

- [ ] **Step 4: Commit**

```bash
git add src/app/galaxy/page.tsx
git commit -m "feat: Galaxy page renders real awareness feed from Supabase"
```

---

### Task 1.4: ControlCaret — Real Space List + Presence

**Files:**
- Modify: `src/components/os/ControlCaret.tsx`

**Depends on:** Task 1.2 (space-data.ts wired)

**Why:** ControlCaret slide-up shows spaces with member names, decision state, and recency. Currently uses `DEMO_SPACES` fallback.

- [ ] **Step 1: Read current ControlCaret.tsx**

Understand how it calls `fetchSpaceList()` and renders the space list.

- [ ] **Step 2: Ensure real data flows through**

ControlCaret should:
1. Call `fetchSpaceList(userId)` with the authenticated user's ID
2. Render each space with Avatar, `text.listTitle` name, `text.subtitle` members + decision state, `text.recency` timestamps
3. Presence Ember (4px cyan dot) should be wired to Supabase Realtime Presence

Verify Supabase Realtime Presence subscription exists and drives the Presence Ember visibility.

- [ ] **Step 3: Verify**

Run: `npm run dev`
Tap cyan dot on Galaxy. Slide-up shows real spaces with member names and timestamps.

- [ ] **Step 4: Commit**

```bash
git add src/components/os/ControlCaret.tsx
git commit -m "feat: ControlCaret renders real space list from Supabase"
```

---

## Chunk 2: Intelligence Service

**Phase Goal:** @xark becomes intelligent — Gemini integration, Apify tool registry, voice input. The most architecturally complex phase.

### Task 2.1: Create Tool Registry

**Files:**
- Create: `src/lib/intelligence/tool-registry.ts`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 3 — extensible registry for Apify actors. New actors added by registration, no code change to orchestration.

- [ ] **Step 1: Create the tool registry**

```typescript
// src/lib/intelligence/tool-registry.ts
// XARK OS v2.0 — Apify Tool Registry
// Register Apify actors by category. Orchestrator routes @xark requests here.

export interface ToolDefinition {
  actorId: string;
  description: string;
  paramMap: (userParams: Record<string, string>) => Record<string, unknown>;
}

const registry: Record<string, ToolDefinition> = {};

export function registerTool(name: string, tool: ToolDefinition): void {
  registry[name] = tool;
}

export function getTool(name: string): ToolDefinition | null {
  return registry[name] ?? null;
}

export function listTools(): string[] {
  return Object.keys(registry);
}

// Register default tools
registerTool("hotel", {
  actorId: "apify/hotel-scraper",
  description: "Search hotels by location, dates, and price range",
  paramMap: (p) => ({
    location: p.location,
    checkIn: p.checkIn,
    checkOut: p.checkOut,
    maxPrice: p.maxPrice ? Number(p.maxPrice) : undefined,
  }),
});

registerTool("flight", {
  actorId: "apify/flight-scraper",
  description: "Search flights by origin, destination, and dates",
  paramMap: (p) => ({
    origin: p.origin,
    destination: p.destination,
    date: p.date,
    returnDate: p.returnDate,
  }),
});

registerTool("activity", {
  actorId: "apify/activity-finder",
  description: "Find activities and experiences by location",
  paramMap: (p) => ({
    location: p.location,
    category: p.category,
  }),
});

registerTool("restaurant", {
  actorId: "apify/restaurant-search",
  description: "Search restaurants by location and cuisine",
  paramMap: (p) => ({
    location: p.location,
    cuisine: p.cuisine,
    maxPrice: p.maxPrice ? Number(p.maxPrice) : undefined,
  }),
});

registerTool("general", {
  actorId: "apify/web-scraper",
  description: "General web search for any topic",
  paramMap: (p) => ({ query: p.query }),
});
```

- [ ] **Step 2: Verify**

Run: `npx tsc --noEmit` — zero type errors.

- [ ] **Step 3: Commit**

```bash
git add src/lib/intelligence/tool-registry.ts
git commit -m "feat: add Apify tool registry for @xark intelligence"
```

---

### Task 2.2: Create Apify Client

**Files:**
- Create: `src/lib/intelligence/apify-client.ts`

**Depends on:** Task 2.1 (tool-registry)

**Why:** Thin wrapper around Apify API. Runs an actor with given params and returns results.

- [ ] **Step 1: Install Apify client**

```bash
npm install apify-client
```

- [ ] **Step 2: Create apify-client.ts**

```typescript
// src/lib/intelligence/apify-client.ts
// XARK OS v2.0 — Apify Actor Client
// Runs Apify actors and returns structured results.

import { ApifyClient } from "apify-client";

const client = process.env.APIFY_API_TOKEN
  ? new ApifyClient({ token: process.env.APIFY_API_TOKEN })
  : null;

export interface ApifyResult {
  title: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  rating?: number;
  source: string;
}

export async function runActor(
  actorId: string,
  input: Record<string, unknown>
): Promise<ApifyResult[]> {
  if (!client) {
    console.warn("Apify: no API token configured, returning empty results");
    return [];
  }

  const run = await client.actor(actorId).call(input);
  const { items } = await client.dataset(run.defaultDatasetId).listItems();

  // Normalize results to our interface
  return items.map((item: Record<string, unknown>) => ({
    title: String(item.name || item.title || ""),
    price: item.price ? String(item.price) : undefined,
    imageUrl: item.imageUrl ? String(item.imageUrl) : (item.image ? String(item.image) : undefined),
    description: item.description ? String(item.description) : undefined,
    externalUrl: item.url ? String(item.url) : undefined,
    rating: typeof item.rating === "number" ? item.rating : undefined,
    source: "apify",
  }));
}
```

- [ ] **Step 3: Add env var**

Add to `.env.local`: `APIFY_API_TOKEN=<your-token>`
Add to `.env.example`: `APIFY_API_TOKEN=`

- [ ] **Step 4: Verify**

Run: `npx tsc --noEmit` — zero type errors.

- [ ] **Step 5: Commit**

```bash
git add src/lib/intelligence/apify-client.ts .env.example
git commit -m "feat: add Apify actor client for @xark search"
```

---

### Task 2.3: Create Intelligence Orchestrator

**Files:**
- Create: `src/lib/intelligence/orchestrator.ts`

**Depends on:** Task 2.1 (tool-registry), Task 2.2 (apify-client)

**Why:** Blueprint Section 3 — the brain of @xark. Gemini parses intent, routes to Apify, synthesizes response.

- [ ] **Step 1: Install Google AI SDK**

```bash
npm install @google/generative-ai
```

- [ ] **Step 2: Create orchestrator.ts**

```typescript
// src/lib/intelligence/orchestrator.ts
// XARK OS v2.0 — @xark Intelligence Orchestrator
// Gemini parses intent → routes to Apify tool → synthesizes response.
// Stateless. No state stored. Reads grounding context + last 15 messages.

import { GoogleGenerativeAI } from "@google/generative-ai";
import { getTool, listTools } from "./tool-registry";
import { runActor, type ApifyResult } from "./apify-client";

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

export interface OrchestratorInput {
  userMessage: string;        // "@xark" prefix already stripped
  groundingPrompt: string;    // from generateGroundingPrompt()
  recentMessages: Array<{ role: string; content: string; sender_name?: string }>;
  spaceId: string;
}

export interface OrchestratorResult {
  response: string;
  searchResults?: ApifyResult[];
  action?: "search" | "reason" | "propose";
  tool?: string;
}

export async function orchestrate(input: OrchestratorInput): Promise<OrchestratorResult> {
  if (!genAI) {
    return { response: "intelligence service is not configured." };
  }

  const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

  // Step 1: Parse intent via Gemini
  const intentPrompt = buildIntentPrompt(input);
  const intentResult = await model.generateContent(intentPrompt);
  const intentText = intentResult.response.text();

  let parsed: { action: string; tool?: string; params?: Record<string, string>; directResponse?: string };
  try {
    parsed = JSON.parse(intentText);
  } catch {
    // Gemini didn't return JSON — treat as direct reasoning response
    return { response: intentText, action: "reason" };
  }

  // Step 2: Route based on action
  if (parsed.action === "search" && parsed.tool && parsed.params) {
    const tool = getTool(parsed.tool);
    if (!tool) {
      return { response: `i don't have a ${parsed.tool} search tool yet.`, action: "search" };
    }

    const mappedParams = tool.paramMap(parsed.params);
    const results = await runActor(tool.actorId, mappedParams);

    if (results.length === 0) {
      return { response: "searched but found no results matching your criteria.", action: "search" };
    }

    // Step 3: Synthesize response via Gemini
    const synthesisPrompt = buildSynthesisPrompt(input, results);
    const synthesisResult = await model.generateContent(synthesisPrompt);

    return {
      response: synthesisResult.response.text(),
      searchResults: results,
      action: "search",
      tool: parsed.tool,
    };
  }

  if (parsed.action === "propose" && parsed.directResponse) {
    return { response: parsed.directResponse, action: "propose" };
  }

  // Default: reasoning response
  if (parsed.directResponse) {
    return { response: parsed.directResponse, action: "reason" };
  }

  return { response: intentText, action: "reason" };
}

function buildIntentPrompt(input: OrchestratorInput): string {
  const tools = listTools();
  return `You are @xark, a group coordination assistant. You are silent, precise, and never use emojis.

GROUNDING CONTEXT (current decision state):
${input.groundingPrompt}

RECENT MESSAGES (last 15):
${input.recentMessages.map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

AVAILABLE TOOLS: ${tools.join(", ")}

USER REQUEST: ${input.userMessage}

Respond with JSON only. Choose one action:
1. {"action": "search", "tool": "<tool-name>", "params": {<tool-specific params>}}
2. {"action": "reason", "directResponse": "<your response to the user>"}
3. {"action": "propose", "directResponse": "<your response>"}

If the user asks to find/search/look for something, use action "search" with the right tool.
If the user asks a question about group state, voting, or consensus, use action "reason".
If the user asks to add an item directly, use action "propose".
Respond only with the JSON object, nothing else.`;
}

function buildSynthesisPrompt(input: OrchestratorInput, results: ApifyResult[]): string {
  const resultsSummary = results
    .slice(0, 8)
    .map((r, i) => `${i + 1}. ${r.title}${r.price ? ` — ${r.price}` : ""}${r.rating ? ` (${r.rating}★)` : ""}`)
    .join("\n");

  return `You are @xark. Synthesize these search results for the group. Be brief and helpful. No emojis. No personality. Report facts.

RESULTS:
${resultsSummary}

USER ASKED: ${input.userMessage}

Respond in 1-2 sentences. Example: "found 4 hotels under $200. they're in your stream now."`;
}
```

- [ ] **Step 3: Add env var**

Add to `.env.local`: `GEMINI_API_KEY=<your-key>`
Add to `.env.example`: `GEMINI_API_KEY=`

- [ ] **Step 4: Verify**

Run: `npx tsc --noEmit` — zero type errors.

- [ ] **Step 5: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts .env.example
git commit -m "feat: add @xark intelligence orchestrator (Gemini + Apify routing)"
```

---

### Task 2.4: Rewrite /api/xark Route

**Files:**
- Create: `src/app/api/xark/route.ts`

**Depends on:** Task 2.3 (orchestrator)

**Why:** Blueprint Section 15. The @xark API endpoint receives messages, checks for "@xark" prefix, orchestrates Gemini + Apify, and returns response.

- [ ] **Step 1: Create the API route**

```typescript
// src/app/api/xark/route.ts
// XARK OS v2.0 — @xark Intelligence Endpoint
// Silent unless message contains "@xark". Privacy-first.

import { NextRequest, NextResponse } from "next/server";
import { orchestrate } from "@/lib/intelligence/orchestrator";
import { buildGroundingContext, generateGroundingPrompt } from "@/lib/ai-grounding";
import { fetchMessages } from "@/lib/messages";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { message, spaceId } = body;

  // SILENT MODE: no "@xark" prefix = no response
  if (!message || !message.toLowerCase().includes("@xark")) {
    return NextResponse.json({ response: null });
  }

  // Strip "@xark" prefix
  const userMessage = message.replace(/@xark\s*/i, "").trim();

  // Build grounding context (Tier 1 — always available)
  const groundingContext = await buildGroundingContext(spaceId);
  const groundingPrompt = generateGroundingPrompt(groundingContext);

  // Fetch last 15 messages (Tier 2 — on invocation only)
  const allMessages = await fetchMessages(spaceId);
  const recentMessages = allMessages.slice(-15).map((m) => ({
    role: m.role,
    content: m.content,
    sender_name: m.sender_name ?? undefined,
  }));

  // Orchestrate
  const result = await orchestrate({
    userMessage,
    groundingPrompt,
    recentMessages,
    spaceId,
  });

  // If search results exist, insert as decision_items
  if (result.searchResults && result.searchResults.length > 0) {
    if (supabaseAdmin) {
      const items = result.searchResults.map((r) => ({
        id: `item_${crypto.randomUUID()}`,
        space_id: spaceId,
        title: r.title.toLowerCase(),
        category: result.tool ?? "general",
        description: r.description ?? "",
        state: "proposed",
        proposed_by: null, // @xark proposed
        agreement_score: 0,
        weighted_score: 0,
        is_locked: false,
        version: 0,
        metadata: {
          price: r.price,
          image_url: r.imageUrl,
          external_url: r.externalUrl,
          source: "apify",
          rating: r.rating,
        },
      }));

      await supabaseAdmin.from("decision_items").upsert(items, { onConflict: "id" });
    }
  }

  return NextResponse.json({ response: result.response });
}
```

- [ ] **Step 2: Verify**

Run: `npm run build` — clean build.
Test: `curl -X POST http://localhost:3000/api/xark -H "Content-Type: application/json" -d '{"message":"hello","spaceId":"space_san-diego-trip"}'`
Expected: `{"response":null}` (no @xark prefix → silent).

Test: `curl -X POST http://localhost:3000/api/xark -H "Content-Type: application/json" -d '{"message":"@xark what does the group think?","spaceId":"space_san-diego-trip"}'`
Expected: Non-null response with grounding-aware reasoning.

- [ ] **Step 3: Commit**

```bash
git add src/app/api/xark/route.ts
git commit -m "feat: add /api/xark endpoint with Gemini orchestration and silent mode"
```

---

### Task 2.5: Fix Bug B1 + B2 in ai-grounding.ts

**Files:**
- Modify: `src/lib/ai-grounding.ts`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 12 bugs:
- B1: `checkSuggestionConflicts()` filters on `"Locked"` (capitalized) but DB stores `"locked"` (lowercase). Matches nothing.
- B2: `generateGroundingPrompt` still uses rigid "Do NOT suggest" directives instead of state map approach.

- [ ] **Step 1: Read current ai-grounding.ts**

Read `src/lib/ai-grounding.ts` to identify the exact lines with bugs.

- [ ] **Step 2: Fix B1 — lowercase state matching**

In `checkSuggestionConflicts()`, change filter from `"Locked"` / `"Finalized"` to lowercase: `"locked"`, `"purchased"`, `"chosen"`, `"decided"`. These are all terminal states that should prevent conflicting suggestions.

- [ ] **Step 3: Fix B2 — state map approach in generateGroundingPrompt**

Rewrite `generateGroundingPrompt(context)` to group items by state:
- **Locked/Purchased**: "These are committed. Do not reopen."
- **Voting** (has reactions, not locked): "Active voting. Respect current signal."
- **Proposed** (no reactions): "Open for discussion."
- **Empty categories**: "No items. Suggest freely."

Include reaction counts per item. Append WEIGHTING RULES. Let Gemini reason about scope.

- [ ] **Step 4: Verify**

Run: `npx tsc --noEmit` — zero type errors.
Run: `npm run build` — clean build.

- [ ] **Step 5: Commit**

```bash
git add src/lib/ai-grounding.ts
git commit -m "fix: lowercase state matching (B1) + state map grounding prompt (B2)"
```

---

### Task 2.6: Voice Input Hook

**Files:**
- Create: `src/hooks/useVoiceInput.ts`
- Modify: `src/components/os/XarkChat.tsx` (add mic interaction)

**Depends on:** Task 2.4 (/api/xark route)

**Why:** Blueprint Section 3 — two voice paths: tap (on-device SpeechRecognition) and long-press (Gemini multimodal).

> **v1 simplification:** Both tap and long-press use on-device SpeechRecognition. Long-press auto-prefixes "@xark" to route through intelligence. The Gemini multimodal path (sending audio blob directly to Gemini for transcription + reasoning in one hop) is deferred to a future phase when latency and quality can be properly tested.

- [ ] **Step 1: Create useVoiceInput hook**

```typescript
// src/hooks/useVoiceInput.ts
// XARK OS v2.0 — Voice Input Hook
// Tap: on-device SpeechRecognition (instant, no network)
// Long-press: @xark listening mode (Gemini multimodal)

import { useState, useRef, useCallback } from "react";

interface VoiceInputResult {
  isListening: boolean;
  isXarkListening: boolean; // long-press mode
  transcript: string;
  startListening: () => void;
  startXarkListening: () => void;
  stopListening: () => void;
  error: string | null;
}

export function useVoiceInput(): VoiceInputResult {
  const [isListening, setIsListening] = useState(false);
  const [isXarkListening, setIsXarkListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [error, setError] = useState<string | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);

  const startListening = useCallback(() => {
    const SpeechRecognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setError("speech recognition not supported");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = "en-US";

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      const text = event.results[0][0].transcript;
      setTranscript(text);
      setIsListening(false);
    };

    recognition.onerror = () => {
      setIsListening(false);
      setError("voice recognition failed");
    };

    recognition.onend = () => setIsListening(false);

    recognitionRef.current = recognition;
    recognition.start();
    setIsListening(true);
    setError(null);
    setTranscript("");
  }, []);

  const startXarkListening = useCallback(() => {
    // Long-press: same SpeechRecognition but auto-prefix "@xark"
    const SpeechRecognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setError("speech recognition not supported");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = "en-US";

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      const text = event.results[0][0].transcript;
      setTranscript(`@xark ${text}`);
      setIsXarkListening(false);
    };

    recognition.onerror = () => {
      setIsXarkListening(false);
      setError("voice recognition failed");
    };

    recognition.onend = () => setIsXarkListening(false);

    recognitionRef.current = recognition;
    recognition.start();
    setIsXarkListening(true);
    setError(null);
    setTranscript("");
  }, []);

  const stopListening = useCallback(() => {
    recognitionRef.current?.stop();
    setIsListening(false);
    setIsXarkListening(false);
  }, []);

  return {
    isListening,
    isXarkListening,
    transcript,
    startListening,
    startXarkListening,
    stopListening,
    error,
  };
}
```

- [ ] **Step 2: Add voice mic to XarkChat input area**

In `src/components/os/XarkChat.tsx`, next to the text input in the Thumb-Arc zone:
- Add a mic indicator: tap = `startListening()`, long-press (500ms) = `startXarkListening()`
- When `isXarkListening`: show cyan breathing dot + "@xark is listening..." placeholder
- When `isListening`: show subtle mic active state
- When transcript arrives, populate the input field
- Mic is floating text, not a button with border/background

- [ ] **Step 3: Verify**

Run: `npm run dev`
Open a space. Tap near mic area → browser asks for mic permission → speaks → text appears in input.
Long-press → "@xark is listening..." appears → speaks → "@xark [text]" populates input.

- [ ] **Step 4: Commit**

```bash
git add src/hooks/useVoiceInput.ts src/components/os/XarkChat.tsx
git commit -m "feat: add voice input (tap: on-device, long-press: @xark mode)"
```

---

## Chunk 3: Decision Engine Core

**Phase Goal:** Reactions write path + full heart-sort port + propose UI. Users can react to items and see scores update in real-time.

### Task 3.1: Verify Existing Reactions Infrastructure + Add unreact RPC

**Files:**
- Create: `supabase/migrations/006_unreact_and_realtime.sql`

**Depends on:** Nothing (independent, but must be run in Supabase SQL Editor)

**Why:** The `reactions` table ALREADY EXISTS in `001_foundation_schema.sql` with columns `(item_id, user_id, signal, weight, created_at)`. The `react_to_item(p_item_id text, p_signal text)` RPC ALREADY EXISTS in `002_functions_triggers.sql` — it uses `auth.uid()` internally for the reactor's identity (2-param function, not 3). RLS policies exist in `003_rls_policies.sql`. What's missing: an `unreact` function and Realtime on the reactions table.

**IMPORTANT — Existing schema to preserve:**
- Table `reactions`: columns are `item_id`, `user_id`, `signal` (NOT `reaction_type`), `weight`, `created_at`
- RPC `react_to_item(p_item_id text, p_signal text)`: 2 params only. Uses `auth.uid()` — does NOT accept user_id param (security: prevents impersonation)
- Signal values: `'love_it'`, `'works_for_me'`, `'not_for_me'`

- [ ] **Step 1: Create migration for unreact + Realtime**

```sql
-- 006_unreact_and_realtime.sql
-- Add unreact function + enable Realtime on reactions

CREATE OR REPLACE FUNCTION unreact_to_item(p_item_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_space_id text;
  v_weighted_score float;
  v_agreement_score float;
  v_member_count integer;
  v_reactor_count integer;
BEGIN
  -- Get space_id
  SELECT space_id INTO v_space_id FROM decision_items WHERE id = p_item_id;
  IF v_space_id IS NULL THEN
    RAISE EXCEPTION 'item_not_found';
  END IF;

  -- Delete reaction for current user
  DELETE FROM reactions WHERE item_id = p_item_id AND user_id = auth.uid()::text;

  -- Recompute weighted_score
  SELECT COALESCE(SUM(weight), 0) INTO v_weighted_score
  FROM reactions WHERE item_id = p_item_id;

  -- Recompute agreement_score
  SELECT COUNT(DISTINCT user_id) INTO v_reactor_count
  FROM reactions WHERE item_id = p_item_id;

  SELECT COUNT(*) INTO v_member_count
  FROM space_members WHERE space_id = v_space_id;

  v_agreement_score := CASE WHEN v_member_count > 0
    THEN v_reactor_count::float / v_member_count::float
    ELSE 0 END;

  -- Update scores
  UPDATE decision_items SET
    weighted_score = v_weighted_score,
    agreement_score = v_agreement_score
  WHERE id = p_item_id;
END;
$$;

-- Enable Realtime on reactions for live score updates
ALTER PUBLICATION supabase_realtime ADD TABLE reactions;
```

- [ ] **Step 2: Run in Supabase SQL Editor**

Copy the SQL and run in the Supabase dashboard SQL Editor.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/006_unreact_and_realtime.sql
git commit -m "feat: add unreact_to_item RPC + enable Realtime on reactions"
```

---

### Task 3.2: Create useReactions Hook

**Files:**
- Create: `src/hooks/useReactions.ts`

**Depends on:** Task 3.1 (unreact RPC deployed)

**Why:** React hook for the voting surface. One reaction per user per item. Updates scores in real-time.

**IMPORTANT — Existing RPC signature:**
The `react_to_item` function in Postgres is `react_to_item(p_item_id text, p_signal text)` — only 2 params. It uses `auth.uid()` internally to identify the reactor. Do NOT pass `user_id` — this is a security feature that prevents impersonation. The `unreact_to_item(p_item_id text)` is also 1 param (uses `auth.uid()` internally).

The reactions table column is `signal` (not `reaction_type`). When querying reactions directly, use `.select("signal")`.

- [ ] **Step 1: Create the hook**

```typescript
// src/hooks/useReactions.ts
// XARK OS v2.0 — Reactions Hook
// Drives PossibilityHorizon voting surface.
// One reaction per user per item. Last wins.
// Uses auth.uid() inside SECURITY DEFINER RPCs — no userId param needed.

import { useState, useCallback } from "react";
import { supabase } from "@/lib/supabase";

export type ReactionType = "love_it" | "works_for_me" | "not_for_me";

interface UseReactionsResult {
  react: (itemId: string, reaction: ReactionType) => Promise<void>;
  unreact: (itemId: string) => Promise<void>;
  getUserReaction: (itemId: string, userId: string) => Promise<ReactionType | null>;
  isReacting: boolean;
}

export function useReactions(): UseReactionsResult {
  const [isReacting, setIsReacting] = useState(false);

  const react = useCallback(async (itemId: string, reaction: ReactionType) => {
    setIsReacting(true);
    try {
      // 2-param RPC: (p_item_id, p_signal). auth.uid() used internally.
      await supabase.rpc("react_to_item", {
        p_item_id: itemId,
        p_signal: reaction,
      });
    } finally {
      setIsReacting(false);
    }
  }, []);

  const unreact = useCallback(async (itemId: string) => {
    setIsReacting(true);
    try {
      // 1-param RPC: (p_item_id). auth.uid() used internally.
      await supabase.rpc("unreact_to_item", {
        p_item_id: itemId,
      });
    } finally {
      setIsReacting(false);
    }
  }, []);

  const getUserReaction = useCallback(async (itemId: string, userId: string): Promise<ReactionType | null> => {
    // Direct query — column is "signal", not "reaction_type"
    const { data } = await supabase
      .from("reactions")
      .select("signal")
      .eq("item_id", itemId)
      .eq("user_id", userId)
      .single();
    return (data?.signal as ReactionType) ?? null;
  }, []);

  return { react, unreact, getUserReaction, isReacting };
}
```

- [ ] **Step 2: Verify**

Run: `npx tsc --noEmit` — zero type errors.

- [ ] **Step 3: Commit**

```bash
git add src/hooks/useReactions.ts
git commit -m "feat: add useReactions hook for item voting"
```

---

### Task 3.3: Port Full Heart-Sort from /algo

**Files:**
- Modify: `src/lib/heart-sort.ts`

**Depends on:** Nothing (independent)

**Why:** The app's heart-sort.ts has a simplified `Possibility` type with 2 functions. The full algo in `/Users/ramchitturi/algo/src/engine/heart-sort.ts` has `DecisionItem`, `calculateWeightedScore`, `addReaction`, `removeReaction`, `calculateAgreementScore`, `getRankedSummary`. Port the full engine.

- [ ] **Step 1: Read the full algo heart-sort**

Read `/Users/ramchitturi/algo/src/engine/heart-sort.ts` to understand the full interface.

- [ ] **Step 2: Port to app's heart-sort.ts**

Keep the existing `Possibility` type and `heartSort()` / `getConsensusState()` for backwards compatibility. Add the full `DecisionItem` interface, `calculateWeightedScore()`, `calculateAgreementScore()`, `getRankedSummary()`, `addReaction()`, `removeReaction()` as additional exports.

Key rules:
- All functions are PURE — no mutation, return new objects
- `calculateAgreementScore`: ALL reactors (including NotForMe) / totalMembers
- `isGroupFavorite`: strictly > 80% (not >=)
- `heartSort`: descending by weightedScore, tie-break by proposedAt ascending

- [ ] **Step 3: Verify**

Run: `npx tsc --noEmit` — zero type errors.
Run: `npm run build` — clean build.

- [ ] **Step 4: Commit**

```bash
git add src/lib/heart-sort.ts
git commit -m "feat: port full heart-sort engine from /algo (DecisionItem, reactions, scoring)"
```

---

## Chunk 4: PossibilityHorizon Reaction Surface

**Phase Goal:** The voting surface — Airbnb-style horizontal scroll with reaction signals. This is designed in a parallel session.

### Task 4.1: PossibilityHorizon Parallel Design Session

**Files:**
- Modify: `src/components/os/PossibilityHorizon.tsx`

**Depends on:** Task 3.2 (useReactions hook), Task 3.3 (heart-sort port)

**Why:** Blueprint Section 17 — the reaction surface is the most critical UX. Requires dedicated visual design.

- [ ] **Step 1: Launch parallel design session with this prompt**

Use the following prompt (from Blueprint Section 17) to design PossibilityHorizon in a separate session:

> Design the PossibilityHorizon reaction surface for Xark OS. This is an Airbnb-style horizontal scroll of edge-to-edge images (hotels, flights, activities) where users vote Love It (+5, amber), Works For Me (+1, gray), or Not For Me (-3, orange). One reaction per user per item. Constraints: Zero-Box doctrine (no borders, no buttons, no cards, no rounded containers). No AI-looking icons. No old-age thumbs up. The reactions must be woven into the image experience — almost invisible until needed, creatively placed to save screen space. The scroll must feel premium, tactile, and fast. Images snap-scroll (snap-x, snap-mandatory, snap-center). Each item shows: edge-to-edge image with bottom vignette, title, price, source. Reaction signals as floating text, not buttons. Tapped reaction glows to full opacity, others fade to 0.2. Constitutional rules: all sizes from theme.ts text tokens, all colors from theme.ts colors object, font-weight 300/400 only, no backdrop-filter. Read CLAUDE.md and CONSTITUTION.md for full visual law. Read src/lib/theme.ts for all available tokens.

- [ ] **Step 2: Integrate the designed component**

Wire `useReactions()` hook for voting. Wire `heartSort()` for item ordering. Wire Supabase Realtime for live score updates.

Data source: `decision_items` WHERE `space_id = spaceId` AND `is_locked = false`, ordered by `heartSort()`.

Each item needs:
- `metadata.image_url` for the edge-to-edge image (fallback: gradient placeholder)
- `metadata.price` for price display
- `metadata.source` for provenance ("apify", "manual", "@xark")
- `weighted_score` and `agreement_score` for visual treatment
- `ConsensusMark` component for consensus state indicator

- [ ] **Step 3: Verify**

Run: `npm run dev`
Open a space → tap "decide" → PossibilityHorizon shows items with images, reactions, and live scoring.

- [ ] **Step 4: Commit**

```bash
git add src/components/os/PossibilityHorizon.tsx
git commit -m "feat: PossibilityHorizon reaction surface with voting and live scores"
```

---

## Chunk 5: Commitment Flow

**Phase Goal:** Two-step commitment — consensus lock (Step 1) → claim + purchase (Step 2). The journey from "the group agrees" to "someone booked it."

### Task 5.1: Extend Handshake for Two-Step (Locked = No Owner)

**Files:**
- Modify: `src/lib/handshake.ts`
- Modify: `src/hooks/useHandshake.ts`

**Depends on:** Task 0.2 (state-flows.ts)

**Why:** Blueprint Section 4 — `locked` is now intermediate in BOOKING_FLOW. Consensus lock sets `is_locked = true` and `state = "locked"` but does NOT stamp an owner. Owner is stamped at claim step.

- [ ] **Step 1: Modify confirmHandshake in handshake.ts**

In the `confirmHandshake()` function, for BOOKING_FLOW items:
- Set `state: "locked"`, `is_locked: true`
- Do NOT set ownership (no `ownerId`, no `reason: "booker"`)
- CommitmentProof remains: `{ type: "verbal", value: "group consensus confirmed via @xark handshake" }`
- @xark whisper changes to: "locked. waiting for someone to own it."

For other flows (SIMPLE_VOTE_FLOW, SOLO_DECISION_FLOW), behavior is unchanged — they DO stamp an owner at their terminal state.

- [ ] **Step 2: Update useHandshake hook**

The `confirm()` callback should no longer pass `confirmerId` as owner for BOOKING_FLOW. Post-lock whisper changes to: "locked. waiting for someone to own it."

- [ ] **Step 3: Verify**

Run: `npx tsc --noEmit` — zero type errors.
Run: `npm run build` — clean build.

- [ ] **Step 4: Commit**

```bash
git add src/lib/handshake.ts src/hooks/useHandshake.ts
git commit -m "feat: two-step commitment — locked state has no owner in BOOKING_FLOW"
```

---

### Task 5.2: Create Claim Sheet Component

**Files:**
- Create: `src/components/os/ClaimSheet.tsx`
- Modify: `src/lib/claims.ts` (add claimWithoutPurchase)

**Depends on:** Task 5.1, Task 0.2 (state-flows.ts)

**Why:** Blueprint Section 4 — "i'll handle this" button on locked items. Claims ownership without purchase proof. State goes to `claimed`.

- [ ] **Step 1: Add claimItem to claims.ts for BOOKING_FLOW**

Modify `claimItem()` in `src/lib/claims.ts`:
- For items in `locked` state (BOOKING_FLOW), transition to `claimed` (not directly to terminal)
- Stamp owner: `{ ownerId, assignedAt, reason: "booker" }`
- No proof required at claim step (proof comes at purchase step)
- Optimistic concurrency via version field

- [ ] **Step 2: Create ClaimSheet component**

```
ClaimSheet.tsx — Slide-up sheet for claiming a locked item.
- Appears when user taps a locked item in PossibilityHorizon or Blueprint
- Shows item title at text.listTitle, opacity 0.9
- "i'll handle this" as floating text (text.label, colors.cyan, opacity 0.9)
- "not yet" as floating text (text.label, colors.white, opacity 0.4)
- On claim: calls claimItem(itemId, userId)
- On success: whisper "[name] is on it" at text.body, opacity 0.6
- Sheet: colors.void bg, 40vh max, slide from bottom via Framer Motion
- Overlay: #000 at opacity 0.8, NO blur
- Constitutional: no buttons with borders/backgrounds, no boxes
```

- [ ] **Step 3: Verify**

Run: `npm run build` — clean build.

- [ ] **Step 4: Commit**

```bash
git add src/components/os/ClaimSheet.tsx src/lib/claims.ts
git commit -m "feat: claim sheet for 'i'll handle this' on locked items"
```

---

### Task 5.3: Create Purchase Sheet Component

**Files:**
- Create: `src/components/os/PurchaseSheet.tsx`

**Depends on:** Task 5.2 (ClaimSheet, claims.ts update)

**Why:** Blueprint Section 4 + Section 8 — after claiming, the user purchases in the real world, then returns with proof + amount. State goes to `purchased`.

- [ ] **Step 1: Create PurchaseSheet component**

```
PurchaseSheet.tsx — Slide-up sheet for confirming purchase + entering amount.
- Appears when user taps a claimed item they own
- Shows item title at text.listTitle
- "how much?" input with cyan underline (text.input, same style as XarkChat input)
- Optional unit toggle: floating text options "per night" / "per person" / "total" (text.label, tap to cycle)
- Proof input: "link to confirmation or drop receipt" placeholder (text.input, opacity.ghost)
- "done" as floating text (colors.cyan, text.label)
- On submit:
  - Updates decision_items:
    - state: "purchased"
    - metadata.price: entered amount with unit
    - commitment_proof: { type: "receipt" or "verbal", value: proof text }
    - ownership: { ownerId, assignedAt, reason: "booker" }
  - System message: "[name] booked [title] for $[amount]"
- Sheet: same styling as ClaimSheet (void bg, 50vh max, slide up, #000 overlay)
- Constitutional: no buttons, no boxes, floating text only
```

- [ ] **Step 2: Wire into XarkChat and PossibilityHorizon**

When a user taps a `claimed` item that they own:
- In PossibilityHorizon: opens PurchaseSheet
- In chat: @xark whisper "you claimed [title]. ready to confirm the purchase?"

- [ ] **Step 3: Verify**

Run: `npm run dev`
Test flow: locked item → tap "i'll handle this" → claimed → tap item again → "how much?" → enter amount → purchased → system message appears.

- [ ] **Step 4: Commit**

```bash
git add src/components/os/PurchaseSheet.tsx
git commit -m "feat: purchase sheet with amount entry and proof confirmation"
```

---

### Task 5.4: System Messages for Lifecycle Events

**Files:**
- Modify: `src/lib/messages.ts`
- Modify: `src/components/os/XarkChat.tsx`
- Create: `supabase/migrations/007_system_messages_rpc.sql`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 5 — system messages render lifecycle events the group should see.

**RLS CONSTRAINT:** The existing `messages_insert_user` RLS policy in `003_rls_policies.sql` only allows `role = 'user'`. System messages with `role: "system"` will be BLOCKED by this policy. Solution: create a SECURITY DEFINER function to insert system messages server-side, bypassing RLS.

- [ ] **Step 1: Create SQL migration for system message RPC**

```sql
-- 007_system_messages_rpc.sql
-- SECURITY DEFINER function to insert system messages (bypasses RLS role='user' check)

CREATE OR REPLACE FUNCTION insert_system_message(
  p_space_id text,
  p_content text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO messages (id, space_id, role, content, user_id, created_at)
  VALUES (
    'msg_sys_' || gen_random_uuid()::text,
    p_space_id,
    'system',
    p_content,
    NULL,
    now()
  );
END;
$$;
```

Run this in Supabase SQL Editor.

- [ ] **Step 2: Add system message helpers to messages.ts**

```typescript
// System messages must go through SECURITY DEFINER RPC (RLS blocks role='system')
export async function saveSystemMessage(spaceId: string, content: string): Promise<void> {
  try {
    await supabase.rpc("insert_system_message", {
      p_space_id: spaceId,
      p_content: content,
    });
  } catch {
    // Silent fail — system messages are informational, not critical
  }
}

// Preset system messages
export const systemMessages = {
  itemLocked: (title: string) =>
    `${title} is locked. waiting for someone to own it.`,
  itemClaimed: (name: string, title: string) =>
    `${name} claimed ${title}`,
  itemPurchased: (name: string, title: string, amount: string) =>
    `${name} booked ${title} for ${amount}`,
  memberJoined: (name: string) =>
    `${name} joined the space`,
};
```

- [ ] **Step 3: Render system messages in XarkChat**

In `XarkChat.tsx`, handle `role: "system"` messages:
- Render at `text.subtitle` (0.65rem), `textColor(0.25)`, centered
- No role label, no timestamp
- Foveal opacity still applies but floor is 0.15

- [ ] **Step 4: Commit**

```bash
git add src/lib/messages.ts src/components/os/XarkChat.tsx supabase/migrations/007_system_messages_rpc.sql
git commit -m "feat: system messages via SECURITY DEFINER RPC (RLS-safe)"
```

---

## Chunk 6: Sharing + Joining

**Phase Goal:** Share a space link. Guest joins via link. Auto-membership.

### Task 6.1: Share Link + Join via Invite

**Files:**
- Modify: `src/app/space/[id]/page.tsx`
- Create: `supabase/migrations/008_join_via_invite.sql`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 6. The "share" floating text exists but needs proper invite link + join flow.

**RLS CONSTRAINT:** The existing `space_members_insert_system` policy in `003_rls_policies.sql` uses `WITH CHECK (false)` — ALL client-side inserts into `space_members` are blocked. Only SECURITY DEFINER functions can insert. We need a `join_via_invite(p_space_id)` function that validates the space exists and adds the calling user as a member.

- [ ] **Step 1: Create SQL migration for join_via_invite RPC**

```sql
-- 008_join_via_invite.sql
-- SECURITY DEFINER function for invite-based joining
-- Bypasses space_members INSERT policy (WITH CHECK false)

CREATE OR REPLACE FUNCTION join_via_invite(p_space_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify space exists
  IF NOT EXISTS (SELECT 1 FROM spaces WHERE id = p_space_id) THEN
    RAISE EXCEPTION 'space_not_found';
  END IF;

  -- Verify not already a member
  IF EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = p_space_id AND user_id = auth.uid()::text
  ) THEN
    RETURN; -- Already a member, no-op
  END IF;

  -- Add as member
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (p_space_id, auth.uid()::text, 'member');

  -- Insert system message
  INSERT INTO messages (id, space_id, role, content, user_id, created_at)
  VALUES (
    'msg_sys_' || gen_random_uuid()::text,
    p_space_id,
    'system',
    (SELECT display_name FROM users WHERE id = auth.uid()::text) || ' joined the space',
    NULL,
    now()
  );
END;
$$;
```

Run in Supabase SQL Editor.

- [ ] **Step 2: Read current space page**

Read `src/app/space/[id]/page.tsx` to understand the current share action.

- [ ] **Step 3: Enhance share with invite flow**

The share action generates: `https://xark.app/space/{spaceId}?invite=true`

When `navigator.share()` is available (mobile):
```typescript
navigator.share({
  title: spaceTitle,
  text: `join us on xark — ${spaceTitle}`,
  url: `${window.location.origin}/space/${spaceId}?invite=true`,
});
```

Desktop fallback: copy to clipboard + "link copied" whisper for 2s.

- [ ] **Step 4: Handle invite=true query param**

When a non-member opens a space URL with `?invite=true`:
1. If not logged in → redirect to `/login?redirect=/space/{id}&invite=true`
2. After login → call `supabase.rpc("join_via_invite", { p_space_id: spaceId })` (SECURITY DEFINER, bypasses RLS)
3. System message auto-inserted by the RPC
4. Remove `?invite=true` from URL

- [ ] **Step 5: Verify**

Run: `npm run dev`
Share a space link. Open in incognito. Login. Verify auto-membership.

- [ ] **Step 6: Commit**

```bash
git add src/app/space/[id]/page.tsx supabase/migrations/008_join_via_invite.sql
git commit -m "feat: share link + join_via_invite RPC (RLS-safe membership)"
```

---

## Chunk 7: Handshake Verification

**Phase Goal:** Verify the existing handshake protocol works with real reaction data.

### Task 7.1: End-to-End Handshake Test

**Files:**
- No new files. Verification only.

**Depends on:** Task 3.1 (reactions table), Task 3.2 (useReactions), Task 5.1 (two-step handshake)

- [ ] **Step 1: Create test scenario**

Using Supabase SQL Editor or seed script, create a scenario where:
1. Space "test-handshake" has 5 members
2. Item "test-hotel" in proposed state
3. 4 of 5 members react with `love_it` (agreementScore = 0.8, exactly at threshold)
4. Verify handshake does NOT fire (strictly greater than 0.80)
5. 5th member reacts with `works_for_me` (agreementScore = 1.0)
6. Verify handshake DOES fire

- [ ] **Step 2: Verify the UI flow**

1. Open the test space in browser
2. @xark whisper appears: "consensus reached on test-hotel. shall i lock this in?"
3. Tap "confirm" → item transitions to `locked`, Social Gold burst
4. @xark whisper: "locked. waiting for someone to own it."
5. Tap the locked item → ClaimSheet appears → "i'll handle this" → claimed
6. Tap claimed item → PurchaseSheet → enter amount → purchased
7. System message: "[name] booked test-hotel for $[amount]"

- [ ] **Step 3: Document any issues**

If any step fails, document the exact failure and fix in the relevant module.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: handshake verification fixes from end-to-end test"
```

---

## Chunk 8: Media Service

**Phase Goal:** Profile photos + trip photo uploads via Firebase Storage.

### Task 8.1: Media Database Migration

**Files:**
- Create: `supabase/migrations/005_media_devices.sql`

**Depends on:** Nothing (independent)

- [ ] **Step 1: Create migration**

```sql
-- 005_media_devices.sql
-- Media table for trip photos + user_devices for FCM tokens

CREATE TABLE IF NOT EXISTS media (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  uploaded_by text REFERENCES users(id),
  storage_path text NOT NULL,
  thumbnail_url text,
  mime_type text NOT NULL DEFAULT 'image/jpeg',
  caption text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_devices (
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text DEFAULT 'web',
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, fcm_token)
);

-- Add photo_url to users table if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url text;

-- Enable RLS on new tables (Supabase blocks all access without policies)
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Media: space members can SELECT and INSERT
CREATE POLICY media_select_member ON media
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

CREATE POLICY media_insert_member ON media
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
    AND uploaded_by = auth.uid()::text
  );

-- User devices: own rows only
CREATE POLICY devices_select_own ON user_devices
  FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY devices_insert_own ON user_devices
  FOR INSERT WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY devices_delete_own ON user_devices
  FOR DELETE USING (user_id = auth.uid()::text);

-- Enable Realtime for media
ALTER PUBLICATION supabase_realtime ADD TABLE media;
```

- [ ] **Step 2: Run in Supabase SQL Editor**

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/005_media_devices.sql
git commit -m "feat: add media + user_devices tables and photo_url column"
```

---

### Task 8.2: Media Upload Library

**Files:**
- Create: `src/lib/media.ts`
- Create: `src/app/api/media/upload/route.ts`

**Depends on:** Task 8.1 (media table deployed)

**Why:** Firebase Storage for binary blobs. Supabase for metadata. Upload flow: client → Firebase Storage → save metadata to Supabase.

- [ ] **Step 1: Create media.ts**

```typescript
// src/lib/media.ts
// XARK OS v2.0 — Media Service
// Firebase Storage for blobs, Supabase for metadata.

import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { supabase } from "@/lib/supabase";

export interface MediaItem {
  id: string;
  spaceId: string;
  uploadedBy: string;
  storagePath: string;
  thumbnailUrl?: string;
  caption?: string;
  createdAt: string;
}

export async function uploadMedia(
  file: File,
  spaceId: string,
  userId: string,
  caption?: string
): Promise<MediaItem | null> {
  if (!storage) {
    console.warn("Firebase Storage not configured");
    return null;
  }

  const mediaId = `media_${crypto.randomUUID()}`;
  const storagePath = `spaces/${spaceId}/media/${mediaId}`;
  const storageRef = ref(storage, storagePath);

  // Upload to Firebase Storage
  await uploadBytes(storageRef, file);
  const downloadUrl = await getDownloadURL(storageRef);

  // Save metadata to Supabase
  const { error } = await supabase.from("media").insert({
    id: mediaId,
    space_id: spaceId,
    uploaded_by: userId,
    storage_path: storagePath,
    thumbnail_url: downloadUrl,
    mime_type: file.type,
    caption: caption ?? null,
  });

  if (error) {
    console.error("Failed to save media metadata:", error.message);
    return null;
  }

  return {
    id: mediaId,
    spaceId,
    uploadedBy: userId,
    storagePath,
    thumbnailUrl: downloadUrl,
    caption,
    createdAt: new Date().toISOString(),
  };
}

export async function fetchMedia(spaceId: string): Promise<MediaItem[]> {
  const { data, error } = await supabase
    .from("media")
    .select("*")
    .eq("space_id", spaceId)
    .order("created_at", { ascending: true });

  if (error || !data) return [];

  return data.map((m) => ({
    id: m.id,
    spaceId: m.space_id,
    uploadedBy: m.uploaded_by,
    storagePath: m.storage_path,
    thumbnailUrl: m.thumbnail_url,
    caption: m.caption,
    createdAt: m.created_at,
  }));
}
```

- [ ] **Step 2: Create MediaUpload component**

Create `src/components/os/MediaUpload.tsx`:
- Floating "add photo" hint (text.hint, opacity 0.35). Not a button with border.
- Tapping opens file picker (accept="image/*")
- Optional caption input (text.input, cyan underline)
- Upload progress: cyan breathing dot
- On success: photo appears in the media stream

- [ ] **Step 3: Verify**

Run: `npm run dev`
Open a space → tap "add photo" → select image → uploads to Firebase Storage → metadata saved to Supabase → photo appears.

- [ ] **Step 4: Commit**

```bash
git add src/lib/media.ts src/components/os/MediaUpload.tsx
git commit -m "feat: media upload via Firebase Storage with Supabase metadata"
```

---

### Task 8.3: Profile Photo Upload

**Files:**
- Modify: `src/app/login/page.tsx` (add optional photo upload after name entry)
- Modify: `src/components/os/UserMenu.tsx` (show profile photo)

**Depends on:** Task 8.1 (users.photo_url column)

**Why:** Blueprint Section 6 — profile photos uploaded at login or later.

- [ ] **Step 1: Add optional photo upload to login flow**

After the name input (transit phase), optionally offer photo upload:
- Floating text: "add a photo" at text.hint, opacity 0.35
- Or "skip" at text.hint, opacity 0.2
- If photo selected: upload to `profiles/{userId}/avatar` in Firebase Storage
- Save URL to `users.photo_url` in Supabase
- Max 2MB, compressed client-side if needed

- [ ] **Step 2: Show profile photo in UserMenu and ControlCaret**

- UserMenu: show photo in avatar if `photo_url` exists
- ControlCaret slide-up: show member photos in avatars (already supports this via Avatar component)

- [ ] **Step 3: Commit**

```bash
git add src/app/login/page.tsx src/components/os/UserMenu.tsx
git commit -m "feat: profile photo upload at login + display in UserMenu"
```

---

## Chunk 9: Notification Service

**Phase Goal:** FCM push notifications for key lifecycle events. Service worker for background notifications.

### Task 9.1: FCM Service Worker

**Files:**
- Create: `public/firebase-messaging-sw.js`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 7 — background notifications require a service worker. Tapping a notification deep-links to the space.

- [ ] **Step 1: Create the service worker**

The service worker needs Firebase config injected. Since service workers can't access `process.env`, the config must either be hardcoded or injected via a controller message from the main thread. We'll use the controller message pattern for security.

```javascript
// public/firebase-messaging-sw.js
// XARK OS v2.0 — FCM Background Notifications
// Config injected via postMessage from main thread on registration.

importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

let messagingInitialized = false;

// Receive Firebase config from main thread
self.addEventListener("message", (event) => {
  if (event.data?.type === "FIREBASE_CONFIG" && !messagingInitialized) {
    firebase.initializeApp(event.data.config);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
      const { title, body, spaceId } = payload.data || {};
      self.registration.showNotification(title || "xark", {
        body: body || "",
        icon: "/icons/icon-192.png",
        data: { url: `/space/${spaceId}` },
      });
    });

    messagingInitialized = true;
  }
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = event.notification.data?.url || "/galaxy";
  event.waitUntil(clients.openWindow(url));
});
```

- [ ] **Step 2: Register service worker + inject config**

Create a client component `src/components/os/ServiceWorkerRegistration.tsx` (or add to an existing client component):

```typescript
"use client";
import { useEffect } from "react";

export function ServiceWorkerRegistration() {
  useEffect(() => {
    if ("serviceWorker" in navigator && process.env.NEXT_PUBLIC_FIREBASE_API_KEY) {
      navigator.serviceWorker.register("/firebase-messaging-sw.js").then((reg) => {
        // Inject Firebase config into service worker
        reg.active?.postMessage({
          type: "FIREBASE_CONFIG",
          config: {
            apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
            projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
            messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
            appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
          },
        });
      });
    }
  }, []);
  return null;
}
```

Add `<ServiceWorkerRegistration />` to `layout.tsx` inside `<ThemeProvider>`.

- [ ] **Step 3: Commit**

```bash
git add public/firebase-messaging-sw.js src/app/layout.tsx
git commit -m "feat: FCM service worker for background push notifications"
```

---

### Task 9.2: Notification Library + API Route

**Files:**
- Create: `src/lib/notifications.ts`
- Create: `src/app/api/notify/route.ts`

**Depends on:** Task 9.1 (service worker), Task 8.1 (user_devices table)

**Why:** Blueprint Section 7 — server-side push trigger for key lifecycle events.

- [ ] **Step 1: Install Firebase Admin SDK**

```bash
npm install firebase-admin
```

- [ ] **Step 2: Create notifications.ts**

```typescript
// src/lib/notifications.ts
// XARK OS v2.0 — Notification Service
// Server-side FCM push via Firebase Admin SDK.

import admin from "firebase-admin";

// Initialize Firebase Admin (singleton)
if (!admin.apps.length) {
  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(serviceAccount)),
    });
  }
}

export async function sendPush(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (!admin.apps.length || tokens.length === 0) return;

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: data ?? {},
    webpush: {
      fcmOptions: { link: data?.url ?? "/galaxy" },
    },
  });
}

export async function registerDevice(
  userId: string,
  fcmToken: string,
  platform: string = "web"
): Promise<void> {
  // This would be called from client-side after getting FCM token
  // Implementation via Supabase insert
}
```

- [ ] **Step 3: Create /api/notify route**

```typescript
// src/app/api/notify/route.ts
// Server-side push trigger. Called by lifecycle event handlers.

import { NextRequest, NextResponse } from "next/server";
import { sendPush } from "@/lib/notifications";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(req: NextRequest) {
  const { event, spaceId, title, body, excludeUserId } = await req.json();

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  // Get space members' FCM tokens
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId);

  if (!members) return NextResponse.json({ sent: 0 });

  const userIds = members
    .map((m) => m.user_id)
    .filter((id) => id !== excludeUserId);

  const { data: devices } = await supabaseAdmin
    .from("user_devices")
    .select("fcm_token")
    .in("user_id", userIds);

  if (!devices || devices.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  const tokens = devices.map((d) => d.fcm_token);
  await sendPush(tokens, title, body, { spaceId, event });

  return NextResponse.json({ sent: tokens.length });
}
```

- [ ] **Step 4: Verify**

Run: `npm run build` — clean build.

- [ ] **Step 5: Commit**

```bash
git add src/lib/notifications.ts src/app/api/notify/route.ts
git commit -m "feat: notification service with FCM push via /api/notify"
```

---

## Chunk 10: Settlement + Itinerary + Memories

**Phase Goal:** Amount entry feeds settlement. Itinerary view for active trips. Memories view post-trip.

### Task 10.1: Fix Bug B3 — Settlement Member Count

**Files:**
- Modify: `src/lib/ledger.ts`

**Depends on:** Nothing (independent)

**Why:** Blueprint Section 12, Bug B3 — `ledger.ts` sets `memberCount = entries.length` (payers only). Should query `space_members` for true group size.

- [ ] **Step 1: Read current ledger.ts**

Read `src/lib/ledger.ts` to find where `memberCount` is set.

- [ ] **Step 2: Fix memberCount to use true space member count**

Change `fetchSettlement(spaceId)` to:
1. Query `space_members` WHERE `space_id = spaceId` to get actual member count
2. Use that count for `fairShare = totalSpent / memberCount`

```typescript
// Add to fetchSettlement:
const { data: membersData } = await supabase
  .from("space_members")
  .select("user_id")
  .eq("space_id", spaceId);
const memberCount = membersData?.length ?? entries.length;
```

- [ ] **Step 3: Verify**

Run: `npx tsc --noEmit` — zero type errors.

- [ ] **Step 4: Commit**

```bash
git add src/lib/ledger.ts
git commit -m "fix: settlement uses true space member count, not just payer count (B3)"
```

---

### Task 10.2: Create Itinerary View Component

**Files:**
- Create: `src/components/os/ItineraryView.tsx`

**Depends on:** Task 5.3 (purchased items with dates)

**Why:** Blueprint Section 9 — purchased items ordered chronologically during active trip.

- [ ] **Step 1: Create ItineraryView.tsx**

```
ItineraryView.tsx — Chronological list of purchased items.
- Fetches decision_items WHERE space_id AND state IN ('purchased', 'locked', 'claimed')
- Ordered by metadata.date or metadata.check_in ascending
- Each row:
  - Date label (text.recency, textColor(0.35))
  - ConsensusMark in ignited state (gold, ✦ equivalent)
  - Title (text.listTitle, opacity 0.9)
  - Cost + owner name (text.subtitle, opacity 0.4)
  - Tap to expand: description, proof, external link
- Photos interspersed by date (from fetchMedia)
- 1px timeline line at opacity 0.1 (same as Blueprint)
- Framer Motion staggered entrance
- Empty state: "no confirmed plans yet" at opacity 0.2
- Constitutional: no cards, no borders. Items float on timeline.
```

- [ ] **Step 2: Wire into Space view**

Add "itinerary" as a third view option in `src/app/space/[id]/page.tsx`:
- Only visible when `computeSpaceState(items)` returns `"ready"`, `"active"`, or `"settled"`
- Floating text toggle alongside "discuss" and "decide"

- [ ] **Step 3: Verify**

Run: `npm run dev`
Open san diego trip → should show itinerary with Hotel Del Coronado and Gaslamp Quarter (both purchased in seed data).

- [ ] **Step 4: Commit**

```bash
git add src/components/os/ItineraryView.tsx src/app/space/[id]/page.tsx
git commit -m "feat: itinerary view with chronological purchased items"
```

---

### Task 10.3: Create Memories View (Post-Trip)

**Files:**
- Create: `src/components/os/MemoriesView.tsx`

**Depends on:** Task 8.2 (media.ts), Task 10.2 (ItineraryView)

**Why:** Blueprint Section 9 — post-trip, photos are the story. Itinerary shrinks to a link.

- [ ] **Step 1: Create MemoriesView.tsx**

```
MemoriesView.tsx — Photo-first post-trip view.
- Shows when computeSpaceState returns "settled"
- Photos in horizontal scroll (snap-x, snap-mandatory, snap-center) grouped by date
- Each photo: edge-to-edge, bottom vignette, caption at text.body opacity 0.7
- "trip details" as floating text (text.hint, opacity 0.25)
  - Tap → expands ItineraryView + settlement
- Empty state: "no photos yet" at opacity 0.2
- Constitutional: no cards, no borders, edge-to-edge images
```

- [ ] **Step 2: Wire into Space view**

When `computeSpaceState` returns `"settled"`, the Space view shows MemoriesView by default instead of the discuss/decide toggle. The toggle becomes: "memories" (default, active) / "details" (itinerary + settlement).

- [ ] **Step 3: Commit**

```bash
git add src/components/os/MemoriesView.tsx src/app/space/[id]/page.tsx
git commit -m "feat: memories view — photo-first post-trip experience"
```

---

### Task 10.4: Enhanced Blueprint Settlement

**Files:**
- Modify: `src/components/os/Blueprint.tsx`

**Depends on:** Task 10.1 (ledger fix)

**Why:** Blueprint Section 8 — amount entry from PurchaseSheet feeds settlement. Blueprint view should show per-user totals with real amounts from purchased items.

- [ ] **Step 1: Verify Blueprint renders purchased items**

Blueprint already fetches locked items. Ensure it also fetches items in `claimed` and `purchased` states (both have `is_locked = true`).

- [ ] **Step 2: Enhance settlement display**

The Settlement Strip should:
- Show total committed amount
- Per-user breakdown: "[name] paid $[total] — [item1 $X, item2 $Y]"
- Debt deltas: "[name] owes [name] $[amount]"
- Payment links: "venmo" and "upi" as floating cyan text
- All amounts from `metadata.price` of purchased items

- [ ] **Step 3: Commit**

```bash
git add src/components/os/Blueprint.tsx
git commit -m "feat: enhanced settlement display with real purchased amounts"
```

---

## Chunk 11: Guardrail Sync

**Phase Goal:** Update all 4 guardrail files to reflect the complete implementation. Final validation.

### Task 11.1: Update .xark-state.json

**Files:**
- Modify: `.xark-state.json`

**Depends on:** All previous phases complete

- [ ] **Step 1: Update foveal_focus**

Set `foveal_focus` to reflect completed implementation state.

- [ ] **Step 2: Update component_registry**

Add all new components and mark them as "active" or "verified":
- `ClaimSheet`: "active"
- `PurchaseSheet`: "active"
- `MediaUpload`: "active"
- `ItineraryView`: "active"
- `MemoriesView`: "active"
- `VoiceInput`: "active"

- [ ] **Step 3: Update xark_intelligence section**

Add entries for:
- `intelligence/orchestrator.ts`
- `intelligence/tool-registry.ts`
- `intelligence/apify-client.ts`
- `notifications.ts`
- `media.ts`
- `state-flows.ts`
- `space-state.ts`

- [ ] **Step 4: Commit**

```bash
git add .xark-state.json
git commit -m "sync: update .xark-state.json with full implementation state"
```

---

### Task 11.2: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Depends on:** All previous phases complete

- [ ] **Step 1: Add new components to CLAUDE.md**

Document:
- Intelligence Service (orchestrator, tool registry, Apify client)
- `state-flows.ts` shared module
- `space-state.ts` emergent state
- ClaimSheet + PurchaseSheet commitment flow
- Media service (media.ts, MediaUpload.tsx)
- Notification service (notifications.ts, FCM service worker)
- ItineraryView + MemoriesView
- Voice input (useVoiceInput hook)
- System messages in XarkChat
- PWA manifest + meta tags

- [ ] **Step 2: Update BOOKING_FLOW documentation**

```
BOOKING_FLOW (extended): proposed → [voting] → locked → claimed → purchased
- locked: consensus reached, no owner
- claimed: someone stepped up, owner stamped
- purchased: proof + amount confirmed, feeds settlement
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "sync: update CLAUDE.md with full implementation documentation"
```

---

### Task 11.3: Update CONSTITUTION.md + GROUNDING_PROTOCOL.md

**Files:**
- Modify: `CONSTITUTION.md`
- Modify: `GROUNDING_PROTOCOL.md`

**Depends on:** All previous phases complete

- [ ] **Step 1: Add new sections to CONSTITUTION.md**

- ClaimSheet + PurchaseSheet visual spec
- ItineraryView timeline spec
- MemoriesView photo scroll spec
- Voice input mic indicator spec
- System message rendering spec
- MediaUpload hint spec

- [ ] **Step 2: Update GROUNDING_PROTOCOL.md**

- Add voice input section (Section 8 enhancement)
- Add system message format
- Update intelligence service architecture

- [ ] **Step 3: Commit**

```bash
git add CONSTITUTION.md GROUNDING_PROTOCOL.md
git commit -m "sync: update CONSTITUTION.md + GROUNDING_PROTOCOL.md with full spec"
```

---

### Task 11.4: Final Build Verification

**Files:** None (verification only)

**Depends on:** All previous tasks

- [ ] **Step 1: Type check**

```bash
npx tsc --noEmit
```
Expected: 0 errors.

- [ ] **Step 2: Build**

```bash
npm run build
```
Expected: clean build, no warnings.

- [ ] **Step 3: Tier 3 Audit**

Search entire codebase for forbidden patterns:
```bash
grep -rn "font-bold\|font-semibold\|font-weight: [5-9]00\|supabase/auth\|@supabase/auth\|backdrop-filter\|backdropFilter" src/
```
Expected: 0 matches.

- [ ] **Step 4: Run dev and smoke test**

```bash
npm run dev
```
1. Login as "ram" → Galaxy shows real awareness events
2. Tap san diego trip → discuss shows real messages
3. Tap decide → PossibilityHorizon shows items with reactions
4. React to an item → scores update in real-time
5. Check ControlCaret → real spaces with member names
6. @xark responds when invoked
7. Share a space link → works
8. PWA: Chrome DevTools → Application → Manifest loads correctly

---

## Dependency Graph

```
Phase 0 (Foundation)
├── Task 0.1: PWA ─────────────────────────────── (independent)
├── Task 0.2: state-flows.ts ──────────────────── (independent)
├── Task 0.3: space-state.ts ──────────────────── (independent)
└── Task 0.4: Fix B4 spaces.ts ────────────────── (independent)

Phase 1 (Living Home Screen)
├── Task 1.1: awareness.ts real data ──────────── (needs seed data)
├── Task 1.2: space-data.ts real data ─────────── (needs seed data)
├── Task 1.3: Galaxy real feed ────────────────── (needs 1.1)
└── Task 1.4: ControlCaret real data ──────────── (needs 1.2)

Phase 2 (Intelligence Service)
├── Task 2.1: tool-registry.ts ────────────────── (independent)
├── Task 2.2: apify-client.ts ─────────────────── (needs 2.1)
├── Task 2.3: orchestrator.ts ─────────────────── (needs 2.1, 2.2)
├── Task 2.4: /api/xark route ────────────────── (needs 2.3)
├── Task 2.5: Fix B1+B2 ai-grounding.ts ──────── (independent)
└── Task 2.6: Voice input ────────────────────── (needs 2.4)

Phase 3 (Decision Engine)
├── Task 3.1: unreact RPC + Realtime SQL ──────── (independent)
├── Task 3.2: useReactions hook ───────────────── (needs 3.1)
└── Task 3.3: heart-sort full port ────────────── (independent)

Phase 4 (PossibilityHorizon)
└── Task 4.1: Reaction surface ────────────────── (needs 3.2, 3.3)

Phase 5 (Commitment Flow)
├── Task 5.1: Two-step handshake ──────────────── (needs 0.2)
├── Task 5.2: ClaimSheet ─────────────────────── (needs 5.1)
├── Task 5.3: PurchaseSheet ───────────────────── (needs 5.2)
└── Task 5.4: System messages + RPC ───────────── (independent, needs SQL deploy)

Phase 6 (Sharing + Joining)
└── Task 6.1: Share link + join RPC ───────────── (independent, needs SQL deploy)

Phase 7 (Handshake Verification)
└── Task 7.1: E2E test ───────────────────────── (needs 3.1, 3.2, 5.1)

Phase 8 (Media)
├── Task 8.1: media + devices SQL ─────────────── (independent)
├── Task 8.2: Media upload ────────────────────── (needs 8.1)
└── Task 8.3: Profile photos ──────────────────── (needs 8.1)

Phase 9 (Notifications)
├── Task 9.1: FCM service worker ──────────────── (independent)
└── Task 9.2: Notification lib + /api/notify ──── (needs 9.1, 8.1)

Phase 10 (Settlement + Itinerary)
├── Task 10.1: Fix B3 ledger.ts ───────────────── (independent)
├── Task 10.2: ItineraryView ──────────────────── (needs 5.3)
├── Task 10.3: MemoriesView ───────────────────── (needs 8.2, 10.2)
└── Task 10.4: Enhanced Blueprint settlement ──── (needs 10.1)

Phase 11 (Guardrail Sync)
├── Task 11.1: .xark-state.json ───────────────── (needs all)
├── Task 11.2: CLAUDE.md ──────────────────────── (needs all)
├── Task 11.3: CONSTITUTION + GROUNDING ────────── (needs all)
└── Task 11.4: Final verification ─────────────── (needs all)
```

## Parallelization Map (for multi-agent execution)

These task groups can run concurrently (no shared state):

**Wave 1** (all independent):
- Task 0.1 (PWA)
- Task 0.2 (state-flows)
- Task 0.3 (space-state)
- Task 0.4 (Fix B4)
- Task 2.1 (tool-registry)
- Task 2.5 (Fix B1+B2)
- Task 3.1 (unreact RPC + Realtime SQL)
- Task 3.3 (heart-sort port)
- Task 5.4 (system messages + SQL deploy)
- Task 6.1 (share link + SQL deploy)
- Task 8.1 (media + devices SQL + RLS)
- Task 9.1 (FCM service worker)
- Task 10.1 (Fix B3)

**Wave 2** (depends on Wave 1):
- Task 1.1 (awareness real data)
- Task 1.2 (space-data real data)
- Task 2.2 (apify-client → needs 2.1)
- Task 3.2 (useReactions → needs 3.1)
- Task 5.1 (two-step handshake → needs 0.2)
- Task 8.2 (media upload → needs 8.1)
- Task 8.3 (profile photos → needs 8.1)

**Wave 3** (depends on Wave 2):
- Task 1.3 (Galaxy → needs 1.1)
- Task 1.4 (ControlCaret → needs 1.2)
- Task 2.3 (orchestrator → needs 2.2)
- Task 4.1 (PossibilityHorizon → needs 3.2, 3.3)
- Task 5.2 (ClaimSheet → needs 5.1)
- Task 9.2 (notifications → needs 9.1, 8.1)
- Task 10.4 (Blueprint settlement → needs 10.1)

**Wave 4** (depends on Wave 3):
- Task 2.4 (/api/xark → needs 2.3)
- Task 5.3 (PurchaseSheet → needs 5.2)
- Task 10.2 (ItineraryView → needs 5.3)

**Wave 5** (depends on Wave 4):
- Task 2.6 (voice input → needs 2.4)
- Task 7.1 (handshake E2E → needs 3.1, 3.2, 5.1)
- Task 10.3 (MemoriesView → needs 8.2, 10.2)

**Wave 6** (final):
- Tasks 11.1–11.4 (guardrail sync + verification)
