// hello OS v2.0 — Unread Message Counts (Read Watermarks)
// Sequence-based unread tracking via read_watermarks table.
// No concurrent UPDATE deadlock — GREATEST ensures monotonic watermark advancement.

import { supabase } from './supabase';

/** Get unread message count for a specific group */
export async function getUnreadCount(groupId: string, userId: string): Promise<number> {
  const { data: wm } = await supabase
    .from('read_watermarks')
    .select('last_read_seq')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .single();

  const lastReadSeq = wm?.last_read_seq ?? 0;

  const { count } = await supabase
    .from('messages')
    .select('*', { count: 'exact', head: true })
    .eq('group_id', groupId)
    .gt('server_seq', lastReadSeq)
    .neq('user_id', userId);

  return count ?? 0;
}

/** Fetch unread counts for multiple groups (used by AwarenessStream, PeopleDock) */
export async function fetchUnreadCounts(
  groupIds: string[],
  userId: string,
): Promise<Record<string, number>> {
  const counts: Record<string, number> = {};
  // Batch: fetch all watermarks for this user
  const { data: watermarks } = await supabase
    .from('read_watermarks')
    .select('group_id, last_read_seq')
    .eq('user_id', userId)
    .in('group_id', groupIds);

  const wmMap = new Map((watermarks ?? []).map((w) => [w.group_id, w.last_read_seq ?? 0]));

  // Count unread per group
  for (const groupId of groupIds) {
    const lastReadSeq = wmMap.get(groupId) ?? 0;
    const { count } = await supabase
      .from('messages')
      .select('*', { count: 'exact', head: true })
      .eq('group_id', groupId)
      .gt('server_seq', lastReadSeq)
      .neq('user_id', userId);
    counts[groupId] = count ?? 0;
  }
  return counts;
}

/** Mark a group as read up to the given sequence number */
export async function markGroupRead(groupId: string, seq: number): Promise<void> {
  await supabase.rpc('mark_group_read', { p_group_id: groupId, p_seq: seq });
}
