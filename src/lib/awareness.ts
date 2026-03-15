// XARK OS v2.0 — AWARENESS STREAM
// Space-level consensus summaries for the home screen.
// One entry per space. Aggregates decision state into a single summary.
// "What do I need to know right now?" — usually nothing. Peace.

import { supabase } from "./supabase";

// ── Types ──

export interface SpaceAwareness {
  spaceId: string;
  spaceTitle: string;
  locked: number;
  needsVote: number;
  exploring: number;
  total: number;
  needsFlight: boolean;
  actionNeeded: boolean;
  lastActivityAt: number;
  priority: number;
}

// ── Summary Text ──

export function summaryText(space: SpaceAwareness): string {
  const parts: string[] = [];

  if (space.needsFlight) parts.push("you still need a flight");
  if (space.needsVote > 0) parts.push(`${space.needsVote} need${space.needsVote === 1 ? "s" : ""} your vote`);
  if (space.locked > 0) parts.push(`${space.locked} locked`);
  if (space.exploring > 0) parts.push(`${space.exploring} exploring`);

  if (parts.length === 0) {
    if (space.total === 0) return "no decisions yet";
    return "all good";
  }

  return parts.join(" · ");
}

// ── Priority Score ──

function scoreSummary(space: SpaceAwareness): number {
  // Action-needed spaces float up. Peaceful ones sink.
  let base = 0.2;
  if (space.needsFlight) base = Math.max(base, 0.9);
  if (space.needsVote > 0) base = Math.max(base, 0.85);
  if (space.exploring > 0) base = Math.max(base, 0.5);
  if (space.locked > 0 && space.needsVote === 0) base = Math.max(base, 0.35);

  // Time decay — recent activity = higher priority
  const hoursAgo = (Date.now() - space.lastActivityAt) / 3_600_000;
  const decay = Math.max(0.3, Math.exp(-0.05 * hoursAgo));

  return Math.min(1, base * decay);
}

// ── Opacity from priority ──

export function awarenessOpacity(priority: number): number {
  if (priority > 0.8) return 0.9;
  if (priority > 0.6) return 0.7;
  if (priority > 0.4) return 0.5;
  if (priority > 0.2) return 0.35;
  return 0.25;
}

// ── Fetch from Supabase ──

export async function fetchAwareness(userId: string): Promise<SpaceAwareness[]> {
  try {
    // Get spaces the user belongs to
    const { data: memberRows } = await supabase
      .from("space_members")
      .select("space_id")
      .eq("user_id", userId);

    const memberSpaceIds = memberRows?.map((r) => r.space_id) ?? [];

    // Fetch spaces — exclude sanctuaries
    const spacesQuery = supabase
      .from("spaces")
      .select("id, title, atmosphere, last_activity_at, created_at")
      .neq("atmosphere", "sanctuary")
      .order("last_activity_at", { ascending: false, nullsFirst: false });

    if (memberSpaceIds.length === 0) return [];
    spacesQuery.in("id", memberSpaceIds);

    const { data: spaces } = await spacesQuery;

    if (!spaces || spaces.length === 0) return [];

    const spaceIds = spaces.map((s) => s.id);

    // Fetch decision items + logistics in parallel
    const [itemsResult, logisticsResult] = await Promise.all([
      supabase
        .from("decision_items")
        .select("id, space_id, state, is_locked, proposed_by")
        .in("space_id", spaceIds),
      Promise.resolve(
        supabase
          .from("member_logistics")
          .select("space_id")
          .in("space_id", spaceIds)
          .eq("user_id", userId)
          .eq("state", "missing")
          .not("origin", "is", null)
      ).catch(() => ({ data: null as null })),
    ]);

    const items = itemsResult.data;

    let flightSpaceIds: Set<string> = new Set();
    if (logisticsResult.data) {
      for (const row of logisticsResult.data) {
        flightSpaceIds.add(row.space_id);
      }
    }

    // Aggregate per space
    const summaries: SpaceAwareness[] = spaces.map((space) => {
      const spaceItems = items?.filter((i) => i.space_id === space.id) ?? [];

      let locked = 0;
      let needsVote = 0;
      let exploring = 0;

      for (const item of spaceItems) {
        if (item.is_locked) {
          locked++;
        } else if (item.proposed_by !== userId) {
          needsVote++;
        } else {
          exploring++;
        }
      }

      const needsFlight = flightSpaceIds.has(space.id);
      const actionNeeded = needsVote > 0 || needsFlight;
      const lastActivityAt = new Date(space.last_activity_at ?? space.created_at).getTime();

      return {
        spaceId: space.id,
        spaceTitle: space.title,
        locked,
        needsVote,
        exploring,
        total: spaceItems.length,
        needsFlight,
        actionNeeded,
        lastActivityAt,
        priority: 0,
      };
    });

    // Score and sort — action-needed spaces first
    return summaries
      .map((s) => ({ ...s, priority: scoreSummary(s) }))
      .sort((a, b) => b.priority - a.priority);
  } catch {
    return getDemoAwareness();
  }
}

// ── Demo Awareness ──

export function getDemoAwareness(): SpaceAwareness[] {
  const now = Date.now();
  const raw: SpaceAwareness[] = [
    {
      spaceId: "space_san-diego-trip",
      spaceTitle: "san diego trip",
      locked: 2,
      needsVote: 1,
      exploring: 1,
      total: 4,
      needsFlight: true,
      actionNeeded: true,
      lastActivityAt: now - 1_800_000,
      priority: 0,
    },
    {
      spaceId: "space_tokyo-neon-nights",
      spaceTitle: "tokyo neon nights",
      locked: 0,
      needsVote: 2,
      exploring: 0,
      total: 2,
      needsFlight: false,
      actionNeeded: true,
      lastActivityAt: now - 259_200_000,
      priority: 0,
    },
    {
      spaceId: "space_summer-2026",
      spaceTitle: "summer 2026",
      locked: 0,
      needsVote: 0,
      exploring: 0,
      total: 0,
      needsFlight: false,
      actionNeeded: false,
      lastActivityAt: now - 1_209_600_000,
      priority: 0,
    },
  ];

  return raw
    .map((s) => ({ ...s, priority: scoreSummary(s) }))
    .sort((a, b) => b.priority - a.priority);
}

export const DEMO_AWARENESS = getDemoAwareness();

// ── Personal Chats (Sanctuary spaces / 1:1) ──

export interface PersonalChat {
  spaceId: string;
  contactName: string;
  lastMessage: string;
  lastActivityAt: number;
}

export async function fetchPersonalChats(userId: string): Promise<PersonalChat[]> {
  try {
    // Get spaces the user belongs to
    const { data: memberRows } = await supabase
      .from("space_members")
      .select("space_id")
      .eq("user_id", userId);

    const memberSpaceIds = memberRows?.map((r) => r.space_id) ?? [];
    if (memberSpaceIds.length === 0) return [];

    // Fetch sanctuary spaces
    const { data: sanctuaries } = await supabase
      .from("spaces")
      .select("id, title, last_activity_at, created_at")
      .eq("atmosphere", "sanctuary")
      .in("id", memberSpaceIds);

    if (!sanctuaries || sanctuaries.length === 0) return [];

    const sanctuaryIds = sanctuaries.map((s) => s.id);

    // Fetch last message per sanctuary via RPC (single query with DISTINCT ON)
    const lastMessageBySpace = new Map<string, { content: string; senderName: string; createdAt: string }>();
    try {
      const { data: latestMsgs } = await supabase.rpc("get_latest_messages_per_space", {
        p_space_ids: sanctuaryIds,
      });
      if (latestMsgs) {
        for (const msg of latestMsgs) {
          lastMessageBySpace.set(msg.space_id, {
            content: msg.content,
            senderName: msg.sender_name ?? "",
            createdAt: msg.created_at,
          });
        }
      }
    } catch {
      // Fallback: RPC may not exist yet
    }

    // Resolve contact name: other member in the sanctuary
    const { data: allMembers } = await supabase
      .from("space_members")
      .select("space_id, user_id")
      .in("space_id", sanctuaryIds);

    const contactBySpace = new Map<string, string>();
    for (const member of allMembers ?? []) {
      if (member.user_id !== userId) {
        contactBySpace.set(member.space_id, member.user_id.replace(/^name_/, ""));
      }
    }

    return sanctuaries.map((space) => {
      const lastMsg = lastMessageBySpace.get(space.id);
      const contactName = contactBySpace.get(space.id) ?? space.title;

      return {
        spaceId: space.id,
        contactName,
        lastMessage: lastMsg?.content ?? "",
        lastActivityAt: lastMsg
          ? new Date(lastMsg.createdAt).getTime()
          : new Date(space.last_activity_at ?? space.created_at).getTime(),
      };
    }).sort((a, b) => b.lastActivityAt - a.lastActivityAt);
  } catch {
    return getDemoPersonalChats();
  }
}

export function getDemoPersonalChats(): PersonalChat[] {
  const now = Date.now();
  return [
    {
      spaceId: "space_ananya",
      contactName: "ananya",
      lastMessage: "sent you the photos from saturday",
      lastActivityAt: now - 3_600_000,
    },
  ];
}
