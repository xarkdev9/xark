# @xark Capabilities Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add travel dates, calendar export, and per-user logistics to Xark OS

**Architecture:** Seven chunks. Chunk 0 is test infrastructure (prerequisite). Chunks 1-5 are independently deployable by separate agents with zero cross-dependencies. Chunk 6 wires everything together (deploy last).

**Tech Stack:** Next.js 15, React 19, TypeScript 5, Supabase Postgres, Framer Motion, Vitest

**Spec:** `docs/superpowers/specs/2026-03-13-xark-capabilities-design.md`

---

## File Structure

| File | Action | Chunk | Responsibility |
|------|--------|-------|---------------|
| `vitest.config.ts` | Create | 0 | Test runner configuration with path aliases |
| `supabase/migrations/009_space_dates.sql` | Create | 1 | space_dates table + RLS |
| `supabase/migrations/010_member_logistics.sql` | Create | 2 | member_logistics table + users.home_city + RLS |
| `src/lib/calendar.ts` | Create | 3 | .ics generation + calendar deep links |
| `src/lib/space-state.ts` | Modify | 4 | Accept optional tripDates parameter |
| `src/lib/member-logistics.ts` | Create | 5 | onMemberJoin + logistics queries |
| `src/lib/awareness.ts` | Modify | 5 | Wire needs_flight events from member_logistics |
| `src/lib/intelligence/orchestrator.ts` | Modify | 6 | Extended OrchestratorResult + set_dates + populate_logistics |
| `src/app/api/xark/route.ts` | Modify | 6 | Handle new actions, confirmation flow, staleness cascade |

---

## Chunk 0: Test Infrastructure (Prerequisite)

**Files:**
- Create: `vitest.config.ts`
- Modify: `package.json` (dev dependency)

**Dependencies:** None. Must complete before Chunks 3, 4, 5.

- [ ] **Step 1: Install vitest**

Run: `npm install -D vitest`

- [ ] **Step 2: Create vitest config with path aliases**

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    globals: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

- [ ] **Step 3: Verify vitest runs**

Run: `npx vitest run --passWithNoTests`
Expected: No errors, "no test files found" or similar

- [ ] **Step 4: Commit**

```bash
git add vitest.config.ts package.json package-lock.json
git commit -m "chore: add vitest test infrastructure"
```

---

## Chunk 1: Migration — space_dates

**Files:**
- Create: `supabase/migrations/009_space_dates.sql`

**Dependencies:** None. Pure SQL. No code changes.

- [ ] **Step 1: Write the migration file**

```sql
-- 009_space_dates.sql
-- Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 1)
-- First-class trip dates entity. One row per space. Versioned for optimistic concurrency.

CREATE TABLE IF NOT EXISTS space_dates (
  space_id    text PRIMARY KEY REFERENCES spaces(id) ON DELETE CASCADE,
  start_date  date NOT NULL,
  end_date    date NOT NULL,
  destination text,
  label       text,
  set_by      text REFERENCES users(id),
  version     integer NOT NULL DEFAULT 1,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  CONSTRAINT valid_range CHECK (end_date >= start_date)
);

-- RLS: auth.uid()::text pattern per 003_rls_policies.sql (Firebase UID via JWT bridge)
ALTER TABLE space_dates ENABLE ROW LEVEL SECURITY;

CREATE POLICY sd_read ON space_dates FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = space_dates.space_id
    AND sm.user_id = auth.uid()::text
  )
);

-- All writes via supabaseAdmin (service role) in API routes.
-- Separate policies per operation (consistent with 003_rls_policies.sql pattern).
-- NOTE: service_role key bypasses RLS entirely, so these are defense-in-depth.
CREATE POLICY sd_insert ON space_dates FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY sd_update ON space_dates FOR UPDATE USING (
  auth.role() = 'service_role'
) WITH CHECK (auth.role() = 'service_role');

CREATE POLICY sd_delete ON space_dates FOR DELETE USING (
  auth.role() = 'service_role'
);
```

- [ ] **Step 2: Verify migration syntax**

Run: `cat supabase/migrations/009_space_dates.sql | head -30`
Expected: Valid SQL with no syntax errors

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/009_space_dates.sql
git commit -m "migration: add space_dates table with RLS"
```

---

## Chunk 2: Migration — member_logistics + users.home_city

**Files:**
- Create: `supabase/migrations/010_member_logistics.sql`

**Dependencies:** None. Pure SQL. Does NOT depend on Chunk 1 at runtime (no FK between tables).

- [ ] **Step 1: Write the migration file**

```sql
-- 010_member_logistics.sql
-- Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 3)
-- Per-user scoped logistics. Three-source passive assembly model.

-- ══════════════════════════════════════
-- 1. Add home_city to users table
-- ══════════════════════════════════════

ALTER TABLE users ADD COLUMN IF NOT EXISTS home_city text;

-- NOTE: fn_restrict_user_update (003_rls_policies.sql) freezes id, phone,
-- password_hash, created_at via allowlist. home_city passes through by design
-- (new columns not in the freeze list are mutable). This is intentional.

-- ══════════════════════════════════════
-- 2. Create member_logistics table
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS member_logistics (
  space_id    text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  user_id     text NOT NULL REFERENCES users(id),
  category    text NOT NULL CHECK (category IN (
    'flight_outbound', 'flight_return', 'ground_transport', 'visa', 'insurance'
  )),
  origin      text,
  destination text,
  state       text NOT NULL DEFAULT 'missing' CHECK (state IN (
    'missing', 'searching', 'proposed', 'locked', 'needs_review'
  )),
  item_id     text REFERENCES decision_items(id) ON DELETE SET NULL,
  source      text CHECK (source IN ('profile', 'creator', 'chat', 'manual')),
  confidence  real CHECK (confidence >= 0 AND confidence <= 1),
  version     integer NOT NULL DEFAULT 1,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  PRIMARY KEY (space_id, user_id, category)
);

CREATE INDEX IF NOT EXISTS idx_ml_space ON member_logistics(space_id);
CREATE INDEX IF NOT EXISTS idx_ml_user  ON member_logistics(user_id, state);

-- ══════════════════════════════════════
-- 3. RLS Policies (auth.uid()::text per 003_rls_policies.sql pattern)
-- ══════════════════════════════════════

ALTER TABLE member_logistics ENABLE ROW LEVEL SECURITY;

-- Read: space members only
CREATE POLICY ml_read ON member_logistics FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = member_logistics.space_id
    AND sm.user_id = auth.uid()::text
  )
);

-- Update own rows only
CREATE POLICY ml_update_own ON member_logistics FOR UPDATE USING (
  user_id = auth.uid()::text
) WITH CHECK (user_id = auth.uid()::text);

-- Insert: service role (onMemberJoin) OR own rows by space members
CREATE POLICY ml_insert ON member_logistics FOR INSERT WITH CHECK (
  auth.role() = 'service_role'
  OR (
    user_id = auth.uid()::text
    AND EXISTS (
      SELECT 1 FROM space_members sm
      WHERE sm.space_id = member_logistics.space_id
      AND sm.user_id = auth.uid()::text
    )
  )
);

-- Delete own rows (self-correction)
CREATE POLICY ml_delete_own ON member_logistics FOR DELETE USING (
  user_id = auth.uid()::text
);
```

- [ ] **Step 2: Verify migration syntax**

Run: `cat supabase/migrations/010_member_logistics.sql | head -30`
Expected: Valid SQL, ALTER TABLE + CREATE TABLE

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/010_member_logistics.sql
git commit -m "migration: add member_logistics table and users.home_city"
```

---

## Chunk 3: Calendar Library

**Files:**
- Create: `src/lib/calendar.ts`
- Create: `src/lib/__tests__/calendar.test.ts`

**Dependencies:** None. Pure functions. No DB calls. No imports from other chunks.

- [ ] **Step 1: Write the test file**

```typescript
// src/lib/__tests__/calendar.test.ts
import { describe, it, expect } from "vitest";
import { generateICS, calendarDeepLink, formatICSDate } from "../calendar";

describe("formatICSDate", () => {
  it("formats YYYY-MM-DD to YYYYMMDD", () => {
    expect(formatICSDate("2026-03-10")).toBe("20260310");
  });

  it("handles date with time by taking date part", () => {
    expect(formatICSDate("2026-03-10T14:00:00Z")).toBe("20260310");
  });
});

describe("generateICS", () => {
  it("generates valid iCalendar with one event", () => {
    const items = [
      {
        id: "item_1",
        title: "Hotel Del Coronado",
        metadata: { check_in: "2026-03-10", check_out: "2026-03-15" },
      },
    ];
    const result = generateICS(items, "san diego trip");

    expect(result).toContain("BEGIN:VCALENDAR");
    expect(result).toContain("VERSION:2.0");
    expect(result).toContain("PRODID:-//xark//xark-os//EN");
    expect(result).toContain("BEGIN:VEVENT");
    expect(result).toContain("DTSTART;VALUE=DATE:20260310");
    expect(result).toContain("DTEND;VALUE=DATE:20260315");
    expect(result).toContain("SUMMARY:Hotel Del Coronado");
    expect(result).toContain("DESCRIPTION:san diego trip");
    expect(result).toContain("UID:item_1@xark.app");
    expect(result).toContain("END:VEVENT");
    expect(result).toContain("END:VCALENDAR");
  });

  it("falls back to tripDates when item has no dates", () => {
    const items = [{ id: "item_2", title: "Surf Lessons", metadata: {} }];
    const result = generateICS(items, "san diego", {
      start_date: "2026-03-10",
      end_date: "2026-03-15",
    });

    expect(result).toContain("DTSTART;VALUE=DATE:20260310");
    expect(result).toContain("DTEND;VALUE=DATE:20260315");
  });

  it("skips items with no dates and no tripDates fallback", () => {
    const items = [{ id: "item_3", title: "No dates", metadata: {} }];
    const result = generateICS(items, "test");

    expect(result).not.toContain("BEGIN:VEVENT");
  });

  it("uses \\r\\n line endings (RFC 5545)", () => {
    const items = [
      { id: "item_4", title: "Test", metadata: { date: "2026-03-10" } },
    ];
    const result = generateICS(items, "test");

    expect(result).toContain("\r\n");
  });
});

describe("calendarDeepLink", () => {
  it("generates Google Calendar link", () => {
    const { google } = calendarDeepLink(
      "Hotel Del",
      "2026-03-10",
      "2026-03-15",
      "san diego trip"
    );

    expect(google).toContain("calendar.google.com/calendar/render");
    expect(google).toContain("action=TEMPLATE");
    expect(google).toContain("Hotel%20Del");
    expect(google).toContain("20260310");
    expect(google).toContain("20260315");
  });

  it("generates Outlook link", () => {
    const { outlook } = calendarDeepLink(
      "Hotel Del",
      "2026-03-10",
      "2026-03-15",
      "san diego trip"
    );

    expect(outlook).toContain("outlook.live.com/calendar");
    expect(outlook).toContain("subject=Hotel%20Del");
    expect(outlook).toContain("startdt=2026-03-10");
  });
});
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `npx vitest run src/lib/__tests__/calendar.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Write the implementation**

```typescript
// src/lib/calendar.ts
// XARK OS v2.0 — Calendar Integration (Layers 1 & 2)
// Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 2)
// Pure functions. No DB calls. No side effects.

export interface LockedItemWithDates {
  id: string;
  title: string;
  metadata?: {
    date?: string;
    check_in?: string;
    check_out?: string;
  };
}

// ── Date formatting ──

export function formatICSDate(dateStr: string): string {
  // Take YYYY-MM-DD part, strip hyphens → YYYYMMDD
  return dateStr.slice(0, 10).replace(/-/g, "");
}

function fmtGoogle(dateStr: string): string {
  return formatICSDate(dateStr);
}

function enc(s: string): string {
  return encodeURIComponent(s);
}

// ── Layer 1: .ics Export ──
// Uses VALUE=DATE (all-day events) — no VTIMEZONE needed (intentional)

export function generateICS(
  items: LockedItemWithDates[],
  spaceTitle: string,
  tripDates?: { start_date: string; end_date: string }
): string {
  const events = items
    .map((item) => {
      const start =
        item.metadata?.check_in || item.metadata?.date || tripDates?.start_date;
      const end =
        item.metadata?.check_out || item.metadata?.date || tripDates?.end_date;
      if (!start) return null;
      return [
        "BEGIN:VEVENT",
        `DTSTART;VALUE=DATE:${formatICSDate(start)}`,
        `DTEND;VALUE=DATE:${formatICSDate(end || start)}`,
        `SUMMARY:${item.title}`,
        `DESCRIPTION:${spaceTitle} — locked via xark`,
        `UID:${item.id}@xark.app`,
        "END:VEVENT",
      ].join("\r\n");
    })
    .filter(Boolean);

  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//xark//xark-os//EN",
    ...events,
    "END:VCALENDAR",
  ].join("\r\n");
}

// ── Layer 2: Deep Links ──

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

- [ ] **Step 4: Run tests — verify they pass**

Run: `npx vitest run src/lib/__tests__/calendar.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Type check**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add src/lib/calendar.ts src/lib/__tests__/calendar.test.ts
git commit -m "feat: calendar .ics export and deep links (layers 1-2)"
```

---

## Chunk 4: space-state.ts — Accept tripDates Parameter

**Files:**
- Modify: `src/lib/space-state.ts` (67 lines)
- Create: `src/lib/__tests__/space-state.test.ts`

**Dependencies:** None. Pure function. Existing code, additive change only.

- [ ] **Step 1: Write the test file**

```typescript
// src/lib/__tests__/space-state.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { computeSpaceState } from "../space-state";
import type { SpaceStateItem } from "../space-state";

describe("computeSpaceState", () => {
  it("returns empty for no items", () => {
    expect(computeSpaceState([])).toBe("empty");
  });

  it("returns exploring for proposed items", () => {
    const items: SpaceStateItem[] = [
      { state: "proposed", is_locked: false },
    ];
    expect(computeSpaceState(items)).toBe("exploring");
  });

  it("returns converging when some locked, some open", () => {
    const items: SpaceStateItem[] = [
      { state: "locked", is_locked: true },
      { state: "proposed", is_locked: false },
    ];
    expect(computeSpaceState(items)).toBe("converging");
  });

  it("returns ready when all locked", () => {
    const items: SpaceStateItem[] = [
      { state: "locked", is_locked: true },
    ];
    expect(computeSpaceState(items)).toBe("ready");
  });

  describe("with tripDates parameter", () => {
    let realDate: typeof Date;

    beforeEach(() => {
      realDate = globalThis.Date;
    });

    afterEach(() => {
      globalThis.Date = realDate;
    });

    it("returns settled when tripDates end_date is in the past", () => {
      const items: SpaceStateItem[] = [
        { state: "purchased", is_locked: true },
      ];
      // No metadata dates on items — uses tripDates instead
      const result = computeSpaceState(items, {
        start_date: "2020-01-01",
        end_date: "2020-01-05",
      });
      expect(result).toBe("settled");
    });

    it("returns active when tripDates span includes now", () => {
      const now = new Date();
      const yesterday = new Date(now.getTime() - 86_400_000).toISOString().slice(0, 10);
      const tomorrow = new Date(now.getTime() + 86_400_000).toISOString().slice(0, 10);

      const items: SpaceStateItem[] = [
        { state: "locked", is_locked: true },
      ];
      const result = computeSpaceState(items, {
        start_date: yesterday,
        end_date: tomorrow,
      });
      expect(result).toBe("active");
    });

    it("ignores tripDates when items have their own metadata dates", () => {
      const items: SpaceStateItem[] = [
        {
          state: "purchased",
          is_locked: true,
          metadata: { check_out: "2099-12-31" }, // far future
        },
      ];
      // tripDates says past, but items have their own dates — item dates win
      const result = computeSpaceState(items, {
        start_date: "2020-01-01",
        end_date: "2020-01-05",
      });
      // Item has check_out in 2099 (future), so not settled despite tripDates being past
      expect(result).toBe("ready");
    });
  });
});
```

- [ ] **Step 2: Run tests — verify they fail on tripDates tests**

Run: `npx vitest run src/lib/__tests__/space-state.test.ts`
Expected: Tests without tripDates PASS, tests with tripDates FAIL (parameter not accepted)

- [ ] **Step 3: Modify space-state.ts**

Open `src/lib/space-state.ts` (67 lines). Apply these changes:

**Change 1 — function signature** (line 24):

Replace:
```typescript
export function computeSpaceState(items: SpaceStateItem[]): SpaceState {
```
With:
```typescript
export function computeSpaceState(
  items: SpaceStateItem[],
  tripDates?: { start_date: string; end_date: string }
): SpaceState {
```

**Change 2 — settled check** (after line 38, inside the `if (allSettled)` block):

Replace the entire `if (allSettled)` block (lines 38-46):
```typescript
  if (allSettled) {
    const now = new Date();
    const hasPastDates = items.some((i) => {
      const dateStr = i.metadata?.check_out || i.metadata?.date;
      if (!dateStr) return false;
      return new Date(dateStr) < now;
    });
    if (hasPastDates) return "settled";
  }
```
With:
```typescript
  if (allSettled) {
    const now = new Date();
    const hasPastDates = items.some((i) => {
      const dateStr = i.metadata?.check_out || i.metadata?.date;
      if (!dateStr) return false;
      return new Date(dateStr) < now;
    });
    // Fallback to tripDates only when NO items have their own dates
    const itemsHaveDates = items.some(
      (i) => i.metadata?.check_out || i.metadata?.date
    );
    const tripPast = !itemsHaveDates && tripDates?.end_date
      ? new Date(tripDates.end_date) < now
      : false;
    if (hasPastDates || tripPast) return "settled";
  }
```

**Change 3 — active check** (lines 49-56):

Replace:
```typescript
  const now = new Date();
  const hasActiveDates = items.some((i) => {
    const checkIn = i.metadata?.check_in || i.metadata?.date;
    const checkOut = i.metadata?.check_out || i.metadata?.date;
    if (!checkIn) return false;
    return new Date(checkIn) <= now && (!checkOut || new Date(checkOut) >= now);
  });
  if (hasActiveDates && hasLocked) return "active";
```
With:
```typescript
  const now = new Date();
  const hasActiveDates = items.some((i) => {
    const checkIn = i.metadata?.check_in || i.metadata?.date;
    const checkOut = i.metadata?.check_out || i.metadata?.date;
    if (!checkIn) return false;
    return new Date(checkIn) <= now && (!checkOut || new Date(checkOut) >= now);
  });
  // Fallback to tripDates only when NO items have their own dates
  const itemsHaveCheckIn = items.some(
    (i) => i.metadata?.check_in || i.metadata?.date
  );
  const tripActive = !itemsHaveCheckIn && tripDates
    ? new Date(tripDates.start_date) <= now && new Date(tripDates.end_date) >= now
    : false;
  if ((hasActiveDates || tripActive) && hasLocked) return "active";
```

- [ ] **Step 4: Run tests — verify all pass**

Run: `npx vitest run src/lib/__tests__/space-state.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Type check**

Run: `npx tsc --noEmit`
Expected: 0 errors. Existing callers pass no second arg — optional param is backwards compatible.

- [ ] **Step 6: Commit**

```bash
git add src/lib/space-state.ts src/lib/__tests__/space-state.test.ts
git commit -m "feat: computeSpaceState accepts optional tripDates parameter"
```

---

## Chunk 5: Member Logistics Library

**Files:**
- Create: `src/lib/member-logistics.ts`
- Create: `src/lib/__tests__/member-logistics.test.ts`

**Dependencies:** Requires Chunk 1 (space_dates table) AND Chunk 2 (member_logistics table, users.home_city) migrations to be deployed for runtime queries. Code compiles independently. Tests cover pure functions only (no DB mocking needed).

- [ ] **Step 1: Write the test file**

```typescript
// src/lib/__tests__/member-logistics.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { resolveOrigin, buildLogisticsSkeletonRows } from "../member-logistics";

describe("resolveOrigin", () => {
  it("prefers trip override over all others", () => {
    const result = resolveOrigin("LAX", "JFK", "SFO");
    expect(result).toEqual({ origin: "LAX", source: "chat" });
  });

  it("prefers creator context over profile", () => {
    const result = resolveOrigin(null, "JFK", "SFO");
    expect(result).toEqual({ origin: "JFK", source: "creator" });
  });

  it("falls back to profile default", () => {
    const result = resolveOrigin(null, null, "SFO");
    expect(result).toEqual({ origin: "SFO", source: "profile" });
  });

  it("returns null when all sources empty", () => {
    const result = resolveOrigin(null, null, null);
    expect(result).toEqual({ origin: null, source: "missing" });
  });
});

describe("buildLogisticsSkeletonRows", () => {
  it("creates outbound and return rows", () => {
    const rows = buildLogisticsSkeletonRows("space_1", "user_1", "SFO", "SAN");
    expect(rows).toHaveLength(2);

    const outbound = rows.find((r) => r.category === "flight_outbound");
    expect(outbound?.origin).toBe("SFO");
    expect(outbound?.destination).toBe("SAN");
    expect(outbound?.state).toBe("missing");
    expect(outbound?.source).toBe("profile");
    expect(outbound?.confidence).toBe(1.0);

    const ret = rows.find((r) => r.category === "flight_return");
    expect(ret?.origin).toBe("SAN");
    expect(ret?.destination).toBe("SFO");
  });

  it("handles null home_city", () => {
    const rows = buildLogisticsSkeletonRows("space_1", "user_1", null, "SAN");
    const outbound = rows.find((r) => r.category === "flight_outbound");
    expect(outbound?.origin).toBeNull();
    expect(outbound?.source).toBeNull();
    expect(outbound?.confidence).toBeNull();
  });

  it("handles null destination", () => {
    const rows = buildLogisticsSkeletonRows("space_1", "user_1", "SFO", null);
    const outbound = rows.find((r) => r.category === "flight_outbound");
    expect(outbound?.origin).toBe("SFO");
    expect(outbound?.destination).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `npx vitest run src/lib/__tests__/member-logistics.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Write the implementation**

```typescript
// src/lib/member-logistics.ts
// XARK OS v2.0 — Per-User Logistics (Three-Source Passive Assembly)
// Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 3)

import { supabaseAdmin } from "./supabase-admin";

// ── Types ──

export interface LogisticsRow {
  space_id: string;
  user_id: string;
  category: string;
  origin: string | null;
  destination: string | null;
  state: string;
  item_id?: string | null;
  source: string | null;
  confidence: number | null;
}

export interface LogisticsExtraction {
  user_name: string;
  category?: string;
  origin?: string;
  destination?: string;
  confidence: number;
}

// ── Source Resolution (deterministic, no ambiguity) ──

export function resolveOrigin(
  tripOverride: string | null,
  creatorProvided: string | null,
  profileDefault: string | null
): { origin: string | null; source: string } {
  if (tripOverride) return { origin: tripOverride, source: "chat" };
  if (creatorProvided) return { origin: creatorProvided, source: "creator" };
  if (profileDefault) return { origin: profileDefault, source: "profile" };
  return { origin: null, source: "missing" };
}

// ── Skeleton Row Builder (pure function) ──

export function buildLogisticsSkeletonRows(
  spaceId: string,
  userId: string,
  homeCity: string | null,
  destination: string | null
): LogisticsRow[] {
  return ["flight_outbound", "flight_return"].map((cat) => ({
    space_id: spaceId,
    user_id: userId,
    category: cat,
    origin: cat === "flight_outbound" ? homeCity : destination,
    destination: cat === "flight_outbound" ? destination : homeCity,
    state: "missing" as const,
    source: homeCity ? ("profile" as const) : null,
    confidence: homeCity ? 1.0 : null,
  }));
}

// ── Auto-Population on Member Join ──

export async function onMemberJoin(
  spaceId: string,
  userId: string
): Promise<void> {
  const { data: user } = await supabaseAdmin
    .from("users")
    .select("home_city")
    .eq("id", userId)
    .single();

  const { data: dates } = await supabaseAdmin
    .from("space_dates")
    .select("destination")
    .eq("space_id", spaceId)
    .single();

  const rows = buildLogisticsSkeletonRows(
    spaceId,
    userId,
    user?.home_city ?? null,
    dates?.destination ?? null
  );

  await supabaseAdmin
    .from("member_logistics")
    .upsert(rows, {
      onConflict: "space_id,user_id,category",
      ignoreDuplicates: true,
    });
}

// ── Fetch logistics for a space ──

export async function fetchSpaceLogistics(
  spaceId: string
): Promise<LogisticsRow[]> {
  const { data } = await supabaseAdmin
    .from("member_logistics")
    .select("*")
    .eq("space_id", spaceId);
  return (data as LogisticsRow[]) ?? [];
}

// ── Apply extractions from Gemini ──

export async function applyLogisticsExtractions(
  spaceId: string,
  extractions: LogisticsExtraction[]
): Promise<{ applied: string[]; skipped: string[] }> {
  const applied: string[] = [];
  const skipped: string[] = [];

  // Resolve user_name → user_id via space_members JOIN users
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id, users!inner(display_name)")
    .eq("space_id", spaceId);

  const nameMap = new Map<string, string[]>();
  for (const m of members ?? []) {
    const name = (m.users as { display_name: string }).display_name.toLowerCase();
    const existing = nameMap.get(name) ?? [];
    existing.push(m.user_id);
    nameMap.set(name, existing);
  }

  for (const ext of extractions) {
    // Skip low confidence
    if (ext.confidence <= 0.8) {
      skipped.push(ext.user_name);
      continue;
    }

    const matches = nameMap.get(ext.user_name.toLowerCase()) ?? [];

    // Ambiguous name → skip (confidence drop)
    if (matches.length !== 1) {
      skipped.push(ext.user_name);
      continue;
    }

    const userId = matches[0];
    const category = ext.category ?? "flight_outbound";

    await supabaseAdmin
      .from("member_logistics")
      .update({
        origin: ext.origin ?? undefined,
        destination: ext.destination ?? undefined,
        source: "chat",
        confidence: ext.confidence,
        updated_at: new Date().toISOString(),
      })
      .match({ space_id: spaceId, user_id: userId, category });

    applied.push(ext.user_name);
  }

  return { applied, skipped };
}

// ── Staleness cascade on date change ──

export async function flagStaleLogistics(spaceId: string): Promise<number> {
  const { data } = await supabaseAdmin
    .from("member_logistics")
    .update({ state: "needs_review", updated_at: new Date().toISOString() })
    .eq("space_id", spaceId)
    .in("state", ["proposed", "locked"])
    .select("space_id");

  return data?.length ?? 0;
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `npx vitest run src/lib/__tests__/member-logistics.test.ts`
Expected: All pure function tests PASS

- [ ] **Step 5: Type check**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add src/lib/member-logistics.ts src/lib/__tests__/member-logistics.test.ts
git commit -m "feat: member logistics library with three-source resolution"
```

- [ ] **Step 7: Wire needs_flight events into awareness.ts**

In `src/lib/awareness.ts`, the `AwarenessKind` type and `whisperText` function already include `needs_flight` (added in a prior session). Now wire `fetchAwareness()` to query `member_logistics` for live events.

Find the comment `// No "said something" events` near the end of `fetchAwareness()` (before `return sortAwareness(events)`). Add this block above it:

```typescript
    // ── needs_flight events from member_logistics ──
    try {
      const { data: logistics } = await supabase
        .from("member_logistics")
        .select("space_id, user_id, origin, destination, state, item_id")
        .in("space_id", spaceIds)
        .eq("user_id", userId)
        .eq("state", "missing")
        .not("origin", "is", null);

      if (logistics) {
        for (const row of logistics) {
          // Only surface if origin is known but no item linked yet
          if (row.origin && !row.item_id) {
            const spaceTitle = spaceMap.get(row.space_id) ?? "";
            events.push({
              id: `flight_${row.space_id}_${row.user_id}`,
              kind: "needs_flight",
              spaceId: row.space_id,
              spaceTitle,
              text: whisperText("needs_flight", "", undefined, spaceTitle),
              actorName: "",
              timestamp: Date.now(), // always fresh — this is current state
              priority: 0,
            });
          }
        }
      }
    } catch {
      // member_logistics table may not exist yet — silent fallback
    }
```

**Note:** The `try/catch` ensures this works even if the `member_logistics` table hasn't been deployed yet (Chunk 2 migration). The query runs as the authenticated user via RLS — only their own logistics rows are visible.

- [ ] **Step 8: Type check**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 9: Commit**

```bash
git add src/lib/awareness.ts
git commit -m "feat: wire needs_flight awareness events from member_logistics"
```

---

## Chunk 6: Orchestrator + API Route — Wire Everything

**Files:**
- Modify: `src/lib/intelligence/orchestrator.ts` (125 lines)
- Modify: `src/app/api/xark/route.ts` (70 lines)

**Dependencies:** Chunks 1-5 must be merged first. This chunk imports from calendar.ts (Chunk 3) and member-logistics.ts (Chunk 5), and writes to space_dates (Chunk 1) and member_logistics (Chunk 2).

**IMPORTANT:** This is the integration chunk. Deploy LAST.

- [ ] **Step 1: Extend OrchestratorResult type**

In `src/lib/intelligence/orchestrator.ts`, find the `OrchestratorResult` interface (line 23):

Replace:
```typescript
export interface OrchestratorResult {
  response: string;
  searchResults?: ApifyResult[];
  action?: "search" | "reason" | "propose";
  tool?: string;
}
```
With:
```typescript
export interface OrchestratorResult {
  response: string;
  searchResults?: ApifyResult[];
  action?: "search" | "reason" | "propose" | "set_dates" | "populate_logistics";
  tool?: string;
  pendingConfirmation?: boolean;
  payload?: Record<string, unknown>;
  extractions?: Array<{
    user_name: string;
    category?: string;
    origin?: string;
    destination?: string;
    confidence: number;
  }>;
}
```

- [ ] **Step 2: Add set_dates and populate_logistics to intent prompt**

In `src/lib/intelligence/orchestrator.ts`, find the `buildIntentPrompt` function. Locate the action options list in the system prompt string (the part that tells Gemini which actions are available).

Add these two new options to the list:

```
- "set_dates": User wants to set, change, or confirm trip dates. Extract start_date (YYYY-MM-DD), end_date (YYYY-MM-DD), and optional label.
- "populate_logistics": You detected member travel origins/destinations in the message. Extract user_name, origin (airport code or city), and confidence (0-1). Only extract when confidence > 0.8.
```

Also add to the JSON response format description:

```
For set_dates, include: { "action": "set_dates", "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "label": "optional" }
For populate_logistics, include: { "action": "populate_logistics", "extractions": [{ "user_name": "name", "origin": "AIRPORT", "confidence": 0.95 }] }
```

- [ ] **Step 3: Add action handlers in orchestrate()**

In the `orchestrate()` function, find the action routing switch/if-else block. Add two new cases after the existing "propose" handler:

```typescript
    case "set_dates": {
      const startDate = parsed.start_date as string;
      const endDate = parsed.end_date as string;
      const label = parsed.label as string | undefined;
      return {
        response: `set dates to ${startDate} – ${endDate}?`,
        action: "set_dates" as const,
        pendingConfirmation: true,
        payload: { start_date: startDate, end_date: endDate, label },
      };
    }

    case "populate_logistics": {
      const extractions = (parsed.extractions ?? []) as OrchestratorResult["extractions"];
      const validExtractions = (extractions ?? []).filter(
        (e) => e.confidence > 0.8
      );
      if (validExtractions.length === 0) {
        // No high-confidence extractions — fall through to normal response
        break;
      }
      const names = validExtractions
        .map((e) => `${e.user_name} from ${e.origin}`)
        .join(", ");
      return {
        response: `got it — ${names}. correct?`,
        action: "populate_logistics" as const,
        pendingConfirmation: true,
        extractions: validExtractions,
      };
    }
```

- [ ] **Step 4: Update API route to handle new actions**

In `src/app/api/xark/route.ts`, add imports at the top:

```typescript
import { applyLogisticsExtractions, flagStaleLogistics } from "@/lib/member-logistics";
```

**Confirmation flow architecture (v1):**
The API route handles TWO types of requests:
1. **Initial request** — user says "@xark dates are mar 10-15" → orchestrator returns `pendingConfirmation: true` with payload → API returns this to client as-is
2. **Confirmation request** — client sends `{ confirm_action: "set_dates", payload: {...} }` → API executes the write directly (no Gemini call)

Add a confirmation handler BEFORE the `orchestrate()` call:

```typescript
    // ── Handle confirmations (no Gemini call needed) ──
    const body = await req.json();
    const { message, spaceId: reqSpaceId, userId, confirm_action, payload } = body;

    if (confirm_action === "set_dates" && payload) {
      const { start_date, end_date, label } = payload;

      // Upsert space_dates with version increment
      const { data: existing } = await supabaseAdmin
        .from("space_dates")
        .select("version")
        .eq("space_id", reqSpaceId)
        .single();

      await supabaseAdmin.from("space_dates").upsert({
        space_id: reqSpaceId,
        start_date,
        end_date,
        label: label ?? null,
        set_by: userId ?? null,
        version: (existing?.version ?? 0) + 1,
        updated_at: new Date().toISOString(),
      });

      // Flag stale apify items — jsonb merge via direct update
      await supabaseAdmin
        .from("decision_items")
        .update({ metadata: { needs_refresh: true } })
        .eq("space_id", reqSpaceId)
        .not("metadata->>source", "is", null);

      // Flag stale logistics
      const staleCount = await flagStaleLogistics(reqSpaceId);
      const staleNote = staleCount > 0
        ? ` ${staleCount} logistics entries may need updating.`
        : "";

      return NextResponse.json({
        response: `dates updated.${staleNote}`,
      });
    }

    if (confirm_action === "confirm_logistics" && payload?.extractions) {
      const { applied, skipped } = await applyLogisticsExtractions(
        reqSpaceId,
        payload.extractions
      );

      let response = `saved origins for ${applied.join(", ")}.`;
      if (skipped.length > 0) {
        response += ` couldn't resolve ${skipped.join(", ")} — which one?`;
      }

      return NextResponse.json({ response });
    }

    // ── Normal @xark flow (existing code continues below) ──
```

After the `orchestrate()` call, the existing result handling stays unchanged. When `result.pendingConfirmation` is true, the API just returns the result as-is — the client holds the payload in state and sends a confirmation request when the user confirms.

Add after the existing search results handler:

```typescript
    // ── Pass through pending confirmations to client ──
    if (result.pendingConfirmation) {
      return NextResponse.json({
        response: result.response,
        pendingConfirmation: true,
        confirm_action: result.action,
        payload: result.payload ?? { extractions: result.extractions },
      });
    }
```

- [ ] **Step 5: Type check**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts src/app/api/xark/route.ts
git commit -m "feat: orchestrator set_dates + populate_logistics actions with API handlers"
```

---

## Execution Order

```
Chunk 0 (vitest setup)                ── PREREQUISITE for chunks with tests (3, 4, 5)
                                        │
Chunk 1 (migration: space_dates)      ──┐
Chunk 2 (migration: member_logistics) ──┤── can run in parallel (after Chunk 0)
Chunk 3 (calendar library)            ──┤
Chunk 4 (space-state.ts update)       ──┤
Chunk 5 (member-logistics + awareness)──┘
                                        │
                                        ▼
Chunk 6 (orchestrator + API wiring)   ── runs LAST (imports from 3 + 5, writes to 1 + 2)
```

- Chunk 0 must complete before any chunk that runs tests (3, 4, 5)
- Chunks 1-5 have zero cross-dependencies at compile time. Deploy in any order
- Chunk 5 has runtime dependency on Chunks 1 + 2 (queries space_dates and member_logistics), but compiles independently and gracefully handles missing tables
- Chunk 6 integrates everything — deploy last
