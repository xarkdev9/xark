"use client";

// XARK OS — Travel Ad Demo
// Full Netflix vertical scroll: flights, hotels, rental cars.
// Friends vote in real-time → user tips consensus → GOLD BURST.
// Self-contained. No Supabase.

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

// ── Chat history — friends planning tokyo trip ──

const SEED_MESSAGES: ChatMessage[] = [
  { id: "t1", role: "user", content: "tokyo in april, who's in?", timestamp: ago(120), senderName: "kai" },
  { id: "t2", role: "user", content: "100% in", timestamp: ago(90), senderName: "ava" },
  { id: "t3", role: "user", content: "same, need flights and hotel", timestamp: ago(60), senderName: "leo" },
  { id: "t4", role: "user", content: "and maybe a car for day trips?", timestamp: ago(45), senderName: "zoe" },
  { id: "t5", role: "user", content: "let me find everything", timestamp: ago(30), senderName: "kai" },
];

// ── Travel items — 3 rails: flights, hotels, cars ──

function makeItems(): PlaygroundItem[] {
  const now = new Date().toISOString();
  return [
    // ── Flights ──
    {
      id: "demo_f1",
      title: "united — sfo → nrt",
      category: "flight",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1436491865332-7a61a109db05?w=400&h=500&fit=crop",
        price: "$890 RT",
        source: "google flights",
        search_label: "flights to tokyo",
      },
      created_at: now,
    },
    {
      id: "demo_f2",
      title: "ana — sfo → hnd",
      category: "flight",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1464037866556-6812c9d1c72e?w=400&h=500&fit=crop",
        price: "$1,240 RT",
        source: "google flights",
        search_label: "flights to tokyo",
      },
      created_at: now,
    },
    {
      id: "demo_f3",
      title: "japan airlines — lax → nrt",
      category: "flight",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1529074963764-98f45c47344b?w=400&h=500&fit=crop",
        price: "$980 RT",
        source: "google flights",
        search_label: "flights to tokyo",
      },
      created_at: now,
    },

    // ── Hotels ──
    {
      id: "demo_h1",
      title: "park hyatt tokyo",
      category: "hotel",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=500&fit=crop",
        price: "$650/nt",
        source: "booking.com",
        search_label: "hotels in tokyo",
      },
      created_at: now,
    },
    {
      id: "demo_h2",
      title: "andaz tokyo",
      category: "hotel",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=400&h=500&fit=crop",
        price: "$420/nt",
        source: "hyatt.com",
        search_label: "hotels in tokyo",
      },
      created_at: now,
    },
    {
      id: "demo_h3",
      title: "hoshinoya tokyo",
      category: "hotel",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=400&h=500&fit=crop",
        price: "$380/nt",
        source: "hoshinoya.com",
        search_label: "hotels in tokyo",
      },
      created_at: now,
    },

    // ── Rental Cars ──
    {
      id: "demo_c1",
      title: "toyota camry hybrid",
      category: "car",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1549317661-bd32c8ce0afa?w=400&h=500&fit=crop",
        price: "$45/day",
        source: "rentacar.com",
        search_label: "rental cars",
      },
      created_at: now,
    },
    {
      id: "demo_c2",
      title: "honda fit",
      category: "car",
      weighted_score: 0,
      agreement_score: 0,
      is_locked: false,
      state: "proposed",
      metadata: {
        image_url: "https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=400&h=500&fit=crop",
        price: "$30/day",
        source: "rentacar.com",
        search_label: "rental cars",
      },
      created_at: now,
    },
  ];
}

// ── Friend voting cascade — scores update progressively ──

interface VoteWave {
  delay: number; // ms after cards appear
  updates: { id: string; score: number; agreement: number }[];
}

const VOTE_WAVES: VoteWave[] = [
  {
    // Wave 1: ava votes (800ms)
    delay: 800,
    updates: [
      { id: "demo_h1", score: 5, agreement: 0.25 },  // park hyatt
      { id: "demo_f1", score: 5, agreement: 0.25 },  // united
    ],
  },
  {
    // Wave 2: kai votes (1400ms)
    delay: 1400,
    updates: [
      { id: "demo_h1", score: 10, agreement: 0.50 },  // park hyatt climbing
      { id: "demo_f2", score: 5, agreement: 0.25 },   // ana
      { id: "demo_c1", score: 5, agreement: 0.25 },   // toyota
    ],
  },
  {
    // Wave 3: zoe votes (2000ms) — park hyatt at 85%, almost there
    delay: 2000,
    updates: [
      { id: "demo_h1", score: 14, agreement: 0.85 },  // park hyatt — one vote away
      { id: "demo_f1", score: 10, agreement: 0.50 },  // united climbing
      { id: "demo_h2", score: 5, agreement: 0.25 },   // andaz
    ],
  },
];

// ── Demo Page ──

export default function TravelDemoPage() {
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

  // Cleanup timers on unmount
  useEffect(() => {
    return () => timersRef.current.forEach(clearTimeout);
  }, []);

  if (!mounted) return null;

  // ── Friend voting cascade — triggered after cards appear ──
  const startVotingCascade = useCallback(() => {
    if (votingStarted) return;
    setVotingStarted(true);

    VOTE_WAVES.forEach((wave) => {
      const t = setTimeout(() => {
        setItems((prev) =>
          prev.map((item) => {
            const update = wave.updates.find((u) => u.id === item.id);
            if (update) {
              return {
                ...item,
                weighted_score: update.score,
                agreement_score: update.agreement,
                state: update.agreement > 0 ? "ranked" : item.state,
              };
            }
            return item;
          })
        );
      }, wave.delay);
      timersRef.current.push(t);
    });
  }, [votingStarted]);

  // ── Swipe ──
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

  // ── Send message ──
  const sendMessage = useCallback(() => {
    const txt = input.trim();
    if (!txt) return;

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

    if (txt.toLowerCase().includes("@xark")) {
      setIsThinking(true);

      const t1 = setTimeout(() => {
        setIsThinking(false);

        setMessages((prev) => [
          ...prev,
          {
            id: `xark_${Date.now()}`,
            role: "xark",
            content: "found flights, hotels, and cars for tokyo",
            timestamp: Date.now(),
            senderName: "@xark",
          },
        ]);

        // Load all travel items at 0 score
        setItems(makeItems());

        // Auto-switch to Decide + start friend voting
        const t2 = setTimeout(() => {
          setView("decide");
          startVotingCascade();
        }, 800);
        timersRef.current.push(t2);
      }, 1500);
      timersRef.current.push(t1);
    }
  }, [input, startVotingCascade]);

  // ── Reaction — park hyatt consensus trigger ──
  const handleReaction = useCallback((itemId: string, signal: ReactionType) => {
    setReactions((prev) => {
      if (prev[itemId] === signal) {
        const next = { ...prev };
        delete next[itemId];
        return next;
      }
      return { ...prev, [itemId]: signal };
    });

    // Park Hyatt: user's love vote = 100% consensus
    if (itemId === "demo_h1" && signal === "love_it") {
      setItems((prev) =>
        prev.map((item) =>
          item.id === "demo_h1"
            ? { ...item, weighted_score: 19, agreement_score: 1.0, is_locked: true, state: "locked" }
            : item
        )
      );

      const t1 = setTimeout(() => setGoldBurst(true), 300);
      const t2 = setTimeout(() => setGoldBurst(false), 3300);
      timersRef.current.push(t1, t2);
    }
  }, []);

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
            tokyo april 2026
          </p>

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
            spaceId="demo_travel"
            spaceTitle="tokyo april 2026"
            messages={messages}
            isThinking={isThinking}
          />
        )}
        {view === "decide" && (
          <PossibilityHorizon
            spaceId="demo_travel"
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
              animation: "travelGoldBurst 3s ease-out forwards",
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
        @keyframes travelGoldBurst {
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
