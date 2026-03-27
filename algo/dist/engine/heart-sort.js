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
import { ReactionType, REACTION_WEIGHTS } from "../models/types.js";
/**
 * Calculates the weighted score for an item based on its reactions.
 * Each user's reaction is counted once (last reaction wins if duplicated).
 */
export function calculateWeightedScore(reactions) {
    // Deduplicate: one reaction per user, last one wins
    const userReactions = new Map();
    for (const reaction of reactions) {
        userReactions.set(reaction.userId, reaction.type);
    }
    let score = 0;
    for (const type of userReactions.values()) {
        score += REACTION_WEIGHTS[type];
    }
    return score;
}
/**
 * Adds a reaction to an item and recalculates its weighted score.
 * Returns the updated item. If the user already reacted, their reaction is replaced.
 */
export function addReaction(item, userId, reactionType, timestamp) {
    // Remove any existing reaction from this user
    const filteredReactions = item.reactions.filter((r) => r.userId !== userId);
    const newReaction = {
        userId,
        itemId: item.id,
        type: reactionType,
        timestamp,
    };
    const reactions = [...filteredReactions, newReaction];
    const weightedScore = calculateWeightedScore(reactions);
    return {
        ...item,
        reactions,
        weightedScore,
    };
}
/**
 * Removes a user's reaction from an item and recalculates score.
 */
export function removeReaction(item, userId) {
    const reactions = item.reactions.filter((r) => r.userId !== userId);
    const weightedScore = calculateWeightedScore(reactions);
    return {
        ...item,
        reactions,
        weightedScore,
    };
}
/**
 * Sorts items by weighted score (descending).
 * Ties are broken by earliest proposal time (first proposed wins).
 */
export function heartSort(items) {
    return [...items].sort((a, b) => {
        if (b.weightedScore !== a.weightedScore) {
            return b.weightedScore - a.weightedScore;
        }
        return a.proposedAt - b.proposedAt;
    });
}
/**
 * Returns the top-N items by weighted score.
 */
export function getTopItems(items, n) {
    return heartSort(items).slice(0, n);
}
/**
 * Calculates an "Agreement Score" — the percentage of group members
 * who have positively reacted (❤️ or 👍🏻) to an item.
 * Items with >80% get a "Group Favorite" designation.
 */
export function calculateAgreementScore(item, totalMembers) {
    const uniqueReactors = new Set(item.reactions.map((r) => r.userId));
    const percentage = totalMembers > 0 ? (uniqueReactors.size / totalMembers) * 100 : 0;
    return {
        percentage,
        isGroupFavorite: percentage > 80,
    };
}
/**
 * Gets a ranked summary of items with their scores and positions.
 */
export function getRankedSummary(items, totalMembers) {
    const sorted = heartSort(items);
    return sorted.map((item, index) => {
        const agreement = calculateAgreementScore(item, totalMembers);
        const hearts = item.reactions.filter((r) => r.type === ReactionType.Heart).length;
        const thumbsUp = item.reactions.filter((r) => r.type === ReactionType.ThumbsUp).length;
        return {
            itemId: item.id,
            title: item.title,
            rank: index + 1,
            weightedScore: item.weightedScore,
            agreementScore: agreement.percentage,
            isGroupFavorite: agreement.isGroupFavorite,
            reactionBreakdown: { hearts, thumbsUp },
        };
    });
}
//# sourceMappingURL=heart-sort.js.map