# Xark Universal Decision Engine — Technical Decision Record

**Date**: March 10, 2026
**Status**: Complete — 198 tests, 0 type errors, hexagonal architecture
**Document Purpose**: Capture every decision, rationale, compatibility detail, and architectural trade-off made during the design and implementation of the Xark consensus engine.

---

## Table of Contents

1. [Evolution Timeline](#1-evolution-timeline)
2. [Core Philosophy & Design Principles](#2-core-philosophy--design-principles)
3. [Type System Decisions](#3-type-system-decisions)
4. [Signal System (Reaction Vocabulary)](#4-signal-system-reaction-vocabulary)
5. [Weighted Heart-Sort Algorithm](#5-weighted-heart-sort-algorithm)
6. [State Machine Architecture](#6-state-machine-architecture)
7. [Green-Lock Commitment Protocol](#7-green-lock-commitment-protocol)
8. [AI Grounding Constraint System](#8-ai-grounding-constraint-system)
9. [Task Assignment System](#9-task-assignment-system)
10. [Hexagonal Architecture (Ports & Adapters)](#10-hexagonal-architecture-ports--adapters)
11. [Service Layer (Planet-Scale)](#11-service-layer-planet-scale)
12. [Request Handler (Framework-Agnostic HTTP)](#12-request-handler-framework-agnostic-http)
13. [Backwards Compatibility Strategy](#13-backwards-compatibility-strategy)
14. [Optimistic Concurrency](#14-optimistic-concurrency)
15. [Cache Strategy](#15-cache-strategy)
16. [Event System](#16-event-system)
17. [Error Taxonomy](#17-error-taxonomy)
18. [File-by-File Reference](#18-file-by-file-reference)
19. [Testing Strategy](#19-testing-strategy)
20. [What This Project Is and Is Not](#20-what-this-project-is-and-is-not)

---

## 1. Evolution Timeline

The codebase evolved through three distinct phases in a single session:

### Phase 1: Semantic Signals (Emoji → Language)

**Problem**: The original engine used emoji reactions (❤️ = `Heart`, 👍 = `ThumbsUp`) with only two signal types (positive or neutral). No way to express resistance.

**Decision**: Replace emojis with human-language signals and add a negative signal.

| Before | After | Weight |
|--------|-------|--------|
| ❤️ `Heart` | "Love it" `LoveIt` | +5 |
| 👍 `ThumbsUp` | "Works for me" `WorksForMe` | +1 |
| *(none)* | "Not for me" `NotForMe` | **-3** |

**Rationale for -3 weight**: One concern cancels exactly three "Works for me" signals (`-3 + 1 + 1 + 1 = 0`). Two "Love it" signals overcome one concern (`5 + 5 - 3 = 7`). This makes resistance meaningful but not an absolute veto — it's a brake, not a wall.

**State rename**: `heart_sorted` → `ranked` in the default `BOOKING_FLOW`. The term "heart-sorted" was too tied to the emoji metaphor. "Ranked" is domain-agnostic and describes what actually happened (items were ranked by weighted score).

**Color mapping** (Xark Neuro Color System):
- Seeking Amber (`#f5a623`) for "Love it"
- Neutral Gray (`#8888a0`) for "Works for me"
- Action Orange (`#e8590c`) for "Not for me"
- Lock Green (`#2ecc40`) — rare, only on commitment (the "green lock")
- Social Gold burst — triggered when all members signal "Love it" (`isUnanimousLoveIt`)

### Phase 2: HTML Demo Updates

**Problem**: Two HTML demo files (`demo.html`, `demo-live.html`) had inline JavaScript engines that used the old emoji vocabulary and two-button UI.

**Decision**: Update both demos to match the new semantic signals. Three buttons instead of two. CSS variables for the Neuro Color System. State labels updated to "ranked".

**Rationale**: The demos are standalone prototypes (no build step, no TypeScript). They re-implement a tiny version of the engine in inline `<script>` tags. Keeping them in sync with the TypeScript engine ensures visual consistency.

### Phase 3: Domain-Agnostic Cleanup

**Problem**: The codebase was littered with booking/travel-specific naming: `BookableItem`, `bookingProof`, `groupId`, `"locked_booking"`. This made it conceptually wrong to use the engine for cars, weddings, daycare, shopping, or any non-booking domain.

**Decision**: Make `DecisionItem` the primary interface. Keep `BookableItem` as a backwards-compat type alias. Rename `bookingProof` → `commitmentProof`, `groupId` → `spaceId`, `"locked_booking"` → `"locked_decision"`.

**Implementation strategy — dual fields**:
```typescript
// Primary: domain-agnostic
export interface DecisionItem {
  spaceId: SpaceId;
  commitmentProof: CommitmentProof | null;
  // ...
}

// Backwards compat: adds old field names
export type BookableItem = DecisionItem & {
  /** @deprecated Use spaceId */
  groupId: GroupId;
  /** @deprecated Use commitmentProof */
  bookingProof: BookingProof | null;
};
```

Items carry **both field sets**. Both point to the same data. This means:
- Old code reading `item.groupId` still works
- New code reading `item.spaceId` also works
- Both are always in sync (set at creation time)

### Phase 4: Planet-Scale Architecture

**Problem**: All state lived in JavaScript `Map` objects inside `ConsensusEngine`. Data was lost on process restart. No multi-user sync. No auth. No caching. Not deployable as a service.

**Decision**: Build a full hexagonal architecture with ports (interfaces), adapters (implementations), and a stateless service layer. Keep `ConsensusEngine` as-is for embedded/testing use.

**Key architectural choice**: The `DecisionService` does NOT wrap `ConsensusEngine`. Instead, it uses the **pure functions** directly (`addReaction`, `commitItem`, `heartSort`, etc.) and wires them to persistence. This avoids state duplication — the service loads from DB, computes, saves back.

---

## 2. Core Philosophy & Design Principles

### "No gates. No votes. No clustering. Just signal → act → lock."

The engine deliberately avoids:
- **Voting** — there's no quorum, no majority threshold, no "X out of Y must agree". Anyone can lock at any time.
- **Gates** — there's no approval workflow. No one blocks anyone. Reactions inform, they don't control.
- **Clustering** — there's no algorithm grouping people by preference. Everyone sees the same ranked list.

The flow is:
1. **Signal** — react with "Love it" / "Works" / "Not for me"
2. **Act** — someone commits in the real world (books, buys, decides)
3. **Lock** — provide proof → engine locks, stamps owner, AI respects it

### Pure Functions for Engine Logic

Every computation function is pure: no mutation, no side effects, always returns a new object.

```typescript
// Never this:
item.reactions.push(reaction);
item.weightedScore = calculateScore(item.reactions);

// Always this:
const updated = addReaction(item, userId, type, timestamp);
// `item` is unchanged, `updated` is a new object
```

**Rationale**:
- Testability: pure functions are trivially testable
- Concurrency safety: no shared mutable state
- Time-travel debugging: every state is a snapshot
- Composability: functions can be chained without side effects

### Domain Agnosticism

The engine has zero knowledge of what is being decided. `category` is an open string — "hotel", "sedan", "daycare", "venue", "stock", anything. The engine only cares about:
- Signals (reactions with weights)
- Score (sum of weights)
- Rank (sorted by score)
- Lock (commitment with proof)
- Ownership (who committed)

---

## 3. Type System Decisions

### ID Types

```typescript
export type UserId = string;
export type GroupId = string;
export type SpaceId = string;
export type ItemId = string;
export type TaskId = string;
```

All are `string` aliases. TypeScript doesn't have nominal types natively, but branded strings provide documentation and intent. Runtime IDs are prefixed: `item_${uuid}`, `space_${uuid}`, `task_${uuid}`.

**Decision**: Use `crypto.randomUUID()` for all IDs.
**Rationale**: Globally unique, no counter coordination, no collisions across distributed nodes.

### DecisionItem vs. BookableItem

```typescript
// Primary: domain-agnostic
export interface DecisionItem {
  id: ItemId;
  spaceId: SpaceId;
  title: string;
  description: string;
  category: string;             // Open string, not an enum
  state: DecisionItemState;     // Open string, allows custom states
  proposedBy: UserId;
  proposedAt: number;
  reactions: Reaction[];
  weightedScore: number;
  commitmentProof: CommitmentProof | null;
  ownership: OwnershipRecord | null;
  ownershipHistory: OwnershipRecord[];
  lockedAt: number | null;
  version: number;              // For optimistic concurrency
  metadata: Record<string, unknown>; // Extensible
}

// Backwards compat: adds deprecated fields
export type BookableItem = DecisionItem & {
  /** @deprecated Use spaceId instead */
  groupId: GroupId;
  /** @deprecated Use commitmentProof instead */
  bookingProof: BookingProof | null;
};
```

**Decision**: `BookableItem` is a type alias (not a separate interface) that extends `DecisionItem`.
**Rationale**: The `&` intersection means any `BookableItem` is also a `DecisionItem`. Old code that accepts `BookableItem` still works. New code can use `DecisionItem`. Both views see the same object.

**Why not just rename?** Too many existing tests, imports, and potential external consumers. The alias approach means zero breaking changes.

### DecisionItemState

```typescript
export type DecisionItemState = string;
```

**Decision**: Open string type, not a closed enum.
**Rationale**: Custom state flows use arbitrary state names ("researching", "shortlisted", "negotiating", "purchased"). A closed enum would break extensibility.

The `BookableItemState` enum exists for the default flow's states:
```typescript
export enum BookableItemState {
  Proposed = "proposed",
  Ranked = "ranked",
  Locked = "locked",
  // Deprecated alias
  HeartSorted = "heart_sorted",
}
```

### CommitmentProof

```typescript
export interface CommitmentProof {
  type: string;          // "confirmation_number", "screenshot", "receipt", "contract", "verbal"
  value: string;         // The proof itself
  submittedBy: UserId;   // Who provided it
  submittedAt: number;   // When (timestamp ms)
}
export type BookingProof = CommitmentProof; // Backwards compat alias
```

**Decision**: `type` is an open string, not an enum.
**Rationale**: Different domains have different proof types. A hotel has confirmation numbers. A car purchase has VINs. A verbal agreement has... "verbal". The engine doesn't validate proof format — it just stores it.

### OwnershipRecord

```typescript
export interface OwnershipRecord {
  ownerId: UserId;
  assignedAt: number;
  reason: "booker" | "transfer";
}
```

**Decision**: `reason` is a closed union type.
**Rationale**: Only two ways to become an owner — original commitment ("booker") or transfer ("I'll take care of this"). No other mechanism exists. This is intentionally restrictive.

### SpaceConfig

```typescript
export interface SpaceConfig {
  reactionWeights: Record<string, number>;
  groupFavoriteThreshold: number;    // Default: 80 (strictly >80%)
  allowSelfReaction: boolean;        // Default: false
  requireProofForLock: boolean;      // Default: true
}
```

**Decision**: `reactionWeights` is `Record<string, number>`, not `Record<ReactionType, number>`.
**Rationale**: Allows custom reaction types beyond the three defaults. A space could define `{ "love_it": 10, "works_for_me": 2, "not_for_me": -5, "urgent": 20 }`.

### DecisionSpace

```typescript
export interface DecisionSpace {
  id: SpaceId;
  name: string;
  members: GroupMember[];
  config: SpaceConfig;
  flow?: {
    name: string;
    initialState: string;
    lockedState: string;
    transitions: Array<{
      from: string;
      to: string;
      trigger: "reaction" | "commitment" | "manual";
    }>;
  };
  createdAt: number;
}
```

**Decision**: `flow` is optional and inline (not a reference to `StateFlowConfig`).
**Rationale**: `types.ts` must not import from `engine/` (dependency direction: engine imports types, not the other way). The inline type is structurally compatible with `StateFlowConfig` but avoids the circular dependency. If omitted, `BOOKING_FLOW` is used as default.

### EngineEvent

```typescript
export interface EngineEvent {
  type: EventType;
  timestamp: number;
  groupId: GroupId;   // Still uses groupId for backwards compat
  actorId: UserId;
  payload: Record<string, unknown>;
}
```

**Decision**: `payload` is `Record<string, unknown>`, not typed per event.
**Rationale**: Simplicity. Event consumers pattern-match on `type` and cast `payload` as needed. A discriminated union would be more type-safe but would significantly increase the type surface area for minimal practical benefit.

---

## 4. Signal System (Reaction Vocabulary)

### ReactionType Enum

```typescript
export enum ReactionType {
  LoveIt = "love_it",
  WorksForMe = "works_for_me",
  NotForMe = "not_for_me",
  // Deprecated aliases — same string values
  Heart = "love_it",
  ThumbsUp = "works_for_me",
}
```

**TypeScript enum with duplicate values**: TypeScript allows two enum members to have the same string value. The reverse mapping (number enums only) would point to the last-declared one, but since these are string enums (no reverse mapping), both work interchangeably.

**Verification**: `ReactionType.Heart === ReactionType.LoveIt` is `true` (both are `"love_it"`).

### REACTION_WEIGHTS

```typescript
export const REACTION_WEIGHTS: Record<string, number> = {
  [ReactionType.LoveIt]: 5,
  [ReactionType.WorksForMe]: 1,
  [ReactionType.NotForMe]: -3,
};
```

**Weight rationale**:

| Signal | Weight | Reasoning |
|--------|--------|-----------|
| Love it | +5 | Strong positive signal. 3 passionate users (15) beat 4 lukewarm users (4). |
| Works for me | +1 | Neutral/acceptable. Low weight — "I'm fine with it" shouldn't dominate. |
| Not for me | -3 | Meaningful brake. One concern cancels three "Works". Two "Love it"s overcome one concern (5+5-3=7). |

**Mathematical properties**:
- One `NotForMe` cancels exactly three `WorksForMe`: `1 + 1 + 1 + (-3) = 0`
- Two `LoveIt` beats one `NotForMe`: `5 + 5 + (-3) = 7`
- Score can go negative (items with more concerns than support sink to bottom)
- Passionate minority (3 hearts = 15) beats lukewarm majority (4 thumbs = 4)

### Reaction Deduplication

One reaction per user per item. Last reaction wins.

```typescript
const userReactions = new Map<UserId, ReactionType>();
for (const reaction of reactions) {
  userReactions.set(reaction.userId, reaction.type);
}
```

**Rationale**: Users can change their mind. If Alice first says "Works" then later says "Love it", only "Love it" counts. This is simpler than tracking reaction history and more aligned with UX expectations.

---

## 5. Weighted Heart-Sort Algorithm

### Core Algorithm

**Performance**: O(1) per reaction update (just add/replace in array and sum), O(n log n) for full sort.

**Sort order**: Descending by `weightedScore`. Ties broken by earliest `proposedAt` (first proposed wins).

```typescript
export function heartSort(items: BookableItem[]): BookableItem[] {
  return [...items].sort((a, b) => {
    if (b.weightedScore !== a.weightedScore) {
      return b.weightedScore - a.weightedScore;
    }
    return a.proposedAt - b.proposedAt; // Earlier proposal wins ties
  });
}
```

**Decision**: Tie-break by `proposedAt` ascending.
**Rationale**: First-mover advantage for equal scores. Prevents random ordering when multiple items have the same score.

### Agreement Score

```typescript
export function calculateAgreementScore(
  item: BookableItem,
  totalMembers: number,
  threshold?: number
): { percentage: number; isGroupFavorite: boolean }
```

**Decision**: Count **all** reactors (including `NotForMe`), not just positive.
**Rationale**: If someone says "Not for me", they still engaged with the item. The agreement score measures engagement, not approval. `isGroupFavorite` is true when percentage **strictly exceeds** the threshold (default 80%).

**Edge case**: `isGroupFavorite` at exactly 80% returns `false`. This is intentional — `> 80%`, not `>= 80%`.

### Ranked Summary

The `getRankedSummary()` function returns a rich breakdown:

```typescript
reactionBreakdown: {
  loveIt: number;
  worksForMe: number;
  notForMe: number;
  // Backwards compat aliases
  hearts: number;    // === loveIt
  thumbsUp: number;  // === worksForMe
}
```

**Decision**: Dual naming in breakdown (new names + old aliases).
**Rationale**: Frontend code might use `hearts` or `loveIt`. Both work. No migration needed.

---

## 6. State Machine Architecture

### StateFlowConfig

```typescript
export interface StateTransition {
  from: string;
  to: string;
  trigger: "reaction" | "commitment" | "manual";
}

export interface StateFlowConfig {
  name: string;
  initialState: string;
  lockedState: string;
  transitions: StateTransition[];
}
```

**Decision**: Three trigger types only.
**Rationale**:
- `"reaction"` — triggered when a user signals (automated)
- `"commitment"` — triggered when a user provides proof (intentional)
- `"manual"` — triggered explicitly (for multi-step flows like `PURCHASE_FLOW`)

### StateMachine Class

Builds an O(1) lookup map from transitions: key = `"${from}:${trigger}"`, value = `StateTransition`.

```typescript
transition(state: string, trigger: string): string | null
```

Returns `null` if no transition defined for the given state+trigger combination. This is a **permissive** design — unknown transitions are silently ignored rather than throwing.

**Rationale**: Prevents crashes when a reaction is added to an item in a state that doesn't have a "reaction" trigger. The engine just keeps the current state.

### Four Preset Flows

**BOOKING_FLOW** (default):
```
proposed → [reaction] → ranked → [commitment] → locked
proposed → [commitment] → locked  (skip ranking)
```

**PURCHASE_FLOW**:
```
researching → [reaction] → shortlisted → [manual] → negotiating → [commitment] → purchased
researching → [commitment] → purchased  (impulse buy)
shortlisted → [commitment] → purchased  (skip negotiation)
```

**SIMPLE_VOTE_FLOW**:
```
nominated → [reaction] → ranked → [commitment] → chosen
nominated → [commitment] → chosen  (skip ranking)
```

**SOLO_DECISION_FLOW**:
```
considering → [reaction] → leaning → [commitment] → decided
considering → [commitment] → decided  (just decide)
```

**Design pattern**: Every flow allows skipping intermediate states via direct `[commitment]` trigger from initial state. This handles the "just lock it" scenario without requiring reactions first.

---

## 7. Green-Lock Commitment Protocol

### Core Principle

"Lock = real-world commitment confirmation, not a vote."

Once someone books a hotel (confirmation number), buys a car (VIN), or signs a contract (screenshot), the engine locks the item. This is not a preference — it's a fact. The AI respects facts.

### commitItem vs. lockItem

```typescript
// New: state-machine-aware
export function commitItem(
  item: BookableItem,
  proof: CommitmentProof,
  stateMachine: StateMachine
): BookableItem

// Legacy: hardcoded to BookableItemState.Locked
export function lockItem(
  item: BookableItem,
  bookingProof: CommitmentProof
): BookableItem
```

**Decision**: Keep both. `commitItem` is the primary API for new code. `lockItem` is deprecated but still works.
**Rationale**: `commitItem` uses the state machine to determine the locked state (could be "purchased", "chosen", "decided" depending on the flow). `lockItem` hardcodes to `"locked"`.

### Ownership Model

On lock:
1. Committer is stamped as owner: `{ ownerId, assignedAt, reason: "booker" }`
2. Owner is added to `ownershipHistory`

On transfer ("I'll take care of this"):
1. New owner replaces current: `{ ownerId, assignedAt, reason: "transfer" }`
2. New owner is appended to `ownershipHistory`

**Decision**: `ownershipHistory` is append-only.
**Rationale**: Full audit trail. Can always see who owned the item and when.

### Validation Rules

- Cannot lock an already-locked item → `GreenLockError`
- Cannot lock with empty/whitespace proof → `GreenLockError`
- Cannot transfer a non-locked item → `GreenLockError`
- Cannot transfer to current owner (self-transfer) → `GreenLockError`
- Cannot react to a locked item → generic `Error`

### Dual Proof Fields

On lock, the engine sets **both** `commitmentProof` and `bookingProof` to the same object:

```typescript
return {
  ...item,
  commitmentProof: proof,
  bookingProof: proof,  // Backwards compat
  // ...
};
```

**Rationale**: Old code reading `item.bookingProof` still works. New code reading `item.commitmentProof` also works. Both reference the same object.

---

## 8. AI Grounding Constraint System

### Purpose

When @xark (the AI assistant) generates suggestions for a group, it must respect locked decisions. If the group booked the Hilton in San Diego, @xark should not suggest hotels in LA.

### GroundingConstraint Types

```typescript
interface GroundingConstraint {
  type: "locked_decision" | "assigned_task";
  itemId: string;
  title: string;
  category: string;
  description: string;
  ownerId: string;
}
```

**Decision**: Two constraint types only.
**Rationale**:
- `"locked_decision"` — items that have been committed (booked, purchased, decided)
- `"assigned_task"` — tasks that have been claimed ("I'll bring sunscreen")

Both are facts the AI must not contradict.

**Previous value**: `"locked_booking"` was renamed to `"locked_decision"` during the domain-agnostic cleanup. This is a breaking change for any code that compared against the string literal.

### Prompt Generation

```typescript
export function generateGroundingPrompt(context: GroundingContext): string
```

When locked decisions exist, generates:
```
=== GROUNDING CONSTRAINTS ===
You MUST respect these confirmed decisions. They are FINAL.
Do NOT suggest alternatives to these — they are committed.

[LOCKED DECISION] Hotel: Hilton San Diego
  Owner: carol
  Do NOT suggest alternatives for "hotel".

[ASSIGNED TASK] Bring sunscreen
  Assigned to: bob
  This task is being handled.
```

When no locked decisions exist:
```
No locked decisions yet. You may suggest any options freely.
```

### Conflict Detection

```typescript
export function checkSuggestionConflicts(
  context: GroundingContext,
  suggestionCategory: string
): GroundingConstraint[]
```

Returns locked decisions in the same category. If you try to suggest a "hotel" and there's already a locked hotel, this returns the conflict.

**Use case**: An AI agent calls this before generating suggestions to avoid wasting tokens on conflicting recommendations.

---

## 9. Task Assignment System

### Design Philosophy

Tasks are "non-decidable" items. You don't need consensus on "who brings the speaker" — someone just claims it.

No proof required. No reactions. No ranking. Just: Created → Assigned.

### Functions

```typescript
createTask(groupId, title, description, createdBy, timestamp): Task
assignTask(task, assigneeId, timestamp): Task
reassignTask(task, newAssigneeId, timestamp): Task
unassignTask(task): Task
resetTaskCounter(): void  // DEPRECATED — no-op
```

**Decision**: `reassignTask` validates against self-reassignment.
**Rationale**: If Bob already owns the task, "reassigning" to Bob is a no-op that indicates a bug. Better to throw.

**Decision**: `resetTaskCounter()` is a no-op.
**Rationale**: Tasks originally used an incrementing counter for IDs. After the UUID migration, the counter is meaningless. The function is kept for backwards compat (old test setup code calls it).

---

## 10. Hexagonal Architecture (Ports & Adapters)

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Any Transport Layer                                         │
│  Express, Fastify, Hono, Lambda, Cloudflare Workers, etc.   │
│                                                              │
│  Your framework code converts native requests into           │
│  ServiceRequest and calls handler.handle()                   │
├──────────────┬──────────────────────────────────────────────┤
│              │                                               │
│  RequestHandler (framework-agnostic router)                  │
│  Maps { method, path, body, token } → { status, body }      │
│              │                                               │
├──────────────┼──────────────────────────────────────────────┤
│              │                                               │
│  DecisionService (stateless orchestrator)                    │
│  Load from DB → Compute (pure functions) → Save → Broadcast │
│              │                                               │
│  Dependency injection: all I/O through ports                │
│              │                                               │
├──────────────┼──────────────────────────────────────────────┤
│              │                                               │
│  ┌───────────┴────────────┐                                  │
│  │   PORTS (interfaces)   │                                  │
│  │                        │                                  │
│  │  PersistencePort  ─────┼──→  MemoryPersistenceAdapter     │
│  │                        │     PostgresAdapter (build yours)│
│  │                        │     MongoAdapter (build yours)   │
│  │                        │     DynamoDBAdapter (build yours)│
│  │                        │                                  │
│  │  EventBusPort     ─────┼──→  MemoryEventBusAdapter        │
│  │                        │     RedisEventBusAdapter          │
│  │                        │     NatsEventBusAdapter           │
│  │                        │     WebSocketAdapter              │
│  │                        │                                  │
│  │  AuthPort         ─────┼──→  NoopAuthAdapter              │
│  │                        │     JwtAuthAdapter                │
│  │                        │     FirebaseAuthAdapter           │
│  │                        │     SupabaseAuthAdapter           │
│  │                        │                                  │
│  │  CachePort        ─────┼──→  MemoryCacheAdapter           │
│  │                        │     RedisCacheAdapter             │
│  │                        │                                  │
│  │  MessagingPort    ─────┼──→  PlaintextMessagingAdapter    │
│  │                        │     SlackMessagingAdapter         │
│  │                        │     DiscordMessagingAdapter       │
│  │                        │     TelegramMessagingAdapter      │
│  └────────────────────────┘                                  │
└─────────────────────────────────────────────────────────────┘
```

### Port Design Decisions

**PersistencePort**: Async CRUD with `getAllSpaces()` (not in legacy `PersistenceAdapter`). Adapters SHOULD check `version` field and throw `VersionConflictError`.

**EventBusPort**: Channel-based pub/sub. Optional `publishMany()` for multi-channel broadcast. Channel convention: `"space:{spaceId}"`.

**AuthPort**: Two-step (authenticate then authorize). 10 granular action types. `Identity` has extensible `metadata` for provider-specific fields.

**CachePort**: Optional — service works without it. `deleteByPrefix()` for bulk invalidation. No `getAll()` — cache is a cache, not a database.

**MessagingPort**: Format (outgoing) + Parse (incoming). `richContent?: unknown` for platform-specific payloads (Slack blocks, Discord embeds). The port handles format/parse — transport (sending the message) is the platform SDK's job.

### Adapter Design Decisions

All reference adapters are:
- Zero-dependency (no npm packages)
- In-memory (no I/O)
- Documented with what to replace them with

**MemoryPersistenceAdapter** differs from legacy `InMemoryAdapter`:
- Checks `version` on save (throws `VersionConflictError` if stale)
- Returns copies (spread operator) to prevent external mutation
- Has `clear()` for test teardown
- Implements `getAllSpaces()`

---

## 11. Service Layer (Planet-Scale)

### DecisionService vs. ConsensusEngine

| | ConsensusEngine | DecisionService |
|---|---|---|
| State storage | In-process Maps | External (via PersistencePort) |
| API style | Synchronous | Async (Promise-based) |
| Auth | None | On every operation |
| Events | In-process listeners | External (via EventBusPort) |
| Caching | None | Via CachePort (optional) |
| Scaling | Single process | Horizontally (any node can serve any request) |
| Use case | Testing, embedded, scripts | Servers, APIs, multi-user apps |

**Decision**: Keep both. Don't deprecate `ConsensusEngine`.
**Rationale**: Different deployment models need different APIs. `ConsensusEngine` is perfect for unit tests (no async, no setup). `DecisionService` is for production.

### Stateless Design

The service holds no state between requests. Every method follows the same pattern:

```
1. Authenticate (via AuthPort)
2. Load from DB (via PersistencePort)
3. Compute (pure functions from engine/)
4. Save to DB (via PersistencePort)
5. Broadcast event (via EventBusPort)
6. Invalidate cache (via CachePort)
7. Return result
```

**Implication**: Any number of `DecisionService` instances can run behind a load balancer. They don't coordinate. The database is the source of truth.

### Version Bumping

Every mutation increments `version`:
```typescript
updated = { ...updated, version: item.version + 1 };
```

The persistence adapter checks this on save. If two concurrent requests try to modify the same item, one will fail with `VersionConflictError` (HTTP 409). The client should reload and retry.

### Constructor (Dependency Injection)

```typescript
interface ServiceOptions {
  persistence: PersistencePort;   // Required
  eventBus: EventBusPort;         // Required
  auth: AuthPort;                 // Required
  cache?: CachePort;              // Optional
  defaultConfig?: Partial<SpaceConfig>;
  defaultFlow?: StateFlowConfig;
  cacheTtlMs?: number;            // Default: 60_000 (1 minute)
}
```

**Decision**: Cache is optional. Auth, persistence, and events are required.
**Rationale**: You can't skip auth (security) or persistence (state) or events (sync). But caching is a performance optimization — the system works without it, just slower.

---

## 12. Request Handler (Framework-Agnostic HTTP)

### Design

```typescript
interface ServiceRequest {
  method: string;       // GET, POST, PUT, DELETE
  path: string;         // e.g., "/spaces/xyz/items"
  body?: unknown;       // Parsed JSON
  token?: string;       // Authorization token
  query?: Record<string, string>;
}

interface ServiceResponse {
  status: number;
  body: unknown;
}
```

**Decision**: No framework dependency. No `req`/`res` objects. Just plain data in, plain data out.
**Rationale**: Works with literally any framework or serverless platform. The adapter code is trivial:

```typescript
// Express
app.all('/api/*', async (req, res) => {
  const result = await handler.handle({
    method: req.method,
    path: req.path.replace('/api', ''),
    body: req.body,
    token: req.headers.authorization?.replace('Bearer ', ''),
  });
  res.status(result.status).json(result.body);
});

// AWS Lambda
export const handler = async (event) => ({
  statusCode: result.status,
  body: JSON.stringify(result.body),
});
```

### Route Table

| Method | Path | Action | Status |
|--------|------|--------|--------|
| POST | `/spaces` | Create space | 201 |
| GET | `/spaces/:id` | Get space | 200 |
| DELETE | `/spaces/:id` | Delete space | 204 |
| POST | `/spaces/:id/items` | Add item | 201 |
| GET | `/spaces/:id/items/ranked` | Ranked summary | 200 |
| GET | `/spaces/:id/items/locked` | Locked items | 200 |
| GET | `/spaces/:id/items/active` | Active items | 200 |
| GET | `/items/:id` | Get item | 200 |
| POST | `/items/:id/react` | React | 200 |
| DELETE | `/items/:id/react` | Unreact | 200 |
| POST | `/items/:id/lock` | Lock/commit | 200 |
| POST | `/items/:id/transfer` | Transfer ownership | 200 |
| GET | `/items/:id/agreement` | Agreement score | 200 |
| GET | `/items/:id/signals` | Signal breakdown | 200 |
| POST | `/spaces/:id/tasks` | Add task | 201 |
| POST | `/tasks/:id/claim` | Claim task | 200 |
| POST | `/tasks/:id/release` | Release task | 200 |
| GET | `/spaces/:id/grounding/prompt` | AI prompt | 200 |
| GET | `/spaces/:id/grounding` | AI context | 200 |
| GET | `/spaces/:id/conflicts` | Check conflicts | 200 |

**Route ordering**: More specific routes (`/grounding/prompt`, 4 segments) are matched before less specific ones (`/grounding`, 3 segments). Segment length checks prevent false matches.

---

## 13. Backwards Compatibility Strategy

### Type Aliases

| Old Name | New Name | Strategy |
|----------|----------|----------|
| `BookableItem` | `DecisionItem` | `BookableItem = DecisionItem & { groupId, bookingProof }` |
| `BookingProof` | `CommitmentProof` | `type BookingProof = CommitmentProof` |
| `PersistenceAdapter` | `PersistencePort` | Both exported, legacy interface still in `engine/persistence.ts` |

### Enum Aliases

| Old Member | New Member | Value |
|------------|-----------|-------|
| `ReactionType.Heart` | `ReactionType.LoveIt` | `"love_it"` |
| `ReactionType.ThumbsUp` | `ReactionType.WorksForMe` | `"works_for_me"` |
| `BookableItemState.HeartSorted` | `BookableItemState.Ranked` | `"heart_sorted"` vs `"ranked"` |

**Note**: `HeartSorted` has value `"heart_sorted"` and `Ranked` has value `"ranked"` — they are NOT the same string. `HeartSorted` is kept for old code that checks against the string value, but the default `BOOKING_FLOW` now produces `"ranked"` instead of `"heart_sorted"`.

### Function Aliases

| Old Function | New Function | Notes |
|--------------|-------------|-------|
| `proposeItem()` | `addItem()` | Old one calls new one |
| `lockItem()` | `commitItem()` | Old one uses hardcoded state |
| `resetTaskCounter()` | *(none)* | No-op (IDs use UUID now) |

### Field Duplication

Items carry both field sets:
```typescript
{
  spaceId: "space_abc",       // New
  groupId: "space_abc",       // Old (same value)
  commitmentProof: proof,     // New
  bookingProof: proof,        // Old (same object)
}
```

### Ranked Summary Breakdown

```typescript
reactionBreakdown: {
  loveIt: 3,        // New
  worksForMe: 1,    // New
  notForMe: 0,      // New
  hearts: 3,        // Old alias (=== loveIt)
  thumbsUp: 1,      // Old alias (=== worksForMe)
}
```

---

## 14. Optimistic Concurrency

### How It Works

Every `BookableItem` has a `version: number` field (starts at 1).

On every mutation in `DecisionService`:
```typescript
updated = { ...updated, version: item.version + 1 };
await this.persistence.saveItem(updated);
```

The persistence adapter checks on save:
```typescript
async saveItem(item: BookableItem): Promise<void> {
  const existing = this.items.get(item.id);
  if (existing && existing.version >= item.version) {
    throw new VersionConflictError(item.id, item.version, existing.version);
  }
  this.items.set(item.id, { ...item });
}
```

### Conflict Resolution

When `VersionConflictError` is thrown:
1. `RequestHandler` maps it to HTTP 409 Conflict
2. Client should reload the item (GET) and retry the operation

**Decision**: No automatic retry in the service layer.
**Rationale**: The service doesn't know what the correct merge strategy is. The client/caller should decide whether to retry with the new state.

### ConsensusEngine (no versioning)

The in-memory `ConsensusEngine` does NOT check versions. It's single-process, single-threaded — there are no concurrent writes. Version is set but never checked.

---

## 15. Cache Strategy

### Key Convention

`"ranked:{spaceId}"` — cached ranked summary for a space.

### Invalidation

Every write operation calls:
```typescript
private async invalidateSpaceCache(spaceId: SpaceId): Promise<void> {
  if (this.cache) {
    await this.cache.deleteByPrefix(`ranked:${spaceId}`);
  }
}
```

Operations that invalidate: `addItem`, `react`, `unreact`, `lock`, `transfer`, `addTask`, `claimTask`, `releaseTask`, `deleteSpace`.

### TTL

Default: 60,000 ms (1 minute). Configurable via `ServiceOptions.cacheTtlMs`.

**Decision**: Short TTL + invalidation-on-write.
**Rationale**: Ranked lists change frequently (every reaction). A long TTL would serve stale data. A short TTL is a safety net in case invalidation misses (e.g., direct DB writes bypassing the service).

### Cache Miss Flow

```
Client requests ranked items
  → Service checks cache ("ranked:{spaceId}")
    → HIT: return cached value
    → MISS: load from DB, compute, cache result, return
```

---

## 16. Event System

### Event Types

```typescript
enum EventType {
  ItemProposed = "item_proposed",
  ReactionAdded = "reaction_added",
  ReactionRemoved = "reaction_removed",
  ItemLocked = "item_locked",
  OwnershipTransferred = "ownership_transferred",
  TaskCreated = "task_created",
  TaskAssigned = "task_assigned",
}
```

### Event Payloads (by type)

| Event | Payload Fields |
|-------|---------------|
| `item_proposed` | `itemId`, `title`, `category` |
| `reaction_added` | `itemId`, `reactionType`, `newScore` |
| `reaction_removed` | `itemId`, `newScore` |
| `item_locked` | `itemId`, `title`, `proofType`, `ownerId` |
| `ownership_transferred` | `itemId`, `title`, `previousOwnerId`, `newOwnerId` |
| `task_created` | `taskId`, `title` |
| `task_assigned` | `taskId`, `title`, `assigneeId` |

### Channel Convention

Events are published to `"space:{spaceId}"`. Subscribers on that channel receive all events for that space.

### Two Event Systems

| | ConsensusEngine | DecisionService |
|---|---|---|
| Mechanism | In-process callback array | EventBusPort adapter |
| Subscribe | `engine.on(callback)` | `eventBus.subscribe(channel, handler)` |
| Scope | Same process only | Cross-process (Redis, WebSocket, etc.) |

---

## 17. Error Taxonomy

| Error Class | When Thrown | HTTP Status | Recovery |
|---|---|---|---|
| `GreenLockError` | Already locked, empty proof, transfer non-locked, self-transfer | 422 | Fix input, retry |
| `TaskAssignmentError` | Self-reassign, unassign non-assigned | 400 | Fix input |
| `VersionConflictError` | Stale version on save | 409 | Reload item, retry |
| `AuthError` | Failed auth or authorization | 403 | Get valid token/permissions |
| `NotFoundError` | Entity not found in DB | 404 | Check ID |
| Generic `Error` | Locked item reaction, other validation | 400 | Fix input |

All error classes extend `Error` with a `name` property set to the class name.

---

## 18. File-by-File Reference

### Source Files — `src/`

| File | Purpose | Key Exports |
|------|---------|-------------|
| `models/types.ts` | Core type definitions | All types, enums, constants |
| `engine/heart-sort.ts` | Weighted sort algorithm | `calculateWeightedScore`, `addReaction`, `removeReaction`, `heartSort`, `getTopItems`, `calculateAgreementScore`, `getRankedSummary` |
| `engine/green-lock.ts` | Commitment protocol | `commitItem`, `lockItem`, `transferOwnership`, `isLocked`, `canLock`, `canTransferOwnership`, `getOwner`, `GreenLockError` |
| `engine/state-machine.ts` | Configurable state machine | `StateMachine`, `StateFlowConfig`, `StateTransition` |
| `engine/state-flows.ts` | Preset flow configs | `BOOKING_FLOW`, `PURCHASE_FLOW`, `SIMPLE_VOTE_FLOW`, `SOLO_DECISION_FLOW` |
| `engine/consensus-engine.ts` | In-memory orchestrator | `ConsensusEngine`, `EngineOptions`, `EventListener` |
| `engine/ai-grounding.ts` | AI constraint system | `buildGroundingContext`, `generateGroundingPrompt`, `checkSuggestionConflicts`, `GroundingConstraint`, `GroundingContext` |
| `engine/task-assignment.ts` | Task system | `createTask`, `assignTask`, `reassignTask`, `unassignTask`, `resetTaskCounter`, `TaskAssignmentError` |
| `engine/persistence.ts` | Legacy persistence | `PersistenceAdapter`, `InMemoryAdapter` |
| `ports/persistence.ts` | DB port | `PersistencePort`, `VersionConflictError` |
| `ports/event-bus.ts` | Event bus port | `EventBusPort`, `Unsubscribe` |
| `ports/auth.ts` | Auth port | `AuthPort`, `Identity`, `Action` |
| `ports/cache.ts` | Cache port | `CachePort` |
| `ports/messaging.ts` | Chat port | `MessagingPort`, `OutgoingMessage`, `IncomingMessage`, `EngineCommand`, `RankedItemSummary` |
| `adapters/memory-persistence.ts` | In-memory DB | `MemoryPersistenceAdapter` |
| `adapters/memory-event-bus.ts` | In-process pub/sub | `MemoryEventBusAdapter` |
| `adapters/memory-cache.ts` | In-memory cache | `MemoryCacheAdapter` |
| `adapters/noop-auth.ts` | No-op auth | `NoopAuthAdapter` |
| `adapters/plaintext-messaging.ts` | Text formatter | `PlaintextMessagingAdapter` |
| `service/decision-service.ts` | Stateless service | `DecisionService`, `ServiceOptions`, `AuthError`, `NotFoundError` |
| `service/request-handler.ts` | HTTP router | `RequestHandler`, `ServiceRequest`, `ServiceResponse` |
| `index.ts` | Public API | Re-exports everything |

### Script Files

| File | Purpose |
|------|---------|
| `apify-fetch.ts` | Fetches hotel data from Booking.com via Apify `voyager~booking-scraper`. Transforms to engine format. Saves to `data/`. |
| `integration-test.ts` | Full lifecycle test with real Apify data. Console output with assertions. |
| `build-demo.ts` | Injects hotel data into `demo-live.html`. |

### Test Files — `src/__tests__/` (198 tests)

| File | Tests | Coverage |
|------|-------|----------|
| `decision-service.test.ts` | 17 | Full lifecycle, persistence survival, cache, events, versioning, tasks, grounding, signals |
| `request-handler.test.ts` | 22 | HTTP routing, all endpoints, error codes (403/404/400) |
| `adapters.test.ts` | 35 | All 5 adapters: CRUD, versions, copies, TTL, pub/sub, commands |
| `consensus-engine.test.ts` | 16 | Full lifecycle, AI grounding, queries, reactions, tasks, events |
| `heart-sort.test.ts` | 25 | Scoring, sorting, agreement, ranked summary, negative weights |
| `green-lock.test.ts` | 20 | Lock, transfer, proof validation, ownership, immutability |
| `state-machine.test.ts` | 21 | All 4 preset flows + custom flows + edge cases |
| `ai-grounding.test.ts` | 8 | Context building, prompt generation, conflict detection |
| `task-assignment.test.ts` | 8 | Create, assign, reassign, unassign, errors |
| `backwards-compat.test.ts` | 18 | Type aliases, enum values, old functions, exports |
| `universal-scenarios.test.ts` | 8 | Solo car purchase, 50-person wedding, restaurant pick, solo daycare, multi-space, pagination, custom weights |

### Config Files

| File | Key Settings |
|------|-------------|
| `package.json` | ESM, zero runtime deps, devDeps: typescript 5.9, vitest 4.0, tsx 4.21, @types/node 25.4 |
| `tsconfig.json` | strict, nodenext, es2022, noUncheckedIndexedAccess, exactOptionalPropertyTypes, sourceMap, declaration |
| `vitest.config.ts` | tests in `src/__tests__/**/*.test.ts` |

---

## 19. Testing Strategy

### Philosophy

- Every pure function is unit-tested in isolation
- The `ConsensusEngine` has integration tests (full lifecycle)
- The `DecisionService` has integration tests (persistence survival, cache invalidation)
- The `RequestHandler` has HTTP-level tests (routing, error codes)
- Every adapter is tested independently
- Backwards compatibility has its own test suite
- Universal scenarios test cross-domain applicability

### Key Test Patterns

**Immutability verification**: Tests check that original objects are not mutated.
```typescript
it("does not mutate the original item", () => {
  const item = makeItem();
  const updated = addReaction(item, "u1", ReactionType.LoveIt, 100);
  expect(item.reactions).toHaveLength(0);
  expect(updated.reactions).toHaveLength(1);
});
```

**Persistence survival**: Tests create data with one service instance, then verify with a new instance using the same adapter.
```typescript
it("state survives across service instances", async () => {
  // Instance 1: create + react
  const item = await service.addItem(...);
  await service.react(alice, item.id, ReactionType.LoveIt);
  // Instance 2: same persistence
  const service2 = new DecisionService({ persistence, ... });
  const retrieved = await service2.getItem(alice, item.id);
  expect(retrieved.weightedScore).toBe(5);
});
```

**Version conflict**: Tests verify that stale writes are rejected.
```typescript
it("throws VersionConflictError on stale version", async () => {
  await adapter.saveItem(makeItem({ version: 2 }));
  await expect(adapter.saveItem(makeItem({ version: 1 }))).rejects.toThrow(VersionConflictError);
});
```

---

## 20. What This Project Is and Is Not

### What It Is

- A **headless decision engine** (TypeScript library)
- A **consensus algorithm** with weighted scoring and commitment locking
- A **plug-and-play architecture** with clean port/adapter boundaries
- **Domain-agnostic** — works for hotels, cars, restaurants, weddings, schools, anything
- **Framework-agnostic** — works with any HTTP framework, any database, any message broker

### What It Is NOT

- **Not a full application** — no server binary, no database setup, no deployment scripts
- **Not a UI framework** — no React components, no CSS, no animations (HTML demos are prototypes only)
- **Not an Apify integration** — Apify is one example data source, not a dependency
- **Not a real-time system** — the event bus port enables real-time, but no WebSocket server is built
- **Not a database** — `InMemoryAdapter`/`MemoryPersistenceAdapter` are for dev/testing only

### What You Need to Build on Top

| Layer | This Project Provides | You Build |
|-------|----------------------|-----------|
| Algorithm | Pure functions, scoring, sorting, locking | *(nothing — it's ready)* |
| Persistence | `PersistencePort` interface | `PostgresAdapter`, `MongoAdapter`, etc. |
| Auth | `AuthPort` interface | `JwtAuthAdapter`, `SupabaseAuthAdapter`, etc. |
| Real-time | `EventBusPort` interface | `RedisEventBusAdapter`, `WebSocketAdapter`, etc. |
| HTTP Server | `RequestHandler` (framework-agnostic) | Express/Fastify/Lambda wrapper (5 lines) |
| Chat | `MessagingPort` interface | `SlackAdapter`, `DiscordAdapter`, etc. |
| UI | *(nothing)* | React/SwiftUI/Flutter/web components |

---

## Appendix: Mathematical Properties

### Score Arithmetic

| Scenario | Calculation | Result |
|----------|------------|--------|
| 3 LoveIt | 5 + 5 + 5 | 15 |
| 4 WorksForMe | 1 + 1 + 1 + 1 | 4 |
| 3 LoveIt vs 4 WorksForMe | 15 vs 4 | Passionate minority wins |
| 1 NotForMe + 3 WorksForMe | -3 + 1 + 1 + 1 | 0 (cancels out) |
| 2 LoveIt + 1 NotForMe | 5 + 5 + (-3) | 7 (enthusiasm overcomes) |
| 1 LoveIt + 1 NotForMe | 5 + (-3) | 2 (still positive) |
| 3 NotForMe | -3 + -3 + -3 | -9 (sinks to bottom) |
| All WorksForMe (group of 5) | 1 + 1 + 1 + 1 + 1 | 5 |
| All LoveIt (group of 5) | 5 + 5 + 5 + 5 + 5 | 25 (triggers Social Gold) |

### Agreement Score

| Reactions | Group Size | Percentage | Group Favorite? |
|-----------|-----------|------------|-----------------|
| 1/4 reacted | 4 | 25% | No |
| 3/4 reacted | 4 | 75% | No |
| 4/5 reacted | 5 | 80% | No (strictly >80%) |
| 5/6 reacted | 6 | 83.3% | Yes |
| 4/4 reacted | 4 | 100% | Yes |
