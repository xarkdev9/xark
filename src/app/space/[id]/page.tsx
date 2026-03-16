"use client";

// XARK OS v2.0 — Space View
// Discuss (chat) + Decide (visual stream) toggle.
// Chat state (messages, draft input) lives HERE — persists across view switches.
// ChatInput is always visible. XarkChat is display-only.

import { useState, useEffect, useCallback, useRef, Suspense } from "react";
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
import { colors, ink, text, textColor, timing } from "@/lib/theme";
import { tryLocalAgent } from "@/lib/local-agent";
import type { LocalContext, LedgerEntry } from "@/lib/local-agent";
import { isRecallQuestion, getRecallWhisper } from "@/lib/local-recall";
import type { RecallResult } from "@/lib/local-recall";
import { useLocalMemory } from "@/hooks/useLocalMemory";
import { useDeviceTier } from "@/hooks/useDeviceTier";
import { ContextCard } from "@/components/os/ContextCard";
import type { LedgerEvent } from "@/components/os/LedgerPill";
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
  messageType?: string;  // 'e2ee' | 'e2ee_xark' | 'xark' | 'system' | 'legacy'
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

  // E2EE — only for phone-authenticated users (Firebase OTP).
  // Dev-auto-login users (name_ prefix) use legacy plaintext path.
  // E2EE requires persistent IndexedDB keys + Sender Key distribution
  // which doesn't work across dev browser sessions.
  const isPhoneAuth = resolvedUserId?.startsWith("phone_") ?? false;
  const e2ee = useE2EE(isPhoneAuth ? resolvedUserId ?? null : null);

  const viewParam = searchParams.get("view");
  const [view, setView] = useState<ViewMode>(
    viewParam === "decide" ? "decide" : "discuss"
  );
  const [spaceTitle, setSpaceTitle] = useState<string>("");
  const [spaceItems, setSpaceItems] = useState<SpaceStateItem[]>([]);
  const [joining, setJoining] = useState(false);
  const [shareWhisper, setShareWhisper] = useState(false);
  const [pendingConfirmation, setPendingConfirmation] = useState<{
    response: string;
    action: string;
    payload: Record<string, unknown>;
  } | null>(null);
  const [constraintWhisper, setConstraintWhisper] = useState<DetectedConstraint | null>(null);

  // ── Tier 1/2 state ──
  const deviceTier = useDeviceTier();
  const localMemory = useLocalMemory(spaceId);
  const [ledgerEvents, setLedgerEvents] = useState<LedgerEvent[]>([]);
  const [localWhisper, setLocalWhisper] = useState<string | null>(null);
  const [contextCard, setContextCard] = useState<RecallResult | null>(null);
  const [recallWhisper, setRecallWhisper] = useState<string | null>(null);

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

    fetchMessages(spaceId, { limit: 50 })
      .then(async (persisted) => {
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
            (m) => m.message_type === 'e2ee' || m.message_type === 'e2ee_xark'
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
              setMessages((prev) =>
                prev.map((m) => {
                  const decrypted = decryptedMap.get(m.id);
                  return decrypted ? { ...m, content: decrypted } : m;
                })
              );
            }
          }
        }

        // Feed messages to Tier 2 memory index (delta sync via watermark)
        if (localMemory.ready) {
          for (const m of mapped) {
            if (!localMemory.watermark || m.timestamp > localMemory.watermark) {
              localMemory.indexMessage({
                id: m.id,
                content: m.content,
                senderName: m.senderName,
                timestamp: m.timestamp,
              });
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

      if (e2ee.available && (msgType === 'e2ee' || msgType === 'e2ee_xark')) {
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

      // Clear thinking indicator when @xark response arrives
      if (incoming.role === 'xark' && content && content !== 'thinking...') {
        setIsThinking(false);
      }

      // Feed to Tier 2 memory index
      if (localMemory.ready && content) {
        localMemory.indexMessage({
          id: incoming.id,
          content,
          senderName: incoming.sender_name ?? "",
          timestamp: new Date(incoming.created_at).getTime(),
        });
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

  // ── Send message — works from any view, E2EE when available ──
  const sendMessage = useCallback(async () => {
    const txt = input.trim();
    if (!txt) return;

    // Guard: must have authenticated userId for RLS INSERT
    if (!resolvedUserId) {
      console.warn("[xark] sendMessage blocked: no authenticated userId yet");
      return;
    }

    const hasXark = txt.toLowerCase().includes("@xark");

    // ── TIER 1: Fast-Path Router (runs even while isThinking) ──
    if (hasXark) {
      const localContext: LocalContext = {
        spaceId,
        userId: resolvedUserId,
        userName: user?.displayName ?? userName ?? "",
        spaceItems,
        supabaseToken: getSupabaseToken(),
      };

      const localResult = tryLocalAgent(txt, localContext);
      if (localResult) {
        setInput("");
        if (localResult.ledgerEntry) persistLedger(localResult.ledgerEntry);
        if (localResult.uiAction) localResult.uiAction();
        if (localResult.whisper) {
          setLocalWhisper(localResult.whisper);
          setTimeout(() => setLocalWhisper(null), 3000);
        }
        return; // Done. No E2EE, no network, no thinking indicator.
      }

      // ── TIER 2: E2EE Memory Engine ──
      if (isRecallQuestion(txt)) {
        const results = await localMemory.search(txt);
        if (results.length > 0) {
          setInput("");
          setContextCard(results[0]);
          return;
        }
        // Zero results — show tier-aware coaching whisper, preserve input
        setRecallWhisper(getRecallWhisper(deviceTier));
        setTimeout(() => setRecallWhisper(null), 5000);
        return; // STRICT HALT: cloud is E2EE-blind
      }
    }

    // isThinking gate: only blocks Tier 3 (network-dependent paths)
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

    const hasXarkTrigger = txt.toLowerCase().includes("@xark");
    const token = getSupabaseToken();

    // ══════════════════════════════════════════════
    // E2EE PATH — encrypt + /api/message
    // ══════════════════════════════════════════════
    if (e2ee.available) {
      try {
        const envelope = await e2ee.encrypt(txt, spaceId);
        if (envelope) {
          // Broadcast encrypted envelope for instant delivery
          if (channelRef.current) {
            broadcastMessage(channelRef.current, {
              id: userMsg.id,
              space_id: spaceId,
              role: "user",
              content: null as unknown as string, // E2EE: server never sees plaintext
              user_id: resolvedUserId ?? null,
              sender_name: user?.displayName ?? userName ?? null,
              created_at: new Date().toISOString(),
              message_type: hasXarkTrigger ? "e2ee_xark" : "e2ee",
              sender_device_id: e2ee.deviceId,
              // E2EE payload for instant decrypt by recipients
              ciphertext_b64: envelope.ciphertext,
              ratchet_header_b64: envelope.ratchetHeader ?? null,
            });
          }

          // Send encrypted message to server
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
              xark_trigger: hasXarkTrigger
                ? { plaintext_command: txt }
                : undefined,
            }),
          });

          const data = await res.json();

          if (!res.ok) {
            console.error("[e2ee] /api/message failed:", data.error);
            // Fall through to legacy path below
          } else {
            // Success — handle @xark response if any
            if (data.xarkMessageId) {
              // @xark will update the thinking placeholder via DB
              // Poll or wait for Realtime to deliver the response
            }
            if (!hasXarkTrigger) {
              setIsThinking(false);
            } else {
              // Wait for @xark response via Realtime
              // Set a timeout to stop thinking indicator
              setTimeout(() => setIsThinking(false), 30_000);
            }
            return;
          }
        }
      } catch (err) {
        console.warn("[e2ee] Encrypt path failed, falling back to legacy:", err);
      }
    }

    // ══════════════════════════════════════════════
    // LEGACY PATH — plaintext save + /api/xark
    // ══════════════════════════════════════════════

    // Broadcast for instant delivery to other users (~50ms)
    if (channelRef.current) {
      broadcastMessage(channelRef.current, {
        id: userMsg.id,
        space_id: spaceId,
        role: "user",
        content: userMsg.content,
        user_id: resolvedUserId ?? null,
        sender_name: user?.displayName ?? userName ?? null,
        created_at: new Date().toISOString(),
      });
    }

    // Persist to DB for durability (async, RLS-aware)
    saveMessage({
      id: userMsg.id,
      spaceId,
      role: "user",
      content: userMsg.content,
      userId: resolvedUserId,
      senderName: user?.displayName ?? userName,
    }).catch((err) => {
      console.error("[xark] message not saved:", err?.message ?? err);
    });

    try {
      const response = await fetch("/api/xark", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          message: txt,
          spaceId,
          userId: resolvedUserId,
        }),
      });

      const data = await response.json();

      // Surface server errors
      if (!response.ok && data.response) {
        setMessages((prev) => [
          ...prev,
          {
            id: generateId(),
            role: "xark",
            content: data.response,
            timestamp: Date.now(),
          },
        ]);
        setIsThinking(false);
        return;
      }

      // Silent mode: @xark returns null when not invoked
      if (data.response === null) {
        setIsThinking(false);
        return;
      }

      // Check for pending confirmation (e.g., set_dates, populate_logistics)
      if (data.pendingConfirmation) {
        setPendingConfirmation({
          response: data.response,
          action: data.action,
          payload: data.payload || {},
        });
      }

      // @xark response (persisted server-side via supabaseAdmin)
      setMessages((prev) => [
        ...prev,
        {
          id: data.messageId ?? generateId(),
          role: "xark",
          content: data.response ?? "i could not generate a response.",
          timestamp: Date.now(),
        },
      ]);
    } catch {
      setMessages((prev) => [
        ...prev,
        {
          id: generateId(),
          role: "xark",
          content: "connection interrupted. try again.",
          timestamp: Date.now(),
        },
      ]);
    } finally {
      setIsThinking(false);
    }
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
  const handleShare = useCallback(async () => {
    const shareUrl = `${window.location.origin}/space/${spaceId}?invite=true`;
    const shareData = {
      title: spaceTitle || "xark space",
      text: `join ${spaceTitle || "this space"} on xark`,
      url: shareUrl,
    };

    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share(shareData);
        return;
      } catch {
        // User cancelled — fall through to clipboard
      }
    }

    try {
      await navigator.clipboard.writeText(shareUrl);
      setShareWhisper(true);
      setTimeout(() => setShareWhisper(false), 2000);
    } catch {
      // Silent fail
    }
  }, [spaceId, spaceTitle]);

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

  return (
    <div className="relative min-h-svh" style={{ background: colors.void }}>
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
              opacity: 0.9,
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
                }}
              >
                discuss
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
                }}
              >
                decide
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
                  }}
                >
                  itinerary
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
                  }}
                >
                  memories
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

      {/* ── View content ── */}
      {view === "discuss" && (
        <XarkChat
          spaceId={spaceId}
          spaceTitle={spaceTitle}
          messages={messages}
          isThinking={isThinking}
          e2eeActive={e2ee.available}
          ledgerEvents={ledgerEvents}
          onLedgerUndo={handleLedgerUndo}
        />
      )}
      {view === "decide" && (
        <PossibilityHorizon spaceId={spaceId} userId={resolvedUserId} authLoading={authLoading} isThinking={isThinking} />
      )}
      {view === "itinerary" && <ItineraryView spaceId={spaceId} />}
      {view === "memories" && <MemoriesView spaceId={spaceId} />}

      {/* ── Pending confirmation whisper ── */}
      {pendingConfirmation && (
        <div style={{ textAlign: "center", padding: "12px 0" }}>
          <span
            role="button"
            tabIndex={0}
            onClick={async () => {
              const confirmToken = getSupabaseToken();
              await fetch("/api/xark", {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  ...(confirmToken ? { Authorization: `Bearer ${confirmToken}` } : {}),
                },
                body: JSON.stringify({
                  confirm_action: pendingConfirmation.action,
                  spaceId,
                  payload: pendingConfirmation.payload,
                }),
              });
              setPendingConfirmation(null);
            }}
            className="cursor-pointer outline-none"
            style={{ ...text.body, color: colors.gold, opacity: 0.8 }}
          >
            confirm
          </span>
          <span style={{ ...text.body, color: ink.tertiary, margin: "0 16px" }}>·</span>
          <span
            role="button"
            tabIndex={0}
            onClick={() => setPendingConfirmation(null)}
            className="cursor-pointer outline-none"
            style={{ ...text.body, color: ink.tertiary }}
          >
            wait
          </span>
        </div>
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

      {/* ── Context Card (Tier 2 recall result) ── */}
      {contextCard && (
        <div className="fixed inset-x-0 z-20 mx-auto px-6" style={{ bottom: "80px", maxWidth: "640px" }}>
          <ContextCard
            content={contextCard.content}
            senderName={contextCard.senderName}
            timestamp={contextCard.timestamp}
            onJump={() => {
              const el = document.getElementById(`msg-${contextCard.messageId}`);
              if (el) {
                el.scrollIntoView({ behavior: "smooth", block: "center" });
                el.animate(
                  [{ background: "rgba(var(--xark-accent-rgb), 0.15)" }, { background: "transparent" }],
                  { duration: 1500 }
                );
              }
              setContextCard(null);
            }}
            onQuote={(content, sender) => {
              setInput(`> ${sender}: "${content.slice(0, 80)}"\n`);
              setContextCard(null);
            }}
            onDismiss={() => setContextCard(null)}
          />
        </div>
      )}

      {/* ── Recall whisper (Tier 2 zero results) ── */}
      {recallWhisper && (
        <div className="fixed inset-x-0 z-20 mx-auto px-6" style={{ bottom: "80px", maxWidth: "640px" }}>
          <p
            style={{ ...text.hint, color: ink.tertiary, textAlign: "center", cursor: "pointer" }}
            onClick={() => setRecallWhisper(null)}
          >
            {recallWhisper}
          </p>
        </div>
      )}

      {/* ── Local command whisper ── */}
      {localWhisper && (
        <div className="fixed inset-x-0 z-20 mx-auto px-6" style={{ bottom: "80px", maxWidth: "640px" }}>
          <p
            style={{ ...text.hint, color: ink.tertiary, textAlign: "center", cursor: "pointer" }}
            onClick={() => setLocalWhisper(null)}
          >
            {localWhisper}
          </p>
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
