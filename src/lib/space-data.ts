// XARK OS v2.0 — SPACE DATA LAYER
// Unified data for Galaxy + ControlCaret. Demo fallback when Supabase is unreachable.

import { supabase } from "./supabase";

// ── Types ───────────────────────────────────────────────────────────────────

export interface SpaceMember {
  id: string;
  displayName: string;
  photoUrl?: string;
}

export interface DecisionSummary {
  locked: number;
  needsVote: number;
  exploring: number;
  total: number;
}

export interface SpaceListItem {
  id: string;
  title: string;
  atmosphere: string;
  members: SpaceMember[];
  decisionSummary: DecisionSummary;
  lastMessage?: { content: string; senderName?: string };
  lastActivityAt: Date;
}

// ── Recency helpers ─────────────────────────────────────────────────────────

export function recencyLabel(date: Date): string {
  const diff = Date.now() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "yesterday";
  if (days < 7) return `${days} days`;
  const weeks = Math.floor(days / 7);
  return `${weeks}w ago`;
}

export function recencyOpacity(date: Date): number {
  const diff = Date.now() - date.getTime();
  const hours = diff / 3600000;
  if (hours < 1) return 0.9;
  if (hours < 24) return 0.7;
  if (hours < 168) return 0.5; // 7 days
  return 0.4;
}

export function decisionStateLabel(summary: DecisionSummary): string {
  const parts: string[] = [];
  if (summary.locked > 0) parts.push(`${summary.locked} locked`);
  if (summary.needsVote > 0) parts.push(`${summary.needsVote} needs your vote`);
  if (summary.exploring > 0) parts.push(`${summary.exploring} exploring`);
  if (parts.length === 0 && summary.total === 0) return "empty — start dreaming";
  if (parts.length === 0) return `${summary.total} ideas`;
  return parts.join(" · ");
}

// ── Demo Data ───────────────────────────────────────────────────────────────

const DEMO_SPACES: SpaceListItem[] = [
  {
    id: "space_san-diego-trip",
    title: "san diego trip",
    atmosphere: "cyan_horizon",
    members: [
      { id: "u_maya", displayName: "maya" },
      { id: "u_jake", displayName: "jake" },
      { id: "u_ananya", displayName: "ananya" },
    ],
    decisionSummary: { locked: 2, needsVote: 1, exploring: 1, total: 4 },
    lastMessage: { content: "i proposed surf lessons at la jolla — check it out", senderName: "ananya" },
    lastActivityAt: new Date(Date.now() - 1800000), // 30 min ago
  },
  {
    id: "space_ananya",
    title: "ananya",
    atmosphere: "sanctuary",
    members: [{ id: "u_ananya", displayName: "ananya" }],
    decisionSummary: { locked: 0, needsVote: 0, exploring: 0, total: 0 },
    lastMessage: { content: "did you see the surf lesson proposal?", senderName: "ananya" },
    lastActivityAt: new Date(Date.now() - 7200000), // 2 hours ago
  },
  {
    id: "space_tokyo-neon-nights",
    title: "tokyo neon nights",
    atmosphere: "amber_glow",
    members: [
      { id: "u_maya", displayName: "maya" },
      { id: "u_jake", displayName: "jake" },
    ],
    decisionSummary: { locked: 0, needsVote: 2, exploring: 0, total: 2 },
    lastMessage: undefined,
    lastActivityAt: new Date(Date.now() - 259200000), // 3 days ago
  },
  {
    id: "space_summer-2026",
    title: "summer 2026",
    atmosphere: "gold_warmth",
    members: [
      { id: "u_maya", displayName: "maya" },
      { id: "u_ananya", displayName: "ananya" },
      { id: "u_jake", displayName: "jake" },
    ],
    decisionSummary: { locked: 0, needsVote: 0, exploring: 0, total: 0 },
    lastMessage: undefined,
    lastActivityAt: new Date(Date.now() - 1209600000), // 2 weeks ago
  },
];

// ── Fetch ───────────────────────────────────────────────────────────────────

export async function fetchSpaceList(userId?: string): Promise<SpaceListItem[]> {
  try {
    // If userId provided, filter to user's spaces via space_members
    let spaceIds: string[] | null = null;
    if (userId) {
      const { data: memberRows } = await supabase
        .from("space_members")
        .select("space_id")
        .eq("user_id", userId);
      if (memberRows && memberRows.length > 0) {
        spaceIds = memberRows.map((r) => r.space_id);
      }
    }

    // Fetch spaces — filter to user's spaces if memberships found
    const spacesQuery = supabase
      .from("spaces")
      .select("id, title, atmosphere, last_activity_at, created_at")
      .order("last_activity_at", { ascending: false, nullsFirst: false });

    if (spaceIds) {
      spacesQuery.in("id", spaceIds);
    }

    const { data: spaces, error } = await spacesQuery;

    if (error || !spaces || spaces.length === 0) return DEMO_SPACES;

    // Batched queries — 4 queries instead of 60+ (N+1 fix)
    const allSpaceIds = spaces.map((s) => s.id);

    const [membersResult, itemsResult, messagesResult] = await Promise.all([
      supabase
        .from("space_members")
        .select("space_id, user_id")
        .in("space_id", allSpaceIds),
      supabase
        .from("decision_items")
        .select("space_id, state, is_locked")
        .in("space_id", allSpaceIds),
      Promise.resolve(
        supabase.rpc("get_latest_messages_per_space", {
          p_space_ids: allSpaceIds,
        })
      ).catch(() => ({ data: null as null })),
    ]);

    // Collect unique user IDs from members
    const membersBySpace = new Map<string, string[]>();
    const uniqueUserIds = new Set<string>();
    for (const row of membersResult.data ?? []) {
      const list = membersBySpace.get(row.space_id) ?? [];
      list.push(row.user_id);
      membersBySpace.set(row.space_id, list);
      uniqueUserIds.add(row.user_id);
    }

    // Fetch all user profiles in one query
    const userMap = new Map<string, { id: string; displayName: string; photoUrl?: string }>();
    if (uniqueUserIds.size > 0) {
      const { data: users } = await supabase
        .from("users")
        .select("id, display_name, photo_url")
        .in("id", Array.from(uniqueUserIds));
      for (const u of users ?? []) {
        userMap.set(u.id, {
          id: u.id,
          displayName: u.display_name ?? "unknown",
          photoUrl: u.photo_url ?? undefined,
        });
      }
    }

    // Build items-by-space map
    const itemsBySpace = new Map<string, Array<{ state: string; is_locked: boolean }>>();
    for (const item of itemsResult.data ?? []) {
      const list = itemsBySpace.get(item.space_id) ?? [];
      list.push(item);
      itemsBySpace.set(item.space_id, list);
    }

    // Build last-message-by-space map
    const lastMsgBySpace = new Map<string, { content: string; senderName?: string }>();
    for (const msg of messagesResult.data ?? []) {
      lastMsgBySpace.set(msg.space_id, {
        content: msg.content,
        senderName: msg.sender_name ?? undefined,
      });
    }

    // Assemble from in-memory maps
    const enriched: SpaceListItem[] = spaces.map((space) => {
      const memberIds = membersBySpace.get(space.id) ?? [];
      const members: SpaceMember[] = memberIds
        .map((uid) => userMap.get(uid))
        .filter((u): u is NonNullable<typeof u> => !!u);

      const spaceItems = itemsBySpace.get(space.id) ?? [];
      const summary: DecisionSummary = { locked: 0, needsVote: 0, exploring: 0, total: spaceItems.length };
      for (const item of spaceItems) {
        if (item.is_locked) summary.locked++;
        else if (item.state === "proposed") summary.exploring++;
        else summary.needsVote++;
      }

      return {
        id: space.id,
        title: space.title,
        atmosphere: space.atmosphere ?? "",
        members,
        decisionSummary: summary,
        lastMessage: lastMsgBySpace.get(space.id),
        lastActivityAt: new Date(space.last_activity_at ?? space.created_at),
      };
    });

    return enriched;
  } catch {
    return DEMO_SPACES;
  }
}

export { DEMO_SPACES };
