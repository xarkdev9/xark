# Xark Universal Decision Engine

Commitment protocol for group and individual coordination: signal → act → lock.

## Commands

```bash
npm run build          # tsc → dist/
npm test               # vitest run (198 tests)
npm run test:watch     # vitest --watch
npx tsx src/apify-fetch.ts [search] [maxItems]   # Fetch hotel data from Apify
npx tsx src/integration-test.ts                   # Full lifecycle integration test
npx tsx src/build-demo.ts                         # Inject hotel data into demo-live.html
```

## Architecture

Hexagonal (Ports & Adapters). Three layers:

```
┌─────────────────────────────────────────────────────┐
│  Any Transport: Express, Fastify, Lambda, Hono...   │
│  ↕  RequestHandler (framework-agnostic router)      │
├─────────────────────────────────────────────────────┤
│  DecisionService (stateless orchestrator)            │
│  ↕ Uses pure functions + dependency-injected ports  │
├─────────────────────────────────────────────────────┤
│  Ports (interfaces)     →   Adapters (plug-and-play)│
│  PersistencePort        →   MemoryPersistence, Pg…  │
│  EventBusPort           →   MemoryEventBus, Redis…  │
│  AuthPort               →   NoopAuth, JWT, OAuth…   │
│  CachePort              →   MemoryCache, Redis…     │
│  MessagingPort          →   Plaintext, Slack, etc.  │
└─────────────────────────────────────────────────────┘
```

- **ConsensusEngine** — in-memory, synchronous (good for testing, embedded, scripts)
- **DecisionService** — stateless, async, persistent (good for servers, planet-scale)

## Project Structure

### Config
- `package.json` — ESM module, devDeps: typescript, vitest, tsx, @types/node
- `tsconfig.json` — strict, nodenext, rootDir=src, outDir=dist
- `vitest.config.ts` — tests in `src/__tests__/**/*.test.ts`

### Core Types — `src/models/types.ts`
- `ReactionType` enum: `LoveIt` (+5), `WorksForMe` (+1), `NotForMe` (-3); deprecated aliases `Heart`, `ThumbsUp`
- `BookableItemState` enum: `Proposed`, `Ranked`, `Locked`; deprecated alias `HeartSorted`
- `REACTION_WEIGHTS` — default weight map for all three signal types
- `DEFAULT_SPACE_CONFIG` — default SpaceConfig (weights, 80% threshold, no self-reaction, require proof)
- **Primary interface**: `DecisionItem` — domain-agnostic (uses `spaceId`, `commitmentProof`)
- **Backwards-compat alias**: `BookableItem = DecisionItem & { groupId, bookingProof }` — items carry both field sets
- `DecisionSpace` — space with members, config, optional `flow` (StateFlowConfig)
- Other interfaces: `SpaceConfig`, `Reaction`, `CommitmentProof`/`BookingProof` (same type), `OwnershipRecord`, `Task`, `Group`, `EngineEvent`
- ID types: `UserId`, `SpaceId`/`GroupId` (same type), `ItemId`, `TaskId`

### Engine (pure functions) — `src/engine/`

- **`heart-sort.ts`** — Weighted sort algorithm. `calculateWeightedScore()`, `addReaction()`, `removeReaction()`, `heartSort()`, `getTopItems()`, `calculateAgreementScore()`, `getRankedSummary()`

- **`green-lock.ts`** — Commitment/lock engine. `commitItem()`, `lockItem()`, `transferOwnership()`, `isLocked()`, `canLock()`, `canTransferOwnership()`, `getOwner()`. Throws `GreenLockError`.

- **`state-machine.ts`** — Configurable `StateMachine` class. `StateFlowConfig`, triggers: `reaction`, `commitment`, `manual`.

- **`state-flows.ts`** — Preset flows: `BOOKING_FLOW`, `PURCHASE_FLOW`, `SIMPLE_VOTE_FLOW`, `SOLO_DECISION_FLOW`

- **`consensus-engine.ts`** — In-memory orchestrator. Manages spaces, groups, items, tasks, events. Synchronous API.

- **`ai-grounding.ts`** — AI constraint system. `buildGroundingContext()`, `generateGroundingPrompt()`, `checkSuggestionConflicts()`. Constraint types: `"locked_decision"`, `"assigned_task"`.

- **`task-assignment.ts`** — Task system. `createTask()`, `assignTask()`, `reassignTask()`, `unassignTask()`.

- **`persistence.ts`** — Legacy `PersistenceAdapter` interface + `InMemoryAdapter`. Superseded by `ports/persistence.ts`.

### Ports (interfaces) — `src/ports/`

- **`persistence.ts`** — `PersistencePort` for any DB. CRUD for items, tasks, spaces. `VersionConflictError` for optimistic concurrency.
- **`event-bus.ts`** — `EventBusPort` for real-time sync. `publish()`, `subscribe()`, `publishMany()`. Channel-based pub/sub.
- **`auth.ts`** — `AuthPort` for identity. `authenticate(token)`, `authorize(identity, action, spaceId)`. Action types: `space:create/read/delete`, `item:propose/react/lock/transfer`, `task:create/claim/release`.
- **`cache.ts`** — `CachePort` for read caching. `get()`, `set()`, `delete()`, `deleteByPrefix()`. Optional — service works without it.
- **`messaging.ts`** — `MessagingPort` for chat apps. `formatItem()`, `formatRankedList()`, `formatLockNotification()`, `parseCommand()`. Platform-agnostic formatting + command parsing.

### Adapters (reference implementations) — `src/adapters/`

- **`memory-persistence.ts`** — `MemoryPersistenceAdapter` — Map-based, version-checked. For dev/testing.
- **`memory-event-bus.ts`** — `MemoryEventBusAdapter` — In-process pub/sub. For single-process.
- **`memory-cache.ts`** — `MemoryCacheAdapter` — Map with TTL. For dev/testing.
- **`noop-auth.ts`** — `NoopAuthAdapter` — Trusts token as userId, authorizes everything. For dev.
- **`plaintext-messaging.ts`** — `PlaintextMessagingAdapter` — Formats as text, parses `/command` syntax. Reference for building Slack/Discord adapters.

### Service (stateless orchestrator) — `src/service/`

- **`decision-service.ts`** — `DecisionService` class. Constructor takes `{ persistence, eventBus, auth, cache? }`. All methods are `async`, take `Identity` as first arg. Loads from DB → computes with pure functions → saves → broadcasts events → invalidates cache. Throws `AuthError`, `NotFoundError`.

- **`request-handler.ts`** — `RequestHandler` class. Maps `ServiceRequest { method, path, body, token }` to `ServiceResponse { status, body }`. Framework-agnostic — works with Express, Fastify, Lambda, Cloudflare Workers, etc.

### Public API — `src/index.ts`
Re-exports everything: types, engine, ports, adapters, service.

### Scripts — `src/`
- **`apify-fetch.ts`** — Fetches data via Apify. Saves to `data/`.
- **`integration-test.ts`** — Full lifecycle test with real data.
- **`build-demo.ts`** — Injects data into `demo-live.html`.

### HTML Demos
- `demo.html` — Static demo (no live data)
- `demo-live.html` — Demo with Apify data injected

### Tests — `src/__tests__/` (198 tests, 11 files)
- `decision-service.test.ts` — Full lifecycle through service layer, persistence survival, cache invalidation, events, versioning, tasks, AI grounding, signals
- `request-handler.test.ts` — HTTP routing: spaces, items, reactions, lock, transfer, tasks, grounding, error codes (403/404/400)
- `adapters.test.ts` — All 5 adapters: persistence (CRUD, version conflicts, copies), event bus (pub/sub, channels, unsubscribe), cache (TTL, prefix delete), auth (noop), messaging (format, parse commands)
- `consensus-engine.test.ts` — Full lifecycle, AI grounding, heart-sort queries, reaction rules, tasks, events
- `heart-sort.test.ts` — Score calculation, reactions, sorting, agreement, ranked summary, negative weights
- `green-lock.test.ts` — Lock, transfer, proof validation, ownership history
- `state-machine.test.ts` — All four preset flows + custom flows
- `ai-grounding.test.ts` — Context building, prompt generation, conflict detection
- `task-assignment.test.ts` — Create, assign, reassign, unassign, errors
- `backwards-compat.test.ts` — Old API surface: type aliases, enum values, standalone functions
- `universal-scenarios.test.ts` — Cross-flow scenarios: cars, weddings, restaurants, multi-space

## Key Conventions
- Pure functions for engine logic (no mutation — always return new objects)
- Hexagonal architecture: ports define contracts, adapters implement them
- `DecisionService` is stateless — all state in persistence, safe to scale horizontally
- Optimistic concurrency via `version` field on items
- Backwards compat via type aliases and deprecated enum members
- All IDs use `crypto.randomUUID()` with type-branded strings
- State machines are configurable per DecisionSpace (via `flow` field)
- Signal vocabulary: "Love it" / "Works" / "Not for me"
- Domain-agnostic: works for any decision domain (travel, shopping, hiring, etc.)
- AI grounding uses `"locked_decision"` (not booking-specific) for constraint types
