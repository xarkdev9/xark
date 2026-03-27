# People & Plans — Galaxy Home Screen Redesign

## Problem

New users land on the Galaxy home screen and see a list of space summaries. They don't know what Xark is — there's no visible chat interface, no voting cards, no signal that this is a messaging + group decision app. The home screen is a meta layer that requires entering a space to discover the product.

## Solution

Split the Galaxy home screen into two swipeable tabs: **People** and **Plans**.

- **People** = WhatsApp-style chat list. Personal chats show last message. Group chats show consensus summaries. Sorted by recency. Tap opens Space in discuss view.
- **Plans** = Action-sorted group list. Shows groups with decision items, prioritized by "needs your vote." Tap opens Space in decide view. An escape hatch for users to go directly to voting.

Users instantly see familiar chat patterns (People) AND the unique value prop (Plans) from minute one.

## Design

### Tab Structure

Two full-screen panels, horizontally swipeable. Top indicator: `people | plans` text labels with accent-colored sliding underline and ambient lighting.

- Tab labels: `text.label` (0.8125rem, weight 300, uppercase, 0.12em tracking)
- Active tab: accent color (`colors.cyan` / `var(--xark-accent)`), opacity 0.9
- Inactive tab: `colors.white`, opacity 0.25
- Underline: 2px accent line, fixed width matching label text width. Slides with swipe gesture position (interpolates between label positions during drag). On tap switch, animates with same 0.3s transition.
- Ambient glow: `radial-gradient(ellipse 80px 30px at center, accentColor(0.06), transparent)` behind active label. Animated via existing `ambientBreath` keyframe (opacity 0.6–1.0 cycle, `timing.breath` 4.5s). Implemented as a pseudo-element or sibling div. Opacity-only animation (GPU-composited, safe for low-end).

### Swipe Implementation

Pure touch events + CSS transform. No library. Must work on low-end Android.

```
touchstart → record startX, startTime
touchmove  → translateX(deltaX) on panel container, interpolate underline position
touchend   → calculate velocity = deltaX / (now - startTime)
             if |deltaX| > 30% screen width OR velocity > 0.3px/ms → switch tab
             else → snap back
             CSS transition: transform 0.3s cubic-bezier(0.22, 1, 0.36, 1)
```

Panel container holds both views side by side at 200% width. `translateX(0)` = People, `translateX(-50%)` = Plans. Tap on inactive label also switches (with same 0.3s transition).

Tab state persists during the Galaxy session but resets to People on navigation return (re-mount).

### People Tab

Sorted by `last_activity_at` descending (most recent first). Mixed list of personal chats and group spaces.

**Personal chat row (atmosphere = "sanctuary"):**
```
[Avatar 36px]  name                    2m
               last message preview...
```
- Avatar: existing `<Avatar>` component at size 36 (up from 24)
- Name: `text.listTitle`, `colors.white`, opacity 0.85
- Time: `text.timestamp`, `colors.white`, opacity 0.2
- Message preview: `text.recency`, `colors.white`, opacity 0.4, single line ellipsis
- Tap → `/space/{id}?name={userName}` (opens in discuss view, default)

**Group chat row:**
```
[Avatar 36px]  space title              15m
               2 locked · 1 needs your vote
```
- Same avatar/title treatment as personal chats
- Summary line: `text.recency`, uses existing `summaryText(space)` from `awareness.ts` + `recencyLabel()`
- Summary color: `textColor(0.35)` for peaceful, `textColor(0.5)` if action needed
- Tap → `/space/{id}?name={userName}` (opens in discuss view)

**Row spacing:** 20px vertical gap between rows. No borders, no dividers (Zero-Box).

### Plans Tab

Groups only — no personal/sanctuary chats. Sorted by awareness priority (existing `scoreSummary()` from `awareness.ts`): needs-vote spaces float up, peaceful ones sink.

**Group row:**
```
[Avatar 36px]  space title              15m
               1 needs your vote
```
- Same avatar/title as People tab
- Status line: `text.recency`. Action-needed items in `colors.amber` at 0.7 opacity. Peaceful items in `textColor(0.25)`.
- Tap → `/space/{id}?name={userName}&view=decide` (opens directly in decide view)
- Peace state message when all spaces are calm: "you're good. your trips are moving along." at `textColor(0.2)`

### Data Fetching

**People tab data:**
Two queries, merged and sorted client-side by `lastActivityAt` descending:

1. Existing `fetchAwareness(userId)` — returns `SpaceAwareness[]` for group spaces (already excludes sanctuaries)
2. New `fetchPersonalChats(userId)` in `src/lib/awareness.ts`:

```typescript
interface PersonalChat {
  spaceId: string;
  contactName: string;    // resolved from the OTHER member's display_name
  lastMessage: string;    // content of most recent message
  lastActivityAt: number; // timestamp of most recent message
}

async function fetchPersonalChats(userId: string): Promise<PersonalChat[]> {
  // 1. Query spaces where atmosphere = 'sanctuary' AND user is a member
  const { data: sanctuaries } = await supabase
    .from("spaces")
    .select("id, title, last_activity_at")
    .eq("atmosphere", "sanctuary")
    .in("id", /* user's space IDs from space_members */);

  // 2. For each sanctuary, fetch last message
  const { data: lastMessages } = await supabase
    .from("messages")
    .select("space_id, content, sender_name, created_at")
    .in("space_id", sanctuaryIds)
    .order("created_at", { ascending: false })
    .limit(1);  // per space — handled via distinct-on or client-side grouping

  // 3. Resolve contact name: query space_members for the OTHER user,
  //    join with users table for display_name.
  //    Fallback: use space.title if member lookup fails.
}
```

Combined into a unified list:
```typescript
type GalaxyItem =
  | { type: "personal"; spaceId: string; contactName: string; lastMessage: string; lastActivityAt: number }
  | { type: "group"; space: SpaceAwareness };
```

**Plans tab data:**
Existing `fetchAwareness(userId)` — already returns exactly what's needed.

**Demo data fallback:**
When Supabase is unreachable, `getDemoAwareness()` returns group spaces (existing). Add `getDemoPersonalChats()` returning:
```typescript
[
  { spaceId: "space_ananya", contactName: "ananya", lastMessage: "sent you the photos", lastActivityAt: Date.now() - 3600_000 },
]
```
This uses the existing "ananya" sanctuary from seed data.

### Real-time Updates

Existing subscriptions carry over unchanged:
- `space_members` INSERT → refetch awareness (new space added to user)

New subscription for People tab personal chat previews:
- Single Supabase Realtime channel subscribing to `postgres_changes` on `messages` table filtered by the user's sanctuary space IDs. Uses `filter: space_id=in.(id1,id2,id3)` syntax. This is bounded by the number of personal chats (typically <20 for a user), well within Supabase filter limits.
- On INSERT event: update the matching `PersonalChat.lastMessage` and `lastActivityAt`, re-sort the People list.
- Group chat real-time: existing broadcast channels handle this. No new subscription needed.

### Galaxy Input

Stays at the bottom of both tabs. No changes. Same behavior: type a plan name to create a space, or `@name` to message a friend. The input zone (`fixed inset-x-0`, bottom 56px) overlays both panels.

### ControlCaret

The ControlCaret (global navigation dot in layout.tsx) is unchanged. It continues to show all spaces via `fetchSpaceList()`. The Galaxy page People/Plans tabs are a view layer on top of the same data. No ControlCaret modifications needed.

### Navigation Flow

```
Galaxy (People tab, default)
├── Tap personal chat → /space/{id} (discuss view)
├── Tap group chat → /space/{id} (discuss view)
├── Back from Space → Galaxy remounts, People tab active
└── Swipe right → Plans tab
    ├── Tap group → /space/{id}?view=decide (decide view)
    └── Back from Space → Galaxy remounts, People tab active
```

Space page reads `?view=decide` param to set initial `ViewMode`:
```typescript
const viewParam = searchParams.get("view");
const [view, setView] = useState<ViewMode>(
  viewParam === "decide" ? "decide" : "discuss"
);
```

**Precedence:** The `isSettled` auto-switch (existing behavior: settled spaces show memories view) takes priority over `?view=decide`. If a space is settled, it opens in memories view regardless of the query param. This is correct because settled spaces have no active decisions to vote on.

### Empty States

**People tab (no chats):**
"start something" (`text.hero`) + "type a plan below, or @someone to message a friend" (`text.subtitle`) + "try it" link that focuses input. (Already implemented in current Galaxy page.)

**Plans tab (no groups with items):**
"no active plans yet" at `text.subtitle`, `textColor(0.25)` + "start a plan below to get going" at `text.recency`, `textColor(0.15)`.

### Accessibility

- Tab labels: `role="tab"`, `aria-selected`, keyboard navigable with arrow keys
- Tab panels: `role="tabpanel"`, `aria-labelledby` pointing to tab label
- Swipe gesture: tap on inactive label is always available as non-gesture alternative

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/app/galaxy/page.tsx` | Modify | Add People/Plans tabs, swipe gesture, tab state, render both panels |
| `src/lib/awareness.ts` | Modify | Add `fetchPersonalChats()` + `getDemoPersonalChats()` + `PersonalChat` type |
| `src/app/space/[id]/page.tsx` | Modify | Read `?view=decide` param for initial view mode (behavioral change: `useState` init reads searchParams) |

### Constraints

- No new dependencies. Touch events + CSS transforms only.
- All text from `theme.ts` type scale. No Tailwind text classes.
- All colors from CSS variables. No hardcoded hex in components.
- No borders, no cards, no dividers. Separation via vertical spacing only (Zero-Box).
- Font weights 300/400 only (No-Bold Mandate).
- Must render at 60fps on low-end Android (no `backdrop-filter`, no heavy shadows, opacity-only animations).
