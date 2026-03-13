# Decide View Redesign — Netflix-Style Category Sections

**Date:** 2026-03-13
**Status:** Approved
**Scope:** `src/components/os/PossibilityHorizon.tsx` rewrite + new sub-components

## Problem

The current Decide view is a single horizontal carousel of edge-to-edge cards (85vw × 70vh). Three issues:

1. No @xark input — users must switch to Discuss to invoke intelligence.
2. No category grouping — hotels, flights, activities, cars mixed in one flat scroll.
3. No visual signal of decision progress across categories.

## Design

A vertically scrolling page of **horizontal card bands**, one per category. Locked categories collapse into settled rows. A shared input zone at the bottom enables @xark invocation.

### Layout

```
┌──────────────────────────────────────┐
│  (header: title + DISCUSS/DECIDE)    │
│  ─── ambient accent line ───         │
├──────────────────────────────────────┤
│                                      │
│  HOTELS  ━━━━━━━ (conviction strip)  │
│  ┌─────────┐ ┌─────────┐ ┌────      │
│  │  card 1 │ │  card 2 │ │  ca...   │  ← horizontal scroll
│  │  280×360 │ │         │ │          │
│  └─────────┘ └─────────┘ └────      │
│                                      │
│  FLIGHTS  ━━━━ (conviction strip)    │
│  ┌─────────┐ ┌─────────┐            │
│  │  card 1 │ │  card 2 │            │  ← horizontal scroll
│  └─────────┘ └─────────┘            │
│                                      │
│  ✓ DINING  hotel del restaurant      │  ← settled (collapsed)
│                                      │
│  ACTIVITIES  ━━━━━━━━━━━             │
│  ┌─────────┐ ┌─────────┐ ┌────      │
│  │         │ │         │ │          │
│  └─────────┘ └─────────┘ └────      │
│                                      │
├──────────────────────────────────────┤
│  [message, or @xark for ideas] MIC   │
│  ─── ambient accent line ───         │
└──────────────────────────────────────┘
```

- Outer page scrolls vertically. Each category band scrolls horizontally.
- `paddingTop: 160px` clears fixed header. `paddingBottom: 30vh` clears input zone.
- `px-6` outer padding. Cards inset from edges (not edge-to-edge).

### Decision Card

280px wide × 360px tall. Self-contained visual unit.

```
┌─────────────────────────┐
│                         │
│    (image / gradient)   │
│                         │
│  ▓▓▓▓ vignette ▓▓▓▓▓▓  │
│  Hotel Del Coronado     │  text.listTitle, opacity 0.9
│  $450/nt · booking.com  │  text.subtitle + text.recency
│  ◎ 92% consensus        │  ConsensusMark + text.recency
│  Love it  Works  Not    │  text.label, floating signal text
└─────────────────────────┘
```

- **Fixed dimensions**: 280px × 360px. Consistent across all categories.
- **Border radius**: 12px. Subtle thumbnail rounding — not `rounded-lg`.
- **Image**: `object-fit: cover`. Gradient placeholder when no image (`amber-rgb 0.15 → accent-rgb 0.08`).
- **Vignette**: bottom-up void gradient for text legibility.
- **Amber wash**: `amberWash(weightedScore)` intensity overlay.
- **Gap**: 12px between cards. First card flush with page left padding. Last card has 24px right padding for scroll breathing room.
- **Snap**: `scroll-snap-type: x mandatory`, `scroll-snap-align: start`.
- **Props**: `id, title, imageUrl, price, source, weightedScore, agreementScore, isLocked, activeReaction, onReact`. No section awareness, no index awareness.

### Category Section

Pure function of its items array.

**Header**: Category name in `text.label` (uppercase, 0.2em tracking) at `textColor(0.35)`.

**Conviction strip**: 1px line, `colors.cyan` at opacity 0.3. Width = `maxConviction * 100%` of available space (where `maxConviction` = highest `agreementScore` in the section). Animates width on score change (0.4s ease). A section at 92% conviction has a nearly-full strip. A section at 10% is a sliver. Zero UI weight.

**Spacing**: 40px between sections. Header → cards: 12px.

### Self-Resolving Behavior

When **all items in a category are locked**, the section collapses to a settled row:

- **Open section**: header + conviction strip + horizontal card scroll (~400px tall)
- **Settled section**: 4px `colors.green` dot (breathing 4.5s) + category name + locked item title, all at `textColor(0.3)`. Single row (~24px tall).

The page physically compresses as decisions get made. A space with 5 categories where 3 are locked shows 2 rich scrollable bands and 3 whisper-thin settled rows. Progress is visible through **spatial compression** — no progress bars, no percentages, no dashboards.

### Input Zone

Shared bottom input, identical to Discuss view's Thumb-Arc pattern:

- Fixed bottom, `paddingBottom: layout.inputBottom` (96px).
- `text.input`, `bg-transparent`, accent underline breathe on focus.
- Placeholder: `"message, or @xark for ideas"`.
- MIC: tap = dictate, long-press = @xark mode (from `useVoiceInput`).
- Gradient fade: `void 1.0 → 1.0 at 40% → 0.8 at 70% → transparent`.
- On send: POST to `/api/xark` with `{ message, spaceId }`. Response items appear via Realtime subscription. Category routing is automatic (API returns `category` from tool registry).
- Empty state greeting anchored near input: `try "@xark find hotels near the beach"` pattern.

## Data Flow

```
PossibilityHorizon (orchestrator)
  │
  ├── Single Supabase query: all decision_items for spaceId
  ├── Single batch reaction query: all user reactions for those item IDs
  ├── Client-side grouping: Record<string, DecisionCardItem[]> (useMemo)
  ├── maxConviction per category: computed in grouping pass
  │
  ├── Single Realtime subscription: decision_items WHERE space_id = X
  │     └── UPDATE → re-map items → re-group (memoized) → affected section re-renders
  │
  ├── <CategorySection category="hotels" items={...} maxConviction={0.92} />
  │     └── <DecisionCard {...item} onReact={handleReaction} />  ×N
  │
  ├── <CategorySection category="flights" items={...} maxConviction={0.45} />
  │     └── <DecisionCard {...item} onReact={handleReaction} />  ×N
  │
  └── <InputZone spaceId={...} />
```

### Key Data Decisions

- **One query, client-side grouping**. No per-category queries. Grouping is O(n) and memoized.
- **Batch reaction fetch**. Replace the current sequential `getUserReaction` loop with a single query: `SELECT * FROM reactions WHERE user_id = $1 AND item_id = ANY($2)`. One roundtrip for all items.
- **Reactions managed at orchestrator level**. PossibilityHorizon holds `activeReactions` state, passes `activeReaction` and `onReact` callback as props to each DecisionCard. No per-card hook instances.
- **Single Realtime channel** per space. UPDATE events flow through the grouping memo. Only affected sections re-render.
- **No shared mutable state** between sections. Each section is a pure render of its items slice.

## Component Architecture

| Component | Location | Responsibility | Props In | Dependencies |
|---|---|---|---|---|
| `PossibilityHorizon` | Existing file, rewrite | Fetch items, group by category, manage reactions, Realtime | `spaceId, userId` | supabase, heart-sort, useReactions |
| `CategorySection` | Same file (not extracted unless >150 lines) | Section header + conviction strip + horizontal card scroll | `category, items, maxConviction, activeReactions, onReact, userId` | None (pure) |
| `DecisionCard` | Same file (not extracted unless >100 lines) | Single card: image, info, consensus, reaction signals | `id, title, imageUrl, price, source, weightedScore, agreementScore, isLocked, activeReaction, onReact` | None (pure) |
| `InputZone` | Same file | Bottom input + mic + @xark POST | `spaceId` | /api/xark, useVoiceInput |

All communication is **props down, callbacks up**. No context providers, no global stores, no cross-component event buses.

Dependency graph (strictly linear, no cycles):

```
PossibilityHorizon → CategorySection → DecisionCard
                   → InputZone
```

## Constitutional Compliance

- **No bold**: All text uses `text.*` tokens (weight 300/400 only).
- **Zero-box**: Cards use 12px radius for thumbnail feel. No `rounded-lg`, no `border`, no `bg-white`. Information floats.
- **Theme-aware**: All colors via `colors.*`, `textColor()`, `accentColor()`. No hardcoded hex.
- **No blur**: Gradient overlays only. No `backdrop-filter`.
- **Font scale**: All typography from `text` object in theme.ts. No Tailwind text-size classes.

## Performance Notes

- **Scope**: Solo + Small Group (2-15 members). Item counts per space bounded (~50 max realistic). All optimizations target this range — no premature infrastructure.
- **Re-render blast radius**: Realtime UPDATE → `setItems` map → `useMemo` re-groups → only changed section's cards re-render. React reconciliation handles this via stable keys.
- **Image loading**: Native `<img>` with `loading="lazy"` for offscreen cards. No next/image dependency (cards are fixed-size, no layout shift).
- **External image privacy**: `metadata.image_url` from Apify exposes user IP to image host. Pre-existing in current code. Future mitigation: proxy through Next.js image route. Not blocking for this iteration.

## Files Modified

| File | Change |
|---|---|
| `src/components/os/PossibilityHorizon.tsx` | Full rewrite: vertical sections, horizontal card bands, batch reactions, InputZone, Realtime |
| `src/hooks/useReactions.ts` | Add `batchGetUserReactions(itemIds, userId)` method |
| `CLAUDE.md` | Document new Decide view architecture |
| `CONSTITUTION.md` | Update Section 15 (Possibility Horizon) |
| `.xark-state.json` | Update component_registry: PossibilityHorizon → verified |

## Verification

1. `npx tsc --noEmit` — zero type errors.
2. Tier 3 audit: grep for `font-bold`, `font-semibold`, `font-weight` > 400, `backdrop-filter`, `border-1`, `bg-white`, `rounded-lg` in modified files.
3. Manual test: navigate to space → Decide tab → see category sections with horizontal card scrolling. Swipe cards within a section. Scroll vertically between sections. Locked categories show as settled rows.
4. Test @xark input: type `@xark find flights` → results appear in flights section via Realtime.
5. Test reactions: tap Love it / Works / Not on cards. Verify single active reaction per card, toggle behavior.
6. Test all 6 themes render correctly on cards and sections.
7. Test empty state: space with no items shows greeting near input.
