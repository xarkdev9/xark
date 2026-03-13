# Decide View Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Decide view (PossibilityHorizon) into Netflix-style category sections with horizontal card bands, conviction strips, self-resolving settled rows, and a shared @xark input zone.

**Architecture:** Vertically scrolling page of horizontal card bands grouped by `category`. Single Supabase query + client-side grouping (memoized). Batch reaction fetch. Single Realtime channel. Locked categories collapse to settled rows. Shared bottom InputZone posts to `/api/xark`.

**Tech Stack:** React 19, Framer Motion, Supabase Realtime, theme.ts tokens, useReactions hook, useVoiceInput hook.

**Spec:** `docs/superpowers/specs/2026-03-13-decide-view-redesign.md`

---

## Chunk 1: Data Layer

### Task 1: Add batch reaction fetch to useReactions hook

**Files:**
- Modify: `src/hooks/useReactions.ts`

- [ ] **Step 1: Add `batchGetUserReactions` to the hook**

Add a new method that fetches all reactions for a list of item IDs in one query. Add it to the interface and return value.

```typescript
// Add to UseReactionsResult interface (after line 18):
batchGetUserReactions: (
  itemIds: string[],
  userId: string
) => Promise<Record<string, ReactionType>>;

// Add implementation inside useReactions() (after getUserReaction):
const batchGetUserReactions = useCallback(
  async (
    itemIds: string[],
    userId: string
  ): Promise<Record<string, ReactionType>> => {
    if (itemIds.length === 0) return {};
    try {
      const { data } = await supabase
        .from("reactions")
        .select("item_id, signal")
        .eq("user_id", userId)
        .in("item_id", itemIds);

      const result: Record<string, ReactionType> = {};
      if (data) {
        for (const row of data) {
          result[row.item_id] = row.signal as ReactionType;
        }
      }
      return result;
    } catch {
      return {};
    }
  },
  []
);

// Update return (line 71):
return { react, unreact, getUserReaction, batchGetUserReactions, isReacting };
```

- [ ] **Step 2: Verify types compile**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/hooks/useReactions.ts
git commit -m "feat: add batchGetUserReactions to useReactions hook"
```

---

## Chunk 2: PossibilityHorizon Rewrite — Orchestrator + CategorySection + DecisionCard

### Task 2: Rewrite PossibilityHorizon.tsx

**Files:**
- Rewrite: `src/components/os/PossibilityHorizon.tsx`

This is the full rewrite. The file contains 4 logical units: types/constants, DecisionCard, CategorySection, and the PossibilityHorizon orchestrator + InputZone. All in one file.

- [ ] **Step 1: Write the complete rewrite**

Replace the entire contents of `src/components/os/PossibilityHorizon.tsx` with:

```typescript
"use client";

import { useState, useEffect, useCallback, useMemo, useRef } from "react";
import { heartSort } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import { getConsensusState } from "@/lib/heart-sort";
import { useReactions } from "@/hooks/useReactions";
import type { ReactionType } from "@/hooks/useReactions";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import { supabase } from "@/lib/supabase";
import {
  colors,
  text,
  textColor,
  amberWash,
  reactions as reactionTokens,
  timing,
  layout,
  opacity,
} from "@/lib/theme";

// ══════════════════════════════════════════════════
// TYPES
// ══════════════════════════════════════════════════

interface DecisionItem {
  id: string;
  title: string;
  category: string;
  weighted_score: number;
  agreement_score: number;
  is_locked: boolean;
  state: string;
  metadata: {
    image_url?: string;
    price?: string;
    source?: string;
  } | null;
  created_at: string;
}

interface DecisionCardItem {
  id: string;
  title: string;
  imageUrl: string;
  price: string;
  source: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  createdAt: number;
}

interface DecisionCardProps extends DecisionCardItem {
  activeReaction?: ReactionType;
  onReact: (itemId: string, signal: ReactionType) => void;
}

interface CategorySectionProps {
  category: string;
  items: DecisionCardItem[];
  maxConviction: number;
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
}

interface PossibilityHorizonProps {
  spaceId: string;
  userId?: string;
}

// ── Demo items — used when Supabase is unreachable ──
const DEMO_ITEMS: Record<string, DecisionItem[]> = {
  "space_san-diego-trip": [
    { id: "demo_h1", title: "Hotel Del Coronado", category: "Hotel", weighted_score: 10, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { price: "$450/nt", source: "booking.com" }, created_at: new Date().toISOString() },
    { id: "demo_h2", title: "Coronado Island Marriott", category: "Hotel", weighted_score: 3, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { price: "$320/nt", source: "marriott.com" }, created_at: new Date().toISOString() },
    { id: "demo_a1", title: "Surf Lessons at La Jolla", category: "Activity", weighted_score: 6, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { price: "$95/person", source: "surfschool.com" }, created_at: new Date().toISOString() },
    { id: "demo_a2", title: "Balboa Park", category: "Activity", weighted_score: 4, agreement_score: 0.45, is_locked: false, state: "proposed", metadata: { price: "Free" }, created_at: new Date().toISOString() },
    { id: "demo_d1", title: "Gaslamp Quarter Dinner", category: "Dining", weighted_score: 8, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { price: "$65/person" }, created_at: new Date().toISOString() },
  ],
};

// ── Signal definitions ──
const SIGNALS: { type: ReactionType; label: string; color: string }[] = [
  { type: "love_it", label: "Love it", color: reactionTokens.loveIt.color },
  { type: "works_for_me", label: "Works for me", color: reactionTokens.worksForMe.color },
  { type: "not_for_me", label: "Not for me", color: reactionTokens.notForMe.color },
];

// ── Consensus state → color mapping (static, no animation) ──
function consensusColor(state: ConsensusState): string {
  if (state === "ignited") return colors.gold;
  if (state === "steady") return colors.cyan;
  return colors.amber;
}

// ══════════════════════════════════════════════════
// DECISION CARD
// ══════════════════════════════════════════════════

function DecisionCard({
  id,
  title,
  imageUrl,
  price,
  source,
  weightedScore,
  agreementScore,
  activeReaction,
  onReact,
}: DecisionCardProps) {
  const consensusState = getConsensusState(agreementScore);

  return (
    <div
      className="relative flex-shrink-0 snap-start"
      style={{ width: "280px", height: "360px" }}
    >
      {/* ── Image or gradient placeholder ── */}
      <div
        className="absolute inset-0"
        style={{
          backgroundImage: imageUrl
            ? `url(${imageUrl})`
            : `linear-gradient(135deg, rgba(var(--xark-amber-rgb), 0.15) 0%, rgba(var(--xark-accent-rgb), 0.08) 100%)`,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />

      {/* ── Bottom vignette ── */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(to top, rgba(var(--xark-void-rgb), 0.95) 0%, rgba(var(--xark-void-rgb), 0.4) 40%, transparent 70%)",
        }}
      />

      {/* ── Amber wash from weightedScore ── */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background: `linear-gradient(to top, ${amberWash(weightedScore)} 0%, transparent 50%)`,
        }}
      />

      {/* ── Content overlay ── */}
      <div className="absolute inset-x-0 bottom-0 px-4 pb-4">
        <p style={{ ...text.listTitle, color: colors.white, opacity: 0.9 }}>
          {title}
        </p>

        {(price || source) && (
          <div className="mt-1 flex items-center gap-3">
            {price && (
              <span style={{ ...text.subtitle, color: colors.white, opacity: 0.5 }}>
                {price}
              </span>
            )}
            {source && (
              <span style={{ ...text.recency, color: colors.white, opacity: 0.25 }}>
                {source}
              </span>
            )}
          </div>
        )}

        {/* ── Static consensus label (no animated ConsensusMark) ── */}
        <div className="mt-2">
          <span
            style={{
              ...text.recency,
              color: consensusColor(consensusState),
              opacity: 0.5,
              textTransform: "uppercase",
            }}
          >
            {Math.round(agreementScore * 100)}% consensus
          </span>
        </div>

        {/* ── Reaction signals ── */}
        <div className="mt-3 flex items-center gap-4">
          {SIGNALS.map((signal) => {
            const isActive = activeReaction === signal.type;
            return (
              <span
                key={signal.type}
                role="button"
                tabIndex={0}
                onClick={() => onReact(id, signal.type)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") onReact(id, signal.type);
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: signal.color,
                  opacity: isActive ? 0.9 : activeReaction ? 0.2 : 0.5,
                  cursor: "pointer",
                  transition: `opacity ${timing.transition} ease`,
                }}
              >
                {signal.label}
              </span>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════
// CATEGORY SECTION
// ══════════════════════════════════════════════════

function CategorySection({
  category,
  items,
  maxConviction,
  activeReactions,
  onReact,
}: CategorySectionProps) {
  const allLocked = items.length > 0 && items.every((i) => i.isLocked);

  // ── Settled row — all items locked ──
  if (allLocked) {
    const lockedTitle = items[0]?.title ?? "";
    return (
      <div className="flex items-center gap-3" style={{ padding: "4px 0" }}>
        <div
          style={{
            width: "4px",
            height: "4px",
            borderRadius: "50%",
            backgroundColor: colors.green,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
            flexShrink: 0,
          }}
        />
        <span style={{ ...text.label, color: textColor(0.3) }}>
          {category}
        </span>
        <span style={{ ...text.recency, color: textColor(0.25) }}>
          {lockedTitle}
          {items.length > 1 ? ` + ${items.length - 1} more` : ""}
        </span>
      </div>
    );
  }

  // ── Open section — header + conviction strip + card scroll ──
  return (
    <div>
      {/* ── Header + conviction strip ── */}
      <div className="flex items-center gap-3">
        <span style={{ ...text.label, color: textColor(0.35), flexShrink: 0 }}>
          {category}
        </span>
        <div style={{ flex: 1, height: "1px", position: "relative" }}>
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              height: "1px",
              width: `${Math.max(maxConviction * 100, 3)}%`,
              backgroundColor: colors.cyan,
              opacity: 0.3,
              transition: `width ${timing.transition} ease`,
            }}
          />
        </div>
      </div>

      {/* ── Horizontal card scroll ── */}
      <div
        className="horizon-scroll flex snap-x snap-mandatory overflow-x-auto"
        style={{
          marginTop: "12px",
          gap: "12px",
          paddingRight: "24px",
          WebkitOverflowScrolling: "touch",
        }}
      >
        {items.map((item) => (
          <DecisionCard
            key={item.id}
            {...item}
            activeReaction={activeReactions[item.id]}
            onReact={onReact}
          />
        ))}
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════
// POSSIBILITY HORIZON — ORCHESTRATOR
// ══════════════════════════════════════════════════

export function PossibilityHorizon({ spaceId, userId }: PossibilityHorizonProps) {
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeReactions, setActiveReactions] = useState<Record<string, ReactionType>>({});
  const [input, setInput] = useState("");
  const [inputFocused, setInputFocused] = useState(false);
  const [errorWhisper, setErrorWhisper] = useState(false);

  const { react, unreact, batchGetUserReactions, isReacting } = useReactions();

  // ── Voice input ──
  const { isListening, isXarkListening, transcript, startListening, startXarkListening, stopListening } =
    useVoiceInput();
  const longPressRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (transcript) setInput(transcript);
  }, [transcript]);

  // ── Fetch ALL decision items (locked + unlocked) ──
  useEffect(() => {
    async function fetchItems() {
      const { data } = await supabase
        .from("decision_items")
        .select("id, title, category, weighted_score, agreement_score, is_locked, state, metadata, created_at")
        .eq("space_id", spaceId);

      if (data && data.length > 0) {
        setItems(data as DecisionItem[]);
        if (userId) {
          const ids = data.map((d) => d.id);
          const reactions = await batchGetUserReactions(ids, userId);
          setActiveReactions(reactions);
        }
      } else {
        // Demo fallback when Supabase is unreachable or empty
        setItems(DEMO_ITEMS[spaceId] ?? []);
      }
      setLoading(false);
    }
    fetchItems();
  }, [spaceId, userId, batchGetUserReactions]);

  // ── Realtime: UPDATE + INSERT ──
  useEffect(() => {
    const channel = supabase
      .channel(`horizon:${spaceId}`)
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const updated = payload.new as DecisionItem;
          setItems((prev) => prev.map((i) => (i.id === updated.id ? updated : i)));
        }
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const inserted = payload.new as DecisionItem;
          setItems((prev) => {
            if (prev.some((i) => i.id === inserted.id)) return prev;
            return [...prev, inserted];
          });
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [spaceId]);

  // ── Sort + group by category (memoized) ──
  const grouped = useMemo(() => {
    // Map to Possibility shape for heartSort
    const sortable = items.map((item) => ({
      id: item.id,
      title: item.title,
      imageUrl: item.metadata?.image_url ?? "",
      weightedScore: item.weighted_score,
      agreementScore: item.agreement_score,
      isLocked: item.is_locked,
      createdAt: new Date(item.created_at).getTime(),
    }));

    const sorted = heartSort(sortable);

    // Build metadata lookup
    const metaMap = new Map(items.map((i) => [i.id, i]));

    // Group by category, preserving sort order
    const groups: Record<string, { items: DecisionCardItem[]; maxConviction: number }> = {};

    for (const item of sorted) {
      const full = metaMap.get(item.id);
      const category = full?.category || "general";
      const cardItem: DecisionCardItem = {
        ...item,
        price: full?.metadata?.price ?? "",
        source: full?.metadata?.source ?? "",
      };

      if (!groups[category]) {
        groups[category] = { items: [], maxConviction: 0 };
      }
      groups[category].items.push(cardItem);
      groups[category].maxConviction = Math.max(
        groups[category].maxConviction,
        item.agreementScore
      );
    }

    return groups;
  }, [items]);

  // ── Reaction handler ──
  const handleReaction = useCallback(
    async (itemId: string, signal: ReactionType) => {
      if (isReacting) return;
      if (activeReactions[itemId] === signal) {
        setActiveReactions((prev) => {
          const next = { ...prev };
          delete next[itemId];
          return next;
        });
        await unreact(itemId);
      } else {
        setActiveReactions((prev) => ({ ...prev, [itemId]: signal }));
        await react(itemId, signal);
      }
    },
    [activeReactions, isReacting, react, unreact]
  );

  // ── @xark send (Decide input is @xark-only — silently ignore non-@xark messages) ──
  const handleSend = useCallback(async () => {
    const txt = input.trim();
    if (!txt) return;
    if (!txt.includes("@xark")) return; // Decide is @xark-only
    setInput("");

    try {
      const response = await fetch("/api/xark", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: txt, spaceId }),
      });
      if (!response.ok) {
        setErrorWhisper(true);
        setTimeout(() => setErrorWhisper(false), 2000);
      }
      // Results arrive via Realtime INSERT — no inline handling needed
    } catch {
      setErrorWhisper(true);
      setTimeout(() => setErrorWhisper(false), 2000);
    }
  }, [input, spaceId]);

  const categoryNames = Object.keys(grouped);
  const hasItems = categoryNames.length > 0;

  // ── Loading state ──
  if (loading) {
    return (
      <div className="flex items-center justify-center" style={{ paddingTop: "200px", opacity: 0.2 }}>
        <div
          style={{
            width: "6px",
            height: "6px",
            borderRadius: "50%",
            backgroundColor: colors.cyan,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
          }}
        />
        <p className="ml-4" style={{ ...text.label, color: colors.white }}>
          loading
        </p>
      </div>
    );
  }

  return (
    <div className="relative flex min-h-svh flex-col">
      {/* ── Category Sections ── */}
      <div
        className="flex-1 overflow-y-auto px-6"
        style={{
          paddingTop: "160px",
          paddingBottom: "30vh",
          display: "flex",
          flexDirection: "column",
          gap: "40px",
        }}
      >
        {hasItems ? (
          categoryNames.map((category) => (
            <CategorySection
              key={category}
              category={category}
              items={grouped[category].items}
              maxConviction={grouped[category].maxConviction}
              activeReactions={activeReactions}
              onReact={handleReaction}
            />
          ))
        ) : (
          /* ── Empty state — greeting near input ── */
          <>
            <div style={{ flex: 1 }} />
            <div style={{ maxWidth: "640px", marginBottom: "16px" }}>
              <span style={{ ...text.label, color: colors.cyan, opacity: 0.4 }}>
                @xark
              </span>
              <p className="mt-1" style={{ ...text.hint, color: colors.white, opacity: 0.35 }}>
                {`try "@xark find hotels near the beach" or "@xark add dates aug 15–25"`}
              </p>
            </div>
          </>
        )}
      </div>

      {/* ── Input Zone — fixed bottom, @xark-only ── */}
      <div
        className="fixed inset-x-0 bottom-0 px-6 pt-12"
        style={{
          paddingBottom: layout.inputBottom,
          background:
            "linear-gradient(to top, rgba(var(--xark-void-rgb), 1) 0%, rgba(var(--xark-void-rgb), 1) 40%, rgba(var(--xark-void-rgb), 0.8) 70%, transparent 100%)",
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          <div className="relative flex items-center gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") handleSend(); }}
              placeholder={
                isXarkListening
                  ? "@xark is listening..."
                  : isListening
                    ? "listening..."
                    : "message, or @xark for ideas"
              }
              spellCheck={false}
              autoComplete="off"
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              className="w-full bg-transparent outline-none"
              style={{ ...text.input, color: colors.white, caretColor: colors.cyan }}
            />
            {/* ── Mic ── */}
            <span
              role="button"
              tabIndex={0}
              onPointerDown={() => {
                longPressRef.current = setTimeout(() => {
                  startXarkListening();
                  longPressRef.current = null;
                }, 500);
              }}
              onPointerUp={() => {
                if (longPressRef.current) {
                  clearTimeout(longPressRef.current);
                  longPressRef.current = null;
                  if (isListening || isXarkListening) stopListening();
                  else startListening();
                }
              }}
              onPointerLeave={() => {
                if (longPressRef.current) {
                  clearTimeout(longPressRef.current);
                  longPressRef.current = null;
                }
              }}
              className="outline-none select-none"
              style={{
                ...text.label,
                color: isXarkListening ? colors.cyan : colors.white,
                opacity: isListening || isXarkListening ? 0.9 : 0.3,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                flexShrink: 0,
              }}
            >
              {isListening || isXarkListening ? (
                <span className="flex items-center gap-2">
                  <span
                    style={{
                      display: "inline-block",
                      width: "6px",
                      height: "6px",
                      borderRadius: "50%",
                      backgroundColor: isXarkListening ? colors.cyan : colors.white,
                      animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                    }}
                  />
                </span>
              ) : (
                "mic"
              )}
            </span>
            {/* ── Accent underline ── */}
            <div
              className="absolute -bottom-2 left-0 h-px w-full"
              style={{
                background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                opacity: inputFocused ? 1 : 0.15,
                animation: inputFocused ? `ambientBreath ${timing.breath} ease-in-out infinite` : "none",
                transition: `opacity ${timing.transition} ease`,
              }}
            />
          </div>

          {/* ── Error whisper ── */}
          {errorWhisper && (
            <p className="mt-2" style={{ ...text.hint, color: textColor(0.3) }}>
              couldn't reach @xark — try again
            </p>
          )}
        </div>
      </div>

      <style jsx>{`
        .horizon-scroll::-webkit-scrollbar { display: none; }
        .horizon-scroll { scrollbar-width: none; -ms-overflow-style: none; }
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.ghost};
          letter-spacing: 0.12em;
        }
      `}</style>
    </div>
  );
}
```

- [ ] **Step 2: Verify types compile**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 3: Tier 3 audit**

Run: `grep -n 'font-bold\|font-semibold\|font-weight.*[5-9]00\|backdrop-filter\|border-1\|bg-white\|rounded-lg' src/components/os/PossibilityHorizon.tsx`
Expected: No matches

- [ ] **Step 4: Commit**

```bash
git add src/components/os/PossibilityHorizon.tsx
git commit -m "feat: rewrite PossibilityHorizon — Netflix-style category sections with conviction strips"
```

---

## Chunk 3: Guardrail Updates

### Task 3: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the KEY MODULE MAP entry**

Find the existing PossibilityHorizon reference in the KEY MODULE MAP section and replace/update. The current entry is in the component_registry section of `.xark-state.json`. Add a line to the KEY MODULE MAP after the UserMenu entry:

```
- src/components/os/PossibilityHorizon.tsx — Decide view: Netflix-style category sections (vertical scroll) with horizontal card bands per category. DecisionCard (280×360, image/gradient, vignette, amber wash, consensus label, reaction signals). CategorySection (header + conviction strip + card scroll, settled row when all locked). InputZone (shared bottom, @xark-only, POST to /api/xark, results via Realtime INSERT). Batch reaction fetch via batchGetUserReactions. Single Supabase query + client-side grouping (useMemo). Self-resolving: locked categories collapse to green dot + title whisper.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with Decide view architecture"
```

### Task 4: Update CONSTITUTION.md Section 15

**Files:**
- Modify: `CONSTITUTION.md`

- [ ] **Step 1: Replace Section 15 content**

Replace the existing Section 15 (THE POSSIBILITY HORIZON) with updated content reflecting the new design:

```markdown
## 15. THE POSSIBILITY HORIZON (DECIDE VIEW)
- `src/components/os/PossibilityHorizon.tsx` — Netflix-style vertical scroll of horizontal card bands, one per category.
- **Category Sections**: Each `category` from `decision_items` (Hotel, Activity, Flight, Dining, etc.) gets its own section. Header in `text.label` at `textColor(0.35)`. Conviction strip: 1px `colors.cyan` line, width = `max(maxAgreementScore * 100%, 3%)`, opacity 0.3.
- **Decision Cards**: 280×360px. No border-radius. Image or gradient placeholder (`amber → accent`). Bottom vignette. Amber wash from `amberWash(weightedScore)`. Title (`text.listTitle`, 0.9). Price (`text.subtitle`, 0.5) + source (`text.recency`, 0.25). Static consensus label (`text.recency`, colored by state: amber/cyan/gold). Reaction signals as floating `text.label`.
- **Self-Resolving**: When all items in a category are locked, section collapses to a settled row: 4px `colors.green` breathing dot + category name + locked title at `textColor(0.3)`.
- **Input Zone**: Fixed bottom, identical to Discuss Thumb-Arc pattern. @xark-only — non-@xark messages silently ignored. Results arrive via Realtime INSERT.
- **Data**: Single Supabase query (ALL items, no `is_locked` filter). Batch reaction fetch. Client-side grouping by `category` (memoized). Single Realtime channel (UPDATE + INSERT).
- Items ordered by `heartSort()` within each category (weightedScore descending, locked items last).
- Snap scroll: `scroll-snap-type: x mandatory`, `scroll-snap-align: start`. Hidden scrollbar. 12px gap between cards.
- **BANNED**: Cards with border-radius, rounded corners, `ConsensusMark` animated SVG on cards (use static text label), buttons with borders/backgrounds.
```

- [ ] **Step 2: Commit**

```bash
git add CONSTITUTION.md
git commit -m "docs: update Constitution Section 15 for Netflix-style Decide view"
```

### Task 5: Update .xark-state.json

**Files:**
- Modify: `.xark-state.json`

- [ ] **Step 1: Update component registry**

Change `"PossibilityHorizon": "active"` to `"PossibilityHorizon": "verified"`.

- [ ] **Step 2: Commit**

```bash
git add .xark-state.json
git commit -m "chore: mark PossibilityHorizon as verified in component registry"
```

---

## Chunk 4: Verification

### Task 6: Full verification pass

- [ ] **Step 1: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 0 errors

- [ ] **Step 2: Tier 3 audit on all modified files**

Run:
```bash
grep -rn 'font-bold\|font-semibold\|font-weight.*[5-9]00\|backdrop-filter\|border-1\|bg-white\|rounded-lg' src/components/os/PossibilityHorizon.tsx src/hooks/useReactions.ts
```
Expected: No matches

- [ ] **Step 3: Dev server smoke test**

Run: `npx next dev -p 3000`

Manual checks:
1. Navigate to any space → tap "decide" → verify category sections render with horizontal card bands
2. Swipe cards horizontally within a section
3. Scroll vertically between sections
4. Verify conviction strip width reflects agreementScore
5. Verify settled rows (green dot + title) for locked categories
6. Type `@xark find flights` in bottom input → verify POST fires
7. Test reaction signals: tap Love it / Works / Not for me on a card
8. Test empty state: space with no items shows @xark greeting near input
9. Switch between all 6 themes — verify cards render correctly
10. Verify no visible scrollbars on horizontal card bands
