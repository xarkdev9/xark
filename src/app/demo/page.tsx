"use client";

// XARK OS — Ad Demo Simulation
// Fully scripted, self-contained. No Supabase, no playground.
// Flow: chat history → "@xark dinner tonight" → shimmer → cards → love → GOLD BURST

import { useState, useCallback, useRef, useEffect, type TouchEvent } from "react";
import { motion } from "framer-motion";
import { XarkChat } from "@/components/os/XarkChat";
import { PossibilityHorizon } from "@/components/os/PossibilityHorizon";
import { ChatInput } from "@/components/os/ChatInput";
import { colors, ink, text, surface } from "@/lib/theme";
import type { ReactionType } from "@/hooks/useReactions";
import type { ChatMessage } from "@/app/space/[id]/page";
import type { PlaygroundItem } from "@/lib/playground";

// ── Helpers ──

function ago(minutes: number): number {
  return Date.now() - minutes * 60 * 1000;
}

// ── Pre-seeded chat history — natural group conversation ──

const SEED_MESSAGES: ChatMessage[] = [
  { id: "s1", role: "user", content: "where should we eat tonight?", timestamp: ago(15), senderName: "ava" },
  { id: "s2", role: "user", content: "sushi?", timestamp: ago(13), senderName: "kai" },
  { id: "s3", role: "user", content: "yes!! somewhere walkable", timestamp: ago(11), senderName: "zoe" },
  { id: "s4", role: "user", content: "i know a few spots downtown", timestamp: ago(9), senderName: "leo" },
  { id: "s5", role: "user", content: "let me ask xark", timestamp: ago(7), senderName: "ava" },
];

// ── Restaurant cards — pre-voted by friends, sushi nakazawa at 85% ──

const RESTAURANTS: PlaygroundItem[] = [
  {
    id: "demo_r1",
    title: "sushi nakazawa",
    category: "restaurant",
    weighted_score: 0,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=400&h=500&fit=crop",
      price: "$45/person",
      source: "google",
      search_label: "sushi spots",
    },
    created_at: new Date().toISOString(),
  },
  {
    id: "demo_r2",
    title: "omakase room",
    category: "restaurant",
    weighted_score: 0,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1553621042-f6e147245754?w=400&h=500&fit=crop",
      price: "$65/person",
      source: "google",
      search_label: "sushi spots",
    },
    created_at: new Date().toISOString(),
  },
  {
    id: "demo_r3",
    title: "blue ribbon sushi",
    category: "restaurant",
    weighted_score: 0,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?w=400&h=500&fit=crop",
      price: "$35/person",
      source: "google",
      search_label: "sushi spots",
    },
    created_at: new Date().toISOString(),
  },
];

// ── Demo Page ──

export default function DemoPage() {
  const [mounted, setMounted] = useState(false);
  const [view, setView] = useState<"discuss" | "decide">("discuss");
  const [input, setInput] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>(SEED_MESSAGES);
  const [items, setItems] = useState<PlaygroundItem[]>([]);
  const [reactions, setReactions] = useState<Record<string, ReactionType>>({});
  const [goldBurst, setGoldBurst] = useState(false);
  const [votingStarted, setVotingStarted] = useState(false);
  const timersRef = useRef<ReturnType<typeof setTimeout>[]>([]);

  useEffect(() => setMounted(true), []);

  useEffect(() => {
    return () => timersRef.current.forEach(clearTimeout);
  }, []);

  if (!mounted) return null;

  // ── Friend voting cascade — scores climb after cards appear ──
  const startVotingCascade = useCallback(() => {
    if (votingStarted) return;
    setVotingStarted(true);

    // +800ms: kai votes love on sushi nakazawa
    const t1 = setTimeout(() => {
      setItems((prev) =>
        prev.map((item) =>
          item.id === "demo_r1"
            ? { ...item, weighted_score: 5, agreement_score: 0.25, state: "ranked" }
            : item
        )
      );
    }, 800);

    // +1400ms: zoe votes love on sushi nakazawa
    const t2 = setTimeout(() => {
      setItems((prev) =>
        prev.map((item) =>
          item.id === "demo_r1"
            ? { ...item, weighted_score: 10, agreement_score: 0.50 }
            : item.id === "demo_r2"
            ? { ...item, weighted_score: 5, agreement_score: 0.25, state: "ranked" }
            : item
        )
      );
    }, 1400);

    // +2000ms: leo votes — sushi nakazawa at 85%
    const t3 = setTimeout(() => {
      setItems((prev) =>
        prev.map((item) =>
          item.id === "demo_r1"
            ? { ...item, weighted_score: 14, agreement_score: 0.85 }
            : item
        )
      );
    }, 2000);

    timersRef.current.push(t1, t2, t3);
  }, [votingStarted]);

  // ── Swipe discuss ↔ decide ──
  const swipeX = useRef(0);
  const swipeY = useRef(0);
  const onSwipeStart = useCallback((e: TouchEvent) => {
    swipeX.current = e.touches[0].clientX;
    swipeY.current = e.touches[0].clientY;
  }, []);
  const onSwipeEnd = useCallback((e: TouchEvent) => {
    const dx = e.changedTouches[0].clientX - swipeX.current;
    const dy = e.changedTouches[0].clientY - swipeY.current;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      if (dx < 0 && view === "discuss") setView("decide");
      else if (dx > 0 && view === "decide") setView("discuss");
    }
  }, [view]);

  // ── Send message — scripted @xark flow ──
  const sendMessage = useCallback(() => {
    const txt = input.trim();
    if (!txt) return;

    // User message (no senderName → right-aligned as "you")
    setMessages((prev) => [
      ...prev,
      {
        id: `user_${Date.now()}`,
        role: "user",
        content: txt,
        timestamp: Date.now(),
      },
    ]);
    setInput("");

    // @xark trigger
    if (txt.toLowerCase().includes("@xark")) {
      setIsThinking(true);

      // 1.5s shimmer thinking → response + auto-switch to Decide
      setTimeout(() => {
        setIsThinking(false);

        // @xark response
        setMessages((prev) => [
          ...prev,
          {
            id: `xark_${Date.now()}`,
            role: "xark",
            content: "found 3 spots nearby",
            timestamp: Date.now(),
            senderName: "@xark",
          },
        ]);

        // Load pre-voted restaurant cards
        setItems(RESTAURANTS);

        // Auto-switch to Decide + start friend voting
        const t = setTimeout(() => {
          setView("decide");
          startVotingCascade();
        }, 800);
        timersRef.current.push(t);
      }, 1500);
    }
  }, [input]);

  // ── Reaction — instant consensus on sushi nakazawa ──
  const handleReaction = useCallback(
    (itemId: string, signal: ReactionType) => {
      setReactions((prev) => {
        if (prev[itemId] === signal) {
          const next = { ...prev };
          delete next[itemId];
          return next;
        }
        return { ...prev, [itemId]: signal };
      });

      // User votes love on sushi nakazawa → 100% consensus → GOLD BURST
      if (itemId === "demo_r1" && signal === "love_it") {
        // Score jumps to unanimous
        setItems((prev) =>
          prev.map((item) =>
            item.id === "demo_r1"
              ? { ...item, weighted_score: 19, agreement_score: 1.0, is_locked: true, state: "locked" }
              : item
          )
        );

        // GOLD BURST
        const gt1 = setTimeout(() => setGoldBurst(true), 300);
        const gt2 = setTimeout(() => setGoldBurst(false), 3300);
        timersRef.current.push(gt1, gt2);
      }
    },
    []
  );

  return (
    <div
      style={{
        height: "100dvh",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        background: surface.chrome,
      }}
    >
      {/* ── Header ── */}
      <div
        className="relative z-10 px-6"
        style={{
          paddingTop: "calc(env(safe-area-inset-top, 0px) + 16px)",
          flexShrink: 0,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          <p style={{ ...text.spaceTitle, color: ink.primary, marginBottom: "8px" }}>
            dinner tonight
          </p>

          {/* View toggle */}
          <div className="flex gap-6" style={{ marginBottom: "8px" }}>
            {(["discuss", "decide"] as const).map((tab) => (
              <span
                key={tab}
                role="button"
                tabIndex={0}
                onClick={() => setView(tab)}
                className="cursor-pointer outline-none"
                style={{
                  ...text.label,
                  position: "relative",
                  color: view === tab ? colors.cyan : ink.tertiary,
                  opacity: view === tab ? 0.85 : 0.5,
                  transition: "opacity 0.3s ease, color 0.3s ease",
                }}
              >
                {tab}
                {view === tab && (
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
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* ── Content ── */}
      <div
        style={{ flex: 1, overflowY: "auto", paddingBottom: "120px" }}
        onTouchStart={onSwipeStart}
        onTouchEnd={onSwipeEnd}
      >
        {view === "discuss" && (
          <XarkChat
            spaceId="demo_dinner"
            spaceTitle="dinner tonight"
            messages={messages}
            isThinking={isThinking}
          />
        )}
        {view === "decide" && (
          <PossibilityHorizon
            spaceId="demo_dinner"
            userId="demo_user"
            isThinking={false}
            playgroundItems={items}
            playgroundReactions={reactions}
            onPlaygroundReact={handleReaction}
          />
        )}
      </div>

      {/* ── GOLD BURST + rotating ring ── */}
      {goldBurst && (
        <>
          <div
            className="pointer-events-none fixed inset-0 z-50"
            style={{
              background:
                "radial-gradient(circle at 50% 50%, rgba(255,215,0,0.2) 0%, rgba(255,215,0,0.08) 40%, transparent 70%)",
              animation: "demoGoldBurst 3s ease-out forwards",
            }}
          />
          <motion.div
            animate={{ rotate: 360, scale: [0.6, 2.5], opacity: [0.4, 0] }}
            transition={{ duration: 2.5, ease: "easeOut" }}
            className="pointer-events-none fixed z-50"
            style={{
              top: "50%", left: "50%",
              width: "180px", height: "180px",
              marginTop: "-90px", marginLeft: "-90px",
              borderRadius: "50%",
              border: "1px dashed rgba(255,215,0,0.4)",
            }}
          />
        </>
      )}

      <style>{`
        @keyframes demoGoldBurst {
          0% { opacity: 0; }
          15% { opacity: 1; }
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
