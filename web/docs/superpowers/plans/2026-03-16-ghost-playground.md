# Ghost Playground Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drop first-time users into 4 pre-loaded sandbox spaces with diegetic coaching, frame-perfect choreography, and zero database records — making them discover every Xark feature by playing.

**Architecture:** Client-side only. `playground.ts` holds all data (friends, spaces, items, messages, photos). `usePlaygroundChoreography` hook drives timed whisper/message sequences. Galaxy page detects playground mode (no real spaces) and renders playground spaces. Space page loads from playground data when `?playground=true`. All production components reused — no new visual components.

**Tech Stack:** React 19, Framer Motion, TypeScript, existing Xark component library.

**Spec:** `docs/superpowers/specs/2026-03-16-ghost-playground-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `src/lib/playground.ts` | CREATE | All playground data: 5 friends, 4 spaces with items/messages/members. Detection function. Getter functions. |
| `src/hooks/usePlaygroundChoreography.ts` | CREATE | Timer-based choreography engine. Returns whispers, queued messages, typing indicator. Cleanup on unmount. |
| `src/components/os/PlaygroundWhisper.tsx` | CREATE | Diegetic whisper component. Weight 300, breathing opacity 30→60%, 4s cycle. Dismisses on interaction. |
| `src/components/os/InlineCardPreview.tsx` | CREATE | Miniature decision card for rendering @xark results inline in chat timeline. Read-only. Tappable to expand. |
| `src/components/os/AwarenessStream.tsx` | MODIFY | Render playground spaces when `isPlayground` prop is true. |
| `src/components/os/PeopleDock.tsx` | MODIFY | Pass through playground mode (no changes to rendering — playground has no personal chats). |
| `src/app/galaxy/page.tsx` | MODIFY | Detect playground mode. Pass playground data to AwarenessStream. Navigate with `?playground=true`. |
| `src/app/space/[id]/page.tsx` | MODIFY | Load from playground.ts when `?playground=true`. Mock reactions. Enable choreography. Mock @xark responses. |
| `src/components/os/XarkChat.tsx` | MODIFY | Render InlineCardPreview in message stream. Show typing indicators from choreography. |
| `src/components/os/PurchaseSheet.tsx` | MODIFY | Accept `prefillAmount` prop for playground pre-filled purchase. |

---

## Chunk 1: Data Layer + Detection

### Task 1: Create playground.ts — Friends & Space Definitions

**Files:**
- Create: `src/lib/playground.ts`

- [ ] **Step 1: Define friend profiles and types**

```typescript
// src/lib/playground.ts

export interface PlaygroundFriend {
  id: string;
  displayName: string;
  letter: string;
}

export const PLAYGROUND_FRIENDS: Record<string, PlaygroundFriend> = {
  leo: { id: "pg_leo", displayName: "leo", letter: "L" },
  kai: { id: "pg_kai", displayName: "kai", letter: "K" },
  ava: { id: "pg_ava", displayName: "ava", letter: "A" },
  zoe: { id: "pg_zoe", displayName: "zoe", letter: "Z" },
  sam: { id: "pg_sam", displayName: "sam", letter: "S" },
};
```

- [ ] **Step 2: Define Space 1 — "tokyo neon nights"**

All items, messages, members for the 94% consensus hook. 3 hotel cards. 6 chat messages. Members: leo, kai, ava, sam.

Key data points:
- "park hyatt tokyo": `agreement_score: 0.94`, `weighted_score: 18`, `is_locked: false`, `state: "ranked"`
- Photo URLs: use Unsplash `?w=400&h=500&fit=crop` format
- Messages have timestamps spaced ~minutes apart
- System message: "sam reacted love to park hyatt"

- [ ] **Step 3: Define Space 2 — "dinner tonight"**

Fresh chat, no decision items. 2 messages from zoe and leo. Members: zoe, leo, kai.

- [ ] **Step 4: Define Space 3 — "maya's birthday"**

Ready stage. 2 locked items (dinner at nobu: claimed by leo, $320 purchased; surprise cake: unclaimed). 4 messages. Members: leo, ava, zoe.

- [ ] **Step 5: Define Space 4 — "weekend hike"**

Settled stage. 3 completed items. 6 demo photo URLs. 5 nostalgia messages. Settlement: $0 outstanding. Members: kai, ava, sam.

- [ ] **Step 6: Create detection and getter functions**

```typescript
import type { SpaceAwareness } from "@/lib/awareness";
import type { ChatMessage } from "@/lib/messages";

export function isPlaygroundMode(
  realSpaces: SpaceAwareness[],
  realChats: { spaceId: string }[]
): boolean {
  return realSpaces.length === 0 && realChats.length === 0;
}

export function getPlaygroundSpaces(): SpaceAwareness[] { ... }
export function getPlaygroundItems(spaceId: string): DecisionItem[] { ... }
export function getPlaygroundMessages(spaceId: string): ChatMessage[] { ... }
export function getPlaygroundMembers(spaceId: string): PlaygroundFriend[] { ... }
export function getPlaygroundPhotos(spaceId: string): string[] { ... }
export function isPlaygroundSpace(spaceId: string): boolean { ... }
```

- [ ] **Step 7: Commit**

```bash
git add src/lib/playground.ts
git commit -m "feat: playground data layer — 5 friends, 4 spaces, detection"
```

---

## Chunk 2: Whisper + Choreography Engine

### Task 2: Create PlaygroundWhisper component

**Files:**
- Create: `src/components/os/PlaygroundWhisper.tsx`

- [ ] **Step 1: Build the diegetic whisper**

A motion.span that:
- Renders inline (not overlay/tooltip)
- Weight 300, breathing opacity (30% → 60%, 4s infinite cycle)
- Accepts `text`, `visible`, `onDismiss` props
- Fades out smoothly when `visible` becomes false
- Uses Framer Motion `animate` for the breathing

```typescript
interface PlaygroundWhisperProps {
  text: string;
  visible: boolean;
  onDismiss?: () => void;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/os/PlaygroundWhisper.tsx
git commit -m "feat: PlaygroundWhisper — diegetic coaching with breathing opacity"
```

### Task 3: Create usePlaygroundChoreography hook

**Files:**
- Create: `src/hooks/usePlaygroundChoreography.ts`

- [ ] **Step 1: Define the choreography hook**

```typescript
interface ChoreographyState {
  whispers: Record<string, { text: string; visible: boolean }>;
  queuedMessages: ChatMessage[];
  typingIndicator: { name: string; visible: boolean } | null;
  tabBadge: { tab: string; text: string } | null;
  placeholderOverride: string | null;
}

export function usePlaygroundChoreography(
  spaceId: string,
  isPlayground: boolean
): ChoreographyState & {
  dismissWhisper: (key: string) => void;
  triggerPostVote: () => void;         // After user votes in Space 1
  triggerPostXark: () => void;         // After @xark search in Space 1/2
  triggerPostClaim: () => void;        // After user claims in Space 3
  triggerPostPurchase: () => void;     // After purchase confirm in Space 3
};
```

- [ ] **Step 2: Implement Space 1 choreography timers**

On mount (when spaceId is tokyo):
- `setTimeout 1500ms` → show "waiting on your vote..." whisper
- `triggerPostVote()`: clears vote whisper, queues @xark system message at +3s, shows "kai is typing..." at +5s, queues kai message at +6.5s, morphs placeholder at +7s
- All timeouts stored in ref array, cleaned up on unmount

- [ ] **Step 3: Implement Space 2 choreography**

On mount: `setTimeout 2000ms` → show "try @xark for ideas..." whisper (pulsing)
- `triggerPostXark()`: dismiss whisper, show "swipe to decide to vote" whisper below inline cards

- [ ] **Step 4: Implement Space 3 choreography**

On mount: `setTimeout 1500ms` → show "tap to claim this task" whisper on unclaimed item
- `triggerPostClaim()`: dismiss claim whisper, show "tap to add your share" whisper on purchased item
- `triggerPostPurchase()`: dismiss purchase whisper, show settlement result

- [ ] **Step 5: Implement Space 4 choreography**

On mount: `setTimeout 1500ms` → show "your adventures, always here" whisper
- Settlement view: show "all settled up" whisper

- [ ] **Step 6: Commit**

```bash
git add src/hooks/usePlaygroundChoreography.ts
git commit -m "feat: usePlaygroundChoreography — timer-based choreography engine for 4 spaces"
```

---

## Chunk 3: Galaxy Page Integration

### Task 4: Wire playground mode into Galaxy page

**Files:**
- Modify: `src/app/galaxy/page.tsx`
- Modify: `src/components/os/AwarenessStream.tsx`

- [ ] **Step 1: Detect playground mode in Galaxy**

In `GalaxyContent`, after `useAuth`:

```typescript
import { isPlaygroundMode, getPlaygroundSpaces } from "@/lib/playground";

// Inside the component, add state:
const [playgroundMode, setPlaygroundMode] = useState(false);
```

Pass `playgroundMode` and playground spaces data to `AwarenessStream` as props.

- [ ] **Step 2: Update AwarenessStream to accept playground spaces**

Add optional `playgroundSpaces` prop to AwarenessStream. When provided and real spaces are empty, render playground spaces instead. Playground space taps navigate with `?playground=true` query param.

The "tokyo neon nights" space should have a visual indicator — its awareness summary shows "94% — waiting on your vote" in amber to leverage the Zeigarnik effect.

- [ ] **Step 3: Verify playground vanishes**

When user creates a first real space (via dream input), `fetchAwareness` returns non-empty on next render → playground spaces disappear. No cleanup needed.

- [ ] **Step 4: Commit**

```bash
git add src/app/galaxy/page.tsx src/components/os/AwarenessStream.tsx
git commit -m "feat: Galaxy playground detection — 4 sandbox spaces for new users"
```

---

## Chunk 4: Space Page Playground Mode

### Task 5: Wire playground into Space page

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Detect playground mode from URL**

```typescript
const isPlayground = searchParams.get("playground") === "true";
```

- [ ] **Step 2: Load playground data instead of Supabase**

When `isPlayground`:
- `messages` state initialized from `getPlaygroundMessages(spaceId)`
- `items` loaded from `getPlaygroundItems(spaceId)`
- `members` from `getPlaygroundMembers(spaceId)`
- Skip all Supabase fetches and Realtime subscriptions
- Skip E2EE initialization

- [ ] **Step 3: Mock reaction handler**

```typescript
const [playgroundReactions, setPlaygroundReactions] = useState<Record<string, ReactionType>>({});

const handlePlaygroundReaction = (itemId: string, signal: ReactionType) => {
  if (playgroundReactions[itemId] === signal) {
    setPlaygroundReactions(prev => { const n = {...prev}; delete n[itemId]; return n; });
  } else {
    setPlaygroundReactions(prev => ({ ...prev, [itemId]: signal }));
  }
  // Trigger choreography callbacks
  choreography.triggerPostVote();
};
```

- [ ] **Step 4: Mock @xark handler**

When `isPlayground` and message contains `@xark`:
- Don't call `/api/xark` or `/api/message`
- Show thinking indicator for 2s
- Inject hardcoded restaurant cards into messages as inline previews
- Inject cards into playground items for the Decide tab
- Call `choreography.triggerPostXark()`

- [ ] **Step 5: Wire choreography hook**

```typescript
const choreography = usePlaygroundChoreography(spaceId, isPlayground);
```

Merge `choreography.queuedMessages` into the message display list. Pass `choreography.typingIndicator` to XarkChat. Pass `choreography.whispers` to relevant card/item positions.

- [ ] **Step 6: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: Space page playground mode — mock data, reactions, @xark, choreography"
```

---

## Chunk 5: Chat Integration + Inline Card Previews

### Task 6: Create InlineCardPreview component

**Files:**
- Create: `src/components/os/InlineCardPreview.tsx`

- [ ] **Step 1: Build miniature card for chat timeline**

A compact card (~120px tall, full chat width) showing:
- Photo thumbnail (left 30%), dark gradient, title + price + score on right
- Read-only (no reaction buttons)
- Tappable — triggers navigation to Decide tab or expand behavior
- Uses same color tokens as DecisionCard (CARD_TEXT, CARD_AMBER, etc.)

```typescript
interface InlineCardPreviewProps {
  title: string;
  imageUrl?: string;
  price?: string;
  score: number;
  onTap?: () => void;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/os/InlineCardPreview.tsx
git commit -m "feat: InlineCardPreview — miniature decision card for chat timeline"
```

### Task 7: Wire typing indicator + inline cards into XarkChat

**Files:**
- Modify: `src/components/os/XarkChat.tsx`

- [ ] **Step 1: Add typing indicator prop**

```typescript
interface XarkChatProps {
  // ... existing props
  typingIndicator?: { name: string; visible: boolean } | null;
  inlineCards?: Array<{ title: string; imageUrl?: string; price?: string; score: number }>;
}
```

Render typing indicator below messages when `visible`:
```
"kai is typing..." — weight 300, ink.tertiary, 1.5s display
```

- [ ] **Step 2: Render inline card previews in message stream**

When `inlineCards` is provided, render them after the last message as a group of InlineCardPreview components. Add a PlaygroundWhisper below: *"swipe to decide to vote"*.

- [ ] **Step 3: Commit**

```bash
git add src/components/os/XarkChat.tsx
git commit -m "feat: XarkChat typing indicator + inline card previews for playground"
```

---

## Chunk 6: Claim/Purchase + Settlement Polish

### Task 8: PurchaseSheet pre-fill support

**Files:**
- Modify: `src/components/os/PurchaseSheet.tsx`

- [ ] **Step 1: Add `prefillAmount` prop**

```typescript
interface PurchaseSheetProps {
  // ... existing props
  prefillAmount?: string; // e.g. "320"
}
```

When `prefillAmount` is provided:
- Input field starts with that value
- Show prominent one-tap button: "confirm $320" instead of generic "confirm"
- User can still edit if they want, but the one-tap path is dominant

- [ ] **Step 2: Commit**

```bash
git add src/components/os/PurchaseSheet.tsx
git commit -m "feat: PurchaseSheet prefillAmount for playground one-tap confirm"
```

### Task 9: Wire Space 3 claim + purchase choreography

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Playground claim handler**

When `isPlayground` and user claims an item:
- Update local state (mark item as claimed by user)
- Call `choreography.triggerPostClaim()`
- PlaygroundWhisper appears on the next item: *"tap to add your share"*

- [ ] **Step 2: Playground purchase handler**

When `isPlayground` and user confirms purchase:
- Update local state (mark item as purchased)
- Call `choreography.triggerPostPurchase()`
- Show settlement result inline: *"you owe leo $40"*

- [ ] **Step 3: Pass prefillAmount to PurchaseSheet**

When `isPlayground`, pass `prefillAmount="320"` to PurchaseSheet for the "dinner at nobu" item.

- [ ] **Step 4: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: playground claim + purchase flow with pre-filled amount and settlement"
```

---

## Chunk 7: Tab Bridging + Final Polish

### Task 10: Tab badge for cross-tab guidance

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Add tab badge state**

When choreography provides a `tabBadge` (e.g., `{ tab: "discuss", text: "new message from kai" }`), render a pulsing Action Orange dot on the specified tab label. The badge dismisses when the user switches to that tab.

- [ ] **Step 2: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: playground tab badge — cross-tab guidance for choreographed messages"
```

### Task 11: Space 4 memories + settlement view

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Playground memories data**

When `isPlayground` and spaceId is "weekend hike":
- Default to memories view (settled spaces already do this via `computeSpaceState`)
- Pass playground photo URLs to MemoriesTab
- Settlement shows $0 with "all settled up" whisper

- [ ] **Step 2: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: playground Space 4 — memories view + settled state"
```

### Task 12: End-to-end smoke test

- [ ] **Step 1: Clear all real spaces for test user**

Use a fresh user with no spaces to trigger playground mode.

- [ ] **Step 2: Verify Galaxy shows 4 playground spaces**

- "tokyo neon nights" with "94% — waiting on your vote" summary
- "dinner tonight" with "where should we eat?" summary
- "maya's birthday" with "2 items ready" summary
- "weekend hike" with "settled" summary

- [ ] **Step 3: Verify Space 1 flow**

Tap tokyo → see cards → see whisper → tap love → gold burst → kai types → kai message → @xark search → inline cards appear

- [ ] **Step 4: Verify Space 2 flow**

Tap dinner → see chat → see @xark whisper → type @xark → cyan text → send → thinking → inline cards → swipe to decide

- [ ] **Step 5: Verify Space 3 flow**

Tap maya → see itinerary → see claim whisper → tap claim → see purchase whisper → tap purchase → confirm $320 → see settlement

- [ ] **Step 6: Verify Space 4 flow**

Tap hike → see memories → see whisper → tap settlement → see $0

- [ ] **Step 7: Verify playground vanishes**

Create a real space via dream input → return to Galaxy → playground spaces gone, real space visible.

- [ ] **Step 8: Commit any fixes**

```bash
git commit -m "fix: playground smoke test fixes"
```

---

## Summary

| Chunk | Tasks | Files | What it delivers |
|-------|-------|-------|-----------------|
| 1 | Task 1 | playground.ts | All data: 5 friends, 4 spaces, detection |
| 2 | Tasks 2-3 | PlaygroundWhisper, usePlaygroundChoreography | Whisper component + choreography engine |
| 3 | Task 4 | galaxy/page.tsx, AwarenessStream | Galaxy detects + renders playground |
| 4 | Task 5 | space/[id]/page.tsx | Space loads playground data, mock reactions, mock @xark |
| 5 | Tasks 6-7 | InlineCardPreview, XarkChat | Chat inline cards + typing indicator |
| 6 | Tasks 8-9 | PurchaseSheet, space page | Claim + purchase with pre-fill |
| 7 | Tasks 10-12 | space page, smoke test | Tab badges, memories, final verification |

**Estimated tasks:** 12 tasks across 7 chunks
**New files:** 4 (playground.ts, usePlaygroundChoreography.ts, PlaygroundWhisper.tsx, InlineCardPreview.tsx)
**Modified files:** 6 (galaxy page, space page, AwarenessStream, XarkChat, PurchaseSheet)
