"use client";

import { useState, useEffect, useCallback, useMemo, useRef } from "react";
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

// Card surfaces — dark, theme-independent
const CARD_GOLD = "#FFCF40";
const CARD_CYAN = "#40E0FF";
const CARD_AMBER = "#F5A623";

// ── Demo items ──
const DEMO_ITEMS: Record<string, DecisionItem[]> = {
  "space_san-diego-trip": [
    { id: "demo_h1", title: "Hotel Del Coronado", category: "Hotel", weighted_score: 10, agreement_score: 0.92, is_locked: true, state: "locked", metadata: { image_url: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=600&h=400&fit=crop", price: "$450/nt", source: "booking.com" }, created_at: new Date().toISOString() },
    { id: "demo_h2", title: "Coronado Island Marriott", category: "Hotel", weighted_score: 3, agreement_score: 0.45, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=500&fit=crop", price: "$320/nt", source: "marriott.com" }, created_at: new Date().toISOString() },
    { id: "demo_h3", title: "La Valencia Hotel", category: "Hotel", weighted_score: 2, agreement_score: 0.30, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=400&h=500&fit=crop", price: "$520/nt", source: "booking.com" }, created_at: new Date().toISOString() },
    { id: "demo_a1", title: "Surf Lessons at La Jolla", category: "Activity", weighted_score: 6, agreement_score: 0.67, is_locked: false, state: "ranked", metadata: { image_url: "https://images.unsplash.com/photo-1502680390548-bdbac40e4a9f?w=400&h=500&fit=crop", price: "$95/person", source: "surfschool.com" }, created_at: new Date().toISOString() },
    { id: "demo_a2", title: "Balboa Park", category: "Activity", weighted_score: 4, agreement_score: 0.45, is_locked: false, state: "proposed", metadata: { image_url: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=400&h=500&fit=crop", price: "Free" }, created_at: new Date().toISOString() },
    { id: "demo_a3", title: "Whale Watching", category: "Activity", weighted_score: 1, agreement_score: 0, is_locked: false, state: "proposed", metadata: { image_url: "https://images.unsplash.com/photo-1568430462989-44163eb1752f?w=400&h=500&fit=crop", price: "$55/person" }, created_at: new Date().toISOString() },
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

  return (
    <motion.div
      className="relative overflow-hidden"
      style={{ width: "100%", height: "340px" }}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
    >
      {/* Destination photo — full bleed, Ken Burns zoom via wrapper */}
      <motion.div
        className="absolute inset-0"
        initial={{ scale: 1.1 }}
        animate={{ scale: imgLoaded ? 1 : 1.1 }}
        transition={{ duration: 2.2, ease: [0.22, 1, 0.36, 1] as const }}
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

      {/* Progressive scrim — readable title at bottom, photo breathes at top */}
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

function CategoryRail({
  category,
  items,
  activeReactions,
  onReact,
  railIndex,
}: {
  category: string;
  items: DecisionCardItem[];
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
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
        <span style={{ ...text.label, color: textColor(0.3) }}>{displayName}</span>
        <span style={{ ...text.recency, color: textColor(0.2) }}>
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
      {/* Rail header */}
      <div className="flex items-baseline justify-between px-6" style={{ marginBottom: "12px" }}>
        <span style={{ ...text.label, color: textColor(0.3) }}>{displayName}</span>
        <span style={{ fontSize: "10px", fontWeight: 300, color: vital.color, opacity: 0.5 }}>{vital.label}</span>
      </div>

      {/* Horizontal scroll — sized so 2.5 cards are visible (peek effect) */}
      <div
        className="horizon-scroll flex overflow-x-auto"
        style={{
          gap: "12px",
          paddingLeft: "24px",
          paddingRight: "48px",
          paddingBottom: "6px",
          WebkitOverflowScrolling: "touch",
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
            size="standard"
            activeReaction={activeReactions[item.id]}
            onReact={onReact}
            entranceDelay={railDelay + 0.08 + idx * 0.06}
          />
        ))}

        {items.length > 10 && (
          <div className="flex flex-shrink-0 items-center justify-center" style={{ width: "40px", minHeight: "200px" }}>
            <span style={{ fontSize: "10px", fontWeight: 300, color: textColor(0.12) }}>+{items.length - 10}</span>
          </div>
        )}
      </div>
    </motion.div>
  );
}

// ══════════════════════════════════════════════
// POSSIBILITY HORIZON — ORCHESTRATOR
// ══════════════════════════════════════════════

export function PossibilityHorizon({ spaceId, userId, authLoading }: PossibilityHorizonProps) {
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [heroUrl, setHeroUrl] = useState<string | null>(null);
  const [spaceTitle, setSpaceTitle] = useState("");
  const [activeReactions, setActiveReactions] = useState<Record<string, ReactionType>>({});
  const scrollRef = useRef<HTMLDivElement>(null);

  const { react, unreact, batchGetUserReactions, isReacting } = useReactions();

  // ── Demo hero images — fallback when no Unsplash key configured ──
  const DEMO_HEROES: Record<string, string> = {
    "space_san-diego-trip": "https://images.unsplash.com/photo-1538097304804-2a1b932466a9?w=800&h=500&fit=crop",
    "space_tokyo-neon-nights": "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&h=500&fit=crop",
    "space_bali-retreat": "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&h=500&fit=crop",
    "space_summer-2026": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=500&fit=crop",
  };

  // ── Fetch space metadata (hero photo + title) ──
  useEffect(() => {
    const fallback = DEMO_HEROES[spaceId] ?? "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=500&fit=crop";
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
        {/* Shimmer hero area */}
        <motion.div
          style={{ width: "100%", height: "340px", background: "linear-gradient(180deg, rgba(0,0,0,0.03) 0%, rgba(0,0,0,0.08) 100%)" }}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.4 }}
        />
        <div className="px-6" style={{ marginTop: "24px" }}>
          <div style={{ ...text.label, color: textColor(0.12), marginBottom: "12px" }}>loading</div>
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
          paddingTop: heroUrl ? "16px" : "140px",
          paddingBottom: "160px",
          display: "flex",
          flexDirection: "column",
          gap: "32px",
        }}
      >
        {hasItems ? (
          categoryNames.map((category, idx) => (
            <CategoryRail
              key={category}
              category={category}
              items={grouped[category]}
              activeReactions={activeReactions}
              onReact={handleReaction}
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
              <span style={{ ...text.label, color: colors.cyan, opacity: 0.4 }}>@xark</span>
              <p className="mt-1" style={{ ...text.hint, color: colors.white, opacity: 0.35 }}>
                {`try "@xark find hotels near the beach" or "@xark add dates aug 15–25"`}
              </p>
            </motion.div>
          </div>
        )}
      </div>
    </div>
  );
}
