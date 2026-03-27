import { describe, it, expect, beforeEach } from "vitest";
import {
  createTask,
  assignTask,
  reassignTask,
  unassignTask,
  resetTaskCounter,
  TaskAssignmentError,
} from "../engine/task-assignment.js";
import { TaskState } from "../models/types.js";

beforeEach(() => {
  resetTaskCounter();
});

describe("createTask", () => {
  it("creates a task in 'created' state", () => {
    const task = createTask("g1", "Bring snacks", "Trail mix and chips", "u1", 1000);

    expect(task.id).toMatch(/^task_/);
    expect(task.groupId).toBe("g1");
    expect(task.title).toBe("Bring snacks");
    expect(task.state).toBe(TaskState.Created);
    expect(task.createdBy).toBe("u1");
    expect(task.assignee).toBeNull();
    expect(task.assignedAt).toBeNull();
  });

  it("generates unique task IDs", () => {
    const t1 = createTask("g1", "Task 1", "", "u1", 1000);
    const t2 = createTask("g1", "Task 2", "", "u1", 2000);
    expect(t1.id).toMatch(/^task_/);
    expect(t2.id).toMatch(/^task_/);
    expect(t1.id).not.toBe(t2.id);
  });
});

describe("assignTask", () => {
  it("assigns a task to a user", () => {
    const task = createTask("g1", "Bring snacks", "", "u1", 1000);
    const assigned = assignTask(task, "u2", 2000);

    expect(assigned.state).toBe(TaskState.Assigned);
    expect(assigned.assignee).toBe("u2");
    expect(assigned.assignedAt).toBe(2000);
  });

  it("does not mutate original task", () => {
    const task = createTask("g1", "Bring snacks", "", "u1", 1000);
    assignTask(task, "u2", 2000);

    expect(task.assignee).toBeNull();
    expect(task.state).toBe(TaskState.Created);
  });
});

describe("reassignTask", () => {
  it("reassigns to a different user", () => {
    const task = createTask("g1", "Bring snacks", "", "u1", 1000);
    const assigned = assignTask(task, "u2", 2000);
    const reassigned = reassignTask(assigned, "u3", 3000);

    expect(reassigned.assignee).toBe("u3");
    expect(reassigned.assignedAt).toBe(3000);
  });

  it("throws if reassigning to same user", () => {
    const task = createTask("g1", "Bring snacks", "", "u1", 1000);
    const assigned = assignTask(task, "u2", 2000);

    expect(() => reassignTask(assigned, "u2", 3000)).toThrow(
      TaskAssignmentError
    );
  });
});

describe("unassignTask", () => {
  it("returns task to created state", () => {
    const task = createTask("g1", "Bring snacks", "", "u1", 1000);
    const assigned = assignTask(task, "u2", 2000);
    const unassigned = unassignTask(assigned);

    expect(unassigned.state).toBe(TaskState.Created);
    expect(unassigned.assignee).toBeNull();
    expect(unassigned.assignedAt).toBeNull();
  });

  it("throws if task is not assigned", () => {
    const task = createTask("g1", "Bring snacks", "", "u1", 1000);

    expect(() => unassignTask(task)).toThrow(TaskAssignmentError);
    expect(() => unassignTask(task)).toThrow("not assigned");
  });
});
