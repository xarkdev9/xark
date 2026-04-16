# Night Shift #2: Make It Work + Make It Shareable — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the hello app from a visual prototype into a working product — playground voting with optimistic updates, add-item sheet, consensus celebrations, status overview, and a zero-install Web Voter View for non-app-users.

**Architecture:** PlaygroundDecisionNotifier (in-memory StateNotifier) holds decision items from seed data. Voting updates scores locally using the heart-sort algorithm. Consensus fires at 80% agreement. Web Voter View is an independent Next.js page at `/v/[code]` with its own API endpoint. Flutter and Web workstreams have zero shared files and run concurrently.

**Tech Stack:** Flutter/Dart (Riverpod 3.3.1, e2ee_chat_sdk), Next.js 16 / React 19, Supabase, Upstash Redis

**Spec:** `docs/superpowers/specs/2026-04-14-night-shift-2-make-it-work-design.md`

---

## Pre-Flight: Agent Context Protocol

Every agent MUST execute these steps before any code change:

```
1. Read this plan file completely
2. Read the spec: docs/superpowers/specs/2026-04-14-night-shift-2-make-it-work-design.md
3. Read app/lib/theme.dart (design system tokens — now brightness-aware getters)
4. Read app/CLAUDE.md (landmines, provider inventory)
5. Read CLAUDE.md root (security boundary, signal vocabulary, terminology)
6. Read nightshifttracker.md (what previous shifts completed)
7. Read EVERY file you will modify BEFORE modifying it
```

After every task:
```bash
# Flutter tasks:
cd /Users/ramchitturi/hello/app && dart analyze lib/
# Web tasks:
cd /Users/ramchitturi/hello/web && npx tsc --noEmit
```

After every task, append to `/Users/ramchitturi/hello/nightshifttracker.md`:
```markdown
## Night Shift #2 — Phase N / Task M: [title]
- **What was done:** [specific changes]
- **Why:** [which todof.md gap this closes]
- **Files changed:** [list]
- **Verification:** [command] → [result]
```

---

## WAVE A — Foundation (Phase 1 + Phase 5 concurrent)

---

## Phase 1: PlaygroundProvider + Feed Integration (Flutter)

### Task 1: Create PlaygroundDecisionNotifier

**Files:**
- Create: `app/lib/providers/playground_provider.dart`

- [ ] **Step 1: Read seed_data.dart to understand the DecisionItem shape**

Read `/Users/ramchitturi/hello/app/lib/providers/seed_data.dart`. Find `mockDecisions` (starts around line 116). Note the DecisionItem fields: `id`, `groupId`, `ciphertextPayload`, `nonce`, `state`, `weightedScore`, `agreementScore`, `reactions` (Map<String, String>), `isLocked`.

- [ ] **Step 2: Read the DecisionItem model**

Read `/Users/ramchitturi/hello/engine/lib/src/domain/models/decision_item.dart`. It's a freezed class with `copyWith`. Key fields:
- `reactions`: `Map<String, String>` — maps userId → signal ('love_it', 'works_for_me', 'not_for_me')
- `agreementScore`: double (0.0 to 1.0)
- `weightedScore`: double
- `state`: String ('proposed', 'ranked', 'locked')
- `isLocked`: bool

- [ ] **Step 3: Write playground_provider.dart**

Create `/Users/ramchitturi/hello/app/lib/providers/playground_provider.dart`:

```dart
import 'dart:async';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'seed_data.dart';

const int _playgroundGroupSize = 6;

class PlaygroundDecisionNotifier extends StateNotifier<List<DecisionItem>> {
  PlaygroundDecisionNotifier() : super(List<DecisionItem>.from(mockDecisions));

  final _consensusController = StreamController<String>.broadcast();

  Stream<String> get consensusEvents => _consensusController.stream;

  void vote(String itemId, String signal, String userId) {
    final items = [...state];
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;

    final item = items[idx];
    final reactions = Map<String, String>.from(item.reactions);
    reactions[userId] = signal;

    double weightedScore = 0;
    for (final r in reactions.values) {
      weightedScore += switch (r) {
        'love_it' => 5,
        'works_for_me' => 1,
        'not_for_me' => -3,
        _ => 0,
      };
    }

    final agreementScore = reactions.length / _playgroundGroupSize;
    final newState = agreementScore >= 0.8 ? 'locked' : item.state;
    final wasLocked = item.state == 'locked';

    items[idx] = item.copyWith(
      reactions: reactions,
      weightedScore: weightedScore,
      agreementScore: agreementScore.clamp(0.0, 1.0),
      state: newState,
      isLocked: newState == 'locked',
    );

    items.sort((a, b) {
      if (a.state == 'locked' && b.state != 'locked') return 1;
      if (b.state == 'locked' && a.state != 'locked') return -1;
      return b.weightedScore.compareTo(a.weightedScore);
    });

    state = items;

    if (!wasLocked && newState == 'locked') {
      _consensusController.add(itemId);
    }
  }

  void addItem(String title, String category, String photoUrl) {
    final id = 'pg_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = DecisionItem(
      id: id,
      groupId: 'swiss_jun_2026',
      ciphertextPayload: title,
      nonce: category,
      state: 'proposed',
      weightedScore: 0,
      agreementScore: 0,
      reactions: const {},
      proposedBy: 'me',
    );
    state = [newItem, ...state];
  }

  @override
  void dispose() {
    _consensusController.close();
    super.dispose();
  }
}

final playgroundDecisionsProvider =
    StateNotifierProvider<PlaygroundDecisionNotifier, List<DecisionItem>>(
  (ref) => PlaygroundDecisionNotifier(),
);

final playgroundConsensusEventProvider = StreamProvider<String>((ref) {
  final notifier = ref.watch(playgroundDecisionsProvider.notifier);
  return notifier.consensusEvents;
});
```

- [ ] **Step 4: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/providers/playground_provider.dart
```

- [ ] **Step 5: Update nightshifttracker.md**

---

### Task 2: Integrate playground into decisions_provider.dart

**Files:**
- Modify: `app/lib/providers/decisions_provider.dart`

- [ ] **Step 1: Read decisions_provider.dart**

Read `/Users/ramchitturi/hello/app/lib/providers/decisions_provider.dart`. The `activeDecisionsProvider` currently returns empty when engine is null (line 22).

- [ ] **Step 2: Add playground fallback**

Add import at top:
```dart
import 'playground_provider.dart';
```

Change the `activeDecisionsProvider` body. After the existing `if (engine is! ChatEngineDecisions)` block (which returns empty list), replace the empty list with a playground read:

Find:
```dart
  if (engine is! ChatEngineDecisions) {
    return const <DecisionItem>[];
  }
```

Replace with:
```dart
  if (engine is! ChatEngineDecisions) {
    // Playground mode — return in-memory decisions for demo
    return ref.watch(playgroundDecisionsProvider);
  }
```

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

---

### Task 3: Verify feed integration

**Files:**
- Read (no modify): `app/lib/providers/feed_provider.dart`

- [ ] **Step 1: Read feed_provider.dart**

Read `/Users/ramchitturi/hello/app/lib/providers/feed_provider.dart`. Verify that it watches `activeDecisionsProvider` and maps `DecisionItem` to `DecisionHeroFeedItem`/`DecisionSmallFeedItem` using the `mockDecisionHero` and `mockDecisionSmall` maps from seed_data.dart.

- [ ] **Step 2: Verify the seed data IDs match**

Read `/Users/ramchitturi/hello/app/lib/providers/seed_data.dart` and check that `mockDecisions` item IDs appear as keys in `mockDecisionHero` and `mockDecisionSmall` maps. If they match, no code changes needed — playground decisions will flow through the feed automatically.

If there's a mismatch (items in mockDecisions whose IDs don't appear in the hero/small maps), they'll fall through to the fallback title `d.id.substring(0, 8)`. This is acceptable.

- [ ] **Step 3: Document in nightshifttracker.md**

Log: "Feed integration verified — playground decisions flow through activeDecisionsProvider → feed_provider mapping automatically. No code changes needed."

---

## Phase 5: Web Voter View (Web/Next.js) — runs concurrently with Phase 1

### Task 4: Create vote API endpoint

**Files:**
- Create: `web/src/app/api/vote/route.ts`

- [ ] **Step 1: Read the invite system**

Read `/Users/ramchitturi/hello/web/src/app/api/invite/route.ts` to understand the invite code pattern. Codes are 128-bit hex stored in `summon_links` table with `code` and `creator_id` columns.

Read `/Users/ramchitturi/hello/web/src/lib/supabase-admin.ts` to understand the admin client import.

- [ ] **Step 2: Check if a reactions table exists**

```bash
cd /Users/ramchitturi/hello && grep -rn 'reactions' engine/lib/src/persistence/ | head -10
cd /Users/ramchitturi/hello && grep -rn 'react' web/src/lib/ | grep -i 'table\|from\|insert\|upsert' | head -10
```

The agent must determine the actual table name and schema for storing reactions. If a `reactions` table doesn't exist, the agent should use the `decision_items` table's `reactions` JSONB column directly (since `DecisionItem.reactions` is a `Map<String, String>`). Adapt the API accordingly — either upsert into a dedicated reactions table OR update the `reactions` JSON field on the `decision_items` row.

- [ ] **Step 3: Write the vote API endpoint**

Create `/Users/ramchitturi/hello/web/src/app/api/vote/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { inviteCode, itemId, signal, voterName } = body;

  if (!inviteCode || !itemId || !signal || !voterName) {
    return NextResponse.json({ error: "missing fields" }, { status: 400 });
  }

  if (!["love_it", "works_for_me", "not_for_me"].includes(signal)) {
    return NextResponse.json({ error: "invalid signal" }, { status: 400 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  // Validate invite code
  const { data: invite, error: invErr } = await supabaseAdmin
    .from("summon_links")
    .select("creator_id")
    .eq("code", inviteCode)
    .maybeSingle();

  if (invErr || !invite) {
    return NextResponse.json({ error: "invalid invite" }, { status: 404 });
  }

  // Build guest user ID from voter name
  const guestId = `guest_${voterName.toLowerCase().replace(/\s+/g, '_')}`;

  // Read current reactions from the decision item
  const { data: item, error: itemErr } = await supabaseAdmin
    .from("decision_items")
    .select("reactions")
    .eq("id", itemId)
    .maybeSingle();

  if (itemErr || !item) {
    return NextResponse.json({ error: "item not found" }, { status: 404 });
  }

  // Upsert the reaction (one per user, last wins)
  const reactions = { ...(item.reactions || {}), [guestId]: signal };

  const { error: updateErr } = await supabaseAdmin
    .from("decision_items")
    .update({ reactions })
    .eq("id", itemId);

  if (updateErr) {
    console.error("[vote] update failed:", updateErr.message);
    return NextResponse.json({ error: "vote failed" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, guestId, signal });
}
```

Note: If the Supabase schema uses a separate `reactions` table instead of a JSON column on `decision_items`, the agent must adapt the query. Read the actual schema first.

- [ ] **Step 4: Run type check**

```bash
cd /Users/ramchitturi/hello/web && npx tsc --noEmit
```

- [ ] **Step 5: Update nightshifttracker.md**

---

### Task 5: Add rate limiting for /api/vote

**Files:**
- Modify: `web/src/lib/rate-limit-edge.ts`

- [ ] **Step 1: Read rate-limit-edge.ts**

Read `/Users/ramchitturi/hello/web/src/lib/rate-limit-edge.ts`. Find the `buildRouteConfig()` function (starts around line 71). Understand the pattern: each route gets a limiter + prefix + failureMode.

- [ ] **Step 2: Add vote limiter**

In `buildRouteConfig()`, after the existing limiters are created (around line 84), add:

```typescript
const voteLimiter = slidingWindow('rl:vote', 30, '1 m');
```

Add to the null check (line 87-88).

After the existing `config.set(...)` calls, add:

```typescript
config.set('/api/vote', {
  limiter: voteLimiter!, prefix: 'rl:vote', keyByIp: true, failureMode: 'open',
});
```

- [ ] **Step 3: Run type check**

```bash
cd /Users/ramchitturi/hello/web && npx tsc --noEmit
```

- [ ] **Step 4: Update nightshifttracker.md**

---

### Task 6: Create the Web Voter View page

**Files:**
- Create: `web/src/app/v/[code]/page.tsx`
- Create: `web/src/app/v/[code]/vote-header.tsx`
- Create: `web/src/app/v/[code]/vote-card.tsx`

- [ ] **Step 1: Read existing patterns**

Read `/Users/ramchitturi/hello/web/src/app/layout.tsx` to understand the root layout (fonts, metadata).
Read `/Users/ramchitturi/hello/web/src/app/globals.css` to understand the CSS tokens available.
Read `/Users/ramchitturi/hello/web/src/app/api/invite/validate/route.ts` (if it exists) to understand how invite validation works.

- [ ] **Step 2: Write vote-header.tsx**

Create `/Users/ramchitturi/hello/web/src/app/v/[code]/vote-header.tsx`:

```tsx
"use client";

import { useState, useEffect } from "react";

export function VoteHeader({ tripName, memberCount }: { tripName: string; memberCount: number }) {
  const [voterName, setVoterName] = useState("");

  useEffect(() => {
    const saved = localStorage.getItem("hello_voter_name");
    if (saved) setVoterName(saved);
  }, []);

  const handleNameChange = (name: string) => {
    setVoterName(name);
    localStorage.setItem("hello_voter_name", name);
  };

  return (
    <header
      style={{
        padding: "24px 16px 16px",
        backdropFilter: "blur(14px)",
        WebkitBackdropFilter: "blur(14px)",
        backgroundColor: "rgba(255,255,255,0.7)",
        borderBottom: "1px solid rgba(0,0,0,0.06)",
        position: "sticky",
        top: 0,
        zIndex: 10,
      }}
    >
      <h1 style={{ fontFamily: "Inter, sans-serif", fontSize: 28, fontWeight: 400, letterSpacing: "-0.02em", color: "var(--hello-white)", margin: 0 }}>
        {tripName}
      </h1>
      <p style={{ fontFamily: "Inter, sans-serif", fontSize: 13, fontWeight: 300, color: "var(--hello-ink-secondary)", marginTop: 4 }}>
        {memberCount} members
      </p>
      <div style={{ marginTop: 12 }}>
        <input
          type="text"
          placeholder="What's your name?"
          value={voterName}
          onChange={e => handleNameChange(e.target.value)}
          style={{
            width: "100%",
            padding: "10px 16px",
            borderRadius: 20,
            border: "1px solid rgba(0,0,0,0.1)",
            background: "var(--hello-surface-recessed)",
            fontFamily: "Inter, sans-serif",
            fontSize: 15,
            fontWeight: 400,
            color: "var(--hello-white)",
            outline: "none",
          }}
        />
      </div>
    </header>
  );
}
```

- [ ] **Step 3: Write vote-card.tsx**

Create `/Users/ramchitturi/hello/web/src/app/v/[code]/vote-card.tsx`:

```tsx
"use client";

import { useState, useEffect } from "react";

interface DecisionItemData {
  id: string;
  title: string;
  category: string;
  photoUrl?: string;
  agreementScore: number;
  reactions: Record<string, string>;
}

const SIGNALS = [
  { key: "love_it", label: "Love It", color: "var(--hello-amber)" },
  { key: "works_for_me", label: "Works", color: "var(--hello-gray)" },
  { key: "not_for_me", label: "Pass", color: "var(--hello-orange)" },
] as const;

export function VoteCard({ item, inviteCode }: { item: DecisionItemData; inviteCode: string }) {
  const [myVote, setMyVote] = useState<string | null>(null);
  const [score, setScore] = useState(item.agreementScore);
  const [isVoting, setIsVoting] = useState(false);

  // Restore vote from localStorage
  useEffect(() => {
    const saved = localStorage.getItem(`vote_${item.id}`);
    if (saved) setMyVote(saved);
  }, [item.id]);

  const handleVote = async (signal: string) => {
    const voterName = localStorage.getItem("hello_voter_name");
    if (!voterName) {
      alert("Please enter your name first");
      return;
    }

    // Optimistic update
    setMyVote(signal);
    localStorage.setItem(`vote_${item.id}`, signal);
    setIsVoting(true);

    try {
      const res = await fetch("/api/vote", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ inviteCode, itemId: item.id, signal, voterName }),
      });
      if (!res.ok) {
        console.error("Vote failed:", await res.text());
      }
    } catch (err) {
      console.error("Vote error:", err);
    } finally {
      setIsVoting(false);
    }
  };

  const pct = Math.round(score * 100);

  return (
    <div
      style={{
        borderRadius: 20,
        overflow: "hidden",
        backdropFilter: "blur(14px)",
        WebkitBackdropFilter: "blur(14px)",
        backgroundColor: "rgba(255,255,255,0.7)",
        border: "1px solid rgba(0,0,0,0.06)",
      }}
    >
      {item.photoUrl && (
        <div style={{ width: "100%", height: 180, position: "relative", overflow: "hidden" }}>
          <img
            src={item.photoUrl}
            alt={item.title}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </div>
      )}
      <div style={{ padding: 16 }}>
        <p style={{ fontFamily: "Inter, sans-serif", fontSize: 10, fontWeight: 400, letterSpacing: "0.1em", color: "var(--hello-ink-tertiary)", textTransform: "uppercase", margin: 0 }}>
          {item.category}
        </p>
        <h3 style={{ fontFamily: "Inter, sans-serif", fontSize: 22, fontWeight: 400, letterSpacing: "-0.01em", color: "var(--hello-white)", margin: "4px 0 12px" }}>
          {item.title}
        </h3>

        {/* Progress bar */}
        <div style={{ height: 4, borderRadius: 2, background: "var(--hello-surface-recessed)", marginBottom: 12 }}>
          <div
            style={{
              height: "100%",
              borderRadius: 2,
              width: `${pct}%`,
              background: pct >= 80 ? "var(--hello-gold)" : "var(--hello-accent)",
              transition: "width 300ms ease",
            }}
          />
        </div>
        <p style={{ fontFamily: "Inter, sans-serif", fontSize: 13, fontWeight: 300, color: "var(--hello-ink-secondary)", margin: "0 0 12px" }}>
          {pct}% agreement
        </p>

        {/* Vote buttons */}
        <div style={{ display: "flex", gap: 8 }}>
          {SIGNALS.map(({ key, label, color }) => {
            const isActive = myVote === key;
            return (
              <button
                key={key}
                onClick={() => handleVote(key)}
                disabled={isVoting}
                style={{
                  flex: 1,
                  padding: "10px 0",
                  borderRadius: 12,
                  border: isActive ? `2px solid ${color}` : "1px solid rgba(0,0,0,0.08)",
                  background: isActive ? `${color}15` : "transparent",
                  color: isActive ? color : "var(--hello-ink-secondary)",
                  fontFamily: "Inter, sans-serif",
                  fontSize: 13,
                  fontWeight: 400,
                  cursor: "pointer",
                  transition: "all 200ms ease",
                }}
              >
                {label}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Write the main vote page**

Create `/Users/ramchitturi/hello/web/src/app/v/[code]/page.tsx`:

```tsx
import { supabaseAdmin } from "@/lib/supabase-admin";
import { VoteHeader } from "./vote-header";
import { VoteCard } from "./vote-card";

// Demo/fallback data for when Supabase is not configured
const DEMO_ITEMS = [
  { id: "demo_1", title: "The Dolder Grand", category: "Hotels", photoUrl: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600", agreementScore: 0.67, reactions: { sarah: "love_it", alex: "works_for_me", maya: "love_it", liam: "not_for_me" } },
  { id: "demo_2", title: "United 827 — JFK→ZRH", category: "Flights", agreementScore: 0.5, reactions: { sarah: "works_for_me", alex: "love_it", maya: "works_for_me" } },
  { id: "demo_3", title: "Fondue Tour Gruyères", category: "Activities", photoUrl: "https://images.unsplash.com/photo-1529699211952-734e80c4d42b?w=600", agreementScore: 0.33, reactions: { sarah: "love_it", alex: "not_for_me" } },
];

async function getInviteData(code: string) {
  if (!supabaseAdmin) return null;

  const { data: invite } = await supabaseAdmin
    .from("summon_links")
    .select("creator_id, space_id")
    .eq("code", code)
    .maybeSingle();

  if (!invite) return null;

  // Fetch group info
  const { data: space } = await supabaseAdmin
    .from("spaces")
    .select("title, id")
    .eq("id", invite.space_id)
    .maybeSingle();

  // Fetch decision items for this group
  const { data: items } = await supabaseAdmin
    .from("decision_items")
    .select("id, ciphertext_payload, nonce, state, weighted_score, agreement_score, reactions")
    .eq("group_id", invite.space_id)
    .neq("state", "archived")
    .order("weighted_score", { ascending: false });

  return {
    groupName: space?.title || "Trip",
    groupId: invite.space_id,
    items: (items || []).map((i: any) => ({
      id: i.id,
      title: i.ciphertext_payload || i.id.substring(0, 12),
      category: i.nonce || "Item",
      agreementScore: i.agreement_score || 0,
      reactions: i.reactions || {},
    })),
  };
}

export default async function VotePage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;

  const data = await getInviteData(code);

  // If Supabase is not configured or invite is invalid, show demo
  const tripName = data?.groupName || "Swiss Alps Trip";
  const items = data?.items?.length ? data.items : DEMO_ITEMS;

  return (
    <main style={{ minHeight: "100vh", background: "#FAFAFA", fontFamily: "Inter, sans-serif" }}>
      <VoteHeader tripName={tripName} memberCount={6} />
      <div style={{ padding: "16px", display: "flex", flexDirection: "column", gap: 16, paddingBottom: 80 }}>
        {items.map((item: any) => (
          <VoteCard key={item.id} item={item} inviteCode={code} />
        ))}
      </div>
      {/* Conversion banner */}
      <div
        style={{
          position: "fixed",
          bottom: 0,
          left: 0,
          right: 0,
          padding: "12px 16px",
          backdropFilter: "blur(14px)",
          WebkitBackdropFilter: "blur(14px)",
          backgroundColor: "rgba(255,255,255,0.9)",
          borderTop: "1px solid rgba(0,0,0,0.06)",
          textAlign: "center",
        }}
      >
        <p style={{ fontSize: 13, fontWeight: 400, color: "#6B6B78", margin: 0 }}>
          Want the full trip experience?{" "}
          <a href="https://gethello.ai" style={{ color: "#FF4D00", textDecoration: "none", fontWeight: 400 }}>
            Get hello →
          </a>
        </p>
      </div>
    </main>
  );
}
```

Note: The Supabase column names may use snake_case (`ciphertext_payload`, `agreement_score`) while the TypeScript model uses camelCase. The agent must verify the actual column names. The demo fallback data ensures the page works even without Supabase configured.

- [ ] **Step 5: Run build**

```bash
cd /Users/ramchitturi/hello/web && npm run build
```

- [ ] **Step 6: Update nightshifttracker.md**

---

## WAVE A GATE

Both Phase 1 (Flutter) and Phase 5 (Web) agents must complete. Then:

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
cd /Users/ramchitturi/hello/web && npx tsc --noEmit
```

---

## WAVE B — Vote Wiring + Add Item (Phase 2 + Phase 3, sequential)

### Task 7: Wire decision_card_small.dart to playground provider

**Files:**
- Modify: `app/lib/views/home/decision_board/cards/decision_card_small.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/cards/decision_card_small.dart`. Find:
- The `_myVote` state variable
- The vote button `onTap` callbacks that call `setState`
- The agreement score display that reads from `widget.item`

- [ ] **Step 2: Add playground provider import**

Add at top:
```dart
import '../../../../providers/playground_provider.dart';
```

- [ ] **Step 3: Remove local _myVote state**

Delete the `String? _myVote` declaration and all `setState(() => _myVote = ...)` calls.

- [ ] **Step 4: Derive vote state from the provider**

In `build()`, read the current user's vote from the playground provider:

```dart
final decisions = ref.watch(playgroundDecisionsProvider);
final liveItem = decisions.firstWhere(
  (d) => d.id == widget.item.item?.id,
  orElse: () => widget.item.item!,
);
final myVote = liveItem.reactions['me'];
final scorePct = (liveItem.agreementScore * 100).round();
```

Use `myVote` to determine which button is highlighted. Use `scorePct` for the progress bar and percentage text.

- [ ] **Step 5: Wire vote button taps to provider**

Replace each vote button's `onTap` with:

```dart
onTap: () {
  HelloHaptic.tap();
  ref.read(playgroundDecisionsProvider.notifier).vote(
    widget.item.item!.id,
    'love_it',  // or 'works_for_me' or 'not_for_me'
    'me',
  );
},
```

- [ ] **Step 6: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 7: Update nightshifttracker.md**

---

### Task 8: Wire decision_page.dart to playground provider

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/decision_page.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/pages/decision_page.dart`. Find the `_vote` state variable and vote button callbacks.

- [ ] **Step 2: Apply same pattern as Task 7**

Add playground provider import. Remove local `_vote`. Derive vote state from `playgroundDecisionsProvider`. Wire vote taps to `ref.read(playgroundDecisionsProvider.notifier).vote(...)`. Use live `agreementScore` for the progress bar.

The item ID extraction depends on how the page receives its data — read the file to determine whether it gets a `FeedItem` or a `DecisionItem` directly.

- [ ] **Step 3: Run dart analyze**

- [ ] **Step 4: Update nightshifttracker.md**

---

### Task 9: Wire decision_sheet.dart to playground provider

**Files:**
- Modify: `app/lib/views/home/decision_board/sheets/decision_sheet.dart`

Same pattern as Tasks 7 and 8. Read the file, remove local vote state, wire to provider.

- [ ] **Step 1-4: Read, wire, analyze, track** (same pattern)

---

### Task 10: Create Add Item Sheet

**Files:**
- Create: `app/lib/views/home/decision_board/sheets/add_item_sheet.dart`

- [ ] **Step 1: Read Gen 3 reference**

Read `/Users/ramchitturi/hello/ui_backup_2026-04-10/flutter/demov2/add_item_sheet.dart` for the existing pattern.

- [ ] **Step 2: List available demo assets**

```bash
ls /Users/ramchitturi/hello/app/assets/decide/
```

- [ ] **Step 3: Write add_item_sheet.dart**

Create `/Users/ramchitturi/hello/app/lib/views/home/decision_board/sheets/add_item_sheet.dart`:

The sheet must:
- Use `showGeneralDialog` (match existing sheet patterns — read `dm_sheet.dart` for the dialog wrapper pattern)
- Have a title `TextField` and a category `TextField`
- Display 6 asset images from `assets/decide/` in a horizontal `ListView`
- Selected image gets a `PlasmaStroke` border
- Submit button: `PlasmaFill` pill, validates non-empty fields, calls `ref.read(playgroundDecisionsProvider.notifier).addItem(title, category, photoUrl)`, calls `HelloHaptic.confirm()`, pops the dialog
- Export a top-level function: `void openAddItemSheet(BuildContext context)`

The sheet must be a `ConsumerStatefulWidget` to access `ref`.

- [ ] **Step 4: Run dart analyze**

- [ ] **Step 5: Update nightshifttracker.md**

---

### Task 11: Add [+] button to PlansView and GroupPage

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/plans_view.dart`
- Modify: `app/lib/views/home/decision_board/pages/group_page.dart`

- [ ] **Step 1: Read both files**

- [ ] **Step 2: Add floating [+] button to plans_view.dart**

In the `Stack` of `PlansView.build()`, add a `Positioned` at `bottom: 20, right: 20`:

```dart
Positioned(
  bottom: 20,
  right: 20,
  child: GestureDetector(
    onTap: () {
      HelloHaptic.tap();
      openAddItemSheet(context);
    },
    child: PlasmaFill(
      shape: BoxShape.circle,
      width: 48,
      height: 48,
      child: Icon(Icons.add_rounded, size: 24, color: Colors.white),
    ),
  ),
),
```

Add import for `add_item_sheet.dart` and `haptics.dart`.

- [ ] **Step 3: Add [+] button to group_page.dart**

Same pattern — add a floating [+] button that's visible when on the Plans page of the dual-pane swipe. Read the file to find the appropriate location (likely inside the `_buildPlansContent` method or equivalent).

- [ ] **Step 4: Run dart analyze**

- [ ] **Step 5: Update nightshifttracker.md**

---

## WAVE C — Consensus + PlansView Migration (Phase 4 + Phase 6, sequential)

### Task 12: Create ConsensusWatcher and wire to scaffold

**Files:**
- Create: `app/lib/views/home/decision_board/consensus_watcher.dart`
- Modify: `app/lib/views/home/decision_board/decision_board_page.dart`

- [ ] **Step 1: Read consensus_banner.dart**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/consensus_banner.dart`. Understand its API — what props it takes, how `isVisible` triggers the slide animation.

- [ ] **Step 2: Write consensus_watcher.dart**

Create `/Users/ramchitturi/hello/app/lib/views/home/decision_board/consensus_watcher.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/playground_provider.dart';
import '../../../utils/haptics.dart';
import 'consensus_banner.dart';

class ConsensusWatcher extends ConsumerStatefulWidget {
  const ConsensusWatcher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ConsensusWatcher> createState() => _ConsensusWatcherState();
}

class _ConsensusWatcherState extends ConsumerState<ConsensusWatcher> {
  String? _celebratingTitle;

  @override
  void initState() {
    super.initState();
    // Listen for consensus events from the playground provider
    ref.listenManual(playgroundConsensusEventProvider, (_, asyncValue) {
      asyncValue.whenData((itemId) {
        final items = ref.read(playgroundDecisionsProvider);
        final item = items.where((i) => i.id == itemId).firstOrNull;
        if (item == null) return;

        HelloHaptic.celebrate();
        setState(() {
          _celebratingTitle = item.ciphertextPayload; // title stored in ciphertextPayload for playground
        });

        // Auto-dismiss after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _celebratingTitle = null);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_celebratingTitle != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: ConsensusBanner(
              isVisible: true,
              title: _celebratingTitle!,
            ),
          ),
      ],
    );
  }
}
```

Note: The `ConsensusBanner` API may differ from what's shown above. The agent must read `consensus_banner.dart` first and match its actual constructor signature. If `ConsensusBanner` takes different props (e.g., `itemTitle` instead of `title`), adapt accordingly.

- [ ] **Step 3: Wire into decision_board_page.dart**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/decision_board_page.dart`. Wrap the main `Scaffold` body (or the `Stack` containing the tab content) with `ConsensusWatcher`:

```dart
// Before:
return Scaffold(body: Stack(children: [...]));

// After:
return ConsensusWatcher(
  child: Scaffold(body: Stack(children: [...])),
);
```

Add import for `consensus_watcher.dart`.

- [ ] **Step 4: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 5: Update nightshifttracker.md**

---

### Task 13: Migrate PlansView from MockPlanItem to DecisionItem

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/plans_view.dart`

- [ ] **Step 1: Read plans_view.dart thoroughly**

Read the entire file. Identify:
- `MockPlanItem` class definition
- `_getMockItems()` function
- All references to `MockPlanItem` fields (`title`, `category`, `photoUrl`, `agreementScore`, `isLocked`, `votedCount`, `totalCount`)
- The 3-tier navigation logic (events → categories → items)

- [ ] **Step 2: Convert to ConsumerStatefulWidget**

If not already a `ConsumerStatefulWidget`, convert the class declaration and state class.

- [ ] **Step 3: Replace MockPlanItem with DecisionItem**

Replace `_getMockItems()` with a provider read:

```dart
final items = ref.watch(playgroundDecisionsProvider);
```

Map `DecisionItem` fields to the UI:
- `item.ciphertextPayload` → title (in playground mode, title is stored here)
- `item.nonce` → category (in playground mode, category is stored here)
- `item.agreementScore` → score
- `item.isLocked` → locked state
- `item.reactions.length` → votedCount
- `_playgroundGroupSize` (6) → totalCount

The 3-tier navigation (events → categories) currently derives categories from MockPlanItem. Update to derive from `DecisionItem.nonce` (which stores category in playground mode).

- [ ] **Step 4: Delete MockPlanItem class and _getMockItems()**

Remove the `MockPlanItem` class definition and the `_getMockItems()` function entirely.

Also check if `MockPlanItem` is imported by any other file:
```bash
grep -rn 'MockPlanItem' /Users/ramchitturi/hello/app/lib/
```

If other files import it (e.g., `decision_card.dart`), update those imports too.

- [ ] **Step 5: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 6: Update nightshifttracker.md**

---

## WAVE D — Status Overview + Final (Phase 7 + Phase 8, sequential)

### Task 14: Create StatusOverview widget

**Files:**
- Create: `app/lib/views/home/decision_board/status_overview.dart`

- [ ] **Step 1: Write status_overview.dart**

Create `/Users/ramchitturi/hello/app/lib/views/home/decision_board/status_overview.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/playground_provider.dart';
import '../../../theme.dart';
import '../../../utils/haptics.dart';
import 'plasma/plasma.dart';

class StatusOverview extends ConsumerWidget {
  const StatusOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(playgroundDecisionsProvider);

    final locked = items.where((i) => i.state == 'locked').length;
    final voting = items.where((i) => i.state != 'locked').length;
    final needsYou = items.where((i) => !i.reactions.containsKey('me')).length;

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _StatusChip(
            icon: Icons.check_circle_outline,
            iconColor: HelloColors.liveGreen,
            count: locked,
            label: 'Locked',
          ),
          SizedBox(width: 8),
          _StatusChip(
            icon: Icons.how_to_vote_outlined,
            iconColor: HelloColors.accent,
            count: voting,
            label: 'Voting',
            usePlasma: true,
          ),
          SizedBox(width: 8),
          _StatusChip(
            icon: Icons.person_outline,
            iconColor: HelloColors.accent,
            count: needsYou,
            label: 'Needs You',
          ),
          SizedBox(width: 8),
          _StatusChip(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: HelloColors.gold,
            count: 0,
            label: 'Settled',
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
    this.usePlasma = false,
  });

  final IconData icon;
  final Color iconColor;
  final int count;
  final String label;
  final bool usePlasma;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: HelloGlass.whisperFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HelloGlass.whisperBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          SizedBox(width: 6),
          Text(
            '$count',
            style: HelloText.small.copyWith(
              color: HelloColors.inkPrimary,
            ),
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: HelloText.caption,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 3: Update nightshifttracker.md**

---

### Task 15: Wire StatusOverview into home_page.dart

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart`

- [ ] **Step 1: Read home_page.dart**

Read the file. Find where the main content is built — the dock, the spotlight hero, or the feed grid.

- [ ] **Step 2: Add StatusOverview above the main content**

Add import:
```dart
import '../status_overview.dart';
```

Insert `StatusOverview()` widget above the main feed content. The exact placement depends on the file structure — it should sit between the top safe area and the feed/dock content.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

---

### Task 16: Final verification

- [ ] **Step 1: Run Flutter analysis**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 2: Run Flutter web build**

```bash
cd /Users/ramchitturi/hello/app && flutter build web --no-tree-shake-icons --no-wasm-dry-run
```

- [ ] **Step 3: Run Web build**

```bash
cd /Users/ramchitturi/hello/web && npm run build
```

- [ ] **Step 4: Update nightshifttracker.md with Night Shift #2 summary**

Append a "NIGHT SHIFT #2 COMPLETE" section listing:
- Total tasks completed
- New files created (9)
- Files modified (~10)
- Key features delivered: playground voting, add item, consensus celebration, status overview, web voter view

---

## Plan Summary

| Wave | Phases | Tasks | Parallelism |
|------|--------|-------|-------------|
| A | 1 (Flutter) + 5 (Web) | 1-6 | 2 concurrent agents |
| B | 2 + 3 | 7-11 | Sequential |
| C | 4 + 6 | 12-13 | Sequential |
| D | 7 + 8 | 14-16 | Sequential |

**Total: 16 tasks across 4 waves.**
