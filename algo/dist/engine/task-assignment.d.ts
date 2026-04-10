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
 * Uses crypto.randomUUID() for globally unique IDs.
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
 * No-op for backwards compatibility. Task IDs are now UUIDs.
 * @deprecated No longer needed — task IDs use crypto.randomUUID()
 */
export declare function resetTaskCounter(): void;
//# sourceMappingURL=task-assignment.d.ts.map