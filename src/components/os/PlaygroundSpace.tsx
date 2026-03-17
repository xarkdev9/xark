"use client";

// XARK OS v2.0 — Playground Space View
// Client-side only. Renders playground data using production components.
// Mock reactions, mock @xark, choreographed whispers + messages.
// No Supabase, no Realtime, no E2EE. Pure React state.

import { useState, useCallback, useRef, type TouchEvent } from "react";
import { useRouter } from "next/navigation";
import { XarkChat } from "@/components/os/XarkChat";
import { PossibilityHorizon } from "@/components/os/PossibilityHorizon";
import { ChatInput } from "@/components/os/ChatInput";
import { PlaygroundWhisper } from "@/components/os/PlaygroundWhisper";
import { usePlaygroundChoreography } from "@/hooks/usePlaygroundChoreography";
import {
  getPlaygroundItems,
  getPlaygroundMessages,
  getPlaygroundMembers,
  getPlaygroundPhotos,
  PLAYGROUND_SPACE_IDS,
  PLAYGROUND_XARK_RESTAURANTS,
} from "@/lib/playground";
import type { PlaygroundItem, PlaygroundMessage } from "@/lib/playground";
import { colors, ink, text, timing, surface } from "@/lib/theme";
import type { ReactionType } from "@/hooks/useReactions";
import type { ChatMessage } from "@/app/space/[id]/page";

type ViewMode = "discuss" | "decide";

interface PlaygroundSpaceProps {
  spaceId: string;
  userName: string;
}

export function PlaygroundSpace({ spaceId, userName }: PlaygroundSpaceProps) {
  const router = useRouter();
  const [view, setView] = useState<ViewMode>(
    spaceId === PLAYGROUND_SPACE_IDS.dinner ? "discuss" : "decide"
  );
  const [input, setInput] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const [playgroundReactions, setPlaygroundReactions] = useState<Record<string, ReactionType>>({});
  const [extraItems, setExtraItems] = useState<PlaygroundItem[]>([]);
  const [inlineCards, setInlineCards] = useState<ChatMessage[]>([]);
  const [goldBurst, setGoldBurst] = useState(false);

  // Choreography engine
  const choreography = usePlaygroundChoreography(spaceId, true);

  // Base data
  const baseItems = getPlaygroundItems(spaceId);
  const baseMessages = getPlaygroundMessages(spaceId);
  const members = getPlaygroundMembers(spaceId);
  const photos = getPlaygroundPhotos(spaceId);

  // Merge choreography messages
  const allMessages: ChatMessage[] = [
    ...baseMessages.map((m) => ({
      id: m.id,
      role: m.role,
      content: m.content,
      timestamp: m.timestamp,
      senderName: m.senderName,
    })),
    ...choreography.queuedMessages.map((m) => ({
      id: m.id,
      role: m.role,
      content: m.content,
      timestamp: m.timestamp,
      senderName: m.senderName,
    })),
    ...inlineCards,
  ].sort((a, b) => a.timestamp - b.timestamp);

  // All items (base + @xark results)
  const allItems = [...baseItems, ...extraItems];

  // Space title
  const titleMap: Record<string, string> = {
    [PLAYGROUND_SPACE_IDS.tokyo]: "tokyo neon nights",
    [PLAYGROUND_SPACE_IDS.dinner]: "dinner tonight",
    [PLAYGROUND_SPACE_IDS.maya]: "maya's birthday",
    [PLAYGROUND_SPACE_IDS.hike]: "weekend hike",
  };
  const spaceTitle = titleMap[spaceId] ?? spaceId;

  // Mock reaction handler
  const handleReaction = useCallback((itemId: string, signal: ReactionType) => {
    setPlaygroundReactions((prev) => {
      if (prev[itemId] === signal) {
        const next = { ...prev };
        delete next[itemId];
        return next;
      }
      return { ...prev, [itemId]: signal };
    });

    // Trigger post-vote choreography (Space 1)
    if (spaceId === PLAYGROUND_SPACE_IDS.tokyo && itemId === "pg_item_hyatt") {
      choreography.triggerPostVote();
    }

    // Dinner space: consensus cascade after voting love on a restaurant
    if (
      spaceId === PLAYGROUND_SPACE_IDS.dinner &&
      signal === "love_it" &&
      PLAYGROUND_XARK_RESTAURANTS.some((r) => r.id === itemId)
    ) {
      // 600ms: zoe votes — score jumps
      setTimeout(() => {
        setExtraItems((prev) =>
          prev.map((item) =>
            item.id === itemId
              ? { ...item, weighted_score: 10, agreement_score: 0.65 }
              : item
          )
        );
      }, 600);

      // 1200ms: leo votes — near consensus
      setTimeout(() => {
        setExtraItems((prev) =>
          prev.map((item) =>
            item.id === itemId
              ? { ...item, weighted_score: 18, agreement_score: 0.95 }
              : item
          )
        );
      }, 1200);

      // 1800ms: gold burst
      setTimeout(() => setGoldBurst(true), 1800);

      // 4800ms: clear gold burst
      setTimeout(() => setGoldBurst(false), 4800);
    }
  }, [spaceId, choreography]);

  // Mock @xark handler
  const sendMessage = useCallback(() => {
    const txt = input.trim();
    if (!txt) return;

    // Add user message
    const userMsg: ChatMessage = {
      id: `pg_user_${Date.now()}`,
      role: "user",
      content: txt,
      timestamp: Date.now(),
      senderName: userName,
    };
    setInlineCards((prev) => [...prev, userMsg]);
    setInput("");

    // Check for @xark
    if (txt.toLowerCase().includes("@xark")) {
      setIsThinking(true);

      // Video-optimized: 1.2s thinking, then cards + auto-switch to Decide
      setTimeout(() => {
        setIsThinking(false);

        // @xark response in chat
        const xarkMsg: ChatMessage = {
          id: `pg_xark_${Date.now()}`,
          role: "xark",
          content: "found 3 spots nearby",
          timestamp: Date.now(),
          senderName: "@xark",
        };
        setInlineCards((prev) => [...prev, xarkMsg]);

        // Add items to Decide tab
        setExtraItems(PLAYGROUND_XARK_RESTAURANTS);

        // Trigger choreography
        choreography.triggerPostXark();

        // Auto-switch to Decide after 800ms
        setTimeout(() => setView("decide"), 800);
      }, 1200);
    }
  }, [input, userName, choreography]);

  // Tab badge dismissal
  const handleTabSwitch = useCallback((tab: ViewMode) => {
    setView(tab);
    if (choreography.tabBadge?.tab === tab) {
      // Badge dismisses on tab switch — no setter needed, it stays until next render
    }
  }, [choreography.tabBadge]);

  // ── Swipe discuss ↔ decide ──
  const viewTabs: ViewMode[] = ["discuss", "decide"];
  const swipeX = useRef(0);
  const swipeY = useRef(0);
  const onSwipeStart = useCallback((e: TouchEvent) => { swipeX.current = e.touches[0].clientX; swipeY.current = e.touches[0].clientY; }, []);
  const onSwipeEnd = useCallback((e: TouchEvent) => {
    const dx = e.changedTouches[0].clientX - swipeX.current;
    const dy = e.changedTouches[0].clientY - swipeY.current;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      const idx = viewTabs.indexOf(view);
      if (dx < 0 && idx < viewTabs.length - 1) setView(viewTabs[idx + 1]);
      else if (dx > 0 && idx > 0) setView(viewTabs[idx - 1]);
    }
  }, [view]);

  // Navigate home
  const goHome = useCallback(() => {
    router.push(`/galaxy?name=${encodeURIComponent(userName)}`);
  }, [router, userName]);

  return (
    <div style={{ height: "100dvh", overflow: "hidden", display: "flex", flexDirection: "column", background: surface.chrome }}>
      {/* ── Header ── */}
      <div
        className="relative z-10 px-6"
        style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 16px)", flexShrink: 0 }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          {/* Back + title */}
          <p
            onClick={goHome}
            style={{
              ...text.spaceTitle,
              color: ink.primary,
              cursor: "pointer",
              marginBottom: "8px",
            }}
          >
            {spaceTitle}
          </p>

          {/* View toggle */}
          <div className="flex gap-6" style={{ marginBottom: "8px" }}>
            {(["discuss", "decide"] as ViewMode[]).map((tab) => {
              const isActive = view === tab;
              const hasBadge = choreography.tabBadge?.tab === tab;
              return (
                <span
                  key={tab}
                  role="button"
                  tabIndex={0}
                  onClick={() => handleTabSwitch(tab)}
                  className="cursor-pointer outline-none"
                  style={{
                    ...text.label,
                    position: "relative",
                    color: isActive ? colors.cyan : ink.tertiary,
                    opacity: isActive ? 0.85 : 0.5,
                    transition: "opacity 0.3s ease, color 0.3s ease",
                  }}
                >
                  {tab}
                  {/* Active underline */}
                  {isActive && (
                    <span
                      style={{
                        position: "absolute",
                        bottom: "-4px",
                        left: 0,
                        width: "100%",
                        height: "2px",
                        background: colors.cyan,
                        opacity: 0.6,
                      }}
                    />
                  )}
                  {/* Tab badge — pulsing orange dot */}
                  {hasBadge && !isActive && (
                    <span
                      style={{
                        position: "absolute",
                        top: "-2px",
                        right: "-8px",
                        width: "6px",
                        height: "6px",
                        borderRadius: "50%",
                        backgroundColor: "#FF6B35",
                        animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                      }}
                    />
                  )}
                </span>
              );
            })}
          </div>
        </div>
      </div>

      {/* ── Content — swipe to switch ── */}
      <div style={{ flex: 1, overflowY: "auto", paddingBottom: "120px" }} onTouchStart={onSwipeStart} onTouchEnd={onSwipeEnd}>
        {view === "discuss" && (
          <XarkChat
            spaceId={spaceId}
            spaceTitle={spaceTitle}
            messages={allMessages}
            isThinking={isThinking}
            typingIndicator={choreography.typingIndicator}
            inlineCards={
              extraItems.length > 0
                ? extraItems.map((item) => ({
                    title: item.title,
                    imageUrl: item.metadata?.image_url,
                    price: item.metadata?.price ?? "",
                    score: 0,
                    onTap: () => handleTabSwitch("decide"),
                  }))
                : undefined
            }
            inlineCardsWhisper={choreography.whispers.decide_hint?.visible ? choreography.whispers.decide_hint.text : undefined}
          />
        )}
        {view === "decide" && (
          <PossibilityHorizon
            spaceId={spaceId}
            userId="pg_user"
            isThinking={isThinking}
            playgroundItems={allItems}
            playgroundReactions={playgroundReactions}
            onPlaygroundReact={handleReaction}
          />
        )}
      </div>

      {/* ── Playground whispers — floating near relevant elements ── */}
      {choreography.whispers.vote?.visible && view === "decide" && (
        <div
          className="fixed z-30"
          style={{ bottom: "200px", left: "50%", transform: "translateX(-50%)" }}
        >
          <PlaygroundWhisper text={choreography.whispers.vote.text} visible={true} />
        </div>
      )}

      {choreography.whispers.xark_hint?.visible && view === "discuss" && (
        <div
          className="fixed z-30 px-6"
          style={{ bottom: "90px", left: 0, right: 0 }}
        >
          <div className="mx-auto" style={{ maxWidth: "640px" }}>
            <PlaygroundWhisper text={choreography.whispers.xark_hint.text} visible={true} />
          </div>
        </div>
      )}

      {choreography.whispers.settlement?.visible && (
        <div
          className="fixed z-30 px-6"
          style={{ bottom: "90px", left: 0, right: 0 }}
        >
          <div className="mx-auto" style={{ maxWidth: "640px" }}>
            <PlaygroundWhisper text={choreography.whispers.settlement.text} visible={true} />
          </div>
        </div>
      )}

      {/* ── Gold Burst — consensus celebration ── */}
      {goldBurst && (
        <div
          className="pointer-events-none fixed inset-0 z-50"
          style={{
            background:
              "radial-gradient(circle at 50% 50%, rgba(255,215,0,0.15) 0%, rgba(255,215,0,0.05) 40%, transparent 70%)",
            animation: "pgGoldBurst 3s ease-out forwards",
          }}
        />
      )}

      <style>{`
        @keyframes pgGoldBurst {
          0% { opacity: 0; }
          20% { opacity: 1; }
          100% { opacity: 0; }
        }
      `}</style>

      {/* ── Chat Input ── */}
      <ChatInput
        input={input}
        onInputChange={setInput}
        onSend={sendMessage}
        isThinking={isThinking}
      />
    </div>
  );
}
