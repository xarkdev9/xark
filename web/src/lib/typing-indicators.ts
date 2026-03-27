/// Ephemeral typing indicators via Supabase Realtime Broadcast.
/// Auto-clear after 5 seconds. Never hits the database.

import { supabase } from './supabase';

interface TypingState {
  userId: string;
  timestamp: number;
}

const typingState = new Map<string, Map<string, number>>(); // groupId -> userId -> timestamp
const clearTimers = new Map<string, ReturnType<typeof setTimeout>>();
const AUTO_CLEAR_MS = 5000;
const DEBOUNCE_MS = 3000;
let lastSentAt = 0;

const listeners = new Set<(groupId: string, typingUsers: string[]) => void>();

export function onTypingChange(cb: (groupId: string, typingUsers: string[]) => void): () => void {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

function notify(groupId: string) {
  const users = getTypingUsers(groupId);
  for (const cb of listeners) cb(groupId, users);
}

export function getTypingUsers(groupId: string): string[] {
  const group = typingState.get(groupId);
  if (!group) return [];
  const now = Date.now();
  return Array.from(group.entries())
    .filter(([, ts]) => now - ts < AUTO_CLEAR_MS)
    .map(([userId]) => userId);
}

export function handleRemoteTyping(groupId: string, userId: string): void {
  if (!typingState.has(groupId)) typingState.set(groupId, new Map());
  typingState.get(groupId)!.set(userId, Date.now());
  notify(groupId);

  // Auto-clear
  const key = `${groupId}:${userId}`;
  if (clearTimers.has(key)) clearTimeout(clearTimers.get(key)!);
  clearTimers.set(key, setTimeout(() => {
    typingState.get(groupId)?.delete(userId);
    notify(groupId);
    clearTimers.delete(key);
  }, AUTO_CLEAR_MS));
}

export async function sendTyping(groupId: string): Promise<void> {
  const now = Date.now();
  if (now - lastSentAt < DEBOUNCE_MS) return; // Debounce
  lastSentAt = now;

  const channel = supabase.channel(`typing:${groupId}`);
  await channel.send({
    type: 'broadcast',
    event: 'typing',
    payload: { timestamp: now },
  });
}

export function subscribeToTyping(groupId: string, currentUserId: string): () => void {
  const channel = supabase.channel(`typing:${groupId}`);
  channel
    .on('broadcast', { event: 'typing' }, (payload: any) => {
      const senderId = payload.payload?.userId;
      if (senderId && senderId !== currentUserId) {
        handleRemoteTyping(groupId, senderId);
      }
    })
    .subscribe();

  return () => channel.unsubscribe();
}
