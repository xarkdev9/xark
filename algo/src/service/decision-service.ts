/**
 * Decision Service — Stateless, Persistent, Planet-Scale
 *
 * Unlike ConsensusEngine (which holds state in Maps), this service
 * loads from persistence, computes with pure functions, saves back,
 * and broadcasts events. Every call is independent — no shared state
 * between requests. This means:
 *
 * - Horizontally scalable (any node can serve any request)
 * - State survives restarts (persisted via adapter)
 * - Multi-user sync via event bus (real-time updates)
 * - Optimistic concurrency via version field (no lost updates)
 * - Cache-friendly (invalidate on write, serve from cache on read)
 *
 * Dependency injection: pass any adapters via constructor.
 * All I/O goes through ports — zero direct dependencies on
 * databases, message brokers, or auth providers.
 */

import type { PersistencePort } from "../ports/persistence.js";
import type { EventBusPort } from "../ports/event-bus.js";
import type { AuthPort, Identity, Action } from "../ports/auth.js";
import type { CachePort } from "../ports/cache.js";
import type {
  BookableItem,
  CommitmentProof,
  DecisionSpace,
  EngineEvent,
  GroupMember,
  ItemId,
  SpaceConfig,
  GroupId,
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
} from "../engine/heart-sort.js";
import { commitItem, transferOwnership, isLocked } from "../engine/green-lock.js";
import {
  createTask,
  assignTask,
  reassignTask,
  unassignTask,
} from "../engine/task-assignment.js";
import {
  buildGroundingContext,
  generateGroundingPrompt,
  checkSuggestionConflicts,
  type GroundingContext,
} from "../engine/ai-grounding.js";
import { StateMachine } from "../engine/state-machine.js";
import { BOOKING_FLOW } from "../engine/state-flows.js";
import type { StateFlowConfig } from "../engine/state-machine.js";
import { randomUUID } from "node:crypto";

// --- Service Options ---

export interface ServiceOptions {
  persistence: PersistencePort;
  eventBus: EventBusPort;
  auth: AuthPort;
  cache?: CachePort;
  defaultConfig?: Partial<SpaceConfig>;
  defaultFlow?: StateFlowConfig;
  cacheTtlMs?: number;
}

// --- Auth Error ---

export class AuthError extends Error {
  constructor(action: Action, groupId: GroupId) {
    super(`Not authorized: ${action} on space "${groupId}"`);
    this.name = "AuthError";
  }
}

export class NotFoundError extends Error {
  constructor(entity: string, id: string) {
    super(`${entity} "${id}" not found`);
    this.name = "NotFoundError";
  }
}

// --- Service ---

export class DecisionService {
  private readonly persistence: PersistencePort;
  private readonly eventBus: EventBusPort;
  private readonly auth: AuthPort;
  private readonly cache: CachePort | null;
  private readonly defaultConfig: SpaceConfig;
  private readonly defaultFlow: StateFlowConfig;
  private readonly cacheTtlMs: number;

  constructor(options: ServiceOptions) {
    this.persistence = options.persistence;
    this.eventBus = options.eventBus;
    this.auth = options.auth;
    this.cache = options.cache ?? null;
    this.defaultConfig = { ...DEFAULT_SPACE_CONFIG, ...options.defaultConfig };
    this.defaultFlow = options.defaultFlow ?? BOOKING_FLOW;
    this.cacheTtlMs = options.cacheTtlMs ?? 60_000; // 1 minute default
  }

  // --- Space Management ---

  async createSpace(
    identity: Identity,
    name: string,
    members: GroupMember[],
    config?: Partial<SpaceConfig>,
    flow?: StateFlowConfig
  ): Promise<DecisionSpace> {
    const groupId = `space_${randomUUID()}` as GroupId;
    await this.authorize(identity, "space:create", groupId);

    const space: DecisionSpace = {
      id: groupId,
      name,
      members,
      config: { ...this.defaultConfig, ...config },
      flow: flow ?? this.defaultFlow,
      createdAt: Date.now(),
    };

    await this.persistence.saveSpace(space);
    return space;
  }

  async getSpace(identity: Identity, groupId: GroupId): Promise<DecisionSpace> {
    await this.authorize(identity, "space:read", groupId);
    const space = await this.persistence.getSpace(groupId);
    if (!space) throw new NotFoundError("Space", groupId);
    return space;
  }

  async deleteSpace(identity: Identity, groupId: GroupId): Promise<void> {
    await this.authorize(identity, "space:delete", groupId);
    await this.persistence.deleteSpace(groupId);
    await this.invalidateSpaceCache(groupId);
  }

  // --- Items ---

  async addItem(
    identity: Identity,
    groupId: GroupId,
    ciphertextPayload: string,
    nonce: string
  ): Promise<BookableItem> {
    await this.authorize(identity, "item:propose", groupId);
    const space = await this.loadSpace(groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const now = Date.now();
    const id = `item_${randomUUID()}` as ItemId;

    const item: BookableItem = {
      id,
      groupId: groupId as GroupId,
      ciphertextPayload,
      nonce,
      state: machine.getInitialState() as BookableItem["state"],
      proposedBy: identity.userId,
      proposedAt: now,
      reactions: [],
      weightedScore: 0,
      commitmentCiphertext: null,
      commitmentNonce: null,
      ownership: null,
      lockedAt: null,
      version: 1,
    };

    await this.persistence.saveItem(item);
    await this.invalidateSpaceCache(groupId);

    const event: EngineEvent = {
      type: EventType.ItemProposed,
      timestamp: now,
      groupId: groupId as GroupId,
      actorId: identity.userId,
      payload: { itemId: id, ciphertextPayload, nonce },
    };
    await this.eventBus.publish(`space:${groupId}`, event);

    return item;
  }

  async react(
    identity: Identity,
    itemId: ItemId,
    reactionType: ReactionType
  ): Promise<BookableItem> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "item:react", item.groupId);

    const space = await this.loadSpace(item.groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const config = space.config ?? this.defaultConfig;
    const now = Date.now();

    if (isLocked(item, machine)) {
      throw new Error(`Cannot react to locked item.`);
    }

    if (!config.allowSelfReaction && item.proposedBy === identity.userId) {
      throw new Error(`Self-reactions are not allowed in this space.`);
    }

    let updated = addReaction(item, identity.userId, reactionType, now, config.reactionWeights);

    // State transition on reaction
    if (updated.reactions.length > 0) {
      const nextState = machine.transition(updated.state as string, "reaction");
      if (nextState !== null && nextState !== updated.state) {
        updated = { ...updated, state: nextState as BookableItem["state"] };
      }
    }

    updated = { ...updated, version: item.version + 1 };
    await this.persistence.saveItem(updated);
    await this.invalidateSpaceCache(item.groupId);

    const event: EngineEvent = {
      type: EventType.ReactionAdded,
      timestamp: now,
      groupId: item.groupId as GroupId,
      actorId: identity.userId,
      payload: { itemId, reactionType, newScore: updated.weightedScore },
    };
    await this.eventBus.publish(`space:${item.groupId}`, event);

    return updated;
  }

  async unreact(
    identity: Identity,
    itemId: ItemId
  ): Promise<BookableItem> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "item:react", item.groupId);

    const space = await this.loadSpace(item.groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const config = space.config ?? this.defaultConfig;
    const now = Date.now();

    if (isLocked(item, machine)) {
      throw new Error(`Cannot modify reactions on locked item.`);
    }

    let updated = removeReaction(item, identity.userId, config.reactionWeights);
    updated = { ...updated, version: item.version + 1 };
    await this.persistence.saveItem(updated);
    await this.invalidateSpaceCache(item.groupId);

    const event: EngineEvent = {
      type: EventType.ReactionRemoved,
      timestamp: now,
      groupId: item.groupId as GroupId,
      actorId: identity.userId,
      payload: { itemId, newScore: updated.weightedScore },
    };
    await this.eventBus.publish(`space:${item.groupId}`, event);

    return updated;
  }

  async lock(
    identity: Identity,
    itemId: ItemId,
    commitmentCiphertext: string,
    commitmentNonce: string
  ): Promise<BookableItem> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "item:lock", item.groupId);

    const space = await this.loadSpace(item.groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);

    const config = space.config ?? this.defaultConfig;
    const now = Date.now();
    let locked = commitItem(item, commitmentCiphertext, commitmentNonce, identity.userId, now, machine, config.requireProofForLock);
    locked = { ...locked, version: item.version + 1 };
    await this.persistence.saveItem(locked);
    await this.invalidateSpaceCache(item.groupId);

    const event: EngineEvent = {
      type: EventType.ItemLocked,
      timestamp: now,
      groupId: item.groupId as GroupId,
      actorId: identity.userId,
      payload: {
        itemId,
        ownerId: identity.userId,
      },
    };
    await this.eventBus.publish(`space:${item.groupId}`, event);

    return locked;
  }

  async transfer(
    identity: Identity,
    itemId: ItemId,
    newOwnerId: UserId
  ): Promise<BookableItem> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "item:transfer", item.groupId);

    const space = await this.loadSpace(item.groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const now = Date.now();
    const previousOwnerId = item.ownership?.ownerId;

    let updated = transferOwnership(item, newOwnerId, now, machine);
    updated = { ...updated, version: item.version + 1 };
    await this.persistence.saveItem(updated);
    await this.invalidateSpaceCache(item.groupId);

    const event: EngineEvent = {
      type: EventType.OwnershipTransferred,
      timestamp: now,
      groupId: item.groupId as GroupId,
      actorId: newOwnerId,
      payload: { itemId, previousOwnerId, newOwnerId },
    };
    await this.eventBus.publish(`space:${item.groupId}`, event);

    return updated;
  }

  // --- Tasks ---

  async addTask(
    identity: Identity,
    groupId: GroupId,
    title: string,
    description: string
  ): Promise<Task> {
    await this.authorize(identity, "task:create", groupId);
    const now = Date.now();

    const task = createTask(
      groupId as GroupId,
      title,
      description,
      identity.userId,
      now
    );

    await this.persistence.saveTask(task);
    await this.invalidateSpaceCache(groupId);

    const event: EngineEvent = {
      type: EventType.TaskCreated,
      timestamp: now,
      groupId: groupId as GroupId,
      actorId: identity.userId,
      payload: { taskId: task.id, title },
    };
    await this.eventBus.publish(`space:${groupId}`, event);

    return task;
  }

  async claimTask(
    identity: Identity,
    taskId: TaskId
  ): Promise<Task> {
    const task = await this.loadTask(taskId);
    const groupId = task.groupId as GroupId;
    await this.authorize(identity, "task:claim", groupId);
    const now = Date.now();

    const updated = task.assignee
      ? reassignTask(task, identity.userId, now)
      : assignTask(task, identity.userId, now);

    await this.persistence.saveTask(updated);
    await this.invalidateSpaceCache(groupId);

    const event: EngineEvent = {
      type: EventType.TaskAssigned,
      timestamp: now,
      groupId: task.groupId,
      actorId: identity.userId,
      payload: { taskId, title: task.title, assigneeId: identity.userId },
    };
    await this.eventBus.publish(`space:${groupId}`, event);

    return updated;
  }

  async releaseTask(
    identity: Identity,
    taskId: TaskId
  ): Promise<Task> {
    const task = await this.loadTask(taskId);
    const groupId = task.groupId as GroupId;
    await this.authorize(identity, "task:release", groupId);

    const updated = unassignTask(task);
    await this.persistence.saveTask(updated);
    await this.invalidateSpaceCache(groupId);

    const event: EngineEvent = {
      type: EventType.TaskReleased,
      timestamp: Date.now(),
      groupId: task.groupId,
      actorId: identity.userId,
      payload: { taskId, title: task.title },
    };
    await this.eventBus.publish(`space:${groupId}`, event);

    return updated;
  }

  // --- Queries (cacheable) ---

  async getItem(identity: Identity, itemId: ItemId): Promise<BookableItem> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "space:read", item.groupId);
    return item;
  }

  async getRankedItems(
    identity: Identity,
    groupId: GroupId
  ): Promise<ReturnType<typeof getRankedSummary>> {
    await this.authorize(identity, "space:read", groupId);

    // Try cache
    const cacheKey = `ranked:${groupId}`;
    if (this.cache) {
      const cached = await this.cache.get<ReturnType<typeof getRankedSummary>>(cacheKey);
      if (cached) return cached;
    }

    const space = await this.loadSpace(groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const config = space.config ?? this.defaultConfig;
    const items = await this.persistence.getItemsBySpace(groupId);
    const active = items.filter((item) => !isLocked(item, machine));
    const totalMembers = space.members.length;
    const ranked = getRankedSummary(active, totalMembers, config.groupFavoriteThreshold);

    if (this.cache) {
      await this.cache.set(cacheKey, ranked, this.cacheTtlMs);
    }

    return ranked;
  }

  async getLockedItems(
    identity: Identity,
    groupId: GroupId
  ): Promise<BookableItem[]> {
    await this.authorize(identity, "space:read", groupId);
    const space = await this.loadSpace(groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const items = await this.persistence.getItemsBySpace(groupId);
    return items.filter((item) => isLocked(item, machine));
  }

  async getActiveItems(
    identity: Identity,
    groupId: GroupId
  ): Promise<BookableItem[]> {
    await this.authorize(identity, "space:read", groupId);
    const space = await this.loadSpace(groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const items = await this.persistence.getItemsBySpace(groupId);
    const active = items.filter((item) => !isLocked(item, machine));
    return heartSort(active);
  }

  async getAgreementScore(
    identity: Identity,
    itemId: ItemId
  ): Promise<{ percentage: number; isGroupFavorite: boolean }> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "space:read", item.groupId);
    const space = await this.loadSpace(item.groupId);
    const config = space.config ?? this.defaultConfig;
    return calculateAgreementScore(item, space.members.length, config.groupFavoriteThreshold);
  }

  async getSignalBreakdown(
    identity: Identity,
    itemId: ItemId
  ): Promise<{
    loveIt: number;
    worksForMe: number;
    notForMe: number;
    isUnanimousLoveIt: boolean;
  }> {
    const item = await this.loadItem(itemId);
    await this.authorize(identity, "space:read", item.groupId);
    const space = await this.loadSpace(item.groupId);
    const totalMembers = space.members.length;

    const loveIt = item.reactions.filter((r) => r.type === ReactionType.LoveIt).length;
    const worksForMe = item.reactions.filter((r) => r.type === ReactionType.WorksForMe).length;
    const notForMe = item.reactions.filter((r) => r.type === ReactionType.NotForMe).length;
    const isUnanimousLoveIt = totalMembers > 0 && loveIt === totalMembers;

    return { loveIt, worksForMe, notForMe, isUnanimousLoveIt };
  }

  // --- AI Grounding ---

  async getGroundingContext(
    identity: Identity,
    groupId: GroupId
  ): Promise<GroundingContext> {
    await this.authorize(identity, "space:read", groupId);
    const space = await this.loadSpace(groupId);
    const machine = new StateMachine(space.flow ?? this.defaultFlow);
    const items = await this.persistence.getItemsBySpace(groupId);
    const tasks = await this.persistence.getTasksBySpace(groupId);
    return buildGroundingContext(groupId as GroupId, items, tasks, machine);
  }

  async getGroundingPrompt(
    identity: Identity,
    groupId: GroupId
  ): Promise<string> {
    const context = await this.getGroundingContext(identity, groupId);
    return generateGroundingPrompt(context);
  }

  async checkConflicts(
    identity: Identity,
    groupId: GroupId,
    category: string
  ): Promise<ReturnType<typeof checkSuggestionConflicts>> {
    const context = await this.getGroundingContext(identity, groupId);
    return checkSuggestionConflicts(context, category);
  }

  // --- Private helpers ---

  private async loadItem(itemId: ItemId): Promise<BookableItem> {
    const item = await this.persistence.getItem(itemId);
    if (!item) throw new NotFoundError("Item", itemId);
    return item;
  }

  private async loadSpace(groupId: GroupId): Promise<DecisionSpace> {
    const space = await this.persistence.getSpace(groupId);
    if (!space) throw new NotFoundError("Space", groupId);
    return space;
  }

  private async loadTask(taskId: TaskId): Promise<Task> {
    const task = await this.persistence.getTask(taskId);
    if (!task) throw new NotFoundError("Task", taskId);
    return task;
  }

  private async authorize(
    identity: Identity,
    action: Action,
    groupId: GroupId
  ): Promise<void> {
    const allowed = await this.auth.authorize(identity, action, groupId);
    if (!allowed) throw new AuthError(action, groupId);
  }

  private async invalidateSpaceCache(groupId: GroupId): Promise<void> {
    if (this.cache) {
      await this.cache.deleteByPrefix(`ranked:${groupId}`);
    }
  }
}
