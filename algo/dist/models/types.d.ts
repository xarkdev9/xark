/**
 * Core types for Xark's Green-Lock Consensus Engine.
 *
 * Two parallel systems:
 * 1. Green-Lock Engine — for bookable items (hotels, flights, restaurants)
 *    Proposed → Heart-Sorted → Booked/Locked → Owned → Transferable
 * 2. Task Assignment — for non-bookable items (time, who brings snacks)
 *    Created → Assigned → Owned
 */
export type UserId = string;
export type GroupId = string;
export type ItemId = string;
export type TaskId = string;
export declare enum ReactionType {
    Heart = "heart",// ❤️ — 5x weight
    ThumbsUp = "thumbs_up"
}
export declare const REACTION_WEIGHTS: Record<ReactionType, number>;
export interface Reaction {
    userId: UserId;
    itemId: ItemId;
    type: ReactionType;
    timestamp: number;
}
export declare enum BookableItemState {
    Proposed = "proposed",
    HeartSorted = "heart_sorted",
    Locked = "locked"
}
export interface BookingProof {
    type: "screenshot" | "confirmation_number";
    value: string;
    submittedBy: UserId;
    submittedAt: number;
}
export interface OwnershipRecord {
    ownerId: UserId;
    assignedAt: number;
    reason: "booker" | "transfer";
}
export interface BookableItem {
    id: ItemId;
    groupId: GroupId;
    title: string;
    description: string;
    category: "hotel" | "flight" | "restaurant" | "activity" | "other";
    state: BookableItemState;
    proposedBy: UserId;
    proposedAt: number;
    reactions: Reaction[];
    weightedScore: number;
    bookingProof: BookingProof | null;
    ownership: OwnershipRecord | null;
    ownershipHistory: OwnershipRecord[];
    lockedAt: number | null;
}
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
export declare enum EventType {
    ItemProposed = "item_proposed",
    ReactionAdded = "reaction_added",
    ReactionRemoved = "reaction_removed",
    ItemLocked = "item_locked",
    OwnershipTransferred = "ownership_transferred",
    TaskCreated = "task_created",
    TaskAssigned = "task_assigned"
}
export interface EngineEvent {
    type: EventType;
    timestamp: number;
    groupId: GroupId;
    actorId: UserId;
    payload: Record<string, unknown>;
}
//# sourceMappingURL=types.d.ts.map