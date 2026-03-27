/**
 * Xark Consensus Engine
 *
 * Orchestrates the full decision lifecycle:
 *   Apify proposes options
 *     → Group reacts (❤️/👍🏻) → Weighted Heart-Sort re-orders in real-time
 *       → Any member books the top choice + provides confirmation
 *         → Green-Lock activates → Booker stamped as owner
 *           → @xark grounds all future suggestions to locked state
 *             → Another member can claim via "I'll take care of this"
 *
 * No gates. No votes. No clustering. Just signal → act → lock.
 */
import type { BookableItem, BookingProof, EngineEvent, Group, GroupId, ItemId, Task, TaskId, UserId } from "../models/types.js";
import { ReactionType } from "../models/types.js";
import { getRankedSummary } from "./heart-sort.js";
import { type GroundingContext } from "./ai-grounding.js";
export type EventListener = (event: EngineEvent) => void;
export declare class ConsensusEngine {
    private groups;
    private items;
    private tasks;
    private groupItems;
    private groupTasks;
    private listeners;
    private itemCounter;
    on(listener: EventListener): () => void;
    private emit;
    registerGroup(group: Group): void;
    getGroup(groupId: GroupId): Group | undefined;
    /**
     * Proposes a new bookable item to a group (typically from Apify agents).
     */
    proposeItem(groupId: GroupId, title: string, description: string, category: BookableItem["category"], proposedBy: UserId, timestamp: number): BookableItem;
    /**
     * Adds a reaction (❤️ or 👍🏻) to an item. Triggers Heart-Sort re-ordering.
     */
    react(itemId: ItemId, userId: UserId, reactionType: ReactionType, timestamp: number): BookableItem;
    /**
     * Removes a user's reaction from an item.
     */
    unreact(itemId: ItemId, userId: UserId, timestamp: number): BookableItem;
    /**
     * Locks an item by providing booking confirmation.
     * The booker is automatically stamped as the owner.
     */
    lock(itemId: ItemId, proof: BookingProof): BookableItem;
    /**
     * Transfers ownership via "I'll take care of this" button.
     */
    transfer(itemId: ItemId, newOwnerId: UserId, timestamp: number): BookableItem;
    addTask(groupId: GroupId, title: string, description: string, createdBy: UserId, timestamp: number): Task;
    claimTask(taskId: TaskId, userId: UserId, timestamp: number): Task;
    releaseTask(taskId: TaskId): Task;
    getItem(itemId: ItemId): BookableItem | undefined;
    getTask(taskId: TaskId): Task | undefined;
    /**
     * Returns all items for a group, sorted by Heart-Sort (weighted score descending).
     */
    getGroupItems(groupId: GroupId): BookableItem[];
    /**
     * Returns only locked items for a group.
     */
    getLockedItems(groupId: GroupId): BookableItem[];
    /**
     * Returns only unlocked (active) items for a group, sorted by score.
     */
    getActiveItems(groupId: GroupId): BookableItem[];
    /**
     * Returns all tasks for a group.
     */
    getGroupTasks(groupId: GroupId): Task[];
    /**
     * Gets ranked summary of items for display.
     */
    getRankedItems(groupId: GroupId): ReturnType<typeof getRankedSummary>;
    /**
     * Calculates agreement score for a specific item.
     */
    getAgreementScore(itemId: ItemId): {
        percentage: number;
        isGroupFavorite: boolean;
    };
    /**
     * Builds the grounding context for @xark.
     * Returns all locked decisions as hard constraints and active items as context.
     */
    getGroundingContext(groupId: GroupId): GroundingContext;
    /**
     * Generates the system prompt fragment for @xark.
     */
    getGroundingPrompt(groupId: GroupId): string;
    private getItemOrThrow;
    private getTaskOrThrow;
    private getOrCreateGroupItems;
    private getOrCreateGroupTasks;
}
//# sourceMappingURL=consensus-engine.d.ts.map