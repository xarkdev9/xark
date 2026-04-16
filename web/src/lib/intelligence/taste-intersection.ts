/// Mathematical intersection of taste profiles before hitting the LLM.
/// Filters suggestions to only those that satisfy ALL active members'
/// constraints, reducing API calls and improving relevance.

export interface TasteProfile {
  userId: string;
  dietary: string[];       // ['vegetarian', 'gluten-free']
  cuisines: string[];      // ['japanese', 'italian']
  budgetMax?: number;      // per-person max
  allergies: string[];     // ['peanuts', 'shellfish']
  dislikes: string[];      // ['spicy', 'raw fish']
  preferences: string[];   // ['outdoor seating', 'quiet']
}

export interface IntersectedConstraints {
  mustAvoid: string[];        // union of all allergies + dislikes
  dietaryRequirements: string[]; // union of all dietary restrictions
  maxBudget: number | null;   // minimum of all budget limits
  sharedCuisines: string[];   // intersection of cuisine preferences
  sharedPreferences: string[]; // intersection of general preferences
  memberCount: number;
}

/**
 * Intersect taste profiles of active group members.
 * The result is a strict constraint set that satisfies everyone.
 */
export function intersectTasteProfiles(profiles: TasteProfile[]): IntersectedConstraints {
  if (profiles.length === 0) {
    return { mustAvoid: [], dietaryRequirements: [], maxBudget: null, sharedCuisines: [], sharedPreferences: [], memberCount: 0 };
  }

  // Union: allergies, dislikes, dietary (everyone's restrictions apply)
  const mustAvoid = [...new Set(profiles.flatMap(p => [...p.allergies, ...p.dislikes]))];
  const dietaryRequirements = [...new Set(profiles.flatMap(p => p.dietary))];

  // Minimum: budget (most constrained member wins)
  const budgets = profiles.map(p => p.budgetMax).filter((b): b is number => b != null);
  const maxBudget = budgets.length > 0 ? Math.min(...budgets) : null;

  // Intersection: cuisines (only cuisines everyone likes)
  const sharedCuisines = profiles.length === 1
    ? profiles[0].cuisines
    : profiles[0].cuisines.filter(c => profiles.every(p => p.cuisines.includes(c)));

  // Intersection: preferences
  const sharedPreferences = profiles.length === 1
    ? profiles[0].preferences
    : profiles[0].preferences.filter(p => profiles.every(prof => prof.preferences.includes(p)));

  return {
    mustAvoid,
    dietaryRequirements,
    maxBudget,
    sharedCuisines,
    sharedPreferences,
    memberCount: profiles.length,
  };
}

/**
 * Generate a constraint prompt for the LLM from intersected profiles.
 */
export function generateConstraintPrompt(constraints: IntersectedConstraints): string {
  const parts: string[] = [];

  if (constraints.dietaryRequirements.length > 0) {
    parts.push(`Dietary requirements: ${constraints.dietaryRequirements.join(', ')}`);
  }
  if (constraints.mustAvoid.length > 0) {
    parts.push(`Must avoid: ${constraints.mustAvoid.join(', ')}`);
  }
  if (constraints.maxBudget !== null) {
    parts.push(`Budget: max $${constraints.maxBudget} per person`);
  }
  if (constraints.sharedCuisines.length > 0) {
    parts.push(`Preferred cuisines: ${constraints.sharedCuisines.join(', ')}`);
  }
  if (constraints.sharedPreferences.length > 0) {
    parts.push(`Preferences: ${constraints.sharedPreferences.join(', ')}`);
  }

  return parts.length > 0
    ? `Group constraints (${constraints.memberCount} members):\n${parts.join('\n')}`
    : '';
}
