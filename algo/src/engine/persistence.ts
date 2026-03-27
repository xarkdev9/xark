/**
 * Persistence Adapter Interface
 *
 * Defines the contract for persisting decision engine state.
 * The InMemoryAdapter wraps the current Map-based storage.
 * Future adapters: PostgresAdapter, RedisAdapter, etc.
 */

import type {
  BookableItem,
  DecisionSpace,
  GroupId,
  ItemId,
  SpaceId,
  Task,
  TaskId,
} from "../models/types.js";

export interface PersistenceAdapter {
  // Items
  saveItem(item: BookableItem): Promise<void>;
  getItem(itemId: ItemId): Promise<BookableItem | undefined>;
  getItemsBySpace(spaceId: SpaceId): Promise<BookableItem[]>;
  deleteItem(itemId: ItemId): Promise<void>;

  // Tasks
  saveTask(task: Task): Promise<void>;
  getTask(taskId: TaskId): Promise<Task | undefined>;
  getTasksBySpace(spaceId: SpaceId): Promise<Task[]>;
  deleteTask(taskId: TaskId): Promise<void>;

  // Spaces
  saveSpace(space: DecisionSpace): Promise<void>;
  getSpace(spaceId: SpaceId): Promise<DecisionSpace | undefined>;
  deleteSpace(spaceId: SpaceId): Promise<void>;
}

/**
 * In-memory persistence adapter.
 * Wraps Maps — equivalent to current engine behavior.
 */
export class InMemoryAdapter implements PersistenceAdapter {
  private items = new Map<ItemId, BookableItem>();
  private tasks = new Map<TaskId, Task>();
  private spaces = new Map<SpaceId, DecisionSpace>();
  private spaceItems = new Map<SpaceId, Set<ItemId>>();
  private spaceTasks = new Map<SpaceId, Set<TaskId>>();

  async saveItem(item: BookableItem): Promise<void> {
    this.items.set(item.id, item);
    const spaceId = item.groupId as SpaceId;
    if (!this.spaceItems.has(spaceId)) {
      this.spaceItems.set(spaceId, new Set());
    }
    this.spaceItems.get(spaceId)!.add(item.id);
  }

  async getItem(itemId: ItemId): Promise<BookableItem | undefined> {
    return this.items.get(itemId);
  }

  async getItemsBySpace(spaceId: SpaceId): Promise<BookableItem[]> {
    const ids = this.spaceItems.get(spaceId);
    if (!ids) return [];
    const items: BookableItem[] = [];
    for (const id of ids) {
      const item = this.items.get(id);
      if (item) items.push(item);
    }
    return items;
  }

  async deleteItem(itemId: ItemId): Promise<void> {
    const item = this.items.get(itemId);
    if (item) {
      const spaceId = item.groupId as SpaceId;
      this.spaceItems.get(spaceId)?.delete(itemId);
    }
    this.items.delete(itemId);
  }

  async saveTask(task: Task): Promise<void> {
    this.tasks.set(task.id, task);
    const spaceId = task.groupId as SpaceId;
    if (!this.spaceTasks.has(spaceId)) {
      this.spaceTasks.set(spaceId, new Set());
    }
    this.spaceTasks.get(spaceId)!.add(task.id);
  }

  async getTask(taskId: TaskId): Promise<Task | undefined> {
    return this.tasks.get(taskId);
  }

  async getTasksBySpace(spaceId: SpaceId): Promise<Task[]> {
    const ids = this.spaceTasks.get(spaceId);
    if (!ids) return [];
    const tasks: Task[] = [];
    for (const id of ids) {
      const task = this.tasks.get(id);
      if (task) tasks.push(task);
    }
    return tasks;
  }

  async deleteTask(taskId: TaskId): Promise<void> {
    const task = this.tasks.get(taskId);
    if (task) {
      const spaceId = task.groupId as SpaceId;
      this.spaceTasks.get(spaceId)?.delete(taskId);
    }
    this.tasks.delete(taskId);
  }

  async saveSpace(space: DecisionSpace): Promise<void> {
    this.spaces.set(space.id, space);
  }

  async getSpace(spaceId: SpaceId): Promise<DecisionSpace | undefined> {
    return this.spaces.get(spaceId);
  }

  async deleteSpace(spaceId: SpaceId): Promise<void> {
    this.spaces.delete(spaceId);
    // Also clean up related items and tasks
    const itemIds = this.spaceItems.get(spaceId);
    if (itemIds) {
      for (const id of itemIds) {
        this.items.delete(id);
      }
      this.spaceItems.delete(spaceId);
    }
    const taskIds = this.spaceTasks.get(spaceId);
    if (taskIds) {
      for (const id of taskIds) {
        this.tasks.delete(id);
      }
      this.spaceTasks.delete(spaceId);
    }
  }
}
