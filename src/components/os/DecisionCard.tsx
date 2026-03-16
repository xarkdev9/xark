"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { motion, animate } from "framer-motion";
import { getConsensusState } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import type { ReactionType } from "@/hooks/useReactions";

// ── Card surfaces are always dark — fixed light text ──
const CARD_TEXT = "#E8E8EC";
const CARD_TEXT_DIM = "rgba(232, 232, 236, 0.5)";

const CATEGORY_GRADIENTS: Record<string, string> = {
  hotel: "linear-gradient(160deg, #8a6a4a 0%, #3a2818 100%)",
  flight: "linear-gradient(180deg, #1a2940 0%, #060a10 100%)",
  dining: "linear-gradient(180deg, #2a1215 0%, #0a0405 100%)",
  restaurant: "linear-gradient(180deg, #2a1215 0%, #0a0405 100%)",
  activity: "linear-gradient(160deg, #1a3a2a 0%, #050f0a 100%)",
  experience: "linear-gradient(160deg, #1a3a2a 0%, #050f0a 100%)",
  general: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)",
};

const CARD_AMBER = "#e8a855";
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
  { type: "love_it", label: "love", color: "#FF6B35" },
  { type: "works_for_me", label: "okay", color: "#A8B4C0" },
  { type: "not_for_me", label: "pass", color: "#6B7280" },
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
  activeReaction,
  onReact,
  onClick,
  entranceDelay = 0,
  lazyImage = false,
  createdAt = 0,
}: DecisionCardProps) {
  const [imgError, setImgError] = useState(false);
  const consensusState = getConsensusState(agreementScore);
  const pct = Math.round(agreementScore * 100);
  const cColor = consensusColor(consensusState);
  const fallbackGradient =
    CATEGORY_GRADIENTS[category.toLowerCase()] ?? CATEGORY_GRADIENTS.general;

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

  return (
    <motion.div
      className="relative flex-shrink-0 overflow-hidden"
      style={{
        width: "82%",
        maxWidth: "340px",
        height: "clamp(320px, 50dvh, 440px)",
        borderRadius: "28px",
        scrollSnapAlign: "center",
        cursor: onClick || (isCommitted && (bookingUrl || bookingPhone)) ? "pointer" : "default",
        boxShadow: isFreshDrop
          ? "0 0 24px rgba(64, 224, 255, 0.3), 0 8px 24px rgba(0,0,0,0.15)"
          : consensusState === "ignited"
          ? "0 4px 20px rgba(255, 207, 64, 0.15), 0 8px 32px rgba(0,0,0,0.15)"
          : "0 4px 20px rgba(0,0,0,0.12)",
      }}
      initial={{ opacity: 0, scale: 0.96 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{
        opacity: { duration: 0.5, ease: [0.22, 1, 0.36, 1], delay: entranceDelay },
        scale: { duration: 0.5, ease: [0.22, 1, 0.36, 1], delay: entranceDelay },
      }}
      onClick={handleCardTap}
      whileTap={{ scale: 0.97 }}
    >
      {/* ── Full-bleed photo ── */}
      {imageUrl && !imgError ? (
        <img
          src={imageUrl}
          alt=""
          loading={lazyImage ? "lazy" : "eager"}
          decoding="async"
          onError={() => setImgError(true)}
          className="absolute inset-0"
          style={{ width: "100%", height: "100%", objectFit: "cover" }}
        />
      ) : (
        <div
          className="absolute inset-0"
          style={{ backgroundImage: fallbackGradient, backgroundSize: "cover", backgroundPosition: "center" }}
        />
      )}

      {/* ── Cinematic gradient — bottom-up, photo stays visible at top ── */}
      <div
        className="absolute inset-0"
        style={{
          background: "linear-gradient(to top, rgba(0,0,0,0.95) 0%, rgba(0,0,0,0.5) 40%, transparent 70%)",
        }}
      />

      {/* ── Content — anchored to bottom ── */}
      <div
        className="absolute inset-x-0 bottom-0"
        style={{ padding: "24px", paddingBottom: "56px" }}
      >
        {/* Score + details row */}
        <div style={{ display: "flex", alignItems: "flex-start", gap: "16px", marginBottom: "0px" }}>
          {/* Consensus score — large, prominent */}
          <div style={{ flexShrink: 0 }}>
            <span
              style={{
                fontSize: "56px",
                fontWeight: 300,
                lineHeight: 1,
                letterSpacing: "-0.04em",
                color: cColor,
                textShadow: consensusState === "ignited"
                  ? `0 0 40px ${cColor}, 0 0 12px ${cColor}`
                  : "0 1px 4px rgba(0,0,0,0.5)",
              }}
            >
              {pct > 0 ? <AnimatedNumber value={pct} /> : "—"}
            </span>
          </div>

          {/* Title + price */}
          <div style={{ paddingTop: "8px", flex: 1, minWidth: 0 }}>
            <p
              style={{
                fontSize: "20px",
                fontWeight: 300,
                color: CARD_TEXT,
                lineHeight: 1.3,
                textShadow: "0 1px 3px rgba(0,0,0,0.4)",
              }}
            >
              {title}
            </p>
            {price && (
              <span
                style={{
                  fontSize: "13px",
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
          </div>
        </div>
      </div>

      {/* ── Reactions — love / okay / pass — spaced across bottom ── */}
      <div
        className="absolute inset-x-0 bottom-0 flex items-center justify-between"
        style={{ height: "48px", padding: "0 24px" }}
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
              whileTap={{ scale: 0.8 }}
              animate={{ scale: isActive ? 1.1 : 1 }}
              transition={{ type: "spring", stiffness: 400, damping: 17 }}
              className="outline-none"
              style={{
                fontSize: "14px",
                fontWeight: 300,
                letterSpacing: "0.15em",
                color: isActive ? signal.color : CARD_TEXT,
                opacity: isActive ? 1 : 0.5,
                cursor: "pointer",
                padding: "8px 4px",
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
    </motion.div>
  );
}
