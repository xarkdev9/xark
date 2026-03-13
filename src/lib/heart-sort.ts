// XARK OS v2.0 — HEART-SORT ENGINE (SSOT)
// The single source of truth for decision ranking.
// All UI components must reflect this logic.
// Full engine ported from /Users/ramchitturi/algo/src/engine/heart-sort.ts

// ── Backwards-Compatible Types (existing) ──

export interface Possibility {
  id: string;
  title: string;
  imageUrl: string;
  weightedScore: number; // 0-1, drives Amber wash intensity and sort order
  agreementScore: number; // 0-1, drives ConsensusMark state
  isLocked: boolean; // true = finalized, Green settle to Cloud Dancer
  createdAt: number;
}

export type ConsensusState = "seeking" | "steady" | "ignited";

// Derive consensus visual state from agreementScore
export function getConsensusState(agreementScore: number): ConsensusState {
  if (agreementScore > 0.8) return "ignited";
  if (agreementScore > 0.3) return "steady";
  return "seeking";
}

// Heart-sort: rank possibilities by weightedScore descending.
// Locked items sink to end (finality = settled).
export function heartSort(items: Possibility[]): Possibility[];
export function heartSort(items: DecisionItem[]): DecisionItem[];
export function heartSort(items: (Possibility | DecisionItem)[]): (Possibility | DecisionItem)[] {
  return [...items].sort((a, b) => {
    // Locked items sink to end
    const aLocked = "isLocked" in a ? a.isLocked : !!a.lockedAt;
    const bLocked = "isLocked" in b ? b.isLocked : !!b.lockedAt;
    if (aLocked !== bLocked) return aLocked ? 1 : -1;

    // Descending by weightedScore
    if (b.weightedScore !== a.weightedScore) {
      return b.weightedScore - a.weightedScore;
    }

    // Tie-break: earliest proposed wins
    const aTime = "createdAt" in a ? a.createdAt : ("proposedAt" in a ? a.proposedAt : 0);
    const bTime = "createdAt" in b ? b.createdAt : ("proposedAt" in b ? b.proposedAt : 0);
    return aTime - bTime;
  });
}

// ── Full Engine Types (ported from /algo) ──

export type ReactionType = "love_it" | "works_for_me" | "not_for_me";

export const REACTION_WEIGHTS: Record<string, number> = {
  love_it: 5,
  works_for_me: 1,
  not_for_me: -3,
};

export interface Reaction {
  userId: string;
  itemId: string;
  type: ReactionType;
  timestamp: number;
}

export interface CommitmentProof {
  type: string;
  value: string;
  submittedBy: string;
  submittedAt: number;
}

export interface OwnershipRecord {
  ownerId: string;
  assignedAt: number;
  reason: "booker" | "transfer";
}

export interface DecisionItem {
  id: string;
  spaceId: string;
  title: string;
  description: string;
  category: string;
  state: string;
  proposedBy: string;
  proposedAt: number;
  reactions: Reaction[];
  weightedScore: number;
  commitmentProof: CommitmentProof | null;
  ownership: OwnershipRecord | null;
  ownershipHistory: OwnershipRecord[];
  lockedAt: number | null;
  version: number;
  metadata: Record<string, unknown>;
}

// ── Pure Computation Functions ──

/**
 * Calculates the weighted score for an item based on its reactions.
 * Each user's reaction is counted once (last reaction wins if duplicated).
 * Pure function — no mutation.
 */
export function calculateWeightedScore(
  reactions: Reaction[],
  weights?: Record<string, number>
): number {
  const effectiveWeights = weights ?? REACTION_WEIGHTS;

  // Deduplicate: one reaction per user, last one wins
  const userReactions = new Map<string, ReactionType>();
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
 * Pure function — returns new object.
 */
export function addReaction(
  item: DecisionItem,
  userId: string,
  reactionType: ReactionType,
  timestamp: number,
  weights?: Record<string, number>
): DecisionItem {
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
 * Pure function — returns new object.
 */
export function removeReaction(
  item: DecisionItem,
  userId: string,
  weights?: Record<string, number>
): DecisionItem {
  const reactions = item.reactions.filter((r) => r.userId !== userId);
  const weightedScore = calculateWeightedScore(reactions, weights);

  return {
    ...item,
    reactions,
    weightedScore,
  };
}

/**
 * Calculates an "Agreement Score" — the percentage of group members
 * who have reacted (ALL reactors including NotForMe) to an item.
 * isGroupFavorite = strictly > 80% (not >=).
 * Pure function.
 */
export function calculateAgreementScore(
  item: DecisionItem,
  totalMembers: number,
  threshold?: number
): { percentage: number; isGroupFavorite: boolean } {
  const effectiveThreshold = threshold ?? 80;

  // ALL reactors (including NotForMe) count for agreement score
  const uniqueReactors = new Set(item.reactions.map((r) => r.userId));
  const percentage =
    totalMembers > 0 ? (uniqueReactors.size / totalMembers) * 100 : 0;

  return {
    percentage,
    isGroupFavorite: percentage > effectiveThreshold, // strictly >
  };
}

/**
 * Gets a ranked summary of items with their scores and positions.
 * Pure function.
 */
export function getRankedSummary(
  items: DecisionItem[],
  totalMembers: number,
  threshold?: number
): Array<{
  itemId: string;
  title: string;
  rank: number;
  weightedScore: number;
  agreementScore: number;
  isGroupFavorite: boolean;
  reactionBreakdown: {
    loveIt: number;
    worksForMe: number;
    notForMe: number;
    hearts: number;
    thumbsUp: number;
  };
}> {
  const sorted = heartSort(items) as DecisionItem[];
  return sorted.map((item, index) => {
    const agreement = calculateAgreementScore(item, totalMembers, threshold);
    const loveIt = item.reactions.filter((r) => r.type === "love_it").length;
    const worksForMe = item.reactions.filter((r) => r.type === "works_for_me").length;
    const notForMe = item.reactions.filter((r) => r.type === "not_for_me").length;

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
