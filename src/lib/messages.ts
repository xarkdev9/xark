// XARK OS v2.0 — MESSAGE PERSISTENCE
// Supabase Postgres for chat message storage.
// Supabase Broadcast for instant delivery (~50ms). DB for durability.
// Graceful fallback: returns empty / no-ops when Supabase is unreachable.

import { supabase, hasSupabaseAuth } from "./supabase";
import type { RealtimeChannel } from "@supabase/supabase-js";

export type MessageType = 'e2ee' | 'e2ee_xark' | 'xark' | 'system' | 'legacy' | 'sender_key_dist';

export interface ChatMessage {
  id: string;
  space_id: string;
  role: "user" | "xark" | "system";
  content: string;
  user_id: string | null;
  sender_name: string | null;
  created_at: string;
  message_type?: MessageType;
  sender_device_id?: number | null;
  // E2EE broadcast fields — included for instant decrypt by recipients
  ciphertext_b64?: string;
  ratchet_header_b64?: string | null;
}

// ── Fetch messages for a space with pagination ──
export async function fetchMessages(
  spaceId: string,
  opts?: { limit?: number; before?: string }
): Promise<ChatMessage[]> {
  const limit = opts?.limit ?? 50;

  let query = supabase
    .from("messages")
    .select("id, space_id, role, content, user_id, sender_name, created_at, message_type, sender_device_id")
    .eq("space_id", spaceId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (opts?.before) {
    query = query.lt("created_at", opts.before);
  }

  const { data, error } = await query;

  if (error) {
    console.error("[xark] fetchMessages failed:", error.message, { spaceId });
    return [];
  }
  if (!data) return [];
  // Reverse to ascending order for display
  return (data as ChatMessage[]).reverse();
}

// ── Persist a single message ──
export async function saveMessage(msg: {
  id: string;
  spaceId: string;
  role: "user" | "xark";
  content: string;
  userId?: string;
  senderName?: string;
  messageType?: MessageType;
  senderDeviceId?: number;
}): Promise<void> {
  const hasJWT = hasSupabaseAuth();
  if (!hasJWT) {
    console.error("[xark] saveMessage: NO JWT on Supabase client! userId:", msg.userId);
  }
  const row: Record<string, unknown> = {
    id: msg.id,
    space_id: msg.spaceId,
    role: msg.role,
    content: msg.content,
    user_id: msg.userId ?? null,
    sender_name: msg.senderName ?? null,
  };
  // E2EE columns — only include when migration 014 has been applied
  if (msg.messageType && msg.messageType !== 'legacy') {
    row.content = msg.messageType === 'e2ee' || msg.messageType === 'e2ee_xark' ? null : msg.content;
    row.sender_name = msg.messageType === 'e2ee' || msg.messageType === 'e2ee_xark' ? null : (msg.senderName ?? null);
    row.message_type = msg.messageType;
    row.sender_device_id = msg.senderDeviceId ?? null;
  }
  const { error } = await supabase.from("messages").insert(row);
  if (error) {
    console.error("[xark] saveMessage failed:", error.message, { userId: msg.userId, spaceId: msg.spaceId, hasJWT });
    throw error;
  }
}

// ── Fetch ciphertexts for a message (client-side decryption) ──
export async function fetchCiphertexts(
  messageIds: string[],
  recipientDeviceId?: number  // BUG 7/8 fix: filter to exact device
): Promise<Array<{
  message_id: string;
  recipient_id: string;
  recipient_device_id: number;
  ciphertext: string;
  ratchet_header: string | null;
}>> {
  if (messageIds.length === 0) return [];

  let query = supabase
    .from("message_ciphertexts")
    .select("message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header")
    .in("message_id", messageIds);

  // BUG 7/8 fix: when device ID is known, filter server-side
  if (recipientDeviceId !== undefined) {
    query = query.eq("recipient_device_id", recipientDeviceId);
  }

  const { data, error } = await query;
  if (error) {
    console.error("[xark] fetchCiphertexts failed:", error.message);
    return [];
  }
  return data ?? [];
}

// ── Subscribe via Broadcast — instant WebSocket delivery, bypasses DB WAL ──
export function subscribeToMessages(
  spaceId: string,
  onMessage: (msg: ChatMessage) => void
): RealtimeChannel {
  const channel = supabase
    .channel(`chat:${spaceId}`, {
      config: { broadcast: { self: false } },
    })
    .on("broadcast", { event: "message" }, ({ payload }) => {
      onMessage(payload as ChatMessage);
    })
    .subscribe();

  return channel;
}

// ── Broadcast a message for instant delivery to other users ──
export function broadcastMessage(
  channel: RealtimeChannel,
  msg: ChatMessage
): void {
  channel.send({
    type: "broadcast",
    event: "message",
    payload: msg,
  });
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
