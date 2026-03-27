/**
 * Weighted Heart-Sort Algorithm
 *
 * Items are re-ordered in real-time by aggregate group reactions.
 * ❤️ = 5x weight, 👍🏻 = 1x weight.
 *
 * Performance: O(1) per reaction update, O(n log n) for full sort.
 *
 * The value is as a pre-commitment alignment tool — it builds social consensus
 * before someone commits real money, reducing the risk of contentious bookings.
 */
import type { BookableItem, ItemId, Reaction, UserId } from "../models/types.js";
import { ReactionType } from "../models/types.js";
/**
 * Calculates the weighted score for an item based on its reactions.
 * Each user's reaction is counted once (last reaction wins if duplicated).
 */
export declare function calculateWeightedScore(reactions: Reaction[]): number;
/**
 * Adds a reaction to an item and recalculates its weighted score.
 * Returns the updated item. If the user already reacted, their reaction is replaced.
 */
export declare function addReaction(item: BookableItem, userId: UserId, reactionType: ReactionType, timestamp: number): BookableItem;
/**
 * Removes a user's reaction from an item and recalculates score.
 */
export declare function removeReaction(item: BookableItem, userId: UserId): BookableItem;
/**
 * Sorts items by weighted score (descending).
 * Ties are broken by earliest proposal time (first proposed wins).
 */
export declare function heartSort(items: BookableItem[]): BookableItem[];
/**
 * Returns the top-N items by weighted score.
 */
export declare function getTopItems(items: BookableItem[], n: number): BookableItem[];
/**
 * Calculates an "Agreement Score" — the percentage of group members
 * who have positively reacted (❤️ or 👍🏻) to an item.
 * Items with >80% get a "Group Favorite" designation.
 */
export declare function calculateAgreementScore(item: BookableItem, totalMembers: number): {
    percentage: number;
    isGroupFavorite: boolean;
};
/**
 * Gets a ranked summary of items with their scores and positions.
 */
export declare function getRankedSummary(items: BookableItem[], totalMembers: number): Array<{
    itemId: ItemId;
    title: string;
    rank: number;
    weightedScore: number;
    agreementScore: number;
    isGroupFavorite: boolean;
    reactionBreakdown: {
        hearts: number;
        thumbsUp: number;
    };
}>;
//# sourceMappingURL=heart-sort.d.ts.map