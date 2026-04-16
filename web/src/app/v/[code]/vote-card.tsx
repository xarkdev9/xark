"use client";

import { useState, useEffect, useCallback } from "react";

interface VoteCardProps {
  inviteCode: string;
  itemId: string;
  title: string;
  category: string;
  photoUrl?: string;
  agreementScore: number;
  weightedScore: number;
}

type Signal = "love_it" | "works_for_me" | "not_for_me";

const SIGNAL_CONFIG: Record<Signal, { label: string; colorVar: string; fallback: string }> = {
  love_it: { label: "Love It", colorVar: "--hello-amber", fallback: "#9E6A06" },
  works_for_me: { label: "Works", colorVar: "--hello-gray", fallback: "#8A8A94" },
  not_for_me: { label: "Pass", colorVar: "--hello-orange", fallback: "#C43D08" },
};

export default function VoteCard({
  inviteCode,
  itemId,
  title,
  category,
  photoUrl,
  agreementScore,
}: VoteCardProps) {
  const [activeSignal, setActiveSignal] = useState<Signal | null>(null);
  const [voting, setVoting] = useState(false);
  const [displayAgreement, setDisplayAgreement] = useState(agreementScore);

  // Load persisted vote on mount
  useEffect(() => {
    const saved = localStorage.getItem(`vote_${itemId}`);
    if (saved && (saved === "love_it" || saved === "works_for_me" || saved === "not_for_me")) {
      setActiveSignal(saved as Signal);
    }
  }, [itemId]);

  const handleVote = useCallback(
    async (signal: Signal) => {
      const voterName = localStorage.getItem("hello_voter_name");
      if (!voterName) {
        alert("Please enter your name first");
        return;
      }

      // Optimistic update
      const prevSignal = activeSignal;
      const prevAgreement = displayAgreement;
      setActiveSignal(signal);
      setDisplayAgreement(Math.min(displayAgreement + 0.05, 1));
      localStorage.setItem(`vote_${itemId}`, signal);
      setVoting(true);

      try {
        const res = await fetch("/api/vote", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ inviteCode, itemId, signal, voterName }),
        });

        if (!res.ok) {
          // Revert optimistic update on failure
          setActiveSignal(prevSignal);
          setDisplayAgreement(prevAgreement);
          if (prevSignal) {
            localStorage.setItem(`vote_${itemId}`, prevSignal);
          } else {
            localStorage.removeItem(`vote_${itemId}`);
          }
          const err = await res.json().catch(() => ({ error: "vote failed" }));
          console.error("[vote]", err.error);
        }
      } catch {
        // Revert on network error
        setActiveSignal(prevSignal);
        setDisplayAgreement(prevAgreement);
        if (prevSignal) {
          localStorage.setItem(`vote_${itemId}`, prevSignal);
        } else {
          localStorage.removeItem(`vote_${itemId}`);
        }
      } finally {
        setVoting(false);
      }
    },
    [inviteCode, itemId, activeSignal, displayAgreement],
  );

  const pct = Math.round(displayAgreement * 100);

  return (
    <div
      style={{
        backdropFilter: "blur(14px)",
        WebkitBackdropFilter: "blur(14px)",
        backgroundColor: "rgba(255, 255, 255, 0.70)",
        borderRadius: "20px",
        border: "1px solid rgba(0, 0, 0, 0.06)",
        overflow: "hidden",
        marginBottom: "16px",
      }}
    >
      {/* Photo */}
      {photoUrl && (
        <div style={{ width: "100%", height: "180px", overflow: "hidden" }}>
          <img
            src={photoUrl}
            alt={title}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              display: "block",
            }}
          />
        </div>
      )}

      <div style={{ padding: "16px 20px 20px" }}>
        {/* Category */}
        <p
          style={{
            fontFamily: "var(--font-inter), Inter, sans-serif",
            fontSize: "10px",
            fontWeight: 400,
            textTransform: "uppercase",
            letterSpacing: "0.08em",
            color: "var(--hello-ink-tertiary, #8A8A94)",
            margin: "0 0 6px 0",
          }}
        >
          {category}
        </p>

        {/* Title */}
        <h3
          style={{
            fontFamily: "var(--font-inter), Inter, sans-serif",
            fontSize: "22px",
            fontWeight: 400,
            color: "var(--hello-white, #111111)",
            margin: "0 0 12px 0",
            lineHeight: 1.25,
          }}
        >
          {title}
        </h3>

        {/* Progress bar */}
        <div
          style={{
            width: "100%",
            height: "4px",
            backgroundColor: "rgba(0, 0, 0, 0.06)",
            borderRadius: "2px",
            overflow: "hidden",
            marginBottom: "6px",
          }}
        >
          <div
            style={{
              width: `${pct}%`,
              height: "100%",
              backgroundColor: "var(--hello-gold, #8B6914)",
              borderRadius: "2px",
              transition: "width 0.3s ease",
            }}
          />
        </div>

        {/* Agreement percentage */}
        <p
          style={{
            fontFamily: "var(--font-inter), Inter, sans-serif",
            fontSize: "12px",
            fontWeight: 400,
            color: "var(--hello-ink-secondary, #6B6B78)",
            margin: "0 0 16px 0",
          }}
        >
          {pct}% agreement
        </p>

        {/* Vote buttons */}
        <div style={{ display: "flex", gap: "8px" }}>
          {(Object.keys(SIGNAL_CONFIG) as Signal[]).map((sig) => {
            const cfg = SIGNAL_CONFIG[sig];
            const isActive = activeSignal === sig;
            const color = `var(${cfg.colorVar}, ${cfg.fallback})`;

            return (
              <button
                key={sig}
                disabled={voting}
                onClick={() => handleVote(sig)}
                style={{
                  flex: 1,
                  fontFamily: "var(--font-inter), Inter, sans-serif",
                  fontSize: "13px",
                  fontWeight: 400,
                  color: isActive ? color : "var(--hello-ink-secondary, #6B6B78)",
                  backgroundColor: isActive ? `color-mix(in srgb, ${color} 8%, transparent)` : "rgba(0, 0, 0, 0.03)",
                  border: isActive ? `2px solid ${color}` : "2px solid transparent",
                  borderRadius: "12px",
                  padding: "10px 4px",
                  cursor: voting ? "wait" : "pointer",
                  transition: "all 0.2s ease",
                  outline: "none",
                }}
              >
                {cfg.label}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
