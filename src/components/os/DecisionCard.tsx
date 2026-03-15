"use client";

import { useCallback, useEffect, useRef } from "react";
import { motion, animate } from "framer-motion";
import { getConsensusState } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import { timing } from "@/lib/theme";
import type { ReactionType } from "@/hooks/useReactions";

type CardSize = "hero" | "standard" | "mini";

// Sized so 2.5 standard cards visible on 375px mobile
const DIMENSIONS: Record<
  CardSize,
  { w: number; h: number; pctSize: number; titleSize: string; showReactions: boolean }
> = {
  hero: { w: 180, h: 260, pctSize: 30, titleSize: "14px", showReactions: true },
  standard: { w: 140, h: 200, pctSize: 20, titleSize: "12px", showReactions: true },
  mini: { w: 100, h: 140, pctSize: 16, titleSize: "10px", showReactions: false },
};

// Card surfaces are always dark — fixed light text
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

const CARD_AMBER = "#F5A623";
const CARD_GOLD = "#FFCF40";
const CARD_CYAN = "#40E0FF";
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

// ── AnimatedNumber — rolling consensus counter ──
function AnimatedNumber({ value }: { value: number }) {
  const nodeRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const node = nodeRef.current;
    if (!node) return;
    const start = parseInt(node.textContent || "0", 10) || 0;
    if (start === value) return;
    const controls = animate(start, value, {
      duration: 0.8,
      ease: [0.22, 1, 0.36, 1],
      onUpdate(v) {
        node.textContent = Math.round(v).toString();
      },
    });
    return () => controls.stop();
  }, [value]);

  return <span ref={nodeRef}>{value}</span>;
}

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
  state?: string;
  metadata?: { url?: string; shared_url?: string; phone?: string; [key: string]: unknown };
  size?: CardSize;
  activeReaction?: ReactionType;
  onReact?: (itemId: string, signal: ReactionType) => void;
  onClick?: () => void;
  entranceDelay?: number;
  lazyImage?: boolean;
  createdAt?: number;
}

export function DecisionCard({
  id,
  title,
  imageUrl,
  category = "general",
  price,
  source,
  agreementScore,
  isLocked,
  state,
  metadata,
  size = "standard",
  activeReaction,
  onReact,
  onClick,
  entranceDelay = 0,
  lazyImage = false,
  createdAt = 0,
}: DecisionCardProps) {
  const dim = DIMENSIONS[size];
  const consensusState = getConsensusState(agreementScore);
  const pct = Math.round(agreementScore * 100);
  const cColor = consensusColor(consensusState);
  const fallbackGradient =
    CATEGORY_GRADIENTS[category.toLowerCase()] ?? CATEGORY_GRADIENTS.general;

  // Freshness check: was this item added in the last 15 seconds?
  const isFreshDrop = createdAt > 0 && (Date.now() - createdAt < 15000);

  const handleReact = useCallback(
    (signal: ReactionType) => {
      if (onReact) onReact(id, signal);
    },
    [id, onReact]
  );

  // Booking bridge
  const isCommitted = isLocked || state === "locked" || state === "claimed" || state === "purchased";
  const bookingUrl = metadata?.url || metadata?.shared_url;
  const bookingPhone = metadata?.phone;

  const handleCardTap = useCallback(() => {
    if (isCommitted && bookingUrl) {
      window.open(bookingUrl as string, "_blank", "noopener,noreferrer");
      return;
    }
    if (isCommitted && bookingPhone) {
      window.open(`tel:${bookingPhone}`);
      return;
    }
    onClick?.();
  }, [isCommitted, bookingUrl, bookingPhone, onClick]);

  // Box shadow: fresh glow (cyan), ignited (breathing gold), or default depth
  const boxShadowValue = isFreshDrop
    ? [
        "0 0 0px rgba(64, 224, 255, 0)",
        "0 0 20px rgba(64, 224, 255, 0.5)",
        "0 8px 28px rgba(0,0,0,0.2)",
      ]
    : consensusState === "ignited"
    ? [
        "0 8px 24px rgba(255, 207, 64, 0.15)",
        "0 12px 40px rgba(255, 207, 64, 0.4)",
        "0 8px 24px rgba(255, 207, 64, 0.15)",
      ]
    : ["0 8px 28px rgba(0,0,0,0.2)"];

  return (
    <motion.div
      layout
      className="relative flex-shrink-0 overflow-hidden"
      style={{
        width: `${dim.w}px`,
        height: `${dim.h}px`,
        borderRadius: "16px",
        scrollSnapAlign: "start",
        cursor: onClick || (isCommitted && (bookingUrl || bookingPhone)) ? "pointer" : "default",
      }}
      // Physics: rise from below with weight
      initial={{ opacity: 0, y: 30, scale: 0.9 }}
      whileInView={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.85 }}
      viewport={{ once: true, amount: 0.2 }}
      animate={{ boxShadow: boxShadowValue }}
      transition={{
        layout: { type: "spring", stiffness: 300, damping: 24 },
        opacity: { duration: 0.5, delay: entranceDelay },
        y: { type: "spring", stiffness: 400, damping: 20, delay: entranceDelay },
        scale: { type: "spring", stiffness: 400, damping: 20, delay: entranceDelay },
        boxShadow: isFreshDrop
          ? { duration: 3, ease: "easeOut" }
          : consensusState === "ignited"
          ? { duration: 3, repeat: Infinity, ease: "easeInOut" }
          : { duration: 0.3 },
      }}
      onClick={handleCardTap}
      whileHover={{ y: -4 }}
      whileTap={{ scale: 0.97 }}
    >
      {/* Photo */}
      {imageUrl ? (
        <img
          src={imageUrl}
          alt=""
          loading={lazyImage ? "lazy" : "eager"}
          decoding="async"
          className="absolute inset-0"
          style={{ width: "100%", height: "100%", objectFit: "cover" }}
        />
      ) : (
        <div
          className="absolute inset-0"
          style={{ backgroundImage: fallbackGradient, backgroundSize: "cover", backgroundPosition: "center" }}
        />
      )}

      {/* Single scrim */}
      <div
        className="absolute inset-0"
        style={{
          background: "linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.08) 30%, rgba(10,10,16,0.6) 50%, rgba(10,10,16,0.92) 65%, #0a0a10 80%)",
        }}
      />

      {/* Data zone */}
      <div
        className="absolute inset-x-0 bottom-0 px-3"
        style={{ paddingBottom: dim.showReactions ? "44px" : "12px" }}
      >
        {/* Consensus % — animated rolling number */}
        <div style={{ marginBottom: "6px" }}>
          <span
            style={{
              fontSize: `${dim.pctSize}px`,
              fontWeight: 400,
              lineHeight: 1,
              letterSpacing: "-0.04em",
              color: cColor,
              textShadow: consensusState === "ignited" ? `0 0 40px ${cColor}, 0 0 12px ${cColor}` : "none",
              opacity: consensusState === "ignited" ? 1 : 0.75,
            }}
          >
            {pct > 0 ? <AnimatedNumber value={pct} /> : "—"}
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

      {/* Reactions — haptic spring physics */}
      {dim.showReactions && (
        <div
          className="absolute inset-x-0 bottom-0 flex items-center justify-around px-2"
          style={{ height: "40px" }}
        >
          {SIGNALS.map((signal) => {
            const isActive = activeReaction === signal.type;
            return (
              <motion.span
                key={signal.type}
                role="button"
                tabIndex={0}
                onClick={(e) => {
                  e.stopPropagation();
                  // Haptic feedback: double heartbeat for love, single tap for others
                  if (typeof navigator !== "undefined" && navigator.vibrate) {
                    navigator.vibrate(signal.type === "love_it" ? [20, 30, 20] : 15);
                  }
                  handleReact(signal.type);
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.stopPropagation();
                    handleReact(signal.type);
                  }
                }}
                // Spring physics: squish on press, pop on active
                whileTap={{ scale: 0.8 }}
                animate={{ scale: isActive ? 1.15 : 1 }}
                transition={{ type: "spring", stiffness: 400, damping: 17 }}
                className="outline-none"
                style={{
                  fontSize: size === "hero" ? "13px" : "12px",
                  fontWeight: 400,
                  letterSpacing: "0.04em",
                  color: isActive ? signal.color : CARD_TEXT,
                  opacity: isActive ? 1 : activeReaction ? 0.15 : 0.55,
                  cursor: "pointer",
                  padding: "6px 8px",
                  textShadow: isActive
                    ? `0 0 16px ${signal.color}, 0 0 6px ${signal.color}`
                    : "none",
                }}
              >
                {signal.label}
              </motion.span>
            );
          })}
        </div>
      )}
    </motion.div>
  );
}
