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
  GroupId,
  Task,
  TaskId,
} from "../models/types.js";

export interface PersistenceAdapter {
  // Items
  saveItem(item: BookableItem): Promise<void>;
  getItem(itemId: ItemId): Promise<BookableItem | undefined>;
  getItemsBySpace(groupId: GroupId): Promise<BookableItem[]>;
  deleteItem(itemId: ItemId): Promise<void>;

  // Tasks
  saveTask(task: Task): Promise<void>;
  getTask(taskId: TaskId): Promise<Task | undefined>;
  getTasksBySpace(groupId: GroupId): Promise<Task[]>;
  deleteTask(taskId: TaskId): Promise<void>;

  // Spaces
  saveSpace(space: DecisionSpace): Promise<void>;
  getSpace(groupId: GroupId): Promise<DecisionSpace | undefined>;
  deleteSpace(groupId: GroupId): Promise<void>;
}

/**
 * In-memory persistence adapter.
 * Wraps Maps — equivalent to current engine behavior.
 */
export class InMemoryAdapter implements PersistenceAdapter {
  private items = new Map<ItemId, BookableItem>();
  private tasks = new Map<TaskId, Task>();
  private spaces = new Map<GroupId, DecisionSpace>();
  private spaceItems = new Map<GroupId, Set<ItemId>>();
  private spaceTasks = new Map<GroupId, Set<TaskId>>();

  async saveItem(item: BookableItem): Promise<void> {
    this.items.set(item.id, item);
    const groupId = item.groupId as GroupId;
    if (!this.spaceItems.has(groupId)) {
      this.spaceItems.set(groupId, new Set());
    }
    this.spaceItems.get(groupId)!.add(item.id);
  }

  async getItem(itemId: ItemId): Promise<BookableItem | undefined> {
    return this.items.get(itemId);
  }

  async getItemsBySpace(groupId: GroupId): Promise<BookableItem[]> {
    const ids = this.spaceItems.get(groupId);
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
      const groupId = item.groupId as GroupId;
      this.spaceItems.get(groupId)?.delete(itemId);
    }
    this.items.delete(itemId);
  }

  async saveTask(task: Task): Promise<void> {
    this.tasks.set(task.id, task);
    const groupId = task.groupId as GroupId;
    if (!this.spaceTasks.has(groupId)) {
      this.spaceTasks.set(groupId, new Set());
    }
    this.spaceTasks.get(groupId)!.add(task.id);
  }

  async getTask(taskId: TaskId): Promise<Task | undefined> {
    return this.tasks.get(taskId);
  }

  async getTasksBySpace(groupId: GroupId): Promise<Task[]> {
    const ids = this.spaceTasks.get(groupId);
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
      const groupId = task.groupId as GroupId;
      this.spaceTasks.get(groupId)?.delete(taskId);
    }
    this.tasks.delete(taskId);
  }

  async saveSpace(space: DecisionSpace): Promise<void> {
    this.spaces.set(space.id, space);
  }

  async getSpace(groupId: GroupId): Promise<DecisionSpace | undefined> {
    return this.spaces.get(groupId);
  }

  async deleteSpace(groupId: GroupId): Promise<void> {
    this.spaces.delete(groupId);
    // Also clean up related items and tasks
    const itemIds = this.spaceItems.get(groupId);
    if (itemIds) {
      for (const id of itemIds) {
        this.items.delete(id);
      }
      this.spaceItems.delete(groupId);
    }
    const taskIds = this.spaceTasks.get(groupId);
    if (taskIds) {
      for (const id of taskIds) {
        this.tasks.delete(id);
      }
      this.spaceTasks.delete(groupId);
    }
  }
}
