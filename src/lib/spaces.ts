// XARK OS v2.0 — SPACE CREATION ENGINE
// The "Manifestation Loop": Dream → Space → Seed Item → Transit
// Optimistic: UI navigates immediately, DB write is parallel.

import { supabase } from "./supabase";

export interface CreateSpaceResult {
  spaceId: string;
  title: string;
  seedItemTitle: string;
}

// ── Generate a URL-safe space ID from a title ──
function generateSpaceId(title: string): string {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-")
    .slice(0, 40);
  return `space_${slug}`;
}

// ── Generate a seed item title from the dream ──
// Simple heuristic: extract the core noun/destination and suggest an experience.
function generateSeedTitle(dream: string): string {
  const cleaned = dream.toLowerCase().replace(/[^a-z0-9\s]/g, "").trim();

  // Common patterns: "trip to X", "X trip", "visit X", "go to X"
  const toMatch = cleaned.match(/(?:trip to|visit|go to|explore|plan)\s+(.+)/);
  if (toMatch) {
    return `sunset at ${toMatch[1]}`;
  }

  // Fallback: use the dream itself as the seed
  return `explore ${cleaned}`;
}

// ── Create a space with one seed item — fire and forget ──
// The UI has ALREADY navigated. This runs in parallel.
export async function createSpace(
  dream: string,
  ownerId: string
): Promise<CreateSpaceResult> {
  const title = dream.toLowerCase().trim();
  const spaceId = generateSpaceId(title);
  const seedItemTitle = generateSeedTitle(dream);

  // 1. Insert the space
  await supabase.from("spaces").insert({
    id: spaceId,
    title,
    owner_id: ownerId,
    atmosphere: "cyan_horizon",
  });

  // 2. Insert the seed item — one "seeking" possibility so Decide is never empty
  // proposed_by is forced to auth.uid() by the trg_force_proposed_by trigger
  await supabase.from("decision_items").insert({
    id: `item_${crypto.randomUUID()}`,
    space_id: spaceId,
    title: seedItemTitle,
    category: "experience",
    description: "",
    state: "proposed",
    is_locked: false,
  });

  // 3. Insert creator's first message — the space is born with a voice
  // Using role='user' because RLS blocks client-side xark messages.
  // @xark messages are inserted server-side via /api/xark with service_role key.
  await supabase.from("messages").insert({
    id: crypto.randomUUID(),
    space_id: spaceId,
    role: "user",
    content: `started planning ${title}. first idea: ${seedItemTitle}`,
    user_id: ownerId,
  });

  return { spaceId, title, seedItemTitle };
}

// ── Get the optimistic space ID for immediate navigation ──
// Call this BEFORE createSpace() to navigate instantly.
export function getOptimisticSpaceId(dream: string): string {
  return generateSpaceId(dream.toLowerCase().trim());
}
