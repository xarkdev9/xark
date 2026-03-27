# XarkSpotlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the XarkSpotlight — a global intelligence surface that turns the "xark" brand anchor into an omnipresent command line with Ghost Prompt whispers, Taste Graph personalization, and a Consensus Closer that auto-locks decisions.

**Architecture:** ControlCaret transforms from pure navigation into the Spotlight invoke point. Tapping opens a half-sheet overlay with a Ghost Prompt input. The sheet auto-dismisses after 800ms morph on send, routing results to the correct space. A whisper engine generates proactive suggestions that pre-fill the Ghost Prompt. The Taste Graph (explicit constraints + implicit reaction weights in Postgres JSONB) personalizes every search. The Consensus Closer elevates cards with gold borders and countdown timers when agreement > 80%, auto-locking via server cron if no one objects.

**Tech Stack:** Next.js 16.1.6 + React 19.2.3 + Framer Motion + Supabase Postgres (JSONB) + Supabase Realtime + Gemini 2.5 Flash + Vercel Cron

**Prerequisites:** Migration `027_taste_graph_consensus.sql` must be applied to Supabase before starting. Verify `agreement_score` is reliably written to `decision_items` by existing reaction triggers/code (known bug B1 in CLAUDE.md).

**Graceful Degradation:** Every smart feature wraps in try/catch with silent fallback. Taste Graph timeout (800ms) → generic search. Trigger failure → reaction still commits. Cron failure → manual "Finalize" button on card.

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `src/components/os/SpotlightSheet.tsx` | Half-sheet overlay: Ghost Prompt input, space chips (Galaxy), 800ms morph dismiss, send handler |
| `src/components/os/GhostInput.tsx` | Input with ghost text pre-fill. Type = override (ghost shatters). Send = accept. |
| `src/components/os/ConsensusTimer.tsx` | Live countdown timer rendered on DecisionCard when `lock_deadline` is set |
| `src/components/os/ConsensusBanner.tsx` | Pinned system banner above chat: "Consensus reached. Locking in Xm." |
| `src/lib/whispers.ts` | Whisper engine: generate whispers from Layer 3 state, priority queue, ranking |
| `src/lib/taste.ts` | Taste Graph helpers: intersect group constraints, build Gemini injection string |
| `src/hooks/useWhispers.ts` | React hook: fetch whispers for current user, manage queue, dismiss/consume |
| `src/hooks/useSpotlight.ts` | React hook: sheet open/close, morph state, send-to-space routing, auto-navigate |
| `src/app/api/cron/consensus/route.ts` | Vercel cron: calls `auto_lock_expired_consensus()` RPC every minute |
| `src/app/api/taste/route.ts` | POST endpoint: parses Day 1 Ghost Prompt text via Gemini → saves constraints |

### Modified Files

| File | Changes |
|------|---------|
| `src/components/os/ControlCaret.tsx` | Anchor gains cyan aura when whispers pending. Tap opens SpotlightSheet instead of (or alongside) space panel. |
| `src/components/os/PossibilityHorizon.tsx` | Reads `lock_deadline` from Realtime. Passes consensus state to DecisionCard. |
| `src/components/os/DecisionCard.tsx` | Gold pulsing border when in countdown. ConsensusTimer overlay. "Finalize" button when timer expired. |
| `src/app/space/[id]/page.tsx` | Mounts ConsensusBanner. Passes spaceId context to SpotlightSheet. |
| `src/app/api/xark/route.ts` | Fetches taste profiles via `get_space_taste_profiles()`. Injects constraints + weights into orchestrator. |
| `src/lib/intelligence/orchestrator.ts` | `OrchestratorInput` gains `tasteContext?: TasteContext`. `buildDynamicPrompt()` injects taste. |
| `src/app/galaxy/page.tsx` | Passes Galaxy context flag to SpotlightSheet for space chip picker. |
| `vercel.json` | Add `/api/cron/consensus` cron at `* * * * *` (every minute). |

---

## Task 1: Cron Endpoint for Consensus Auto-Lock

**Files:**
- Create: `src/app/api/cron/consensus/route.ts`
- Modify: `vercel.json`

- [ ] **Step 1: Create the cron endpoint**

```typescript
// src/app/api/cron/consensus/route.ts
import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function GET(req: NextRequest) {
  // Verify cron secret — matches existing pattern in /api/cron/purge
  const authHeader = req.headers.get("authorization");
  const cronSecret = process.env.CRON_SECRET;

  if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  const { data, error } = await supabaseAdmin.rpc("auto_lock_expired_consensus");

  if (error) {
    console.error("[cron/consensus] auto-lock failed:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ locked: data ?? 0 });
}
```

- [ ] **Step 2: Add cron to vercel.json**

Add to the `crons` array:
```json
{
  "path": "/api/cron/consensus",
  "schedule": "* * * * *"
}
```

- [ ] **Step 3: Verify existing cron pattern matches**

Read `src/app/api/cron/purge/route.ts` to confirm the auth pattern is consistent. Use the same `CRON_SECRET` verification.

- [ ] **Step 4: Commit**

```bash
git add src/app/api/cron/consensus/route.ts vercel.json
git commit -m "feat(consensus): add auto-lock cron endpoint — fires Green-Lock on expired countdowns every minute"
```

---

## Task 2: Taste Graph Client Library

**Files:**
- Create: `src/lib/taste.ts`

- [ ] **Step 1: Define types and intersection logic**

```typescript
// src/lib/taste.ts
// Taste Graph helpers — intersect group constraints, build Gemini injection.
// Called by /api/xark at search time. Pure functions, no side effects.

export interface TasteProfile {
  user_id: string;
  hard_constraints: string[];  // ["vegan", "no_chains"]
  implicit_weights: Record<string, number>;  // {"japanese": 12, "steakhouse": -6}
  onboarded: boolean;
}

export interface TasteContext {
  /** Hard vetoes — union of all members' constraints. One vegan = no steakhouses. */
  hardConstraints: string[];
  /** Soft preferences — aggregated weight string for Gemini prompt injection. */
  softPreferences: string;
  /** How many members have onboarded (for analytics/whisper triggers). */
  onboardedCount: number;
  memberCount: number;
}

/**
 * Intersect taste profiles for a group. Returns unified constraints + preferences.
 * Called server-side by /api/xark with profiles from get_space_taste_profiles RPC.
 */
export function intersectTasteProfiles(profiles: TasteProfile[]): TasteContext {
  // Hard constraints: UNION of all members (one vegan vetoes steakhouses for everyone)
  const allConstraints = new Set<string>();
  for (const p of profiles) {
    if (Array.isArray(p.hard_constraints)) {
      for (const c of p.hard_constraints) allConstraints.add(c);
    }
  }

  // Implicit weights: SUM across all members
  const aggregated: Record<string, number> = {};
  for (const p of profiles) {
    if (p.implicit_weights && typeof p.implicit_weights === "object") {
      for (const [key, val] of Object.entries(p.implicit_weights)) {
        if (typeof val === "number") {
          aggregated[key] = (aggregated[key] ?? 0) + val;
        }
      }
    }
  }

  // Sort by absolute weight descending, take top 5 for prompt brevity
  const sorted = Object.entries(aggregated)
    .sort((a, b) => Math.abs(b[1]) - Math.abs(a[1]))
    .slice(0, 5);

  // Build a natural-language preference string for Gemini
  const likes = sorted.filter(([, v]) => v > 0).map(([k]) => k);
  const dislikes = sorted.filter(([, v]) => v < 0).map(([k]) => k);

  const parts: string[] = [];
  if (likes.length > 0) parts.push(`group prefers: ${likes.join(", ")}`);
  if (dislikes.length > 0) parts.push(`group avoids: ${dislikes.join(", ")}`);

  return {
    hardConstraints: Array.from(allConstraints),
    softPreferences: parts.join(". "),
    onboardedCount: profiles.filter((p) => p.onboarded).length,
    memberCount: profiles.length,
  };
}

/**
 * Build the Gemini prompt injection from taste context.
 * Returns a short string to append to the dynamic prompt.
 */
export function buildTastePromptInjection(ctx: TasteContext): string {
  const lines: string[] = [];

  if (ctx.hardConstraints.length > 0) {
    lines.push(`HARD CONSTRAINTS (must respect): ${ctx.hardConstraints.join(", ")}`);
  }

  if (ctx.softPreferences) {
    lines.push(`SOFT PREFERENCES: ${ctx.softPreferences}`);
  }

  return lines.length > 0
    ? `\n\nGROUP TASTE PROFILE:\n${lines.join("\n")}`
    : "";
}
```

- [ ] **Step 2: Write tests**

```typescript
// src/lib/__tests__/taste.test.ts
import { describe, it, expect } from "vitest";
import { intersectTasteProfiles, buildTastePromptInjection } from "../taste";

describe("intersectTasteProfiles", () => {
  it("unions hard constraints across all members", () => {
    const profiles = [
      { user_id: "a", hard_constraints: ["vegan"], implicit_weights: {}, onboarded: true },
      { user_id: "b", hard_constraints: ["no_chains", "gluten_free"], implicit_weights: {}, onboarded: true },
    ];
    const ctx = intersectTasteProfiles(profiles);
    expect(ctx.hardConstraints).toContain("vegan");
    expect(ctx.hardConstraints).toContain("no_chains");
    expect(ctx.hardConstraints).toContain("gluten_free");
    expect(ctx.hardConstraints).toHaveLength(3);
  });

  it("sums implicit weights across members", () => {
    const profiles = [
      { user_id: "a", hard_constraints: [], implicit_weights: { japanese: 5, italian: -3 }, onboarded: true },
      { user_id: "b", hard_constraints: [], implicit_weights: { japanese: 5, mexican: 1 }, onboarded: true },
    ];
    const ctx = intersectTasteProfiles(profiles);
    expect(ctx.softPreferences).toContain("japanese");
    expect(ctx.softPreferences).not.toContain("italian"); // -3 is a dislike
  });

  it("handles empty profiles gracefully", () => {
    const ctx = intersectTasteProfiles([]);
    expect(ctx.hardConstraints).toEqual([]);
    expect(ctx.softPreferences).toBe("");
    expect(ctx.memberCount).toBe(0);
  });

  it("counts onboarded members", () => {
    const profiles = [
      { user_id: "a", hard_constraints: [], implicit_weights: {}, onboarded: true },
      { user_id: "b", hard_constraints: [], implicit_weights: {}, onboarded: false },
      { user_id: "c", hard_constraints: [], implicit_weights: {}, onboarded: true },
    ];
    const ctx = intersectTasteProfiles(profiles);
    expect(ctx.onboardedCount).toBe(2);
    expect(ctx.memberCount).toBe(3);
  });
});

describe("buildTastePromptInjection", () => {
  it("returns empty string when no taste data", () => {
    const result = buildTastePromptInjection({
      hardConstraints: [],
      softPreferences: "",
      onboardedCount: 0,
      memberCount: 0,
    });
    expect(result).toBe("");
  });

  it("includes hard constraints and soft preferences", () => {
    const result = buildTastePromptInjection({
      hardConstraints: ["vegan", "no_chains"],
      softPreferences: "group prefers: japanese. group avoids: steakhouse",
      onboardedCount: 2,
      memberCount: 3,
    });
    expect(result).toContain("HARD CONSTRAINTS");
    expect(result).toContain("vegan");
    expect(result).toContain("SOFT PREFERENCES");
    expect(result).toContain("japanese");
  });
});
```

- [ ] **Step 3: Run tests**

```bash
npx vitest run src/lib/__tests__/taste.test.ts
```

- [ ] **Step 4: Commit**

```bash
git add src/lib/taste.ts src/lib/__tests__/taste.test.ts
git commit -m "feat(taste): taste graph intersection library with tests"
```

---

## Task 3: Day 1 Taste Onboarding API

**Files:**
- Create: `src/app/api/taste/route.ts`

- [ ] **Step 1: Create the onboarding endpoint**

This endpoint receives the raw Day 1 Ghost Prompt text ("I'm vegan, hate tourist traps, massive coffee snob"), calls Gemini to parse it into structured constraints, and saves via the `save_taste_profile` RPC.

```typescript
// src/app/api/taste/route.ts
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export const maxDuration = 15;

export async function POST(req: NextRequest) {
  // Auth — verifyAuth takes the Authorization header string, not the request
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  // Rate limit: 3/min (onboarding is a one-time action)
  // checkRateLimit is synchronous, windowMs in milliseconds (60_000 = 1 minute)
  if (!checkRateLimit(`taste:${auth.userId}`, 3, 60_000)) {
    return NextResponse.json({ error: "Rate limited" }, { status: 429 });
  }

  const { text } = await req.json();
  if (!text || typeof text !== "string" || text.length > 500) {
    return NextResponse.json({ error: "Invalid input" }, { status: 400 });
  }

  // Parse constraints via Gemini (fast, ~1-2s)
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return NextResponse.json({ error: "AI unavailable" }, { status: 503 });

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: "gemini-2.5-flash",
    generationConfig: { responseMimeType: "application/json" },
  });

  const prompt = `Parse the following user preference statement into a JSON array of short constraint tags.
Rules:
- Tags should be lowercase, underscore-separated (e.g., "vegan", "no_chains", "budget_under_200")
- Dietary: vegan, vegetarian, gluten_free, halal, kosher, no_seafood, no_spicy, etc.
- Style: no_chains, no_tourist_traps, local_only, fine_dining, casual, specialty_coffee, etc.
- Budget: budget_under_50, budget_under_100, budget_under_200, luxury, etc.
- Accessibility: wheelchair_accessible, no_stairs, etc.
- Return ONLY a JSON array of strings. Max 10 tags.

User says: "${text.slice(0, 500)}"

JSON:`;

  try {
    const result = await model.generateContent(prompt);
    const raw = result.response.text();
    const constraints: string[] = JSON.parse(raw);

    if (!Array.isArray(constraints) || constraints.some((c) => typeof c !== "string")) {
      return NextResponse.json({ error: "Parse failed" }, { status: 500 });
    }

    // Save to DB via RPC
    if (supabaseAdmin) {
      await supabaseAdmin.rpc("save_taste_profile", {
        p_user_id: auth.userId,
        p_constraints: JSON.stringify(constraints.slice(0, 10)),
        p_raw_text: text.slice(0, 500),
      });
    }

    return NextResponse.json({ constraints });
  } catch (err) {
    console.error("[taste] Parse failed:", err);
    return NextResponse.json({ error: "Parse failed" }, { status: 500 });
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/app/api/taste/route.ts
git commit -m "feat(taste): Day 1 onboarding API — Gemini parses natural language into constraint tags"
```

---

## Task 4: Wire Taste Graph into /api/xark Search

**Files:**
- Modify: `src/app/api/xark/route.ts`
- Modify: `src/lib/intelligence/orchestrator.ts`

- [ ] **Step 1: Add taste fetch to /api/xark with 800ms timeout**

In `/api/xark/route.ts`, add taste profile fetch inside the existing `Promise.all` block (around line 149). Wrap in an 800ms timeout for graceful degradation.

```typescript
// Add import at top
import { intersectTasteProfiles, buildTastePromptInjection, type TasteContext } from "@/lib/taste";

// Inside the POST handler, replace the existing Promise.all with:
const tasteTimeout = new Promise<null>((resolve) => setTimeout(() => resolve(null), 800));
const tasteFetch = supabaseAdmin
  ? supabaseAdmin.rpc("get_space_taste_profiles", { p_space_id: spaceId }).then((r) => r.data)
  : Promise.resolve(null);

const [spaceRow, groundingCtx, recentMsgs, tasteRaw] = await Promise.all([
  supabaseAdmin?.from("spaces").select("title").eq("id", spaceId).single(),
  buildGroundingContext(spaceId),
  fetchMessages(spaceId, { limit: 15 }),
  Promise.race([tasteFetch, tasteTimeout]),  // 800ms timeout — graceful degradation
]);

// Build taste context (null-safe)
let tasteContext: TasteContext | null = null;
if (Array.isArray(tasteRaw) && tasteRaw.length > 0) {
  try {
    tasteContext = intersectTasteProfiles(tasteRaw);
  } catch {
    // Silent degradation — search proceeds without personalization
  }
}
```

- [ ] **Step 2: Pass taste context to orchestrator**

In the `orchestrate()` call, add tasteContext to the input:

```typescript
const result = await orchestrate({
  userMessage: sanitized,
  groundingPrompt: generateGroundingPrompt(groundingCtx),
  recentMessages: sanitizeForIntelligence(recentMsgs),
  spaceId,
  spaceTitle: spaceRow?.data?.title || spaceId,
  tasteContext,  // NEW — may be null
});
```

- [ ] **Step 3: Update OrchestratorInput type and buildDynamicPrompt**

In `orchestrator.ts`:

```typescript
// Add to OrchestratorInput interface:
tasteContext?: import("@/lib/taste").TasteContext | null;

// In buildDynamicPrompt(), before the USER REQUEST section, add:
if (input.tasteContext) {
  const tasteInjection = buildTastePromptInjection(input.tasteContext);
  if (tasteInjection) {
    prompt += tasteInjection;
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/api/xark/route.ts src/lib/intelligence/orchestrator.ts
git commit -m "feat(taste): wire taste graph into search — 800ms graceful timeout, group constraints injected into Gemini"
```

---

## Task 5: Whisper Engine

**Files:**
- Create: `src/lib/whispers.ts`
- Create: `src/hooks/useWhispers.ts`

- [ ] **Step 1: Create the whisper engine**

Whispers are generated from Layer 3 state. No LLM call. Pure deterministic checks.

```typescript
// src/lib/whispers.ts
import { supabase } from "./supabase";

export interface Whisper {
  id: string;
  priority: number;  // Lower = higher priority. P0 = consensus, P1 = time-sensitive, P2 = nudge
  ghostText: string;  // Pre-fills the Ghost Prompt input
  spaceId: string;
  spaceTitle: string;
  type: "consensus_ready" | "missing_category" | "price_drop" | "onboarding" | "nudge_vote";
  itemId?: string;  // For consensus whispers
}

/**
 * Generate whispers for a user across all their spaces.
 * Runs deterministic Layer 3 checks. No LLM. ~50ms.
 */
export async function generateWhispers(userId: string): Promise<Whisper[]> {
  const whispers: Whisper[] = [];

  try {
    // Check if user has onboarded taste profile
    const { data: taste } = await supabase
      .from("user_taste_profiles")
      .select("onboarded")
      .eq("user_id", userId)
      .single();

    if (!taste || !taste.onboarded) {
      whispers.push({
        id: "onboarding",
        priority: 2,
        ghostText: "tell me how you travel and what you eat.",
        spaceId: "",
        spaceTitle: "",
        type: "onboarding",
      });
    }

    // Fetch active spaces with decision context
    const { data: spaces } = await supabase
      .from("space_members")
      .select("space_id, spaces(title)")
      .eq("user_id", userId);

    if (!spaces || spaces.length === 0) return whispers;

    const spaceIds = spaces.map((s) => s.space_id);

    // Fetch items in countdown (consensus ready to lock)
    const { data: countdownItems } = await supabase
      .from("decision_items")
      .select("id, title, space_id, lock_deadline, agreement_score")
      .in("space_id", spaceIds)
      .not("lock_deadline", "is", null)
      .eq("is_locked", false)
      .order("lock_deadline", { ascending: true })
      .limit(3);

    for (const item of countdownItems ?? []) {
      const space = spaces.find((s) => s.space_id === item.space_id);
      const title = (space?.spaces as { title?: string })?.title ?? item.space_id;
      const pct = Math.round((item.agreement_score ?? 0) * 100);

      whispers.push({
        id: `consensus_${item.id}`,
        priority: 0,  // P0 — highest
        ghostText: `${item.title} has ${pct}% consensus. hit send to lock it now, or type to object.`,
        spaceId: item.space_id,
        spaceTitle: title,
        type: "consensus_ready",
        itemId: item.id,
      });
    }

    // Fetch spaces with dates but no hotel cards — BATCHED (no N+1)
    const { data: spaceDates } = await supabase
      .from("spaces")
      .select("id, title, metadata")
      .in("id", spaceIds)
      .not("metadata->start_date", "is", null);

    if (spaceDates && spaceDates.length > 0) {
      const datedSpaceIds = spaceDates.map((s) => s.id);
      const { data: hotelItems } = await supabase
        .from("decision_items")
        .select("space_id")
        .in("space_id", datedSpaceIds)
        .eq("category", "hotel");

      const spacesWithHotels = new Set((hotelItems ?? []).map((i) => i.space_id));

      for (const space of spaceDates) {
        if (!spacesWithHotels.has(space.id)) {
          const dest = space.title ?? "your trip";
          whispers.push({
            id: `missing_hotel_${space.id}`,
            priority: 1,
            ghostText: `${dest} has dates but no hotels yet. hit send to search.`,
            spaceId: space.id,
            spaceTitle: space.title ?? space.id,
            type: "missing_category",
          });
        }
      }
    }

    // Fetch items with zero reactions from this user (nudge to vote)
    const { data: unvotedItems } = await supabase
      .from("decision_items")
      .select("id, title, space_id")
      .in("space_id", spaceIds)
      .eq("is_locked", false)
      .not("proposed_by", "eq", userId)
      .limit(20);

    if (unvotedItems && unvotedItems.length > 0) {
      const { data: userReactions } = await supabase
        .from("reactions")
        .select("item_id")
        .eq("user_id", userId)
        .in("item_id", unvotedItems.map((i) => i.id));

      const votedIds = new Set((userReactions ?? []).map((r) => r.item_id));
      const unvoted = unvotedItems.filter((i) => !votedIds.has(i.id));

      if (unvoted.length >= 3) {
        const space = spaces.find((s) => s.space_id === unvoted[0].space_id);
        const title = (space?.spaces as { title?: string })?.title ?? unvoted[0].space_id;
        whispers.push({
          id: `nudge_vote_${unvoted[0].space_id}`,
          priority: 2,
          ghostText: `${unvoted.length} options in ${title} need your vote. swipe to decide.`,
          spaceId: unvoted[0].space_id,
          spaceTitle: title,
          type: "nudge_vote",
        });
      }
    }
  } catch (err) {
    console.warn("[whispers] generation failed:", err);
    // Graceful degradation — return whatever we have so far
  }

  // Sort by priority (lower = higher priority)
  return whispers.sort((a, b) => a.priority - b.priority);
}
```

- [ ] **Step 2: Create the useWhispers hook**

```typescript
// src/hooks/useWhispers.ts
import { useState, useEffect, useCallback, useRef } from "react";
import { generateWhispers, type Whisper } from "@/lib/whispers";

export function useWhispers(userId: string | null) {
  const [whispers, setWhispers] = useState<Whisper[]>([]);
  const [currentWhisper, setCurrentWhisper] = useState<Whisper | null>(null);
  const fetchedRef = useRef(false);

  // Fetch whispers on mount and every 60s
  useEffect(() => {
    if (!userId) return;

    async function fetch() {
      const result = await generateWhispers(userId!);
      setWhispers(result);
      if (result.length > 0 && !fetchedRef.current) {
        setCurrentWhisper(result[0]);
      }
      fetchedRef.current = true;
    }

    fetch();
    const interval = setInterval(fetch, 60_000);
    return () => clearInterval(interval);
  }, [userId]);

  // Consume: user accepted the whisper (hit send)
  const consumeWhisper = useCallback(() => {
    setWhispers((prev) => {
      const next = prev.slice(1);
      setCurrentWhisper(next[0] ?? null);
      return next;
    });
  }, []);

  // Dismiss: user overrode (typed their own query)
  const dismissWhisper = useCallback(() => {
    setWhispers((prev) => {
      // Move current to back of queue
      if (prev.length > 1) {
        const [first, ...rest] = prev;
        const next = [...rest, first];
        setCurrentWhisper(next[0] ?? null);
        return next;
      }
      setCurrentWhisper(null);
      return [];
    });
  }, []);

  return {
    currentWhisper,
    hasWhispers: whispers.length > 0,
    consumeWhisper,
    dismissWhisper,
  };
}
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/whispers.ts src/hooks/useWhispers.ts
git commit -m "feat(whispers): proactive whisper engine — Layer 3 deterministic checks, priority queue, useWhispers hook"
```

---

## Task 6: Ghost Input Component

**Files:**
- Create: `src/components/os/GhostInput.tsx`

- [ ] **Step 1: Build the Ghost Prompt input**

The input pre-fills with ghost text (muted, italic). Typing shatters the ghost. Send accepts.

```typescript
// src/components/os/GhostInput.tsx
"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text as textTokens, ink, surface } from "@/lib/theme";

interface GhostInputProps {
  ghostText: string | null;
  onSend: (text: string, wasGhost: boolean) => void;
  onGhostDismissed?: () => void;
  autoFocus?: boolean;
}

export function GhostInput({ ghostText, onSend, onGhostDismissed, autoFocus = true }: GhostInputProps) {
  const [value, setValue] = useState("");
  const [ghostVisible, setGhostVisible] = useState(!!ghostText);
  const inputRef = useRef<HTMLInputElement>(null);

  // Reset ghost when new ghost text arrives
  useEffect(() => {
    if (ghostText) {
      setGhostVisible(true);
      setValue("");
    } else {
      setGhostVisible(false);
    }
  }, [ghostText]);

  // Autofocus on mount
  useEffect(() => {
    if (autoFocus) {
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [autoFocus]);

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const newVal = e.target.value;
      setValue(newVal);

      // First keystroke shatters the ghost
      if (ghostVisible && newVal.length > 0) {
        setGhostVisible(false);
        onGhostDismissed?.();
      }
    },
    [ghostVisible, onGhostDismissed]
  );

  const handleSubmit = useCallback(() => {
    if (ghostVisible && ghostText) {
      // Accept ghost text
      onSend(ghostText, true);
    } else if (value.trim()) {
      // Send user's own text
      onSend(value.trim(), false);
    }
    setValue("");
    setGhostVisible(false);
  }, [ghostVisible, ghostText, value, onSend]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        handleSubmit();
      }
    },
    [handleSubmit]
  );

  return (
    <div style={{ position: "relative", width: "100%" }}>
      {/* Ghost text layer — sits behind the real input */}
      <AnimatePresence>
        {ghostVisible && ghostText && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.15 } }}
            style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              paddingLeft: "16px",
              paddingRight: "48px",
              pointerEvents: "none",
              ...textTokens.input,
              opacity: 0.4,
              color: ink.tertiary,
              opacity: 0.5,
            }}
          >
            {ghostText}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Real input */}
      <input
        ref={inputRef}
        type="text"
        value={value}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        placeholder={ghostVisible ? "" : "ask xark anything..."}
        style={{
          width: "100%",
          background: "transparent",
          border: "none",
          outline: "none",
          padding: "12px 48px 12px 16px",
          ...textTokens.input,
          color: ink.primary,
          caretColor: colors.cyan,
        }}
      />

      {/* Send button */}
      <button
        onClick={handleSubmit}
        style={{
          position: "absolute",
          right: "12px",
          top: "50%",
          transform: "translateY(-50%)",
          background: "none",
          border: "none",
          padding: "8px",
          cursor: "pointer",
          opacity: (ghostVisible && ghostText) || value.trim() ? 0.9 : 0.3,
          color: colors.cyan,
          fontSize: "14px",
          fontWeight: 300,
          letterSpacing: "0.08em",
          transition: "opacity 0.2s",
        }}
      >
        send
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/os/GhostInput.tsx
git commit -m "feat(spotlight): GhostInput component — ghost text pre-fill, type to shatter, send to accept"
```

---

## Task 7: Spotlight Sheet Component

**Files:**
- Create: `src/components/os/SpotlightSheet.tsx`
- Create: `src/hooks/useSpotlight.ts`

- [ ] **Step 1: Create the useSpotlight hook**

Manages sheet state, morph animation, send-to-space routing, auto-navigation.

```typescript
// src/hooks/useSpotlight.ts
"use client";

import { useState, useCallback, useRef } from "react";
import { useRouter, usePathname } from "next/navigation";

interface SpotlightState {
  isOpen: boolean;
  morphText: string | null;  // "Scouting Tokyo sushi..." during 800ms morph
  targetSpaceId: string | null;
}

export function useSpotlight(getToken: () => string | null) {
  const [state, setState] = useState<SpotlightState>({
    isOpen: false,
    morphText: null,
    targetSpaceId: null,
  });
  const router = useRouter();
  const pathname = usePathname();
  const morphTimeoutRef = useRef<ReturnType<typeof setTimeout>>();

  const isInsideSpace = pathname?.startsWith("/space/");
  const currentSpaceId = isInsideSpace ? pathname.split("/")[2] : null;

  const open = useCallback(() => {
    setState({ isOpen: true, morphText: null, targetSpaceId: currentSpaceId });
  }, [currentSpaceId]);

  const close = useCallback(() => {
    if (morphTimeoutRef.current) clearTimeout(morphTimeoutRef.current);
    setState({ isOpen: false, morphText: null, targetSpaceId: null });
  }, []);

  const setTargetSpace = useCallback((spaceId: string) => {
    setState((prev) => ({ ...prev, targetSpaceId: spaceId }));
  }, []);

  const send = useCallback(
    async (text: string, spaceId: string, spaceTitle?: string) => {
      // 1. Morph input → breathing status pill
      const label = spaceTitle || "results";
      setState((prev) => ({
        ...prev,
        morphText: `scouting ${label.toLowerCase()}...`,
      }));

      // 2. Fire the API call (don't await — async)
      const token = getToken();
      fetch("/api/xark", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          message: `@xark ${text}`,
          spaceId,
          userId: "",  // Ignored server-side, JWT used
        }),
      }).catch(console.warn);

      // 3. Auto-dismiss after 800ms
      morphTimeoutRef.current = setTimeout(() => {
        setState({ isOpen: false, morphText: null, targetSpaceId: null });

        // 4. Context-aware landing
        if (!isInsideSpace) {
          // From Galaxy → navigate to target space
          router.push(`/space/${spaceId}`);
        }
        // From inside a space → stays where they are (sheet just closes)
      }, 800);
    },
    [isInsideSpace, router]
  );

  return {
    ...state,
    isInsideSpace,
    currentSpaceId,
    open,
    close,
    send,
    setTargetSpace,
  };
}
```

- [ ] **Step 2: Create SpotlightSheet component**

```typescript
// src/components/os/SpotlightSheet.tsx
"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text as textTokens, ink, surface, opacity, timing } from "@/lib/theme";
import { GhostInput } from "./GhostInput";
import { supabase } from "@/lib/supabase";
import type { SpaceListItem } from "@/lib/space-data";
import { fetchSpaceList } from "@/lib/space-data";

interface SpotlightSheetProps {
  isOpen: boolean;
  morphText: string | null;
  targetSpaceId: string | null;
  isInsideSpace: boolean;
  ghostText: string | null;
  ghostSpaceId: string | null;
  getToken: () => string | null;  // JWT for authenticated API calls
  onClose: () => void;
  onSend: (text: string, spaceId: string, spaceTitle?: string) => void;
  onSetTargetSpace: (spaceId: string) => void;
  onGhostAccepted: () => void;
  onGhostDismissed: () => void;
}

export function SpotlightSheet({
  isOpen,
  morphText,
  targetSpaceId,
  isInsideSpace,
  ghostText,
  ghostSpaceId,
  onClose,
  onSend,
  onSetTargetSpace,
  onGhostAccepted,
  onGhostDismissed,
}: SpotlightSheetProps) {
  const [spaces, setSpaces] = useState<SpaceListItem[]>([]);
  const [spaceTitle, setSpaceTitle] = useState<string>("");

  // Fetch spaces for Galaxy context (space chip picker)
  useEffect(() => {
    if (!isOpen || isInsideSpace) return;
    fetchSpaceList().then((list) => setSpaces(list.slice(0, 8)));
  }, [isOpen, isInsideSpace]);

  // Fetch space title for context pill
  useEffect(() => {
    if (!targetSpaceId) { setSpaceTitle(""); return; }
    const space = spaces.find((s) => s.id === targetSpaceId);
    if (space) { setSpaceTitle(space.title); return; }
    // Fallback: fetch from DB
    supabase.from("spaces").select("title").eq("id", targetSpaceId).single()
      .then(({ data }) => setSpaceTitle(data?.title ?? ""));
  }, [targetSpaceId, spaces]);

  const handleSend = (text: string, wasGhost: boolean) => {
    // For onboarding whisper (no spaceId), route to taste API
    if (wasGhost && ghostSpaceId === "") {
      const token = getToken();
      fetch("/api/taste", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ text }),
      }).catch(console.warn);
      onGhostAccepted();
      onClose();
      return;
    }

    const spaceId = wasGhost && ghostSpaceId ? ghostSpaceId : targetSpaceId;
    if (!spaceId) return;  // No space selected — need disambiguation

    if (wasGhost) onGhostAccepted();
    onSend(text, spaceId, spaceTitle);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Overlay */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: opacity.overlay }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            style={{
              position: "fixed",
              inset: 0,
              backgroundColor: colors.overlay,
              zIndex: 50,
            }}
          />

          {/* Sheet */}
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 30, stiffness: 300 }}
            style={{
              position: "fixed",
              bottom: 0,
              left: 0,
              right: 0,
              zIndex: 51,
              backgroundColor: surface.chrome,
              borderTopLeftRadius: "20px",
              borderTopRightRadius: "20px",
              maxHeight: "50vh",
              display: "flex",
              flexDirection: "column",
              paddingBottom: "env(safe-area-inset-bottom, 0px)",
            }}
          >
            {/* Handle bar */}
            <div style={{ display: "flex", justifyContent: "center", padding: "8px 0 4px" }}>
              <div style={{
                width: "36px",
                height: "4px",
                borderRadius: "2px",
                backgroundColor: ink.tertiary,
                opacity: 0.3,
              }} />
            </div>

            {/* Context pill (inside space) */}
            {isInsideSpace && targetSpaceId && spaceTitle && !morphText && (
              <div style={{ padding: "4px 16px 8px" }}>
                <span style={{
                  ...textTokens.label,
                  color: colors.cyan,
                  opacity: 0.7,
                  letterSpacing: "0.06em",
                }}>
                  {spaceTitle.toLowerCase()}
                </span>
              </div>
            )}

            {/* Space chips (Galaxy context) */}
            {!isInsideSpace && !morphText && (
              <div style={{
                display: "flex",
                gap: "8px",
                padding: "4px 16px 8px",
                overflowX: "auto",
                WebkitOverflowScrolling: "touch",
              }}>
                {spaces.map((space) => (
                  <button
                    key={space.id}
                    onClick={() => onSetTargetSpace(space.id)}
                    style={{
                      flexShrink: 0,
                      padding: "6px 14px",
                      borderRadius: "16px",
                      border: "none",
                      backgroundColor: space.id === targetSpaceId
                        ? colors.cyan
                        : surface.recessed,
                      color: space.id === targetSpaceId
                        ? colors.void
                        : ink.secondary,
                      ...textTokens.label,
                      cursor: "pointer",
                      transition: "all 0.2s",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {space.title.toLowerCase()}
                  </button>
                ))}
              </div>
            )}

            {/* Morph state — breathing status pill */}
            {morphText ? (
              <div style={{ padding: "16px", display: "flex", alignItems: "center", gap: "10px" }}>
                <motion.div
                  animate={{ opacity: [0.5, 1, 0.5] }}
                  transition={{ repeat: Infinity, duration: 1.5 }}
                  style={{
                    width: "8px",
                    height: "8px",
                    borderRadius: "50%",
                    backgroundColor: "#FF6B35",
                  }}
                />
                <span style={{
                  ...textTokens.subtitle,
                  color: ink.secondary,
                  opacity: 0.4,
                }}>
                  {morphText}
                </span>
              </div>
            ) : (
              /* Ghost Input */
              <div style={{ padding: "0 8px 8px" }}>
                <GhostInput
                  ghostText={ghostText}
                  onSend={handleSend}
                  onGhostDismissed={onGhostDismissed}
                  autoFocus
                />
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add src/components/os/SpotlightSheet.tsx src/hooks/useSpotlight.ts
git commit -m "feat(spotlight): SpotlightSheet + useSpotlight — half-sheet overlay, space chips, 800ms morph dismiss, auto-navigate"
```

---

## Task 8: Transform ControlCaret into Spotlight Anchor

**Files:**
- Modify: `src/components/os/ControlCaret.tsx`

- [ ] **Step 1: Add whisper glow and Spotlight trigger**

Key changes to ControlCaret:
1. Import `useWhispers` and `useSpotlight`
2. The "xark" text gains a cyan breathing aura when `hasWhispers` is true
3. Tap behavior changes: always opens SpotlightSheet (space panel becomes secondary, accessed via long-press or stays as-is inside the sheet)
4. Mount `SpotlightSheet` inside ControlCaret (it's already global via layout)

Add these modifications:

```typescript
// Add imports
import { SpotlightSheet } from "./SpotlightSheet";
import { useSpotlight } from "@/hooks/useSpotlight";
import { useWhispers } from "@/hooks/useWhispers";
import { useAuth } from "@/hooks/useAuth";

// Inside the component, add hooks:
const { user } = useAuth(userName);
const spotlight = useSpotlight();
const { currentWhisper, hasWhispers, consumeWhisper, dismissWhisper } = useWhispers(user?.id ?? null);

// Replace the tap handler for the "xark" text:
// OLD: onClick → if isInsideSpace → navigate to /galaxy, else → toggle panel
// NEW: onClick → open Spotlight sheet
// Long-press → toggle space panel (original behavior)
const handleAnchorTap = () => {
  if (isInsideSpace) {
    spotlight.open();
  } else {
    spotlight.open();
  }
};

// Anchor text style: add cyan aura when whispers pending
// In the "xark" text span, add conditional textShadow:
const anchorShadow = hasWhispers
  ? "0 0 12px rgba(64,224,255,0.5), 0 0 24px rgba(64,224,255,0.25)"
  : spotlight.isOpen
    ? "0 0 20px rgba(255,107,53,0.6), 0 0 40px rgba(255,107,53,0.3)"
    : "0 0 8px rgba(255,107,53,0.15)";

// Render SpotlightSheet at the end of the component, before the closing fragment:
<SpotlightSheet
  isOpen={spotlight.isOpen}
  morphText={spotlight.morphText}
  targetSpaceId={spotlight.targetSpaceId}
  isInsideSpace={spotlight.isInsideSpace}
  ghostText={currentWhisper?.ghostText ?? null}
  ghostSpaceId={currentWhisper?.spaceId ?? null}
  onClose={spotlight.close}
  onSend={spotlight.send}
  onSetTargetSpace={spotlight.setTargetSpace}
  onGhostAccepted={consumeWhisper}
  onGhostDismissed={dismissWhisper}
/>
```

- [ ] **Step 2: Preserve the space panel as long-press fallback**

The existing slide-up space panel remains accessible. Add a long-press handler (500ms) that opens the original panel. The normal tap opens SpotlightSheet. Use a `useRef` timer to distinguish tap from long-press.

- [ ] **Step 3: Commit**

```bash
git add src/components/os/ControlCaret.tsx
git commit -m "feat(spotlight): transform ControlCaret — anchor glow on whispers, tap opens Spotlight, long-press opens space panel"
```

---

## Task 9: Consensus Timer + Card Elevation

**Files:**
- Create: `src/components/os/ConsensusTimer.tsx`
- Modify: `src/components/os/DecisionCard.tsx`
- Modify: `src/components/os/PossibilityHorizon.tsx`

- [ ] **Step 1: Create ConsensusTimer component**

```typescript
// src/components/os/ConsensusTimer.tsx
"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { colors, text as textTokens } from "@/lib/theme";

interface ConsensusTimerProps {
  deadline: string;  // ISO timestamp
  onExpired?: () => void;
}

export function ConsensusTimer({ deadline, onExpired }: ConsensusTimerProps) {
  const [remaining, setRemaining] = useState("");
  const [expired, setExpired] = useState(false);

  useEffect(() => {
    function tick() {
      const diff = new Date(deadline).getTime() - Date.now();
      if (diff <= 0) {
        setRemaining("0:00");
        setExpired(true);
        onExpired?.();
        return;
      }
      const minutes = Math.floor(diff / 60000);
      const seconds = Math.floor((diff % 60000) / 1000);
      setRemaining(`${minutes}:${seconds.toString().padStart(2, "0")}`);
    }

    tick();
    const interval = setInterval(tick, 1000);
    return () => clearInterval(interval);
  }, [deadline, onExpired]);

  return (
    <motion.div
      animate={{ opacity: [0.7, 1, 0.7] }}
      transition={{ repeat: Infinity, duration: 2 }}
      style={{
        display: "flex",
        alignItems: "center",
        gap: "6px",
        ...textTokens.label,
        color: expired ? colors.green : colors.gold,
        letterSpacing: "0.08em",
      }}
    >
      <span style={{ fontSize: "10px" }}>{expired ? "\u2705" : "\uD83D\uDD12"}</span>
      <span>{expired ? "ready to finalize" : `locking in ${remaining}`}</span>
    </motion.div>
  );
}
```

- [ ] **Step 2: Modify DecisionCard for gold border + timer + finalize**

Add to DecisionCard props:
```typescript
lockDeadline?: string | null;  // ISO timestamp when countdown expires
onFinalize?: (itemId: string) => void;
```

In the card's outer container, add conditional gold border:
```typescript
const isCountdown = lockDeadline && new Date(lockDeadline) > new Date();
const isExpiredCountdown = lockDeadline && new Date(lockDeadline) <= new Date() && !isLocked;

// In the card wrapper style, add:
boxShadow: isCountdown
  ? `0 0 20px rgba(255,215,0,0.3), 0 0 40px rgba(255,215,0,0.15), inset 0 0 0 2px rgba(255,215,0,0.4)`
  : existingShadow,

// Below the reactions section, add timer/finalize:
{(isCountdown || isExpiredCountdown) && (
  <div style={{ padding: "0 16px 12px" }}>
    {isExpiredCountdown ? (
      <button
        onClick={() => onFinalize?.(id)}
        style={{
          background: "none",
          border: "none",
          ...textTokens.label,
          color: colors.green,
          cursor: "pointer",
          letterSpacing: "0.08em",
          padding: 0,
        }}
      >
        finalize
      </button>
    ) : (
      <ConsensusTimer deadline={lockDeadline!} />
    )}
  </div>
)}
```

- [ ] **Step 3: Add `lock_deadline` to DecisionItem type**

In PossibilityHorizon, update the `DecisionItem` / `DecisionCardItem` interface to include:
```typescript
lock_deadline?: string | null;
```

Also update the `.select()` query to include `lock_deadline`:
```typescript
.select("id, title, category, description, state, weighted_score, agreement_score, is_locked, locked_at, metadata, lock_deadline")
```

- [ ] **Step 4: Modify PossibilityHorizon to pass lock_deadline**

In the Realtime UPDATE handler, ensure `lock_deadline` is captured from the payload:
```typescript
// In the UPDATE handler, update the item's lock_deadline:
setItems((prev) =>
  prev.map((item) =>
    item.id === updated.id
      ? { ...item, ...updated, lock_deadline: updated.lock_deadline }
      : item
  )
);
```

In the DecisionCard render, pass the new props:
```typescript
<DecisionCard
  {...existingProps}
  lockDeadline={item.lock_deadline}
  onFinalize={handleFinalize}
/>
```

Add a `handleFinalize` function that calls `cancel_consensus_countdown` (granted to `authenticated`) then locks the specific item via the existing Green-Lock protocol:
```typescript
const handleFinalize = async (itemId: string) => {
  // cancel_consensus_countdown is granted to authenticated role
  // Then lock via existing claims protocol
  const { claimItem } = await import("@/lib/claims");
  await claimItem(itemId, userId ?? "", "consensus");
  // The Realtime subscription will pick up the is_locked change
};
```

- [ ] **Step 4: Commit**

```bash
git add src/components/os/ConsensusTimer.tsx src/components/os/DecisionCard.tsx src/components/os/PossibilityHorizon.tsx
git commit -m "feat(consensus): card gold border + live countdown timer + manual finalize button on expiry"
```

---

## Task 10: Consensus Banner

**Files:**
- Create: `src/components/os/ConsensusBanner.tsx`
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Create pinned banner component**

```typescript
// src/components/os/ConsensusBanner.tsx
"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text as textTokens, ink, surface } from "@/lib/theme";
import { supabase } from "@/lib/supabase";

interface ConsensusBannerProps {
  spaceId: string;
}

interface CountdownItem {
  id: string;
  title: string;
  lock_deadline: string;
}

export function ConsensusBanner({ spaceId }: ConsensusBannerProps) {
  const [item, setItem] = useState<CountdownItem | null>(null);

  useEffect(() => {
    // Fetch items in countdown for this space
    async function fetch() {
      const { data } = await supabase
        .from("decision_items")
        .select("id, title, lock_deadline")
        .eq("space_id", spaceId)
        .not("lock_deadline", "is", null)
        .eq("is_locked", false)
        .order("lock_deadline", { ascending: true })
        .limit(1);

      setItem(data?.[0] ?? null);
    }

    fetch();

    // Listen for Realtime changes
    const channel = supabase
      .channel(`consensus_banner:${spaceId}`)
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const updated = payload.new as Record<string, unknown>;
          if (updated.lock_deadline && !updated.is_locked) {
            setItem({
              id: updated.id as string,
              title: updated.title as string,
              lock_deadline: updated.lock_deadline as string,
            });
          } else if (updated.is_locked || !updated.lock_deadline) {
            setItem((prev) => (prev?.id === updated.id ? null : prev));
          }
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [spaceId]);

  return (
    <AnimatePresence>
      {item && (
        <motion.div
          initial={{ y: -40, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -40, opacity: 0 }}
          style={{
            position: "sticky",
            top: 0,
            zIndex: 30,
            padding: "8px 16px",
            backgroundColor: surface.chrome,
            display: "flex",
            alignItems: "center",
            gap: "8px",
          }}
        >
          <motion.div
            animate={{ opacity: [0.5, 1, 0.5] }}
            transition={{ repeat: Infinity, duration: 2 }}
            style={{
              width: "6px",
              height: "6px",
              borderRadius: "50%",
              backgroundColor: colors.gold,
            }}
          />
          <span style={{
            ...textTokens.label,
            color: ink.secondary,
            letterSpacing: "0.04em",
          }}>
            consensus on {item.title.toLowerCase()}. auto-locking soon.
          </span>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
```

- [ ] **Step 2: Mount in space page**

In `src/app/space/[id]/page.tsx`, add the banner above the chat view:

```typescript
import { ConsensusBanner } from "@/components/os/ConsensusBanner";

// In the JSX, just above XarkChat or the main content area:
<ConsensusBanner spaceId={spaceId} />
```

- [ ] **Step 3: Commit**

```bash
git add src/components/os/ConsensusBanner.tsx src/app/space/[id]/page.tsx
git commit -m "feat(consensus): pinned banner above chat when consensus countdown active"
```

---

## Task 11: Integration Wiring + Galaxy Context

**Files:**
- Modify: `src/app/galaxy/page.tsx`

- [ ] **Step 1: Pass Galaxy context to ControlCaret**

The SpotlightSheet needs to know when it's on Galaxy (for space chips). Since ControlCaret is globally mounted via layout and already reads `usePathname()`, this is already handled in `useSpotlight.ts` via `isInsideSpace`. No changes needed to Galaxy page itself.

Verify: open the app on Galaxy, tap "xark", confirm space chips appear.
Verify: open the app inside a space, tap "xark", confirm context pill appears with space title.

- [ ] **Step 2: End-to-end smoke test checklist**

Verify these flows work:

1. **Spotlight from Space**: Navigate to a space → tap "xark" → type "find sushi" → sheet morphs to "scouting..." → auto-dismisses → PossibilityHorizon receives cards via Realtime
2. **Spotlight from Galaxy**: Navigate to Galaxy → tap "xark" → space chips visible → select a space → type "find hotels" → sheet morphs → auto-navigates to space → cards appear
3. **Ghost Prompt accept**: Ensure a whisper exists (consensus or missing hotel) → tap pulsing "xark" → see ghost text → hit send → whisper consumed → action fires
4. **Ghost Prompt override**: Same setup → tap "xark" → see ghost text → start typing → ghost shatters → type own query → send → whisper moved to back of queue
5. **Consensus countdown**: React to items until agreement > 80% → verify gold border appears on card → timer counts down → banner appears above chat
6. **Consensus finalize**: Let timer expire → verify "finalize" button appears → tap → item locks
7. **Taste onboarding**: First time user → Ghost Prompt shows "tell me how you travel..." → type preferences → hit send → verify profile saved in DB
8. **Graceful degradation**: Kill Supabase connection → open Spotlight → type query → verify it still works (generic results, no crash)

- [ ] **Step 3: Final commit**

```bash
git add src/app/galaxy/page.tsx
git commit -m "feat(spotlight): integration wiring — Spotlight sheet live from Galaxy and Space, Ghost Prompt, Consensus Closer, Taste Graph"
```

---

## Dependency Graph

```
Task 1 (Cron endpoint)           ─── independent
Task 2 (Taste library)           ─── independent
Task 3 (Taste onboarding API)    ─── depends on Task 2
Task 4 (Wire taste into /api/xark) ── depends on Task 2
Task 5 (Whisper engine)          ─── independent
Task 6 (Ghost Input)             ─── independent
Task 7 (Spotlight Sheet)         ─── depends on Task 6
Task 8 (ControlCaret transform)  ─── depends on Task 5, 7
Task 9 (Consensus Timer + Card)  ─── depends on Task 1 + migration 027 applied
Task 10 (Consensus Banner)       ─── depends on migration 027 applied
Task 11 (Integration)            ─── depends on all above
```

**Parallelizable groups:**
- Group A (independent): Tasks 1, 2, 5, 6, 10
- Group B (after Group A): Tasks 3, 4, 7, 9
- Group C (after Group B): Task 8
- Group D (final): Task 11

**Estimated task count:** 11 tasks, ~35 steps total.
