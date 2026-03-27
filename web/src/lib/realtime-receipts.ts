// hello OS v2.0 — Ephemeral Delivery/Read Receipts (crypto.md #33)
// Receipts flow exclusively through Supabase Realtime Broadcast.
// Never written to the database — prevents millions of receipt rows.
// If the recipient is offline, receipts are lost (the app reconciles
// on next sync via message status).

import { supabase } from './supabase';

/**
 * An ephemeral delivery or read receipt.
 * Transient — exists only in Realtime broadcast, never persisted.
 */
export interface Receipt {
  messageId: string;
  userId: string;
  deviceId: number;
  type: 'delivered' | 'read';
  timestamp: number;
}

/** Active receipt channels keyed by channel name */
const receiptChannels = new Map<string, ReturnType<typeof supabase.channel>>();

/**
 * Subscribe to receipts for a group.
 * Returns an unsubscribe function — call on unmount / group leave.
 */
export function subscribeToReceipts(
  groupId: string,
  onReceipt: (receipt: Receipt) => void,
): () => void {
  const channelName = `receipts:${groupId}`;

  if (receiptChannels.has(channelName)) {
    // Already subscribed — no-op unsubscribe to prevent double-cleanup
    return () => {};
  }

  const channel = supabase.channel(channelName);

  channel
    .on('broadcast', { event: 'receipt' }, (payload: { payload: Receipt }) => {
      onReceipt(payload.payload);
    })
    .subscribe();

  receiptChannels.set(channelName, channel);

  return () => {
    channel.unsubscribe();
    receiptChannels.delete(channelName);
  };
}

/**
 * Ensure a receipt channel exists and is subscribed.
 * Reuses existing channels to avoid redundant subscriptions.
 */
async function ensureReceiptChannel(
  groupId: string,
): Promise<ReturnType<typeof supabase.channel>> {
  const channelName = `receipts:${groupId}`;
  let channel = receiptChannels.get(channelName);

  if (!channel) {
    channel = supabase.channel(channelName);
    await channel.subscribe();
    receiptChannels.set(channelName, channel);
  }

  return channel;
}

/**
 * Send a delivery receipt (ephemeral — broadcast only, no DB write).
 * Fire-and-forget: failures are logged but never surfaced to the caller.
 */
export async function sendDeliveredReceipt(
  groupId: string,
  messageId: string,
  userId: string,
  deviceId: number,
): Promise<void> {
  try {
    const channel = await ensureReceiptChannel(groupId);

    await channel.send({
      type: 'broadcast',
      event: 'receipt',
      payload: {
        messageId,
        userId,
        deviceId,
        type: 'delivered',
        timestamp: Date.now(),
      } satisfies Receipt,
    });
  } catch (err) {
    console.warn('[hello-receipts] Failed to send delivered receipt:', err);
  }
}

/**
 * Send a read receipt (ephemeral — broadcast only, no DB write).
 * Fire-and-forget: failures are logged but never surfaced to the caller.
 */
export async function sendReadReceipt(
  groupId: string,
  messageId: string,
  userId: string,
  deviceId: number,
): Promise<void> {
  try {
    const channel = await ensureReceiptChannel(groupId);

    await channel.send({
      type: 'broadcast',
      event: 'receipt',
      payload: {
        messageId,
        userId,
        deviceId,
        type: 'read',
        timestamp: Date.now(),
      } satisfies Receipt,
    });
  } catch (err) {
    console.warn('[hello-receipts] Failed to send read receipt:', err);
  }
}

/**
 * Tear down all active receipt channels.
 * Call on logout / app teardown.
 */
export function cleanupAllReceiptChannels(): void {
  for (const [name, channel] of receiptChannels) {
    channel.unsubscribe();
    receiptChannels.delete(name);
  }
}
