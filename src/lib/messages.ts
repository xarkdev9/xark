// XARK OS v2.0 — MESSAGE PERSISTENCE
// Supabase Postgres for chat message storage.
// Supabase Realtime for live multi-user sync.
// Graceful fallback: returns empty / no-ops when Supabase is unreachable.

import { supabase } from "./supabase";
import type { RealtimeChannel } from "@supabase/supabase-js";

export interface ChatMessage {
  id: string;
  space_id: string;
  role: "user" | "xark" | "system";
  content: string;
  user_id: string | null;
  sender_name: string | null;
  created_at: string;
}

// ── Fetch all messages for a space, ordered by creation time ──
export async function fetchMessages(spaceId: string): Promise<ChatMessage[]> {
  const { data, error } = await supabase
    .from("messages")
    .select("id, space_id, role, content, user_id, sender_name, created_at")
    .eq("space_id", spaceId)
    .order("created_at", { ascending: true });

  if (error || !data) return [];
  return data as ChatMessage[];
}

// ── Persist a single message ──
export async function saveMessage(msg: {
  id: string;
  spaceId: string;
  role: "user" | "xark";
  content: string;
  userId?: string;
  senderName?: string;
}): Promise<void> {
  await supabase.from("messages").insert({
    id: msg.id,
    space_id: msg.spaceId,
    role: msg.role,
    content: msg.content,
    user_id: msg.userId ?? null,
    sender_name: msg.senderName ?? null,
  });
}

// ── Subscribe to new messages via Supabase Realtime ──
export function subscribeToMessages(
  spaceId: string,
  onMessage: (msg: ChatMessage) => void
): RealtimeChannel {
  const channel = supabase
    .channel(`messages:${spaceId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "messages",
        filter: `space_id=eq.${spaceId}`,
      },
      (payload) => {
        onMessage(payload.new as ChatMessage);
      }
    )
    .subscribe();

  return channel;
}

// ── Unsubscribe cleanup ──
export function unsubscribeFromMessages(channel: RealtimeChannel): void {
  supabase.removeChannel(channel);
}

// ── System messages — via SECURITY DEFINER RPC (RLS blocks role='system') ──

export async function saveSystemMessage(spaceId: string, content: string): Promise<void> {
  try {
    await supabase.rpc("insert_system_message", {
      p_space_id: spaceId,
      p_content: content,
    });
  } catch {
    // Silent fail — system messages are informational, not critical
  }
}

// Preset system messages
export const systemMessages = {
  itemLocked: (title: string) =>
    `${title} is locked. waiting for someone to own it.`,
  itemClaimed: (name: string, title: string) =>
    `${name} claimed ${title}`,
  itemPurchased: (name: string, title: string, amount: string) =>
    `${name} booked ${title} for ${amount}`,
  memberJoined: (name: string) =>
    `${name} joined the space`,
};
