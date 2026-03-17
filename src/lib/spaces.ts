// XARK OS v2.0 — SPACE CREATION ENGINE
// The "Manifestation Loop": Dream → Space → Seed Item → Transit
// Optimistic: UI navigates immediately, DB write is parallel.

import { supabase } from "./supabase";
import { fetchDestinationPhoto } from "./unsplash";
import { storageAdapter } from "./storage";

function generateId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

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
// inviteUsername: if provided, looks up user by display_name and adds as member.
export async function createSpace(
  dream: string,
  ownerId: string,
  inviteUsername?: string
): Promise<CreateSpaceResult> {
  const title = dream.toLowerCase().trim();
  const spaceId = generateSpaceId(title);
  const seedItemTitle = generateSeedTitle(dream);

  // Personal chat (just "@name", no other content) → sanctuary atmosphere
  const isPersonalChat = inviteUsername && title === `chat with ${inviteUsername.toLowerCase()}`;
  const atmosphere = isPersonalChat ? "sanctuary" : "cyan_horizon";

  // 1. Insert the space
  await supabase.from("spaces").insert({
    id: spaceId,
    title,
    owner_id: ownerId,
    atmosphere,
  });

  // 2. Explicitly add creator as owner in space_members
  // Use insert (not upsert) — upsert's SELECT check fails when user isn't a member yet
  await supabase.from("space_members").insert(
    { space_id: spaceId, user_id: ownerId, role: "owner" }
  );

  // 3. If inviting someone, look them up and add as member
  if (inviteUsername) {
    const { data: invitedUser } = await supabase
      .from("users")
      .select("id")
      .ilike("display_name", inviteUsername)
      .single();

    if (invitedUser) {
      await supabase.from("space_members").upsert(
        { space_id: spaceId, user_id: invitedUser.id, role: "member" },
        { onConflict: "space_id,user_id" }
      );
    }
  }

  // 4. Insert the seed item — one "seeking" possibility so Decide is never empty
  // Skip for sanctuary (personal chats don't need decision items)
  if (!isPersonalChat) {
    await supabase.from("decision_items").insert({
      id: `item_${generateId()}`,
      space_id: spaceId,
      title: seedItemTitle,
      category: "experience",
      description: "",
      state: "proposed",
      is_locked: false,
    });
  }

  // 5. Insert creator's first message — the space is born with a voice
  await supabase.from("messages").insert({
    id: generateId(),
    space_id: spaceId,
    role: "user",
    content: isPersonalChat
      ? `hey ${inviteUsername}`
      : `started planning ${title}. first idea: ${seedItemTitle}`,
    user_id: ownerId,
  });

  // 6. Fetch Unsplash hero → upload to Firebase Storage → store Firebase CDN URL
  // Fire-and-forget. Non-blocking. Space is already navigable.
  fetchDestinationPhoto(title).then(async (photo) => {
    if (!photo) return;

    let heroUrl = photo.imageUrl; // Fallback: Unsplash CDN URL

    // Upload to storage adapter — eliminates Unsplash dependency
    try {
      const storagePath = `heroes/${spaceId}/hero.jpg`;
      heroUrl = await storageAdapter.upload(storagePath, photo.imageBlob, "image/jpeg");
    } catch {
      // Storage upload failed — fall back to Unsplash URL
    }

    supabase
      .from("spaces")
      .update({
        metadata: {
          hero_url: heroUrl,
          hero_photographer: photo.photographerName,
          hero_photographer_url: photo.photographerUrl,
        },
      })
      .eq("id", spaceId)
      .then(() => {});
  }).catch(() => {});

  return { spaceId, title, seedItemTitle };
}

// ── Get the optimistic space ID for immediate navigation ──
// Call this BEFORE createSpace() to navigate instantly.
export function getOptimisticSpaceId(dream: string): string {
  return generateSpaceId(dream.toLowerCase().trim());
}

/** Generate a shareable invite link for a space */
export async function createInviteLink(spaceId: string, userId: string): Promise<string | null> {
  try {
    const { data } = await supabase
      .from("space_invites")
      .insert({ space_id: spaceId, created_by: userId })
      .select("token")
      .single();

    if (!data) return null;
    const base = typeof window !== "undefined" ? window.location.origin : "";
    return `${base}/j/${data.token}`;
  } catch {
    return null;
  }
}
