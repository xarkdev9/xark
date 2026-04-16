/**
 * hello Universal Decision Engine
 *
 * Orchestrates the full decision lifecycle:
 *   Options proposed (by Apify, manually, or any source)
 *     → Members react (❤️/👍🏻) → Weighted Heart-Sort re-orders in real-time
 *       → Any member commits (books, purchases, decides) + provides proof
 *         → Lock activates → Committer stamped as owner
 *           → @hello grounds all future suggestions to locked state
 *             → Another member can claim via "I'll take care of this"
 *
 * Supports multiple DecisionSpaces — each with its own state machine,
 * reaction weights, thresholds, and items.
 *
 * No gates. No votes. No clustering. Just signal → act → lock.
 */
import type { BookableItem, DecisionSpace, EngineEvent, Group, GroupId, ItemId, SpaceConfig, Task, TaskId, UserId } from "../models/types.js";
import { ReactionType } from "../models/types.js";
import { getRankedSummary } from "./heart-sort.js";
import { type GroundingContext } from "./ai-grounding.js";
import { StateMachine } from "./state-machine.js";
export type EventListener = (event: EngineEvent) => void;
export interface EngineOptions {
    defaultConfig?: Partial<SpaceConfig>;
}
export declare class ConsensusEngine {
    private groups;
    private spaces;
    private spaceMachines;
    private items;
    private tasks;
    private groupItems;
    private groupTasks;
    private listeners;
    private defaultConfig;
    constructor(options?: EngineOptions);
    on(listener: EventListener): () => void;
    private emit;
    /**
     * Creates a new DecisionSpace with its own config and state machine.
     */
    createSpace(space: DecisionSpace): void;
    /**
     * Gets a DecisionSpace by ID.
     */
    getSpace(groupId: GroupId): DecisionSpace | undefined;
    /**
     * Gets the config for a space, falling back to default.
     */
    getSpaceConfig(groupId: GroupId): SpaceConfig;
    /**
     * Gets the state machine for a space, creating a default if needed.
     */
    getStateMachine(groupId: GroupId): StateMachine;
    /**
     * Sets a custom state machine for a space.
     */
    setStateMachine(groupId: GroupId, machine: StateMachine): void;
    /**
     * Registers a group. Alias for createSpace with default config.
     */
    registerGroup(group: Group): void;
    getGroup(groupId: GroupId): Group | undefined;
    /**
     * Adds a new decision item to a space/group.
     * Uses crypto.randomUUID() for globally unique IDs.
     */
    addItem(groupId: GroupId, ciphertextPayload: string, nonce: string, proposedBy: UserId, timestamp: number): BookableItem;
    /**
     * Proposes a new bookable item to a group.
     * Backwards-compatible alias for addItem().
     */
    proposeItem(groupId: GroupId, ciphertextPayload: string, nonce: string, proposedBy: UserId, timestamp: number): BookableItem;
    /**
     * Adds a reaction to an item. Triggers re-ranking.
     */
    react(itemId: ItemId, userId: UserId, reactionType: ReactionType, timestamp: number): BookableItem;
    /**
     * Removes a user's reaction from an item.
     */
    unreact(itemId: ItemId, userId: UserId, timestamp: number): BookableItem;
    /**
     * Locks/commits an item by providing proof.
     * The committer is automatically stamped as the owner.
     */
    lock(itemId: ItemId, commitmentCiphertext: string, commitmentNonce: string, userId: UserId, timestamp: number): BookableItem;
    /**
     * Transfers ownership via "I'll take care of this" button.
     */
    transfer(itemId: ItemId, newOwnerId: UserId, timestamp: number): BookableItem;
    addTask(groupId: GroupId, title: string, description: string, createdBy: UserId, timestamp: number): Task;
    claimTask(taskId: TaskId, userId: UserId, timestamp: number): Task;
    releaseTask(taskId: TaskId, timestamp?: number): Task;
    getItem(itemId: ItemId): BookableItem | undefined;
    getTask(taskId: TaskId): Task | undefined;
    /**
     * Returns all items for a group/space, sorted by Heart-Sort (weighted score descending).
     * Supports pagination via offset/limit.
     */
    getGroupItems(groupId: GroupId, options?: {
        offset?: number;
        limit?: number;
    }): BookableItem[];
    /**
     * Returns only locked items for a group/space.
     */
    getLockedItems(groupId: GroupId): BookableItem[];
    /**
     * Returns only unlocked (active) items for a group/space, sorted by score.
     */
    getActiveItems(groupId: GroupId): BookableItem[];
    /**
     * Returns all tasks for a group/space.
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
     * Returns the signal breakdown for an item.
     * Frontend uses isUnanimousLoveIt to trigger the Social Gold burst.
     */
    getSignalBreakdown(itemId: ItemId): {
        loveIt: number;
        worksForMe: number;
        notForMe: number;
        isUnanimousLoveIt: boolean;
    };
    /**
     * Builds the grounding context for @hello.
     * Returns all locked decisions as hard constraints and active items as context.
     */
    getGroundingContext(groupId: GroupId): GroundingContext;
    /**
     * Generates the system prompt fragment for @hello.
     */
    getGroundingPrompt(groupId: GroupId): string;
    private getItemOrThrow;
    private getTaskOrThrow;
    private getOrCreateGroupItems;
    private getOrCreateGroupTasks;
}
//# sourceMappingURL=consensus-engine.d.ts.map