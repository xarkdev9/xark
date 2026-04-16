/**
 * Task Assignment System
 *
 * Handles non-bookable items (time, who brings snacks, etc.)
 * Lightweight ownership without the ceremony of lock + proof.
 *
 * State lifecycle: Created → Assigned → Owned
 */
import { TaskState } from "../models/types.js";
import { randomUUID } from "node:crypto";
export class TaskAssignmentError extends Error {
    constructor(message) {
        super(message);
        this.name = "TaskAssignmentError";
    }
}
/**
 * Creates a new task for a group.
 * Uses crypto.randomUUID() for globally unique IDs.
 */
export function createTask(groupId, title, description, createdBy, timestamp) {
    return {
        id: `task_${randomUUID()}`,
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
export function assignTask(task, assigneeId, timestamp) {
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
export function reassignTask(task, newAssigneeId, timestamp) {
    if (task.assignee === newAssigneeId) {
        throw new TaskAssignmentError(`User is already assigned to "${task.title}".`);
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
export function unassignTask(task) {
    if (task.state !== TaskState.Assigned) {
        throw new TaskAssignmentError(`Task "${task.title}" is not assigned.`);
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
export function resetTaskCounter() {
    // No-op: task IDs are now UUIDs, no counter to reset
}
//# sourceMappingURL=task-assignment.js.map