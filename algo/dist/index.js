/**
 * hello Universal Decision Engine
 *
 * A commitment protocol for group and individual coordination.
 * Social alignment (heart-sort) → Commitment (booking/purchase/decision) → Lock.
 *
 * No gates. No votes. No clustering. Just signal → act → lock.
 */
// Core types
export { ReactionType, REACTION_WEIGHTS, BookableItemState, TaskState, EventType, DEFAULT_SPACE_CONFIG, } from "./models/types.js";
// Heart-Sort Algorithm
export { calculateWeightedScore, addReaction, removeReaction, heartSort, getTopItems, calculateAgreementScore, getRankedSummary, } from "./engine/heart-sort.js";
// Green-Lock / Commitment Engine
export { GreenLockError, lockItem, commitItem, transferOwnership, isLocked, getOwner, canLock, canTransferOwnership, } from "./engine/green-lock.js";
// Task Assignment
export { TaskAssignmentError, createTask, assignTask, reassignTask, unassignTask, resetTaskCounter, } from "./engine/task-assignment.js";
// AI Grounding
export { buildGroundingContext, generateGroundingPrompt, checkSuggestionConflicts, } from "./engine/ai-grounding.js";
// State Machine
export { StateMachine } from "./engine/state-machine.js";
// State Flows (presets)
export { BOOKING_FLOW, PURCHASE_FLOW, SIMPLE_VOTE_FLOW, SOLO_DECISION_FLOW, } from "./engine/state-flows.js";
// Persistence
export { InMemoryAdapter } from "./engine/persistence.js";
// Consensus Engine (in-memory orchestrator)
export { ConsensusEngine } from "./engine/consensus-engine.js";
// --- Planet-Scale Layer ---
// Ports (interfaces for plug-and-play adapters)
export { VersionConflictError } from "./ports/persistence.js";
// Adapters (reference implementations)
export { MemoryPersistenceAdapter } from "./adapters/memory-persistence.js";
export { PostgresPersistenceAdapter } from "./adapters/postgres-persistence.js";
export { MemoryEventBusAdapter } from "./adapters/memory-event-bus.js";
export { MemoryCacheAdapter } from "./adapters/memory-cache.js";
export { NoopAuthAdapter } from "./adapters/noop-auth.js";
export { PlaintextMessagingAdapter } from "./adapters/plaintext-messaging.js";
// Service (stateless, persistent, scalable)
export { DecisionService, AuthError, NotFoundError } from "./service/decision-service.js";
export { RequestHandler } from "./service/request-handler.js";
//# sourceMappingURL=index.js.map