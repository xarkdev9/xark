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
import { BookableItemState, DEFAULT_SPACE_CONFIG, EventType, ReactionType, } from "../models/types.js";
import { addReaction, removeReaction, heartSort, calculateAgreementScore, getRankedSummary, } from "./heart-sort.js";
import { lockItem, transferOwnership, isLocked, commitItem } from "./green-lock.js";
import { createTask, assignTask, reassignTask, unassignTask, } from "./task-assignment.js";
import { buildGroundingContext, generateGroundingPrompt, } from "./ai-grounding.js";
import { StateMachine } from "./state-machine.js";
import { BOOKING_FLOW } from "./state-flows.js";
import { randomUUID } from "node:crypto";
export class ConsensusEngine {
    groups = new Map();
    spaces = new Map();
    spaceMachines = new Map();
    items = new Map();
    tasks = new Map();
    groupItems = new Map();
    groupTasks = new Map();
    listeners = [];
    defaultConfig;
    constructor(options) {
        this.defaultConfig = {
            ...DEFAULT_SPACE_CONFIG,
            ...options?.defaultConfig,
        };
    }
    // --- Event System ---
    on(listener) {
        this.listeners.push(listener);
        return () => {
            this.listeners = this.listeners.filter((l) => l !== listener);
        };
    }
    emit(event) {
        for (const listener of this.listeners) {
            listener(event);
        }
    }
    // --- Decision Space Management ---
    /**
     * Creates a new DecisionSpace with its own config and state machine.
     */
    createSpace(space) {
        this.spaces.set(space.id, space);
        const flowConfig = space.flow ?? BOOKING_FLOW;
        this.spaceMachines.set(space.id, new StateMachine(flowConfig));
        if (!this.groupItems.has(space.id)) {
            this.groupItems.set(space.id, new Set());
        }
        if (!this.groupTasks.has(space.id)) {
            this.groupTasks.set(space.id, new Set());
        }
        // Also register as group for backwards compat
        this.groups.set(space.id, {
            id: space.id,
            name: space.name,
            members: space.members,
            createdAt: space.createdAt,
        });
    }
    /**
     * Gets a DecisionSpace by ID.
     */
    getSpace(groupId) {
        return this.spaces.get(groupId);
    }
    /**
     * Gets the config for a space, falling back to default.
     */
    getSpaceConfig(groupId) {
        const space = this.spaces.get(groupId);
        return space?.config ?? this.defaultConfig;
    }
    /**
     * Gets the state machine for a space, creating a default if needed.
     */
    getStateMachine(groupId) {
        let machine = this.spaceMachines.get(groupId);
        if (!machine) {
            machine = new StateMachine(BOOKING_FLOW);
            this.spaceMachines.set(groupId, machine);
        }
        return machine;
    }
    /**
     * Sets a custom state machine for a space.
     */
    setStateMachine(groupId, machine) {
        this.spaceMachines.set(groupId, machine);
    }
    // --- Group Management (backwards compat) ---
    /**
     * Registers a group. Alias for createSpace with default config.
     */
    registerGroup(group) {
        this.groups.set(group.id, group);
        if (!this.groupItems.has(group.id)) {
            this.groupItems.set(group.id, new Set());
        }
        if (!this.groupTasks.has(group.id)) {
            this.groupTasks.set(group.id, new Set());
        }
    }
    getGroup(groupId) {
        return this.groups.get(groupId);
    }
    // --- Decision Items ---
    /**
     * Adds a new decision item to a space/group.
     * Uses crypto.randomUUID() for globally unique IDs.
     */
    addItem(groupId, ciphertextPayload, nonce, proposedBy, timestamp) {
        const config = this.getSpaceConfig(groupId);
        const machine = this.getStateMachine(groupId);
        const id = `item_${randomUUID()}`;
        const item = {
            id,
            groupId: groupId,
            ciphertextPayload,
            nonce,
            state: machine.getInitialState(),
            proposedBy,
            proposedAt: timestamp,
            reactions: [],
            weightedScore: 0,
            commitmentCiphertext: null,
            commitmentNonce: null,
            ownership: null,
            lockedAt: null,
            version: 1,
        };
        this.items.set(item.id, item);
        this.getOrCreateGroupItems(groupId).add(item.id);
        this.emit({
            type: EventType.ItemProposed,
            timestamp,
            groupId: groupId,
            actorId: proposedBy,
            payload: { itemId: item.id, ciphertextPayload, nonce },
        });
        return item;
    }
    /**
     * Proposes a new bookable item to a group.
     * Backwards-compatible alias for addItem().
     */
    proposeItem(groupId, ciphertextPayload, nonce, proposedBy, timestamp) {
        return this.addItem(groupId, ciphertextPayload, nonce, proposedBy, timestamp);
    }
    /**
     * Adds a reaction to an item. Triggers re-ranking.
     */
    react(itemId, userId, reactionType, timestamp) {
        const item = this.getItemOrThrow(itemId);
        const machine = this.getStateMachine(item.groupId);
        const config = this.getSpaceConfig(item.groupId);
        if (isLocked(item, machine)) {
            throw new Error(`Cannot react to locked item.`);
        }
        if (!config.allowSelfReaction && item.proposedBy === userId) {
            throw new Error(`Self-reactions are not allowed in this space.`);
        }
        const updated = addReaction(item, userId, reactionType, timestamp, config.reactionWeights);
        // Transition via state machine on first reaction
        if (updated.reactions.length > 0) {
            const nextState = machine.transition(updated.state, "reaction");
            if (nextState !== null && nextState !== updated.state) {
                updated.state = nextState;
            }
        }
        this.items.set(itemId, updated);
        this.emit({
            type: EventType.ReactionAdded,
            timestamp,
            groupId: item.groupId,
            actorId: userId,
            payload: { itemId, reactionType, newScore: updated.weightedScore },
        });
        return updated;
    }
    /**
     * Removes a user's reaction from an item.
     */
    unreact(itemId, userId, timestamp) {
        const item = this.getItemOrThrow(itemId);
        const machine = this.getStateMachine(item.groupId);
        const config = this.getSpaceConfig(item.groupId);
        if (isLocked(item, machine)) {
            throw new Error(`Cannot modify reactions on locked item.`);
        }
        const updated = removeReaction(item, userId, config.reactionWeights);
        this.items.set(itemId, updated);
        this.emit({
            type: EventType.ReactionRemoved,
            timestamp,
            groupId: item.groupId,
            actorId: userId,
            payload: { itemId, newScore: updated.weightedScore },
        });
        return updated;
    }
    /**
     * Locks/commits an item by providing proof.
     * The committer is automatically stamped as the owner.
     */
    lock(itemId, commitmentCiphertext, commitmentNonce, userId, timestamp) {
        const item = this.getItemOrThrow(itemId);
        const machine = this.getStateMachine(item.groupId);
        const config = this.getSpaceConfig(item.groupId);
        const locked = commitItem(item, commitmentCiphertext, commitmentNonce, userId, timestamp, machine, config.requireProofForLock);
        this.items.set(itemId, locked);
        this.emit({
            type: EventType.ItemLocked,
            timestamp: timestamp,
            groupId: item.groupId,
            actorId: userId,
            payload: {
                itemId,
                ownerId: userId,
            },
        });
        return locked;
    }
    /**
     * Transfers ownership via "I'll take care of this" button.
     */
    transfer(itemId, newOwnerId, timestamp) {
        const item = this.getItemOrThrow(itemId);
        const machine = this.getStateMachine(item.groupId);
        const previousOwnerId = item.ownership?.ownerId;
        const updated = transferOwnership(item, newOwnerId, timestamp, machine);
        this.items.set(itemId, updated);
        this.emit({
            type: EventType.OwnershipTransferred,
            timestamp,
            groupId: item.groupId,
            actorId: newOwnerId,
            payload: {
                itemId,
                previousOwnerId,
                newOwnerId,
            },
        });
        return updated;
    }
    // --- Task Assignment (Non-bookable items) ---
    addTask(groupId, title, description, createdBy, timestamp) {
        const task = createTask(groupId, title, description, createdBy, timestamp);
        this.tasks.set(task.id, task);
        this.getOrCreateGroupTasks(groupId).add(task.id);
        this.emit({
            type: EventType.TaskCreated,
            timestamp,
            groupId,
            actorId: createdBy,
            payload: { taskId: task.id, title },
        });
        return task;
    }
    claimTask(taskId, userId, timestamp) {
        const task = this.getTaskOrThrow(taskId);
        const updated = task.assignee
            ? reassignTask(task, userId, timestamp)
            : assignTask(task, userId, timestamp);
        this.tasks.set(taskId, updated);
        this.emit({
            type: EventType.TaskAssigned,
            timestamp,
            groupId: task.groupId,
            actorId: userId,
            payload: { taskId, title: task.title, assigneeId: userId },
        });
        return updated;
    }
    releaseTask(taskId, timestamp) {
        const task = this.getTaskOrThrow(taskId);
        const updated = unassignTask(task);
        this.tasks.set(taskId, updated);
        this.emit({
            type: EventType.TaskReleased,
            timestamp: timestamp ?? Date.now(),
            groupId: task.groupId,
            actorId: task.assignee ?? "",
            payload: { taskId, title: task.title },
        });
        return updated;
    }
    // --- Queries ---
    getItem(itemId) {
        return this.items.get(itemId);
    }
    getTask(taskId) {
        return this.tasks.get(taskId);
    }
    /**
     * Returns all items for a group/space, sorted by Heart-Sort (weighted score descending).
     * Supports pagination via offset/limit.
     */
    getGroupItems(groupId, options) {
        const itemIds = this.groupItems.get(groupId);
        if (!itemIds)
            return [];
        const items = [];
        for (const id of itemIds) {
            const item = this.items.get(id);
            if (item)
                items.push(item);
        }
        const sorted = heartSort(items);
        if (options) {
            const offset = options.offset ?? 0;
            const limit = options.limit ?? sorted.length;
            return sorted.slice(offset, offset + limit);
        }
        return sorted;
    }
    /**
     * Returns only locked items for a group/space.
     */
    getLockedItems(groupId) {
        const machine = this.getStateMachine(groupId);
        return this.getGroupItems(groupId).filter((item) => isLocked(item, machine));
    }
    /**
     * Returns only unlocked (active) items for a group/space, sorted by score.
     */
    getActiveItems(groupId) {
        const machine = this.getStateMachine(groupId);
        return this.getGroupItems(groupId).filter((item) => !isLocked(item, machine));
    }
    /**
     * Returns all tasks for a group/space.
     */
    getGroupTasks(groupId) {
        const taskIds = this.groupTasks.get(groupId);
        if (!taskIds)
            return [];
        const tasks = [];
        for (const id of taskIds) {
            const task = this.tasks.get(id);
            if (task)
                tasks.push(task);
        }
        return tasks;
    }
    /**
     * Gets ranked summary of items for display.
     */
    getRankedItems(groupId) {
        const group = this.groups.get(groupId);
        const totalMembers = group?.members.length ?? 0;
        const config = this.getSpaceConfig(groupId);
        const items = this.getActiveItems(groupId);
        return getRankedSummary(items, totalMembers, config.groupFavoriteThreshold);
    }
    /**
     * Calculates agreement score for a specific item.
     */
    getAgreementScore(itemId) {
        const item = this.getItemOrThrow(itemId);
        const group = this.groups.get(item.groupId);
        const totalMembers = group?.members.length ?? 0;
        const config = this.getSpaceConfig(item.groupId);
        return calculateAgreementScore(item, totalMembers, config.groupFavoriteThreshold);
    }
    // --- Signal Breakdown (for frontend variable reward schedule) ---
    /**
     * Returns the signal breakdown for an item.
     * Frontend uses isUnanimousLoveIt to trigger the Social Gold burst.
     */
    getSignalBreakdown(itemId) {
        const item = this.getItemOrThrow(itemId);
        const group = this.groups.get(item.groupId);
        const totalMembers = group?.members.length ?? 0;
        const loveIt = item.reactions.filter((r) => r.type === ReactionType.LoveIt).length;
        const worksForMe = item.reactions.filter((r) => r.type === ReactionType.WorksForMe).length;
        const notForMe = item.reactions.filter((r) => r.type === ReactionType.NotForMe).length;
        const isUnanimousLoveIt = totalMembers > 0 && loveIt === totalMembers;
        return { loveIt, worksForMe, notForMe, isUnanimousLoveIt };
    }
    // --- AI Grounding ---
    /**
     * Builds the grounding context for @hello.
     * Returns all locked decisions as hard constraints and active items as context.
     */
    getGroundingContext(groupId) {
        const machine = this.getStateMachine(groupId);
        const items = this.getGroupItems(groupId);
        const tasks = this.getGroupTasks(groupId);
        return buildGroundingContext(groupId, items, tasks, machine);
    }
    /**
     * Generates the system prompt fragment for @hello.
     */
    getGroundingPrompt(groupId) {
        const context = this.getGroundingContext(groupId);
        return generateGroundingPrompt(context);
    }
    // --- Private helpers ---
    getItemOrThrow(itemId) {
        const item = this.items.get(itemId);
        if (!item)
            throw new Error(`Item "${itemId}" not found.`);
        return item;
    }
    getTaskOrThrow(taskId) {
        const task = this.tasks.get(taskId);
        if (!task)
            throw new Error(`Task "${taskId}" not found.`);
        return task;
    }
    getOrCreateGroupItems(groupId) {
        let set = this.groupItems.get(groupId);
        if (!set) {
            set = new Set();
            this.groupItems.set(groupId, set);
        }
        return set;
    }
    getOrCreateGroupTasks(groupId) {
        let set = this.groupTasks.get(groupId);
        if (!set) {
            set = new Set();
            this.groupTasks.set(groupId, set);
        }
        return set;
    }
}
//# sourceMappingURL=consensus-engine.js.map