"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { heartSort } from "@/lib/heart-sort";
import { useReactions } from "@/hooks/useReactions";
import type { ReactionType } from "@/hooks/useReactions";
import { supabase } from "@/lib/supabase";
import { DecisionCard } from "@/components/os/DecisionCard";
import {
  colors,
  text,
  textColor,
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
  category: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  createdAt: number;
}

interface PossibilityHorizonProps {
  spaceId: string;
  userId?: string;
  authLoading?: boolean;
}

// ── Demo items ──
const DEMO_ITEMS: Record<string, DecisionItem[]> = {
  "space_san-diego-trip": [
    { id: "demo_h1", title: "Hotel Del Coronado", category: "Hotel", weighted_score: 10, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { image_url: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=400&h=500&fit=crop", price: "$450/nt", source: "booking.com" }, created_at: new Date().toISOString() },
    { id: "demo_h2", title: "Coronado Island Marriott", category: "Hotel", weighted_score: 3, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=500&fit=crop", price: "$320/nt", source: "marriott.com" }, created_at: new Date().toISOString() },
    { id: "demo_a1", title: "Surf Lessons at La Jolla", category: "Activity", weighted_score: 6, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1502680390548-bdbac40e4a9f?w=400&h=500&fit=crop", price: "$95/person", source: "surfschool.com" }, created_at: new Date().toISOString() },
    { id: "demo_a2", title: "Balboa Park", category: "Activity", weighted_score: 4, agreement_score: 0.45, is_locked: false, state: "proposed", metadata: { image_url: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=400&h=500&fit=crop", price: "Free" }, created_at: new Date().toISOString() },
    { id: "demo_d1", title: "Gaslamp Quarter Dinner", category: "Dining", weighted_score: 8, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { image_url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&h=500&fit=crop", price: "$65/person" }, created_at: new Date().toISOString() },
  ],
};

const PLURAL_MAP: Record<string, string> = {
  hotel: "hotels", activity: "activities", flight: "flights",
  dining: "dining", experience: "experiences", restaurant: "restaurants", general: "general",
};

function pluralizeCategory(cat: string): string {
  return PLURAL_MAP[cat.toLowerCase()] ?? cat.toLowerCase() + "s";
}

function categoryVital(items: DecisionCardItem[]): { text: string; color: string } {
  const total = items.length;
  const rated = items.filter((i) => i.agreementScore > 0).length;
  const topItem = items[0];

  if (topItem && topItem.agreementScore >= 0.8) {
    const pct = Math.round(topItem.agreementScore * 100);
    return { text: `${pct}% on #1 · ${rated} of ${total}`, color: colors.gold };
  }
  if (rated === 0) return { text: "needs votes", color: colors.amber };
  return { text: `${rated} of ${total} rated`, color: colors.cyan };
}

// ══════════════════════════════════════════════
// SHIMMER
// ══════════════════════════════════════════════

function ShimmerCard({ delay = 0 }: { delay?: number }) {
  return (
    <motion.div
      className="flex-shrink-0"
      style={{
        width: "165px",
        height: "240px",
        borderRadius: "16px",
        background:
          "linear-gradient(90deg, rgba(255,255,255,0.02) 0%, rgba(255,255,255,0.06) 50%, rgba(255,255,255,0.02) 100%)",
        backgroundSize: "200px 100%",
        animation: "shimmer 1.5s ease-in-out infinite",
      }}
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay, duration: 0.4 }}
    />
  );
}

// ══════════════════════════════════════════════
// CATEGORY SECTION
// ══════════════════════════════════════════════

function CategorySection({
  category,
  items,
  activeReactions,
  onReact,
  categoryIndex,
}: {
  category: string;
  items: DecisionCardItem[];
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
  categoryIndex: number;
}) {
  const allLocked = items.length > 0 && items.every((i) => i.isLocked);
  const displayName = pluralizeCategory(category);
  const vital = categoryVital(items);
  const baseDelay = 0.15 + categoryIndex * 0.15;

  if (allLocked) {
    const lockedTitle = items[0]?.title ?? "";
    return (
      <motion.div
        className="flex items-center gap-3"
        style={{ padding: "6px 0" }}
        initial={{ opacity: 0, y: 16 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ delay: baseDelay, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        <div
          style={{
            width: "5px", height: "5px", borderRadius: "50%",
            backgroundColor: colors.green,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
            flexShrink: 0,
          }}
        />
        <span style={{ ...text.label, color: textColor(0.3) }}>{displayName}</span>
        <span style={{ ...text.recency, color: textColor(0.2) }}>
          {lockedTitle}{items.length > 1 ? ` + ${items.length - 1} more` : ""}
        </span>
      </motion.div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.1 }}
      transition={{ delay: baseDelay, duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
    >
      {/* Rail header */}
      <div className="flex items-baseline justify-between" style={{ marginBottom: "14px" }}>
        <span style={{ ...text.label, color: textColor(0.3) }}>{displayName}</span>
        <span style={{ ...text.recency, color: vital.color, opacity: 0.4 }}>{vital.text}</span>
      </div>

      {/* Horizontal card rail — NO snap for buttery smooth scroll */}
      <div
        className="horizon-scroll flex overflow-x-auto"
        style={{
          gap: "14px",
          paddingRight: "40px",
          paddingBottom: "4px",
          WebkitOverflowScrolling: "touch",
        }}
      >
        {items.slice(0, 8).map((item, idx) => (
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
            size={idx === 0 ? "hero" : "standard"}
            activeReaction={activeReactions[item.id]}
            onReact={onReact}
            entranceDelay={baseDelay + 0.1 + idx * 0.08}
          />
        ))}

        {items.length > 8 && (
          <motion.div
            className="flex flex-shrink-0 items-center justify-center"
            style={{ width: "50px", minHeight: "200px" }}
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: baseDelay + 0.8 }}
          >
            <span style={{ ...text.recency, color: textColor(0.15) }}>+{items.length - 8}</span>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}

// ══════════════════════════════════════════════
// POSSIBILITY HORIZON
// ══════════════════════════════════════════════

export function PossibilityHorizon({ spaceId, userId, authLoading }: PossibilityHorizonProps) {
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [heroUrl, setHeroUrl] = useState<string | null>(null);
  const [heroLoaded, setHeroLoaded] = useState(false);
  const [activeReactions, setActiveReactions] = useState<Record<string, ReactionType>>({});

  const { react, unreact, batchGetUserReactions, isReacting } = useReactions();

  // ── Fetch hero image ──
  useEffect(() => {
    supabase
      .from("spaces")
      .select("metadata")
      .eq("id", spaceId)
      .single()
      .then(({ data }) => {
        if (data?.metadata?.hero_url) setHeroUrl(data.metadata.hero_url);
      });
  }, [spaceId]);

  // ── Fetch decision items ──
  useEffect(() => {
    if (authLoading) return;
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

  // ── Sort + group ──
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
      const category = full?.category || "general";
      if (!groups[category]) groups[category] = [];
      groups[category].push({
        ...item,
        category,
        price: full?.metadata?.price ?? "",
        source: full?.metadata?.source ?? "",
      });
    }
    return groups;
  }, [items]);

  // ── Reactions ──
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

  const categoryNames = Object.keys(grouped);
  const hasItems = categoryNames.length > 0;

  // ── Loading ──
  if (loading) {
    return (
      <div className="relative flex min-h-svh flex-col">
        <div className="flex-1 px-6" style={{ paddingTop: "160px", paddingBottom: "160px" }}>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5 }}
          >
            <div style={{ ...text.label, color: textColor(0.15), marginBottom: "14px" }}>loading</div>
            <div className="flex gap-3.5">
              <ShimmerCard delay={0} />
              <ShimmerCard delay={0.1} />
              <ShimmerCard delay={0.2} />
            </div>
          </motion.div>
        </div>
      </div>
    );
  }

  return (
    <div className="relative flex min-h-svh flex-col">
      {/* ── Hero image with fade-in ── */}
      <AnimatePresence>
        {heroUrl && (
          <motion.div
            className="absolute inset-x-0 top-0"
            style={{ height: "50%", zIndex: 0 }}
            initial={{ opacity: 0 }}
            animate={{ opacity: heroLoaded ? 1 : 0 }}
            transition={{ duration: 1.2, ease: [0.22, 1, 0.36, 1] }}
          >
            <img
              src={heroUrl}
              alt=""
              className="h-full w-full object-cover"
              loading="eager"
              onLoad={() => setHeroLoaded(true)}
            />
            {/* Single progressive scrim — hero fades to void */}
            <div
              className="absolute inset-0"
              style={{
                background:
                  "linear-gradient(180deg, rgba(0,0,0,0.2) 0%, rgba(0,0,0,0.05) 25%, rgba(var(--xark-void-rgb),0.5) 55%, rgba(var(--xark-void-rgb),0.85) 72%, var(--xark-void) 88%)",
              }}
            />
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Category Rails ── */}
      <div
        className="flex-1 overflow-y-auto px-6"
        style={{
          paddingTop: heroUrl ? "300px" : "150px",
          paddingBottom: "160px",
          display: "flex",
          flexDirection: "column",
          gap: "36px",
          position: "relative",
          zIndex: 1,
        }}
      >
        {hasItems ? (
          categoryNames.map((category, idx) => (
            <CategorySection
              key={category}
              category={category}
              items={grouped[category]}
              activeReactions={activeReactions}
              onReact={handleReaction}
              categoryIndex={idx}
            />
          ))
        ) : (
          <>
            <div style={{ flex: 1 }} />
            <motion.div
              style={{ maxWidth: "640px", marginBottom: "16px" }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5, duration: 0.8 }}
            >
              <span style={{ ...text.label, color: colors.cyan, opacity: 0.4 }}>@xark</span>
              <p className="mt-1" style={{ ...text.hint, color: colors.white, opacity: 0.35 }}>
                {`try "@xark find hotels near the beach" or "@xark add dates aug 15–25"`}
              </p>
            </motion.div>
          </>
        )}
      </div>
    </div>
  );
}
