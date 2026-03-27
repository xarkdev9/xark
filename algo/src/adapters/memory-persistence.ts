/**
 * In-Memory Persistence Adapter
 *
 * Zero-dependency, zero-config. Good for:
 * - Development and testing
 * - Single-process deployments
 * - Embedded use (CLI tools, scripts)
 *
 * NOT for production multi-user deployments — data is lost on restart.
 * Supports optimistic concurrency via version checks.
 */

import type { PersistencePort } from "../ports/persistence.js";
import { VersionConflictError } from "../ports/persistence.js";
import type {
  BookableItem,
  DecisionSpace,
  ItemId,
  GroupId,
  Task,
  TaskId,
} from "../models/types.js";

export class MemoryPersistenceAdapter implements PersistencePort {
  private items = new Map<ItemId, BookableItem>();
  private tasks = new Map<TaskId, Task>();
  private spaces = new Map<GroupId, DecisionSpace>();
  private spaceItems = new Map<GroupId, Set<ItemId>>();
  private spaceTasks = new Map<GroupId, Set<TaskId>>();

  async saveItem(item: BookableItem): Promise<void> {
    const existing = this.items.get(item.id);
    if (existing && existing.version >= item.version) {
      throw new VersionConflictError(item.id, item.version, existing.version);
    }
    this.items.set(item.id, structuredClone(item));
    const groupId = item.groupId;
    if (!this.spaceItems.has(groupId)) {
      this.spaceItems.set(groupId, new Set());
    }
    this.spaceItems.get(groupId)!.add(item.id);
  }

  async getItem(itemId: ItemId): Promise<BookableItem | undefined> {
    const item = this.items.get(itemId);
    return item ? structuredClone(item) : undefined;
  }

  async getItemsBySpace(groupId: GroupId): Promise<BookableItem[]> {
    const ids = this.spaceItems.get(groupId);
    if (!ids) return [];
    const items: BookableItem[] = [];
    for (const id of ids) {
      const item = this.items.get(id);
      if (item) items.push(structuredClone(item));
    }
    return items;
  }

  async deleteItem(itemId: ItemId): Promise<void> {
    const item = this.items.get(itemId);
    if (item) {
      this.spaceItems.get(item.groupId)?.delete(itemId);
    }
    this.items.delete(itemId);
  }

  async saveTask(task: Task): Promise<void> {
    this.tasks.set(task.id, structuredClone(task));
    const groupId = task.groupId as GroupId;
    if (!this.spaceTasks.has(groupId)) {
      this.spaceTasks.set(groupId, new Set());
    }
    this.spaceTasks.get(groupId)!.add(task.id);
  }

  async getTask(taskId: TaskId): Promise<Task | undefined> {
    const task = this.tasks.get(taskId);
    return task ? structuredClone(task) : undefined;
  }

  async getTasksBySpace(groupId: GroupId): Promise<Task[]> {
    const ids = this.spaceTasks.get(groupId);
    if (!ids) return [];
    const tasks: Task[] = [];
    for (const id of ids) {
      const task = this.tasks.get(id);
      if (task) tasks.push(structuredClone(task));
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
    this.spaces.set(space.id, structuredClone(space));
  }

  async getSpace(groupId: GroupId): Promise<DecisionSpace | undefined> {
    const space = this.spaces.get(groupId);
    return space ? structuredClone(space) : undefined;
  }

  async getAllSpaces(): Promise<DecisionSpace[]> {
    return [...this.spaces.values()].map((s) => structuredClone(s));
  }

  async deleteSpace(groupId: GroupId): Promise<void> {
    const itemIds = this.spaceItems.get(groupId);
    if (itemIds) {
      for (const id of itemIds) this.items.delete(id);
      this.spaceItems.delete(groupId);
    }
    const taskIds = this.spaceTasks.get(groupId);
    if (taskIds) {
      for (const id of taskIds) this.tasks.delete(id);
      this.spaceTasks.delete(groupId);
    }
    this.spaces.delete(groupId);
  }

  /** Clears all data. Useful for test teardown. */
  clear(): void {
    this.items.clear();
    this.tasks.clear();
    this.spaces.clear();
    this.spaceItems.clear();
    this.spaceTasks.clear();
  }
}
