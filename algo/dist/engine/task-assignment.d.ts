/**
 * Task Assignment System
 *
 * Handles non-bookable items (time, who brings snacks, etc.)
 * Lightweight ownership without the ceremony of lock + proof.
 *
 * State lifecycle: Created → Assigned → Owned
 */
import type { Task, GroupId, UserId } from "../models/types.js";
export declare class TaskAssignmentError extends Error {
    constructor(message: string);
}
/**
 * Creates a new task for a group.
 */
export declare function createTask(groupId: GroupId, title: string, description: string, createdBy: UserId, timestamp: number): Task;
/**
 * Assigns a task to a user. Any member can claim a task.
 */
export declare function assignTask(task: Task, assigneeId: UserId, timestamp: number): Task;
/**
 * Reassigns a task to a different user.
 */
export declare function reassignTask(task: Task, newAssigneeId: UserId, timestamp: number): Task;
/**
 * Unassigns a task, returning it to "created" state.
 */
export declare function unassignTask(task: Task): Task;
/**
 * Resets the task counter (for testing).
 */
export declare function resetTaskCounter(): void;
//# sourceMappingURL=task-assignment.d.ts.map