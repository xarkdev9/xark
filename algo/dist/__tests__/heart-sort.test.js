import { describe, it, expect } from "vitest";
import { calculateWeightedScore, addReaction, removeReaction, heartSort, getTopItems, calculateAgreementScore, getRankedSummary, } from "../engine/heart-sort.js";
import { ReactionType, BookableItemState } from "../models/types.js";
function makeItem(overrides = {}) {
    return {
        id: "item_1",
        groupId: "group_1",
        title: "Test Hotel",
        description: "A nice hotel",
        category: "hotel",
        state: BookableItemState.Proposed,
        proposedBy: "user_1",
        proposedAt: 1000,
        reactions: [],
        weightedScore: 0,
        bookingProof: null,
        ownership: null,
        ownershipHistory: [],
        lockedAt: null,
        ...overrides,
    };
}
describe("calculateWeightedScore", () => {
    it("returns 0 for no reactions", () => {
        expect(calculateWeightedScore([])).toBe(0);
    });
    it("scores thumbs_up as 1", () => {
        const reactions = [
            { userId: "u1", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 1 },
        ];
        expect(calculateWeightedScore(reactions)).toBe(1);
    });
    it("scores heart as 5", () => {
        const reactions = [
            { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 1 },
        ];
        expect(calculateWeightedScore(reactions)).toBe(5);
    });
    it("sums multiple reactions from different users", () => {
        const reactions = [
            { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 1 },
            { userId: "u2", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 2 },
            { userId: "u3", itemId: "i1", type: ReactionType.Heart, timestamp: 3 },
        ];
        expect(calculateWeightedScore(reactions)).toBe(11); // 5 + 1 + 5
    });
    it("deduplicates: last reaction from same user wins", () => {
        const reactions = [
            { userId: "u1", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 1 },
            { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 2 },
        ];
        expect(calculateWeightedScore(reactions)).toBe(5); // Last reaction is heart
    });
    it("a passionate ❤️ from 3 beats a lukewarm 👍 from 4", () => {
        const hearts = [
            { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 1 },
            { userId: "u2", itemId: "i1", type: ReactionType.Heart, timestamp: 2 },
            { userId: "u3", itemId: "i1", type: ReactionType.Heart, timestamp: 3 },
        ];
        const thumbs = [
            { userId: "u4", itemId: "i2", type: ReactionType.ThumbsUp, timestamp: 1 },
            { userId: "u5", itemId: "i2", type: ReactionType.ThumbsUp, timestamp: 2 },
            { userId: "u6", itemId: "i2", type: ReactionType.ThumbsUp, timestamp: 3 },
            { userId: "u7", itemId: "i2", type: ReactionType.ThumbsUp, timestamp: 4 },
        ];
        expect(calculateWeightedScore(hearts)).toBe(15); // 3 × 5
        expect(calculateWeightedScore(thumbs)).toBe(4); // 4 × 1
        expect(calculateWeightedScore(hearts)).toBeGreaterThan(calculateWeightedScore(thumbs));
    });
});
describe("addReaction", () => {
    it("adds a reaction and updates score", () => {
        const item = makeItem();
        const updated = addReaction(item, "u1", ReactionType.Heart, 100);
        expect(updated.reactions).toHaveLength(1);
        expect(updated.weightedScore).toBe(5);
    });
    it("replaces existing reaction from same user", () => {
        const item = makeItem({
            reactions: [
                { userId: "u1", itemId: "item_1", type: ReactionType.Heart, timestamp: 1 },
            ],
            weightedScore: 5,
        });
        const updated = addReaction(item, "u1", ReactionType.ThumbsUp, 200);
        expect(updated.reactions).toHaveLength(1);
        expect(updated.weightedScore).toBe(1);
        expect(updated.reactions[0].type).toBe(ReactionType.ThumbsUp);
    });
    it("does not mutate the original item", () => {
        const item = makeItem();
        const updated = addReaction(item, "u1", ReactionType.Heart, 100);
        expect(item.reactions).toHaveLength(0);
        expect(updated.reactions).toHaveLength(1);
    });
});
describe("removeReaction", () => {
    it("removes a reaction and recalculates score", () => {
        const item = makeItem({
            reactions: [
                { userId: "u1", itemId: "item_1", type: ReactionType.Heart, timestamp: 1 },
                { userId: "u2", itemId: "item_1", type: ReactionType.ThumbsUp, timestamp: 2 },
            ],
            weightedScore: 6,
        });
        const updated = removeReaction(item, "u1");
        expect(updated.reactions).toHaveLength(1);
        expect(updated.weightedScore).toBe(1);
    });
    it("returns score 0 when all reactions removed", () => {
        const item = makeItem({
            reactions: [
                { userId: "u1", itemId: "item_1", type: ReactionType.Heart, timestamp: 1 },
            ],
            weightedScore: 5,
        });
        const updated = removeReaction(item, "u1");
        expect(updated.reactions).toHaveLength(0);
        expect(updated.weightedScore).toBe(0);
    });
});
describe("heartSort", () => {
    it("sorts items by weighted score descending", () => {
        const items = [
            makeItem({ id: "a", weightedScore: 3, proposedAt: 1 }),
            makeItem({ id: "b", weightedScore: 10, proposedAt: 2 }),
            makeItem({ id: "c", weightedScore: 7, proposedAt: 3 }),
        ];
        const sorted = heartSort(items);
        expect(sorted.map((i) => i.id)).toEqual(["b", "c", "a"]);
    });
    it("breaks ties by earliest proposal time", () => {
        const items = [
            makeItem({ id: "a", weightedScore: 5, proposedAt: 300 }),
            makeItem({ id: "b", weightedScore: 5, proposedAt: 100 }),
            makeItem({ id: "c", weightedScore: 5, proposedAt: 200 }),
        ];
        const sorted = heartSort(items);
        expect(sorted.map((i) => i.id)).toEqual(["b", "c", "a"]);
    });
    it("does not mutate original array", () => {
        const items = [
            makeItem({ id: "a", weightedScore: 1 }),
            makeItem({ id: "b", weightedScore: 10 }),
        ];
        const original = [...items];
        heartSort(items);
        expect(items.map((i) => i.id)).toEqual(original.map((i) => i.id));
    });
});
describe("getTopItems", () => {
    it("returns top N items", () => {
        const items = [
            makeItem({ id: "a", weightedScore: 1 }),
            makeItem({ id: "b", weightedScore: 10 }),
            makeItem({ id: "c", weightedScore: 5 }),
        ];
        const top = getTopItems(items, 2);
        expect(top).toHaveLength(2);
        expect(top.map((i) => i.id)).toEqual(["b", "c"]);
    });
});
describe("calculateAgreementScore", () => {
    it("returns 0% with no reactions", () => {
        const item = makeItem();
        const result = calculateAgreementScore(item, 5);
        expect(result.percentage).toBe(0);
        expect(result.isGroupFavorite).toBe(false);
    });
    it("returns 100% when all members reacted", () => {
        const item = makeItem({
            reactions: [
                { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 1 },
                { userId: "u2", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 2 },
                { userId: "u3", itemId: "i1", type: ReactionType.Heart, timestamp: 3 },
            ],
        });
        const result = calculateAgreementScore(item, 3);
        expect(result.percentage).toBe(100);
        expect(result.isGroupFavorite).toBe(true);
    });
    it("marks as group favorite when >80%", () => {
        const item = makeItem({
            reactions: [
                { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 1 },
                { userId: "u2", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 2 },
                { userId: "u3", itemId: "i1", type: ReactionType.Heart, timestamp: 3 },
                { userId: "u4", itemId: "i1", type: ReactionType.Heart, timestamp: 4 },
                { userId: "u5", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 5 },
            ],
        });
        // 5/6 = 83.3%
        const result = calculateAgreementScore(item, 6);
        expect(result.percentage).toBeCloseTo(83.33, 1);
        expect(result.isGroupFavorite).toBe(true);
    });
    it("does NOT mark as group favorite at exactly 80%", () => {
        const item = makeItem({
            reactions: [
                { userId: "u1", itemId: "i1", type: ReactionType.Heart, timestamp: 1 },
                { userId: "u2", itemId: "i1", type: ReactionType.ThumbsUp, timestamp: 2 },
                { userId: "u3", itemId: "i1", type: ReactionType.Heart, timestamp: 3 },
                { userId: "u4", itemId: "i1", type: ReactionType.Heart, timestamp: 4 },
            ],
        });
        // 4/5 = 80%
        const result = calculateAgreementScore(item, 5);
        expect(result.percentage).toBe(80);
        expect(result.isGroupFavorite).toBe(false);
    });
});
describe("getRankedSummary", () => {
    it("produces ranked summary with correct positions and breakdowns", () => {
        const items = [
            makeItem({
                id: "a",
                title: "Hotel A",
                reactions: [
                    { userId: "u1", itemId: "a", type: ReactionType.ThumbsUp, timestamp: 1 },
                ],
                weightedScore: 1,
            }),
            makeItem({
                id: "b",
                title: "Hotel B",
                reactions: [
                    { userId: "u1", itemId: "b", type: ReactionType.Heart, timestamp: 1 },
                    { userId: "u2", itemId: "b", type: ReactionType.Heart, timestamp: 2 },
                ],
                weightedScore: 10,
            }),
        ];
        const summary = getRankedSummary(items, 4);
        expect(summary).toHaveLength(2);
        expect(summary[0].rank).toBe(1);
        expect(summary[0].title).toBe("Hotel B");
        expect(summary[0].weightedScore).toBe(10);
        expect(summary[0].reactionBreakdown.hearts).toBe(2);
        expect(summary[1].rank).toBe(2);
        expect(summary[1].title).toBe("Hotel A");
    });
});
//# sourceMappingURL=heart-sort.test.js.map