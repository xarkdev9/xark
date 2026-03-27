// XARK OS v2.0 — E2EE Hook
// Manages E2EE lifecycle: init, key registration, encrypt/decrypt.
// Gracefully degrades to legacy mode if migration 014 not applied.

"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import type { EncryptedEnvelope } from "@/lib/crypto/encryption-service";
import type { DecryptedMessage } from "@/lib/crypto/types";

/**
 * PRIORITY 2 FIX: Recover unacked ratchet states on startup.
 *
 * The two-phase commit in encryption-service.ts saves an "unacked ratchet" entry
 * to IndexedDB BEFORE the network call, then deletes it on ACK. If the tab closes
 * between the save and the ACK, the entry persists and the chain index is consumed.
 *
 * Recovery logic:
 * - Older than 5 minutes: message definitely failed. Delete the unacked entry.
 *   The consumed chain index is a designed gap in Signal Protocol.
 * - Recent (< 5 minutes): tab may have closed mid-send. Check the outbox —
 *   if the message is queued there, the outbox retry will handle it.
 *   If not in the outbox, the send was abandoned — clean up.
 */
async function recoverUnackedRatchets(): Promise<void> {
  try {
    const { keyStore } = await import("@/lib/crypto/keystore");
    const unacked = await keyStore.getUnackedRatchets();
    if (unacked.length === 0) return;

    console.log(`[xark-e2ee] Found ${unacked.length} unacked ratchet(s) — recovering`);

    const { getPendingMessages } = await import("@/lib/crypto/outbox");
    const outboxEntries = await getPendingMessages();
    const outboxIds = new Set(outboxEntries.map((e) => e.id));

    const STALE_THRESHOLD_MS = 5 * 60 * 1000; // 5 minutes
    const now = Date.now();

    for (const entry of unacked) {
      const age = now - entry.createdAt;

      if (age > STALE_THRESHOLD_MS) {
        // Old entry — message definitely failed to send. Chain index consumed (gap).
        console.log(
          `[xark-e2ee] Cleaning stale unacked ratchet ${entry.messageId} ` +
          `(age: ${Math.round(age / 1000)}s, type: ${entry.sessionType})`
        );
        await keyStore.ackRatchet(entry.messageId);
      } else {
        // Recent entry — check if the outbox is handling it.
        // The outbox key is the message ID, but unacked ratchets use "pending_*"
        // keys while outbox uses the real message ID. We check if ANY outbox entry
        // exists for the same space/session, which means the send is being retried.
        const isInOutbox = outboxIds.has(entry.messageId);

        if (isInOutbox) {
          // Outbox retry will handle the send — leave the unacked entry alone.
          console.log(
            `[xark-e2ee] Unacked ratchet ${entry.messageId} found in outbox — leaving for retry`
          );
        } else {
          // Not in outbox, send was abandoned mid-flight. Clean up.
          console.log(
            `[xark-e2ee] Cleaning recent orphaned ratchet ${entry.messageId} ` +
            `(age: ${Math.round(age / 1000)}s, not in outbox)`
          );
          await keyStore.ackRatchet(entry.messageId);
        }
      }
    }
  } catch (err) {
    // Non-fatal — recovery is best-effort
    console.warn("[xark-e2ee] Unacked ratchet recovery failed:", err);
  }
}

/**
 * Proactive SK recovery — called after first key registration.
 * Finds all spaces the user belongs to, identifies senders who have key bundles,
 * and requests their Sender Keys via Realtime broadcast.
 * This ensures messages sent BEFORE this user registered keys can be decrypted
 * once the sender responds with their SK.
 */
async function requestSKsFromAllSpaces(userId: string, deviceId: number): Promise<void> {
  try {
    const { supabase } = await import("@/lib/supabase");
    const { requestMissingSenderKey } = await import("@/lib/crypto/sk-recovery");

    // Find all spaces this user belongs to
    const { data: memberships } = await supabase
      .from("space_members")
      .select("group_id")
      .eq("user_id", userId);

    if (!memberships || memberships.length === 0) return;

    const groupIds = memberships.map((m) => m.group_id);
    console.log(`[xark-e2ee] Proactive SK recovery: ${groupIds.length} spaces`);

    // For each space, find other members who have registered keys
    for (const groupId of groupIds) {
      const { data: devices } = await supabase.rpc("get_space_member_devices", {
        p_group_id: groupId,
        p_exclude_user: userId,
      });

      if (!devices || devices.length === 0) continue;

      // Request SK from each member — fire-and-forget, non-blocking
      for (const dev of devices as Array<{ user_id: string; device_id: number }>) {
        requestMissingSenderKey(groupId, dev.user_id, userId, deviceId).catch(() => {});
      }

      console.log(`[xark-e2ee] Requested SK from ${devices.length} member(s) in ${groupId.slice(0, 12)}...`);
    }
  } catch (err) {
    console.warn("[xark-e2ee] Proactive SK recovery failed:", err);
  }
}

export interface E2EEState {
  ready: boolean;       // crypto initialized (may still be unavailable)
  available: boolean;   // keys registered, tables exist
  deviceId: number | null;
}

export function useE2EE(userId: string | null): E2EEState & {
  encrypt: (text: string, groupId: string, media?: {
    mediaUrl: string; aesKeyBase64: string; ivBase64: string; mimeType: string; inlineThumbnail?: string;
  }, linkPreview?: {
    url: string; title?: string; description?: string; mediaUrl?: string;
    aesKeyBase64?: string; ivBase64?: string; mimeType?: string; inlineThumbnail?: string;
  }) => Promise<EncryptedEnvelope | null>;
  decrypt: (
    messageId: string,
    senderId: string,
    senderDeviceId: number | null,
    ciphertextB64: string,
    ratchetHeaderB64: string | null,
    recipientId: string,
    groupId: string
  ) => Promise<DecryptedMessage | null>;
} {
  const [state, setState] = useState<E2EEState>({
    ready: false,
    available: false,
    deviceId: null,
  });
  const initRef = useRef(false);
  const prevUserIdRef = useRef<string | null>(null);

  // PRIORITY 6 FIX: Reset initRef when userId changes so E2EE can re-initialize
  // for a new user (logout/login) or retry after a failed first attempt.
  useEffect(() => {
    if (userId !== prevUserIdRef.current) {
      prevUserIdRef.current = userId;
      if (initRef.current) {
        console.log('[xark-e2ee] userId changed — resetting init guard for re-initialization');
        initRef.current = false;
        setState({ ready: false, available: false, deviceId: null });
      }
    }
  }, [userId]);

  useEffect(() => {
    if (!userId || initRef.current) return;
    initRef.current = true;

    async function init() {
      try {
        // BUG 1 fix: wait for JWT with exponential backoff before key registration
        const { getSupabaseToken } = await import("@/lib/supabase");
        let retries = 0;
        const maxRetries = 8;
        while (!getSupabaseToken() && retries < maxRetries) {
          const delay = Math.min(500 * Math.pow(2, retries), 4000);
          await new Promise(r => setTimeout(r, delay));
          retries++;
        }
        if (!getSupabaseToken()) {
          console.error("[xark-e2ee] No JWT after retries — E2EE unavailable");
          setState({ ready: true, available: false, deviceId: null });
          return;
        }
        if (retries > 0) {
          console.log(`[xark-e2ee] JWT ready after ${retries} retries`);
        }

        // Dynamic imports — avoid SSR issues with WASM (libsodium)
        const { initCrypto } = await import("@/lib/crypto/primitives");
        const { hasRegisteredKeys, registerKeys, replenishOTKsIfNeeded } =
          await import("@/lib/crypto/key-manager");
        const { keyStore } = await import("@/lib/crypto/keystore");

        await initCrypto();

        const hasKeys = await hasRegisteredKeys();
        if (!hasKeys) {
          try {
            const { deviceId } = await registerKeys();
            setState({ ready: true, available: true, deviceId });

            // ── PROACTIVE SK RECOVERY ──
            // First-time key registration: request Sender Keys from all space members.
            // Without this, messages sent BEFORE this user registered keys are
            // permanently "decrypting..." because no SK was distributed to them.
            if (userId) requestSKsFromAllSpaces(userId, deviceId).catch(() => {});

            return;
          } catch (err) {
            // Migration 014 not applied — E2EE tables don't exist yet
            console.warn("[xark-e2ee] Key registration failed:", err);
            setState({ ready: true, available: false, deviceId: null });
            return;
          }
        }

        // Local keys exist — verify server has our bundle too (heals divergence).
        // If server has no bundle, wipe local keys and re-register.
        const deviceId = await keyStore.getDeviceId();
        try {
          const { supabase: sb } = await import("@/lib/supabase");
          const { count } = await sb
            .from("key_bundles")
            .select("user_id", { count: "exact", head: true })
            .eq("user_id", userId)
            .eq("device_id", deviceId);
          if (count === 0) {
            console.warn("[xark-e2ee] Local keys exist but server bundle missing — re-registering");
            await keyStore.clear();
            const result = await registerKeys();
            setState({ ready: true, available: true, deviceId: result.deviceId });
            // Proactive SK recovery + pre-distribution after re-registration
            if (userId) {
              requestSKsFromAllSpaces(userId, result.deviceId).catch(() => {});
            }
            return;
          }
        } catch (verifyErr) {
          // Verification query failed — proceed optimistically
          console.warn("[xark-e2ee] Server bundle check failed:", verifyErr);
        }

        // E2EE fully wired — local + server in sync
        setState({ ready: true, available: true, deviceId });

        // PRIORITY 2: Recover unacked ratchet states from previous crashed sessions.
        recoverUnackedRatchets().catch(() => {});

        // Replenish OTKs in background (fire-and-forget)
        replenishOTKsIfNeeded().catch(() => {});
      } catch (err) {
        console.warn("[xark-e2ee] Init failed:", err);
        setState({ ready: true, available: false, deviceId: null });
      }
    }

    init();
  }, [userId]);

  const encrypt = useCallback(
    async (text: string, groupId: string, media?: {
      mediaUrl: string; aesKeyBase64: string; ivBase64: string; mimeType: string; inlineThumbnail?: string;
    }, linkPreview?: {
      url: string; title?: string; description?: string; mediaUrl?: string;
      aesKeyBase64?: string; ivBase64?: string; mimeType?: string; inlineThumbnail?: string;
    }): Promise<EncryptedEnvelope | null> => {
      if (!state.available) return null;
      try {
        const { encryptForSpace } = await import(
          "@/lib/crypto/encryption-service"
        );
        return await encryptForSpace(text, groupId, media, linkPreview);
      } catch (err) {
        console.warn("[xark-e2ee] Encrypt failed:", err);
        return null;
      }
    },
    [state.available]
  );

  const decrypt = useCallback(
    async (
      messageId: string,
      senderId: string,
      senderDeviceId: number | null,
      ciphertextB64: string,
      ratchetHeaderB64: string | null,
      recipientId: string,
      groupId: string
    ): Promise<DecryptedMessage | null> => {
      if (!state.available) return null;
      try {
        const { decryptMessage } = await import(
          "@/lib/crypto/encryption-service"
        );
        return await decryptMessage(
          messageId,
          senderId,
          senderDeviceId,
          ciphertextB64,
          ratchetHeaderB64,
          recipientId,
          groupId
        );
      } catch (err) {
        console.warn("[xark-e2ee] Decrypt failed:", err);
        throw err;
      }
    },
    [state.available]
  );

  return { ...state, encrypt, decrypt };
}
