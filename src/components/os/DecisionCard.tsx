"use client";

import { useCallback } from "react";
import { motion } from "framer-motion";
import { getConsensusState } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import { timing } from "@/lib/theme";
import type { ReactionType } from "@/hooks/useReactions";

type CardSize = "hero" | "standard" | "mini";

// Sized so 2.5 standard cards visible on 375px mobile (with 24px padding + 12px gaps)
// (375 - 24 - 48) / 2.5 = ~121px per card + gap → 140px card shows 2.3 with peek
const DIMENSIONS: Record<
  CardSize,
  { w: number; h: number; pctSize: number; titleSize: string; showReactions: boolean }
> = {
  hero: { w: 180, h: 260, pctSize: 30, titleSize: "14px", showReactions: true },
  standard: { w: 140, h: 200, pctSize: 20, titleSize: "12px", showReactions: true },
  mini: { w: 100, h: 140, pctSize: 16, titleSize: "10px", showReactions: false },
};

// Card surfaces are always dark regardless of theme — use fixed light text
const CARD_TEXT = "#E8E8EC";
const CARD_TEXT_DIM = "rgba(232, 232, 236, 0.5)";
const CARD_TEXT_GHOST = "rgba(232, 232, 236, 0.25)";

const CATEGORY_GRADIENTS: Record<string, string> = {
  hotel: "linear-gradient(160deg, #8a6a4a 0%, #3a2818 100%)",
  flight: "linear-gradient(180deg, #1a2940 0%, #060a10 100%)",
  dining: "linear-gradient(180deg, #2a1215 0%, #0a0405 100%)",
  restaurant: "linear-gradient(180deg, #2a1215 0%, #0a0405 100%)",
  activity: "linear-gradient(160deg, #1a3a2a 0%, #050f0a 100%)",
  experience: "linear-gradient(160deg, #1a3a2a 0%, #050f0a 100%)",
  general: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)",
};

// Bright signal colors for dark card surfaces (theme-independent)
const CARD_AMBER = "#F5A623";
const CARD_GOLD = "#FFCF40";
const CARD_CYAN = "#40E0FF";
const CARD_GREEN = "#34D399";
const CARD_ORANGE = "#F0652A";
const CARD_GRAY = "#9CA3AF";

function consensusColor(state: ConsensusState): string {
  if (state === "ignited") return CARD_GOLD;
  if (state === "steady") return CARD_CYAN;
  return CARD_AMBER;
}

const SIGNALS: { type: ReactionType; label: string; color: string }[] = [
  { type: "love_it", label: "love", color: CARD_AMBER },
  { type: "works_for_me", label: "okay", color: CARD_GRAY },
  { type: "not_for_me", label: "pass", color: CARD_ORANGE },
];

interface DecisionCardProps {
  id: string;
  title: string;
  imageUrl?: string;
  category?: string;
  price?: string;
  source?: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  size?: CardSize;
  activeReaction?: ReactionType;
  onReact?: (itemId: string, signal: ReactionType) => void;
  onClick?: () => void;
  entranceDelay?: number;
}

export function DecisionCard({
  id,
  title,
  imageUrl,
  category = "general",
  price,
  source,
  agreementScore,
  size = "standard",
  activeReaction,
  onReact,
  onClick,
  entranceDelay = 0,
}: DecisionCardProps) {
  const dim = DIMENSIONS[size];
  const consensusState = getConsensusState(agreementScore);
  const pct = Math.round(agreementScore * 100);
  const cColor = consensusColor(consensusState);
  const fallbackGradient =
    CATEGORY_GRADIENTS[category.toLowerCase()] ?? CATEGORY_GRADIENTS.general;

  const handleReact = useCallback(
    (signal: ReactionType) => {
      if (onReact) onReact(id, signal);
    },
    [id, onReact]
  );

  return (
    <motion.div
      className="relative flex-shrink-0 overflow-hidden"
      style={{
        width: `${dim.w}px`,
        height: `${dim.h}px`,
        borderRadius: "16px",
        boxShadow:
          size === "hero"
            ? `0 0 40px rgba(255,207,64,0.06), 0 8px 32px rgba(0,0,0,0.25)`
            : "0 8px 28px rgba(0,0,0,0.2)",
        cursor: onClick ? "pointer" : "default",
      }}
      initial={{ opacity: 0, x: 80, scale: 0.88 }}
      whileInView={{ opacity: 1, x: 0, scale: 1 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{
        delay: entranceDelay,
        duration: 0.6,
        ease: [0.22, 1, 0.36, 1],
      }}
      onClick={onClick}
    >
      {/* Full card background — single combined gradient over photo/fallback */}
      <div
        className="absolute inset-0"
        style={{
          backgroundImage: imageUrl ? `url(${imageUrl})` : fallbackGradient,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />
      {/* Single scrim — lets image breathe at top, solid at bottom for text */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.08) 30%, rgba(10,10,16,0.6) 50%, rgba(10,10,16,0.92) 65%, #0a0a10 80%)",
        }}
      />

      {/* Data zone */}
      <div
        className="absolute inset-x-0 bottom-0 px-3"
        style={{ paddingBottom: dim.showReactions ? "44px" : "12px" }}
      >
        {/* Consensus % — the brightest thing */}
        <div style={{ marginBottom: "6px" }}>
          <span
            style={{
              fontSize: `${dim.pctSize}px`,
              fontWeight: 400,
              lineHeight: 1,
              letterSpacing: "-0.04em",
              color: cColor,
              textShadow:
                consensusState === "ignited"
                  ? `0 0 40px ${cColor}, 0 0 12px ${cColor}`
                  : "none",
              opacity: consensusState === "ignited" ? 1 : 0.75,
            }}
          >
            {pct > 0 ? pct : "—"}
          </span>
          {pct > 0 && (
            <span
              style={{
                fontSize: `${Math.round(dim.pctSize * 0.4)}px`,
                color: cColor,
                opacity: 0.4,
                verticalAlign: "super",
                marginLeft: "2px",
              }}
            >
              %
            </span>
          )}
          {/* Consensus bar */}
          <div
            style={{
              marginTop: "4px",
              height: "2px",
              background: "rgba(255,255,255,0.1)",
              borderRadius: "1px",
              overflow: "hidden",
            }}
          >
            <motion.div
              style={{
                height: "100%",
                backgroundColor: cColor,
                opacity: consensusState === "ignited" ? 0.7 : 0.3,
                borderRadius: "1px",
              }}
              initial={{ width: "0%" }}
              whileInView={{ width: `${pct}%` }}
              viewport={{ once: true }}
              transition={{ delay: entranceDelay + 0.3, duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
            />
          </div>
        </div>

        {/* Title */}
        <p
          style={{
            fontSize: dim.titleSize,
            fontWeight: 400,
            color: CARD_TEXT,
            lineHeight: 1.3,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: size === "mini" ? "nowrap" : ("normal" as const),
          }}
        >
          {title}
        </p>

        {/* Price + source */}
        {price && size !== "mini" && (
          <span
            style={{
              fontSize: size === "hero" ? "11px" : "10px",
              fontWeight: 300,
              color: CARD_TEXT_DIM,
              display: "inline-block",
              marginTop: "4px",
            }}
          >
            {price}
            {source ? ` · ${source}` : ""}
          </span>
        )}
        {price && size === "mini" && (
          <span
            style={{
              fontSize: "9px",
              fontWeight: 300,
              color: CARD_TEXT_GHOST,
              display: "inline-block",
              marginTop: "2px",
            }}
          >
            {price}
          </span>
        )}
      </div>

      {/* Reactions — hero + standard only */}
      {dim.showReactions && (
        <div
          className="absolute inset-x-0 bottom-0 flex items-center justify-around px-2"
          style={{ height: "40px" }}
        >
          {SIGNALS.map((signal) => {
            const isActive = activeReaction === signal.type;
            return (
              <span
                key={signal.type}
                role="button"
                tabIndex={0}
                onClick={(e) => {
                  e.stopPropagation();
                  handleReact(signal.type);
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.stopPropagation();
                    handleReact(signal.type);
                  }
                }}
                className="outline-none"
                style={{
                  fontSize: size === "hero" ? "13px" : "12px",
                  fontWeight: 400,
                  letterSpacing: "0.04em",
                  color: isActive ? signal.color : CARD_TEXT,
                  opacity: isActive ? 1 : activeReaction ? 0.15 : 0.55,
                  cursor: "pointer",
                  padding: "6px 4px",
                  textShadow: isActive
                    ? `0 0 16px ${signal.color}, 0 0 6px ${signal.color}`
                    : "none",
                  transition: `opacity ${timing.transition} ease, color ${timing.transition} ease, text-shadow ${timing.transition} ease`,
                }}
              >
                {signal.label}
              </span>
            );
          })}
        </div>
      )}
    </motion.div>
  );
}
