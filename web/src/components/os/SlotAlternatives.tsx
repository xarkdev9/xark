"use client";

import { useState } from "react";

interface Alternative {
  title: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  rating?: number;
  source?: string;
}

interface SlotAlternativesProps {
  alternatives: Alternative[];
  onSelect?: (alt: Alternative) => void;
}

export function SlotAlternatives({ alternatives, onSelect }: SlotAlternativesProps) {
  const [expanded, setExpanded] = useState(false);

  if (alternatives.length === 0) return null;

  return (
    <div style={{ marginTop: 4, marginLeft: 24 }}>
      {/* Collapsed chip */}
      <button
        onClick={() => setExpanded(!expanded)}
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 4,
          padding: "3px 10px",
          borderRadius: 12,
          border: "1px solid var(--hello-ink-tertiary)",
          background: "transparent",
          color: "var(--hello-ink-tertiary)",
          fontSize: 11,
          fontWeight: 400,
          cursor: "pointer",
          transition: "all 0.15s ease",
          fontFamily: "inherit",
          opacity: 0.7,
        }}
      >
        {expanded ? "hide" : `+${alternatives.length} alternative${alternatives.length > 1 ? "s" : ""}`}
        <svg
          width="10"
          height="10"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          style={{
            transform: expanded ? "rotate(180deg)" : "rotate(0)",
            transition: "transform 0.15s ease",
          }}
        >
          <polyline points="6 9 12 15 18 9" />
        </svg>
      </button>

      {/* Expanded list */}
      {expanded && (
        <div
          style={{
            marginTop: 6,
            display: "flex",
            flexDirection: "column",
            gap: 4,
          }}
        >
          {alternatives.map((alt, idx) => (
            <button
              key={idx}
              onClick={() => onSelect?.(alt)}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                padding: "6px 10px",
                borderRadius: 8,
                border: "1px solid rgba(255,255,255,0.06)",
                background: "var(--hello-surface-chrome)",
                color: "var(--hello-ink-secondary)",
                fontSize: 12,
                fontWeight: 400,
                cursor: "pointer",
                textAlign: "left",
                width: "100%",
                fontFamily: "inherit",
                transition: "border-color 0.15s ease",
              }}
            >
              {/* Thumbnail */}
              {alt.imageUrl ? (
                <img
                  src={alt.imageUrl}
                  alt=""
                  width={28}
                  height={28}
                  style={{ borderRadius: 6, objectFit: "cover", flexShrink: 0 }}
                />
              ) : null}

              {/* Info */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontSize: 12,
                  fontWeight: 400,
                  color: "var(--hello-ink-primary)",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}>
                  {alt.title}
                </div>
                <div style={{ fontSize: 10, color: "var(--hello-ink-tertiary)", fontWeight: 300 }}>
                  {[alt.price, alt.rating ? `${alt.rating}★` : null].filter(Boolean).join(" · ")}
                </div>
              </div>

              {/* Swap arrow */}
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--hello-ink-tertiary)" strokeWidth="1.5" style={{ flexShrink: 0, opacity: 0.5 }}>
                <path d="M7 16V4m0 0L3 8m4-4l4 4M17 8v12m0 0l4-4m-4 4l-4-4" />
              </svg>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
