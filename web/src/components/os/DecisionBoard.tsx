"use client";

import React, { useState, useEffect, useCallback, useMemo, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { heartSort } from "@/lib/heart-sort";
import { getConsensusState } from "@/lib/heart-sort";
import { useReactions } from "@/hooks/useReactions";
import type { ReactionType } from "@/hooks/useReactions";
import { supabase } from "@/lib/supabase";
import { DecisionCard } from "@/components/os/DecisionCard";
import { AddItemModal } from "@/components/os/AddItemModal";
import { useE2EE } from "@/hooks/useE2EE";
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
    type?: string;
    assignee_id?: string | null;
    options?: string[];
    image_url?: string;
    encrypted_image?: string;  // JSON-stringified E2EE image payload
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
  metadata?: any;
}

interface DecisionBoardProps {
  groupId: string;
  filterCategory?: string;
  userId?: string;
  authLoading?: boolean;
  isThinking?: boolean;
  playgroundItems?: DecisionItem[];
  playgroundReactions?: Record<string, import("@/hooks/useReactions").ReactionType>;
  onPlaygroundReact?: (itemId: string, signal: import("@/hooks/useReactions").ReactionType) => void;
}

// Card surfaces — dark, theme-independent
const CARD_GOLD = "#FFCF40";
const CARD_CYAN = "#FF6B35";
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
  "space_tokyo-neon-nights": [
    {
      id: "demo_t1", title: "Park Hyatt Tokyo", category: "hotel",
      weighted_score: 18, agreement_score: 0.94, is_locked: false, state: "ranked",
      metadata: { image_url: "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&h=500&fit=crop", price: "$650/nt", source: "booking.com", search_label: "hotels" },
      created_at: new Date(Date.now() - 45*60000).toISOString()
    },
    {
      id: "demo_t2", title: "Andaz Tokyo", category: "hotel",
      weighted_score: 8, agreement_score: 0.60, is_locked: false, state: "ranked",
      metadata: { image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=500&fit=crop", price: "$420/nt", source: "hyatt.com", search_label: "hotels" },
      created_at: new Date(Date.now() - 44*60000).toISOString()
    },
    {
      id: "demo_t3", title: "Hoshinoya Tokyo", category: "hotel",
      weighted_score: 3, agreement_score: 0.30, is_locked: false, state: "ranked",
      metadata: { image_url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=400&h=500&fit=crop", price: "$380/nt", source: "hoshinoya.com", search_label: "hotels" },
      created_at: new Date(Date.now() - 43*60000).toISOString()
    },
    { id: "demo_t4", title: "Aman Tokyo", category: "hotel", weighted_score: 15, agreement_score: 0.85, is_locked: false, state: "ranked", metadata: { price: "$900/nt", source: "aman.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t5", title: "Mandarin Oriental", category: "hotel", weighted_score: 12, agreement_score: 0.70, is_locked: false, state: "ranked", metadata: { price: "$700/nt", source: "booking.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t6", title: "Ritz-Carlton", category: "hotel", weighted_score: 14, agreement_score: 0.75, is_locked: false, state: "ranked", metadata: { price: "$850/nt", source: "marriott.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t7", title: "Shangri-La", category: "hotel", weighted_score: 10, agreement_score: 0.65, is_locked: false, state: "ranked", metadata: { price: "$550/nt", source: "shangri-la.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t8", title: "Palace Hotel", category: "hotel", weighted_score: 16, agreement_score: 0.88, is_locked: false, state: "ranked", metadata: { price: "$600/nt", source: "palacehoteltokyo.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t9", title: "The Peninsula", category: "hotel", weighted_score: 13, agreement_score: 0.72, is_locked: false, state: "ranked", metadata: { price: "$750/nt", source: "peninsula.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t10", title: "Conrad Tokyo", category: "hotel", weighted_score: 9, agreement_score: 0.55, is_locked: false, state: "ranked", metadata: { price: "$450/nt", source: "hilton.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t11", title: "Four Seasons", category: "hotel", weighted_score: 17, agreement_score: 0.90, is_locked: false, state: "ranked", metadata: { price: "$800/nt", source: "fourseasons.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t12", title: "K5 Tokyo", category: "hotel", weighted_score: 7, agreement_score: 0.40, is_locked: false, state: "ranked", metadata: { price: "$300/nt", source: "booking.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t13", title: "Trunk Hotel", category: "hotel", weighted_score: 11, agreement_score: 0.68, is_locked: false, state: "ranked", metadata: { price: "$350/nt", source: "trunk-hotel.com", search_label: "hotels" }, created_at: new Date().toISOString() },
    { id: "demo_t14", title: "Get balloons and party hats", category: "task", weighted_score: 99, agreement_score: 0, is_locked: false, state: "proposed", metadata: { type: "task" }, created_at: new Date().toISOString() },
    { id: "demo_t15", title: "Book the Uber to Narita", category: "task", weighted_score: 98, agreement_score: 0, is_locked: false, state: "proposed", metadata: { type: "task", price: "≈ $80" }, created_at: new Date().toISOString() },
    { id: "demo_t16", title: "Pick up pocket wifi at airport", category: "task", weighted_score: 97, agreement_score: 0, is_locked: false, state: "proposed", metadata: { type: "task", assignee_id: "pg_leo" }, created_at: new Date().toISOString() },
    { id: "demo_t17", title: "Which weekend works best for Kyoto?", category: "poll", weighted_score: 96, agreement_score: 0, is_locked: false, state: "proposed", metadata: { type: "poll", options: ["Aug 12 - 15", "Aug 19 - 22", "Sept 2 - 5"] }, created_at: new Date().toISOString() }
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

// HeroBanner removed in v4 redesign — full-focus card replaces it

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
// BOUNTY CARD & POLL CARD (Sub-components)
// ══════════════════════════════════════════════

function BountyCard({ item, isClaimed, onClaim }: { item: DecisionCardItem, isClaimed: boolean, onClaim: () => void }) {
  return (
    <motion.div 
      className="flex-shrink-0 flex flex-col justify-between p-5 shadow-xl relative overflow-hidden"
      style={{
        width: "200px", 
        height: "220px", 
        borderRadius: "22px",
        background: isClaimed ? "rgba(255,255,255,0.03)" : "linear-gradient(145deg, #1C1C1E 0%, #000 100%)",
        border: `1px solid ${isClaimed ? "rgba(255,255,255,0.04)" : "rgba(255, 107, 53, 0.4)"}`, 
        scrollSnapAlign: "center",
        cursor: "pointer"
      }}
      whileTap={{ scale: 0.95 }}
      onClick={onClaim}
    >
       {/* Ambient glow for unclaimed bounties */}
       {!isClaimed && (
         <div style={{ position: "absolute", top: -20, right: -20, width: 80, height: 80, background: "radial-gradient(circle, rgba(255,107,53,0.3) 0%, transparent 70%)", filter: "blur(10px)" }} />
       )}

       <div className="relative z-10">
         <span style={{ fontSize: "11px", color: isClaimed ? ink.tertiary : colors.accent, letterSpacing: "0.12em", textTransform: "uppercase", fontWeight: 600 }}>
           {isClaimed ? "Owned" : "Bounty"}
         </span>
         <h3 style={{ fontSize: "17px", color: colors.white, fontWeight: 300, marginTop: "12px", lineHeight: 1.3 }}>
           {item.title}
         </h3>
       </div>
       
       <div className="flex items-center justify-between relative z-10">
         <span style={{ fontSize: "13px", color: ink.tertiary }}>
           {item.price || "Task"}
         </span>
         
         {/* Avatar Slot / Stamp */}
         <motion.div 
           animate={isClaimed ? { scale: [1.2, 1], rotate: [-10, 0] } : {}}
           style={{ 
             width: "40px", height: "40px", borderRadius: "50%", 
             border: `1px dashed ${isClaimed ? "transparent" : "rgba(255,255,255,0.25)"}`,
             display: "flex", alignItems: "center", justifyContent: "center",
             background: isClaimed ? colors.accent : "rgba(255,255,255,0.02)",
             color: colors.white, fontSize: "16px", fontWeight: 500,
             boxShadow: isClaimed ? "0 4px 12px rgba(255,107,53,0.4)" : "none",
             transition: "background 0.3s, border 0.3s"
           }}
         >
           {isClaimed ? "R" : "+"}
         </motion.div>
       </div>
    </motion.div>
  );
}

export function BountyRow({ item, isClaimed, onClaim }: { item: DecisionCardItem, isClaimed: boolean, onClaim: () => void }) {
  return (
    <motion.div 
      className="flex items-center justify-between p-4 mb-3 relative overflow-hidden"
      style={{
        borderRadius: "16px",
        background: isClaimed ? "rgba(255,255,255,0.03)" : "linear-gradient(145deg, #1C1C1E 0%, #000 100%)",
        border: `1px solid ${isClaimed ? "rgba(255,255,255,0.04)" : "rgba(255, 107, 53, 0.4)"}`, 
        cursor: "pointer"
      }}
      whileTap={{ scale: 0.98 }}
      onClick={onClaim}
    >
       {!isClaimed && (
         <div style={{ position: "absolute", top: -20, right: -20, width: 80, height: 80, background: "radial-gradient(circle, rgba(255,107,53,0.3) 0%, transparent 70%)", filter: "blur(10px)" }} />
       )}

       <div className="flex-1 min-w-0 pr-4 relative z-10">
         <h3 style={{ fontSize: "16px", color: colors.white, fontWeight: 400, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", letterSpacing: "-0.01em" }}>
           {item.title}
         </h3>
         {item.price && (
           <p style={{ fontSize: "13px", color: ink.tertiary, marginTop: "4px" }}>{item.price}</p>
         )}
       </div>
       
       <motion.div 
         animate={isClaimed ? { scale: [1.2, 1], rotate: [-10, 0] } : {}}
         className="flex-shrink-0 relative z-10"
         style={{ 
           width: "32px", height: "32px", borderRadius: "50%", 
           border: `1px dashed ${isClaimed ? "transparent" : "rgba(255,255,255,0.25)"}`,
           display: "flex", alignItems: "center", justifyContent: "center",
           background: isClaimed ? colors.accent : "rgba(255,255,255,0.02)",
           color: colors.white, fontSize: "14px", fontWeight: 500,
           boxShadow: isClaimed ? "0 4px 12px rgba(255,107,53,0.4)" : "none",
           transition: "background 0.3s, border 0.3s"
         }}
       >
         {isClaimed ? "R" : "+"}
       </motion.div>
    </motion.div>
  );
}

function PollCard({ item, activeReaction, onReact, fullWidth }: { item: DecisionCardItem, activeReaction?: ReactionType, onReact: (id: string, signal: ReactionType) => void, fullWidth?: boolean }) {
  const options = item.metadata?.options || ["Yes", "No"];
  return (
    <motion.div
      className="flex-shrink-0 flex flex-col p-6 shadow-2xl relative overflow-hidden"
      style={{
        width: fullWidth ? "100%" : "280px",
        height: "clamp(340px, 50dvh, 420px)",
        borderRadius: "26px",
        background: "linear-gradient(180deg, #1A1A1D 0%, #000 100%)",
        border: "1px solid rgba(255,255,255,0.08)",
        scrollSnapAlign: "center"
      }}
    >
       <div style={{ position: "absolute", top: 16, right: 16, background: "rgba(64, 224, 255, 0.15)", color: "#FF6B35", padding: "6px 10px", borderRadius: "12px", fontSize: "10px", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase" }}>Active Poll</div>
       
       <div className="flex-1 flex flex-col justify-center">
         <h3 style={{ fontSize: "22px", color: colors.white, fontWeight: 300, marginBottom: "24px", lineHeight: 1.35, letterSpacing: "-0.01em" }}>
           {item.title}
         </h3>
         
         <div className="flex flex-col gap-3">
           {options.map((opt: string, i: number) => {
             // Fake a selected state using reaction mapping for prototyping
             const reactionKey = i === 0 ? "love_it" : i === 1 ? "works_for_me" : "not_for_me";
             const isSelected = activeReaction === reactionKey;
             return (
               <motion.div 
                 key={opt}
                 onClick={() => onReact(item.id, reactionKey as ReactionType)}
                 style={{
                   padding: "16px 20px", borderRadius: "16px",
                   background: isSelected ? "rgba(64, 224, 255, 0.12)" : "rgba(255,255,255,0.04)",
                   border: `1px solid ${isSelected ? "#FF6B35" : "rgba(255,255,255,0.02)"}`,
                   cursor: "pointer",
                   display: "flex", justifyContent: "space-between", alignItems: "center"
                 }}
                 whileTap={{ scale: 0.97 }}
               >
                 <span style={{ fontSize: "16px", color: isSelected ? "#FF6B35" : colors.white, fontWeight: isSelected ? 400 : 300 }}>{opt}</span>
                 {isSelected && <span style={{ color: "#FF6B35" }}>✓</span>}
               </motion.div>
             )
           })}
         </div>
       </div>
    </motion.div>
  );
}

// ══════════════════════════════════════════════
// SMART RAIL (Layout Router)
// ══════════════════════════════════════════════

export const SmartRail = React.memo(function SmartRail({
  category,
  items,
  activeReactions,
  onReact,
  onFinalize,
  railIndex,
  onViewAll,
}: {
  category: string;
  items: DecisionCardItem[];
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
  onFinalize?: (itemId: string) => void;
  railIndex: number;
  onViewAll?: (category: string) => void;
}) {
  const isUpForGrabs = category === "Up for Grabs" || category === "up for grabs";
  const isVault = category === "The Vault: Claimed Tasks" || category === "the vault: claimed";
  const isActivePolls = category === "Active Polls" || category === "active polls";

  const [isExpanded, setIsExpanded] = useState(!isVault);
  const railDelay = 0.2 + railIndex * 0.25;

  if (isUpForGrabs || isVault) {
    return (
      <motion.div
        className="mb-10 px-6"
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.15 }}
        transition={{ delay: railDelay, duration: 0.7, ease: [0.22, 1, 0.36, 1] as const }}
      >
        <div 
          className="flex items-center justify-between mb-4 cursor-pointer"
          onClick={() => isVault && setIsExpanded(!isExpanded)}
        >
          <div className="flex items-center gap-2">
            <h2 style={{ ...text.listTitle, color: colors.white }}>{category.toLowerCase()}</h2>
            {isVault && <span style={{ ...text.recency, color: ink.tertiary }}>({items.length})</span>}
            {!isVault && <span style={{ ...text.label, color: colors.gold, background: "rgba(255,190,40,0.1)", padding: "2px 8px", borderRadius: "12px" }}>needs votes</span>}
          </div>
          {isVault && (
            <span style={{ fontSize: "14px", color: ink.tertiary }}>{isExpanded ? "Hide" : "Show"}</span>
          )}
        </div>

        <AnimatePresence>
          {isExpanded && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              style={{ overflow: "hidden" }}
            >
              <div className="flex flex-col">
                {items.map(item => (
                  <BountyRow 
                    key={item.id} 
                    item={item} 
                    isClaimed={isVault} 
                    onClaim={() => onReact(item.id, "love_it")} 
                  />
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    );
  }

  if (isActivePolls) {
    return (
      <motion.div
        className="mb-10 px-6"
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.15 }}
        transition={{ delay: railDelay, duration: 0.7, ease: [0.22, 1, 0.36, 1] as const }}
      >
        <h2 style={{ ...text.listTitle, color: colors.white, marginBottom: "16px" }}>{category.toLowerCase()}</h2>
        <div className="flex flex-col gap-6">
          {items.map(item => (
            <PollCard 
              key={item.id} 
              item={item} 
              activeReaction={activeReactions[item.id]} 
              onReact={onReact}
              fullWidth={true}
            />
          ))}
        </div>
      </motion.div>
    );
  }

  return (
    <CategoryRail
      category={category}
      items={items}
      activeReactions={activeReactions}
      onReact={onReact}
      onFinalize={onFinalize}
      railIndex={railIndex}
      onViewAll={onViewAll}
    />
  );
});

// ══════════════════════════════════════════════
// CATEGORY RAIL (Classic Cinematic)
// ══════════════════════════════════════════════

const CategoryRail = React.memo(function CategoryRail({
  category,
  items,
  activeReactions,
  onReact,
  onFinalize,
  railIndex,
  onViewAll,
}: {
  category: string;
  items: DecisionCardItem[];
  activeReactions: Record<string, ReactionType>;
  onReact: (itemId: string, signal: ReactionType) => void;
  onFinalize?: (itemId: string) => void;
  railIndex: number;
  onViewAll?: (category: string) => void;
}) {
  const allLocked = items.length > 0 && items.every((i) => i.isLocked);
  const displayName = pluralizeCategory(category);
  const vital = categoryVital(items);
  const railDelay = 0.2 + railIndex * 0.25;
  const displayItems = items.slice(0, 10);
  const hasMore = items.length > 10;

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
        onTouchStart={(e) => e.stopPropagation()}
        onTouchMove={(e) => e.stopPropagation()}
        onTouchEnd={(e) => e.stopPropagation()}
        style={{
          gap: "12px",
          paddingLeft: "20px",
          paddingRight: "20px",
          paddingBottom: "12px",
          WebkitOverflowScrolling: "touch",
          scrollbarWidth: "none",
        }}
      >
        {displayItems.map((item, idx) => (
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

        {hasMore && (
          <motion.div
            className="flex-shrink-0 flex flex-col items-center justify-center shadow-2xl"
            style={{ 
              width: "160px", 
              height: "clamp(340px, 50dvh, 420px)",
              borderRadius: "26px", 
              border: "1px solid rgba(255,255,255,0.08)",
              background: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)",
              cursor: "pointer", 
              scrollSnapAlign: "center"
            }}
            onClick={() => onViewAll?.(category)}
            whileTap={{ scale: 0.95 }}
          >
            <span style={{ fontSize: "24px", color: colors.white, fontWeight: 300 }}>+{items.length - 10}</span>
            <span style={{ fontSize: "14px", color: ink.tertiary, marginTop: "8px" }}>View All</span>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}, (prev, next) =>
  prev.category === next.category &&
  prev.items === next.items &&
  prev.activeReactions === next.activeReactions &&
  prev.onFinalize === next.onFinalize &&
  prev.railIndex === next.railIndex &&
  prev.onViewAll === next.onViewAll
);

// ══════════════════════════════════════════════
// POSSIBILITY HORIZON — ORCHESTRATOR
// ══════════════════════════════════════════════

export default function DecisionBoard({ groupId, filterCategory, userId, authLoading, isThinking, playgroundItems, playgroundReactions, onPlaygroundReact }: DecisionBoardProps) {
  const isPlayground = !!playgroundItems;
  const [items, setItems] = useState<DecisionItem[]>([]);
  const [loading, setLoading] = useState(!isPlayground);
  const [activeReactions, setActiveReactions] = useState<Record<string, ReactionType>>({});
  const [incomingQueue, setIncomingQueue] = useState<DecisionItem[]>([]);
  const [liveWhisper, setLiveWhisper] = useState<string | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  const { react, unreact, batchGetUserReactions, isReacting } = useReactions();
  const e2ee = useE2EE(userId ?? null);

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
        .eq("group_id", groupId)
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
        // Fallback checks for various missing combinations
        let fallbackMatch = DEMO_ITEMS[groupId];
        if (!fallbackMatch) {
          if (groupId.includes("tokyo")) fallbackMatch = DEMO_ITEMS["space_tokyo-neon-nights"];
          else if (groupId.includes("san-diego")) fallbackMatch = DEMO_ITEMS["space_san-diego-trip"];
        }
        setItems(fallbackMatch ?? []);
      }
      setLoading(false);
    }
    fetchItems();
  }, [groupId, userId, batchGetUserReactions, authLoading]);

  // ── Realtime ──
  useEffect(() => {
    const channel = supabase
      .channel(`horizon:${groupId}`)
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "decision_items", filter: `group_id=eq.${groupId}` },
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
        { event: "INSERT", schema: "public", table: "decision_items", filter: `group_id=eq.${groupId}` },
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
  }, [groupId]);

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
    const sortable = items.map((item) => {
      // E2EE encrypted image: parse the thumbnail for instant preview
      let imageUrl = item.metadata?.image_url ?? "";
      if (!imageUrl && item.metadata?.encrypted_image) {
        try {
          const enc = JSON.parse(item.metadata.encrypted_image as string);
          if (enc.inlineThumbnail) imageUrl = enc.inlineThumbnail;
        } catch { /* use empty */ }
      }
      return {
      id: item.id,
      title: item.title,
      imageUrl,
      weightedScore: item.weighted_score,
      agreementScore: item.agreement_score,
      isLocked: item.is_locked,
      createdAt: new Date(item.created_at).getTime(),
    }; });

    const sorted = heartSort(sortable);
    const metaMap = new Map(items.map((i) => [i.id, i]));
    const groups: Record<string, DecisionCardItem[]> = {};

    for (const item of sorted) {
      const full = metaMap.get(item.id);
      
      let groupKey = "general";

      // SMART GENRE ROUTING — group by CATEGORY, not search query
      if (full?.metadata?.type === "task") {
        const isClaimed = full?.metadata?.assignee_id || activeReactions[item.id] === "love_it";
        groupKey = isClaimed ? "claimed tasks" : "up for grabs";
      } else if (full?.metadata?.type === "poll") {
        groupKey = "polls";
      } else {
        // Map tool category names to human-readable labels
        const cat = full?.category || "general";
        const CATEGORY_LABELS: Record<string, string> = {
          local_restaurant: "restaurants",
          local_activity: "things to do",
          local_general: "recommendations",
          restaurant: "restaurants",
          activity: "things to do",
          hotel: "hotels",
          flight: "flights",
          general: "ideas",
          poll: "polls",
        };
        groupKey = CATEGORY_LABELS[cat] || cat;
      }

      if (!groups[groupKey]) groups[groupKey] = [];
      groups[groupKey].push({
        ...item,
        category: full?.category || "general",
        price: full?.metadata?.price ?? "",
        source: full?.metadata?.source ?? "",
        lockDeadline: full?.lock_deadline ?? null,
        metadata: full?.metadata,
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

  // ── v4 Decide: single-category focus + selected card state ──
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const [selectedIdx, setSelectedIdx] = useState(0);
  const miniStripRef = useRef<HTMLDivElement>(null);

  // Auto-set to "all" overview when items load
  useEffect(() => {
    if (hasItems && !activeCategory) {
      setActiveCategory("all");
    }
  }, [hasItems, categoryNames, activeCategory]);

  // Current category items
  const activeCatItems = activeCategory ? (grouped[activeCategory] || []) : [];
  const selectedItem = activeCatItems[selectedIdx] || null;

  const selectCard = useCallback((idx: number) => {
    setSelectedIdx(idx);
    // Scroll mini strip to center the active card
    setTimeout(() => {
      const strip = miniStripRef.current;
      if (!strip) return;
      const mc = strip.children[idx] as HTMLElement;
      if (mc) mc.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
    }, 50);
  }, []);

  const switchCategory = useCallback((cat: string) => {
    setActiveCategory(cat);
    setSelectedIdx(0);
  }, []);

  // Auto-advance after vote
  const handleReactionWithAdvance = useCallback(
    async (itemId: string, signal: ReactionType) => {
      await handleReaction(itemId, signal);
      // Auto-advance to next card after 500ms
      setTimeout(() => {
        if (selectedIdx < activeCatItems.length - 1) {
          selectCard(selectedIdx + 1);
        }
      }, 500);
    },
    [handleReaction, selectedIdx, activeCatItems.length, selectCard]
  );

  // Build category summary — powers the overview health strip
  const categorySummary = useMemo(() => {
    return categoryNames
      .slice()
      .sort((a, b) => a.localeCompare(b))
      .map((cat) => {
        const catItems = grouped[cat] || [];
        const votedCount = catItems.filter((i) => activeReactions[i.id]).length;
        const lockedCount = catItems.filter((i) => i.isLocked).length;
        const unvotedCount = catItems.length - votedCount;
        const topItem = catItems[0];
        const allDone = catItems.length > 0 && lockedCount === catItems.length;
        return {
          category: cat,
          itemCount: catItems.length,
          votedCount,
          lockedCount,
          unvotedCount,
          allDone,
          needsYou: unvotedCount > 0 && !allDone,
          progress: catItems.length > 0 ? votedCount / catItems.length : 0,
          topImageUrl: topItem?.imageUrl,
          topTitle: topItem?.title,
          agreementScore: topItem?.agreementScore ?? 0,
        };
      });
  }, [categoryNames, grouped, activeReactions]);

  // ── Loading ──
  if (loading) {
    return (
      <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
        <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <div className="flex gap-3">
            <ShimmerCard delay={0.1} />
            <ShimmerCard delay={0.2} />
            <ShimmerCard delay={0.3} />
          </div>
        </div>
      </div>
    );
  }

  const rxns = isPlayground ? (playgroundReactions ?? {}) : activeReactions;
  const onReactFn = isPlayground ? (onPlaygroundReact ?? handleReactionWithAdvance) : handleReactionWithAdvance;
  const vital = activeCategory ? categoryVital(activeCatItems) : null;

  return (
    <div ref={scrollRef} style={{ display: "flex", flexDirection: "column", height: "100%" }}>

      {/* ── Scanner: @hello scanning indicator ── */}
      <AnimatePresence>
        {isThinking && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="px-6 flex items-center gap-3"
            style={{ overflow: "hidden", paddingTop: "8px", paddingBottom: "4px" }}
          >
            <div style={{
              width: "8px", height: "8px", borderRadius: "50%",
              backgroundColor: colors.accent,
              animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
              boxShadow: `0 0 12px ${colors.accent}`,
            }} />
            <span style={{ ...text.label, color: colors.accent }}>scanning options...</span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Vital label ── */}
      {vital && (
        <div style={{ padding: "6px 20px 4px", fontSize: "11px", fontWeight: 300, color: vital.color, opacity: 0.7, letterSpacing: "0.06em" }}>
          {vital.label}
        </div>
      )}

      {/* ═══ ADD ITEM FAB ═══ */}
      {!isPlayground && (
        <button
          onClick={() => setShowAddModal(true)}
          className="hello-bg-led"
          style={{
            position: "absolute",
            top: "12px",
            right: "16px",
            width: "36px",
            height: "36px",
            borderRadius: "50%",
            border: "none",
            fontSize: "22px",
            fontWeight: 300,
            lineHeight: 1,
            cursor: "pointer",
            zIndex: 15,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0 2px 8px rgba(0,0,0,0.15)",
          }}
        >
          +
        </button>
      )}

      {/* ═══ OVERVIEW: Category Health Strip ═══ */}
      {activeCategory === "all" && hasItems ? (
        <div style={{ flex: 1, overflowY: "auto", padding: "8px 16px", minHeight: 0 }}>
          {/* Overall stats */}
          <div style={{ display: "flex", gap: "16px", marginBottom: "16px", padding: "0 4px" }}>
            <div>
              <div style={{ fontSize: "24px", fontWeight: 300, color: ink.primary, lineHeight: 1 }}>
                {items.length}
              </div>
              <div style={{ fontSize: "10px", fontWeight: 300, color: ink.tertiary, marginTop: "2px" }}>items</div>
            </div>
            <div>
              <div style={{ fontSize: "24px", fontWeight: 300, color: colors.green, lineHeight: 1 }}>
                {items.filter((i) => i.is_locked).length}
              </div>
              <div style={{ fontSize: "10px", fontWeight: 300, color: ink.tertiary, marginTop: "2px" }}>decided</div>
            </div>
            <div>
              <div style={{ fontSize: "24px", fontWeight: 300, color: colors.amber, lineHeight: 1 }}>
                {categorySummary.filter((c) => c.needsYou).length}
              </div>
              <div style={{ fontSize: "10px", fontWeight: 300, color: ink.tertiary, marginTop: "2px" }}>need you</div>
            </div>
          </div>

          {/* Category rows */}
          {categorySummary.map((cat) => (
            <button
              key={cat.category}
              onClick={() => switchCategory(cat.category)}
              style={{
                width: "100%",
                display: "flex",
                alignItems: "center",
                gap: "12px",
                padding: "12px 8px",
                background: "none",
                border: "none",
                borderBottom: "0.5px solid rgba(128,128,128,0.1)",
                cursor: "pointer",
                textAlign: "left",
              }}
            >
              {/* Category name + count */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontSize: "14px",
                  fontWeight: 400,
                  color: cat.needsYou ? ink.primary : cat.allDone ? colors.green : ink.secondary,
                  textTransform: "capitalize",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}>
                  {cat.category}
                </div>
                <div style={{ fontSize: "11px", fontWeight: 300, color: ink.tertiary, marginTop: "1px" }}>
                  {cat.allDone
                    ? "all decided"
                    : cat.lockedCount > 0
                    ? `${cat.lockedCount} decided, ${cat.unvotedCount} need votes`
                    : `${cat.itemCount} items, ${cat.unvotedCount} need votes`
                  }
                </div>
              </div>

              {/* Progress bar */}
              <div style={{ width: "60px", flexShrink: 0 }}>
                <div style={{
                  width: "100%",
                  height: "4px",
                  borderRadius: "2px",
                  background: "rgba(128,128,128,0.12)",
                  overflow: "hidden",
                }}>
                  <div style={{
                    width: `${Math.round(cat.progress * 100)}%`,
                    height: "100%",
                    borderRadius: "2px",
                    background: cat.allDone ? colors.green : cat.progress > 0.5 ? colors.amber : colors.accent,
                    transition: "width 0.3s ease",
                  }} />
                </div>
              </div>

              {/* Status badge */}
              <div style={{ width: "20px", flexShrink: 0, textAlign: "center" }}>
                {cat.allDone ? (
                  <span style={{ color: colors.green, fontSize: "14px" }}>✓</span>
                ) : cat.needsYou ? (
                  <span style={{ color: colors.amber, fontSize: "10px", fontWeight: 300 }}>●</span>
                ) : null}
              </div>
            </button>
          ))}
        </div>
      ) : hasItems && selectedItem ? (
      /* ═══ SELECTED CARD — explicit height ═══ */
        <div style={{ flex: 1, padding: "4px 12px 8px", minHeight: 0 }}>
          <AnimatePresence mode="wait">
            <motion.div
              key={selectedItem.id}
              initial={{ opacity: 0, scale: 0.97 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.97 }}
              transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
              style={{ height: "100%", position: "relative" }}
            >
              <DecisionCard
                id={selectedItem.id}
                title={selectedItem.title}
                imageUrl={selectedItem.imageUrl}
                category={selectedItem.category}
                price={selectedItem.price}
                source={selectedItem.source}
                weightedScore={selectedItem.weightedScore}
                agreementScore={selectedItem.agreementScore}
                isLocked={selectedItem.isLocked}
                metadata={selectedItem.metadata}
                activeReaction={rxns[selectedItem.id]}
                onReact={onReactFn}
                onFinalize={isPlayground ? undefined : handleFinalize}
                lockDeadline={selectedItem.lockDeadline}
                fullFocus
              />
            </motion.div>
          </AnimatePresence>
        </div>
      ) : (
        <div style={{ flex: 1, padding: "60px 24px" }}>
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5, duration: 0.8 }}>
            <span style={{ ...text.label, color: colors.accent, opacity: 0.4 }}>@hello</span>
            <p className="mt-1" style={{ ...text.hint, color: ink.tertiary }}>
              {`try "@hello find hotels near the beach" or "@hello add dates aug 15–25"`}
            </p>
          </motion.div>
        </div>
      )}

      {/* ═══ BOTTOM DOCK — fixed above ChatInput ═══ */}
      {hasItems && (
        <div style={{ flexShrink: 0, background: "var(--hello-void)" }}>
          {/* ── Mini Card Strip (hidden in overview mode) ── */}
          {activeCategory !== "all" && <div
            ref={miniStripRef}
            className="flex gap-[6px] overflow-x-auto"
            style={{
              padding: "6px 12px",
              scrollbarWidth: "none",
              WebkitOverflowScrolling: "touch",
              msOverflowStyle: "none",
            }}
          >
            {activeCatItems.map((item, i) => {
              const isActive = i === selectedIdx;
              const isVoted = !!rxns[item.id];
              return (
                <motion.div
                  key={item.id}
                  onClick={() => selectCard(i)}
                  whileTap={{ scale: 0.9 }}
                  style={{
                    flexShrink: 0,
                    width: "52px", height: "52px",
                    borderRadius: "10px",
                    overflow: "hidden",
                    cursor: "pointer",
                    position: "relative",
                    opacity: isActive ? 1 : isVoted ? 0.6 : 0.4,
                    border: isActive ? "2px solid var(--hello-accent)" : "2px solid transparent",
                    transform: isActive ? "scale(1.1)" : "scale(1)",
                    transition: "all 0.2s ease",
                    WebkitTapHighlightColor: "transparent",
                  }}
                >
                  {item.imageUrl ? (
                    <img src={item.imageUrl} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
                  ) : (
                    <div style={{ width: "100%", height: "100%", background: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)" }} />
                  )}
                  {isVoted && !isActive && (
                    <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.25)", borderRadius: "8px" }} />
                  )}
                </motion.div>
              );
            })}
          </div>}

          {/* ── Category Tags ── */}
          <div
            className="flex items-center overflow-x-auto"
            style={{
              padding: "6px 12px 8px",
              scrollbarWidth: "none",
              WebkitOverflowScrolling: "touch",
              msOverflowStyle: "none",
              maskImage: "linear-gradient(to right, black 0%, black calc(100% - 32px), transparent)",
              WebkitMaskImage: "linear-gradient(to right, black 0%, black calc(100% - 32px), transparent)",
            }}
          >
            {["all", ...categoryNames.slice().sort((a, b) => a.localeCompare(b))].map((cat, i) => {
              const isActive = cat === activeCategory;
              const count = cat === "all" ? items.length : (grouped[cat]?.length || 0);
              return (
                <React.Fragment key={cat}>
                  {i > 0 && (
                    <div style={{ flexShrink: 0, width: "3px", height: "3px", borderRadius: "50%", background: ink.tertiary, opacity: 0.15, alignSelf: "center" }} />
                  )}
                  <span
                    role="button"
                    tabIndex={0}
                    onClick={() => switchCategory(cat)}
                    onKeyDown={(e) => { if (e.key === "Enter") switchCategory(cat); }}
                    className="outline-none"
                    style={{
                      flexShrink: 0,
                      padding: "8px 14px",
                      fontSize: "14px",
                      fontWeight: 400,
                      letterSpacing: "0.01em",
                      color: isActive ? colors.accent : ink.tertiary,
                      cursor: "pointer",
                      WebkitTapHighlightColor: "transparent",
                      transition: "color 0.2s ease",
                      whiteSpace: "nowrap",
                      textTransform: "capitalize",
                    }}
                  >
                    {cat} <span style={{ fontSize: "11px", fontWeight: 300, opacity: isActive ? 0.7 : 0.5, marginLeft: "3px" }}>{count}</span>
                  </span>
                </React.Fragment>
              );
            })}
          </div>

          {/* ── Hairline divider — separates tags from ChatInput below ── */}
          <div style={{ height: "0.5px", background: "rgba(0,0,0,0.08)", margin: "4px 20px 0" }} />
        </div>
      )}

      {/* ── Multiplayer ghost whisper ── */}
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

      {/* ═══ ADD ITEM MODAL ═══ */}
      <AddItemModal
        open={showAddModal}
        onClose={() => setShowAddModal(false)}
        groupId={groupId}
        userId={userId}
        e2eeAvailable={e2ee.available}
        e2eeDeviceId={e2ee.deviceId}
        encrypt={e2ee.encrypt}
      />
    </div>
  );
}
