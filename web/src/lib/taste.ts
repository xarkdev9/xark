// src/lib/taste.ts
// Taste Graph helpers — intersect group constraints, build Gemini injection.
// Called by /api/xark at search time. Pure functions, no side effects.

export interface TasteProfile {
  user_id: string;
  hard_constraints: string[];  // ["vegan", "no_chains"]
  implicit_weights: Record<string, number>;  // {"japanese": 12, "steakhouse": -6}
  onboarded: boolean;
}

export interface TasteContext {
  /** Hard vetoes — union of all members' constraints. One vegan = no steakhouses. */
  hardConstraints: string[];
  /** Soft preferences — aggregated weight string for Gemini prompt injection. */
  softPreferences: string;
  /** How many members have onboarded (for analytics/whisper triggers). */
  onboardedCount: number;
  memberCount: number;
}

/**
 * Intersect taste profiles for a group. Returns unified constraints + preferences.
 * Called server-side by /api/xark with profiles from get_space_taste_profiles RPC.
 */
export function intersectTasteProfiles(profiles: TasteProfile[]): TasteContext {
  // Hard constraints: UNION of all members (one vegan vetoes steakhouses for everyone)
  const allConstraints = new Set<string>();
  for (const p of profiles) {
    if (Array.isArray(p.hard_constraints)) {
      for (const c of p.hard_constraints) allConstraints.add(c);
    }
  }

  // Implicit weights: SUM across all members
  const aggregated: Record<string, number> = {};
  for (const p of profiles) {
    if (p.implicit_weights && typeof p.implicit_weights === "object") {
      for (const [key, val] of Object.entries(p.implicit_weights)) {
        if (typeof val === "number") {
          aggregated[key] = (aggregated[key] ?? 0) + val;
        }
      }
    }
  }

  // Sort by absolute weight descending, take top 5 for prompt brevity
  const sorted = Object.entries(aggregated)
    .sort((a, b) => Math.abs(b[1]) - Math.abs(a[1]))
    .slice(0, 5);

  // Build a natural-language preference string for Gemini
  const likes = sorted.filter(([, v]) => v > 0).map(([k]) => k);
  const dislikes = sorted.filter(([, v]) => v < 0).map(([k]) => k);

  const parts: string[] = [];
  if (likes.length > 0) parts.push(`group prefers: ${likes.join(", ")}`);
  if (dislikes.length > 0) parts.push(`group avoids: ${dislikes.join(", ")}`);

  return {
    hardConstraints: Array.from(allConstraints),
    softPreferences: parts.join(". "),
    onboardedCount: profiles.filter((p) => p.onboarded).length,
    memberCount: profiles.length,
  };
}

/**
 * Build the Gemini prompt injection from taste context.
 * Returns a short string to append to the dynamic prompt.
 */
export function buildTastePromptInjection(ctx: TasteContext): string {
  const lines: string[] = [];

  if (ctx.hardConstraints.length > 0) {
    lines.push(`HARD CONSTRAINTS (must respect): ${ctx.hardConstraints.join(", ")}`);
  }

  if (ctx.softPreferences) {
    lines.push(`SOFT PREFERENCES: ${ctx.softPreferences}`);
  }

  return lines.length > 0
    ? `\n\nGROUP TASTE PROFILE:\n${lines.join("\n")}`
    : "";
}
