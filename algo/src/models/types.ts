/**
 * Core types for Xark's Universal Decision Engine.
 *
 * Two parallel systems:
 * 1. Decision Engine — for any decidable item (hotels, cars, venues, schools…)
 *    State flow is configurable per DecisionSpace.
 * 2. Task Assignment — for non-decidable items (time, who brings snacks)
 *    Created → Assigned → Owned
 */

// --- Identifiers ---

export type UserId = string;
export type GroupId = string;
export type SpaceId = string;
export type ItemId = string;
export type TaskId = string;

// --- Reactions ---

export enum ReactionType {
  LoveIt = "love_it", // "Love it" — 5x weight (Seeking Amber)
  WorksForMe = "works_for_me", // "Works" — 1x weight (neutral)
  NotForMe = "not_for_me", // "Not for me" — -3 weight (Action Orange)
  // Deprecated aliases (same string values as new names)
  Heart = "love_it",
  ThumbsUp = "works_for_me",
}

export const REACTION_WEIGHTS: Record<string, number> = {
  [ReactionType.LoveIt]: 5,
  [ReactionType.WorksForMe]: 1,
  [ReactionType.NotForMe]: -3,
};

export interface Reaction {
  userId: UserId;
  itemId: ItemId;
  type: ReactionType;
  timestamp: number;
}

// --- Decision Item States ---

export enum BookableItemState {
  Proposed = "proposed",
  Ranked = "ranked",
  Locked = "locked",
  // Deprecated alias
  HeartSorted = "heart_sorted",
}

// Open string alias — any state value is valid for custom flows
export type DecisionItemState = string;

// --- Commitment Proof ---

export interface CommitmentProof {
  type: string; // "screenshot", "confirmation_number", "receipt", "contract", "verbal", etc.
  value: string;
  submittedBy: UserId;
  submittedAt: number;
}

// Backwards-compat alias
export type BookingProof = CommitmentProof;

export interface OwnershipRecord {
  ownerId: UserId;
  assignedAt: number;
  reason: "booker" | "transfer";
}

// --- Decision Item (universal) ---

export interface DecisionItem {
  id: ItemId;
  spaceId: SpaceId;
  title: string;
  description: string;
  category: string; // Open string — "hotel", "sedan", "venue", "daycare", anything
  state: DecisionItemState;
  proposedBy: UserId;
  proposedAt: number;
  reactions: Reaction[];
  weightedScore: number;
  commitmentProof: CommitmentProof | null;
  ownership: OwnershipRecord | null;
  ownershipHistory: OwnershipRecord[];
  lockedAt: number | null;
  version: number;
  metadata: Record<string, unknown>;
}

/**
 * @deprecated Use DecisionItem. BookableItem extends DecisionItem with
 * legacy field aliases (groupId for spaceId, bookingProof for commitmentProof).
 */
export type BookableItem = DecisionItem & {
  /** @deprecated Use spaceId instead */
  groupId: GroupId;
  /** @deprecated Use commitmentProof instead */
  bookingProof: BookingProof | null;
};

// --- Task States (Non-bookable items) ---

export enum TaskState {
  Created = "created",
  Assigned = "assigned",
}

export interface Task {
  id: TaskId;
  groupId: GroupId;
  title: string;
  description: string;
  state: TaskState;
  createdBy: UserId;
  createdAt: number;
  assignee: UserId | null;
  assignedAt: number | null;
}

// --- Group ---

export interface GroupMember {
  userId: UserId;
  name: string;
  avatarUrl: string;
  joinedAt: number;
}

export interface Group {
  id: GroupId;
  name: string;
  members: GroupMember[];
  createdAt: number;
}

// --- Decision Space (universal group concept) ---

export interface SpaceConfig {
  reactionWeights: Record<string, number>;
  groupFavoriteThreshold: number;
  allowSelfReaction: boolean;
  requireProofForLock: boolean;
}

export interface DecisionSpace {
  id: SpaceId;
  name: string;
  members: GroupMember[];
  config: SpaceConfig;
  /** State flow configuration. If omitted, BOOKING_FLOW is used. */
  flow?: { name: string; initialState: string; lockedState: string; transitions: Array<{ from: string; to: string; trigger: "reaction" | "commitment" | "manual" }> };
  createdAt: number;
}

// Default config matching current behavior
export const DEFAULT_SPACE_CONFIG: SpaceConfig = {
  reactionWeights: {
    [ReactionType.LoveIt]: 5,
    [ReactionType.WorksForMe]: 1,
    [ReactionType.NotForMe]: -3,
  },
  groupFavoriteThreshold: 80,
  allowSelfReaction: true,
  requireProofForLock: true,
};

// --- Events ---

export enum EventType {
  ItemProposed = "item_proposed",
  ReactionAdded = "reaction_added",
  ReactionRemoved = "reaction_removed",
  ItemLocked = "item_locked",
  OwnershipTransferred = "ownership_transferred",
  TaskCreated = "task_created",
  TaskAssigned = "task_assigned",
  TaskReleased = "task_released",
}

export interface EngineEvent {
  type: EventType;
  timestamp: number;
  groupId: GroupId;
  actorId: UserId;
  payload: Record<string, unknown>;
}
