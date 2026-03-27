/**
 * Xark Universal Decision Engine
 *
 * Orchestrates the full decision lifecycle:
 *   Options proposed (by Apify, manually, or any source)
 *     → Members react (❤️/👍🏻) → Weighted Heart-Sort re-orders in real-time
 *       → Any member commits (books, purchases, decides) + provides proof
 *         → Lock activates → Committer stamped as owner
 *           → @xark grounds all future suggestions to locked state
 *             → Another member can claim via "I'll take care of this"
 *
 * Supports multiple DecisionSpaces — each with its own state machine,
 * reaction weights, thresholds, and items.
 *
 * No gates. No votes. No clustering. Just signal → act → lock.
 */

import type {
  BookableItem,
  CommitmentProof,
  DecisionSpace,
  EngineEvent,
  Group,
  GroupId,
  ItemId,
  SpaceConfig,
  SpaceId,
  Task,
  TaskId,
  UserId,
} from "../models/types.js";
import {
  BookableItemState,
  DEFAULT_SPACE_CONFIG,
  EventType,
  ReactionType,
} from "../models/types.js";
import {
  addReaction,
  removeReaction,
  heartSort,
  calculateAgreementScore,
  getRankedSummary,
} from "./heart-sort.js";
import { lockItem, transferOwnership, isLocked, commitItem } from "./green-lock.js";
import {
  createTask,
  assignTask,
  reassignTask,
  unassignTask,
} from "./task-assignment.js";
import {
  buildGroundingContext,
  generateGroundingPrompt,
  type GroundingContext,
} from "./ai-grounding.js";
import { StateMachine } from "./state-machine.js";
import { BOOKING_FLOW } from "./state-flows.js";
import { randomUUID } from "node:crypto";

export type EventListener = (event: EngineEvent) => void;

export interface EngineOptions {
  defaultConfig?: Partial<SpaceConfig>;
}

export class ConsensusEngine {
  private groups: Map<GroupId, Group> = new Map();
  private spaces: Map<SpaceId, DecisionSpace> = new Map();
  private spaceMachines: Map<SpaceId, StateMachine> = new Map();
  private items: Map<ItemId, BookableItem> = new Map();
  private tasks: Map<TaskId, Task> = new Map();
  private groupItems: Map<GroupId, Set<ItemId>> = new Map();
  private groupTasks: Map<GroupId, Set<TaskId>> = new Map();
  private listeners: EventListener[] = [];
  private defaultConfig: SpaceConfig;

  constructor(options?: EngineOptions) {
    this.defaultConfig = {
      ...DEFAULT_SPACE_CONFIG,
      ...options?.defaultConfig,
    };
  }

  // --- Event System ---

  on(listener: EventListener): () => void {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener);
    };
  }

  private emit(event: EngineEvent): void {
    for (const listener of this.listeners) {
      listener(event);
    }
  }

  // --- Decision Space Management ---

  /**
   * Creates a new DecisionSpace with its own config and state machine.
   */
  createSpace(space: DecisionSpace): void {
    this.spaces.set(space.id, space);
    const flowConfig = space.flow ?? BOOKING_FLOW;
    this.spaceMachines.set(space.id, new StateMachine(flowConfig));
    if (!this.groupItems.has(space.id as GroupId)) {
      this.groupItems.set(space.id as GroupId, new Set());
    }
    if (!this.groupTasks.has(space.id as GroupId)) {
      this.groupTasks.set(space.id as GroupId, new Set());
    }
    // Also register as group for backwards compat
    this.groups.set(space.id as GroupId, {
      id: space.id as GroupId,
      name: space.name,
      members: space.members,
      createdAt: space.createdAt,
    });
  }

  /**
   * Gets a DecisionSpace by ID.
   */
  getSpace(spaceId: SpaceId): DecisionSpace | undefined {
    return this.spaces.get(spaceId);
  }

  /**
   * Gets the config for a space, falling back to default.
   */
  getSpaceConfig(spaceId: SpaceId): SpaceConfig {
    const space = this.spaces.get(spaceId);
    return space?.config ?? this.defaultConfig;
  }

  /**
   * Gets the state machine for a space, creating a default if needed.
   */
  getStateMachine(spaceId: SpaceId): StateMachine {
    let machine = this.spaceMachines.get(spaceId);
    if (!machine) {
      machine = new StateMachine(BOOKING_FLOW);
      this.spaceMachines.set(spaceId, machine);
    }
    return machine;
  }

  /**
   * Sets a custom state machine for a space.
   */
  setStateMachine(spaceId: SpaceId, machine: StateMachine): void {
    this.spaceMachines.set(spaceId, machine);
  }

  // --- Group Management (backwards compat) ---

  /**
   * Registers a group. Alias for createSpace with default config.
   */
  registerGroup(group: Group): void {
    this.groups.set(group.id, group);
    if (!this.groupItems.has(group.id)) {
      this.groupItems.set(group.id, new Set());
    }
    if (!this.groupTasks.has(group.id)) {
      this.groupTasks.set(group.id, new Set());
    }
  }

  getGroup(groupId: GroupId): Group | undefined {
    return this.groups.get(groupId);
  }

  // --- Decision Items ---

  /**
   * Adds a new decision item to a space/group.
   * Uses crypto.randomUUID() for globally unique IDs.
   */
  addItem(
    spaceId: SpaceId,
    title: string,
    description: string,
    category: string,
    proposedBy: UserId,
    timestamp: number
  ): BookableItem {
    const config = this.getSpaceConfig(spaceId);
    const machine = this.getStateMachine(spaceId);
    const id = `item_${randomUUID()}` as ItemId;

    const item: BookableItem = {
      id,
      spaceId,
      groupId: spaceId as GroupId,
      title,
      description,
      category,
      state: machine.getInitialState() as BookableItem["state"],
      proposedBy,
      proposedAt: timestamp,
      reactions: [],
      weightedScore: 0,
      commitmentProof: null,
      bookingProof: null,
      ownership: null,
      ownershipHistory: [],
      lockedAt: null,
      version: 1,
      metadata: {},
    };

    this.items.set(item.id, item);
    this.getOrCreateGroupItems(spaceId as GroupId).add(item.id);

    this.emit({
      type: EventType.ItemProposed,
      timestamp,
      groupId: spaceId as GroupId,
      actorId: proposedBy,
      payload: { itemId: item.id, title, category },
    });

    return item;
  }

  /**
   * Proposes a new bookable item to a group.
   * Backwards-compatible alias for addItem().
   */
  proposeItem(
    groupId: GroupId,
    title: string,
    description: string,
    category: string,
    proposedBy: UserId,
    timestamp: number
  ): BookableItem {
    return this.addItem(groupId as SpaceId, title, description, category, proposedBy, timestamp);
  }

  /**
   * Adds a reaction to an item. Triggers re-ranking.
   */
  react(
    itemId: ItemId,
    userId: UserId,
    reactionType: ReactionType,
    timestamp: number
  ): BookableItem {
    const item = this.getItemOrThrow(itemId);
    const machine = this.getStateMachine(item.groupId as SpaceId);
    const config = this.getSpaceConfig(item.groupId as SpaceId);

    if (isLocked(item, machine)) {
      throw new Error(`Cannot react to locked item "${item.title}".`);
    }

    if (!config.allowSelfReaction && item.proposedBy === userId) {
      throw new Error(`Self-reactions are not allowed in this space.`);
    }

    const updated = addReaction(item, userId, reactionType, timestamp, config.reactionWeights);

    // Transition via state machine on first reaction
    if (updated.reactions.length > 0) {
      const nextState = machine.transition(updated.state as string, "reaction");
      if (nextState !== null && nextState !== updated.state) {
        (updated as any).state = nextState;
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
  unreact(itemId: ItemId, userId: UserId, timestamp: number): BookableItem {
    const item = this.getItemOrThrow(itemId);
    const machine = this.getStateMachine(item.groupId as SpaceId);
    const config = this.getSpaceConfig(item.groupId as SpaceId);

    if (isLocked(item, machine)) {
      throw new Error(`Cannot modify reactions on locked item "${item.title}".`);
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
  lock(itemId: ItemId, proof: CommitmentProof): BookableItem {
    const item = this.getItemOrThrow(itemId);
    const machine = this.getStateMachine(item.groupId as SpaceId);
    const config = this.getSpaceConfig(item.groupId as SpaceId);

    const locked = commitItem(item, proof, machine, config.requireProofForLock);
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
  transfer(
    itemId: ItemId,
    newOwnerId: UserId,
    timestamp: number
  ): BookableItem {
    const item = this.getItemOrThrow(itemId);
    const machine = this.getStateMachine(item.groupId as SpaceId);
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
        title: item.title,
        previousOwnerId,
        newOwnerId,
      },
    });

    return updated;
  }

  // --- Task Assignment (Non-bookable items) ---

  addTask(
    groupId: GroupId,
    title: string,
    description: string,
    createdBy: UserId,
    timestamp: number
  ): Task {
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

  claimTask(taskId: TaskId, userId: UserId, timestamp: number): Task {
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

  releaseTask(taskId: TaskId, timestamp?: number): Task {
    const task = this.getTaskOrThrow(taskId);
    const updated = unassignTask(task);
    this.tasks.set(taskId, updated);

    this.emit({
      type: EventType.TaskReleased,
      timestamp: timestamp ?? Date.now(),
      groupId: task.groupId,
      actorId: task.assignee ?? ("" as UserId),
      payload: { taskId, title: task.title },
    });

    return updated;
  }

  // --- Queries ---

  getItem(itemId: ItemId): BookableItem | undefined {
    return this.items.get(itemId);
  }

  getTask(taskId: TaskId): Task | undefined {
    return this.tasks.get(taskId);
  }

  /**
   * Returns all items for a group/space, sorted by Heart-Sort (weighted score descending).
   * Supports pagination via offset/limit.
   */
  getGroupItems(groupId: GroupId, options?: { offset?: number; limit?: number }): BookableItem[] {
    const itemIds = this.groupItems.get(groupId);
    if (!itemIds) return [];

    const items: BookableItem[] = [];
    for (const id of itemIds) {
      const item = this.items.get(id);
      if (item) items.push(item);
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
  getLockedItems(groupId: GroupId): BookableItem[] {
    const machine = this.getStateMachine(groupId as SpaceId);
    return this.getGroupItems(groupId).filter((item) => isLocked(item, machine));
  }

  /**
   * Returns only unlocked (active) items for a group/space, sorted by score.
   */
  getActiveItems(groupId: GroupId): BookableItem[] {
    const machine = this.getStateMachine(groupId as SpaceId);
    return this.getGroupItems(groupId).filter((item) => !isLocked(item, machine));
  }

  /**
   * Returns all tasks for a group/space.
   */
  getGroupTasks(groupId: GroupId): Task[] {
    const taskIds = this.groupTasks.get(groupId);
    if (!taskIds) return [];

    const tasks: Task[] = [];
    for (const id of taskIds) {
      const task = this.tasks.get(id);
      if (task) tasks.push(task);
    }
    return tasks;
  }

  /**
   * Gets ranked summary of items for display.
   */
  getRankedItems(groupId: GroupId): ReturnType<typeof getRankedSummary> {
    const group = this.groups.get(groupId);
    const totalMembers = group?.members.length ?? 0;
    const config = this.getSpaceConfig(groupId as SpaceId);
    const items = this.getActiveItems(groupId);
    return getRankedSummary(items, totalMembers, config.groupFavoriteThreshold);
  }

  /**
   * Calculates agreement score for a specific item.
   */
  getAgreementScore(
    itemId: ItemId
  ): { percentage: number; isGroupFavorite: boolean } {
    const item = this.getItemOrThrow(itemId);
    const group = this.groups.get(item.groupId);
    const totalMembers = group?.members.length ?? 0;
    const config = this.getSpaceConfig(item.groupId as SpaceId);
    return calculateAgreementScore(item, totalMembers, config.groupFavoriteThreshold);
  }

  // --- Signal Breakdown (for frontend variable reward schedule) ---

  /**
   * Returns the signal breakdown for an item.
   * Frontend uses isUnanimousLoveIt to trigger the Social Gold burst.
   */
  getSignalBreakdown(
    itemId: ItemId
  ): { loveIt: number; worksForMe: number; notForMe: number; isUnanimousLoveIt: boolean } {
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
   * Builds the grounding context for @xark.
   * Returns all locked decisions as hard constraints and active items as context.
   */
  getGroundingContext(groupId: GroupId): GroundingContext {
    const machine = this.getStateMachine(groupId as SpaceId);
    const items = this.getGroupItems(groupId);
    const tasks = this.getGroupTasks(groupId);
    return buildGroundingContext(groupId, items, tasks, machine);
  }

  /**
   * Generates the system prompt fragment for @xark.
   */
  getGroundingPrompt(groupId: GroupId): string {
    const context = this.getGroundingContext(groupId);
    return generateGroundingPrompt(context);
  }

  // --- Private helpers ---

  private getItemOrThrow(itemId: ItemId): BookableItem {
    const item = this.items.get(itemId);
    if (!item) throw new Error(`Item "${itemId}" not found.`);
    return item;
  }

  private getTaskOrThrow(taskId: TaskId): Task {
    const task = this.tasks.get(taskId);
    if (!task) throw new Error(`Task "${taskId}" not found.`);
    return task;
  }

  private getOrCreateGroupItems(groupId: GroupId): Set<ItemId> {
    let set = this.groupItems.get(groupId);
    if (!set) {
      set = new Set();
      this.groupItems.set(groupId, set);
    }
    return set;
  }

  private getOrCreateGroupTasks(groupId: GroupId): Set<TaskId> {
    let set = this.groupTasks.get(groupId);
    if (!set) {
      set = new Set();
      this.groupTasks.set(groupId, set);
    }
    return set;
  }
}
