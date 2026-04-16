import { describe, it, expect } from "vitest";
import { buildGroundingContext, generateGroundingPrompt, checkSuggestionConflicts, } from "../engine/ai-grounding.js";
import { BookableItemState, TaskState } from "../models/types.js";
function makeItem(overrides = {}) {
    return {
        id: "item_1",
        groupId: "group_1",
        ciphertextPayload: "Hilton San Diego",
        nonce: "nonce",
        state: BookableItemState.Proposed,
        proposedBy: "user_1",
        proposedAt: 1000,
        reactions: [],
        weightedScore: 0,
        commitmentCiphertext: null,
        commitmentNonce: null,
        ownership: null,
        lockedAt: null,
        version: 1,
        ...overrides,
    };
}
function makeTask(overrides = {}) {
    return {
        id: "task_1",
        groupId: "group_1",
        title: "Bring sunscreen",
        description: "SPF 50",
        state: TaskState.Created,
        createdBy: "user_1",
        createdAt: 1000,
        assignee: null,
        assignedAt: null,
        ...overrides,
    };
}
describe("buildGroundingContext", () => {
    it("separates locked items as constraints and active items as context", () => {
        const items = [
            makeItem({
                id: "locked_hotel",
                ciphertextPayload: "Hilton SD",
                state: BookableItemState.Locked,
                ownership: { ownerId: "u2", assignedAt: 2000, reason: "booker" },
            }),
            makeItem({
                id: "active_restaurant",
                ciphertextPayload: "Nobu",
                state: BookableItemState.Ranked,
                weightedScore: 8,
            }),
        ];
        const ctx = buildGroundingContext("g1", items, []);
        expect(ctx.lockedDecisions).toHaveLength(1);
        expect(ctx.lockedDecisions[0].type).toBe("locked_decision");
        expect(ctx.lockedDecisions[0].ciphertextPayload).toBe("Hilton SD");
        expect(ctx.activeItems).toHaveLength(1);
        expect(ctx.activeItems[0].ciphertextPayload).toBe("Nobu");
        expect(ctx.activeItems[0].weightedScore).toBe(8);
    });
    it("includes assigned tasks as constraints", () => {
        const tasks = [
            makeTask({
                state: TaskState.Assigned,
                assignee: "u3",
                title: "Bring sunscreen",
            }),
            makeTask({
                id: "task_2",
                title: "Pick meeting time",
                state: TaskState.Created,
            }),
        ];
        const ctx = buildGroundingContext("g1", [], tasks);
        expect(ctx.lockedDecisions[0].ciphertextPayload).toBe("Bring sunscreen");
    });
    it("returns empty arrays when no items or tasks", () => {
        const ctx = buildGroundingContext("g1", [], []);
        expect(ctx.lockedDecisions).toHaveLength(0);
        expect(ctx.activeItems).toHaveLength(0);
    });
});
describe("generateGroundingPrompt", () => {
    it("returns permissive message when no locked decisions", () => {
        const ctx = buildGroundingContext("g1", [], []);
        const prompt = generateGroundingPrompt(ctx);
        expect(prompt).toContain("No locked decisions");
        expect(prompt).toContain("suggest any options freely");
    });
    it("generates constraint instructions for locked bookings", () => {
        const items = [
            makeItem({
                state: BookableItemState.Locked,
                ciphertextPayload: "Hilton San Diego",
                ownership: { ownerId: "u2", assignedAt: 2000, reason: "booker" },
            }),
        ];
        const ctx = buildGroundingContext("g1", items, []);
        const prompt = generateGroundingPrompt(ctx);
        expect(prompt).toContain("GROUNDING CONSTRAINTS");
        expect(prompt).toContain("LOCKED DECISION");
        expect(prompt).toContain(items[0].id);
        expect(prompt).toContain("Do NOT suggest alternatives");
    });
    it("includes both bookings and tasks in prompt", () => {
        const items = [
            makeItem({
                state: BookableItemState.Locked,
                ciphertextPayload: "Flight to SD",
                ownership: { ownerId: "u1", assignedAt: 2000, reason: "booker" },
            }),
        ];
        const tasks = [
            makeTask({
                state: TaskState.Assigned,
                assignee: "u3",
                title: "Bring snacks",
            }),
        ];
        const ctx = buildGroundingContext("g1", items, tasks);
        const prompt = generateGroundingPrompt(ctx);
        expect(prompt).toContain(items[0].id);
        expect(prompt).toContain(tasks[0].id);
        expect(prompt).toContain("ASSIGNED TASK");
    });
});
//# sourceMappingURL=ai-grounding.test.js.map