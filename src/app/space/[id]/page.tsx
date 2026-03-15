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
} from "@/lib/messages";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { computeSpaceState } from "@/lib/space-state";
import type { SpaceStateItem } from "@/lib/space-state";
import { colors, ink, text, textColor, timing } from "@/lib/theme";

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
}

type ViewMode = "discuss" | "decide" | "itinerary" | "memories";

function SpacePageInner() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const spaceId = params.id as string;
  const userName = searchParams.get("name") ?? undefined;
  const isInvite = searchParams.get("invite") === "true";

  const { user, isAuthenticated, isLoading: authLoading } = useAuth(userName);
  // CRITICAL: userId must come from authenticated user only (e.g., "name_ram"),
  // never from raw URL param (e.g., "ram"). RLS checks user_id = auth.jwt()->>'sub'.
  const resolvedUserId = user?.uid ?? undefined;

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

  // ═══════════════════════════════════════════
  // CHAT STATE — lives here, shared across views
  // ═══════════════════════════════════════════
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const messagesLoaded = useRef(false);
  const channelRef = useRef<RealtimeChannel | null>(null);

  // ── Fetch persisted messages AFTER auth resolves ──
  useEffect(() => {
    if (authLoading || messagesLoaded.current) return;

    fetchMessages(spaceId, { limit: 50 })
      .then((persisted) => {
        if (persisted.length > 0) {
          setMessages(
            persisted.map((m) => ({
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: new Date(m.created_at).getTime(),
              senderName: m.sender_name ?? undefined,
            }))
          );
        }
        messagesLoaded.current = true;
      })
      .catch(() => {
        messagesLoaded.current = true;
      });
  }, [spaceId, authLoading]);

  // ── Broadcast channel — instant message delivery across devices ──
  useEffect(() => {
    const channel = subscribeToMessages(spaceId, (incoming) => {
      setMessages((prev) => {
        if (prev.some((m) => m.id === incoming.id)) return prev;
        return [
          ...prev,
          {
            id: incoming.id,
            role: incoming.role,
            content: incoming.content,
            timestamp: new Date(incoming.created_at).getTime(),
            senderName: incoming.sender_name ?? undefined,
          },
        ];
      });
    });
    channelRef.current = channel;

    return () => {
      unsubscribeFromMessages(channel);
      channelRef.current = null;
    };
  }, [spaceId]);

  // ── Send message — works from any view ──
  const sendMessage = useCallback(async () => {
    const txt = input.trim();
    if (!txt || isThinking) return;

    // Guard: must have authenticated userId for RLS INSERT
    if (!resolvedUserId) {
      console.warn("[xark] sendMessage blocked: no authenticated userId yet");
      return;
    }

    const userMsg: ChatMessage = {
      id: generateId(),
      role: "user",
      content: txt,
      timestamp: Date.now(),
      senderName: user?.displayName ?? userName,
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setIsThinking(true);

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
      const token = getSupabaseToken();
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
  }, [input, isThinking, spaceId, resolvedUserId, user, userName]);

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
        />
      )}
      {view === "decide" && (
        <PossibilityHorizon spaceId={spaceId} userId={resolvedUserId} authLoading={authLoading} />
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
