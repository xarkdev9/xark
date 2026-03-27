# Ghost Playground — First-Time User Experience

**Date**: 2026-03-16
**Status**: Design approved
**Author**: Ram + Claude

## Overview

A client-side sandbox that drops new users into 4 pre-loaded spaces with fake friends, diegetic coaching whispers, and frame-perfect choreography. Users discover every Xark feature by playing — not by reading tutorials. The playground vanishes the moment they create their first real space or get invited to one.

## Core Principles

1. **Zeigarnik Effect** — Incomplete states (94% consensus) compel interaction
2. **Diegetic Whispers** — Coaching appears as environmental text, not tooltip overlays
3. **Dopamine Payoffs** — Every interaction triggers an immediate reward (gold burst, card dealing, settlement resolution)
4. **Discovery, Not Instruction** — Users feel like they found the features, not that they were taught

## Detection & Lifecycle

```
isPlayground = fetchAwareness() returns [] AND fetchPersonalChats() returns []
```

- Playground renders when user has zero real spaces
- First real space creation or invite acceptance → playground vanishes forever
- No database records, no cleanup needed — pure conditional render
- No flag stored — computed fresh each mount

## The 5 Friends

| Name | Letter | Role | Appears In |
|------|--------|------|-----------|
| leo | L | The planner — finds places, books things | tokyo, dinner, maya's |
| kai | K | The enthusiast — "yes!! let's do it" | tokyo, dinner, hike |
| ava | A | The practical one — "what's the budget?" | tokyo, maya's, hike |
| zoe | Z | The spontaneous one — "just book it" | dinner, maya's |
| sam | S | The quiet voter — reacts but rarely chats | tokyo, hike |

Friends appear in groups of 3-4 per space (never all 5) to feel like natural subsets of a friend group.

**Presence indicators**: Before choreographed messages appear, show "{name} is typing..." for 1.5s. Trains users to expect multiplayer presence.

## Space 1: "tokyo neon nights" (The Hook)

**Stage**: Decide — 94% consensus on top hotel
**Members**: leo, kai, ava, sam + user
**Goal**: Teach voting, consensus, gold burst, @xark search

### Pre-loaded Data

- Hero: Tokyo cityscape (deterministic from hero pool)
- 3 hotel cards:
  - "park hyatt tokyo" — 94% consensus, $650/nt, Unsplash photo (seeking amber glow)
  - "andaz tokyo" — 60% consensus, $420/nt
  - "hoshinoya tokyo" — 30% consensus, $380/nt
- Chat (6 messages):
  1. leo: "found a few hotels for tokyo"
  2. kai: "park hyatt looks incredible"
  3. ava: "is it in budget though?"
  4. leo: "it's worth it for the views"
  5. sam reacted love to park hyatt (system)
  6. kai: "just need your vote"

### Choreography (on first tap into space)

| Time | Event |
|------|-------|
| 0ms | Cards drift in (normal entrance stagger) |
| 1500ms | Diegetic whisper above "love" button: *"waiting on your vote..."* (weight 300, 20% opacity) |
| User taps "love" | 94% rolls to 100% → Social Gold burst → card locks |
| +3000ms (after burst) | @xark whisper in chat: *"everyone agreed. park hyatt is locked."* |
| +5000ms | If user is on Decide tab: pulse Action Orange badge on "DISCUSS" tab with whisper *"new message from kai"* |
| +5000ms | "kai is typing..." indicator (1.5s) |
| +6500ms | kai message: *"what about dinner?"* |
| +7000ms | Input placeholder morphs to: *"suggest a place, or ask @xark..."* |
| User types "@xark sushi" | Text turns cyan → thinking → 3 restaurant cards deal into chat as inline previews, then auto-glide to Decide tab after 2s |

### Exit State

User has learned: card voting, consensus mechanics, gold burst reward, @xark search invocation, intelligence cyan feedback.

## Space 2: "dinner tonight" (The Magic Trick)

**Stage**: Discuss — fresh conversation, no decision items yet
**Members**: zoe, leo, kai + user
**Goal**: Teach @xark invocation, chat-to-decide flow

### Pre-loaded Data

- No decision items (Decide tab empty)
- Chat (2 messages):
  1. zoe: "where should we eat?"
  2. leo: "somewhere walkable"

### Choreography

| Time | Event |
|------|-------|
| 0ms | Chat renders with 2 messages |
| 2000ms | Input whisper (pulsing 20-30% opacity over 4s): *"try @xark for ideas..."* |
| User types "@xark" | Magnetic Input: text turns cyan with glow shadow |
| User sends "@xark [query]" | Thinking indicator → 3 restaurant cards appear as inline miniature previews in chat timeline |
| After cards render | Inline previews stay permanently in chat as read-only snapshots. Whisper below: *"swipe to decide to vote"*. Tapping a preview expands to full card. |
| User swipes to Decide | Full cards are there, ready to vote |

### Why Inline-First

Forcing a manual tab swipe breaks flow. The answer to a chat question should appear in the chat. Inline card previews (miniature DecisionCards in the message stream) show the result where the user asked, then migrate to the proper Decide view.

### Exit State

User has learned: @xark is the AI trigger, chat and decisions are connected, tab switching.

## Space 3: "maya's birthday" (The Friction Killer)

**Stage**: Ready — items locked, one claimed, one unclaimed
**Members**: leo, ava, zoe + user
**Goal**: Teach claiming, purchase entry, settlement

### Pre-loaded Data

- Itinerary view (ready/active spaces show itinerary):
  - "dinner at nobu" — locked 100%, claimed by leo, purchased $320
  - "surprise cake" — locked 100%, unclaimed
- Chat (4 messages):
  1. ava: "i'll get the cake"
  2. leo: "nobu is booked for 8pm"
  3. zoe: "this is going to be so good"
  4. leo: "dinner was $320, splitting 4 ways"

### Choreography

| Time | Event |
|------|-------|
| 0ms | Itinerary renders with 2 locked items |
| 1500ms | Diegetic whisper on "surprise cake": *"tap to claim this task"* |
| User taps cake | ClaimSheet slides up → user taps "i'll handle this" |
| After claim | Whisper on "dinner at nobu": *"tap to add your share"* |
| User taps nobu | PurchaseSheet slides up with **pre-filled $320** and single-tap "confirm $320" button |
| User confirms | Settlement preview: *"you owe leo $40"* with venmo/upi deep links |

### Pre-filled Purchase

No keyboard entry during onboarding. PurchaseSheet opens with amount pre-populated and a prominent one-tap confirm. The goal is to show the settlement mechanic, not test data entry. Real usage will have the input field.

### Exit State

User has learned: claiming ownership, purchase confirmation, settlement math, payment links.

## Space 4: "weekend hike" (The Afterglow)

**Stage**: Settled — completed, all paid
**Members**: kai, ava, sam + user
**Goal**: Prove Xark has permanent value beyond planning

### Pre-loaded Data

- Memories tab (default view for settled spaces): 6 photos (hiking trail, campfire, sunset, group selfie, mountain vista, packed car)
- Itinerary: 3 completed items with checkmarks
- Settlement: $0 outstanding, all settled
- Chat (5 messages):
  1. kai: "that sunrise was unreal"
  2. ava: "we need to do this again"
  3. sam: "best weekend in a while"
  4. kai: "next time let's try camping"
  5. ava: "already planning it"

### Choreography

| Time | Event |
|------|-------|
| 0ms | Opens to Memories tab (settled spaces default) |
| 1500ms | Whisper below photos: *"your adventures, always here"* |
| User taps Discuss | Chat history visible |
| User taps settlement | Clean $0 display — whisper: *"all settled up"* |

### Exit State

User has learned: Xark is a permanent scrapbook + ledger, not a disposable planning tool.

## Architecture

### File: `src/lib/playground.ts`

Single source of truth for all playground data.

```typescript
export const PLAYGROUND_FRIENDS = { leo, kai, ava, zoe, sam };
export const PLAYGROUND_SPACES: PlaygroundSpace[] = [...]; // 4 spaces
export function isPlaygroundMode(realSpaces: any[], realChats: any[]): boolean;
export function getPlaygroundSpaces(): SpaceAwareness[];
export function getPlaygroundItems(spaceId: string): DecisionItem[];
export function getPlaygroundMessages(spaceId: string): ChatMessage[];
export function getPlaygroundMembers(spaceId: string): Member[];
```

### No New Components

Existing production components render playground data:
- `PossibilityHorizon` + `DecisionCard` — same cards, playground items
- `XarkChat` — same chat stream, playground messages
- `ClaimSheet` + `PurchaseSheet` — same sheets, playground items
- `MemoriesTab` — same grid, playground photos

### Mock Layer

```typescript
// In Space page, when isPlayground:
const handleReaction = (itemId, signal) => {
  // Update local state only — no Supabase RPC
  setPlaygroundReactions(prev => ({ ...prev, [itemId]: signal }));
  // Trigger choreography (gold burst, whisper, etc.)
};
```

### Choreography Engine

```typescript
// usePlaygroundChoreography(spaceId) hook
// Returns: { whispers, queuedMessages, typingIndicator }
// Uses useEffect timers for frame-perfect sequencing
// All timers cleaned up on unmount
```

### Whisper Rendering

Whispers are NOT tooltip overlays. They render as:
- Inline text elements positioned near their trigger
- Weight 300, breathing animation (opacity 30% → 60% over 4s, infinite)
- Same font system as all other Xark text (Inter, theme-aware)
- Dismissed on first relevant interaction (tap vote, type @xark, etc.)
- 35-40% base opacity — visible in daylight on mobile, still environmental not alerting

### Galaxy Page Integration

```typescript
// In Galaxy page:
const realSpaces = await fetchAwareness(userId);
const realChats = await fetchPersonalChats(userId);

if (isPlaygroundMode(realSpaces, realChats)) {
  // Render playground spaces in AwarenessStream
  // Playground spaces have special onTap → navigate to space with ?playground=true
} else {
  // Normal render
}
```

### Space Page Integration

```typescript
// In Space page:
const isPlayground = searchParams.get("playground") === "true";

if (isPlayground) {
  // Load from playground.ts instead of Supabase
  // Mock reactions (local state)
  // Enable choreography timers
  // @xark queries return hardcoded results (no Gemini API call)
}
```

## What This Does NOT Include

- No database records for playground data
- No new visual components (reuses all production components)
- No guided overlay/modal tutorial system
- No "skip tutorial" button (there's nothing to skip — it's just spaces)
- No analytics tracking of playground interactions (v2)
- No multi-device sync of playground state (it's ephemeral local state)

## Success Criteria

1. New user lands on Galaxy → sees 4 spaces, taps "tokyo neon nights" within 10 seconds
2. User completes voting flow (tap love → gold burst) within 30 seconds of entering space 1
3. User invokes @xark at least once during playground session
4. User sees settlement flow (claim → purchase → "you owe") in space 3
5. Playground vanishes cleanly when first real space is created — no phantom data, no cleanup
