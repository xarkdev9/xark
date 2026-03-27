"use client";

// XARK OS v2.0 — Inline Card Preview
// Miniature decision card for rendering @xark results in the chat timeline.
// Read-only. Tappable to navigate to Decide tab.

import { motion } from "framer-motion";

const CARD_TEXT = "#E8E8EC";
const CARD_AMBER = "#e8a855";

interface InlineCardPreviewProps {
  title: string;
  imageUrl?: string;
  price?: string;
  score: number;
  onTap?: () => void;
}

export function InlineCardPreview({ title, imageUrl, price, score, onTap }: InlineCardPreviewProps) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
      onClick={onTap}
      style={{
        position: "relative",
        height: "100px",
        borderRadius: "16px",
        overflow: "hidden",
        cursor: onTap ? "pointer" : "default",
        marginBottom: "8px",
      }}
    >
      {/* Photo or gradient */}
      {imageUrl ? (
        <img
          src={imageUrl}
          alt=""
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }}
        />
      ) : (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)",
          }}
        />
      )}

      {/* Gradient overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "linear-gradient(to right, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.4) 60%, transparent 100%)",
        }}
      />

      {/* Content */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          padding: "0 16px",
          gap: "12px",
        }}
      >
        {/* Score */}
        <span
          style={{
            fontSize: "28px",
            fontWeight: 300,
            color: CARD_AMBER,
            lineHeight: 1,
            letterSpacing: "-0.02em",
            flexShrink: 0,
          }}
        >
          {score > 0 ? score : "—"}
        </span>

        {/* Title + price */}
        <div style={{ minWidth: 0 }}>
          <p
            style={{
              fontSize: "15px",
              fontWeight: 400,
              color: CARD_TEXT,
              lineHeight: 1.3,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {title}
          </p>
          {price && (
            <p
              style={{
                fontSize: "12px",
                fontWeight: 300,
                color: "rgba(232,232,236,0.5)",
                marginTop: "2px",
              }}
            >
              {price}
            </p>
          )}
        </div>
      </div>
    </motion.div>
  );
}
