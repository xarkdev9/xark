/**
 * Task Assignment System
 *
 * Handles non-bookable items (time, who brings snacks, etc.)
 * Lightweight ownership without the ceremony of lock + proof.
 *
 * State lifecycle: Created → Assigned → Owned
 */
import { TaskState } from "../models/types.js";
export class TaskAssignmentError extends Error {
    constructor(message) {
        super(message);
        this.name = "TaskAssignmentError";
    }
}
let taskCounter = 0;
/**
 * Creates a new task for a group.
 */
export function createTask(groupId, title, description, createdBy, timestamp) {
    taskCounter++;
    return {
        id: `task_${taskCounter}`,
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
 * Resets the task counter (for testing).
 */
export function resetTaskCounter() {
    taskCounter = 0;
}
//# sourceMappingURL=task-assignment.js.map