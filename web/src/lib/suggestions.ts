// hello OS v2.0 — WHISPER ENGINE
// Proactive suggestions from Layer 3 state (votes, cards, locks, dates).
// No LLM calls. Pure deterministic Postgres queries.
// Priority: 0 = highest (P0), 2 = lowest (P2).

import { supabase } from "./supabase";

// ── Types ──

export type WhisperType =
  | "onboarding"
  | "consensus_ready"
  | "missing_category"
  | "nudge_vote"
  | "itinerary_ready"
  | "consensus_split";

export interface Whisper {
  id: string;
  priority: number;
  ghostText: string;
  groupId: string;
  spaceTitle: string;
  type: WhisperType;
  itemId?: string;
}

// ── Generator ──

export async function generateWhispers(userId: string): Promise<Whisper[]> {
  const whispers: Whisper[] = [];

  try {
    // ── Check 1 (P2): Has user onboarded taste profile? ──
    try {
      const { data: tasteProfile } = await supabase
        .from("user_taste_profiles")
        .select("onboarded")
        .eq("user_id", userId)
        .maybeSingle();

      if (!tasteProfile || !tasteProfile.onboarded) {
        whispers.push({
          id: `onboarding_${userId}`,
          priority: 2,
          ghostText: "tell me how you travel and what you eat.",
          groupId: "",
          spaceTitle: "",
          type: "onboarding",
        });
      }
    } catch {
      // Graceful degradation — table may not exist yet
    }

    // ── Fetch user's spaces (needed for checks 2, 3, 4) ──
    const { data: memberRows } = await supabase
      .from("space_members")
      .select("group_id")
      .eq("user_id", userId);

    const memberGroupIds = (memberRows ?? []).map((r) => r.group_id);

    if (memberGroupIds.length === 0) {
      return sortByPriority(whispers);
    }

    // Fetch space titles in one shot
    const { data: spacesData } = await supabase
      .from("spaces")
      .select("id, title")
      .in("id", memberGroupIds);

    const spaceTitleById = new Map<string, string>(
      (spacesData ?? []).map((s) => [s.id, s.title])
    );

    // ── Check 2 (P0): Items in countdown (lock_deadline IS NOT NULL, is_locked = false) ──
    try {
      const { data: countdownItems } = await supabase
        .from("decision_items")
        .select("id, title, group_id, lock_deadline")
        .in("group_id", memberGroupIds)
        .not("lock_deadline", "is", null)
        .eq("is_locked", false);

      for (const item of countdownItems ?? []) {
        const spaceTitle = spaceTitleById.get(item.group_id) ?? "";
        const deadline = new Date(item.lock_deadline);
        const hoursLeft = Math.round(
          (deadline.getTime() - Date.now()) / 3_600_000
        );
        const timePhrase =
          hoursLeft <= 1
            ? "expires soon"
            : hoursLeft < 24
            ? `${hoursLeft}h left`
            : `${Math.round(hoursLeft / 24)}d left`;

        whispers.push({
          id: `consensus_ready_${item.id}`,
          priority: 0,
          ghostText: `${item.title} — ${timePhrase}. lock it in?`,
          groupId: item.group_id,
          spaceTitle,
          type: "consensus_ready",
          itemId: item.id,
        });
      }
    } catch {
      // Graceful degradation
    }

    // ── Check 3 (P1): Spaces with dates but no hotels — BATCHED ──
    try {
      // Spaces that have trip dates set
      const { data: spaceDates } = await supabase
        .from("spaces")
        .select("id, title")
        .in("id", memberGroupIds)
        .not("metadata->trip_start", "is", null);

      if (spaceDates && spaceDates.length > 0) {
        const datedGroupIds = spaceDates.map((s) => s.id);

        // ONE query for all hotel items — no N+1
        const { data: hotelItems } = await supabase
          .from("decision_items")
          .select("group_id")
          .in("group_id", datedGroupIds)
          .eq("category", "hotel");

        const spacesWithHotels = new Set(
          (hotelItems ?? []).map((i) => i.group_id)
        );

        for (const space of spaceDates) {
          if (!spacesWithHotels.has(space.id)) {
            whispers.push({
              id: `missing_category_hotel_${space.id}`,
              priority: 1,
              ghostText: `${space.title} has dates but no hotel. want me to find options?`,
              groupId: space.id,
              spaceTitle: space.title,
              type: "missing_category",
            });
          }
        }
      }
    } catch {
      // Graceful degradation
    }

    // ── Check 4 (P2): Items the user hasn't voted on ──
    try {
      // All active (unlocked) items in user's spaces
      const { data: allItems } = await supabase
        .from("decision_items")
        .select("id, title, group_id")
        .in("group_id", memberGroupIds)
        .eq("is_locked", false);

      if (allItems && allItems.length > 0) {
        const allItemIds = allItems.map((i) => i.id);

        // Items the user has already reacted to
        const { data: userReactions } = await supabase
          .from("reactions")
          .select("item_id")
          .eq("user_id", userId)
          .in("item_id", allItemIds);

        const votedItemIds = new Set(
          (userReactions ?? []).map((r) => r.item_id)
        );

        const unvotedItems = allItems.filter(
          (item) => !votedItemIds.has(item.id)
        );

        if (unvotedItems.length >= 3) {
          // Group by space and emit one whisper for the space with the most unvoted items
          const unvotedBySpace = new Map<
            string,
            { count: number; spaceTitle: string }
          >();

          for (const item of unvotedItems) {
            const existing = unvotedBySpace.get(item.group_id);
            if (existing) {
              existing.count++;
            } else {
              unvotedBySpace.set(item.group_id, {
                count: 1,
                spaceTitle: spaceTitleById.get(item.group_id) ?? "",
              });
            }
          }

          // Pick the space with the most unvoted items
          let topGroupId = "";
          let topCount = 0;
          let topTitle = "";

          for (const [groupId, { count, spaceTitle }] of unvotedBySpace) {
            if (count > topCount) {
              topCount = count;
              topGroupId = groupId;
              topTitle = spaceTitle;
            }
          }

          if (topGroupId) {
            whispers.push({
              id: `nudge_vote_${topGroupId}_${userId}`,
              priority: 2,
              ghostText: `${topCount} card${topCount === 1 ? "" : "s"} waiting for your vote in ${topTitle}.`,
              groupId: topGroupId,
              spaceTitle: topTitle,
              type: "nudge_vote",
            });
          }
        }
      }
    } catch {
      // Graceful degradation
    }

    // ── Check 5 (P1): Dates set + destination but no itinerary ──
    try {
      const { data: spaces } = await supabase
        .from("space_members")
        .select("group_id, spaces!inner(title)")
        .eq("user_id", userId);

      if (spaces && spaces.length > 0) {
        for (const membership of spaces) {
          const groupId = membership.group_id;
          const title = (membership as any).spaces?.title || "";

          // Check if dates exist
          const { data: dates } = await supabase
            .from("space_dates")
            .select("start_date, end_date")
            .eq("group_id", groupId)
            .maybeSingle();

          if (dates?.start_date && dates?.end_date) {
            // Check if recommendation items exist
            const { count } = await supabase
              .from("decision_items")
              .select("id", { count: "exact", head: true })
              .eq("group_id", groupId)
              .eq("category", "recommendation");

            if ((count ?? 0) === 0) {
              // Dates set but no itinerary — suggest building one
              whispers.push({
                id: `itinerary_ready_${groupId}`,
                priority: 1,
                ghostText: `dates are locked for ${title}. building your plan...`,
                groupId,
                spaceTitle: title,
                type: "itinerary_ready",
              });
              break; // Max 1 itinerary whisper
            }
          }
        }
      }
    } catch {
      // Graceful degradation
    }

    // ── Check 6 (P0): Split vote — consensus conflict ──
    try {
      const { data: spaces } = await supabase
        .from("space_members")
        .select("group_id, spaces!inner(title)")
        .eq("user_id", userId);

      if (spaces && spaces.length > 0) {
        for (const membership of spaces) {
          const groupId = membership.group_id;
          const title = (membership as any).spaces?.title || "";

          // Find items with split votes (>=25% NotForMe)
          const { data: items } = await supabase
            .from("decision_items")
            .select("id, title, metadata")
            .eq("group_id", groupId)
            .eq("state", "proposed");

          if (items && items.length > 0) {
            for (const item of items) {
              const { data: reactions } = await supabase
                .from("reactions")
                .select("reaction_type")
                .eq("item_id", item.id);

              if (reactions && reactions.length >= 3) {
                const notForMe = reactions.filter((r: any) => r.reaction_type === "not_for_me").length;
                if (notForMe / reactions.length >= 0.25) {
                  whispers.push({
                    id: `consensus_split_${item.id}`,
                    priority: 0,
                    ghostText: `looks like you're split on ${item.title}. want me to find a compromise?`,
                    groupId,
                    spaceTitle: title,
                    type: "consensus_split",
                    itemId: item.id,
                  });
                  break; // Max 1 split whisper per check
                }
              }
            }
          }
        }
      }
    } catch {
      // Graceful degradation
    }
  } catch {
    // Outer guard — return whatever was collected before the error
  }

  // Throttle: max 2 whispers total (prevents notification spam)
  return sortByPriority(whispers).slice(0, 2);
}

// ── Helpers ──

function sortByPriority(whispers: Whisper[]): Whisper[] {
  return [...whispers].sort((a, b) => a.priority - b.priority);
}
