"use client";

import { useCallback } from "react";
import { motion } from "framer-motion";
import { getConsensusState } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import { colors, text, amberWash, timing } from "@/lib/theme";
import type { ReactionType } from "@/hooks/useReactions";

type CardSize = "hero" | "standard" | "mini";

const DIMENSIONS: Record<
  CardSize,
  { w: number; h: number; pctSize: number; titleSize: string; showReactions: boolean }
> = {
  hero: { w: 150, h: 220, pctSize: 28, titleSize: "12px", showReactions: true },
  standard: { w: 130, h: 195, pctSize: 20, titleSize: "11px", showReactions: true },
  mini: { w: 100, h: 130, pctSize: 16, titleSize: "9px", showReactions: false },
};

const CATEGORY_GRADIENTS: Record<string, string> = {
  hotel: "linear-gradient(160deg, #8a6a4a 0%, #5a4030 50%, #2a1a10 100%)",
  flight: "linear-gradient(180deg, #1a2940 0%, #0d1520 60%, #060a10 100%)",
  dining: "linear-gradient(180deg, #2a1215 0%, #1a0a0c 60%, #0a0405 100%)",
  restaurant: "linear-gradient(180deg, #2a1215 0%, #1a0a0c 60%, #0a0405 100%)",
  activity: "linear-gradient(160deg, #1a3a2a 0%, #0a2015 60%, #050f0a 100%)",
  experience: "linear-gradient(160deg, #1a3a2a 0%, #0a2015 60%, #050f0a 100%)",
  general: "linear-gradient(160deg, #2a2a3a 0%, #1a1a28 60%, #0a0a14 100%)",
};

function consensusColor(state: ConsensusState): string {
  if (state === "ignited") return colors.gold;
  if (state === "steady") return colors.cyan;
  return colors.amber;
}

const SIGNALS: { type: ReactionType; label: string; color: string }[] = [
  { type: "love_it", label: "love", color: colors.amber },
  { type: "works_for_me", label: "okay", color: colors.gray },
  { type: "not_for_me", label: "pass", color: colors.orange },
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
  weightedScore,
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
      className="relative flex-shrink-0 snap-start overflow-hidden"
      style={{
        width: `${dim.w}px`,
        height: `${dim.h}px`,
        borderRadius: "14px",
        boxShadow:
          size === "hero"
            ? "0 0 28px rgba(255,207,64,0.08), 0 4px 24px rgba(0,0,0,0.15)"
            : "0 4px 24px rgba(0,0,0,0.12)",
        cursor: onClick ? "pointer" : "default",
        willChange: "transform",
      }}
      initial={{ opacity: 0, x: 60, scale: 0.92 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      transition={{
        delay: entranceDelay,
        duration: 0.5,
        ease: [0.22, 1, 0.36, 1],
      }}
      whileHover={{ scale: 1.08, y: -6 }}
      onClick={onClick}
    >
      {/* Photo zone — top 42% */}
      <div
        className="absolute left-0 right-0 top-0"
        style={{
          height: "42%",
          backgroundImage: imageUrl ? `url(${imageUrl})` : fallbackGradient,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />

      {/* Gradient bridge */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(180deg, transparent 30%, rgba(10,10,16,0.85) 48%, #0a0a10 58%)",
        }}
      />

      {/* Amber wash */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background: `linear-gradient(to top, ${amberWash(weightedScore)} 0%, transparent 40%)`,
        }}
      />

      {/* Data zone */}
      <div
        className="absolute inset-x-0 bottom-0 px-2.5"
        style={{ paddingBottom: dim.showReactions ? "34px" : "8px" }}
      >
        {/* Consensus % */}
        <div style={{ marginBottom: "4px" }}>
          <span
            style={{
              fontSize: `${dim.pctSize}px`,
              fontWeight: 400,
              lineHeight: 1,
              letterSpacing: "-0.03em",
              color: cColor,
              textShadow:
                size === "hero" ? `0 0 30px ${cColor}40` : "none",
              opacity: consensusState === "ignited" ? 0.95 : 0.7,
            }}
          >
            {pct > 0 ? pct : "—"}
          </span>
          {pct > 0 && (
            <span
              style={{
                fontSize: `${Math.round(dim.pctSize * 0.4)}px`,
                color: cColor,
                opacity: 0.35,
                verticalAlign: "super",
                marginLeft: "1px",
              }}
            >
              %
            </span>
          )}
          <div style={{ marginTop: "3px", height: "2px", position: "relative" }}>
            <div
              style={{
                position: "absolute",
                left: 0,
                top: 0,
                height: "2px",
                width: `${pct}%`,
                backgroundColor: cColor,
                opacity: consensusState === "ignited" ? 0.6 : 0.3,
                borderRadius: "1px",
                transition: "width 0.8s cubic-bezier(0.22, 1, 0.36, 1)",
              }}
            />
          </div>
        </div>

        {/* Title */}
        <p
          style={{
            fontSize: dim.titleSize,
            fontWeight: 400,
            color: colors.white,
            opacity: 0.85,
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
              fontSize: "9px",
              fontWeight: 300,
              color: colors.white,
              opacity: 0.3,
              display: "inline-block",
              marginTop: "2px",
            }}
          >
            {price}
            {source ? ` · ${source}` : ""}
          </span>
        )}
        {price && size === "mini" && (
          <span
            style={{
              fontSize: "8px",
              fontWeight: 300,
              color: colors.white,
              opacity: 0.25,
              display: "inline-block",
              marginTop: "1px",
            }}
          >
            {price}
          </span>
        )}
      </div>

      {/* Reactions — hero + standard only */}
      {dim.showReactions && (
        <div
          className="absolute inset-x-0 bottom-0 flex items-center justify-between px-2.5"
          style={{ height: "30px" }}
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
                  ...text.subtitle,
                  fontSize: size === "hero" ? "11px" : "10px",
                  color: isActive ? signal.color : colors.white,
                  opacity: isActive ? 1 : activeReaction ? 0.12 : 0.4,
                  cursor: "pointer",
                  textShadow: isActive
                    ? `0 0 12px ${signal.color}, 0 0 4px ${signal.color}`
                    : "0 1px 3px rgba(0,0,0,0.4)",
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
