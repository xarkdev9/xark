"use client";

import { useState, useEffect, useCallback, useMemo, useRef } from "react";
import { heartSort } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import { getConsensusState } from "@/lib/heart-sort";
import { useReactions } from "@/hooks/useReactions";
import type { ReactionType } from "@/hooks/useReactions";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import { supabase } from "@/lib/supabase";
import {
  colors,
  text,
  textColor,
  amberWash,
  reactions as reactionTokens,
  timing,
  layout,
  opacity,
} from "@/lib/theme";

// ══════════════════════════════════════════════════
// TYPES
// ══════════════════════════════════════════════════

interface DecisionItem {
  id: string;
  title: string;
  category: string;
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

interface DecisionCardItem {
  id: string;
  title: string;
  imageUrl: string;
  price: string;
  source: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  createdAt: number;
}

interface DecisionCardProps extends DecisionCardItem {
  activeReaction?: ReactionType;
  onReact: (itemId: string, signal: ReactionType) => void;
}

interface CategorySectionProps {
  category: string;
  items: DecisionCardItem[];
  maxConviction: number;
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
}

interface PossibilityHorizonProps {
  spaceId: string;
  userId?: string;
}

// ── Demo items — used when Supabase is unreachable ──
const DEMO_ITEMS: Record<string, DecisionItem[]> = {
  "space_san-diego-trip": [
    { id: "demo_h1", title: "Hotel Del Coronado", category: "Hotel", weighted_score: 10, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { price: "$450/nt", source: "booking.com" }, created_at: new Date().toISOString() },
    { id: "demo_h2", title: "Coronado Island Marriott", category: "Hotel", weighted_score: 3, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { price: "$320/nt", source: "marriott.com" }, created_at: new Date().toISOString() },
    { id: "demo_a1", title: "Surf Lessons at La Jolla", category: "Activity", weighted_score: 6, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { price: "$95/person", source: "surfschool.com" }, created_at: new Date().toISOString() },
    { id: "demo_a2", title: "Balboa Park", category: "Activity", weighted_score: 4, agreement_score: 0.45, is_locked: false, state: "proposed", metadata: { price: "Free" }, created_at: new Date().toISOString() },
    { id: "demo_d1", title: "Gaslamp Quarter Dinner", category: "Dining", weighted_score: 8, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { price: "$65/person" }, created_at: new Date().toISOString() },
  ],
};

// ── Signal definitions ──
const SIGNALS: { type: ReactionType; label: string; color: string }[] = [
  { type: "love_it", label: "Love it", color: reactionTokens.loveIt.color },
  { type: "works_for_me", label: "Works for me", color: reactionTokens.worksForMe.color },
  { type: "not_for_me", label: "Not for me", color: reactionTokens.notForMe.color },
];

// ── Consensus state → color mapping (static, no animation) ──
function consensusColor(state: ConsensusState): string {
  if (state === "ignited") return colors.gold;
  if (state === "steady") return colors.cyan;
  return colors.amber;
}

// ══════════════════════════════════════════════════
// DECISION CARD
// ══════════════════════════════════════════════════

function DecisionCard({
  id,
  title,
  imageUrl,
  price,
  source,
  weightedScore,
  agreementScore,
  activeReaction,
  onReact,
}: DecisionCardProps) {
  const consensusState = getConsensusState(agreementScore);

  return (
    <div
      className="relative flex-shrink-0 snap-start"
      style={{ width: "280px", height: "360px" }}
    >
      {/* ── Image or gradient placeholder ── */}
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

      {/* ── Amber wash from weightedScore ── */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background: `linear-gradient(to top, ${amberWash(weightedScore)} 0%, transparent 50%)`,
        }}
      />

      {/* ── Content overlay ── */}
      <div className="absolute inset-x-0 bottom-0 px-4 pb-4">
        <p style={{ ...text.listTitle, color: colors.white, opacity: 0.9 }}>
          {title}
        </p>

        {(price || source) && (
          <div className="mt-1 flex items-center gap-3">
            {price && (
              <span style={{ ...text.subtitle, color: colors.white, opacity: 0.5 }}>
                {price}
              </span>
            )}
            {source && (
              <span style={{ ...text.recency, color: colors.white, opacity: 0.25 }}>
                {source}
              </span>
            )}
          </div>
        )}

        {/* ── Static consensus label (no animated ConsensusMark) ── */}
        <div className="mt-2">
          <span
            style={{
              ...text.recency,
              color: consensusColor(consensusState),
              opacity: 0.5,
              textTransform: "uppercase",
            }}
          >
            {Math.round(agreementScore * 100)}% consensus
          </span>
        </div>

        {/* ── Reaction signals ── */}
        <div className="mt-3 flex items-center gap-4">
          {SIGNALS.map((signal) => {
            const isActive = activeReaction === signal.type;
            return (
              <span
                key={signal.type}
                role="button"
                tabIndex={0}
                onClick={() => onReact(id, signal.type)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") onReact(id, signal.type);
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: signal.color,
                  opacity: isActive ? 0.9 : activeReaction ? 0.2 : 0.5,
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
    </div>
  );
}

// ══════════════════════════════════════════════════
// CATEGORY SECTION
// ══════════════════════════════════════════════════

function CategorySection({
  category,
  items,
  maxConviction,
  activeReactions,
  onReact,
}: CategorySectionProps) {
  const allLocked = items.length > 0 && items.every((i) => i.isLocked);

  // ── Settled row — all items locked ──
  if (allLocked) {
    const lockedTitle = items[0]?.title ?? "";
    return (
      <div className="flex items-center gap-3" style={{ padding: "4px 0" }}>
        <div
          style={{
            width: "4px",
            height: "4px",
            borderRadius: "50%",
            backgroundColor: colors.green,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
            flexShrink: 0,
          }}
        />
        <span style={{ ...text.label, color: textColor(0.3) }}>
          {category}
        </span>
        <span style={{ ...text.recency, color: textColor(0.25) }}>
          {lockedTitle}
          {items.length > 1 ? ` + ${items.length - 1} more` : ""}
        </span>
      </div>
    );
  }

  // ── Open section — header + conviction strip + card scroll ──
  return (
    <div>
      {/* ── Header + conviction strip ── */}
      <div className="flex items-center gap-3">
        <span style={{ ...text.label, color: textColor(0.35), flexShrink: 0 }}>
          {category}
        </span>
        <div style={{ flex: 1, height: "1px", position: "relative" }}>
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              height: "1px",
              width: `${Math.max(maxConviction * 100, 3)}%`,
              backgroundColor: colors.cyan,
              opacity: 0.3,
              transition: `width ${timing.transition} ease`,
            }}
          />
        </div>
      </div>

      {/* ── Horizontal card scroll ── */}
      <div
        className="horizon-scroll flex snap-x snap-mandatory overflow-x-auto"
        style={{
          marginTop: "12px",
          gap: "12px",
          paddingRight: "24px",
          WebkitOverflowScrolling: "touch",
        }}
      >
        {items.map((item) => (
          <DecisionCard
            key={item.id}
            {...item}
            activeReaction={activeReactions[item.id]}
            onReact={onReact}
          />
        ))}
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════
// POSSIBILITY HORIZON — ORCHESTRATOR
// ══════════════════════════════════════════════════

export function PossibilityHorizon({ spaceId, userId }: PossibilityHorizonProps) {
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeReactions, setActiveReactions] = useState<Record<string, ReactionType>>({});
  const [input, setInput] = useState("");
  const [inputFocused, setInputFocused] = useState(false);
  const [errorWhisper, setErrorWhisper] = useState(false);

  const { react, unreact, batchGetUserReactions, isReacting } = useReactions();

  // ── Voice input ──
  const { isListening, isXarkListening, transcript, startListening, startXarkListening, stopListening } =
    useVoiceInput();
  const longPressRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (transcript) setInput(transcript);
  }, [transcript]);

  // ── Fetch ALL decision items (locked + unlocked) ──
  useEffect(() => {
    async function fetchItems() {
      const { data } = await supabase
        .from("decision_items")
        .select("id, title, category, weighted_score, agreement_score, is_locked, state, metadata, created_at")
        .eq("space_id", spaceId);

      if (data && data.length > 0) {
        setItems(data as DecisionItem[]);
        if (userId) {
          const ids = data.map((d) => d.id);
          const reactions = await batchGetUserReactions(ids, userId);
          setActiveReactions(reactions);
        }
      } else {
        // Demo fallback when Supabase is unreachable or empty
        setItems(DEMO_ITEMS[spaceId] ?? []);
      }
      setLoading(false);
    }
    fetchItems();
  }, [spaceId, userId, batchGetUserReactions]);

  // ── Realtime: UPDATE + INSERT ──
  useEffect(() => {
    const channel = supabase
      .channel(`horizon:${spaceId}`)
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const updated = payload.new as DecisionItem;
          setItems((prev) => prev.map((i) => (i.id === updated.id ? updated : i)));
        }
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const inserted = payload.new as DecisionItem;
          setItems((prev) => {
            if (prev.some((i) => i.id === inserted.id)) return prev;
            return [...prev, inserted];
          });
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [spaceId]);

  // ── Sort + group by category (memoized) ──
  const grouped = useMemo(() => {
    const sortable = items.map((item) => ({
      id: item.id,
      title: item.title,
      imageUrl: item.metadata?.image_url ?? "",
      weightedScore: item.weighted_score,
      agreementScore: item.agreement_score,
      isLocked: item.is_locked,
      createdAt: new Date(item.created_at).getTime(),
    }));

    const sorted = heartSort(sortable);
    const metaMap = new Map(items.map((i) => [i.id, i]));
    const groups: Record<string, { items: DecisionCardItem[]; maxConviction: number }> = {};

    for (const item of sorted) {
      const full = metaMap.get(item.id);
      const category = full?.category || "general";
      const cardItem: DecisionCardItem = {
        ...item,
        price: full?.metadata?.price ?? "",
        source: full?.metadata?.source ?? "",
      };

      if (!groups[category]) {
        groups[category] = { items: [], maxConviction: 0 };
      }
      groups[category].items.push(cardItem);
      groups[category].maxConviction = Math.max(
        groups[category].maxConviction,
        item.agreementScore
      );
    }

    return groups;
  }, [items]);

  // ── Reaction handler ──
  const handleReaction = useCallback(
    async (itemId: string, signal: ReactionType) => {
      if (isReacting) return;
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

  // ── @xark send (Decide input is @xark-only — silently ignore non-@xark messages) ──
  const handleSend = useCallback(async () => {
    const txt = input.trim();
    if (!txt) return;
    if (!txt.includes("@xark")) return;
    setInput("");

    try {
      const response = await fetch("/api/xark", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: txt, spaceId }),
      });
      if (!response.ok) {
        setErrorWhisper(true);
        setTimeout(() => setErrorWhisper(false), 2000);
      }
    } catch {
      setErrorWhisper(true);
      setTimeout(() => setErrorWhisper(false), 2000);
    }
  }, [input, spaceId]);

  const categoryNames = Object.keys(grouped);
  const hasItems = categoryNames.length > 0;

  if (loading) {
    return (
      <div className="flex items-center justify-center" style={{ paddingTop: "200px", opacity: 0.2 }}>
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
          loading
        </p>
      </div>
    );
  }

  return (
    <div className="relative flex min-h-svh flex-col">
      {/* ── Category Sections ── */}
      <div
        className="flex-1 overflow-y-auto px-6"
        style={{
          paddingTop: "160px",
          paddingBottom: "30vh",
          display: "flex",
          flexDirection: "column",
          gap: "40px",
        }}
      >
        {hasItems ? (
          categoryNames.map((category) => (
            <CategorySection
              key={category}
              category={category}
              items={grouped[category].items}
              maxConviction={grouped[category].maxConviction}
              activeReactions={activeReactions}
              onReact={handleReaction}
            />
          ))
        ) : (
          <>
            <div style={{ flex: 1 }} />
            <div style={{ maxWidth: "640px", marginBottom: "16px" }}>
              <span style={{ ...text.label, color: colors.cyan, opacity: 0.4 }}>
                @xark
              </span>
              <p className="mt-1" style={{ ...text.hint, color: colors.white, opacity: 0.35 }}>
                {`try "@xark find hotels near the beach" or "@xark add dates aug 15–25"`}
              </p>
            </div>
          </>
        )}
      </div>

      {/* ── Input Zone — fixed bottom, @xark-only ── */}
      <div
        className="fixed inset-x-0 bottom-0 px-6 pt-12"
        style={{
          paddingBottom: layout.inputBottom,
          background:
            "linear-gradient(to top, rgba(var(--xark-void-rgb), 1) 0%, rgba(var(--xark-void-rgb), 1) 40%, rgba(var(--xark-void-rgb), 0.8) 70%, transparent 100%)",
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          <div className="relative flex items-center gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") handleSend(); }}
              placeholder={
                isXarkListening
                  ? "@xark is listening..."
                  : isListening
                    ? "listening..."
                    : "message, or @xark for ideas"
              }
              spellCheck={false}
              autoComplete="off"
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              className="w-full bg-transparent outline-none"
              style={{ ...text.input, color: colors.white, caretColor: colors.cyan }}
            />
            {/* ── Mic ── */}
            <span
              role="button"
              tabIndex={0}
              onPointerDown={() => {
                longPressRef.current = setTimeout(() => {
                  startXarkListening();
                  longPressRef.current = null;
                }, 500);
              }}
              onPointerUp={() => {
                if (longPressRef.current) {
                  clearTimeout(longPressRef.current);
                  longPressRef.current = null;
                  if (isListening || isXarkListening) stopListening();
                  else startListening();
                }
              }}
              onPointerLeave={() => {
                if (longPressRef.current) {
                  clearTimeout(longPressRef.current);
                  longPressRef.current = null;
                }
              }}
              className="outline-none select-none"
              style={{
                ...text.label,
                color: isXarkListening ? colors.cyan : colors.white,
                opacity: isListening || isXarkListening ? 0.9 : 0.3,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                flexShrink: 0,
              }}
            >
              {isListening || isXarkListening ? (
                <span className="flex items-center gap-2">
                  <span
                    style={{
                      display: "inline-block",
                      width: "6px",
                      height: "6px",
                      borderRadius: "50%",
                      backgroundColor: isXarkListening ? colors.cyan : colors.white,
                      animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                    }}
                  />
                </span>
              ) : (
                "mic"
              )}
            </span>
            {/* ── Accent underline ── */}
            <div
              className="absolute -bottom-2 left-0 h-px w-full"
              style={{
                background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                opacity: inputFocused ? 1 : 0.15,
                animation: inputFocused ? `ambientBreath ${timing.breath} ease-in-out infinite` : "none",
                transition: `opacity ${timing.transition} ease`,
              }}
            />
          </div>

          {/* ── Error whisper ── */}
          {errorWhisper && (
            <p className="mt-2" style={{ ...text.hint, color: textColor(0.3) }}>
              couldn't reach @xark — try again
            </p>
          )}
        </div>
      </div>

      <style jsx>{`
        .horizon-scroll::-webkit-scrollbar { display: none; }
        .horizon-scroll { scrollbar-width: none; -ms-overflow-style: none; }
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.ghost};
          letter-spacing: 0.12em;
        }
      `}</style>
    </div>
  );
}
