// XARK OS v2.0 — AWARENESS STREAM
// Aggregates cross-space activity into a priority-sorted stream.
// The home screen renders this. Position = priority. Opacity = urgency.

import { supabase } from "./supabase";

// ── Types ──

export type AwarenessKind =
  | "needs_vote"
  | "needs_flight"
  | "proposal"
  | "locked"
  | "joined"
  | "ignited"
  | "assigned";

export interface AwarenessEvent {
  id: string;
  kind: AwarenessKind;
  spaceId: string;
  spaceTitle: string;
  text: string;
  actorName: string;
  timestamp: number;
  priority: number;
  itemTitle?: string;
}

// ── Priority Weights ──

const PRIORITY_WEIGHTS: Record<AwarenessKind, number> = {
  needs_vote: 0.95,
  needs_flight: 0.90,
  ignited: 0.90,
  proposal: 0.75,
  assigned: 0.70,
  locked: 0.40,
  joined: 0.30,
};

// ── Time Decay ──

function timeDecay(timestamp: number): number {
  const hoursAgo = (Date.now() - timestamp) / 3_600_000;
  return Math.max(0.1, Math.exp(-0.115 * hoursAgo));
}

// ── Score ──

export function scoreEvent(event: AwarenessEvent): number {
  const base = PRIORITY_WEIGHTS[event.kind] ?? 0.5;
  const decay = timeDecay(event.timestamp);
  return Math.min(1, base * decay);
}

// ── Sort ──

export function sortAwareness(events: AwarenessEvent[]): AwarenessEvent[] {
  return [...events]
    .map((e) => ({ ...e, priority: scoreEvent(e) }))
    .sort((a, b) => b.priority - a.priority);
}

// ── Opacity from priority ──

export function awarenessOpacity(priority: number): number {
  if (priority > 0.8) return 0.9;
  if (priority > 0.6) return 0.7;
  if (priority > 0.4) return 0.5;
  if (priority > 0.2) return 0.35;
  return 0.25;
}

// ── Whisper Text Generators ──

function whisperText(kind: AwarenessKind, actorName: string, itemTitle?: string, spaceTitle?: string): string {
  switch (kind) {
    case "needs_vote":
      return `${itemTitle ?? "something"} needs your vote`;
    case "needs_flight":
      return `you still need a flight`;
    case "ignited":
      return `the group is leaning toward ${itemTitle ?? "a decision"}`;
    case "proposal":
      return `${actorName} proposed ${itemTitle ?? "something new"}`;
    case "assigned":
      return `${itemTitle ?? "a task"} was assigned to ${actorName}`;
    case "locked":
      return `${itemTitle ?? "a decision"} is locked`;
    case "joined":
      return `${actorName} joined ${spaceTitle ?? "a space"}`;
  }
}

// ── Fetch from Supabase ──

export async function fetchAwareness(userId: string): Promise<AwarenessEvent[]> {
  const events: AwarenessEvent[] = [];

  try {
    // Get spaces the user belongs to via space_members
    const { data: memberRows } = await supabase
      .from("space_members")
      .select("space_id")
      .eq("user_id", userId);

    const memberSpaceIds = memberRows?.map((r) => r.space_id) ?? [];

    // Fetch space details — filter to user's spaces, exclude sanctuaries (private 1:1)
    const spacesQuery = supabase
      .from("spaces")
      .select("id, title, atmosphere")
      .neq("atmosphere", "sanctuary")
      .order("last_activity_at", { ascending: false, nullsFirst: false });

    if (memberSpaceIds.length > 0) {
      spacesQuery.in("id", memberSpaceIds);
    }

    const { data: spaces } = await spacesQuery;

    if (!spaces || spaces.length === 0) return [];

    const spaceMap = new Map(spaces.map((s) => [s.id, s.title]));
    const spaceIds = spaces.map((s) => s.id);

    const { data: items } = await supabase
      .from("decision_items")
      .select("id, title, space_id, state, agreement_score, is_locked, proposed_by, created_at, locked_at, ownership")
      .in("space_id", spaceIds);

    if (items) {
      for (const item of items) {
        const spaceTitle = spaceMap.get(item.space_id) ?? "";
        const ts = item.created_at ? new Date(item.created_at).getTime() : Date.now();

        if (item.is_locked) {
          events.push({
            id: `locked_${item.id}`,
            kind: "locked",
            spaceId: item.space_id,
            spaceTitle,
            text: whisperText("locked", "", item.title, spaceTitle),
            actorName: item.ownership?.ownerId?.replace(/^name_/, "") ?? "",
            timestamp: item.locked_at ? new Date(item.locked_at).getTime() : ts,
            priority: 0,
            itemTitle: item.title,
          });
          continue;
        }

        // TODO: also exclude items the user has already reacted to
        if (item.proposed_by !== userId) {
          events.push({
            id: `vote_${item.id}`,
            kind: "needs_vote",
            spaceId: item.space_id,
            spaceTitle,
            text: whisperText("needs_vote", "", item.title, spaceTitle),
            actorName: item.proposed_by?.replace(/^name_/, "") ?? "",
            timestamp: ts,
            priority: 0,
            itemTitle: item.title,
          });
        }

        if ((item.agreement_score ?? 0) > 0.8) {
          events.push({
            id: `ignited_${item.id}`,
            kind: "ignited",
            spaceId: item.space_id,
            spaceTitle,
            text: whisperText("ignited", "", item.title, spaceTitle),
            actorName: "",
            timestamp: ts,
            priority: 0,
            itemTitle: item.title,
          });
        }
      }
    }

    // ── needs_flight events from member_logistics ──
    try {
      const { data: logistics } = await supabase
        .from("member_logistics")
        .select("space_id, user_id, origin, destination, state, item_id")
        .in("space_id", spaceIds)
        .eq("user_id", userId)
        .eq("state", "missing")
        .not("origin", "is", null);

      if (logistics) {
        for (const row of logistics) {
          // Only surface if origin is known but no item linked yet
          if (row.origin && !row.item_id) {
            const spaceTitle = spaceMap.get(row.space_id) ?? "";
            events.push({
              id: `flight_${row.space_id}_${row.user_id}`,
              kind: "needs_flight",
              spaceId: row.space_id,
              spaceTitle,
              text: whisperText("needs_flight", "", undefined, spaceTitle),
              actorName: "",
              timestamp: Date.now(), // always fresh — this is current state
              priority: 0,
            });
          }
        }
      }
    } catch {
      // member_logistics table may not exist yet — silent fallback
    }

    // No "said something" events — home screen shows actionable state only.
    // Sanctuaries are excluded above. Messages are not awareness events.

    return sortAwareness(events);
  } catch {
    return getDemoAwareness();
  }
}

// ── Demo Awareness ──

export function getDemoAwareness(): AwarenessEvent[] {
  const now = Date.now();
  const raw: Omit<AwarenessEvent, "priority">[] = [
    {
      id: "aw_1",
      kind: "needs_vote",
      spaceId: "space_san-diego-trip",
      spaceTitle: "san diego trip",
      text: "surf lessons needs your vote",
      actorName: "ananya",
      timestamp: now - 1_800_000,
      itemTitle: "surf lessons at la jolla",
    },
    {
      id: "aw_2",
      kind: "locked",
      spaceId: "space_san-diego-trip",
      spaceTitle: "san diego trip",
      text: "hotel del coronado is locked",
      actorName: "ram",
      timestamp: now - 3_600_000,
      itemTitle: "hotel del coronado",
    },
    {
      id: "aw_3",
      kind: "needs_flight",
      spaceId: "space_san-diego-trip",
      spaceTitle: "san diego trip",
      text: "you still need a flight",
      actorName: "",
      timestamp: now - 7_200_000,
    },
    {
      id: "aw_4",
      kind: "needs_vote",
      spaceId: "space_tokyo-neon-nights",
      spaceTitle: "tokyo neon nights",
      text: "shibuya crossing tour needs your vote",
      actorName: "maya",
      timestamp: now - 259_200_000,
      itemTitle: "shibuya crossing tour",
    },
    {
      id: "aw_5",
      kind: "proposal",
      spaceId: "space_tokyo-neon-nights",
      spaceTitle: "tokyo neon nights",
      text: "jake proposed teamlab borderless",
      actorName: "jake",
      timestamp: now - 345_600_000,
      itemTitle: "teamlab borderless",
    },
  ];
  return sortAwareness(raw.map((e) => ({ ...e, priority: 0 })));
}

export const DEMO_AWARENESS = getDemoAwareness();
