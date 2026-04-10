/**
 * Core types for hello's Universal Decision Engine.
 *
 * Two parallel systems:
 * 1. Decision Engine — for any decidable item (hotels, cars, venues, schools…)
 *    State flow is configurable per DecisionSpace.
 * 2. Task Assignment — for non-decidable items (time, who brings snacks)
 *    Created → Assigned → Owned
 */
export type UserId = string;
export type GroupId = string;
export type ItemId = string;
export type TaskId = string;
export declare enum ReactionType {
    LoveIt = "love_it",// "Love it" — 5x weight (Seeking Amber)
    WorksForMe = "works_for_me",// "Works" — 1x weight (neutral)
    NotForMe = "not_for_me",// "Not for me" — -3 weight (Action Orange)
    Heart = "love_it",
    ThumbsUp = "works_for_me"
}
export declare const REACTION_WEIGHTS: Record<string, number>;
export interface Reaction {
    userId: UserId;
    itemId: ItemId;
    type: ReactionType;
    timestamp: number;
}
export declare enum BookableItemState {
    Proposed = "proposed",
    Ranked = "ranked",
    Locked = "locked",
    HeartSorted = "heart_sorted"
}
export type DecisionItemState = string;
export interface CommitmentProof {
    type: string;
    value: string;
    submittedBy: UserId;
    submittedAt: number;
}
export type BookingProof = CommitmentProof;
export interface OwnershipRecord {
    ownerId: UserId;
    assignedAt: number;
    reason: "booker" | "transfer";
}
export type OwnershipState = OwnershipRecord;
export interface ObliviousDecisionItem {
    id: string;
    groupId: string;
    proposedBy: string;
    proposedAt: number;
    ciphertextPayload: string;
    nonce: string;
    state: 'proposed' | 'ranked' | 'considering' | 'locked' | 'decided';
    reactions: Reaction[];
    weightedScore: number;
    lockedAt: number | null;
    ownership: OwnershipState | null;
    commitmentCiphertext: string | null;
    commitmentNonce: string | null;
    version: number;
}
export interface DecryptedItemPayload {
    title: string;
    description: string;
    category: string;
    priceCents?: bigint;
    customMetadata?: any;
}
export interface DecryptedCommitmentProof {
    type: string;
    value: string;
    submittedBy: string;
}
export type DecisionItem = ObliviousDecisionItem;
export type BookableItem = ObliviousDecisionItem;
export declare enum TaskState {
    Created = "created",
    Assigned = "assigned"
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
export interface SpaceConfig {
    reactionWeights: Record<string, number>;
    groupFavoriteThreshold: number;
    allowSelfReaction: boolean;
    requireProofForLock: boolean;
}
export interface DecisionSpace {
    id: GroupId;
    name: string;
    members: GroupMember[];
    config: SpaceConfig;
    /** State flow configuration. If omitted, BOOKING_FLOW is used. */
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
export declare const DEFAULT_SPACE_CONFIG: SpaceConfig;
export declare enum EventType {
    ItemProposed = "item_proposed",
    ReactionAdded = "reaction_added",
    ReactionRemoved = "reaction_removed",
    ItemLocked = "item_locked",
    OwnershipTransferred = "ownership_transferred",
    TaskCreated = "task_created",
    TaskAssigned = "task_assigned",
    TaskReleased = "task_released"
}
export interface EngineEvent {
    type: EventType;
    timestamp: number;
    groupId: GroupId;
    actorId: UserId;
    payload: Record<string, unknown>;
}
//# sourceMappingURL=types.d.ts.map