// web/src/lib/intelligence/conflict-resolver.ts
// AI-mediated conflict resolution for split votes.
// Detects when >=25% of voters disagree, finds a compromise alternative.

import { getAIProvider } from "./ai-provider-factory";

export interface SplitVoteItem {
  id: string;
  title: string;
  category: string;
  groupId: string;
  metadata: Record<string, unknown>;
  totalReactions: number;
  notForMeCount: number;
  notForMeRatio: number;
}

export interface CompromiseResult {
  query: string;
  reason: string;
  results: Array<{
    title: string;
    price?: string;
    imageUrl?: string;
    description?: string;
    externalUrl?: string;
    rating?: number;
    source: string;
  }>;
}

/**
 * Detect split votes on items in a group.
 * Returns items where >=25% of voters chose NotForMe and total reactions >=3.
 */
export async function detectSplitVotes(
  groupId: string,
  items: Array<{ id: string; title: string; category: string; metadata: Record<string, unknown> }>,
  reactions: Array<{ item_id: string; reaction_type: string; user_id: string }>
): Promise<SplitVoteItem[]> {
  const splits: SplitVoteItem[] = [];

  for (const item of items) {
    const itemReactions = reactions.filter((r) => r.item_id === item.id);
    if (itemReactions.length < 3) continue;

    const notForMe = itemReactions.filter((r) => r.reaction_type === "not_for_me").length;
    const ratio = notForMe / itemReactions.length;

    if (ratio >= 0.25) {
      splits.push({
        ...item,
        groupId,
        totalReactions: itemReactions.length,
        notForMeCount: notForMe,
        notForMeRatio: ratio,
      });
    }
  }

  return splits;
}

/**
 * Find a compromise alternative for a split-vote item.
 * Uses AI to understand WHY people disagree, then searches for a middle ground.
 */
export async function findCompromise(
  item: SplitVoteItem,
  destination: string,
  tasteContext?: string
): Promise<CompromiseResult | null> {
  const provider = getAIProvider();
  if (!provider) return null;

  try {
    // Ask AI to suggest a compromise search query
    const prompt = `An item "${item.title}" (${item.category}) in ${destination} has split votes: ${item.notForMeCount} of ${item.totalReactions} people voted "Not for me".

Common reasons for disagreement: budget concerns, dietary restrictions, accessibility, style/vibe mismatch.
${tasteContext ? `Group taste context: ${tasteContext}` : ""}

Suggest a compromise alternative that:
1. Keeps the best aspects of the original (location, type, vibe)
2. Addresses likely objections (price, dietary, accessibility)
3. Is specific enough to search for

Return JSON: {"query": "specific search query for the compromise", "reason": "brief explanation of the compromise (max 20 words, no AI cringe)"}`;

    const result = await provider.generateJson(prompt);
    const query = String(result.query || "");
    const reason = String(result.reason || "");

    if (!query) return null;

    // Search for the compromise
    const { searchLocal } = await import("./searchapi-client");
    const searchResults = await searchLocal({
      query,
      location: destination,
    });

    return {
      query,
      reason,
      results: searchResults.map((r) => ({
        title: r.title,
        price: r.price,
        imageUrl: r.imageUrl,
        description: r.description,
        externalUrl: r.externalUrl,
        rating: r.rating,
        source: "mediator",
      })),
    };
  } catch (err) {
    console.error("[conflict-resolver] Compromise search failed:", err instanceof Error ? err.message : String(err));
    return null;
  }
}

/**
 * Build a mediator whisper message for a split-vote item.
 * Rules: Never name WHO voted NotForMe. Frame compromise positively.
 */
export function buildMediatorMessage(item: SplitVoteItem, compromise: CompromiseResult): string {
  const hasResults = compromise.results.length > 0;
  if (!hasResults) {
    return `looks like you're split on ${item.title}. couldn't find a great alternative — maybe vote on what matters most?`;
  }

  const topResult = compromise.results[0];
  const pricePart = topResult.price ? ` (${topResult.price})` : "";
  return `looks like you're split on ${item.title}. found ${topResult.title}${pricePart} — ${compromise.reason}. take a look.`;
}
