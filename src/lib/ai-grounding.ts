// XARK OS v2.0 — AI GROUNDING CONSTRAINT SYSTEM
// Per Section 8 of mar10_algo.md: @xark MUST respect locked decisions.
// Locked categories become forbidden — @xark will not suggest alternatives.
// Source of truth: /Users/ramchitturi/algo/src/engine/ai-grounding.ts

import { supabase } from "./supabase";

// ── Reaction Weights (Section 5 of mar10_algo.md) ──

export const REACTION_WEIGHTS = {
  love_it: 5,
  works_for_me: 1,
  not_for_me: -3,
} as const;

// ── Types ──

export interface SpaceItem {
  id: string;
  title: string;
  category: string;
  description: string;
  state: string;
  weightedScore: number;
  agreementScore: number;
  ownership: { ownerId: string } | null;
}

export interface GroundingConstraint {
  type: "locked_decision" | "assigned_task";
  itemId: string;
  title: string;
  category: string;
  description: string;
  ownerId: string;
}

export interface RecentlyLocked {
  title: string;
  ownerName: string;
}

export interface GroundingContext {
  spaceId: string;
  constraints: GroundingConstraint[];
  forbiddenCategories: string[];
  lockedCategories: string[];
  currentFavorites: string[];
  forbiddenSuggestions: string[];
  topIgnitedTitle: string | null;
  recentlyLocked: RecentlyLocked | null;
}

export interface ConflictResult {
  hasConflict: boolean;
  reason?: string;
  conflictingItemId?: string;
}

// ── Supabase Queries ──

async function fetchLockedItems(spaceId: string) {
  const { data, error } = await supabase
    .from("decision_items")
    .select("id, title, category, description, state, weighted_score, ownership")
    .eq("space_id", spaceId)
    .eq("is_locked", true)
    .order("locked_at", { ascending: false });

  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  return data ?? [];
}

async function fetchAllItems(spaceId: string): Promise<SpaceItem[]> {
  const { data, error } = await supabase
    .from("decision_items")
    .select("id, title, category, description, state, weighted_score, agreement_score, ownership")
    .eq("space_id", spaceId);

  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  return (data ?? []).map((d) => ({
    id: d.id,
    title: d.title,
    category: d.category,
    description: d.description ?? "",
    state: d.state,
    weightedScore: d.weighted_score ?? 0,
    agreementScore: d.agreement_score ?? 0,
    ownership: d.ownership,
  }));
}

async function fetchAssignedTasks(spaceId: string) {
  const { data, error } = await supabase
    .from("tasks")
    .select("id, title, assignee_id")
    .eq("space_id", spaceId)
    .not("assignee_id", "is", null);

  if (error) throw new Error(`Supabase query failed: ${error.message}`);
  return data ?? [];
}

// ── Context Builder ──

export async function buildGroundingContext(
  spaceId: string
): Promise<GroundingContext> {
  const [lockedItems, assignedTasks, allItems] = await Promise.all([
    fetchLockedItems(spaceId),
    fetchAssignedTasks(spaceId),
    fetchAllItems(spaceId),
  ]);

  const constraints: GroundingConstraint[] = [];

  for (const item of lockedItems) {
    constraints.push({
      type: "locked_decision",
      itemId: item.id,
      title: item.title,
      category: item.category,
      description: item.description ?? "",
      ownerId: item.ownership?.ownerId ?? "",
    });
  }

  for (const task of assignedTasks) {
    constraints.push({
      type: "assigned_task",
      itemId: task.id,
      title: task.title,
      category: "",
      description: "",
      ownerId: task.assignee_id,
    });
  }

  const lockedCategories = [
    ...new Set(
      constraints
        .filter((c) => c.type === "locked_decision" && c.category)
        .map((c) => c.category)
    ),
  ];

  // Current favorites: top-scored unlocked items (lowercase states from DB)
  const unlockedItems = allItems.filter(
    (i) => !["locked", "purchased", "chosen", "decided"].includes(i.state)
  );
  const currentFavorites = unlockedItems
    .sort((a, b) => b.weightedScore - a.weightedScore)
    .slice(0, 3)
    .map((i) => i.title);

  // Top ignited: highest-scoring unlocked item with agreementScore > 0.8
  const ignitedItems = unlockedItems
    .filter((i) => i.agreementScore > 0.8)
    .sort((a, b) => b.agreementScore - a.agreementScore);
  const topIgnitedTitle = ignitedItems.length > 0 ? ignitedItems[0].title : null;

  // Recently locked: most recent locked item with owner display name
  let recentlyLocked: RecentlyLocked | null = null;
  if (lockedItems.length > 0) {
    const newest = lockedItems[0]; // fetchLockedItems returns latest first by default
    const ownerId = newest.ownership?.ownerId ?? "";
    recentlyLocked = {
      title: newest.title,
      ownerName: ownerId.replace(/^user_/, "").replace(/^name_/, ""),
    };
  }

  return {
    spaceId,
    constraints,
    forbiddenCategories: lockedCategories,
    lockedCategories,
    currentFavorites,
    forbiddenSuggestions: lockedCategories,
    topIgnitedTitle,
    recentlyLocked,
  };
}

// ── Deterministic Greeting — data-driven, no AI call ──
// Logic A: agreementScore > 0.8 (ignited) → prompt to lock
// Logic B: recently locked item → confirmation with owner name
// Logic C: fallback → warm onboarding with contextual examples

function getContextualExamples(spaceTitle?: string): [string, string] {
  const t = (spaceTitle ?? "").toLowerCase();

  if (/trip|travel|vacation|getaway|visit|weekend/.test(t))
    return ["find a good hotel near the beach", "what should we do on day one"];

  if (/dinner|food|eat|restaurant|lunch|brunch/.test(t))
    return ["find a good spot nearby", "what's everyone in the mood for"];

  if (/party|birthday|celebration|event|wedding/.test(t))
    return ["find a venue for us", "what should we plan first"];

  if (/buy|purchase|shop|gift/.test(t))
    return ["find the best option", "compare a few choices for me"];

  // Generic — works for any planning context
  return ["look into a few options for us", "add an idea to the list"];
}

export function getGreeting(context: GroundingContext, spaceTitle?: string): string {
  // Logic A — an unlocked item has ignited consensus
  if (context.topIgnitedTitle) {
    return `morning. the group is leaning toward ${context.topIgnitedTitle}. should we lock it?`;
  }

  // Logic B — an item was recently locked
  if (context.recentlyLocked) {
    return `${context.recentlyLocked.ownerName} just locked in ${context.recentlyLocked.title}. we're all set.`;
  }

  // Logic C — warm onboarding with contextual examples
  const name = spaceTitle ?? "this";
  const [ex1, ex2] = getContextualExamples(spaceTitle);
  return `what are we thinking for ${name}? just type what's on your mind — something like "${ex1}" or "${ex2}"`;
}

// ── Conflict Checker (Section 8 of mar10_algo.md) ──
// Prevents @xark from suggesting a "Four Seasons" if the group locked the "Hilton."

export function checkSuggestionConflicts(
  currentItems: SpaceItem[],
  proposedCategory: string
): ConflictResult {
  // 1. Identify items that have reached terminal states (lowercase from DB)
  const lockedItems = currentItems.filter(
    (item) => ["locked", "purchased", "chosen", "decided"].includes(item.state)
  );

  // 2. Check if the proposed category is already solved
  const conflictingItem = lockedItems.find(
    (item) => item.category.toLowerCase() === proposedCategory.toLowerCase()
  );

  if (conflictingItem) {
    return {
      hasConflict: true,
      reason: `Category [${proposedCategory}] is locked by decision: ${conflictingItem.title}`,
      conflictingItemId: conflictingItem.id,
    };
  }

  return { hasConflict: false };
}

// ── Context-Based Conflict Checker ──
// Convenience wrapper that uses GroundingContext instead of raw items.

export function checkContextConflicts(
  context: GroundingContext,
  suggestionCategory: string
): GroundingConstraint[] {
  return context.constraints.filter(
    (c) =>
      c.type === "locked_decision" &&
      c.category.toLowerCase() === suggestionCategory.toLowerCase()
  );
}

// ── Grounding Manifest Generator ──
// Produces the dynamic prompt prefix for @xark with weight rules.

export function generateGroundingManifest(items: SpaceItem[]): string {
  const locked = items
    .filter((i) => ["locked", "purchased", "chosen", "decided"].includes(i.state))
    .map((i) => i.title);

  return [
    "GROUNDING MANIFEST:",
    `- LOCKED DECISIONS: ${locked.length > 0 ? locked.join(", ") : "None"}`,
    `- FORBIDDEN CATEGORIES: ${locked.length > 0 ? "Do not suggest alternatives for locked items." : "All categories open."}`,
    `- WEIGHTING RULES: ${REACTION_WEIGHTS.not_for_me} (Not for me), +${REACTION_WEIGHTS.works_for_me} (Works for me), +${REACTION_WEIGHTS.love_it} (Love it).`,
  ].join("\n");
}

// ── Full Grounding Prompt Generator (State Map Approach) ──
// Groups items by state for nuanced reasoning instead of rigid category bans.
// Lets Gemini reason about scope — "hotel" locked doesn't ban "Airbnb for a different city."

export function generateGroundingPrompt(context: GroundingContext): string {
  if (context.constraints.length === 0 && context.currentFavorites.length === 0) {
    return "No locked decisions yet. You may suggest any options freely.";
  }

  const lines: string[] = [
    "=== CURRENT SPACE STATE MAP ===",
    "",
  ];

  // Group constraints by type
  const locked = context.constraints.filter((c) => c.type === "locked_decision");
  const tasks = context.constraints.filter((c) => c.type === "assigned_task");

  // Locked/Purchased — committed, do not reopen
  if (locked.length > 0) {
    lines.push("COMMITTED (do not reopen, do not suggest alternatives for the SAME decision):");
    for (const c of locked) {
      lines.push(`  - [${c.category}] ${c.title}${c.ownerId ? ` (owner: ${c.ownerId})` : ""}`);
    }
    lines.push("");
  }

  // Current favorites — items with high scores, not yet locked
  if (context.currentFavorites.length > 0) {
    lines.push("VOTING (active reactions, respect current signal):");
    for (const fav of context.currentFavorites) {
      lines.push(`  - ${fav}`);
    }
    lines.push("");
  }

  // Top ignited — ready for commitment
  if (context.topIgnitedTitle) {
    lines.push(`IGNITED (>80% agreement, ready for commitment): ${context.topIgnitedTitle}`);
    lines.push("");
  }

  // Recently locked
  if (context.recentlyLocked) {
    lines.push(`RECENTLY LOCKED: ${context.recentlyLocked.title} by ${context.recentlyLocked.ownerName}`);
    lines.push("");
  }

  // Assigned tasks
  if (tasks.length > 0) {
    lines.push("ASSIGNED TASKS (being handled):");
    for (const t of tasks) {
      lines.push(`  - ${t.title}${t.ownerId ? ` (assigned to: ${t.ownerId})` : ""}`);
    }
    lines.push("");
  }

  // Scope reasoning guidance
  lines.push("SCOPE RULES:");
  lines.push("  - A locked 'hotel' does NOT ban 'Airbnb for a different city' if it's a different need.");
  lines.push("  - A locked 'Italian restaurant' DOES ban 'let's try Italian' for the same meal.");
  lines.push("  - Test: is this the SAME decision or a DIFFERENT decision?");
  lines.push("");

  // Weighting rules
  lines.push(
    `WEIGHTING RULES: ${REACTION_WEIGHTS.not_for_me} (Not for me), +${REACTION_WEIGHTS.works_for_me} (Works for me), +${REACTION_WEIGHTS.love_it} (Love it).`
  );

  return lines.join("\n");
}
