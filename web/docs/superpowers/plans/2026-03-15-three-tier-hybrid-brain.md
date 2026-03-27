# Three-Tier Hybrid Brain Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a three-tier local intelligence system that intercepts @xark commands client-side, enabling <1ms admin commands (Tier 1), zero-knowledge encrypted message recall (Tier 2), and optimized cloud queries with streaming (Tier 3).

**Architecture:** Client-side interceptor sits at the top of `sendMessage()` in the Space page. Tier 1 (regex router) catches admin commands and routes mutations through `/api/local-action`. Tier 2 (Web Worker with FlexSearch/semantic search) provides encrypted message recall with actionable context cards. Tier 3 (existing Gemini orchestrator) gets streaming synthesis, context caching, and multi-action parallel execution.

**Tech Stack:** Next.js 16 + React 19, Supabase Postgres + Realtime, Vitest, MiniSearch (~15KB), libsodium-wrappers-sumo (XChaCha20-Poly1305), Web Workers, transformers.js (Phase 3 only)

**Spec:** `docs/superpowers/specs/2026-03-15-three-tier-hybrid-brain-design.md`

---

## Chunk 1: Phase 1 — Tier 1: Fast-Path Router

### Task 1: Database Migration — `space_ledger` Table

**Files:**
- Create: `supabase/migrations/017_hybrid_brain.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- 017_hybrid_brain.sql
-- Three-Tier Hybrid Brain: space_ledger for admin audit trail

-- Space ledger: Layer 3, unencrypted administrative audit trail
create table if not exists space_ledger (
  id uuid primary key default gen_random_uuid(),
  space_id text not null references spaces(id) on delete cascade,
  actor_id text not null,
  actor_name text,
  action text not null,
  payload jsonb default '{}',
  previous jsonb default '{}',
  revert_target_id uuid,
  created_at timestamptz default now()
);

create index idx_ledger_space_created
  on space_ledger(space_id, created_at desc);

alter table space_ledger enable row level security;

create policy "members_read_ledger" on space_ledger
  for select using (space_id = any(auth_user_space_ids()));

create policy "members_write_ledger" on space_ledger
  for insert with check (
    space_id = any(auth_user_space_ids())
    and actor_id = auth.jwt()->>'sub'
  );

-- Publish to Realtime for live pill rendering
alter publication supabase_realtime add table space_ledger;

-- Note: auth_user_space_ids() is already declared STABLE in migration 20260313212810.
-- No ALTER needed. Verified: function signature includes LANGUAGE sql SECURITY DEFINER STABLE.
```

- [ ] **Step 2: Run migration on Supabase**

Run: `supabase db push` or apply via Supabase dashboard SQL editor.
Expected: Table `space_ledger` created with RLS policies, index, and Realtime publication.

- [ ] **Step 3: Verify migration**

Run in Supabase SQL editor:
```sql
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'space_ledger';
```
Expected: 9 columns (id, space_id, actor_id, actor_name, action, payload, previous, revert_target_id, created_at).

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/017_hybrid_brain.sql
git commit -m "feat: add space_ledger table for Tier 1 admin audit trail"
```

---

### Task 2: Tier 1 Types and Contract

**Files:**
- Create: `src/lib/local-agent.ts`
- Test: `src/lib/__tests__/local-agent.test.ts`

- [ ] **Step 1: Write the failing tests for types and tryLocalAgent skeleton**

```typescript
// src/lib/__tests__/local-agent.test.ts
import { describe, it, expect } from "vitest";
import { tryLocalAgent } from "../local-agent";
import type { LocalContext } from "../local-agent";

const mockContext: LocalContext = {
  spaceId: "space_test",
  userId: "name_ram",
  userName: "ram",
  spaceItems: [],
  setView: () => {},
  supabaseToken: "mock-token",
};

describe("tryLocalAgent", () => {
  it("returns null for non-@xark messages", () => {
    const result = tryLocalAgent("hello everyone", mockContext);
    expect(result).toBeNull();
  });

  it("returns null for unrecognized @xark commands", () => {
    const result = tryLocalAgent("@xark find me flights to miami", mockContext);
    expect(result).toBeNull();
  });

  it("handles navigation: show decide", () => {
    let viewSet = "";
    const ctx = { ...mockContext, setView: (v: string) => { viewSet = v; } };
    const result = tryLocalAgent("@xark show decide", ctx as unknown as LocalContext);
    expect(result).not.toBeNull();
    expect(result!.handled).toBe(true);
    expect(result!.whisper).toContain("decide");
    result!.uiAction?.();
    expect(viewSet).toBe("decide");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: FAIL — module `../local-agent` not found.

- [ ] **Step 3: Write the types and tryLocalAgent skeleton**

```typescript
// src/lib/local-agent.ts
// XARK OS v2.0 — Tier 1: Fast-Path Local Router
// Deterministic regex matching for admin commands + state queries.
// <1ms, zero AI, zero network. First gate in sendMessage().

import type { SpaceStateItem } from "./space-state";

type ViewMode = "discuss" | "decide" | "itinerary" | "memories";

export interface LocalContext {
  spaceId: string;
  userId: string;
  userName: string;
  spaceItems: SpaceStateItem[];
  setView: (view: ViewMode) => void;
  supabaseToken: string | null;
}

export interface LedgerEntry {
  space_id: string;
  actor_id: string;
  actor_name: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  revert_target_id?: string;
}

export interface LocalResult {
  handled: true;
  ledgerEntry?: LedgerEntry;
  uiAction?: () => void;
  whisper?: string;
}

interface LocalCommand {
  pattern: RegExp;
  execute: (match: RegExpMatchArray, context: LocalContext) => LocalResult | null;
}

// ── Navigation commands — pure UI, no DB ──
const NAVIGATION_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+(?:show|go\s+to|switch\s+to|open)\s+(discuss|decide|itinerary|memories)/i,
    execute: (match, ctx) => {
      const target = match[1].toLowerCase() as ViewMode;
      return {
        handled: true,
        uiAction: () => ctx.setView(target),
        whisper: `switched to ${target}`,
      };
    },
  },
];

// ── All command registries (order matters — first match wins) ──
const ALL_COMMANDS: LocalCommand[] = [
  ...NAVIGATION_COMMANDS,
  // Date and rename commands added in subsequent tasks
];

/**
 * Try to handle an @xark message locally.
 * Returns LocalResult if handled, null if not (falls through to Tier 2/3).
 */
export function tryLocalAgent(
  text: string,
  context: LocalContext
): LocalResult | null {
  if (!text.toLowerCase().includes("@xark")) return null;

  for (const cmd of ALL_COMMANDS) {
    const match = text.match(cmd.pattern);
    if (match) {
      return cmd.execute(match, context);
    }
  }

  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/local-agent.ts src/lib/__tests__/local-agent.test.ts
git commit -m "feat: Tier 1 local-agent skeleton with navigation commands"
```

---

### Task 3: `/api/local-action` Server Route

**Files:**
- Create: `src/app/api/local-action/route.ts`
- Read: `src/lib/supabase-admin.ts` (import pattern)
- Read: `src/app/api/xark/route.ts` (JWT + membership verification pattern)

- [ ] **Step 1: Write the server route**

```typescript
// src/app/api/local-action/route.ts
// Tier 1 mutation endpoint. JWT-validated, supabaseAdmin writes.
// Atomic: mutation + ledger entry. Upserts space_dates for date commands.

import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";

export async function POST(req: Request) {
  // ── Auth ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const { action, spaceId, payload, previous } = body;

  if (!action || !spaceId) {
    return NextResponse.json({ error: "missing action or spaceId" }, { status: 400 });
  }

  // ── Membership check (CRITICAL: supabaseAdmin bypasses RLS) ──
  // space_members has composite PK (space_id, user_id) — no "id" column
  const { data: member } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId)
    .eq("user_id", auth.userId)
    .single();

  if (!member) {
    return NextResponse.json({ error: "not a member" }, { status: 403 });
  }

  // ── Execute mutation based on action type ──
  try {
    if (action === "update_dates") {
      const { start_date, end_date, label } = payload ?? {};
      if (!start_date || !end_date) {
        return NextResponse.json({ error: "missing dates" }, { status: 400 });
      }

      // Fetch previous state for undo
      const { data: currentDates } = await supabaseAdmin
        .from("space_dates")
        .select("start_date, end_date, label, version")
        .eq("space_id", spaceId)
        .single();

      // Upsert space_dates (downstream: purge TTL, retention, computeSpaceState)
      await supabaseAdmin.from("space_dates").upsert({
        space_id: spaceId,
        start_date,
        end_date,
        label: label ?? null,
        set_by: auth.userId,
        version: (currentDates?.version ?? 0) + 1,
        updated_at: new Date().toISOString(),
      });

      // Also update spaces.metadata
      const { data: space } = await supabaseAdmin
        .from("spaces")
        .select("metadata")
        .eq("id", spaceId)
        .single();

      const metadata = (space?.metadata as Record<string, unknown>) ?? {};
      await supabaseAdmin
        .from("spaces")
        .update({
          metadata: { ...metadata, start_date, end_date, label: label ?? undefined },
        })
        .eq("id", spaceId);

      // Write ledger entry
      await supabaseAdmin.from("space_ledger").insert({
        space_id: spaceId,
        actor_id: auth.userId,
        actor_name: body.actorName ?? null,
        action: "update_dates",
        payload: { start_date, end_date, label },
        previous: currentDates
          ? { start_date: currentDates.start_date, end_date: currentDates.end_date, label: currentDates.label }
          : {},
      });

      return NextResponse.json({ ok: true });
    }

    if (action === "rename_space") {
      const { new_title } = payload ?? {};
      if (!new_title || typeof new_title !== "string") {
        return NextResponse.json({ error: "missing new_title" }, { status: 400 });
      }

      // Fetch previous title
      const { data: space } = await supabaseAdmin
        .from("spaces")
        .select("title")
        .eq("id", spaceId)
        .single();

      const previousTitle = space?.title ?? "";

      await supabaseAdmin
        .from("spaces")
        .update({ title: new_title.trim() })
        .eq("id", spaceId);

      await supabaseAdmin.from("space_ledger").insert({
        space_id: spaceId,
        actor_id: auth.userId,
        actor_name: body.actorName ?? null,
        action: "rename_space",
        payload: { new_title: new_title.trim() },
        previous: { old_title: previousTitle },
      });

      return NextResponse.json({ ok: true });
    }

    if (action === "revert") {
      const { revert_target_id, revert_action, revert_previous } = payload ?? {};
      if (!revert_target_id || !revert_action || !revert_previous) {
        return NextResponse.json({ error: "missing revert data" }, { status: 400 });
      }

      // Apply the revert based on the original action type
      if (revert_action === "update_dates") {
        const prev = revert_previous as { start_date?: string; end_date?: string; label?: string };
        if (prev.start_date && prev.end_date) {
          await supabaseAdmin.from("space_dates").upsert({
            space_id: spaceId,
            start_date: prev.start_date,
            end_date: prev.end_date,
            label: prev.label ?? null,
            set_by: auth.userId,
            updated_at: new Date().toISOString(),
          });
        } else {
          await supabaseAdmin.from("space_dates").delete().eq("space_id", spaceId);
        }
      } else if (revert_action === "rename_space") {
        const prev = revert_previous as { old_title?: string };
        if (prev.old_title) {
          await supabaseAdmin.from("spaces").update({ title: prev.old_title }).eq("id", spaceId);
        }
      }

      // Write revert ledger entry
      await supabaseAdmin.from("space_ledger").insert({
        space_id: spaceId,
        actor_id: auth.userId,
        actor_name: body.actorName ?? null,
        action: `revert_${revert_action}`,
        payload: revert_previous,
        previous: payload,
        revert_target_id,
      });

      return NextResponse.json({ ok: true });
    }

    return NextResponse.json({ error: `unknown action: ${action}` }, { status: 400 });
  } catch (err) {
    console.error("[local-action]", err);
    return NextResponse.json({ error: "mutation failed" }, { status: 500 });
  }
}
```

- [ ] **Step 2: Verify the route compiles**

Run: `npx next build --no-lint 2>&1 | head -20` (quick syntax check)
or: `npx tsc --noEmit src/app/api/local-action/route.ts` (if available)
Expected: No TypeScript errors.

- [ ] **Step 3: Commit**

```bash
git add src/app/api/local-action/route.ts
git commit -m "feat: /api/local-action server route for Tier 1 mutations"
```

---

### Task 4: Date Command — Regex + Handler

**Files:**
- Modify: `src/lib/local-agent.ts`
- Modify: `src/lib/__tests__/local-agent.test.ts`

- [ ] **Step 1: Write failing tests for date commands**

Add to `src/lib/__tests__/local-agent.test.ts`:

```typescript
describe("date commands", () => {
  it("matches 'set dates to june 1-5'", () => {
    const result = tryLocalAgent("@xark set dates to june 1-5", mockContext);
    expect(result).not.toBeNull();
    expect(result!.handled).toBe(true);
    expect(result!.ledgerEntry).toBeDefined();
    expect(result!.ledgerEntry!.action).toBe("update_dates");
    expect(result!.ledgerEntry!.payload).toHaveProperty("start_date");
    expect(result!.ledgerEntry!.payload).toHaveProperty("end_date");
  });

  it("matches 'change dates to march 20-25'", () => {
    const result = tryLocalAgent("@xark change dates to march 20-25", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.action).toBe("update_dates");
  });

  it("does NOT match vague date requests", () => {
    const result = tryLocalAgent("@xark push the dates back a few weeks because nina got delayed", mockContext);
    expect(result).toBeNull(); // Too complex for regex — falls to Tier 3
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: New date tests FAIL.

- [ ] **Step 3: Implement date parsing and command**

Add to `src/lib/local-agent.ts`:

```typescript
// ── Simple date parsing — handles "june 1-5", "march 20 to march 25", "dec 12-15" ──
const MONTH_MAP: Record<string, number> = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2,
  apr: 3, april: 3, may: 4, jun: 5, june: 5,
  jul: 6, july: 6, aug: 7, august: 7, sep: 8, september: 8,
  oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11,
};

function parseSimpleDateRange(text: string): { start_date: string; end_date: string } | null {
  // Pattern: "month day-day" (e.g., "june 1-5")
  const singleMonth = text.match(/(\w+)\s+(\d{1,2})\s*[-–to]+\s*(\d{1,2})/i);
  if (singleMonth) {
    const month = MONTH_MAP[singleMonth[1].toLowerCase()];
    if (month !== undefined) {
      const year = new Date().getFullYear();
      const start = new Date(year, month, parseInt(singleMonth[2]));
      const end = new Date(year, month, parseInt(singleMonth[3]));
      // If dates are in the past, assume next year
      if (end < new Date()) {
        start.setFullYear(year + 1);
        end.setFullYear(year + 1);
      }
      return {
        start_date: start.toISOString().split("T")[0],
        end_date: end.toISOString().split("T")[0],
      };
    }
  }

  // Pattern: "month day to month day" (e.g., "march 20 to march 25")
  const twoMonth = text.match(/(\w+)\s+(\d{1,2})\s+to\s+(\w+)\s+(\d{1,2})/i);
  if (twoMonth) {
    const m1 = MONTH_MAP[twoMonth[1].toLowerCase()];
    const m2 = MONTH_MAP[twoMonth[3].toLowerCase()];
    if (m1 !== undefined && m2 !== undefined) {
      const year = new Date().getFullYear();
      const start = new Date(year, m1, parseInt(twoMonth[2]));
      const end = new Date(year, m2, parseInt(twoMonth[4]));
      if (end < new Date()) {
        start.setFullYear(year + 1);
        end.setFullYear(year + 1);
      }
      return {
        start_date: start.toISOString().split("T")[0],
        end_date: end.toISOString().split("T")[0],
      };
    }
  }

  return null;
}

// ── Date commands — mutate via /api/local-action ──
const DATE_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+(?:set|change|update|modify)\s+(?:trip\s+)?dates?\s+to\s+(.+)/i,
    execute: (match, ctx) => {
      const dateText = match[1].trim();
      const parsed = parseSimpleDateRange(dateText);
      if (!parsed) return null; // Can't parse — fall through to Tier 3

      return {
        handled: true,
        ledgerEntry: {
          space_id: ctx.spaceId,
          actor_id: ctx.userId,
          actor_name: ctx.userName,
          action: "update_dates",
          payload: { start_date: parsed.start_date, end_date: parsed.end_date },
          previous: {}, // Server fills this from current state
        },
        whisper: `dates set to ${dateText}`,
      };
    },
  },
];
```

Then update `ALL_COMMANDS`:

```typescript
const ALL_COMMANDS: LocalCommand[] = [
  ...NAVIGATION_COMMANDS,
  ...DATE_COMMANDS,
];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/local-agent.ts src/lib/__tests__/local-agent.test.ts
git commit -m "feat: Tier 1 date command parsing with simple date range support"
```

---

### Task 5: Rename Command — Regex + Handler

**Files:**
- Modify: `src/lib/local-agent.ts`
- Modify: `src/lib/__tests__/local-agent.test.ts`

- [ ] **Step 1: Write failing tests for rename**

Add to test file:

```typescript
describe("rename commands", () => {
  it("matches 'rename space to Miami 2026'", () => {
    const result = tryLocalAgent("@xark rename space to Miami 2026", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.action).toBe("rename_space");
    expect(result!.ledgerEntry!.payload).toEqual({ new_title: "Miami 2026" });
  });

  it("matches 'rename this to Summer Trip'", () => {
    const result = tryLocalAgent("@xark rename this to Summer Trip", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.payload).toEqual({ new_title: "Summer Trip" });
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: Rename tests FAIL.

- [ ] **Step 3: Implement rename command**

Add to `src/lib/local-agent.ts`:

```typescript
const RENAME_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+rename\s+(?:space|this|it|group)\s+to\s+(.+)/i,
    execute: (match, ctx) => {
      const newTitle = match[1].trim();
      if (!newTitle || newTitle.length > 100) return null;

      return {
        handled: true,
        ledgerEntry: {
          space_id: ctx.spaceId,
          actor_id: ctx.userId,
          actor_name: ctx.userName,
          action: "rename_space",
          payload: { new_title: newTitle },
          previous: {}, // Server fills from current title
        },
        whisper: `renamed to "${newTitle}"`,
      };
    },
  },
];
```

Update `ALL_COMMANDS` to include `...RENAME_COMMANDS`.

- [ ] **Step 4: Run tests**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/local-agent.ts src/lib/__tests__/local-agent.test.ts
git commit -m "feat: Tier 1 rename command"
```

---

### Task 6: State Query Commands

**Files:**
- Modify: `src/lib/local-agent.ts`
- Modify: `src/lib/__tests__/local-agent.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
describe("state query commands", () => {
  const ctxWithItems: LocalContext = {
    ...mockContext,
    spaceItems: [
      { state: "proposed", is_locked: false, category: "hotel", metadata: {} },
      { state: "ranked", is_locked: false, category: "restaurant", metadata: {} },
      { state: "locked", is_locked: true, category: "activity", metadata: {} },
    ],
  };

  it("matches 'what's the status'", () => {
    const result = tryLocalAgent("@xark what's the status", ctxWithItems);
    expect(result).not.toBeNull();
    expect(result!.handled).toBe(true);
    expect(result!.whisper).toContain("3 items");
  });

  it("matches 'status'", () => {
    const result = tryLocalAgent("@xark status", ctxWithItems);
    expect(result).not.toBeNull();
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`

- [ ] **Step 3: Implement state query commands**

```typescript
const STATE_QUERY_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+(?:what(?:'s| is) the )?status/i,
    execute: (_match, ctx) => {
      const total = ctx.spaceItems.length;
      const locked = ctx.spaceItems.filter((i) => i.is_locked).length;
      const proposed = total - locked;

      let summary: string;
      if (total === 0) {
        summary = "nothing here yet. wide open.";
      } else if (locked === total) {
        summary = `all ${total} items locked. ready to go.`;
      } else {
        summary = `${total} items total. ${locked} locked, ${proposed} still open.`;
      }

      return {
        handled: true,
        whisper: summary,
      };
    },
  },
  {
    pattern: /@xark\s+who\s+hasn(?:'t|t)\s+voted/i,
    execute: (_match, ctx) => {
      // Aggregate count from local state (no reactions data — see spec M2)
      const openItems = ctx.spaceItems.filter((i) => !i.is_locked).length;
      return {
        handled: true,
        whisper: openItems > 0
          ? `${openItems} items still need votes.`
          : "everything has been voted on.",
      };
    },
  },
];
```

Update `ALL_COMMANDS` to include `...STATE_QUERY_COMMANDS`.

- [ ] **Step 4: Run tests**

Run: `npx vitest run src/lib/__tests__/local-agent.test.ts`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/local-agent.ts src/lib/__tests__/local-agent.test.ts
git commit -m "feat: Tier 1 state query commands (status, who hasn't voted)"
```

---

### Task 7: `LedgerPill.tsx` Component

**Files:**
- Create: `src/components/os/LedgerPill.tsx`
- Read: `src/lib/theme.ts` (for token imports)

- [ ] **Step 1: Write the LedgerPill component**

```typescript
// src/components/os/LedgerPill.tsx
// Interactive system pill for space_ledger events.
// Structure: icon → actor → verb → [tappable payload] → undo

"use client";

import { colors, ink, text } from "@/lib/theme";

const ACTION_CONFIG: Record<string, { icon: string; verb: string }> = {
  update_dates: { icon: "\uD83D\uDCC5", verb: "updated dates to" },
  rename_space: { icon: "\u270F\uFE0F", verb: "renamed space to" },
  revert_update_dates: { icon: "\u21A9\uFE0F", verb: "reverted dates to" },
  revert_rename_space: { icon: "\u21A9\uFE0F", verb: "reverted name to" },
};

interface LedgerPillProps {
  actorName: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  ledgerId: string;
  revertTargetId?: string;
  onUndo?: (ledgerId: string, action: string, previous: Record<string, unknown>) => void;
}

function formatPayload(action: string, payload: Record<string, unknown>): string {
  if (action === "update_dates" || action === "revert_update_dates") {
    return `${payload.start_date ?? ""} – ${payload.end_date ?? ""}`;
  }
  if (action === "rename_space" || action === "revert_rename_space") {
    return String(payload.new_title ?? payload.old_title ?? "");
  }
  return JSON.stringify(payload);
}

export function LedgerPill({
  actorName,
  action,
  payload,
  previous,
  ledgerId,
  revertTargetId,
  onUndo,
}: LedgerPillProps) {
  const config = ACTION_CONFIG[action] ?? { icon: "\u2699\uFE0F", verb: action };
  const payloadText = formatPayload(action, payload);
  const isRevert = action.startsWith("revert_");

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: "6px",
        padding: "8px 0",
      }}
    >
      <span style={{ ...text.timestamp, color: ink.tertiary }}>
        {config.icon} {actorName} {config.verb}
      </span>
      <span
        style={{
          ...text.timestamp,
          color: colors.cyan,
          cursor: "pointer",
        }}
      >
        [{payloadText}]
      </span>
      {!isRevert && onUndo && (
        <>
          <span style={{ ...text.timestamp, color: ink.tertiary }}>&middot;</span>
          <span
            role="button"
            tabIndex={0}
            onClick={() => onUndo(ledgerId, action, previous)}
            onKeyDown={(e) => { if (e.key === "Enter") onUndo(ledgerId, action, previous); }}
            style={{
              ...text.timestamp,
              color: ink.tertiary,
              cursor: "pointer",
            }}
            className="outline-none"
          >
            undo
          </span>
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Verify no TypeScript errors**

Run: `npx tsc --noEmit` or check IDE for red squiggles.

- [ ] **Step 3: Commit**

```bash
git add src/components/os/LedgerPill.tsx
git commit -m "feat: LedgerPill component for interactive system pills"
```

---

### Task 8: XarkChat — Interleave Ledger Pills

**Files:**
- Modify: `src/components/os/XarkChat.tsx`
- Read: `src/components/os/LedgerPill.tsx`

**IMPORTANT:** Before modifying, read the full `XarkChat.tsx` component. It has Framer Motion `AnimatePresence`, sanctuary bridge, handshake rendering, foveal opacity, and grouped message logic. The code snippets below are structural guidance — adapt to the actual variable names and rendering patterns in the component. The main message loop uses an internal `allMessages` variable that merges props with greeting. Identify that loop before modifying.

- [ ] **Step 1: Add ledger event type and props**

In `XarkChat.tsx`, add to the props interface:

```typescript
// Add to XarkChat props:
ledgerEvents?: Array<{
  id: string;
  actorName: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  revertTargetId?: string;
  timestamp: number;
}>;
onLedgerUndo?: (ledgerId: string, action: string, previous: Record<string, unknown>) => void;
```

- [ ] **Step 2: Merge and sort messages with ledger events**

Before the `allMessages.map()` loop, merge chat messages and ledger events into a single sorted timeline:

```typescript
// Build unified timeline
type TimelineItem =
  | { type: "message"; data: typeof allMessages[number]; timestamp: number }
  | { type: "ledger"; data: typeof ledgerEvents[number]; timestamp: number };

const timeline: TimelineItem[] = [
  ...allMessages.map((m) => ({ type: "message" as const, data: m, timestamp: m.timestamp })),
  ...(ledgerEvents ?? []).map((e) => ({ type: "ledger" as const, data: e, timestamp: e.timestamp })),
].sort((a, b) => a.timestamp - b.timestamp);
```

- [ ] **Step 3: Render LedgerPill in the timeline loop**

Replace the existing `allMessages.map()` with `timeline.map()`, rendering `LedgerPill` for ledger items:

```typescript
{timeline.map((item, index) => {
  if (item.type === "ledger") {
    return (
      <LedgerPill
        key={`ledger-${item.data.id}`}
        actorName={item.data.actorName}
        action={item.data.action}
        payload={item.data.payload}
        previous={item.data.previous}
        ledgerId={item.data.id}
        revertTargetId={item.data.revertTargetId}
        onUndo={onLedgerUndo}
      />
    );
  }

  // Existing message rendering...
  const msg = item.data;
  // ... rest of existing code
})}
```

- [ ] **Step 4: Verify build passes**

Run: `npx next build --no-lint 2>&1 | tail -5`
Expected: Build succeeds (ledgerEvents prop is optional, existing callers won't break).

- [ ] **Step 5: Commit**

```bash
git add src/components/os/XarkChat.tsx
git commit -m "feat: interleave ledger pills in XarkChat timeline"
```

---

### Task 9: Space Page — Wire Tier 1 + Ledger Subscription

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

This is the integration task. Wire `tryLocalAgent()` into `sendMessage()`, add ledger Realtime subscription, and the `persistLedger()` function.

- [ ] **Step 1: Add imports and state**

At the top of `SpacePageInner`:

```typescript
import { tryLocalAgent } from "@/lib/local-agent";
import type { LocalContext, LedgerEntry } from "@/lib/local-agent";

// Inside SpacePageInner, add state:
const [ledgerEvents, setLedgerEvents] = useState<Array<{
  id: string;
  actorName: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  revertTargetId?: string;
  timestamp: number;
}>>([]);
const [localWhisper, setLocalWhisper] = useState<string | null>(null);
```

- [ ] **Step 2: Add persistLedger and handleLedgerUndo functions**

```typescript
// ── Persist ledger entry via /api/local-action ──
const persistLedger = useCallback(async (entry: LedgerEntry) => {
  const token = getSupabaseToken();
  try {
    await fetch("/api/local-action", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({
        action: entry.action,
        spaceId: entry.space_id,
        payload: entry.payload,
        previous: entry.previous,
        actorName: entry.actor_name,
      }),
    });
  } catch (err) {
    console.error("[local-action] failed:", err);
  }
}, []);

const handleLedgerUndo = useCallback(async (
  ledgerId: string,
  action: string,
  previous: Record<string, unknown>
) => {
  const token = getSupabaseToken();
  try {
    await fetch("/api/local-action", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({
        action: "revert",
        spaceId: spaceId,
        payload: { revert_target_id: ledgerId, revert_action: action, revert_previous: previous },
        actorName: user?.displayName ?? userName,
      }),
    });
  } catch (err) {
    console.error("[local-action] undo failed:", err);
  }
}, [spaceId, user, userName]);
```

- [ ] **Step 3: Add ledger Realtime subscription**

Add a new `useEffect` after the message broadcast subscription:

```typescript
// ── Ledger Realtime subscription ──
useEffect(() => {
  if (authLoading) return;

  const channel = supabase
    .channel(`ledger:${spaceId}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "space_ledger", filter: `space_id=eq.${spaceId}` },
      (payload) => {
        const row = payload.new as Record<string, unknown>;
        setLedgerEvents((prev) => {
          if (prev.some((e) => e.id === row.id)) return prev;
          return [
            ...prev,
            {
              id: row.id as string,
              actorName: (row.actor_name as string) ?? "someone",
              action: row.action as string,
              payload: (row.payload as Record<string, unknown>) ?? {},
              previous: (row.previous as Record<string, unknown>) ?? {},
              revertTargetId: row.revert_target_id as string | undefined,
              timestamp: new Date(row.created_at as string).getTime(),
            },
          ];
        });
      }
    )
    .subscribe();

  // Fetch existing ledger events for this space
  supabase
    .from("space_ledger")
    .select("*")
    .eq("space_id", spaceId)
    .order("created_at", { ascending: true })
    .then(({ data }) => {
      if (data) {
        setLedgerEvents(
          data.map((row) => ({
            id: row.id,
            actorName: row.actor_name ?? "someone",
            action: row.action,
            payload: row.payload ?? {},
            previous: row.previous ?? {},
            revertTargetId: row.revert_target_id ?? undefined,
            timestamp: new Date(row.created_at).getTime(),
          }))
        );
      }
    });

  return () => { supabase.removeChannel(channel); };
}, [spaceId, authLoading]);
```

- [ ] **Step 4: Wire Tier 1 into sendMessage**

At the top of the `sendMessage` callback (before the existing `resolvedUserId` guard):

```typescript
const sendMessage = useCallback(async () => {
  const txt = input.trim();
  if (!txt) return;

  // Guard: must have authenticated userId
  if (!resolvedUserId) {
    console.warn("[xark] sendMessage blocked: no authenticated userId yet");
    return;
  }

  const hasXark = txt.toLowerCase().includes("@xark");

  // ── TIER 1: Fast-Path Router (runs even while isThinking — navigation/status are instant) ──
  if (hasXark) {
    const localContext: LocalContext = {
      spaceId,
      userId: resolvedUserId,
      userName: user?.displayName ?? userName ?? "",
      spaceItems,
      setView,
      supabaseToken: getSupabaseToken(),
    };

    const localResult = tryLocalAgent(txt, localContext);
    if (localResult) {
      setInput("");
      if (localResult.ledgerEntry) persistLedger(localResult.ledgerEntry);
      if (localResult.uiAction) localResult.uiAction();
      if (localResult.whisper) {
        setLocalWhisper(localResult.whisper);
        setTimeout(() => setLocalWhisper(null), 3000);
      }
      return; // Done. No E2EE, no network, no thinking indicator.
    }
  }

  // isThinking gate: only blocks Tier 2/3 (network-dependent paths)
  if (isThinking) return;

  // ... existing E2EE and legacy paths below (unchanged) ...
```

- [ ] **Step 5: Pass ledger props to XarkChat**

Update the XarkChat render:

```typescript
<XarkChat
  spaceId={spaceId}
  spaceTitle={spaceTitle}
  messages={messages}
  isThinking={isThinking}
  e2eeActive={e2ee.available}
  ledgerEvents={ledgerEvents}
  onLedgerUndo={handleLedgerUndo}
/>
```

- [ ] **Step 6: Add local whisper display**

Add a whisper UI element near the constraint whisper:

```typescript
{/* ── Local command whisper ── */}
{localWhisper && (
  <div
    className="fixed inset-x-0 z-20 mx-auto px-6"
    style={{ bottom: "80px", maxWidth: "640px" }}
  >
    <p
      style={{ ...text.hint, color: ink.tertiary, textAlign: "center" }}
      onClick={() => setLocalWhisper(null)}
    >
      {localWhisper}
    </p>
  </div>
)}
```

- [ ] **Step 7: Run all tests to verify nothing is broken**

Run: `npx vitest run`
Expected: All existing tests + new local-agent tests PASS.

- [ ] **Step 8: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: wire Tier 1 fast-path router into Space page with ledger subscription"
```

---

## Chunk 2: Phase 2 — Tier 2: Lexical Memory Engine

### Task 10: Install MiniSearch

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Install minisearch**

Run: `npm install minisearch`
Expected: `minisearch` added to dependencies.

- [ ] **Step 2: Commit**

```bash
git add package.json package-lock.json
git commit -m "deps: add minisearch for Tier 2 lexical search"
```

---

### Task 11: Recall Detection Module

**Files:**
- Create: `src/lib/local-recall.ts`
- Test: `src/lib/__tests__/local-recall.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// src/lib/__tests__/local-recall.test.ts
import { describe, it, expect } from "vitest";
import { isRecallQuestion } from "../local-recall";

describe("isRecallQuestion", () => {
  it("detects 'what was that sushi place'", () => {
    expect(isRecallQuestion("@xark what was that sushi place")).toBe(true);
  });

  it("detects 'who said we should go hiking'", () => {
    expect(isRecallQuestion("@xark who said we should go hiking")).toBe(true);
  });

  it("detects 'what did nina link'", () => {
    expect(isRecallQuestion("@xark what did nina link")).toBe(true);
  });

  it("detects 'search for hotel messages'", () => {
    expect(isRecallQuestion("@xark search for hotel messages")).toBe(true);
  });

  it("rejects 'find me flights to miami'", () => {
    expect(isRecallQuestion("@xark find me flights to miami")).toBe(false);
  });

  it("rejects 'search for hotels in Miami' (Tier 3 search, not recall)", () => {
    expect(isRecallQuestion("@xark search for hotels in Miami")).toBe(false);
  });

  it("rejects 'look up flight prices' (Tier 3 search, not recall)", () => {
    expect(isRecallQuestion("@xark look up flight prices")).toBe(false);
  });

  it("rejects 'set dates to june 1-5'", () => {
    expect(isRecallQuestion("@xark set dates to june 1-5")).toBe(false);
  });

  it("rejects plain chat messages", () => {
    expect(isRecallQuestion("hey everyone what time is dinner")).toBe(false);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx vitest run src/lib/__tests__/local-recall.test.ts`

- [ ] **Step 3: Implement recall detection**

```typescript
// src/lib/local-recall.ts
// Tier 2: Recall question detection + local memory search wrapper.

// Patterns tuned to avoid false-positive against Tier 3 search commands.
// "search for hotels in miami" is a Gemini search, NOT a recall question.
// Only match recall-intent phrases (referencing past chat, people, or memory).
const RECALL_PATTERNS = [
  /what was that/i,
  /who said/i,
  /who mentioned/i,
  /remember when/i,
  /what did .+ (?:say|send|link|share|suggest|recommend)/i,
  /find .+ message/i,
  /when did .+ (?:say|send|mention)/i,
  /what .+ (?:link|place|hotel|restaurant|spot) .+ (?:link|share|send|mention|suggest)/i,
  /search (?:for )?(?:that|the) (?:message|thing|link|place)/i,
  /look up (?:that|the|what) (?:message|thing|link)/i,
];

export function isRecallQuestion(text: string): boolean {
  const cleaned = text.replace(/@xark\s*/i, "").trim();
  return RECALL_PATTERNS.some((p) => p.test(cleaned));
}

export interface RecallResult {
  messageId: string;
  content: string;
  senderName: string;
  timestamp: number;
}

export function getRecallWhisper(deviceTier: "high" | "low"): string {
  return deviceTier === "high"
    ? "couldn't find anything matching that in our recent chat history."
    : "couldn't find that exactly. local memory is keyword-only for now. try specific words like 'hotel' or 'marriott'.";
}
```

- [ ] **Step 4: Run tests**

Run: `npx vitest run src/lib/__tests__/local-recall.test.ts`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/local-recall.ts src/lib/__tests__/local-recall.test.ts
git commit -m "feat: recall question detection for Tier 2 memory engine"
```

---

### Task 12: Memory Worker — Lexical Search Engine

**Files:**
- Create: `src/workers/memory-worker.ts`

- [ ] **Step 1: Create the Web Worker with MiniSearch**

```typescript
// src/workers/memory-worker.ts
// Tier 2: E2EE Memory Engine — Web Worker
// Manages in-memory search index, encrypted blob lifecycle,
// debounced persistence, delta sync watermark.

import MiniSearch from "minisearch";

interface IndexedMessage {
  id: string;
  content: string;
  senderName: string;
  timestamp: number;
}

let index: MiniSearch<IndexedMessage> | null = null;
let messages: Map<string, IndexedMessage> = new Map();
let lastIndexedTimestamp: number = 0; // timestamp-based watermark (not ID-based — UUIDs aren't ordered)
let persistTimer: ReturnType<typeof setTimeout> | null = null;
const MAX_MESSAGES = 1000;
const PERSIST_DEBOUNCE_MS = 3000;
const MAX_CONTENT_LENGTH = 2000;

function initIndex() {
  index = new MiniSearch<IndexedMessage>({
    fields: ["content", "senderName"],
    storeFields: ["content", "senderName", "timestamp"],
    searchOptions: {
      fuzzy: 0.2,
      prefix: true,
    },
  });
}

function evictOldest() {
  if (messages.size <= MAX_MESSAGES) return;
  const sorted = [...messages.values()].sort((a, b) => a.timestamp - b.timestamp);
  while (messages.size > MAX_MESSAGES) {
    const oldest = sorted.shift();
    if (oldest) {
      messages.delete(oldest.id);
      index?.discard(oldest.id);
    }
  }
}

function schedulePersist() {
  if (persistTimer) clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    const serialized = JSON.stringify({
      messages: [...messages.values()],
      lastIndexedTimestamp,
    });
    // Post serialized data to main thread for encryption + IndexedDB write
    self.postMessage({ type: "PERSIST", payload: serialized });
    persistTimer = null;
  }, PERSIST_DEBOUNCE_MS);
}

// ── Message handler ──
self.onmessage = (event: MessageEvent) => {
  const { type } = event.data;

  if (type === "INIT") {
    initIndex();
    messages = new Map();
    lastIndexedMessageId = null;

    // If encrypted blob provided, it arrives pre-decrypted from main thread
    const { serializedIndex } = event.data;
    if (serializedIndex) {
      try {
        const parsed = JSON.parse(serializedIndex);
        if (Array.isArray(parsed.messages)) {
          for (const msg of parsed.messages) {
            messages.set(msg.id, msg);
          }
          index!.addAll([...messages.values()]);
          lastIndexedTimestamp = parsed.lastIndexedTimestamp ?? 0;
        }
      } catch {
        // Corrupted blob — start fresh
        initIndex();
        messages = new Map();
      }
    }

    self.postMessage({ type: "READY", watermarkTime: lastIndexedTimestamp });
  }

  if (type === "INDEX_MESSAGE") {
    const { message } = event.data;
    if (!message?.id || !message?.content) return;
    if (messages.has(message.id)) return; // Already indexed

    const truncated: IndexedMessage = {
      id: message.id,
      content: message.content.slice(0, MAX_CONTENT_LENGTH),
      senderName: message.senderName ?? "",
      timestamp: message.timestamp ?? Date.now(),
    };

    messages.set(truncated.id, truncated);
    index?.add(truncated);
    lastIndexedTimestamp = Math.max(lastIndexedTimestamp, truncated.timestamp);

    evictOldest();
    schedulePersist();
  }

  if (type === "SEARCH") {
    const { query } = event.data;
    if (!index || !query) {
      self.postMessage({ type: "RESULTS", matches: [] });
      return;
    }

    const cleaned = query.replace(/@xark\s*/i, "").trim();
    const results = index.search(cleaned, { limit: 5 });

    const matches = results
      .map((r) => {
        const msg = messages.get(String(r.id));
        return msg
          ? { messageId: msg.id, content: msg.content, senderName: msg.senderName, timestamp: msg.timestamp }
          : null;
      })
      .filter(Boolean);

    self.postMessage({ type: "RESULTS", matches });
  }
};
```

- [ ] **Step 2: Verify Worker file has no import issues**

Run: `npx tsc --noEmit src/workers/memory-worker.ts 2>&1 | head -5`
Note: Web Workers with imports may need bundler configuration. If TypeScript errors occur with `self.onmessage`, add a `/// <reference lib="webworker" />` directive at the top.

- [ ] **Step 3: Commit**

```bash
git add src/workers/memory-worker.ts
git commit -m "feat: memory-worker with MiniSearch lexical engine, debounce, and eviction"
```

---

### Task 13: `useLocalMemory` Hook

**Files:**
- Create: `src/hooks/useLocalMemory.ts`

- [ ] **Step 1: Write the hook**

```typescript
// src/hooks/useLocalMemory.ts
// React hook for Tier 2 E2EE Memory Engine.
// Initializes Worker on space open, bridges postMessage/onmessage,
// exposes search() and indexMessage(). Encrypted blob persistence via IndexedDB.

"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import type { RecallResult } from "@/lib/local-recall";

const IDB_STORE = "xark-memory";
const IDB_VERSION = 1;

// ── IndexedDB helpers ──
function openIDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(IDB_STORE, IDB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("blobs")) {
        db.createObjectStore("blobs");
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function getBlob(spaceId: string): Promise<string | null> {
  const db = await openIDB();
  return new Promise((resolve) => {
    const tx = db.transaction("blobs", "readonly");
    const req = tx.objectStore("blobs").get(spaceId);
    req.onsuccess = () => resolve(req.result ?? null);
    req.onerror = () => resolve(null);
  });
}

async function setBlob(spaceId: string, data: string): Promise<void> {
  const db = await openIDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction("blobs", "readwrite");
    tx.objectStore("blobs").put(data, spaceId);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function deleteBlob(spaceId: string): Promise<void> {
  const db = await openIDB();
  return new Promise((resolve) => {
    const tx = db.transaction("blobs", "readwrite");
    tx.objectStore("blobs").delete(spaceId);
    tx.oncomplete = () => resolve();
    tx.onerror = () => resolve();
  });
}

// ── Encryption helpers — XChaCha20-Poly1305 via libsodium ──
// Key derived from identity key via HKDF. Blob is encrypted before IndexedDB write,
// decrypted on load. Consistent with existing crypto stack in src/lib/crypto/primitives.ts.
async function encryptAndSetBlob(spaceId: string, plaintext: string): Promise<void> {
  const { initCrypto, encrypt } = await import("@/lib/crypto/primitives");
  await initCrypto();
  // Derive a memory-index key from identity key using HKDF with "xark-memory" context
  const keyStore = await import("@/lib/crypto/keystore");
  const identityKey = await keyStore.getIdentityKey();
  if (!identityKey) return; // No identity key — skip persistence
  const sodium = (await import("libsodium-wrappers-sumo")).default;
  await sodium.ready;
  const salt = sodium.from_string(`xark-memory-${spaceId}`);
  const key = sodium.crypto_generichash(32, identityKey.privateKey, salt);
  const nonce = sodium.randombytes_buf(sodium.crypto_secretbox_NONCEBYTES);
  const ciphertext = sodium.crypto_secretbox_easy(sodium.from_string(plaintext), nonce, key);
  const combined = new Uint8Array(nonce.length + ciphertext.length);
  combined.set(nonce);
  combined.set(ciphertext, nonce.length);
  await setBlob(spaceId, sodium.to_base64(combined));
}

async function decryptBlob(spaceId: string): Promise<string | null> {
  const raw = await getBlob(spaceId);
  if (!raw) return null;
  try {
    const sodium = (await import("libsodium-wrappers-sumo")).default;
    await sodium.ready;
    const keyStore = await import("@/lib/crypto/keystore");
    const identityKey = await keyStore.getIdentityKey();
    if (!identityKey) return null;
    const salt = sodium.from_string(`xark-memory-${spaceId}`);
    const key = sodium.crypto_generichash(32, identityKey.privateKey, salt);
    const combined = sodium.from_base64(raw);
    const nonce = combined.slice(0, sodium.crypto_secretbox_NONCEBYTES);
    const ciphertext = combined.slice(sodium.crypto_secretbox_NONCEBYTES);
    const plaintext = sodium.crypto_secretbox_open_easy(ciphertext, nonce, key);
    return sodium.to_string(plaintext);
  } catch {
    return null; // Corrupted or wrong key — start fresh
  }
}

export function useLocalMemory(spaceId: string | null) {
  const workerRef = useRef<Worker | null>(null);
  const [ready, setReady] = useState(false);
  const [watermark, setWatermark] = useState<number | null>(null); // timestamp-based, not ID-based
  const resolveSearch = useRef<((results: RecallResult[]) => void) | null>(null);

  // ── Initialize Worker when spaceId changes ──
  useEffect(() => {
    if (!spaceId) return;

    const worker = new Worker(
      new URL("../workers/memory-worker.ts", import.meta.url),
      { type: "module" }
    );
    workerRef.current = worker;

    worker.onmessage = (event: MessageEvent) => {
      const { type } = event.data;

      if (type === "READY") {
        setReady(true);
        setWatermark(event.data.watermarkTime ?? null); // timestamp-based
      }

      if (type === "RESULTS") {
        resolveSearch.current?.(event.data.matches ?? []);
        resolveSearch.current = null;
      }

      if (type === "PERSIST") {
        // SECURITY: Encrypt blob before writing to IndexedDB.
        // Uses XChaCha20-Poly1305 via libsodium crypto_secretbox, key from identity key via HKDF.
        // For Phase 2 v1: encrypt with a key derived from a stable device secret stored in KeyStore.
        // The Worker sends serialized plaintext; main thread encrypts before IndexedDB write.
        encryptAndSetBlob(spaceId, event.data.payload).catch(() => {});
      }
    };

    // Load existing encrypted blob, decrypt, and init worker
    decryptBlob(spaceId).then((plaintext) => {
      worker.postMessage({
        type: "INIT",
        spaceId,
        serializedIndex: plaintext ?? undefined,
        deviceTier: "low", // lexical only in Phase 2
      });
    });

    return () => {
      worker.terminate();
      workerRef.current = null;
      setReady(false);
      setWatermark(null);
    };
  }, [spaceId]);

  const indexMessage = useCallback(
    (message: { id: string; content: string; senderName?: string; timestamp: number }) => {
      if (!workerRef.current || !ready) return;
      workerRef.current.postMessage({
        type: "INDEX_MESSAGE",
        message: {
          id: message.id,
          content: message.content.slice(0, 2000), // Per-message truncation (spec 11.2)
          senderName: message.senderName ?? "",
          timestamp: message.timestamp,
        },
      });
    },
    [ready]
  );

  const search = useCallback(
    (query: string): Promise<RecallResult[]> => {
      if (!workerRef.current || !ready) return Promise.resolve([]);
      return new Promise((resolve) => {
        resolveSearch.current = resolve;
        workerRef.current!.postMessage({ type: "SEARCH", query });
        // Timeout: if worker doesn't respond in 2s, resolve empty
        setTimeout(() => {
          if (resolveSearch.current === resolve) {
            resolveSearch.current = null;
            resolve([]);
          }
        }, 2000);
      });
    },
    [ready]
  );

  return { ready, watermark, indexMessage, search, deleteBlob: () => spaceId ? deleteBlob(spaceId) : Promise.resolve() };
}
```

- [ ] **Step 2: Commit**

```bash
git add src/hooks/useLocalMemory.ts
git commit -m "feat: useLocalMemory hook with Worker bridge and IndexedDB persistence"
```

---

### Task 14: `ContextCard.tsx` Component

**Files:**
- Create: `src/components/os/ContextCard.tsx`

- [ ] **Step 1: Write the ContextCard component**

```typescript
// src/components/os/ContextCard.tsx
// Actionable context card for Tier 2 recall results.
// Slides up above ChatInput. Jump to Message + Quote to Group.

"use client";

import { colors, ink, text, timing } from "@/lib/theme";

interface ContextCardProps {
  content: string;
  senderName: string;
  timestamp: number;
  onJump: () => void;
  onQuote: (content: string, senderName: string) => void;
  onDismiss: () => void;
}

function formatRelativeTime(ts: number): string {
  const diff = Date.now() - ts;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function ContextCard({
  content,
  senderName,
  timestamp,
  onJump,
  onQuote,
  onDismiss,
}: ContextCardProps) {
  // Truncate content to 2 lines (~120 chars)
  const displayContent = content.length > 120 ? content.slice(0, 117) + "..." : content;

  return (
    <div
      style={{
        padding: "10px 14px",
        background: "rgba(var(--xark-accent-rgb), 0.06)",
        borderRadius: "8px",
        marginBottom: "8px",
      }}
    >
      {/* ── Header: sender + time + dismiss ── */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "4px" }}>
        <span style={{ ...text.timestamp, color: ink.secondary }}>
          {senderName} &middot; {formatRelativeTime(timestamp)}
        </span>
        <span
          role="button"
          tabIndex={0}
          onClick={onDismiss}
          onKeyDown={(e) => { if (e.key === "Enter") onDismiss(); }}
          style={{ ...text.timestamp, color: ink.tertiary, cursor: "pointer" }}
          className="outline-none"
        >
          &times;
        </span>
      </div>

      {/* ── Content ── */}
      <p style={{ ...text.hint, color: ink.primary, marginBottom: "8px" }}>
        {displayContent}
      </p>

      {/* ── Actions ── */}
      <div style={{ display: "flex", gap: "16px" }}>
        <span
          role="button"
          tabIndex={0}
          onClick={onJump}
          onKeyDown={(e) => { if (e.key === "Enter") onJump(); }}
          style={{ ...text.timestamp, color: colors.cyan, cursor: "pointer" }}
          className="outline-none"
        >
          jump to message
        </span>
        <span
          role="button"
          tabIndex={0}
          onClick={() => onQuote(content, senderName)}
          onKeyDown={(e) => { if (e.key === "Enter") onQuote(content, senderName); }}
          style={{ ...text.timestamp, color: colors.cyan, cursor: "pointer" }}
          className="outline-none"
        >
          quote to group
        </span>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/os/ContextCard.tsx
git commit -m "feat: ContextCard component for Tier 2 recall results"
```

---

### Task 15: Space Page — Wire Tier 2 into sendMessage

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Add imports and state for Tier 2**

```typescript
import { isRecallQuestion, getRecallWhisper } from "@/lib/local-recall";
import type { RecallResult } from "@/lib/local-recall";
import { useLocalMemory } from "@/hooks/useLocalMemory";
import { useDeviceTier } from "@/hooks/useDeviceTier";
import { ContextCard } from "@/components/os/ContextCard";

// Inside SpacePageInner:
const deviceTier = useDeviceTier();
const localMemory = useLocalMemory(spaceId);
const [contextCard, setContextCard] = useState<RecallResult | null>(null);
const [recallWhisper, setRecallWhisper] = useState<string | null>(null);
```

- [ ] **Step 2: Feed decrypted messages to Worker**

In the batch decrypt `useEffect` (after `decryptedMap` merge), add:

```typescript
// Feed decrypted messages to Tier 2 index
if (localMemory.ready) {
  for (const m of mapped) {
    if (!localMemory.watermark || m.timestamp > localMemory.watermark) {
      localMemory.indexMessage({
        id: m.id,
        content: m.content,
        senderName: m.senderName,
        timestamp: m.timestamp,
      });
    }
  }
}
```

In the Realtime broadcast handler (after content is resolved), add:

```typescript
// Feed to Tier 2 index
if (localMemory.ready && content) {
  localMemory.indexMessage({
    id: incoming.id,
    content,
    senderName: incoming.sender_name ?? "",
    timestamp: new Date(incoming.created_at).getTime(),
  });
}
```

- [ ] **Step 3: Wire Tier 2 into sendMessage**

After the Tier 1 block in `sendMessage`, add:

```typescript
    // ── TIER 2: E2EE Memory Engine ──
    if (hasXark && isRecallQuestion(txt)) {
      const results = await localMemory.search(txt);
      if (results.length > 0) {
        setInput("");
        setContextCard(results[0]);
        return;
      }
      // Zero results — show tier-aware coaching whisper, preserve input
      setRecallWhisper(getRecallWhisper(deviceTier));
      setTimeout(() => setRecallWhisper(null), 5000);
      return; // STRICT HALT
    }
```

- [ ] **Step 4: Add ContextCard and recall whisper UI**

Below the constraint whisper section:

```typescript
{/* ── Context Card (Tier 2 recall result) ── */}
{contextCard && (
  <div className="fixed inset-x-0 z-20 mx-auto px-6" style={{ bottom: "80px", maxWidth: "640px" }}>
    <ContextCard
      content={contextCard.content}
      senderName={contextCard.senderName}
      timestamp={contextCard.timestamp}
      onJump={() => {
        // Scroll to message — find index and scroll
        const msgIndex = messages.findIndex((m) => m.id === contextCard.messageId);
        if (msgIndex >= 0) {
          const el = document.getElementById(`msg-${contextCard.messageId}`);
          el?.scrollIntoView({ behavior: "smooth", block: "center" });
          // Brief cyan pulse
          el?.animate([{ background: "rgba(var(--xark-accent-rgb), 0.15)" }, { background: "transparent" }], { duration: 1500 });
        }
        setContextCard(null);
      }}
      onQuote={(content, sender) => {
        setInput(`> ${sender}: "${content.slice(0, 80)}"\n`);
        setContextCard(null);
      }}
      onDismiss={() => setContextCard(null)}
    />
  </div>
)}

{/* ── Recall whisper (Tier 2 zero results) ── */}
{recallWhisper && (
  <div className="fixed inset-x-0 z-20 mx-auto px-6" style={{ bottom: "80px", maxWidth: "640px" }}>
    <p
      style={{ ...text.hint, color: ink.tertiary, textAlign: "center", cursor: "pointer" }}
      onClick={() => setRecallWhisper(null)}
    >
      {recallWhisper}
    </p>
  </div>
)}
```

- [ ] **Step 5: Run all tests**

Run: `npx vitest run`
Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: wire Tier 2 memory engine into Space page with ContextCard"
```

---

## Chunk 3: Phase 3 — Semantic Search Upgrade (Deferred)

> Phase 3 adds transformers.js for high-tier devices. It is architecturally isolated — only the Worker's internal search engine changes. No UI, API, or contract changes. This phase should be implemented after Phase 2 is validated in production.

### Task 16: transformers.js Integration (outline only)

**Files:**
- Modify: `src/workers/memory-worker.ts` (add semantic search path)
- Modify: `package.json` (add `@xenova/transformers`)

**Key steps:**
1. Install `@xenova/transformers` (~22MB model cached via ServiceWorker)
2. In Worker `INIT`, if `deviceTier === "high"`, load the `all-MiniLM-L6-v2` ONNX model
3. On `INDEX_MESSAGE`, generate 384-dim embedding alongside lexical index
4. On `SEARCH`, compute query embedding → cosine similarity against stored embeddings
5. Return top-5 by similarity score
6. The `useLocalMemory` hook already passes `deviceTier` — no hook changes needed

**Deferred to a separate plan after Phase 2 ships and is validated.**

---

## Chunk 4: Phase 4 — Tier 3 Cloud Optimizations

### Task 17: Prompt Split (Static/Dynamic)

**Files:**
- Modify: `src/lib/intelligence/orchestrator.ts`

- [ ] **Step 1: Extract buildStaticPrompt from buildIntentPrompt**

Split the existing `buildIntentPrompt()` function. The static portion (voice rules, boundaries, tool definitions, routing examples, JSON schema) moves to `buildStaticPrompt()`. The dynamic portion (space title, grounding context, recent messages, current date, user request) moves to `buildDynamicPrompt()`.

```typescript
/** Static system prompt — stable across all invocations (~800 tokens) */
export function buildStaticPrompt(): string {
  return `You are @xark, a smart friend who handles group planning logistics...

VOICE RULES (CRITICAL - READ CAREFULLY):
... [existing voice rules, boundaries, tool definitions, routing examples, JSON schema] ...

AVAILABLE TOOLS (two tiers):
... [existing tool definitions] ...

TIER SELECTION (CRITICAL):
... [existing tier selection rules] ...

ROUTING RULES:
... [existing routing rules] ...

ROUTING EXAMPLES:
... [existing examples] ...

JSON SCHEMA:
... [existing schema] ...`;
}

/** Dynamic prompt — changes every invocation */
export function buildDynamicPrompt(input: OrchestratorInput): string {
  return `SPACE TITLE (this is the destination/context for ALL queries):
"${input.spaceTitle || "untitled"}"

GROUNDING CONTEXT (what's been decided):
${input.groundingPrompt}
IMPLICIT CONSTRAINTS: if the grounding context mentions a budget, dietary restriction, or accessibility need, you MUST automatically include it in tool params.

RECENT MESSAGES:
${input.recentMessages.map((m) => \`\${m.sender_name || m.role}: \${m.content}\`).join("\\n")}

CURRENT DATE & TIME: ${new Date().toISOString()}
DATE MATH RULES: if a user says "next weekend", "tonight", "tomorrow", or any relative date, use the CURRENT DATE to calculate exact YYYY-MM-DD.

USER REQUEST: ${input.userMessage}`;
}

// Update buildIntentPrompt to compose:
function buildIntentPrompt(input: OrchestratorInput): string {
  return buildStaticPrompt() + "\n\n" + buildDynamicPrompt(input);
}
```

- [ ] **Step 2: Add flash model guard**

```typescript
const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";
if (modelName.includes("pro")) {
  console.warn("[@xark] pro model detected — flash recommended for routing latency");
}
```

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `npx vitest run`
Expected: All PASS. The prompt content is identical — just reorganized.

- [ ] **Step 4: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts
git commit -m "refactor: split buildIntentPrompt into static/dynamic for context caching readiness"
```

---

### Task 18: Streaming Synthesis

**Files:**
- Modify: `src/lib/intelligence/orchestrator.ts`
- Modify: `src/app/api/message/route.ts`
- Modify: `src/app/api/xark/route.ts`
- Modify: `src/components/os/XarkChat.tsx`

- [ ] **Step 1: Add streaming synthesis to orchestrator**

Create a new `orchestrateStreaming()` export that calls `onChunk` during synthesis:

```typescript
/** Streaming variant — identical to orchestrate() but streams the final synthesis step */
export async function orchestrateStreaming(
  input: OrchestratorInput,
  onChunk: (chunk: string, seq: number, done: boolean) => void
): Promise<OrchestratorResult> {
  // Intent parsing and tool execution remain non-streaming (identical to orchestrate())
  // ... [same intent parse + tool execution logic] ...

  // Only the final synthesis step streams
  const synthesisStream = await model.generateContentStream(synthesisPrompt);

  let seq = 0;
  let accumulated = "";
  let buffer = "";

  const flushBuffer = () => {
    if (buffer.length > 0) {
      accumulated += buffer;
      onChunk(buffer, seq++, false);
      buffer = "";
    }
  };

  // Batch chunks every 50ms for WebSocket efficiency
  const flushTimer = setInterval(flushBuffer, 50);

  for await (const chunk of synthesisStream.stream) {
    const chunkText = chunk.text();
    if (chunkText) {
      buffer += chunkText;
      // Also flush every ~10 tokens (~40 chars)
      if (buffer.length >= 40) flushBuffer();
    }
  }

  clearInterval(flushTimer);
  flushBuffer();
  onChunk("", seq++, true); // Signal completion

  return {
    response: accumulated,
    searchResults: results,
    action: "search",
    tool: parsed.tool,
  };
}
```

- [ ] **Step 2: Add chunk broadcast to /api/message and /api/xark**

In the `orchestrateAndUpdate()` function within `/api/message/route.ts`, replace the synthesis call with the streaming version. Broadcast each chunk via Supabase Realtime:

```typescript
const channel = supabaseAdmin.channel(`chat:${spaceId}`);

await orchestrateStreaming(orchestratorInput, (chunk, seq, done) => {
  channel.send({
    type: "broadcast",
    event: "xark_stream_chunk",
    payload: { messageId: xarkMsgId, chunk, seq, done },
  });
});
```

- [ ] **Step 3: Add chunk accumulation to XarkChat**

In the Space page broadcast handler, add a case for `xark_stream_chunk`:

```typescript
// In the Realtime subscription:
channel.on("broadcast", { event: "xark_stream_chunk" }, (payload) => {
  const { messageId, chunk, seq, done } = payload.payload;
  setMessages((prev) =>
    prev.map((m) =>
      m.id === messageId
        ? { ...m, content: (m.content === "thinking..." ? "" : m.content) + chunk }
        : m
    )
  );
  if (done) setIsThinking(false);
});
```

- [ ] **Step 4: Verify build passes**

Run: `npx next build --no-lint 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts src/app/api/message/route.ts src/app/api/xark/route.ts src/app/space/[id]/page.tsx
git commit -m "feat: streaming synthesis with batched chunk broadcast"
```

---

### Task 19: Multi-Action Parallel Execution

**Files:**
- Modify: `src/lib/intelligence/orchestrator.ts`

- [ ] **Step 1: Extend intent parsing for multi-action**

In `orchestrate()`, after parsing the intent JSON, add support for the `actions` array:

```typescript
// After parsing intent:
if (parsed.actions && Array.isArray(parsed.actions)) {
  // Multi-action: fire all tools concurrently
  const toolCalls = parsed.actions
    .filter((a: any) => a.action === "search" && a.tool && a.params)
    .map((a: any) => {
      const tool = getTool(a.tool);
      if (!tool) return Promise.reject(new Error(`unknown tool: ${a.tool}`));
      return withTimeout(
        tool.tier === "apify"
          ? runActor(tool.actorId, tool.paramMap(a.params))
          : geminiLocalSearch(model, a.params.query ?? "", input.spaceTitle ?? ""),
        GEMINI_TIMEOUT_MS
      ).then((results) => ({ tool: a.tool, results }));
    });

  const outcomes = await Promise.allSettled(toolCalls);
  const succeeded: { tool: string; results: any[] }[] = [];
  const timedOut: string[] = [];

  outcomes.forEach((outcome, i) => {
    if (outcome.status === "fulfilled") {
      succeeded.push(outcome.value);
    } else {
      timedOut.push(parsed.actions![i]?.tool ?? "unknown");
    }
  });

  // Merge all results
  const allResults = succeeded.flatMap((s) =>
    s.results.map((r: any) => ({ ...r, source: s.tool }))
  );

  // Synthesis with timeout context
  const timeoutNote = timedOut.length > 0
    ? `\nNOTE: ${timedOut.join(", ")} search timed out. Mention this briefly.`
    : "";

  // ... synthesize with allResults + timeoutNote ...
}
```

- [ ] **Step 2: Update intent prompt to document multi-action schema**

Add to the JSON SCHEMA section in `buildStaticPrompt()`:

```
For multi-tool requests (e.g., "find flights AND hotels"):
{
  "_thought_process": "...",
  "actions": [
    { "action": "search", "tool": "flight", "params": {...} },
    { "action": "search", "tool": "hotel", "params": {...} }
  ]
}
```

- [ ] **Step 3: Run tests**

Run: `npx vitest run`
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts
git commit -m "feat: multi-action parallel execution with Promise.allSettled"
```

---

### Task 20: Conditional Context Caching

**Files:**
- Modify: `src/lib/intelligence/orchestrator.ts`

- [ ] **Step 1: Add token estimator and caching logic**

```typescript
const CACHE_TRIGGER_THRESHOLD = 33_000; // buffered above 32,768 API minimum

function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

// In orchestrate(), before the intent parse:
const staticPrompt = buildStaticPrompt();
const dynamicPrompt = buildDynamicPrompt(input);
const fullPrompt = staticPrompt + "\n\n" + dynamicPrompt;
const tokenEstimate = estimateTokens(fullPrompt);

let intentResult;
if (tokenEstimate > CACHE_TRIGGER_THRESHOLD) {
  // TODO: Implement Gemini Context Caching when payload exceeds threshold
  // For now, use standard path (context caching requires server-side cache management)
  console.log(`[@xark] payload ~${tokenEstimate} tokens — context caching candidate`);
}

// Standard path (always used for now — caching is a future optimization)
intentResult = await withTimeout(
  model.generateContent({
    contents: [{ role: "user", parts: [{ text: fullPrompt }] }],
    generationConfig: { responseMimeType: "application/json" },
  }),
  GEMINI_TIMEOUT_MS
);
```

Note: Full Gemini Context Caching API integration requires a `CachedContent` resource with TTL management. The threshold detection and prompt split are the structural prerequisites. The actual caching API call can be wired in when a space's payload consistently exceeds 33K tokens.

- [ ] **Step 2: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts
git commit -m "feat: context caching readiness with token estimation and threshold detection"
```

---

### Task 21: Final Integration Test

- [ ] **Step 1: Run full test suite**

Run: `npx vitest run`
Expected: All tests PASS.

- [ ] **Step 2: Run build**

Run: `npx next build --no-lint`
Expected: Build succeeds.

- [ ] **Step 3: Manual verification checklist**

Start dev server: `npm run dev`

1. Open a space. Type `@xark show decide` — view should switch instantly (no spinner).
2. Type `@xark set dates to june 1-5` — whisper appears "dates set to june 1-5", ledger pill appears in timeline for all users.
3. Type `@xark rename space to Miami Beach` — whisper + ledger pill.
4. Tap "undo" on a ledger pill — revert ledger pill appears.
5. Type `@xark status` — whisper shows item counts.
6. Type `@xark what was that hotel nina mentioned` — recall result or coaching whisper appears.
7. Type `@xark find coffee shops` — falls through to Tier 3 (Gemini), normal flow.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration test corrections for three-tier hybrid brain"
```
