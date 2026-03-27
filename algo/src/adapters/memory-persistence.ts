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
  SpaceId,
  Task,
  TaskId,
} from "../models/types.js";

export class MemoryPersistenceAdapter implements PersistencePort {
  private items = new Map<ItemId, BookableItem>();
  private tasks = new Map<TaskId, Task>();
  private spaces = new Map<SpaceId, DecisionSpace>();
  private spaceItems = new Map<SpaceId, Set<ItemId>>();
  private spaceTasks = new Map<SpaceId, Set<TaskId>>();

  async saveItem(item: BookableItem): Promise<void> {
    const existing = this.items.get(item.id);
    if (existing && existing.version >= item.version) {
      throw new VersionConflictError(item.id, item.version, existing.version);
    }
    this.items.set(item.id, structuredClone(item));
    const spaceId = item.spaceId;
    if (!this.spaceItems.has(spaceId)) {
      this.spaceItems.set(spaceId, new Set());
    }
    this.spaceItems.get(spaceId)!.add(item.id);
  }

  async getItem(itemId: ItemId): Promise<BookableItem | undefined> {
    const item = this.items.get(itemId);
    return item ? structuredClone(item) : undefined;
  }

  async getItemsBySpace(spaceId: SpaceId): Promise<BookableItem[]> {
    const ids = this.spaceItems.get(spaceId);
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
      this.spaceItems.get(item.spaceId)?.delete(itemId);
    }
    this.items.delete(itemId);
  }

  async saveTask(task: Task): Promise<void> {
    this.tasks.set(task.id, structuredClone(task));
    const spaceId = task.groupId as SpaceId;
    if (!this.spaceTasks.has(spaceId)) {
      this.spaceTasks.set(spaceId, new Set());
    }
    this.spaceTasks.get(spaceId)!.add(task.id);
  }

  async getTask(taskId: TaskId): Promise<Task | undefined> {
    const task = this.tasks.get(taskId);
    return task ? structuredClone(task) : undefined;
  }

  async getTasksBySpace(spaceId: SpaceId): Promise<Task[]> {
    const ids = this.spaceTasks.get(spaceId);
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
      const spaceId = task.groupId as SpaceId;
      this.spaceTasks.get(spaceId)?.delete(taskId);
    }
    this.tasks.delete(taskId);
  }

  async saveSpace(space: DecisionSpace): Promise<void> {
    this.spaces.set(space.id, structuredClone(space));
  }

  async getSpace(spaceId: SpaceId): Promise<DecisionSpace | undefined> {
    const space = this.spaces.get(spaceId);
    return space ? structuredClone(space) : undefined;
  }

  async getAllSpaces(): Promise<DecisionSpace[]> {
    return [...this.spaces.values()].map((s) => structuredClone(s));
  }

  async deleteSpace(spaceId: SpaceId): Promise<void> {
    const itemIds = this.spaceItems.get(spaceId);
    if (itemIds) {
      for (const id of itemIds) this.items.delete(id);
      this.spaceItems.delete(spaceId);
    }
    const taskIds = this.spaceTasks.get(spaceId);
    if (taskIds) {
      for (const id of taskIds) this.tasks.delete(id);
      this.spaceTasks.delete(spaceId);
    }
    this.spaces.delete(spaceId);
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
