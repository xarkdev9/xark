"use client";

// hello OS v2.0 — Space View
// Discuss (chat) + Decide (visual stream) toggle.
// Chat state (messages, draft input) lives HERE — persists across view switches.
// ChatInput is always visible. HelloChat is display-only.

import { useState, useEffect, useCallback, useRef, Suspense } from "react";
import { motion } from "framer-motion";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import { HelloChat } from "@/components/os/HelloChat";
import { Avatar } from "@/components/os/Avatar";
import DecisionBoard from "@/components/os/DecisionBoard";
import { ItineraryView } from "@/components/os/ItineraryView";
import { MemoriesView } from "@/components/os/MemoriesView";
import { ChatInput } from "@/components/os/ChatInput";
import { HelloPanel, type HelloPanelPayload } from "@/components/os/HelloPanel";
import { useAuth } from "@/hooks/useAuth";
import { supabase, getSupabaseToken } from "@/lib/supabase";
import {
  fetchMessages,
  saveMessage,
  broadcastMessage,
  subscribeToMessages,
  unsubscribeFromMessages,
  fetchCiphertexts,
} from "@/lib/messages";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { computeGroupState } from "@/lib/space-state";
import { useE2EE } from "@/hooks/useE2EE";
import { detectConstraints } from "@/lib/constraints";
import type { DetectedConstraint } from "@/lib/crypto/types";
import type { GroupStateItem } from "@/lib/space-state";
import { colors, ink, text, textColor, timing, surface } from "@/lib/theme";
import type { LedgerEntry } from "@/lib/group-actions";
import type { LedgerEvent } from "@/components/os/LedgerPill";
import { markSpaceRead } from "@/lib/unread";
import { PlaygroundSpace } from "@/components/os/PlaygroundSpace";
import { isPlaygroundSpace } from "@/lib/playground";
import { ConsensusBanner } from "@/components/os/ConsensusBanner";

// Demo space title map — used when Supabase is unreachable
const DEMO_TITLES: Record<string, string> = {
  "space_san-diego-trip": "san diego trip",
  space_ananya: "ananya",
  "space_tokyo-neon-nights": "tokyo neon nights",
  "space_summer-2026": "summer 2026",
};

// Universal UUID fallback for browsers without crypto.randomUUID
function generateId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export interface ChatMessage {
  id: string;
  role: "user" | "hello" | "system";
  content: string;
  timestamp: number;
  senderName?: string;
  userId?: string;
  senderDeviceId?: number;
  messageType?: string;  // 'e2ee' | 'hello' | 'system' | 'legacy'
  deliveryStatus?: 'queued' | 'sent' | 'delivered' | 'read';
  /** E2EE media: Firebase download URL of encrypted blob */
  mediaUrl?: string;
  /** E2EE media: AES-256-GCM key for decrypting the blob (base64) */
  aesKeyBase64?: string;
  /** E2EE media: AES-GCM IV (base64) */
  ivBase64?: string;
  /** E2EE media: original MIME type (e.g. 'image/jpeg') */
  mimeType?: string;
  /** E2EE media: tiny Base64 JPEG thumbnail for instant blurry preview */
  inlineThumbnail?: string;
  /** E2EE link preview (OG metadata + encrypted preview image) */
  linkPreview?: {
    url: string;
    title?: string;
    description?: string;
    mediaUrl?: string;
    aesKeyBase64?: string;
    ivBase64?: string;
    mimeType?: string;
    inlineThumbnail?: string;
  };
}

type ViewMode = "discuss" | "decide" | "itinerary" | "memories";

function SpacePageInner() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const groupId = params.id as string;
  const userName = searchParams.get("name") ?? undefined;
  const isInvite = searchParams.get("invite") === "true";

  const isPlayground = searchParams.get("playground") === "true" && isPlaygroundSpace(groupId);

  const { user, isAuthenticated, isLoading: authLoading } = useAuth(userName);
  // CRITICAL: userId must come from authenticated user only (e.g., "name_ram"),
  // never from raw URL param (e.g., "ram"). RLS checks user_id = auth.jwt()->>'sub'.
  const resolvedUserId = user?.uid ?? undefined;

  const e2ee = useE2EE(resolvedUserId ?? null);

  // PRIORITY 4 FIX: Ref-based E2EE state for the Realtime handler.
  // The Realtime subscription effect no longer depends on e2ee.available,
  // preventing teardown/re-subscribe during E2EE init transition.
  // The handler reads from this ref to get the latest crypto state.
  const e2eeRef = useRef(e2ee);
  useEffect(() => { e2eeRef.current = e2ee; }, [e2ee]);

  const viewParam = searchParams.get("view");
  const [view, setView] = useState<ViewMode>(
    viewParam === "decide" ? "decide" : "discuss"
  );
  const [spaceTitle, setSpaceTitle] = useState<string>("");
  const [atmosphere, setGroupType] = useState<string>("cyan_horizon");
  const [spaceItems, setSpaceItems] = useState<GroupStateItem[]>([]);
  const [joining, setJoining] = useState(false);
  const [shareWhisper, setShareWhisper] = useState(false);
  const [constraintWhisper, setConstraintWhisper] = useState<DetectedConstraint | null>(null);
  const [memberCount, setMemberCount] = useState(0);

  // Fetch member count
  useEffect(() => {
    supabase.from("space_members").select("user_id", { count: "exact", head: true }).eq("group_id", groupId)
      .then(({ count }) => { if (count !== null) setMemberCount(count); });
  }, [groupId]);

  // ── Outbox drain — retry queued messages on reconnect / tab visible / mount ──
  useEffect(() => {
    if (!resolvedUserId) return;
    let cleanup: (() => void) | undefined;
    (async () => {
      const { startOutboxSync } = await import("@/lib/crypto/outbox");
      cleanup = startOutboxSync(
        (id) => console.log(`[hello-outbox] Sent queued message ${id}`),
        (id, err) => console.warn(`[hello-outbox] Permanently failed: ${id} — ${err}`)
      );
    })();
    return () => cleanup?.();
  }, [resolvedUserId]);

  // ── Swipe to switch discuss ↔ decide ──
  const viewTabs: ViewMode[] = ["discuss", "decide"];
  const swipeStartX = useRef(0);
  const swipeStartY = useRef(0);

  const handleSwipeStart = useCallback((e: React.TouchEvent) => {
    swipeStartX.current = e.touches[0].clientX;
    swipeStartY.current = e.touches[0].clientY;
  }, []);

  const handleSwipeEnd = useCallback((e: React.TouchEvent) => {
    const dx = e.changedTouches[0].clientX - swipeStartX.current;
    const dy = e.changedTouches[0].clientY - swipeStartY.current;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      const idx = viewTabs.indexOf(view);
      if (dx < 0 && idx < viewTabs.length - 1) setView(viewTabs[idx + 1]);
      else if (dx > 0 && idx > 0) setView(viewTabs[idx - 1]);
    }
  }, [view]);

  const [ledgerEvents, setLedgerEvents] = useState<LedgerEvent[]>([]);

  // ═══════════════════════════════════════════
  // CHAT STATE — lives here, shared across views
  // ═══════════════════════════════════════════
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [helloPanelOpen, setHelloPanelOpen] = useState(false);
  const [pendingLinkPreview, setPendingLinkPreview] = useState<{
    title: string | null; description: string | null; imageBase64: string | null; url: string;
  } | null>(null);
  const [isThinking, setIsThinking] = useState(
    searchParams.get("hello") === "thinking"
  );
  const messagesLoaded = useRef(false);
  const channelRef = useRef<RealtimeChannel | null>(null);

  // ── Listen for SpotlightSheet @hello-thinking event (when user sends from ControlCaret inside this space) ──
  const thinkingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    const handler = (e: Event) => {
      const detail = (e as CustomEvent).detail;
      if (detail?.groupId === groupId) {
        setIsThinking(true);
        // Safety: clear after 30s if no @hello response arrives
        if (thinkingTimerRef.current) clearTimeout(thinkingTimerRef.current);
        thinkingTimerRef.current = setTimeout(() => setIsThinking(false), 30_000);
      }
    };
    window.addEventListener("hello-thinking", handler);
    return () => {
      window.removeEventListener("hello-thinking", handler);
      if (thinkingTimerRef.current) clearTimeout(thinkingTimerRef.current);
    };
  }, [groupId]);

  // Safety timeout for URL-param triggered thinking (Home → Space navigation)
  useEffect(() => {
    if (searchParams.get("hello") === "thinking") {
      const t = setTimeout(() => setIsThinking(false), 30_000);
      return () => clearTimeout(t);
    }
  }, [searchParams]);

  // ── PHASE A: Local-First Cache Read — instant render, no auth gate ──
  const cacheLoaded = useRef(false);
  useEffect(() => {
    if (cacheLoaded.current) return;
    cacheLoaded.current = true;
    import("@/lib/crypto/message-cache").then(({ getCachedMessages }) => {
      getCachedMessages(groupId, 50).then((cached) => {
        if (cached.length > 0) {
          setMessages(cached.map((m) => ({
            id: m.id,
            role: m.role as "user" | "hello" | "system",
            content: m.content,
            timestamp: m.timestamp,
            senderName: m.senderName,
            userId: m.userId,
            senderDeviceId: m.senderDeviceId,
            messageType: m.messageType,
          })));
        }
      }).catch(() => {});
    });
  }, [groupId]);

  // ── PHASE B: Fetch persisted messages AFTER auth resolves, then batch-decrypt E2EE ──
  useEffect(() => {
    if (authLoading || !e2ee.available) return;
    if (messagesLoaded.current) return;

    // BUG 9 fix: fetch ALL sender_key_dist messages first (not limited to 50)
    // Then fetch regular messages
    const fetchAllSkDist = async () => {
      try {
        const { data } = await supabase
          .from("messages")
          .select("id, group_id, role, content, user_id, sender_name, created_at, message_type, sender_device_id")
          .eq("group_id", groupId)
          .eq("message_type", "sender_key_dist")
          .order("created_at", { ascending: true });
        return data ?? [];
      } catch { return []; }
    };

    Promise.all([fetchAllSkDist(), fetchMessages(groupId, { limit: 50 })])
      .then(async ([skDistMsgs, persisted]) => {
        // Process SK dist messages first (before regular decrypt)
        if (e2ee.available && skDistMsgs.length > 0) {
          for (const dm of skDistMsgs) {
            try {
              const cts = await fetchCiphertexts([dm.id]);
              const myCt = cts.find(
                (ct) => ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_'
              );
              if (myCt && dm.user_id) {
                const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                await processSenderKeyDistribution(
                  dm.id, dm.user_id, dm.sender_device_id ?? 0, groupId, myCt.ciphertext, myCt.ratchet_header ?? ''
                );
              }
            } catch { /* continue */ }
          }
        }

        if (persisted.length === 0) {
          messagesLoaded.current = true;
          return;
        }

        // Map messages immediately (show "[decryption pending]" for E2EE)
        const mapped: ChatMessage[] = persisted
          .filter((m) => m.message_type !== 'sender_key_dist')
          .map((m) => ({
            id: m.id,
            role: m.role,
            content: m.content ?? '',
            timestamp: new Date(m.created_at).getTime(),
            senderName: m.sender_name ?? undefined,
            userId: m.user_id ?? undefined,
            senderDeviceId: m.sender_device_id ?? undefined,
            messageType: m.message_type ?? 'legacy',
          }));
        setMessages(mapped);

        // Batch decrypt E2EE messages
        if (e2ee.available) {
          // Process sender_key_dist messages silently first
          const distMsgs = persisted.filter((m) => m.message_type === 'sender_key_dist');
          for (const dm of distMsgs) {
            try {
              const cts = await fetchCiphertexts([dm.id]);
              const myCt = cts.find(
                (ct) => ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_'
              );
              if (myCt && dm.user_id) {
                const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                await processSenderKeyDistribution(
                  dm.id,
                  dm.user_id,
                  dm.sender_device_id ?? 0,
                  groupId,
                  myCt.ciphertext,
                  myCt.ratchet_header ?? ''
                );
              }
            } catch (err) {
              console.warn('[e2ee] SK dist processing failed:', err);
            }
          }

          // Now decrypt regular E2EE messages
          const e2eeMsgs = persisted.filter(
            (m) => m.message_type === 'e2ee'
          );
          if (e2eeMsgs.length > 0) {
            const e2eeIds = e2eeMsgs.map((m) => m.id);
            const ciphertexts = await fetchCiphertexts(e2eeIds);

            // ── Process piggybacked SK distributions FIRST ──
            // Distribution ciphertexts are addressed to specific users (not '_group_')
            // and live alongside the message ciphertext under the same message_id.
            const distCts = ciphertexts.filter(
              (ct) => ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_'
            );
            for (const dct of distCts) {
              try {
                const msg = e2eeMsgs.find((m) => m.id === dct.message_id);
                if (msg?.user_id) {
                  const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                  await processSenderKeyDistribution(
                    msg.id,
                    msg.user_id, msg.sender_device_id ?? 0, groupId, dct.ciphertext, dct.ratchet_header ?? ''
                  );
                }
              } catch (err) {
                console.warn('[e2ee] Piggybacked SK dist failed:', err);
              }
            }

            // ── Now decrypt the group ciphertexts ──
            const groupCts = ciphertexts.filter((ct) => ct.recipient_id === '_group_');
            const decryptedMap = new Map<string, { text: string; mediaUrl?: string; aesKeyBase64?: string; ivBase64?: string; mimeType?: string; inlineThumbnail?: string; linkPreview?: ChatMessage['linkPreview'] }>();
            for (const ct of groupCts) {
              try {
                const msg = e2eeMsgs.find((m) => m.id === ct.message_id);
                if (!msg) continue;

                // P3.2: Self-message cache check — sender can't self-decrypt SK messages
                // Check media cache first, then text-only cache
                if (msg.user_id === resolvedUserId) {
                  try {
                    const { keyStore } = await import("@/lib/crypto/keystore");
                    const cachedMedia = await keyStore.getDecryptedMedia(ct.message_id);
                    if (cachedMedia) {
                      decryptedMap.set(ct.message_id, cachedMedia);
                      continue;
                    }
                    const cached = await keyStore.getDecryptedMessage(ct.message_id);
                    if (cached) {
                      decryptedMap.set(ct.message_id, { text: cached });
                      continue;
                    }
                  } catch { /* fall through to normal decrypt */ }
                }

                const decrypted = await e2ee.decrypt(
                  ct.message_id,
                  msg.user_id ?? '',
                  msg.sender_device_id ?? null,
                  ct.ciphertext,
                  ct.ratchet_header,
                  ct.recipient_id,
                  groupId
                );
                if (decrypted) {
                  decryptedMap.set(ct.message_id, {
                    text: decrypted.text,
                    mediaUrl: decrypted.mediaUrl ?? undefined,
                    aesKeyBase64: decrypted.aesKeyBase64,
                    ivBase64: decrypted.ivBase64,
                    mimeType: decrypted.mimeType,
                    inlineThumbnail: decrypted.inlineThumbnail,
                    linkPreview: decrypted.linkPreview,
                  });
                }
              } catch (err) {
                console.warn('[e2ee] Decrypt failed for', ct.message_id, err);
                decryptedMap.set(ct.message_id, { text: '[Error: Decryption Failed]' });

                // P3.3: Trigger SK recovery for failed decryption
                const failedMsg = e2eeMsgs.find((m) => m.id === ct.message_id);
                if (failedMsg?.user_id && failedMsg.user_id !== resolvedUserId) {
                  import("@/lib/crypto/sk-recovery").then(({ requestMissingSenderKey }) => {
                    requestMissingSenderKey(groupId, failedMsg.user_id!, resolvedUserId ?? '', e2ee.deviceId ?? 0);
                  }).catch(() => {});
                }
              }
            }

            // Merge decrypted content + media metadata into messages
            if (decryptedMap.size > 0) {
              for (const m of mapped) {
                const decrypted = decryptedMap.get(m.id);
                if (decrypted) {
                  m.content = decrypted.text;
                  if (decrypted.mediaUrl) m.mediaUrl = decrypted.mediaUrl;
                  if (decrypted.aesKeyBase64) m.aesKeyBase64 = decrypted.aesKeyBase64;
                  if (decrypted.ivBase64) m.ivBase64 = decrypted.ivBase64;
                  if (decrypted.mimeType) m.mimeType = decrypted.mimeType;
                  if (decrypted.inlineThumbnail) m.inlineThumbnail = decrypted.inlineThumbnail;
                  if (decrypted.linkPreview) m.linkPreview = decrypted.linkPreview;
                }
              }
              setMessages((prev) => {
                // Merge: deduplicate by id, prefer decrypted content
                const byId = new Map(prev.map(m => [m.id, m]));
                for (const m of mapped) byId.set(m.id, m);
                const merged = Array.from(byId.values()).sort((a, b) => a.timestamp - b.timestamp);
                return merged;
              });
            }
          }
        }

        // Cache all successfully decrypted messages for local-first rendering
        import("@/lib/crypto/message-cache").then(({ cacheBatchMessages, evictOldMessages }) => {
          const toCache = mapped.filter(m => m.content && m.content !== '[decryption pending]' && m.content !== '[Error: Decryption Failed]');
          cacheBatchMessages(groupId, toCache).then(() => evictOldMessages(groupId)).catch(() => {});
        });

        messagesLoaded.current = true;
      })
      .catch(() => {
        messagesLoaded.current = true;
      });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId, authLoading, e2ee.available]);

  // ── PRIORITY 0 FIX: Catch-up decryption pass ──
  // After PHASE B completes and E2EE is available, scan React state for messages
  // still showing "[decryption pending]" or "[Error: Decryption Failed]" (stale
  // cache from PHASE A) and re-attempt decryption. Debounced to avoid re-firing
  // on every message state update — runs once when messagesLoaded flips true.
  const catchupRanRef = useRef(false);
  useEffect(() => {
    if (!e2ee.available || !messagesLoaded.current || catchupRanRef.current) return;
    catchupRanRef.current = true;

    const undecrypted = messages.filter(
      (m) =>
        m.messageType === 'e2ee' &&
        (m.content === '[decryption pending]' || m.content === '[Error: Decryption Failed]')
    );
    if (undecrypted.length === 0) return;

    console.log(`[hello-catchup] Re-decrypting ${undecrypted.length} stale message(s)`);

    (async () => {
      const ids = undecrypted.map((m) => m.id);
      const ciphertexts = await fetchCiphertexts(ids);
      const fixes = new Map<string, string>();

      for (const m of undecrypted) {
        try {
          // Check plaintext cache first (own messages)
          if (m.userId === resolvedUserId) {
            const { keyStore } = await import("@/lib/crypto/keystore");
            const cached = await keyStore.getDecryptedMessage(m.id);
            if (cached) { fixes.set(m.id, cached); continue; }
          }

          // Process any piggybacked SK distribution for this message
          const distCt = ciphertexts.find(
            (ct) => ct.message_id === m.id && ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_'
          );
          if (distCt && m.userId) {
            const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
            await processSenderKeyDistribution(
              m.id, m.userId, m.senderDeviceId ?? 0, groupId, distCt.ciphertext, distCt.ratchet_header ?? ''
            );
          }

          const groupCt = ciphertexts.find(
            (ct) => ct.message_id === m.id && ct.recipient_id === '_group_'
          );
          if (groupCt) {
            const result = await e2ee.decrypt(
              m.id, m.userId ?? '', m.senderDeviceId ?? null,
              groupCt.ciphertext, groupCt.ratchet_header ?? null, '_group_', groupId
            );
            if (result) fixes.set(m.id, result.text);
          }
        } catch (err) {
          console.warn('[hello-catchup] Re-decrypt failed for', m.id, err);
        }
      }

      if (fixes.size > 0) {
        console.log(`[hello-catchup] Recovered ${fixes.size} message(s)`);
        setMessages((prev) =>
          prev.map((m) => {
            const fixed = fixes.get(m.id);
            return fixed ? { ...m, content: fixed } : m;
          })
        );
        // Update local cache with recovered messages
        import("@/lib/crypto/message-cache").then(({ cacheBatchMessages }) => {
          const recovered = undecrypted
            .filter((m) => fixes.has(m.id))
            .map((m) => ({ ...m, content: fixes.get(m.id)! }));
          cacheBatchMessages(groupId, recovered).catch(() => {});
        });
      }
    })();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [e2ee.available, messages.length]);

  // ── PRIORITY 1 FIX: Re-decrypt on Sender Key arrival ──
  // When a Sender Key distribution is processed (from any path — Realtime, PHASE B,
  // or P2P recovery), encryption-service.ts emits a 'sk-arrived' DOM event.
  // This listener re-scans messages from that sender that still show decrypt errors
  // and retries them now that the key is available.
  useEffect(() => {
    if (!e2ee.available) return;

    const handler = async (e: Event) => {
      const { groupId: arrivedGroupId, senderId } = (e as CustomEvent).detail;
      if (arrivedGroupId !== groupId) return;

      // Find failed messages from this sender in current state
      const failed = messages.filter(
        (m) =>
          m.userId === senderId &&
          m.messageType === 'e2ee' &&
          (m.content === '[Error: Decryption Failed]' || m.content === '[decryption pending]')
      );
      if (failed.length === 0) return;

      console.log(`[hello-sk-arrived] SK arrived for ${senderId}, re-decrypting ${failed.length} message(s)`);

      const ids = failed.map((m) => m.id);
      const ciphertexts = await fetchCiphertexts(ids);
      const fixes = new Map<string, string>();

      for (const m of failed) {
        try {
          const groupCt = ciphertexts.find(
            (ct) => ct.message_id === m.id && ct.recipient_id === '_group_'
          );
          if (groupCt) {
            const result = await e2ee.decrypt(
              m.id, m.userId ?? '', m.senderDeviceId ?? null,
              groupCt.ciphertext, groupCt.ratchet_header ?? null, '_group_', groupId
            );
            if (result) fixes.set(m.id, result.text);
          }
        } catch (err) {
          console.warn('[hello-sk-arrived] Re-decrypt still failed for', m.id, err);
        }
      }

      if (fixes.size > 0) {
        console.log(`[hello-sk-arrived] Recovered ${fixes.size} message(s) after SK arrival`);
        setMessages((prev) =>
          prev.map((m) => {
            const fixed = fixes.get(m.id);
            return fixed ? { ...m, content: fixed } : m;
          })
        );
        // Update local cache
        import("@/lib/crypto/message-cache").then(({ cacheBatchMessages }) => {
          const recovered = failed
            .filter((m) => fixes.has(m.id))
            .map((m) => ({ ...m, content: fixes.get(m.id)! }));
          cacheBatchMessages(groupId, recovered).catch(() => {});
        });
      }
    };

    window.addEventListener('sk-arrived', handler);
    return () => window.removeEventListener('sk-arrived', handler);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId, e2ee.available, messages]);

  // ── Mark space as read when user opens it ──
  useEffect(() => {
    if (authLoading || !resolvedUserId) return;
    markSpaceRead(groupId);
  }, [groupId, authLoading, resolvedUserId]);

  // ── Broadcast channel — instant message delivery across devices ──
  // PRIORITY 4 FIX: e2ee.available removed from dependency array. The handler reads
  // from e2eeRef.current (always fresh) instead of the closure-captured e2ee value.
  // This prevents teardown/re-subscribe during E2EE init transition — no message gap.
  useEffect(() => {
    const channel = subscribeToMessages(groupId, async (incoming) => {
      // Read latest E2EE state from ref (not stale closure)
      const e2eeSnap = e2eeRef.current;

      // Sender Key distribution — process silently, don't display
      if (incoming.message_type === 'sender_key_dist') {
        if (e2eeSnap.available && incoming.user_id) {
          try {
            // Fetch our ciphertext from DB (distribution has per-recipient rows)
            const cts = await fetchCiphertexts([incoming.id]);
            const myCt = cts.find(
              (ct) => ct.recipient_device_id === e2eeSnap.deviceId && ct.recipient_id !== '_group_'
            );
            if (myCt) {
              const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
              await processSenderKeyDistribution(
                incoming.id,
                incoming.user_id,
                incoming.sender_device_id ?? 0,
                groupId,
                myCt.ciphertext,
                myCt.ratchet_header ?? ''
              );
            }
          } catch (err) {
            console.warn('[e2ee] Realtime SK dist processing failed:', err);
          }
        }
        return; // Don't add to chat
      }

      // E2EE message — decrypt inline from broadcast payload
      let content = incoming.content ?? '';
      let mediaFields: { mediaUrl?: string; aesKeyBase64?: string; ivBase64?: string; mimeType?: string; inlineThumbnail?: string; linkPreview?: ChatMessage['linkPreview'] } = {};
      const msgType = incoming.message_type ?? 'legacy';

      if (e2eeSnap.available && msgType === 'e2ee') {
        if (incoming.ciphertext_b64) {
          // ── PRIORITY 3 FIX: Deterministic decrypt path ──
          // The sender's client only broadcasts AFTER /api/message returns 200 OK,
          // which guarantees all DB writes (message + ciphertext + distribution rows)
          // are committed. So we can fetch ciphertexts immediately — no sleep needed.
          //
          // A single 500ms safety-net retry is kept for extreme edge cases (network
          // latency between Postgres replicas, CDN cache coherence, etc).

          // Step 1: Fetch ciphertexts and process piggybacked SK distribution
          const processDistribution = async (): Promise<boolean> => {
            try {
              const cts = await fetchCiphertexts([incoming.id]);
              const myDistCt = cts.find(
                (ct) => ct.recipient_device_id === e2eeSnap.deviceId && ct.recipient_id !== '_group_'
              );
              if (myDistCt && incoming.user_id) {
                const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                await processSenderKeyDistribution(
                  incoming.id, incoming.user_id, incoming.sender_device_id ?? 0, groupId,
                  myDistCt.ciphertext, myDistCt.ratchet_header ?? ''
                );
              }
              return true;
            } catch (err) {
              console.warn('[e2ee] Piggybacked SK dist check failed:', err);
              return false;
            }
          };

          await processDistribution();

          // Step 2: Decrypt the group ciphertext
          try {
            const decrypted = await e2eeSnap.decrypt(
              incoming.id,
              incoming.user_id ?? '',
              incoming.sender_device_id ?? null,
              incoming.ciphertext_b64,
              incoming.ratchet_header_b64 ?? null,
              '_group_',
              groupId
            );
            if (decrypted) {
              content = decrypted.text;
              if (decrypted.mediaUrl || decrypted.linkPreview) {
                mediaFields = {
                  mediaUrl: decrypted.mediaUrl ?? undefined,
                  aesKeyBase64: decrypted.aesKeyBase64,
                  ivBase64: decrypted.ivBase64,
                  mimeType: decrypted.mimeType,
                  inlineThumbnail: decrypted.inlineThumbnail,
                  linkPreview: decrypted.linkPreview,
                };
              }
            }
          } catch (firstErr) {
            // Safety-net: single 500ms retry for replica lag edge cases
            console.warn('[e2ee] Realtime decrypt failed, single retry in 500ms:', firstErr);
            await new Promise(r => setTimeout(r, 500));
            try {
              await processDistribution();
              const retryDecrypt = await e2eeRef.current.decrypt(
                incoming.id,
                incoming.user_id ?? '',
                incoming.sender_device_id ?? null,
                incoming.ciphertext_b64,
                incoming.ratchet_header_b64 ?? null,
                '_group_',
                groupId
              );
              if (retryDecrypt) {
                content = retryDecrypt.text;
                if (retryDecrypt.mediaUrl) {
                  mediaFields = {
                    mediaUrl: retryDecrypt.mediaUrl,
                    aesKeyBase64: retryDecrypt.aesKeyBase64,
                    ivBase64: retryDecrypt.ivBase64,
                    mimeType: retryDecrypt.mimeType,
                  };
                }
              }
            } catch (retryErr) {
              console.warn('[e2ee] Safety-net retry failed:', retryErr);
              content = '[Error: Decryption Failed]';
              // Priority 1 (sk-arrived event) will auto-recover this if SK arrives later
              if (incoming.user_id && incoming.user_id !== resolvedUserId) {
                import("@/lib/crypto/sk-recovery").then(({ requestMissingSenderKey }) => {
                  requestMissingSenderKey(groupId, incoming.user_id!, resolvedUserId ?? '', e2eeRef.current.deviceId ?? 0);
                }).catch(() => {});
              }
            }
          }
        } else {
          content = '[decryption pending]';
        }
      }

      const newMsg: ChatMessage = {
        id: incoming.id,
        role: incoming.role as "user" | "hello" | "system",
        content,
        timestamp: new Date(incoming.created_at).getTime(),
        senderName: incoming.sender_name ?? undefined,
        userId: incoming.user_id ?? undefined,
        senderDeviceId: incoming.sender_device_id ?? undefined,
        messageType: msgType,
        ...mediaFields,
      };

      // Clear thinking indicator when @hello responds (phantom receipt or final response)
      if (incoming.role === "hello") {
        setIsThinking(false);
        if (thinkingTimerRef.current) { clearTimeout(thinkingTimerRef.current); thinkingTimerRef.current = null; }
      }

      setMessages((prev) => {
        if (prev.some((m) => m.id === incoming.id)) return prev;
        return [...prev, newMsg];
      });

      // Cache the new message for local-first rendering on next open
      if (content && content !== '[Error: Decryption Failed]' && content !== '[decryption pending]') {
        import("@/lib/crypto/message-cache").then(({ cacheBatchMessages }) => {
          cacheBatchMessages(groupId, [newMsg]).catch(() => {});
        });
      }
    }, (updatedMsg) => {
      setMessages((prev) => prev.map(m => m.id === updatedMsg.id ? { ...m, content: updatedMsg.content } : m));
    });
    channelRef.current = channel;

    return () => {
      unsubscribeFromMessages(channel);
      channelRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId, resolvedUserId]);

  // ── Broadcast reconciliation — catch missed messages ──
  // Supabase Broadcast is fire-and-forget WebSocket. If a user's Wi-Fi drops
  // for even 2 seconds, they miss broadcasts permanently. This loop polls
  // every 30s and on tab-visible to detect and fill gaps.
  useEffect(() => {
    if (!groupId || authLoading) return;

    const lastSeenRef = { current: Date.now() };
    const failedMsgIds = new Set<string>(); // Track messages that failed decrypt — don't retry them endlessly

    const reconcile = async () => {
      try {
        const latest = await fetchMessages(groupId, { limit: 1 });
        if (latest.length === 0) return;

        const latestTs = new Date(latest[0].created_at).getTime();

        // If the latest server message is newer than our last seen, we missed something
        if (latestTs > lastSeenRef.current) {
          console.log('[hello-reconcile] Gap detected, fetching missing messages');
          const missing = await fetchMessages(groupId, { limit: 20 });
          // Merge missing messages — decrypt E2EE before adding
          const existingIds = new Set(messages.map(m => m.id));
          const newRaw = missing
            .filter(m => !existingIds.has(m.id))
            .filter(m => !failedMsgIds.has(m.id))  // Don't retry messages that already failed decrypt
            .filter(m => m.message_type !== 'sender_key_dist');
          if (newRaw.length === 0) return;
          console.log(`[hello-reconcile] Found ${newRaw.length} missed messages`);

          // Decrypt E2EE messages before merging
          const decrypted: ChatMessage[] = [];
          for (const m of newRaw) {
            let content = m.content ?? '';
            if (m.message_type === 'e2ee' && e2ee.available) {
              // Check plaintext cache first (own messages)
              if (m.user_id === resolvedUserId) {
                try {
                  const { keyStore } = await import("@/lib/crypto/keystore");
                  const cached = await keyStore.getDecryptedMessage(m.id);
                  if (cached) { content = cached; }
                } catch { /* fall through */ }
              }
              // If not cached, try full decrypt
              if (!content || content === '') {
                try {
                  const cts = await fetchCiphertexts([m.id]);
                  // Process distribution first
                  const distCt = cts.find(ct => ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_');
                  if (distCt && m.user_id) {
                    const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                    await processSenderKeyDistribution(m.id, m.user_id, m.sender_device_id ?? 0, groupId, distCt.ciphertext, distCt.ratchet_header ?? '');
                  }
                  const groupCt = cts.find(ct => ct.recipient_id === '_group_');
                  if (groupCt) {
                    const result = await e2ee.decrypt(m.id, m.user_id ?? '', m.sender_device_id ?? null, groupCt.ciphertext, groupCt.ratchet_header ?? null, '_group_', groupId);
                    if (result) content = result.text;
                  }
                } catch (err) {
                  console.warn('[hello-reconcile] decrypt failed:', err);
                  content = '[decryption pending]';
                  failedMsgIds.add(m.id); // Don't retry this message in future reconciliation cycles
                }
              }
            }
            decrypted.push({
              id: m.id,
              role: m.role as "user" | "hello" | "system",
              content,
              timestamp: new Date(m.created_at).getTime(),
              senderName: m.sender_name ?? undefined,
              userId: m.user_id ?? undefined,
              senderDeviceId: m.sender_device_id ?? undefined,
              messageType: m.message_type ?? 'legacy',
            });
          }
          if (decrypted.length > 0) {
            setMessages(prev => {
              const ids = new Set(prev.map(m => m.id));
              const fresh = decrypted.filter(m => !ids.has(m.id));
              if (fresh.length === 0) return prev;
              return [...prev, ...fresh].sort((a, b) => a.timestamp - b.timestamp);
            });
          }
        }

        lastSeenRef.current = Date.now();
      } catch {
        // Silent — reconciliation is best-effort
      }
    };

    const interval = setInterval(reconcile, 30000); // Every 30 seconds

    // Also reconcile on visibility change (user returns to tab)
    const onVisible = () => {
      if (document.visibilityState === 'visible') reconcile();
    };
    document.addEventListener('visibilitychange', onVisible);

    return () => {
      clearInterval(interval);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [groupId, authLoading]);

  // ── Listen for incoming SK requests — respond with re-distribution ──
  useEffect(() => {
    if (!resolvedUserId || !e2ee.available || !e2ee.deviceId) return;

    let cleanup: (() => void) | undefined;
    (async () => {
      const { subscribeToSKRequests } = await import("@/lib/crypto/sk-recovery");
      const { respondToSenderKeyRequest } = await import("@/lib/crypto/encryption-service");
      cleanup = subscribeToSKRequests(
        groupId,
        resolvedUserId,
        async (requesterId, requesterDeviceId) => {
          // crypto.md #19: respond to NACK with SK re-distribution via 1:1 Double Ratchet
          await respondToSenderKeyRequest(groupId, requesterId, requesterDeviceId);
        }
      );
    })();

    return () => { cleanup?.(); };
  }, [groupId, resolvedUserId, e2ee.available, e2ee.deviceId]);

  // ── Persist ledger entry via /api/local-action ──
  const persistLedger = useCallback(async (entry: LedgerEntry) => {
    const token = getSupabaseToken();
    try {
      await fetch("/api/local-action", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          action: entry.action,
          groupId: entry.group_id,
          payload: entry.payload,
          previous: entry.previous,
          actorName: entry.actor_name,
        }),
      });
    } catch (err) {
      console.error("[local-action] failed:", err);
    }
  }, []);

  const handleLedgerUndo = useCallback(async (
    ledgerId: string,
    action: string,
    previous: Record<string, unknown>
  ) => {
    const token = getSupabaseToken();
    try {
      await fetch("/api/local-action", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          action: "revert",
          groupId,
          payload: { revert_target_id: ledgerId, revert_action: action, revert_previous: previous },
          actorName: user?.displayName ?? userName,
        }),
      });
    } catch (err) {
      console.error("[local-action] undo failed:", err);
    }
  }, [groupId, user, userName]);

  // ── Ledger Realtime subscription ──
  useEffect(() => {
    if (authLoading) return;

    const channel = supabase
      .channel(`ledger:${groupId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "space_ledger", filter: `group_id=eq.${groupId}` },
        (payload) => {
          const row = payload.new as Record<string, unknown>;
          setLedgerEvents((prev) => {
            if (prev.some((e) => e.id === row.id)) return prev;
            return [
              ...prev,
              {
                id: row.id as string,
                actorName: (row.actor_name as string) ?? "someone",
                action: row.action as string,
                payload: (row.payload as Record<string, unknown>) ?? {},
                previous: (row.previous as Record<string, unknown>) ?? {},
                revertTargetId: row.revert_target_id as string | undefined,
                timestamp: new Date(row.created_at as string).getTime(),
              },
            ];
          });
        }
      )
      .subscribe();

    // Fetch existing ledger events
    supabase
      .from("space_ledger")
      .select("*")
      .eq("group_id", groupId)
      .order("created_at", { ascending: true })
      .then(({ data }) => {
        if (data) {
          setLedgerEvents(
            data.map((row: Record<string, unknown>) => ({
              id: row.id as string,
              actorName: (row.actor_name as string) ?? "someone",
              action: row.action as string,
              payload: (row.payload as Record<string, unknown>) ?? {},
              previous: (row.previous as Record<string, unknown>) ?? {},
              revertTargetId: row.revert_target_id as string | undefined,
              timestamp: new Date(row.created_at as string).getTime(),
            }))
          );
        }
      });

    return () => { supabase.removeChannel(channel); };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId, authLoading]);

  // ── Send queue — prevents rapid-fire concurrent sends that desync SK chain ──
  const sendQueueRef = useRef<Promise<void>>(Promise.resolve());
  const isSendingRef = useRef(false);

  // ── Media upload concurrency counter ──
  // Unlike text sends (which must serialize for SK chain integrity), media uploads
  // are independent: each gets its own AES key, so concurrent uploads are safe.
  // The ref tracks in-flight count instead of a boolean gate, allowing rapid-fire.
  const mediaUploadsInFlight = useRef(0);

  // ── Send message — works from any view, pure E2EE when available ──
  const sendMessage = useCallback(async () => {
    const txt = input.trim();
    if (!txt) return;

    // Guard: must have authenticated userId for RLS INSERT
    if (!resolvedUserId) {
      return;
    }

    // Synchronous guard — useRef is instant, unlike React state
    if (isSendingRef.current) {
      // Queue this send behind the current one
      const captured = txt;
      setInput("");
      sendQueueRef.current = sendQueueRef.current.then(async () => {
        // Re-invoke with queued text after previous send completes
        // This is handled by the optimistic message appearing immediately below
      });
      return;
    }
    isSendingRef.current = true;

    const token = getSupabaseToken();

    // ── @hello INTERCEPT — Phantom Receipt Architecture ──
    // @hello commands are NOT encrypted. They route directly to /api/hello.
    // The server drops a phantom receipt into the timeline. AI results go to DecisionBoard.
    // This preserves E2EE purity: human messages never touch the AI endpoint.
    if (txt.toLowerCase().startsWith("@hello")) {
      // Show user's query in the chat timeline (optimistic — same as normal messages)
      const helloQueryMsg: ChatMessage = {
        id: generateId(),
        role: "user",
        content: txt,
        timestamp: Date.now(),
        senderName: user?.displayName ?? userName,
        userId: resolvedUserId,
        messageType: "helloQuery",
      };
      setMessages((prev) => [...prev, helloQueryMsg]);
      setInput("");
      setIsThinking(true);

      // Safety: clear thinking after 30s if no @hello response
      if (thinkingTimerRef.current) clearTimeout(thinkingTimerRef.current);
      thinkingTimerRef.current = setTimeout(() => setIsThinking(false), 30_000);

      if (token) {
        fetch("/api/hello", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            message: txt,
            groupId,
            userId: resolvedUserId,
          }),
        })
          .catch((err) => {
            console.warn("[hello] AI invocation failed:", err);
            setIsThinking(false);
            if (thinkingTimerRef.current) { clearTimeout(thinkingTimerRef.current); thinkingTimerRef.current = null; }
          });
        // Don't clear thinking here — Realtime handler clears it when @hello message arrives
      } else {
        setIsThinking(false);
        if (thinkingTimerRef.current) { clearTimeout(thinkingTimerRef.current); thinkingTimerRef.current = null; }
      }
      isSendingRef.current = false;
      return;
    }

    const userMsg: ChatMessage = {
      id: generateId(),
      role: "user",
      content: txt,
      timestamp: Date.now(),
      senderName: user?.displayName ?? userName,
      userId: resolvedUserId,
      senderDeviceId: e2ee.deviceId ?? undefined,
      messageType: e2ee.available ? "e2ee" : "legacy",
      deliveryStatus: 'queued' as const,
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput("");

    const SEND_TIMEOUT_MS = 15_000;
    const sendTimeout = setTimeout(() => {
      // Safety timeout for message send — not AI thinking
      setMessages((prev) =>
        prev.map((m) =>
          m.id === userMsg.id ? { ...m, content: "[send timed out — tap to retry]" } : m
        )
      );
    }, SEND_TIMEOUT_MS);

    try {
      // ── Constraint detection (sender's device only) ──
      const constraint = detectConstraints(txt);
      if (constraint) {
        setConstraintWhisper(constraint);
      }

      // ══════════════════════════════════════════════
      // E2EE PATH — encrypt + /api/message
      // ══════════════════════════════════════════════
      if (e2ee.available) {
        try {
          // ── LINK PREVIEW PIPELINE ──
          // If a link preview is pending, encrypt its og:image (if any) and build the payload
          let linkPreviewPayload: {
            url: string; title?: string; description?: string; mediaUrl?: string;
            aesKeyBase64?: string; ivBase64?: string; mimeType?: string; inlineThumbnail?: string;
          } | undefined;

          if (pendingLinkPreview) {
            const lp = pendingLinkPreview;
            linkPreviewPayload = {
              url: lp.url,
              title: lp.title ?? undefined,
              description: lp.description ?? undefined,
            };

            // If the preview has an og:image, encrypt it through the media pipeline
            if (lp.imageBase64) {
              try {
                // Convert data:image Base64 to Blob without fetch() (avoids CSP connect-src block)
                const [header, b64Data] = lp.imageBase64.split(',');
                const imgMime = header?.match(/data:([^;]+)/)?.[1] || 'image/jpeg';
                const binary = atob(b64Data);
                const bytes = new Uint8Array(binary.length);
                for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
                const imgBlob = new Blob([bytes], { type: imgMime });

                // Generate thumbnail from the og:image
                const { generateInlineThumbnail } = await import("@/lib/media/thumbnail-generator");
                const imgFile = new File([imgBlob], 'og-image', { type: imgMime });
                const thumb = await generateInlineThumbnail(imgFile);

                // Encrypt the og:image
                const { encryptFile } = await import("@/lib/crypto/file-encryption");
                const { encryptedBlob, aesKeyBase64: imgKey, ivBase64: imgIv } = await encryptFile(imgFile);

                // Upload encrypted og:image to Firebase
                const { storageAdapter } = await import("@/lib/storage");
                const ogMediaId = `og_${crypto.randomUUID()}`;
                const ogPath = `spaces/${groupId}/media/${ogMediaId}.enc`;
                const ogDownloadUrl = await storageAdapter.upload(ogPath, encryptedBlob, 'application/octet-stream');

                linkPreviewPayload.mediaUrl = ogDownloadUrl;
                linkPreviewPayload.aesKeyBase64 = imgKey;
                linkPreviewPayload.ivBase64 = imgIv;
                linkPreviewPayload.mimeType = imgMime;
                if (thumb) linkPreviewPayload.inlineThumbnail = thumb;
              } catch (err) {
                console.warn("[link-preview] og:image encryption failed:", err);
                // Non-fatal — send preview without image
              }
            }

            // Attach to optimistic message
            userMsg.linkPreview = linkPreviewPayload;
            // Update state with linkPreview on the optimistic message
            setMessages((prev) =>
              prev.map((m) => m.id === userMsg.id ? { ...m, linkPreview: linkPreviewPayload } : m)
            );
            setPendingLinkPreview(null);
          }

          const envelope = await e2ee.encrypt(txt, groupId, undefined, linkPreviewPayload);
          if (envelope) {
            // FIX: Sender-Side Amnesia Route. Cache plaintext instantly to survive reload.
            const { keyStore } = await import("@/lib/crypto/keystore");
            await keyStore.saveDecryptedMessage(userMsg.id, txt);

            const res = await fetch("/api/message", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
              },
              body: JSON.stringify({
                id: userMsg.id,
                group_id: groupId,
                sender_device_id: e2ee.deviceId,
                ciphertext: envelope.ciphertext,
                ratchet_header: envelope.ratchetHeader ?? null,
                recipient_id: envelope.recipientId,
                recipient_device_id: envelope.recipientDeviceId,
                ...(envelope.distributionCiphertexts?.length
                  ? { distribution_ciphertexts: envelope.distributionCiphertexts }
                  : {}),
              }),
            });

            const data = await res.json();

            if (!res.ok) {
              console.error("[hello-e2ee] /api/message failed:", data.error);
              // Queue for automatic retry instead of just showing error
              const { enqueueMessage } = await import("@/lib/crypto/outbox");
              await enqueueMessage({
                id: userMsg.id,
                groupId,
                envelope: {
                  ciphertext: envelope.ciphertext,
                  ratchetHeader: envelope.ratchetHeader,
                  recipientId: envelope.recipientId,
                  recipientDeviceId: envelope.recipientDeviceId,
                },
                senderDeviceId: e2ee.deviceId!,
                createdAt: Date.now(),
                attempts: 1,
                distributionCiphertexts: envelope.distributionCiphertexts,
              });
              // Commit ratchet — message IS encrypted and queued, will be sent on retry
              if (envelope.commit) await envelope.commit();
              setMessages((prev) =>
                prev.map((m) =>
                  m.id === userMsg.id ? { ...m, content: "[queued — will send when online]" } : m
                )
              );
              setIsThinking(false);
              return;
            } else {
              // TWO-PHASE COMMIT: persist ratchet state only after network ACK
              if (envelope.commit) await envelope.commit();

              // PRIORITY 3: Server confirmed all DB writes (message + ciphertexts +
              // distribution rows) are committed before returning 200. Safe to broadcast.
              if (data.distribution_written) {
                console.log('[hello-e2ee] Distribution confirmed written before broadcast');
              }

              // Broadcast for instant delivery (after DB write)
              if (channelRef.current) {
                broadcastMessage(channelRef.current, {
                  id: userMsg.id,
                  group_id: groupId,
                  role: "user",
                  content: null as unknown as string,
                  user_id: resolvedUserId ?? null,
                  sender_name: user?.displayName ?? userName ?? null,
                  created_at: new Date().toISOString(),
                  message_type: "e2ee",
                  sender_device_id: e2ee.deviceId,
                  ciphertext_b64: envelope.ciphertext,
                  ratchet_header_b64: envelope.ratchetHeader ?? null,
                });
              }

              // P4.5: Update delivery status to 'sent' (server ACK received)
              setMessages((prev) =>
                prev.map((m) => m.id === userMsg.id ? { ...m, deliveryStatus: 'sent' as const } : m)
              );

              setIsThinking(false);
              return;
            }
          }
        } catch (err) {
          console.error("[hello-e2ee] Encrypt failed — message NOT sent (fail-closed):", err);
          setMessages((prev) =>
            prev.map((m) =>
              m.id === userMsg.id ? { ...m, content: "[encryption failed — tap to retry]" } : m
            )
          );
          setIsThinking(false);
          return;
        }
      }

      // ══════════════════════════════════════════════
      // FAIL-CLOSED: E2EE not available — refuse to send plaintext
      // ══════════════════════════════════════════════
      if (!e2ee.available) {
        console.error("[hello-e2ee] E2EE not available — refusing to send plaintext");
        setMessages((prev) =>
          prev.map((m) =>
            m.id === userMsg.id
              ? { ...m, content: "[encryption unavailable — check your connection]" }
              : m
          )
        );
        setIsThinking(false);
        return;
      }

      setIsThinking(false);
    } finally {
      clearTimeout(sendTimeout);
      isSendingRef.current = false;
    }
  }, [input, groupId, resolvedUserId, user, userName, e2ee]);

  // ═══════════════════════════════════════════
  // SPACE METADATA
  // ═══════════════════════════════════════════

  // ── Fetch space title (after auth resolves for RLS) ──
  useEffect(() => {
    if (authLoading) return;
    async function loadTitle() {
      try {
        const { data } = await supabase
          .from("spaces")
          .select("title,groupType")
          .eq("id", groupId)
          .maybeSingle();
        
        if (data?.type) {
          setGroupType(data.type);
        }

        if (data?.type === "dm" && resolvedUserId) {
          const { data: otherMember } = await supabase
            .from("space_members")
            .select("user_id")
            .eq("group_id", groupId)
            .neq("user_id", resolvedUserId)
            .limit(1)
            .maybeSingle();
          if (otherMember?.user_id) {
            const { data: otherUser } = await supabase
              .from("users")
              .select("display_name, phone")
              .eq("id", otherMember.user_id)
              .maybeSingle();
            if (otherUser) {
              // Signal Hybrid: check local contact cache first, then server name
              const { resolveDisplayName } = await import("@/hooks/useDisplayName");
              const resolved = await resolveDisplayName(otherUser.display_name, otherUser.phone);
              setSpaceTitle(resolved);
              return;
            }
          }
        }

        if (data?.title) {
          let displayTitle = data.title;
          if (displayTitle && user?.displayName) {
            const parts = displayTitle.split(/&|,/).map((s: string) => s.trim());
            const filtered = parts.filter((p: string) => p.toLowerCase() !== user.displayName!.toLowerCase());
            if (filtered.length > 0) displayTitle = filtered.join(" & ");
            // Fallback: if somehow empty, leave as is or take first
            else if (parts.length > 0) displayTitle = parts[0];
          }
          setSpaceTitle(displayTitle);
          return;
        }
      } catch {
        // fallthrough
      }
      setSpaceTitle(
        DEMO_TITLES[groupId] ??
          groupId.replace(/^space_/, "").replace(/-/g, " ")
      );
    }
    loadTitle();
  }, [groupId, authLoading, resolvedUserId]);

  // ── Fetch decision items for space state computation (after auth resolves) ──
  useEffect(() => {
    if (authLoading) return;
    async function loadItems() {
      try {
        const { data } = await supabase
          .from("decision_items")
          .select("state, is_locked, category, metadata")
          .eq("group_id", groupId)
          .limit(200);
        if (data) setSpaceItems(data as GroupStateItem[]);
      } catch {
        // Silent — demo fallback stays empty
      }
    }
    loadItems();
  }, [groupId, authLoading]);

  const spaceState = computeGroupState(spaceItems);
  const showItinerary =
    spaceState === "ready" ||
    spaceState === "active" ||
    spaceState === "settled";
  const isSettled = spaceState === "settled";

  useEffect(() => {
    if (isSettled) setView("memories");
  }, [isSettled]);

  // ── Invite flow ──
  useEffect(() => {
    if (!isInvite || authLoading) return;

    if (!isAuthenticated) {
      const returnUrl = `/space/${groupId}?invite=true${userName ? `&name=${encodeURIComponent(userName)}` : ""}`;
      router.replace(`/login?returnTo=${encodeURIComponent(returnUrl)}`);
      return;
    }

    async function joinSpace() {
      setJoining(true);
      try {
        await supabase.rpc("join_via_invite", { p_group_id: groupId });
      } catch {
        // Silently handle — user may already be a member
      } finally {
        setJoining(false);
        const newParams = new URLSearchParams(searchParams.toString());
        newParams.delete("invite");
        const remaining = newParams.toString();
        router.replace(
          `/space/${groupId}${remaining ? `?${remaining}` : ""}`
        );
      }
    }
    joinSpace();
  }, [
    isInvite,
    isAuthenticated,
    authLoading,
    groupId,
    userName,
    router,
    searchParams,
  ]);

  // ── Share action ──
  const [showShareOptions, setShowShareOptions] = useState(false);

  const handleShare = useCallback(async () => {
    // Generate a proper invite link via /api/invite (creates a cryptographic deep link)
    try {
      const { generateAndShareInvite } = await import("@/components/os/InviteSurface");
      await generateAndShareInvite(user?.displayName ?? userName ?? "someone");
    } catch {
      // User cancelled share or generation failed — try clipboard fallback with space URL
      const fallbackUrl = `${window.location.origin}/space/${groupId}`;
      try {
        await navigator.clipboard.writeText(fallbackUrl);
        setShareWhisper(true);
        setTimeout(() => setShareWhisper(false), 2000);
      } catch { /* silent */ }
    }
  }, [groupId, user, userName]);

  // Fallback share text for WhatsApp/SMS options (when native share was cancelled)
  const shareUrl = `${typeof window !== "undefined" ? window.location.origin : ""}/space/${groupId}`;
  const shareText = `join ${spaceTitle || "this space"} on hello: ${shareUrl}`;

  // ── Joining whisper ──
  if (joining) {
    return (
      <div
        className="flex min-h-svh items-center justify-center"
        style={{ background: colors.void }}
      >
        <p style={{ ...text.hint, color: ink.tertiary }}>
          joining space...
        </p>
      </div>
    );
  }

  // ── PLAYGROUND MODE — after all hooks, safe early return ──
  if (isPlayground) {
    return <PlaygroundSpace groupId={groupId} userName={userName ?? "you"} />;
  }

  return (
    <div className="relative min-h-svh" style={{ background: colors.void }}>
      {/* ── Background gradient shift — warm on discuss, cool on decide ── */}
      <motion.div
        animate={{
          background: view === "discuss"
            ? "radial-gradient(circle at 30% 60%, rgba(255,107,53,0.04), transparent 60%)"
            : view === "decide"
            ? "radial-gradient(circle at 70% 40%, rgba(64,224,255,0.04), transparent 60%)"
            : "none",
        }}
        transition={{ duration: 1, ease: [0.16, 1, 0.3, 1] }}
        style={{ position: "fixed", inset: 0, pointerEvents: "none", zIndex: 0 }}
      />
      {/* ── Header: title + view toggle + share ── */}
      <div
        className="fixed inset-x-0 top-0 z-30 px-6 pb-0"
        style={{
          paddingTop: "env(safe-area-inset-top, 0px)",
          background: colors.void,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          <div className="flex items-center gap-3" style={{ paddingTop: "4px", paddingBottom: "2px" }}>
            <button
              onClick={() => router.push(`/galaxy?name=${encodeURIComponent(userName ?? '')}`)}
              className="outline-none"
              style={{ fontSize: "28px", color: ink.primary, lineHeight: 1 }}
            >
              ‹
            </button>
            <Avatar name={spaceTitle} size={28} />
            <p
              style={{
                fontSize: "17px",
                fontWeight: 400,
                letterSpacing: "-0.01em",
                color: colors.white,
                margin: 0,
                flex: 1,
                overflow: "hidden",
                textOverflow: "ellipsis",
                whiteSpace: "nowrap",
              }}
            >
              {spaceTitle}
            </p>
          </div>

          <div className="mt-3 flex items-center justify-between relative">
            <div className="flex items-center gap-6">
              <span
                role="button"
                tabIndex={0}
                onClick={() => setView("discuss")}
                onKeyDown={(e) => {
                  if (e.key === "Enter") setView("discuss");
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: view === "discuss" ? colors.cyan : ink.secondary,
                  cursor: "pointer",
                  transition: `color ${timing.transition} ease`,
                  position: "relative",
                  opacity: view === "discuss" ? 1 : 0.6,
                }}
              >
                discuss
                {view === "discuss" && (
                  <motion.span
                    layoutId="space-tab-pill"
                    style={{
                      position: "absolute", bottom: "-4px", left: 0,
                      width: "100%", height: "2px",
                      background: colors.cyan, opacity: 0.6,
                    }}
                    transition={{ type: "spring", stiffness: 300, damping: 25 }}
                  />
                )}
              </span>
              <>
                  <span
                    role="button"
                    tabIndex={0}
                    onClick={() => setView("decide")}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") setView("decide");
                    }}
                    className="outline-none"
                    style={{
                      ...text.label,
                      color: view === "decide" ? colors.cyan : ink.secondary,
                      cursor: "pointer",
                      transition: `color ${timing.transition} ease`,
                      position: "relative",
                      opacity: view === "decide" ? 1 : 0.6,
                    }}
                  >
                    decide
                    {view === "decide" && (
                      <motion.span
                        layoutId="space-tab-pill"
                        style={{
                          position: "absolute", bottom: "-4px", left: 0,
                          width: "100%", height: "2px",
                          background: colors.cyan, opacity: 0.6,
                        }}
                        transition={{ type: "spring", stiffness: 300, damping: 25 }}
                      />
                    )}
                  </span>
                  {showItinerary && !isSettled && (
                    <span
                      role="button"
                      tabIndex={0}
                      onClick={() => setView("itinerary")}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") setView("itinerary");
                      }}
                      className="outline-none"
                      style={{
                        ...text.label,
                        color: view === "itinerary" ? colors.cyan : ink.secondary,
                        cursor: "pointer",
                        transition: `color ${timing.transition} ease`,
                        position: "relative",
                        opacity: view === "itinerary" ? 1 : 0.6,
                      }}
                    >
                      itinerary
                      {view === "itinerary" && (
                        <motion.span
                          layoutId="space-tab-pill"
                          style={{
                            position: "absolute", bottom: "-4px", left: 0,
                            width: "100%", height: "2px",
                            background: colors.cyan, opacity: 0.6,
                          }}
                          transition={{ type: "spring", stiffness: 300, damping: 25 }}
                        />
                      )}
                    </span>
                  )}
                  {isSettled && (
                    <span
                      role="button"
                      tabIndex={0}
                      onClick={() => setView("memories")}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") setView("memories");
                      }}
                      className="outline-none"
                      style={{
                        ...text.label,
                        color: view === "memories" ? colors.cyan : ink.secondary,
                        cursor: "pointer",
                        transition: `color ${timing.transition} ease`,
                        position: "relative",
                        opacity: view === "memories" ? 1 : 0.6,
                      }}
                    >
                      memories
                      {view === "memories" && (
                        <motion.span
                          layoutId="space-tab-pill"
                          style={{
                            position: "absolute", bottom: "-4px", left: 0,
                            width: "100%", height: "2px",
                            background: colors.cyan, opacity: 0.6,
                          }}
                          transition={{ type: "spring", stiffness: 300, damping: 25 }}
                        />
                      )}
                    </span>
                  )}
                </>
            </div>

            {type !== "dm" && (
              <span
                role="button"
                tabIndex={0}
                onClick={handleShare}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleShare();
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: shareWhisper ? ink.secondary : ink.tertiary,
                  cursor: "pointer",
                  transition: `color ${timing.transition} ease`,
                }}
              >
                {shareWhisper ? "link copied" : "share"}
              </span>
            )}
          </div>

          <div
            className="mt-3"
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: 0.15,
            }}
          />
        </div>
      </div>

      {/* ── View content — swipe left/right to switch discuss ↔ decide ── */}
      <div onTouchStart={handleSwipeStart} onTouchEnd={handleSwipeEnd}>
      {view === "discuss" && <ConsensusBanner groupId={groupId} />}
      {view === "discuss" && (
        <HelloChat
          groupId={groupId}
          spaceTitle={spaceTitle}
          messages={messages}
          isThinking={isThinking}
          e2eeActive={e2ee.available}
          ledgerEvents={ledgerEvents}
          onLedgerUndo={handleLedgerUndo}
          onInvite={handleShare}
          memberCount={memberCount}
          currentUserId={resolvedUserId}
          currentUserName={user?.displayName ?? userName ?? undefined}
          currentDeviceId={e2ee.deviceId ?? undefined}
        />
      )}
      <div className={view === 'decide' ? 'block' : 'hidden'}
        onTouchStart={(e) => e.stopPropagation()}
        onTouchEnd={(e) => e.stopPropagation()}
        style={{
          position: "fixed",
          inset: 0,
          top: "calc(env(safe-area-inset-top, 0px) + 80px)",
          bottom: "68px",
          zIndex: 10,
        }}
      >
        <DecisionBoard groupId={groupId} userId={resolvedUserId} authLoading={authLoading} isThinking={isThinking} />
      </div>
      {view === "itinerary" && <ItineraryView groupId={groupId} />}
      {view === "memories" && <MemoriesView groupId={groupId} />}
      </div>

      {/* ── Share options — WhatsApp, SMS, copy link ── */}
      {showShareOptions && (
        <>
          <div
            className="fixed inset-0 z-40"
            style={{ background: "rgba(0,0,0,0.5)" }}
            onClick={() => setShowShareOptions(false)}
          />
          <div
            className="fixed inset-x-0 bottom-0 z-50 px-6 pb-12 pt-8"
            style={{ background: surface.chrome }}
          >
            <div className="mx-auto" style={{ maxWidth: "640px" }}>
              <p style={{ ...text.subtitle, color: ink.secondary, marginBottom: "20px" }}>
                invite to {spaceTitle || "this space"}
              </p>

              {/* WhatsApp */}
              <a
                href={`https://wa.me/?text=${encodeURIComponent(shareText)}`}
                target="_blank"
                rel="noopener noreferrer"
                className="outline-none"
                style={{
                  display: "flex", alignItems: "center", gap: "14px",
                  padding: "14px 0", color: ink.primary,
                  textDecoration: "none",
                }}
              >
                <svg width="22" height="22" viewBox="0 0 24 24" fill="#25D366">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                </svg>
                <span style={{ fontSize: "16px", fontWeight: 400 }}>whatsapp</span>
              </a>

              {/* SMS / iMessage */}
              <a
                href={`sms:?body=${encodeURIComponent(shareText)}`}
                className="outline-none"
                style={{
                  display: "flex", alignItems: "center", gap: "14px",
                  padding: "14px 0", color: ink.primary,
                  textDecoration: "none",
                }}
              >
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
                </svg>
                <span style={{ fontSize: "16px", fontWeight: 400 }}>text message</span>
              </a>

              {/* Copy link */}
              <div
                role="button"
                tabIndex={0}
                onClick={async () => {
                  try {
                    if (navigator.clipboard?.writeText) {
                      await navigator.clipboard.writeText(shareUrl);
                    } else {
                      const ta = document.createElement("textarea");
                      ta.value = shareUrl;
                      ta.style.position = "fixed";
                      ta.style.opacity = "0";
                      document.body.appendChild(ta);
                      ta.select();
                      document.execCommand("copy");
                      document.body.removeChild(ta);
                    }
                  } catch { /* */ }
                  setShowShareOptions(false);
                  setShareWhisper(true);
                  setTimeout(() => setShareWhisper(false), 2000);
                }}
                className="cursor-pointer outline-none"
                style={{
                  display: "flex", alignItems: "center", gap: "14px",
                  padding: "14px 0", color: ink.primary,
                }}
              >
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                  <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
                </svg>
                <span style={{ fontSize: "16px", fontWeight: 400 }}>copy link</span>
              </div>

              {/* Cancel */}
              <div
                role="button"
                tabIndex={0}
                onClick={() => setShowShareOptions(false)}
                className="cursor-pointer outline-none"
                style={{
                  padding: "14px 0", marginTop: "8px",
                  color: ink.tertiary, fontSize: "14px", fontWeight: 300,
                  textAlign: "center",
                }}
              >
                cancel
              </div>
            </div>
          </div>
        </>
      )}

      {/* ── Constraint whisper — detected from encrypted message text ── */}
      {constraintWhisper && (
        <div
          className="fixed inset-x-0 z-20 mx-auto px-6"
          style={{
            bottom: "80px",
            maxWidth: "640px",
          }}
        >
          <div
            className="flex items-center justify-between py-2 px-3"
            style={{
              background: "rgba(var(--hello-accent-rgb), 0.08)",
              borderRadius: "8px",
            }}
          >
            <p style={{ ...text.hint, color: ink.secondary }}>
              detected: <span style={{ color: colors.cyan }}>{constraintWhisper.type}</span>{" "}
              ({constraintWhisper.value})
            </p>
            <div className="flex items-center gap-4">
              <span
                role="button"
                tabIndex={0}
                onClick={() => {
                  // Save constraint (fire-and-forget)
                  if (resolvedUserId) {
                    import("@/lib/constraints").then(({ saveConstraint }) =>
                      saveConstraint(constraintWhisper, resolvedUserId, groupId).catch(() => {})
                    );
                  }
                  setConstraintWhisper(null);
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter") setConstraintWhisper(null);
                }}
                className="outline-none cursor-pointer"
                style={{ ...text.hint, color: colors.cyan }}
              >
                save
              </span>
              <span
                role="button"
                tabIndex={0}
                onClick={() => setConstraintWhisper(null)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") setConstraintWhisper(null);
                }}
                className="outline-none cursor-pointer"
                style={{ ...text.hint, color: ink.tertiary }}
              >
                dismiss
              </span>
            </div>
          </div>
        </div>
      )}

      {/* ── ChatInput — always visible, draft persists across views ── */}
      <ChatInput
        input={input}
        onInputChange={(val) => {
          // Auto-trigger: "@hello " typed → open HelloPanel
          if (val.toLowerCase() === "@hello " || val.toLowerCase() === "@hello") {
            setInput("");
            setHelloPanelOpen(true);
            return;
          }
          setInput(val);
        }}
        onSend={sendMessage}
        isThinking={isThinking}
        pendingLinkPreview={pendingLinkPreview}
        onLinkPreviewReady={setPendingLinkPreview}
        onHelloTap={() => setHelloPanelOpen(true)}
        onMediaSelected={async (file) => {
          // ── CONCURRENT MEDIA UPLOAD ──
          // Unlike text sends, media uploads are independent (each gets its own AES key).
          // No isThinking gate — multiple files can upload in parallel.
          // The ref counter tracks in-flight uploads for the thinking indicator.
          if (!resolvedUserId || !e2ee.available) return;

          mediaUploadsInFlight.current++;
          setIsThinking(true);

          try {
            // ── E2EE MEDIA PIPELINE: encrypt locally -> upload encrypted blob -> send key via E2EE ──
            const mimeType = file.type || 'application/octet-stream';

            // Generate tiny inline thumbnail BEFORE encryption (from raw file)
            const { generateInlineThumbnail } = await import("@/lib/media/thumbnail-generator");
            const inlineThumbnail = await generateInlineThumbnail(file);

            const { encryptFile } = await import("@/lib/crypto/file-encryption");
            const { encryptedBlob, aesKeyBase64, ivBase64 } = await encryptFile(file);

            // Upload encrypted blob to Firebase (server never sees plaintext)
            const { storageAdapter } = await import("@/lib/storage");
            const mediaId = `media_${crypto.randomUUID()}`;
            const storagePath = `spaces/${groupId}/media/${mediaId}.enc`;
            const downloadUrl = await storageAdapter.upload(storagePath, encryptedBlob, 'application/octet-stream');

            // Build optimistic message — appears immediately in sender's chat
            const mediaMsg: ChatMessage = {
              id: generateId(),
              role: "user",
              content: file.name || "sent a photo",
              timestamp: Date.now(),
              senderName: user?.displayName ?? userName,
              userId: resolvedUserId,
              senderDeviceId: e2ee.deviceId ?? undefined,
              messageType: "e2ee",
              deliveryStatus: 'queued',
              mediaUrl: downloadUrl,
              aesKeyBase64,
              ivBase64,
              mimeType,
              ...(inlineThumbnail && { inlineThumbnail }),
            };
            setMessages((prev) => [...prev, mediaMsg]);

            // Encrypt with media metadata — acquireSenderKeyLock serializes per-space
            // so concurrent uploads queue here correctly for SK chain integrity
            const envelope = await e2ee.encrypt(
              mediaMsg.content,
              groupId,
              { mediaUrl: downloadUrl, aesKeyBase64, ivBase64, mimeType, ...(inlineThumbnail && { inlineThumbnail }) }
            );

            if (!envelope) {
              setMessages((prev) =>
                prev.map((m) => m.id === mediaMsg.id ? { ...m, content: "[encryption failed]" } : m)
              );
              return;
            }

            // Cache plaintext + media metadata locally (sender can't self-decrypt SK)
            const { keyStore } = await import("@/lib/crypto/keystore");
            await keyStore.saveDecryptedMessage(mediaMsg.id, mediaMsg.content);
            await keyStore.saveDecryptedMedia(mediaMsg.id, {
              text: mediaMsg.content,
              mediaUrl: downloadUrl,
              aesKeyBase64,
              ivBase64,
              mimeType,
              ...(inlineThumbnail && { inlineThumbnail }),
            });

            const token = getSupabaseToken();
            const res = await fetch("/api/message", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
              },
              body: JSON.stringify({
                id: mediaMsg.id,
                group_id: groupId,
                sender_device_id: e2ee.deviceId,
                ciphertext: envelope.ciphertext,
                ratchet_header: envelope.ratchetHeader ?? null,
                recipient_id: envelope.recipientId,
                recipient_device_id: envelope.recipientDeviceId,
                ...(envelope.distributionCiphertexts?.length
                  ? { distribution_ciphertexts: envelope.distributionCiphertexts }
                  : {}),
              }),
            });

            if (res.ok) {
              if (envelope.commit) await envelope.commit();
              // Broadcast for instant delivery
              if (channelRef.current) {
                broadcastMessage(channelRef.current, {
                  id: mediaMsg.id,
                  group_id: groupId,
                  role: "user",
                  content: null as unknown as string,
                  user_id: resolvedUserId ?? null,
                  sender_name: user?.displayName ?? userName ?? null,
                  created_at: new Date().toISOString(),
                  message_type: "e2ee",
                  sender_device_id: e2ee.deviceId,
                  ciphertext_b64: envelope.ciphertext,
                  ratchet_header_b64: envelope.ratchetHeader ?? null,
                });
              }
              setMessages((prev) =>
                prev.map((m) => m.id === mediaMsg.id ? { ...m, deliveryStatus: 'sent' as const } : m)
              );
            } else {
              console.error("[media] /api/message failed");
              setMessages((prev) =>
                prev.map((m) => m.id === mediaMsg.id ? { ...m, content: "[send failed — tap to retry]" } : m)
              );
            }
          } catch (err) {
            console.warn("[media] E2EE upload failed:", err);
          } finally {
            mediaUploadsInFlight.current--;
            // Only clear thinking when ALL concurrent uploads are done
            if (mediaUploadsInFlight.current <= 0) {
              mediaUploadsInFlight.current = 0;
              setIsThinking(false);
            }
          }
        }}
      />

      {/* ═══ HELLO PANEL — Raycast-style slot-filling AI invocation ═══ */}
      <HelloPanel
        open={helloPanelOpen}
        onClose={() => setHelloPanelOpen(false)}
        spaceTitle={spaceTitle}
        onSwitchToDecide={() => setView("decide")}
        onSubmit={async (payload: HelloPanelPayload) => {
          if (!resolvedUserId) return { response: "not logged in" };

          try {
            const token = getSupabaseToken();
            const res = await fetch("/api/hello", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
              },
              body: JSON.stringify({
                message: payload.rawMessage,
                groupId,
                userId: resolvedUserId,
                slotPayload: {
                  source: payload.source,
                  intent: payload.intent,
                  confidence: payload.confidence,
                  params: payload.params,
                },
                silent: true, // Tell API to NOT write phantom receipt to chat
              }),
            });

            if (!res.ok) {
              return { response: "search failed. try again." };
            }

            const data = await res.json();
            return {
              response: data.response || "done.",
              results: data.searchResults || [],
            };
          } catch {
            return { response: "something went wrong." };
          }
        }}
      />
    </div>
  );
}

export default function SpacePage() {
  return (
    <Suspense>
      <SpacePageInner />
    </Suspense>
  );
}
