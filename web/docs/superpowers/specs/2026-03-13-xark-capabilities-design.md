# @xark Capabilities Design — Calendar, Travel Dates, Per-User Logistics

**Date:** 2026-03-13
**Status:** Approved
**Scope:** Three new @xark capabilities for Xark OS v2.0

---

## 1. Travel Dates — Conversational Date Management

### Problem
Xark has no first-class date entity. Dates are scattered in `decision_items.metadata` fields (`date`, `check_in`, `check_out`). Changing trip dates requires updating every item individually. At scale, a single date change cascades into rechecking flights, hotels, car reservations for every member.

### Design

**New table: `space_dates`**

```sql
CREATE TABLE space_dates (
  space_id    text PRIMARY KEY REFERENCES spaces(id) ON DELETE CASCADE,
  start_date  date NOT NULL,
  end_date    date NOT NULL,
  destination text,           -- "san diego", "tokyo" — resolved from space title or @xark
  label       text,           -- "spring break", "tokyo week 1"
  set_by      text REFERENCES users(id),
  version     integer NOT NULL DEFAULT 1,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  CONSTRAINT valid_range CHECK (end_date >= start_date)
);

-- RLS: space members only (auth.uid()::text matches Firebase UID via JWT bridge)
ALTER TABLE space_dates ENABLE ROW LEVEL SECURITY;
CREATE POLICY sd_read ON space_dates FOR SELECT USING (
  EXISTS (SELECT 1 FROM space_members sm WHERE sm.space_id = space_dates.space_id AND sm.user_id = auth.uid()::text)
);
CREATE POLICY sd_write ON space_dates FOR ALL USING (auth.role() = 'service_role');
```

**Key decisions:**
- `date` type, not `timestamptz` — no timezone ambiguity
- `destination` column — used by `onMemberJoin` to auto-populate flight destinations. Resolved from space title or explicitly set via @xark
- Optimistic concurrency via `version` field — prevents race conditions when two members change dates simultaneously
- One row per space (v1). Multi-segment trips (different dates for different legs) deferred
- No date history table in v1. `version` tracks concurrency but not audit trail. History deferred

**Confirmation gate:** @xark never silently writes dates. Flow:
1. User says "@xark dates are mar 10-15" or "@xark move trip to april"
2. Gemini parses → extracts dates
3. @xark whispers: "set dates to mar 10 – mar 15?"
4. User confirms → saved with version bump
5. @xark whispers: "dates updated. 3 items may need refreshing"

**Extended `OrchestratorResult` type** (C3 fix — existing type only has search/reason/propose):

```typescript
export interface OrchestratorResult {
  response: string;
  searchResults?: ApifyResult[];
  action?: "search" | "reason" | "propose" | "set_dates" | "populate_logistics";
  tool?: string;
  pendingConfirmation?: boolean;
  payload?: Record<string, unknown>;
  extractions?: Array<{ user_name: string; category?: string; origin?: string; destination?: string; confidence: number }>;
}
```

**New orchestrator action: `set_dates`**

```typescript
case "set_dates": {
  const { start_date, end_date, label } = result;
  // Confirmation gate — return message, don't write yet
  return {
    response: `set dates to ${start_date} – ${end_date}?`,
    action: 'set_dates',
    pendingConfirmation: true,
    payload: { start_date, end_date, label },
  };
}
```

**Confirmation state (v1):** Pending confirmation is held in client-side XarkChat component state. Page refresh clears pending state — user must re-invoke. v1.1: consider server-side `pending_actions` table for durability.

On confirmation, the API route:
1. Upserts `space_dates` with version increment
2. Flags stale items: `UPDATE decision_items SET metadata = metadata || '{"needs_refresh": true}' WHERE space_id = $1 AND metadata->>'source' = 'apify'`
3. Does NOT auto-re-search. Pull-based revalidation — user or @xark initiates refresh

**O(1) date change cost:** Decoupled from item count. One `space_dates` upsert + one bulk `needs_refresh` flag. No cascading Apify calls.

**Staleness UX:** Items with `needs_refresh: true` show subtle indicator (text.hint, "dates changed · tap to refresh"). @xark can mention: "3 items may have different availability for the new dates."

**`computeSpaceState()` update:** Accepts optional `tripDates` parameter to decouple from item metadata dates:

```typescript
export function computeSpaceState(
  items: SpaceStateItem[],
  tripDates?: { start_date: string; end_date: string }
): SpaceState
```

---

## 2. Calendar Integration — Layers 1 & 2 (v1)

### Problem
PWA browser sandbox cannot access local calendar APIs. Users need to get locked decisions into their calendars.

### Design: Four Layers (v1 ships Layers 1 & 2)

**Layer 1: .ics Export**
Generate downloadable .ics files from locked decision items with date metadata.

```typescript
// src/lib/calendar.ts
// Uses VALUE=DATE (all-day events) — no VTIMEZONE needed (intentional, not oversight)
export function generateICS(
  items: LockedItemWithDates[],
  spaceTitle: string,
  tripDates?: { start_date: string; end_date: string }  // fallback from space_dates
): string {
  const events = items
    .filter(item => item.metadata?.date || item.metadata?.check_in || tripDates)
    .map(item => {
      const start = item.metadata?.check_in || item.metadata?.date || tripDates?.start_date;
      const end = item.metadata?.check_out || item.metadata?.date || tripDates?.end_date;
      if (!start) return null;
      return [
        'BEGIN:VEVENT',
        `DTSTART;VALUE=DATE:${formatICSDate(start)}`,
        `DTEND;VALUE=DATE:${formatICSDate(end || start)}`,
        `SUMMARY:${item.title}`,
        `DESCRIPTION:${spaceTitle} — locked via xark`,
        `UID:${item.id}@xark.app`,
        'END:VEVENT',
      ].join('\r\n');
    })
    .filter(Boolean);

  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//xark//xark-os//EN',
    ...events,
    'END:VCALENDAR',
  ].join('\r\n');
}
```

**Trigger:** @xark whisper after items lock: "added to your trip. want to save to calendar?" → generates .ics blob → browser download.

**Layer 2: Deep Links**
Platform-specific calendar deep links for one-tap add:

```typescript
export function calendarDeepLink(
  title: string,
  startDate: string,
  endDate: string,
  description: string
): { google: string; outlook: string } {
  const googleUrl = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${enc(title)}&dates=${fmtGoogle(startDate)}/${fmtGoogle(endDate)}&details=${enc(description)}`;
  const outlookUrl = `https://outlook.live.com/calendar/0/action/compose?subject=${enc(title)}&startdt=${startDate}&enddt=${endDate}&body=${enc(description)}`;
  return { google: googleUrl, outlook: outlookUrl };
}
```

**UX:** After lock confirmation, @xark whispers: "save to calendar?" with floating text links: "google" and "outlook" (same styling as venmo/upi in Blueprint — text.label, colors.cyan).

**Conflict Detection (Layer 3) — deferred to v1.1:** Requires OAuth to Google/Outlook calendar APIs. User grants read access → @xark checks for conflicts before proposing dates.

**Auto-Sync (Layer 4) — deferred to v1.2+:** Background worker syncs locked items to calendar. Requires persistent OAuth tokens + webhook infrastructure.

---

## 3. Per-User Scoped Items — Three-Source Passive Assembly

### Problem
Current system treats all items as group-level. A trip with members from different cities needs per-user flights (Ram from SFO, Ananya from JFK). No per-user scoping exists. Asking each member individually doesn't scale to 1M users.

### Design: Three-Source Model

@xark **assembles** per-user travel profiles from three passive sources. No forms. No per-user prompts. No waiting.

**Source 1: Persistent User Profile**

```sql
ALTER TABLE users ADD COLUMN home_city text;
-- NOTE: fn_restrict_user_update (003_rls_policies.sql) uses an allowlist that freezes
-- id, phone, password_hash, created_at. New columns like home_city pass through by design.
-- The migration MUST add a comment to fn_restrict_user_update confirming home_city is mutable.
```

Set once — first time @xark needs a flight origin and no data exists. Stored forever. 1M users each answer once, not per trip. `home_city` is never sent to client — only read server-side by `supabaseAdmin` to populate `member_logistics.origin`.

**Source 2: Creator Context**

The space creator knows where their friends live. One natural-language message:
> "planning san diego with ananya from nyc and maya from chicago"

Gemini extracts all origins from this single message. **1 message populates N members.** At 1M users, work is O(creators), not O(members).

**Source 3: Passive Chat Extraction**

@xark scans messages it already receives (in grounding context) for origin signals:
- "i'll fly from lax this time" → trip-specific override
- "ananya's coming from boston, not nyc" → correction

**Zero additional API calls** — extraction piggybacked on existing `/api/xark` Gemini calls via 3 lines in system prompt.

**Resolution priority:** Trip override (Source 3) > Creator-provided (Source 2) > Profile default (Source 1)

### Schema

```sql
CREATE TABLE member_logistics (
  space_id    text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  user_id     text NOT NULL REFERENCES users(id),
  category    text NOT NULL CHECK (category IN (
    'flight_outbound','flight_return','ground_transport','visa','insurance'
  )),
  origin      text,
  destination text,
  state       text NOT NULL DEFAULT 'missing' CHECK (state IN (
    'missing','searching','proposed','locked','needs_review'
  )),
  item_id     text REFERENCES decision_items(id) ON DELETE SET NULL,
  source      text CHECK (source IN ('profile','creator','chat','manual')),
  confidence  real CHECK (confidence >= 0 AND confidence <= 1),
  version     integer NOT NULL DEFAULT 1,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  PRIMARY KEY (space_id, user_id, category)
);

CREATE INDEX idx_ml_space ON member_logistics(space_id);
CREATE INDEX idx_ml_user  ON member_logistics(user_id, state);
```

### RLS Policies

```sql
ALTER TABLE member_logistics ENABLE ROW LEVEL SECURITY;

-- Read: space members only (auth.uid()::text — Firebase UID via JWT bridge, per 003_rls_policies.sql pattern)
CREATE POLICY ml_read ON member_logistics FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = member_logistics.space_id
    AND sm.user_id = auth.uid()::text
  )
);

-- Update own rows: users modify only their own logistics
CREATE POLICY ml_update_own ON member_logistics FOR UPDATE USING (
  user_id = auth.uid()::text
) WITH CHECK (user_id = auth.uid()::text);

-- Insert: service role (onMemberJoin auto-population) OR own rows by space members
-- Own-row insert covers the case where auto-population failed or new categories are needed
CREATE POLICY ml_insert ON member_logistics FOR INSERT WITH CHECK (
  auth.role() = 'service_role'
  OR (
    user_id = auth.uid()::text
    AND EXISTS (SELECT 1 FROM space_members sm WHERE sm.space_id = member_logistics.space_id AND sm.user_id = auth.uid()::text)
  )
);

-- Delete own rows (self-correction) or cascade on member leave
CREATE POLICY ml_delete_own ON member_logistics FOR DELETE USING (
  user_id = auth.uid()::text
);
```

**Note:** `onMemberJoin` always creates skeleton rows for all categories (even with null origin), so UPDATE is the primary self-correction path. The INSERT policy is a safety net for edge cases where auto-population fails.

### Security Model

| Threat | Mitigation |
|--------|-----------|
| User A reads User B's `home_city` | `home_city` never sent to client. Only `origin` in `member_logistics` visible to space members via RLS |
| Creator sets wrong origin | Confirmation gate. `source: 'creator'` flagged → member sees "ram set your origin as JFK — correct?" |
| Passive extraction error | `confidence` threshold (>0.8). Below = not saved. Above = saved with confirmation pending |
| Cross-space data leak | RLS enforces `space_members` check on every read |
| Stale data after user moves | `home_city` editable in user settings. Trip-level overrides take priority |

### Orchestrator Action: `populate_logistics`

Added to orchestrator intent prompt options. Gemini extracts member origins/destinations from message context and returns structured data:

```json
{
  "action": "populate_logistics",
  "extractions": [
    { "user_name": "ananya", "origin": "JFK", "confidence": 0.95 },
    { "user_name": "maya", "origin": "ORD", "confidence": 0.90 }
  ]
}
```

Handler resolves `user_name` → `user_id` via `space_members JOIN users ON user_id = users.id WHERE LOWER(display_name) = LOWER($name)`. Filters by confidence >0.8. If multiple members match a name (e.g., two "Maya"s), confidence drops to 0.5 (below threshold) and @xark asks: "which maya — maya chen or maya patel?" Upserts into `member_logistics`, returns confirmation whisper.

### Auto-Population on Member Join

Always creates skeleton rows for ALL categories — even with null origin. This ensures UPDATE-based self-correction always works (row always exists).

```typescript
async function onMemberJoin(spaceId: string, userId: string) {
  // users.home_city read via supabaseAdmin (service role) — never exposed to client
  const { data: user } = await supabaseAdmin
    .from('users').select('home_city').eq('id', userId).single();

  // space_dates.destination — the trip destination
  const { data: dates } = await supabaseAdmin
    .from('space_dates').select('destination').eq('space_id', spaceId).single();

  const dest = dates?.destination ?? null;
  const home = user?.home_city ?? null;

  // Create skeleton rows for all flight categories (always, even with nulls)
  const rows = ['flight_outbound', 'flight_return'].map(cat => ({
    space_id: spaceId,
    user_id: userId,
    category: cat,
    origin: cat === 'flight_outbound' ? home : dest,
    destination: cat === 'flight_outbound' ? dest : home,
    state: 'missing' as const,
    source: home ? 'profile' as const : null,
    confidence: home ? 1.0 : null,
  }));

  await supabaseAdmin.from('member_logistics')
    .upsert(rows, { onConflict: 'space_id,user_id,category', ignoreDuplicates: true });
}
```

### Personalized Views

Each user sees their own logistics prominently, with group summary for coordination:
- **Ram sees:** "your flights: SFO → SAN" with his flight items
- **Ananya sees:** "your flights: JFK → SAN" with her flight items
- **Group summary visible to all:** "ram: flights locked · ananya: searching"

### Awareness Integration

New `AwarenessKind: 'needs_flight'` — surfaces on Galaxy when a member has logistics with `origin` set but no `item_id`:
> "san diego trip · you still need a flight"

### Date Change → Staleness Cascade

When `space_dates` version bumps:
1. All `member_logistics` rows with `state: 'proposed'` or `state: 'locked'` get `state: 'needs_review'`
2. Linked `decision_items` get `metadata.needs_refresh: true`
3. @xark whispers: "dates changed. your flight from SFO may need updating"
4. No auto-re-search. User or @xark initiates refresh

### Scale Analysis

| Scale | Rows (member_logistics) | API calls added | Profile prompts |
|-------|------------------------|----------------|----------------|
| 10 users, 3 spaces | ~60 | 0 (piggybacked) | ~10 (one-time) |
| 10K users, 5K spaces | ~50K | 0 | ~10K (one-time) |
| 1M users, 200K spaces | ~5M | 0 | ~0 (repeat users) |

---

## Cross-Cutting Concerns

### New Orchestrator Actions Summary

| Action | Trigger | Gemini cost | DB writes |
|--------|---------|-------------|-----------|
| `set_dates` | "@xark dates are mar 10-15" | Part of existing call | 1 upsert + 1 bulk flag |
| `populate_logistics` | Passive extraction from any message | Part of existing call | N upserts (N = extracted members) |

### New SQL Migrations Required

Migration numbering: existing migrations go 001-005, 007-008 (006 missing). Verify numbering at implementation time.

1. `009_space_dates.sql` — `CREATE TABLE space_dates` (with `destination` column) + RLS
2. `010_member_logistics.sql` — `ALTER TABLE users ADD COLUMN home_city` + update `fn_restrict_user_update` comment + `CREATE TABLE member_logistics` + RLS + indexes + DELETE policy
3. All RLS policies use `auth.uid()::text` cast (matching 003_rls_policies.sql pattern for Firebase UID via JWT bridge)

### Files to Create/Modify

| File | Action |
|------|--------|
| `src/lib/calendar.ts` | New — .ics generation + deep links |
| `src/lib/intelligence/orchestrator.ts` | Modify — add `set_dates` + `populate_logistics` actions |
| `src/app/api/xark/route.ts` | Modify — handle new action types, confirmation flow |
| `src/lib/space-state.ts` | Modify — accept `tripDates` parameter |
| `src/lib/awareness.ts` | Modify — add `needs_flight` event kind |
| `supabase/migrations/009_space_dates.sql` | New |
| `supabase/migrations/010_member_logistics.sql` | New |

### What v1 Ships

- Travel dates: full (conversational set/modify, versioning, staleness flags)
- Calendar: Layers 1+2 (.ics export + Google/Outlook deep links)
- Per-user logistics: full three-source model (profile + creator + passive extraction)
- Calendar Layers 3+4 (OAuth conflict detection, auto-sync): deferred to v1.1+

### What v1 Does NOT Ship

- Multi-segment trip dates (different dates per leg)
- Native calendar access (requires Capacitor wrap)
- Auto re-search on date change (intentionally pull-based)
- Flight booking (items are links to external platforms)
- Server-side pending confirmation state (v1 uses client-side state)
- Date change audit trail / history table
- Dynamic logistics categories beyond the initial 5 (CHECK constraint; new categories require migration)

### Auth Integration Note

Xark uses Firebase Auth exclusively (Supabase Auth is banned). All RLS policies in this spec use `auth.uid()::text` — the Firebase UID is injected into Supabase JWT claims via the JWT bridge configured in `supabase-admin.ts`. This matches the pattern established in `003_rls_policies.sql`. All write operations go through `supabaseAdmin` (service role) in API routes, never direct client inserts.
