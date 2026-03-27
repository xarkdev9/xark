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
import { BookableItemState, EventType, ReactionType, } from "../models/types.js";
import { addReaction, removeReaction, heartSort, calculateAgreementScore, getRankedSummary, } from "./heart-sort.js";
import { lockItem, transferOwnership, isLocked } from "./green-lock.js";
import { createTask, assignTask, reassignTask, unassignTask, } from "./task-assignment.js";
import { buildGroundingContext, generateGroundingPrompt, } from "./ai-grounding.js";
export class ConsensusEngine {
    groups = new Map();
    items = new Map();
    tasks = new Map();
    groupItems = new Map();
    groupTasks = new Map();
    listeners = [];
    itemCounter = 0;
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
    // --- Group Management ---
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
    // --- Bookable Items (Green-Lock Engine) ---
    /**
     * Proposes a new bookable item to a group (typically from Apify agents).
     */
    proposeItem(groupId, title, description, category, proposedBy, timestamp) {
        this.itemCounter++;
        const item = {
            id: `item_${this.itemCounter}`,
            groupId,
            title,
            description,
            category,
            state: BookableItemState.Proposed,
            proposedBy,
            proposedAt: timestamp,
            reactions: [],
            weightedScore: 0,
            bookingProof: null,
            ownership: null,
            ownershipHistory: [],
            lockedAt: null,
        };
        this.items.set(item.id, item);
        this.getOrCreateGroupItems(groupId).add(item.id);
        this.emit({
            type: EventType.ItemProposed,
            timestamp,
            groupId,
            actorId: proposedBy,
            payload: { itemId: item.id, title, category },
        });
        return item;
    }
    /**
     * Adds a reaction (❤️ or 👍🏻) to an item. Triggers Heart-Sort re-ordering.
     */
    react(itemId, userId, reactionType, timestamp) {
        const item = this.getItemOrThrow(itemId);
        if (isLocked(item)) {
            throw new Error(`Cannot react to locked item "${item.title}".`);
        }
        const updated = addReaction(item, userId, reactionType, timestamp);
        // Transition to heart_sorted once any reaction exists
        if (updated.state === BookableItemState.Proposed && updated.reactions.length > 0) {
            updated.state = BookableItemState.HeartSorted;
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
        if (isLocked(item)) {
            throw new Error(`Cannot modify reactions on locked item "${item.title}".`);
        }
        const updated = removeReaction(item, userId);
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
     * Locks an item by providing booking confirmation.
     * The booker is automatically stamped as the owner.
     */
    lock(itemId, proof) {
        const item = this.getItemOrThrow(itemId);
        const locked = lockItem(item, proof);
        this.items.set(itemId, locked);
        this.emit({
            type: EventType.ItemLocked,
            timestamp: proof.submittedAt,
            groupId: item.groupId,
            actorId: proof.submittedBy,
            payload: {
                itemId,
                title: item.title,
                proofType: proof.type,
                ownerId: proof.submittedBy,
            },
        });
        return locked;
    }
    /**
     * Transfers ownership via "I'll take care of this" button.
     */
    transfer(itemId, newOwnerId, timestamp) {
        const item = this.getItemOrThrow(itemId);
        const previousOwnerId = item.ownership?.ownerId;
        const updated = transferOwnership(item, newOwnerId, timestamp);
        this.items.set(itemId, updated);
        this.emit({
            type: EventType.OwnershipTransferred,
            timestamp,
            groupId: item.groupId,
            actorId: newOwnerId,
            payload: {
                itemId,
                title: item.title,
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
    releaseTask(taskId) {
        const task = this.getTaskOrThrow(taskId);
        const updated = unassignTask(task);
        this.tasks.set(taskId, updated);
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
     * Returns all items for a group, sorted by Heart-Sort (weighted score descending).
     */
    getGroupItems(groupId) {
        const itemIds = this.groupItems.get(groupId);
        if (!itemIds)
            return [];
        const items = [];
        for (const id of itemIds) {
            const item = this.items.get(id);
            if (item)
                items.push(item);
        }
        return heartSort(items);
    }
    /**
     * Returns only locked items for a group.
     */
    getLockedItems(groupId) {
        return this.getGroupItems(groupId).filter(isLocked);
    }
    /**
     * Returns only unlocked (active) items for a group, sorted by score.
     */
    getActiveItems(groupId) {
        return this.getGroupItems(groupId).filter((item) => !isLocked(item));
    }
    /**
     * Returns all tasks for a group.
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
        const items = this.getActiveItems(groupId);
        return getRankedSummary(items, totalMembers);
    }
    /**
     * Calculates agreement score for a specific item.
     */
    getAgreementScore(itemId) {
        const item = this.getItemOrThrow(itemId);
        const group = this.groups.get(item.groupId);
        const totalMembers = group?.members.length ?? 0;
        return calculateAgreementScore(item, totalMembers);
    }
    // --- AI Grounding ---
    /**
     * Builds the grounding context for @xark.
     * Returns all locked decisions as hard constraints and active items as context.
     */
    getGroundingContext(groupId) {
        const items = this.getGroupItems(groupId);
        const tasks = this.getGroupTasks(groupId);
        return buildGroundingContext(groupId, items, tasks);
    }
    /**
     * Generates the system prompt fragment for @xark.
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