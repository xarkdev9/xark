/**
 * Xark Consensus Algorithm — Green-Lock Engine
 *
 * A commitment protocol for group coordination.
 * Social alignment (heart-sort) → Financial commitment (booking) → Lock.
 *
 * No gates. No votes. No clustering. Just signal → act → lock.
 */
export { ReactionType, REACTION_WEIGHTS, BookableItemState, TaskState, EventType, } from "./models/types.js";
export type { UserId, GroupId, ItemId, TaskId, Reaction, BookingProof, OwnershipRecord, BookableItem, Task, GroupMember, Group, EngineEvent, } from "./models/types.js";
export { calculateWeightedScore, addReaction, removeReaction, heartSort, getTopItems, calculateAgreementScore, getRankedSummary, } from "./engine/heart-sort.js";
export { GreenLockError, lockItem, transferOwnership, isLocked, getOwner, canLock, canTransferOwnership, } from "./engine/green-lock.js";
export { TaskAssignmentError, createTask, assignTask, reassignTask, unassignTask, } from "./engine/task-assignment.js";
export { buildGroundingContext, generateGroundingPrompt, checkSuggestionConflicts, } from "./engine/ai-grounding.js";
export type { GroundingConstraint, GroundingContext } from "./engine/ai-grounding.js";
export { ConsensusEngine } from "./engine/consensus-engine.js";
//# sourceMappingURL=index.d.ts.map