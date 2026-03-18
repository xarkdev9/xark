"use client";

import React, { useState, useEffect, useCallback, useMemo, useRef } from "react";
import { motion, AnimatePresence, useScroll, useTransform } from "framer-motion";
import { heartSort } from "@/lib/heart-sort";
import { getConsensusState } from "@/lib/heart-sort";
import { useReactions } from "@/hooks/useReactions";
import type { ReactionType } from "@/hooks/useReactions";
import Image from "next/image";
import { supabase } from "@/lib/supabase";
import { DecisionCard } from "@/components/os/DecisionCard";
import {
  colors,
  ink,
  text,
  timing,
} from "@/lib/theme";

// ══════════════════════════════════════════════
// TYPES
// ══════════════════════════════════════════════

interface DecisionItem {
  id: string;
  title: string;
  category: string;
  weighted_score: number;
  agreement_score: number;
  is_locked: boolean;
  state: string;
  lock_deadline?: string | null;
  metadata: {
    image_url?: string;
    price?: string;
    source?: string;
    search_batch?: string;
    search_label?: string;
  } | null;
  created_at: string;
}

interface DecisionCardItem {
  id: string;
  title: string;
  imageUrl: string;
  price: string;
  source: string;
  category: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  createdAt: number;
  lockDeadline?: string | null;
}

interface PossibilityHorizonProps {
  spaceId: string;
  userId?: string;
  authLoading?: boolean;
  isThinking?: boolean;
  playgroundItems?: DecisionItem[];
  playgroundReactions?: Record<string, import("@/hooks/useReactions").ReactionType>;
  onPlaygroundReact?: (itemId: string, signal: import("@/hooks/useReactions").ReactionType) => void;
}

// Card surfaces — dark, theme-independent
const CARD_GOLD = "#FFCF40";
const CARD_CYAN = "#40E0FF";
const CARD_AMBER = "#F5A623";

// ── Demo items ──
const DEMO_ITEMS: Record<string, DecisionItem[]> = {
  "space_san-diego-trip": [
    { id: "demo_h1", title: "Hotel Del Coronado", category: "Hotel", weighted_score: 10, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { image_url: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=600&h=400&fit=crop", price: "$450/nt", source: "booking.com" }, created_at: "2025-08-01T12:00:00Z" },
    { id: "demo_h2", title: "Coronado Island Marriott", category: "Hotel", weighted_score: 3, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=500&fit=crop", price: "$320/nt", source: "marriott.com" }, created_at: "2025-08-01T12:00:00Z" },
    { id: "demo_h3", title: "La Valencia Hotel", category: "Hotel", weighted_score: 2, agreement_score: 0.30, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=400&h=500&fit=crop", price: "$520/nt", source: "booking.com" }, created_at: "2025-08-01T12:00:00Z" },
    { id: "demo_a1", title: "Surf Lessons at La Jolla", category: "Activity", weighted_score: 6, agreement_score: 0.67, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1502680390548-bdbac40e4a9f?w=400&h=500&fit=crop", price: "$95/person", source: "surfschool.com" }, created_at: "2025-08-01T12:00:00Z" },
    { id: "demo_a2", title: "Balboa Park", category: "Activity", weighted_score: 4, agreement_score: 0.45, is_locked: false, state: "proposed", metadata: { image_url: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=400&h=500&fit=crop", price: "Free" }, created_at: "2025-08-01T12:00:00Z" },
    { id: "demo_a3", title: "Whale Watching", category: "Activity", weighted_score: 1, agreement_score: 0, is_locked: false, state: "proposed", metadata: { image_url: "https://images.unsplash.com/photo-1568430462989-44163eb1752f?w=400&h=500&fit=crop", price: "$55/person" }, created_at: "2025-08-01T12:00:00Z" },
    { id: "demo_d1", title: "Gaslamp Quarter Dinner", category: "Dining", weighted_score: 8, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { image_url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&h=500&fit=crop", price: "$65/person" }, created_at: "2025-08-01T12:00:00Z" },
  ],
};

const PLURAL_MAP: Record<string, string> = {
  hotel: "hotels", activity: "activities", flight: "flights",
  dining: "dining", experience: "experiences", restaurant: "restaurants", general: "general",
};

function pluralizeCategory(cat: string): string {
  const lower = cat.toLowerCase();
  // If it's a known category, pluralize. Otherwise it's a search_label — use as-is.
  return PLURAL_MAP[lower] ?? lower;
}

function categoryVital(items: DecisionCardItem[]): { label: string; color: string } {
  const total = items.length;
  const rated = items.filter((i) => i.agreementScore > 0).length;
  const topItem = items[0];

  if (topItem && topItem.agreementScore >= 0.8) {
    const pct = Math.round(topItem.agreementScore * 100);
    return { label: `${pct}% on #1 · ${rated} of ${total}`, color: CARD_GOLD };
  }
  if (rated === 0) return { label: "needs votes", color: CARD_AMBER };
  return { label: `${rated} of ${total} rated`, color: CARD_CYAN };
}

function heroConsensusColor(score: number): string {
  const state = getConsensusState(score);
  if (state === "ignited") return CARD_GOLD;
  if (state === "steady") return CARD_CYAN;
  return CARD_AMBER;
}

// ══════════════════════════════════════════════
// HERO BANNER — full-width, cinematic, Netflix-style
// ══════════════════════════════════════════════

function HeroBanner({
  heroUrl,
  spaceTitle,
}: {
  heroUrl: string;
  spaceTitle: string;
}) {
  const [imgLoaded, setImgLoaded] = useState(false);

  // Cinematic parallax: bind image Y + opacity to scroll position
  const { scrollY } = useScroll();
  const y = useTransform(scrollY, [0, 400], [0, 150]);
  const heroOpacity = useTransform(scrollY, [0, 300], [1, 0.2]);

  return (
    <motion.div
      className="absolute top-0 inset-x-0 overflow-hidden"
      style={{ height: "380px", zIndex: 0 }}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
    >
      {/* Parallax layer */}
      <motion.div className="absolute inset-0" style={{ y, opacity: heroOpacity }}>
        <motion.div
          className="absolute inset-0"
          initial={{ scale: 1.15 }}
          animate={{ scale: imgLoaded ? 1 : 1.15 }}
          transition={{ duration: 3, ease: [0.22, 1, 0.36, 1] }}
        >
          <Image
            src={heroUrl}
            alt={spaceTitle}
            fill
            sizes="100vw"
            priority
            className="object-cover"
            onLoad={() => setImgLoaded(true)}
          />
        </motion.div>
      </motion.div>

      {/* Progressive scrim */}
      <div
        className="absolute inset-0"
        style={{
          background: "linear-gradient(180deg, rgba(0,0,0,0.08) 0%, rgba(0,0,0,0.02) 35%, rgba(var(--xark-void-rgb),0.4) 65%, rgba(var(--xark-void-rgb),0.85) 82%, var(--xark-void) 95%)",
        }}
      />
    </motion.div>
  );
}

// ══════════════════════════════════════════════
// SHIMMER
// ══════════════════════════════════════════════

function ShimmerCard({ delay = 0 }: { delay?: number }) {
  return (
    <motion.div
      className="flex-shrink-0"
      style={{
        width: "140px", height: "200px", borderRadius: "14px",
        background: "linear-gradient(90deg, rgba(255,255,255,0.02) 0%, rgba(255,255,255,0.06) 50%, rgba(255,255,255,0.02) 100%)",
        backgroundSize: "200px 100%", animation: "shimmer 1.5s ease-in-out infinite",
      }}
      initial={{ opacity: 0, scale: 0.92 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay, duration: 0.4 }}
    />
  );
}

// ══════════════════════════════════════════════
// CATEGORY RAIL — the row of cards
// ══════════════════════════════════════════════

const CategoryRail = React.memo(function CategoryRail({
  category,
  items,
  activeReactions,
  onReact,
  onFinalize,
  railIndex,
}: {
  category: string;
  items: DecisionCardItem[];
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
  onFinalize?: (itemId: string) => void;
  railIndex: number;
}) {
  const allLocked = items.length > 0 && items.every((i) => i.isLocked);
  const displayName = pluralizeCategory(category);
  const vital = categoryVital(items);
  const railDelay = 0.2 + railIndex * 0.25;

  if (allLocked) {
    const lockedTitle = items[0]?.title ?? "";
    return (
      <motion.div
        className="flex items-center gap-3 px-6"
        style={{ padding: "8px 24px" }}
        initial={{ opacity: 0, y: 16 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ delay: railDelay, duration: 0.5, ease: [0.22, 1, 0.36, 1] as const }}
      >
        <div style={{
          width: "5px", height: "5px", borderRadius: "50%",
          backgroundColor: colors.green,
          animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
          flexShrink: 0,
        }} />
        <span style={{ ...text.label, color: ink.tertiary }}>{displayName}</span>
        <span style={{ ...text.recency, color: ink.tertiary }}>
          {lockedTitle}{items.length > 1 ? ` + ${items.length - 1} more` : ""}
        </span>
      </motion.div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.15 }}
      transition={{ delay: railDelay, duration: 0.7, ease: [0.22, 1, 0.36, 1] as const }}
    >
      {/* Rail header — editorial, large */}
      <div className="flex items-baseline justify-between px-6" style={{ marginBottom: "16px" }}>
        <span style={{ fontSize: "1.75rem", fontWeight: 300, color: colors.white, opacity: 0.8, letterSpacing: "-0.01em" }}>
          {displayName}
        </span>
        <span style={{ fontSize: "12px", fontWeight: 300, color: vital.color, opacity: 0.6, letterSpacing: "0.06em" }}>
          {vital.label}
        </span>
      </div>

      {/* Horizontal snap scroll — immersive cards, one at a time with peek */}
      <div
        className="horizon-scroll flex overflow-x-auto snap-x snap-mandatory"
        style={{
          gap: "12px",
          paddingLeft: "20px",
          paddingRight: "20px",
          paddingBottom: "8px",
          WebkitOverflowScrolling: "touch",
          scrollbarWidth: "none",
        }}
      >
        {items.map((item, idx) => (
          <DecisionCard
            key={item.id}
            id={item.id}
            title={item.title}
            imageUrl={item.imageUrl || undefined}
            category={item.category}
            price={item.price}
            source={item.source}
            weightedScore={item.weightedScore}
            agreementScore={item.agreementScore}
            isLocked={item.isLocked}
            activeReaction={activeReactions[item.id]}
            onReact={onReact}
            entranceDelay={railDelay + 0.1 + idx * 0.12}
            lazyImage={idx >= 3}
            lockDeadline={item.lockDeadline}
            onFinalize={onFinalize}
          />
        ))}

        {items.length > 10 && (
          <div className="flex flex-shrink-0 items-center justify-center snap-center" style={{ width: "60px", minHeight: "clamp(320px, 50dvh, 440px)" }}>
            <span style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary }}>+{items.length - 10}</span>
          </div>
        )}
      </div>
    </motion.div>
  );
}, (prev, next) =>
  prev.category === next.category &&
  prev.items === next.items &&
  prev.activeReactions === next.activeReactions &&
  prev.onFinalize === next.onFinalize &&
  prev.railIndex === next.railIndex
);

// ══════════════════════════════════════════════
// POSSIBILITY HORIZON — ORCHESTRATOR
// ══════════════════════════════════════════════

export function PossibilityHorizon({ spaceId, userId, authLoading, isThinking, playgroundItems, playgroundReactions, onPlaygroundReact }: PossibilityHorizonProps) {
  const isPlayground = !!playgroundItems;
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(!isPlayground);
  const [heroUrl, setHeroUrl] = useState<string | null>(null);
  const [spaceTitle, setSpaceTitle] = useState("");
  const [activeReactions, setActiveReactions] = useState<Record<string, ReactionType>>({});
  const [incomingQueue, setIncomingQueue] = useState<DecisionItem[]>([]);
  const [liveWhisper, setLiveWhisper] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  const { react, unreact, batchGetUserReactions, isReacting } = useReactions();

  // ── Hero images — deterministic per space (no Unsplash key needed) ──
  const HERO_POOL = [
    "https://images.unsplash.com/photo-1538097304804-2a1b932466a9?w=800&h=500&fit=crop", // san diego coast
    "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&h=500&fit=crop", // tokyo night
    "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&h=500&fit=crop", // bali temple
    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=500&fit=crop", // tropical beach
    "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800&h=500&fit=crop", // road trip
    "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&h=500&fit=crop", // mountain lake
    "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=500&fit=crop", // camping
    "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&h=500&fit=crop", // dinner
    "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&h=500&fit=crop", // sunset valley
    "https://images.unsplash.com/photo-1530789253388-582c481c54b0?w=800&h=500&fit=crop", // travel map
  ];

  // Hash spaceId to pick a deterministic hero — same space always gets same image
  function heroForSpace(id: string): string {
    let hash = 0;
    for (let i = 0; i < id.length; i++) hash = ((hash << 5) - hash + id.charCodeAt(i)) | 0;
    return HERO_POOL[Math.abs(hash) % HERO_POOL.length];
  }

  // ── Fetch space metadata (hero photo + title) ──
  useEffect(() => {
    const fallback = heroForSpace(spaceId);
    const fallbackTitle = spaceId.replace(/^space_/, "").replace(/-/g, " ");

    Promise.resolve(
      supabase
        .from("spaces")
        .select("title, metadata")
        .eq("id", spaceId)
        .single()
    ).then(({ data }) => {
      setHeroUrl(data?.metadata?.hero_url ?? fallback);
      setSpaceTitle(data?.title ?? fallbackTitle);
    }).catch(() => {
      setHeroUrl(fallback);
      setSpaceTitle(fallbackTitle);
    });
  }, [spaceId]);

  // ── Load playground items when provided ──
  useEffect(() => {
    if (isPlayground && playgroundItems) {
      setItems(playgroundItems as DecisionItem[]);
      setLoading(false);
    }
  }, [isPlayground, playgroundItems]);

  // ── Fetch decision items (skip in playground) ──
  useEffect(() => {
    if (authLoading || isPlayground) return;
    async function fetchItems() {
      const { data } = await supabase
        .from("decision_items")
        .select("id, title, category, weighted_score, agreement_score, is_locked, state, lock_deadline, metadata, created_at")
        .eq("space_id", spaceId)
        .order("weighted_score", { ascending: false })
        .limit(100);

      if (data && data.length > 0) {
        setItems(data as DecisionItem[]);
        if (userId) {
          const ids = data.map((d) => d.id);
          const reactions = await batchGetUserReactions(ids, userId);
          setActiveReactions(reactions);
        }
      } else {
        setItems(DEMO_ITEMS[spaceId] ?? []);
      }
      setLoading(false);
    }
    fetchItems();
  }, [spaceId, userId, batchGetUserReactions, authLoading]);

  // ── Realtime ──
  useEffect(() => {
    const channel = supabase
      .channel(`horizon:${spaceId}`)
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const updated = payload.new as DecisionItem;
          setItems((prev) => {
            const oldItem = prev.find((i) => i.id === updated.id);
            // Multiplayer presence: if score went up, someone just loved it
            if (oldItem && updated.weighted_score > oldItem.weighted_score) {
              setLiveWhisper(`someone loved ${updated.title.toLowerCase()}`);
              setTimeout(() => setLiveWhisper(null), 3000);
            }
            return prev.map((i) => (i.id === updated.id ? updated : i));
          });
        }
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "decision_items", filter: `space_id=eq.${spaceId}` },
        (payload) => {
          const inserted = payload.new as DecisionItem;
          // Dealer queue: don't slam on the table, put in the deck
          setIncomingQueue((prev) => {
            if (prev.some((i) => i.id === inserted.id)) return prev;
            return [...prev, inserted];
          });
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [spaceId]);

  // ── Dealer effect: unpacks queue one card at a time ──
  useEffect(() => {
    if (incomingQueue.length > 0) {
      const timer = setTimeout(() => {
        const nextCard = incomingQueue[0];
        setItems((prev) => {
          if (prev.some((i) => i.id === nextCard.id)) return prev;
          return [...prev, nextCard];
        });
        setIncomingQueue((prev) => prev.slice(1));

        // Haptic tick: let the user physically feel each card arriving
        if (typeof navigator !== "undefined" && navigator.vibrate) {
          navigator.vibrate(10);
        }
      }, 300);
      return () => clearTimeout(timer);
    }
  }, [incomingQueue]);

  // ── Sort + group — ALL items go into rails, hero is the destination photo ──
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
    const groups: Record<string, DecisionCardItem[]> = {};

    for (const item of sorted) {
      const full = metaMap.get(item.id);
      // Group by search_label when present (e.g. "coronado island hotel"), else by category
      const groupKey = full?.metadata?.search_label || full?.category || "general";
      if (!groups[groupKey]) groups[groupKey] = [];
      groups[groupKey].push({
        ...item,
        category: full?.category || "general",
        price: full?.metadata?.price ?? "",
        source: full?.metadata?.source ?? "",
        lockDeadline: full?.lock_deadline ?? null,
      });
    }

    return groups;
  }, [items]);

  // ── Reactions — optimistic with rollback on failure ──
  // No global isReacting guard — each item can be voted independently
  const pendingItems = useRef(new Set<string>());
  const handleReaction = useCallback(
    async (itemId: string, signal: ReactionType) => {
      // Per-item debounce: skip if this specific item has a pending RPC
      if (pendingItems.current.has(itemId)) return;
      pendingItems.current.add(itemId);

      const prevReaction = activeReactions[itemId];

      try {
        if (prevReaction === signal) {
          // Toggle off
          setActiveReactions((prev) => {
            const next = { ...prev };
            delete next[itemId];
            return next;
          });
          const ok = await unreact(itemId);
          if (!ok) {
            setActiveReactions((prev) => ({ ...prev, [itemId]: prevReaction }));
          }
        } else {
          // Set new reaction
          setActiveReactions((prev) => ({ ...prev, [itemId]: signal }));
          const ok = await react(itemId, signal);
          if (!ok) {
            if (prevReaction) {
              setActiveReactions((prev) => ({ ...prev, [itemId]: prevReaction }));
            } else {
              setActiveReactions((prev) => {
                const next = { ...prev };
                delete next[itemId];
                return next;
              });
            }
          }
        }
      } finally {
        pendingItems.current.delete(itemId);
      }
    },
    [activeReactions, react, unreact]
  );

  // ── Finalize: manual fallback when cron didn't fire ──
  const handleFinalize = useCallback(async (itemId: string) => {
    try {
      const { claimItem } = await import("@/lib/claims");
      await claimItem(itemId, userId ?? "", "consensus");
    } catch (err) {
      console.warn("[consensus] finalize failed:", err);
    }
  }, [userId]);

  const categoryNames = Object.keys(grouped);
  const hasItems = categoryNames.length > 0;

  // ── Loading ──
  if (loading) {
    return (
      <div className="relative flex min-h-svh flex-col">
        {/* Shimmer hero area */}
        <motion.div
          style={{ width: "100%", height: "340px", background: "linear-gradient(180deg, rgba(0,0,0,0.03) 0%, rgba(0,0,0,0.08) 100%)" }}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.4 }}
        />
        <div className="px-6" style={{ marginTop: "24px" }}>
          <div style={{ ...text.label, color: ink.tertiary, marginBottom: "12px" }}>loading</div>
          <div className="flex gap-3">
            <ShimmerCard delay={0.1} />
            <ShimmerCard delay={0.2} />
            <ShimmerCard delay={0.3} />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div ref={scrollRef} className="relative flex min-h-svh flex-col">

      {/* ── HERO BANNER — destination photo from Unsplash ── */}
      {heroUrl && (
        <HeroBanner heroUrl={heroUrl} spaceTitle={spaceTitle} />
      )}

      {/* ── Category Rails ── */}
      <div
        style={{
          paddingTop: heroUrl ? "340px" : "140px",
          paddingBottom: "160px",
          display: "flex",
          flexDirection: "column",
          gap: "32px",
          position: "relative",
          zIndex: 10,
        }}
      >
        {/* Scanner: proves @xark is actively hunting */}
        <AnimatePresence>
          {isThinking && (
            <motion.div
              initial={{ opacity: 0, height: 0, scale: 0.95 }}
              animate={{ opacity: 1, height: "auto", scale: 1 }}
              exit={{ opacity: 0, height: 0, scale: 0.95 }}
              className="px-6 flex items-center gap-3"
              style={{ overflow: "hidden", marginBottom: "8px" }}
            >
              <div
                style={{
                  width: "8px", height: "8px", borderRadius: "50%",
                  backgroundColor: colors.accent,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                  boxShadow: `0 0 12px ${colors.accent}`,
                }}
              />
              <span style={{ ...text.label, color: colors.accent }}>
                scanning options...
              </span>
            </motion.div>
          )}
        </AnimatePresence>
        {hasItems ? (
          categoryNames.map((category, idx) => (
            <CategoryRail
              key={category}
              category={category}
              items={grouped[category]}
              activeReactions={isPlayground ? (playgroundReactions ?? {}) : activeReactions}
              onReact={isPlayground ? (onPlaygroundReact ?? handleReaction) : handleReaction}
              onFinalize={isPlayground ? undefined : handleFinalize}
              railIndex={idx}
            />
          ))
        ) : (
          <div className="px-6" style={{ paddingTop: "60px" }}>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5, duration: 0.8 }}
            >
              <span style={{ ...text.label, color: colors.accent, opacity: 0.4 }}>@xark</span>
              <p className="mt-1" style={{ ...text.hint, color: ink.tertiary }}>
                {`try "@xark find hotels near the beach" or "@xark add dates aug 15–25"`}
              </p>
            </motion.div>
          </div>
        )}
      </div>

      {/* Multiplayer ghost whisper — "someone loved hotel del" */}
      <AnimatePresence>
        {liveWhisper && (
          <motion.div
            initial={{ opacity: 0, y: 20, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10, scale: 0.9 }}
            className="fixed bottom-32 left-0 right-0 flex justify-center pointer-events-none z-50"
          >
            <span style={{
              ...text.hint,
              color: colors.gold,
              background: "rgba(0,0,0,0.85)",
              padding: "8px 20px",
              borderRadius: "20px",
              boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
            }}>
              {liveWhisper}
            </span>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
