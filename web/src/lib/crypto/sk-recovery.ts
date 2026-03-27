// hello OS v2.0 — P2P Sender Key Recovery Protocol
// When a recipient misses a SK distribution (offline, broadcast failure),
// they can request re-distribution from the sender via Realtime broadcast.
// This is an ephemeral control channel — no DB writes, no stored state.

import { supabase, getSupabaseToken } from '../supabase';
import { keyStore } from './keystore';

/** Pending SK requests — keyed by "groupId:senderId" to prevent duplicates */
const pendingRequests = new Set<string>();

/** Callbacks waiting for SK arrival — keyed by "groupId:senderId" */
const waitingCallbacks = new Map<string, Array<() => void>>();

/**
 * Request a missing Sender Key from its owner.
 * Sends a control message via Realtime broadcast with event 'sk_request'.
 * Deduplicates: only one request per groupId:senderId at a time.
 * Fire-and-forget — does not block the decrypt path.
 */
export async function requestMissingSenderKey(
  groupId: string,
  senderId: string,
  myUserId: string,
  myDeviceId: number
): Promise<void> {
  const requestKey = `${groupId}:${senderId}`;

  // Deduplicate — don't spam requests
  if (pendingRequests.has(requestKey)) return;
  pendingRequests.add(requestKey);

  // Auto-clear after 30s to allow retry
  setTimeout(() => pendingRequests.delete(requestKey), 30000);

  console.log(`[hello-sk-recovery] Requesting SK from ${senderId} for space ${groupId}`);

  const token = getSupabaseToken();
  if (!token) {
    console.warn('[hello-sk-recovery] No JWT — cannot send SK request');
    return;
  }

  try {
    // Send SK request as a broadcast on the space chat channel.
    // The sender's client listens for these and responds with re-distribution.
    const channel = supabase.channel(`chat:${groupId}`);
    await channel.subscribe();

    await channel.send({
      type: 'broadcast',
      event: 'sk_request',
      payload: {
        requester_id: myUserId,
        requester_device_id: myDeviceId,
        target_sender_id: senderId,
        group_id: groupId,
        timestamp: Date.now(),
      },
    });

    console.log(`[hello-sk-recovery] SK request sent for ${requestKey}`);
    supabase.removeChannel(channel);
  } catch (err) {
    console.warn('[hello-sk-recovery] Failed to send SK request:', err);
    pendingRequests.delete(requestKey);
  }
}

/**
 * Wait for a Sender Key to arrive (with timeout).
 * Returns true if key became available, false if timed out.
 * Used by decryptMessage to give recovery a chance before returning placeholder.
 */
export function waitForSenderKey(
  groupId: string,
  senderId: string,
  timeoutMs: number = 10000
): Promise<boolean> {
  const waitKey = `${groupId}:${senderId}`;

  return new Promise(resolve => {
    const timer = setTimeout(() => {
      // Timeout — remove callback and resolve false
      const callbacks = waitingCallbacks.get(waitKey);
      if (callbacks) {
        const idx = callbacks.indexOf(cb);
        if (idx >= 0) callbacks.splice(idx, 1);
        if (callbacks.length === 0) waitingCallbacks.delete(waitKey);
      }
      resolve(false);
    }, timeoutMs);

    const cb = () => {
      clearTimeout(timer);
      resolve(true);
    };

    const existing = waitingCallbacks.get(waitKey) ?? [];
    existing.push(cb);
    waitingCallbacks.set(waitKey, existing);
  });
}

/**
 * Notify that a Sender Key has arrived (call after processing SK distribution).
 * Resolves any pending waitForSenderKey promises so decrypt can retry.
 */
export function notifySenderKeyArrived(groupId: string, senderId: string): void {
  const waitKey = `${groupId}:${senderId}`;
  const callbacks = waitingCallbacks.get(waitKey);
  if (callbacks) {
    for (const cb of callbacks) cb();
    waitingCallbacks.delete(waitKey);
  }
  pendingRequests.delete(waitKey);
}

/**
 * Handle an incoming SK request (called when another user asks for our SK).
 * Verifies the requester is a current space member AND has registered keys
 * before authorizing re-distribution. Prevents kicked users and spoofed
 * identities from obtaining fresh key material.
 */
export async function handleSenderKeyRequest(
  groupId: string,
  requesterId: string,
  requesterDeviceId: number,
  myUserId: string
): Promise<boolean> {
  // Verify requester is still a space member (prevents kicked users from getting new keys)
  const { data: membership } = await supabase
    .from('space_members')
    .select('user_id')
    .eq('group_id', groupId)
    .eq('user_id', requesterId)
    .single();

  if (!membership) {
    console.warn(`[hello-sk-recovery] Rejected SK request from non-member ${requesterId}`);
    return false;
  }

  // Also verify requester has registered keys (prevents identity spoofing)
  const { data: keyBundle } = await supabase
    .from('key_bundles')
    .select('user_id')
    .eq('user_id', requesterId)
    .eq('device_id', requesterDeviceId)
    .single();

  if (!keyBundle) {
    console.warn(`[hello-sk-recovery] Rejected SK request — no key bundle for ${requesterId}:${requesterDeviceId}`);
    return false;
  }

  console.log(`[hello-sk-recovery] Authorized SK request from ${requesterId} for space ${groupId}`);
  return true;
}

/**
 * Subscribe to incoming SK requests for a space.
 * When another user broadcasts an sk_request targeting us, we verify their
 * membership and invoke the onRequestApproved callback so the caller can
 * re-distribute the Sender Key via pairwise session.
 *
 * Returns an unsubscribe function — call on space leave / unmount.
 */
export function subscribeToSKRequests(
  groupId: string,
  myUserId: string,
  onRequestApproved: (requesterId: string, requesterDeviceId: number) => Promise<void>
): () => void {
  const channel = supabase
    .channel(`sk-recovery:${groupId}`)
    .on('broadcast', { event: 'sk_request' }, async ({ payload }) => {
      if (payload.target_sender_id !== myUserId) return; // Not for me

      const approved = await handleSenderKeyRequest(
        groupId,
        payload.requester_id,
        payload.requester_device_id,
        myUserId
      );

      if (approved) {
        await onRequestApproved(payload.requester_id, payload.requester_device_id);
      }
    })
    .subscribe();

  return () => supabase.removeChannel(channel);
}
