// XARK OS v2.0 — Unread Message Counts
// Tracks last_read_at per user per space via Supabase RPCs.

import { supabase } from "./supabase";

export interface UnreadCount {
  space_id: string;
  unread_count: number;
}

/** Fetch unread counts for all spaces the current user belongs to */
export async function fetchUnreadCounts(): Promise<Record<string, number>> {
  try {
    const { data, error } = await supabase.rpc("get_unread_counts");
    if (error || !data) return {};
    const result: Record<string, number> = {};
    for (const row of data as UnreadCount[]) {
      if (row.unread_count > 0) {
        result[row.space_id] = row.unread_count;
      }
    }
    return result;
  } catch {
    return {};
  }
}

/** Mark a space as read (sets last_read_at to now) */
export async function markSpaceRead(spaceId: string): Promise<void> {
  try {
    await supabase.rpc("mark_space_read", { p_space_id: spaceId });
  } catch {
    // Silent — best effort
  }
}
