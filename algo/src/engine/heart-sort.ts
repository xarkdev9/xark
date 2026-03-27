/**
 * Weighted Heart-Sort Algorithm
 *
 * Items are re-ordered in real-time by aggregate group reactions.
 * Default: ❤️ = 5x weight, 👍🏻 = 1x weight. Weights are configurable.
 *
 * Performance: O(1) per reaction update, O(n log n) for full sort.
 *
 * The value is as a pre-commitment alignment tool — it builds social consensus
 * before someone commits, reducing the risk of contentious decisions.
 */

import type { BookableItem, ItemId, Reaction, UserId } from "../models/types.js";
import { ReactionType, REACTION_WEIGHTS } from "../models/types.js";

/**
 * Calculates the weighted score for an item based on its reactions.
 * Each user's reaction is counted once (last reaction wins if duplicated).
 *
 * @param weights Optional custom weights. Defaults to REACTION_WEIGHTS.
 */
export function calculateWeightedScore(
  reactions: Reaction[],
  weights?: Record<string, number>
): number {
  const effectiveWeights = weights ?? REACTION_WEIGHTS;

  // Deduplicate: one reaction per user, last one wins
  const userReactions = new Map<UserId, ReactionType>();
  for (const reaction of reactions) {
    userReactions.set(reaction.userId, reaction.type);
  }

  let score = 0;
  for (const type of userReactions.values()) {
    score += effectiveWeights[type] ?? 0;
  }
  return score;
}

/**
 * Adds a reaction to an item and recalculates its weighted score.
 * Returns the updated item. If the user already reacted, their reaction is replaced.
 */
export function addReaction(
  item: BookableItem,
  userId: UserId,
  reactionType: ReactionType,
  timestamp: number,
  weights?: Record<string, number>
): BookableItem {
  // Remove any existing reaction from this user
  const filteredReactions = item.reactions.filter((r) => r.userId !== userId);

  const newReaction: Reaction = {
    userId,
    itemId: item.id,
    type: reactionType,
    timestamp,
  };

  const reactions = [...filteredReactions, newReaction];
  const weightedScore = calculateWeightedScore(reactions, weights);

  return {
    ...item,
    reactions,
    weightedScore,
  };
}

/**
 * Removes a user's reaction from an item and recalculates score.
 */
export function removeReaction(
  item: BookableItem,
  userId: UserId,
  weights?: Record<string, number>
): BookableItem {
  const reactions = item.reactions.filter((r) => r.userId !== userId);
  const weightedScore = calculateWeightedScore(reactions, weights);

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
export function heartSort(items: BookableItem[]): BookableItem[] {
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
export function getTopItems(items: BookableItem[], n: number): BookableItem[] {
  return heartSort(items).slice(0, n);
}

/**
 * Calculates an "Agreement Score" — the percentage of group members
 * who have positively reacted (❤️ or 👍🏻) to an item.
 *
 * @param threshold Custom threshold for "Group Favorite". Default: 80 (strictly >80%).
 */
export function calculateAgreementScore(
  item: BookableItem,
  totalMembers: number,
  threshold?: number
): { percentage: number; isGroupFavorite: boolean } {
  const effectiveThreshold = threshold ?? 80;
  // Only count positive signals (LoveIt, WorksForMe) as agreement — NotForMe is resistance, not agreement
  const positiveReactors = new Set(
    item.reactions
      .filter((r) => r.type !== ReactionType.NotForMe)
      .map((r) => r.userId)
  );
  const percentage =
    totalMembers > 0 ? (positiveReactors.size / totalMembers) * 100 : 0;
  return {
    percentage,
    isGroupFavorite: percentage > effectiveThreshold,
  };
}

/**
 * Gets a ranked summary of items with their scores and positions.
 */
export function getRankedSummary(
  items: BookableItem[],
  totalMembers: number,
  threshold?: number
): Array<{
  itemId: ItemId;
  title: string;
  rank: number;
  weightedScore: number;
  agreementScore: number;
  isGroupFavorite: boolean;
  reactionBreakdown: {
    loveIt: number;
    worksForMe: number;
    notForMe: number;
    // Backwards compat aliases
    hearts: number;
    thumbsUp: number;
  };
}> {
  const sorted = heartSort(items);
  return sorted.map((item, index) => {
    const agreement = calculateAgreementScore(item, totalMembers, threshold);
    const loveIt = item.reactions.filter(
      (r) => r.type === ReactionType.LoveIt
    ).length;
    const worksForMe = item.reactions.filter(
      (r) => r.type === ReactionType.WorksForMe
    ).length;
    const notForMe = item.reactions.filter(
      (r) => r.type === ReactionType.NotForMe
    ).length;

    return {
      itemId: item.id,
      title: item.title,
      rank: index + 1,
      weightedScore: item.weightedScore,
      agreementScore: agreement.percentage,
      isGroupFavorite: agreement.isGroupFavorite,
      reactionBreakdown: {
        loveIt,
        worksForMe,
        notForMe,
        hearts: loveIt,
        thumbsUp: worksForMe,
      },
    };
  });
}
