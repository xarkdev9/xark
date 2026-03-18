"use client";

// XARK OS v2.0 — Space View
// Discuss (chat) + Decide (visual stream) toggle.
// Chat state (messages, draft input) lives HERE — persists across view switches.
// ChatInput is always visible. XarkChat is display-only.

import { useState, useEffect, useCallback, useRef, Suspense } from "react";
import { motion } from "framer-motion";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import { XarkChat } from "@/components/os/XarkChat";
import { PossibilityHorizon } from "@/components/os/PossibilityHorizon";
import { ItineraryView } from "@/components/os/ItineraryView";
import { MemoriesView } from "@/components/os/MemoriesView";
import { ChatInput } from "@/components/os/ChatInput";
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
import { computeSpaceState } from "@/lib/space-state";
import { useE2EE } from "@/hooks/useE2EE";
import { detectConstraints } from "@/lib/constraints";
import type { DetectedConstraint } from "@/lib/crypto/types";
import type { SpaceStateItem } from "@/lib/space-state";
import { colors, ink, text, textColor, timing, surface } from "@/lib/theme";
import type { LedgerEntry } from "@/lib/local-agent";
import type { LedgerEvent } from "@/components/os/LedgerPill";
import { markSpaceRead } from "@/lib/unread";
import { PlaygroundSpace } from "@/components/os/PlaygroundSpace";
import { isPlaygroundSpace } from "@/lib/playground";

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
  role: "user" | "xark" | "system";
  content: string;
  timestamp: number;
  senderName?: string;
  messageType?: string;  // 'e2ee' | 'xark' | 'system' | 'legacy'
}

type ViewMode = "discuss" | "decide" | "itinerary" | "memories";

function SpacePageInner() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const spaceId = params.id as string;
  const userName = searchParams.get("name") ?? undefined;
  const isInvite = searchParams.get("invite") === "true";

  // ── PLAYGROUND MODE — early return, no Supabase ──
  const isPlayground = searchParams.get("playground") === "true" && isPlaygroundSpace(spaceId);
  if (isPlayground) {
    return <PlaygroundSpace spaceId={spaceId} userName={userName ?? "you"} />;
  }

  const { user, isAuthenticated, isLoading: authLoading } = useAuth(userName);
  // CRITICAL: userId must come from authenticated user only (e.g., "name_ram"),
  // never from raw URL param (e.g., "ram"). RLS checks user_id = auth.jwt()->>'sub'.
  const resolvedUserId = user?.uid ?? undefined;

  const e2ee = useE2EE(resolvedUserId ?? null);

  const viewParam = searchParams.get("view");
  const [view, setView] = useState<ViewMode>(
    viewParam === "decide" ? "decide" : "discuss"
  );
  const [spaceTitle, setSpaceTitle] = useState<string>("");
  const [spaceItems, setSpaceItems] = useState<SpaceStateItem[]>([]);
  const [joining, setJoining] = useState(false);
  const [shareWhisper, setShareWhisper] = useState(false);
  const [constraintWhisper, setConstraintWhisper] = useState<DetectedConstraint | null>(null);
  const [memberCount, setMemberCount] = useState(0);

  // Fetch member count
  useEffect(() => {
    supabase.from("space_members").select("user_id", { count: "exact", head: true }).eq("space_id", spaceId)
      .then(({ count }) => { if (count !== null) setMemberCount(count); });
  }, [spaceId]);

  // ── Outbox drain — retry queued messages on reconnect / tab visible / mount ──
  useEffect(() => {
    if (!resolvedUserId) return;
    let cleanup: (() => void) | undefined;
    (async () => {
      const { startOutboxSync } = await import("@/lib/crypto/outbox");
      cleanup = startOutboxSync(
        (id) => console.log(`[xark-outbox] Sent queued message ${id}`),
        (id, err) => console.warn(`[xark-outbox] Permanently failed: ${id} — ${err}`)
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
  const [isThinking, setIsThinking] = useState(false);
  const messagesLoaded = useRef(false);
  const channelRef = useRef<RealtimeChannel | null>(null);

  // ── Fetch persisted messages AFTER auth resolves, then batch-decrypt E2EE ──
  useEffect(() => {
    if (authLoading || messagesLoaded.current) return;

    // BUG 9 fix: fetch ALL sender_key_dist messages first (not limited to 50)
    // Then fetch regular messages
    const fetchAllSkDist = async () => {
      try {
        const { data } = await supabase
          .from("messages")
          .select("id, space_id, role, content, user_id, sender_name, created_at, message_type, sender_device_id")
          .eq("space_id", spaceId)
          .eq("message_type", "sender_key_dist")
          .order("created_at", { ascending: true });
        return data ?? [];
      } catch { return []; }
    };

    Promise.all([fetchAllSkDist(), fetchMessages(spaceId, { limit: 50 })])
      .then(async ([skDistMsgs, persisted]) => {
        // Process SK dist messages first (before regular decrypt)
        if (e2ee.available && skDistMsgs.length > 0) {
          for (const dm of skDistMsgs) {
            try {
              const cts = await fetchCiphertexts([dm.id]);
              const myCt = cts.find(
                (ct) => ct.recipient_id === resolvedUserId ||
                  (ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_')
              );
              if (myCt && dm.user_id) {
                const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                await processSenderKeyDistribution(
                  dm.user_id, dm.sender_device_id ?? 0, spaceId, myCt.ciphertext, myCt.ratchet_header ?? ''
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
                (ct) => ct.recipient_id === resolvedUserId ||
                  (ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_')
              );
              if (myCt && dm.user_id) {
                const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
                await processSenderKeyDistribution(
                  dm.user_id,
                  dm.sender_device_id ?? 0,
                  spaceId,
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

            const decryptedMap = new Map<string, string>();
            for (const ct of ciphertexts) {
              try {
                const msg = e2eeMsgs.find((m) => m.id === ct.message_id);
                if (!msg) continue;
                const decrypted = await e2ee.decrypt(
                  ct.message_id,
                  msg.user_id ?? '',
                  msg.sender_device_id ?? null,
                  ct.ciphertext,
                  ct.ratchet_header,
                  ct.recipient_id,
                  spaceId
                );
                if (decrypted) {
                  decryptedMap.set(ct.message_id, decrypted.text);
                }
              } catch (err) {
                console.warn('[e2ee] Decrypt failed for', ct.message_id, err);
              }
            }

            // Merge decrypted text into messages
            if (decryptedMap.size > 0) {
              for (const m of mapped) {
                const decrypted = decryptedMap.get(m.id);
                if (decrypted) {
                  m.content = decrypted;
                }
              }
              setMessages([...mapped]);
            }
          }
        }

        messagesLoaded.current = true;
      })
      .catch(() => {
        messagesLoaded.current = true;
      });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [spaceId, authLoading, e2ee.available]);

  // ── Mark space as read when user opens it ──
  useEffect(() => {
    if (authLoading || !resolvedUserId) return;
    markSpaceRead(spaceId);
  }, [spaceId, authLoading, resolvedUserId]);

  // ── Broadcast channel — instant message delivery across devices ──
  useEffect(() => {
    const channel = subscribeToMessages(spaceId, async (incoming) => {
      // Sender Key distribution — process silently, don't display
      if (incoming.message_type === 'sender_key_dist') {
        if (e2ee.available && incoming.user_id) {
          try {
            // Fetch our ciphertext from DB (distribution has per-recipient rows)
            const cts = await fetchCiphertexts([incoming.id]);
            const myCt = cts.find(
              (ct) => ct.recipient_id === resolvedUserId ||
                (ct.recipient_device_id === e2ee.deviceId && ct.recipient_id !== '_group_')
            );
            if (myCt) {
              const { processSenderKeyDistribution } = await import("@/lib/crypto/encryption-service");
              await processSenderKeyDistribution(
                incoming.user_id,
                incoming.sender_device_id ?? 0,
                spaceId,
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
      const msgType = incoming.message_type ?? 'legacy';

      if (e2ee.available && msgType === 'e2ee') {
        if (incoming.ciphertext_b64) {
          try {
            const decrypted = await e2ee.decrypt(
              incoming.id,
              incoming.user_id ?? '',
              incoming.sender_device_id ?? null,
              incoming.ciphertext_b64,
              incoming.ratchet_header_b64 ?? null,
              '_group_', // broadcast messages are always group
              spaceId
            );
            if (decrypted) {
              content = decrypted.text;
            }
          } catch (err) {
            console.warn('[e2ee] Realtime decrypt failed:', err);
            content = '[decryption pending]';
          }
        } else {
          content = '[decryption pending]';
        }
      }

      setMessages((prev) => {
        if (prev.some((m) => m.id === incoming.id)) return prev;
        return [
          ...prev,
          {
            id: incoming.id,
            role: incoming.role,
            content,
            timestamp: new Date(incoming.created_at).getTime(),
            senderName: incoming.sender_name ?? undefined,
            messageType: msgType,
          },
        ];
      });
    });
    channelRef.current = channel;

    return () => {
      unsubscribeFromMessages(channel);
      channelRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [spaceId, e2ee.available, resolvedUserId]);

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
          spaceId: entry.space_id,
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
          spaceId,
          payload: { revert_target_id: ledgerId, revert_action: action, revert_previous: previous },
          actorName: user?.displayName ?? userName,
        }),
      });
    } catch (err) {
      console.error("[local-action] undo failed:", err);
    }
  }, [spaceId, user, userName]);

  // ── Ledger Realtime subscription ──
  useEffect(() => {
    if (authLoading) return;

    const channel = supabase
      .channel(`ledger:${spaceId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "space_ledger", filter: `space_id=eq.${spaceId}` },
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
      .eq("space_id", spaceId)
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
  }, [spaceId, authLoading]);

  // ── Send message — works from any view, pure E2EE when available ──
  const sendMessage = useCallback(async () => {
    const txt = input.trim();
    if (!txt) return;

    // Guard: must have authenticated userId for RLS INSERT
    if (!resolvedUserId) {
      addDebug("BLOCKED: no userId");
      return;
    }
    const token = getSupabaseToken();
    addDebug(`sending: "${txt.slice(0, 20)}" as ${resolvedUserId.slice(0, 15)} | jwt:${token ? 'yes' : 'NO'} | e2ee:${e2ee.available}`);

    // isThinking gate: blocks double-send while network request in flight
    if (isThinking) return;

    const userMsg: ChatMessage = {
      id: generateId(),
      role: "user",
      content: txt,
      timestamp: Date.now(),
      senderName: user?.displayName ?? userName,
      messageType: e2ee.available ? "e2ee" : "legacy",
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setIsThinking(true);

    // ── Constraint detection (sender's device only) ──
    const constraint = detectConstraints(txt);
    if (constraint) {
      setConstraintWhisper(constraint);
    }

    // ══════════════════════════════════════════════
    // E2EE PATH — encrypt + /api/message
    // ══════════════════════════════════════════════
    if (e2ee.available) {
      addDebug("E2EE PATH active — encrypting...");
      try {
        const envelope = await e2ee.encrypt(txt, spaceId);
        if (envelope) {
          const res = await fetch("/api/message", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
            body: JSON.stringify({
              space_id: spaceId,
              sender_device_id: e2ee.deviceId,
              ciphertext: envelope.ciphertext,
              ratchet_header: envelope.ratchetHeader ?? null,
              recipient_id: envelope.recipientId,
              recipient_device_id: envelope.recipientDeviceId,
            }),
          });

          const data = await res.json();

          if (!res.ok) {
            console.error("[xark-e2ee] /api/message failed:", data.error);
            // Queue for automatic retry instead of just showing error
            const { enqueueMessage } = await import("@/lib/crypto/outbox");
            await enqueueMessage({
              id: userMsg.id,
              spaceId,
              envelope: {
                ciphertext: envelope.ciphertext,
                ratchetHeader: envelope.ratchetHeader,
                recipientId: envelope.recipientId,
                recipientDeviceId: envelope.recipientDeviceId,
              },
              senderDeviceId: e2ee.deviceId!,
              createdAt: Date.now(),
              attempts: 1,
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

            // Broadcast for instant delivery (after DB write)
            if (channelRef.current) {
              broadcastMessage(channelRef.current, {
                id: userMsg.id,
                space_id: spaceId,
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

            setIsThinking(false);
            return;
          }
        }
      } catch (err) {
        console.error("[xark-e2ee] Encrypt failed — message NOT sent (fail-closed):", err);
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
      console.error("[xark-e2ee] E2EE not available — refusing to send plaintext");
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
  }, [input, isThinking, spaceId, resolvedUserId, user, userName, e2ee]);

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
          .select("title")
          .eq("id", spaceId)
          .single();
        if (data?.title) {
          setSpaceTitle(data.title);
          return;
        }
      } catch {
        // fallthrough
      }
      setSpaceTitle(
        DEMO_TITLES[spaceId] ??
          spaceId.replace(/^space_/, "").replace(/-/g, " ")
      );
    }
    loadTitle();
  }, [spaceId, authLoading]);

  // ── Fetch decision items for space state computation (after auth resolves) ──
  useEffect(() => {
    if (authLoading) return;
    async function loadItems() {
      try {
        const { data } = await supabase
          .from("decision_items")
          .select("state, is_locked, category, metadata")
          .eq("space_id", spaceId)
          .limit(200);
        if (data) setSpaceItems(data as SpaceStateItem[]);
      } catch {
        // Silent — demo fallback stays empty
      }
    }
    loadItems();
  }, [spaceId, authLoading]);

  const spaceState = computeSpaceState(spaceItems);
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
      const returnUrl = `/space/${spaceId}?invite=true${userName ? `&name=${userName}` : ""}`;
      router.replace(`/login?returnTo=${encodeURIComponent(returnUrl)}`);
      return;
    }

    async function joinSpace() {
      setJoining(true);
      try {
        await supabase.rpc("join_via_invite", { p_space_id: spaceId });
      } catch {
        // Silently handle — user may already be a member
      } finally {
        setJoining(false);
        const newParams = new URLSearchParams(searchParams.toString());
        newParams.delete("invite");
        const remaining = newParams.toString();
        router.replace(
          `/space/${spaceId}${remaining ? `?${remaining}` : ""}`
        );
      }
    }
    joinSpace();
  }, [
    isInvite,
    isAuthenticated,
    authLoading,
    spaceId,
    userName,
    router,
    searchParams,
  ]);

  // ── Share action ──
  const [showShareOptions, setShowShareOptions] = useState(false);

  const handleShare = useCallback(async () => {
    const shareUrl = `${window.location.origin}/space/${spaceId}?invite=true`;
    const shareText = `join ${spaceTitle || "this space"} on xark: ${shareUrl}`;

    // Native share sheet (HTTPS / localhost)
    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({
          title: spaceTitle || "xark space",
          text: `join ${spaceTitle || "this space"} on xark`,
          url: shareUrl,
        });
        return;
      } catch {
        // User cancelled — fall through
      }
    }

    // Fallback: show inline share options (WhatsApp, SMS, copy)
    setShowShareOptions(true);
  }, [spaceId, spaceTitle]);

  const shareUrl = `${typeof window !== "undefined" ? window.location.origin : ""}/space/${spaceId}?invite=true`;
  const shareText = `join ${spaceTitle || "this space"} on xark: ${shareUrl}`;

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

  // Debug state for visible output
  const [debugLog, setDebugLog] = useState<string[]>([]);
  const addDebug = useCallback((msg: string) => {
    setDebugLog(prev => [...prev.slice(-4), msg]);
  }, []);

  // Log auth state on mount — decode JWT sub to verify identity
  useEffect(() => {
    const token = getSupabaseToken();
    let jwtSub = 'none';
    if (token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        jwtSub = payload.sub ?? 'missing';
      } catch { jwtSub = 'decode-fail'; }
    }
    addDebug(`uid: ${resolvedUserId ?? 'null'} | jwt-sub: ${jwtSub} | e2ee: ${e2ee.available ? 'ON' : 'off'}`);
    addDebug(`space: ${spaceId} | token: ${token ? token.slice(-8) : 'NULL'}`);
  }, [resolvedUserId, e2ee.available, addDebug, spaceId]);

  return (
    <div className="relative min-h-svh" style={{ background: colors.void }}>
      {/* ── DEBUG BANNER — remove after fixing ── */}
      <div
        className="fixed inset-x-0 z-[99] px-3 py-1"
        style={{ top: 0, background: "rgba(0,0,0,0.85)", fontSize: "10px", fontFamily: "monospace", color: "#0f0", lineHeight: 1.4 }}
      >
        {debugLog.map((l, i) => <div key={i}>{l}</div>)}
      </div>

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
        className="fixed inset-x-0 top-0 z-30 px-6 pt-14 pb-0"
        style={{
          background: colors.void,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          <p
            style={{
              ...text.spaceTitle,
              color: colors.white,
              opacity: 0.95,
              display: "-webkit-box",
              WebkitLineClamp: 2,
              WebkitBoxOrient: "vertical" as never,
              overflow: "hidden",
            }}
          >
            {spaceTitle}
          </p>

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
                  color: view === "discuss" ? colors.cyan : ink.tertiary,
                  cursor: "pointer",
                  transition: `color ${timing.transition} ease`,
                  position: "relative",
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
                  color: view === "decide" ? colors.cyan : ink.tertiary,
                  cursor: "pointer",
                  transition: `color ${timing.transition} ease`,
                  position: "relative",
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
                    color: view === "itinerary" ? colors.cyan : ink.tertiary,
                    cursor: "pointer",
                    transition: `color ${timing.transition} ease`,
                    position: "relative",
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
                    color: view === "memories" ? colors.cyan : ink.tertiary,
                    cursor: "pointer",
                    transition: `color ${timing.transition} ease`,
                    position: "relative",
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
            </div>

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
      {view === "discuss" && (
        <XarkChat
          spaceId={spaceId}
          spaceTitle={spaceTitle}
          messages={messages}
          isThinking={isThinking}
          e2eeActive={e2ee.available}
          ledgerEvents={ledgerEvents}
          onLedgerUndo={handleLedgerUndo}
          onInvite={handleShare}
          memberCount={memberCount}
        />
      )}
      {view === "decide" && (
        <PossibilityHorizon spaceId={spaceId} userId={resolvedUserId} authLoading={authLoading} isThinking={isThinking} />
      )}
      {view === "itinerary" && <ItineraryView spaceId={spaceId} />}
      {view === "memories" && <MemoriesView spaceId={spaceId} />}
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
              background: "rgba(var(--xark-accent-rgb), 0.08)",
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
                      saveConstraint(constraintWhisper, resolvedUserId, spaceId).catch(() => {})
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
        onInputChange={setInput}
        onSend={sendMessage}
        isThinking={isThinking}
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
