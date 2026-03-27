/**
 * Task Assignment System
 *
 * Handles non-bookable items (time, who brings snacks, etc.)
 * Lightweight ownership without the ceremony of lock + proof.
 *
 * State lifecycle: Created → Assigned → Owned
 */

import type { Task, TaskId, GroupId, UserId } from "../models/types.js";
import { TaskState } from "../models/types.js";
import { randomUUID } from "node:crypto";

export class TaskAssignmentError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TaskAssignmentError";
  }
}

/**
 * Creates a new task for a group.
 * Uses crypto.randomUUID() for globally unique IDs.
 */
export function createTask(
  groupId: GroupId,
  title: string,
  description: string,
  createdBy: UserId,
  timestamp: number
): Task {
  return {
    id: `task_${randomUUID()}` as TaskId,
    groupId,
    title,
    description,
    state: TaskState.Created,
    createdBy,
    createdAt: timestamp,
    assignee: null,
    assignedAt: null,
  };
}

/**
 * Assigns a task to a user. Any member can claim a task.
 */
export function assignTask(
  task: Task,
  assigneeId: UserId,
  timestamp: number
): Task {
  return {
    ...task,
    state: TaskState.Assigned,
    assignee: assigneeId,
    assignedAt: timestamp,
  };
}

/**
 * Reassigns a task to a different user.
 */
export function reassignTask(
  task: Task,
  newAssigneeId: UserId,
  timestamp: number
): Task {
  if (task.assignee === newAssigneeId) {
    throw new TaskAssignmentError(
      `User is already assigned to "${task.title}".`
    );
  }

  return {
    ...task,
    assignee: newAssigneeId,
    assignedAt: timestamp,
  };
}

/**
 * Unassigns a task, returning it to "created" state.
 */
export function unassignTask(task: Task): Task {
  if (task.state !== TaskState.Assigned) {
    throw new TaskAssignmentError(
      `Task "${task.title}" is not assigned.`
    );
  }

  return {
    ...task,
    state: TaskState.Created,
    assignee: null,
    assignedAt: null,
  };
}

/**
 * No-op for backwards compatibility. Task IDs are now UUIDs.
 * @deprecated No longer needed — task IDs use crypto.randomUUID()
 */
export function resetTaskCounter(): void {
  // No-op: task IDs are now UUIDs, no counter to reset
}
