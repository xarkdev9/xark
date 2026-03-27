/**
 * Persistence Port
 *
 * Contract for storing decision engine state.
 * Implement this for any database: Postgres, MySQL, MongoDB, DynamoDB,
 * Supabase, Firebase, SQLite, flat files, etc.
 *
 * All methods are async to support network-bound storage.
 * Optimistic concurrency via version field — adapters SHOULD check
 * version on save and throw VersionConflictError if stale.
 */

import type {
  BookableItem,
  DecisionSpace,
  ItemId,
  SpaceId,
  Task,
  TaskId,
} from "../models/types.js";

export interface PersistencePort {
  // --- Items ---
  saveItem(item: BookableItem): Promise<void>;
  getItem(itemId: ItemId): Promise<BookableItem | undefined>;
  getItemsBySpace(spaceId: SpaceId): Promise<BookableItem[]>;
  deleteItem(itemId: ItemId): Promise<void>;

  // --- Tasks ---
  saveTask(task: Task): Promise<void>;
  getTask(taskId: TaskId): Promise<Task | undefined>;
  getTasksBySpace(spaceId: SpaceId): Promise<Task[]>;
  deleteTask(taskId: TaskId): Promise<void>;

  // --- Spaces ---
  saveSpace(space: DecisionSpace): Promise<void>;
  getSpace(spaceId: SpaceId): Promise<DecisionSpace | undefined>;
  getAllSpaces(): Promise<DecisionSpace[]>;
  deleteSpace(spaceId: SpaceId): Promise<void>;
}

/**
 * Thrown when a save fails due to version mismatch.
 * Callers should reload and retry.
 */
export class VersionConflictError extends Error {
  constructor(
    public readonly itemId: string,
    public readonly expectedVersion: number,
    public readonly actualVersion: number
  ) {
    super(
      `Version conflict on "${itemId}": expected ${expectedVersion}, got ${actualVersion}. Reload and retry.`
    );
    this.name = "VersionConflictError";
  }
}
