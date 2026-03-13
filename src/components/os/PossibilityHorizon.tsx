"use client";

import { useRef, useState, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { heartSort, getConsensusState } from "@/lib/heart-sort";
import { ConsensusMark } from "./ConsensusMark";
import { useReactions } from "@/hooks/useReactions";
import type { ReactionType } from "@/hooks/useReactions";
import { supabase } from "@/lib/supabase";
import {
  colors,
  text,
  textColor,
  amberWash,
  reactions as reactionTokens,
  timing,
} from "@/lib/theme";

// ── Decision item from Supabase ──
interface DecisionItem {
  id: string;
  title: string;
  weighted_score: number;
  agreement_score: number;
  is_locked: boolean;
  state: string;
  metadata: {
    image_url?: string;
    price?: string;
    source?: string;
  } | null;
  created_at: string;
}

// ── Signal definitions ──
const SIGNALS: {
  type: ReactionType;
  label: string;
  color: string;
}[] = [
  { type: "love_it", label: "Love it", color: reactionTokens.loveIt.color },
  {
    type: "works_for_me",
    label: "Works for me",
    color: reactionTokens.worksForMe.color,
  },
  {
    type: "not_for_me",
    label: "Not for me",
    color: reactionTokens.notForMe.color,
  },
];

interface PossibilityHorizonProps {
  spaceId: string;
  userId?: string;
}

export function PossibilityHorizon({
  spaceId,
  userId,
}: PossibilityHorizonProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [dragStartX, setDragStartX] = useState(0);
  const [dragScrollLeft, setDragScrollLeft] = useState(0);
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeReactions, setActiveReactions] = useState<
    Record<string, ReactionType>
  >({});

  const { react, unreact, getUserReaction, isReacting } = useReactions();

  // ── Fetch decision items ──
  useEffect(() => {
    async function fetchItems() {
      const { data } = await supabase
        .from("decision_items")
        .select(
          "id, title, weighted_score, agreement_score, is_locked, state, metadata, created_at"
        )
        .eq("space_id", spaceId)
        .eq("is_locked", false);

      if (data) {
        setItems(data as DecisionItem[]);
        // Load user reactions
        if (userId) {
          const reactions: Record<string, ReactionType> = {};
          for (const item of data) {
            const r = await getUserReaction(item.id, userId);
            if (r) reactions[item.id] = r;
          }
          setActiveReactions(reactions);
        }
      }
      setLoading(false);
    }

    fetchItems();
  }, [spaceId, userId, getUserReaction]);

  // ── Subscribe to Realtime for live score updates ──
  useEffect(() => {
    const channel = supabase
      .channel(`horizon:${spaceId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "decision_items",
          filter: `space_id=eq.${spaceId}`,
        },
        (payload) => {
          const updated = payload.new as DecisionItem;
          setItems((prev) =>
            prev.map((i) => (i.id === updated.id ? updated : i))
          );
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [spaceId]);

  // ── Sort using heartSort ──
  const sorted = heartSort(
    items.map((item) => ({
      id: item.id,
      title: item.title,
      imageUrl: item.metadata?.image_url ?? "",
      weightedScore: item.weighted_score,
      agreementScore: item.agreement_score,
      isLocked: item.is_locked,
      createdAt: new Date(item.created_at).getTime(),
    }))
  );

  // ── Map sorted IDs back to full items for metadata access ──
  const itemMap = new Map(items.map((i) => [i.id, i]));

  // ── Pointer-based drag ──
  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    if (!scrollRef.current) return;
    setIsDragging(true);
    setDragStartX(e.clientX);
    setDragScrollLeft(scrollRef.current.scrollLeft);
    scrollRef.current.setPointerCapture(e.pointerId);
  }, []);

  const handlePointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!isDragging || !scrollRef.current) return;
      const dx = e.clientX - dragStartX;
      scrollRef.current.scrollLeft = dragScrollLeft - dx;
    },
    [isDragging, dragStartX, dragScrollLeft]
  );

  const handlePointerUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  // ── Handle reaction tap ──
  const handleReaction = useCallback(
    async (itemId: string, signal: ReactionType) => {
      if (isReacting) return;

      // Toggle: if same reaction, unreact
      if (activeReactions[itemId] === signal) {
        setActiveReactions((prev) => {
          const next = { ...prev };
          delete next[itemId];
          return next;
        });
        await unreact(itemId);
      } else {
        setActiveReactions((prev) => ({ ...prev, [itemId]: signal }));
        await react(itemId, signal);
      }
    },
    [activeReactions, isReacting, react, unreact]
  );

  if (loading) {
    return (
      <div
        className="flex items-center justify-center pt-32"
        style={{ opacity: 0.2 }}
      >
        <div
          style={{
            width: "6px",
            height: "6px",
            borderRadius: "50%",
            backgroundColor: colors.cyan,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
          }}
        />
        <p className="ml-4" style={{ ...text.label, color: colors.white }}>
          possibilities loading
        </p>
      </div>
    );
  }

  if (sorted.length === 0) {
    return (
      <div
        className="flex items-center justify-center pt-32"
        style={{ opacity: 0.2 }}
      >
        <p style={{ ...text.label, color: colors.white }}>
          no possibilities yet
        </p>
      </div>
    );
  }

  return (
    <div className="relative w-full" style={{ paddingTop: "120px" }}>
      <div
        ref={scrollRef}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        className="horizon-scroll flex snap-x snap-mandatory overflow-x-auto"
        style={{
          cursor: isDragging ? "grabbing" : "grab",
          WebkitOverflowScrolling: "touch",
        }}
      >
        <AnimatePresence>
          {sorted.map((item, index) => {
            const consensusState = getConsensusState(item.agreementScore);
            const full = itemMap.get(item.id);
            const imageUrl = full?.metadata?.image_url;
            const price = full?.metadata?.price;
            const source = full?.metadata?.source;
            const currentReaction = activeReactions[item.id];

            return (
              <motion.div
                key={item.id}
                className="relative flex-shrink-0 snap-center"
                style={{
                  width: "85vw",
                  maxWidth: "480px",
                  height: "70vh",
                  maxHeight: "640px",
                }}
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{
                  duration: 0.4,
                  delay: index * timing.staggerDelay,
                }}
              >
                {/* ── Edge-to-edge image or gradient placeholder ── */}
                <div
                  className="absolute inset-0"
                  style={{
                    backgroundImage: imageUrl
                      ? `url(${imageUrl})`
                      : `linear-gradient(135deg, rgba(var(--xark-amber-rgb), 0.15) 0%, rgba(var(--xark-accent-rgb), 0.08) 100%)`,
                    backgroundSize: "cover",
                    backgroundPosition: "center",
                  }}
                />

                {/* ── Bottom vignette ── */}
                <div
                  className="absolute inset-0"
                  style={{
                    background:
                      "linear-gradient(to top, rgba(var(--xark-void-rgb), 0.95) 0%, rgba(var(--xark-void-rgb), 0.4) 40%, transparent 70%)",
                  }}
                />

                {/* ── Amber atmospheric wash from weightedScore ── */}
                <div
                  className="pointer-events-none absolute inset-0"
                  style={{
                    background: `linear-gradient(to top, rgba(var(--xark-amber-rgb), ${amberWash(item.weightedScore)}) 0%, transparent 50%)`,
                  }}
                />

                {/* ── Content overlay ── */}
                <div className="absolute inset-x-0 bottom-0 px-6 pb-8">
                  {/* ── Title ── */}
                  <p
                    style={{
                      ...text.listTitle,
                      color: colors.white,
                      opacity: 0.9,
                    }}
                  >
                    {item.title}
                  </p>

                  {/* ── Price + source ── */}
                  {(price || source) && (
                    <div className="mt-1 flex items-center gap-3">
                      {price && (
                        <span
                          style={{
                            ...text.subtitle,
                            color: colors.white,
                            opacity: 0.5,
                          }}
                        >
                          {price}
                        </span>
                      )}
                      {source && (
                        <span
                          style={{
                            ...text.recency,
                            color: colors.white,
                            opacity: 0.25,
                          }}
                        >
                          {source}
                        </span>
                      )}
                    </div>
                  )}

                  {/* ── Consensus mark + percentage ── */}
                  <div className="mt-3 flex items-center gap-3">
                    <ConsensusMark
                      agreementScore={item.agreementScore}
                      state={consensusState}
                      size={24}
                    />
                    <span
                      style={{
                        ...text.recency,
                        color: colors.white,
                        opacity: 0.4,
                        textTransform: "uppercase",
                      }}
                    >
                      {Math.round(item.agreementScore * 100)}% consensus
                    </span>
                  </div>

                  {/* ── Reaction signals — floating text, no buttons, no boxes ── */}
                  <div className="mt-4 flex items-center gap-5">
                    {SIGNALS.map((signal) => {
                      const isActive = currentReaction === signal.type;
                      return (
                        <span
                          key={signal.type}
                          role="button"
                          tabIndex={0}
                          onClick={() => handleReaction(item.id, signal.type)}
                          onKeyDown={(e) => {
                            if (e.key === "Enter")
                              handleReaction(item.id, signal.type);
                          }}
                          className="outline-none"
                          style={{
                            ...text.label,
                            color: signal.color,
                            opacity: isActive
                              ? 0.9
                              : currentReaction
                                ? 0.2
                                : 0.5,
                            cursor: "pointer",
                            transition: `opacity ${timing.transition} ease`,
                          }}
                        >
                          {signal.label}
                        </span>
                      );
                    })}
                  </div>
                </div>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>

      <style jsx>{`
        .horizon-scroll::-webkit-scrollbar {
          display: none;
        }
        .horizon-scroll {
          scrollbar-width: none;
          -ms-overflow-style: none;
        }
      `}</style>
    </div>
  );
}
