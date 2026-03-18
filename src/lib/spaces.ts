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
  const seedItemTitle = generateSeedTitle(dream);

  const isPersonalChat = !!inviteUsername;

  let finalSpaceId: string = "";
  // Route through /api/local-action (server-side, supabaseAdmin)
  // This handles: space creation + creator as member + invite + seed message atomically
  try {
    const token = (await import("./supabase")).getSupabaseToken();
    const res = await fetch("/api/local-action", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({
        action: "create_space",
        spaceId: generateSpaceId(title), // We still pass a base ID, backend appends a UUID
        payload: {
          title,
          invite_username: inviteUsername ?? null,
          atmosphere: isPersonalChat ? "sanctuary" : "cyan_horizon",
        },
        actorName: null,
      }),
    });
    
    if (!res.ok) {
        throw new Error(`API responded with ${res.status}`);
    }
    
    const data = await res.json();
    if (data.spaceId) {
        finalSpaceId = data.spaceId;
    } else {
        throw new Error("API did not return a spaceId");
    }
  } catch (err) {
    console.error("[spaces] createSpace via API failed:", err);
    throw err;
  }

  if (!finalSpaceId) throw new Error("API did not return a valid spaceId");

  // 6. Fetch Unsplash hero → upload to Firebase Storage → store Firebase CDN URL
  // Fire-and-forget. Non-blocking. Space is already navigable.
  fetchDestinationPhoto(title).then(async (photo) => {
    if (!photo) return;

    let heroUrl = photo.imageUrl; // Fallback: Unsplash CDN URL

    // Upload to storage adapter — eliminates Unsplash dependency
    try {
      const storagePath = `heroes/${finalSpaceId}/hero.jpg`;
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
      .eq("id", finalSpaceId)
      .then(() => {});
  }).catch(() => {});

  return { spaceId: finalSpaceId, title, seedItemTitle };
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
