/**
 * Xark Consensus Algorithm — Green-Lock Engine
 *
 * A commitment protocol for group coordination.
 * Social alignment (heart-sort) → Financial commitment (booking) → Lock.
 *
 * No gates. No votes. No clustering. Just signal → act → lock.
 */
// Core types
export { ReactionType, REACTION_WEIGHTS, BookableItemState, TaskState, EventType, } from "./models/types.js";
// Heart-Sort Algorithm
export { calculateWeightedScore, addReaction, removeReaction, heartSort, getTopItems, calculateAgreementScore, getRankedSummary, } from "./engine/heart-sort.js";
// Green-Lock Engine
export { GreenLockError, lockItem, transferOwnership, isLocked, getOwner, canLock, canTransferOwnership, } from "./engine/green-lock.js";
// Task Assignment
export { TaskAssignmentError, createTask, assignTask, reassignTask, unassignTask, } from "./engine/task-assignment.js";
// AI Grounding
export { buildGroundingContext, generateGroundingPrompt, checkSuggestionConflicts, } from "./engine/ai-grounding.js";
// Consensus Engine (orchestrator)
export { ConsensusEngine } from "./engine/consensus-engine.js";
//# sourceMappingURL=index.js.map