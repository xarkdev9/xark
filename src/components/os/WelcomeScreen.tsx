"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";

type Phase = "spark" | "collision" | "reveal" | "idle";

const EASE_OUT_EXPO = [0.16, 1, 0.3, 1] as const;

import { ink, colors } from "@/lib/theme";

interface WelcomeScreenProps {
  onBegin: () => void;
}

export function WelcomeScreen({ onBegin }: WelcomeScreenProps) {
  const [phase, setPhase] = useState<Phase>("spark");
  const [isHovered, setIsHovered] = useState(false);

  useEffect(() => {
    const timers = [
      setTimeout(() => setPhase("collision"), 800),
      setTimeout(() => setPhase("reveal"), 1800),
      setTimeout(() => setPhase("idle"), 3500),
    ];
    return () => timers.forEach(clearTimeout);
  }, []);

  const line1 = "People, plans, and memories.";
  const line2 = "Decide together, effortlessly.";

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        overflow: "hidden",
        zIndex: 10,
        userSelect: "none",
      }}
    >
      {/* ── MOTION TYPOGRAPHY ── */}
      <div
        style={{
          position: "relative",
          zIndex: 10,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          width: "100%",
          padding: "0 32px",
          overflow: "hidden",
        }}
      >
        {/* Wordmark — slides up from below with skew */}
        <div style={{ padding: "16px 0", perspective: "1000px" }}>
          <motion.div
            initial={{ y: "100%", opacity: 0, rotateX: 20 }}
            animate={phase !== "spark" ? { y: 0, opacity: 1, rotateX: 0 } : {}}
            transition={{ duration: 1.2, ease: EASE_OUT_EXPO, delay: 0.2 }}
            onClick={onBegin}
            whileTap={{
              scale: 0.92,
              boxShadow: "0 4px 16px rgba(0, 0, 0, 0.08)",
              transition: { type: "spring", stiffness: 400, damping: 25 }
            }}
            className="cursor-pointer select-none flex items-center justify-center gap-6"
            style={{
              background: "rgba(255, 255, 255, 0.7)",
              backdropFilter: "blur(40px) saturate(200%)",
              WebkitBackdropFilter: "blur(40px) saturate(200%)",
              boxShadow: "0 16px 64px rgba(0, 0, 0, 0.08)",
              borderRadius: "999px",
              padding: "24px 64px",
              WebkitTapHighlightColor: "transparent",
            }}
          >
            {/* Ultra-Light OS Text */}
            <span
              style={{
                fontSize: "clamp(4rem, 12vw, 8rem)",
                fontWeight: 100,
                letterSpacing: "-0.04em",
                lineHeight: 0.8,
                color: ink.primary,
              }}
            >
              xark
            </span>

            {/* Giant Cyan Heartbeat */}
            <motion.div
              animate={{ opacity: [0.4, 1, 0.4] }}
              transition={{ duration: 2.5, repeat: Infinity, ease: "easeInOut" }}
              style={{
                width: "clamp(12px, 3vw, 24px)",
                height: "clamp(12px, 3vw, 24px)",
                borderRadius: "50%",
                backgroundColor: colors.cyan,
                boxShadow: `0 0 16px ${colors.cyan}`,
              }}
            />
          </motion.div>
        </div>

        {/* Tagline — two lines, slide-up reveal */}
        <div
          style={{
            marginTop: "32px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: "8px",
          }}
        >
          {[line1, line2].map((lineText, i) => (
            <div key={i} style={{ overflow: "hidden" }}>
              <motion.p
                initial={{ y: "100%" }}
                animate={
                  phase === "reveal" || phase === "idle" ? { y: 0 } : {}
                }
                transition={{
                  duration: 0.8,
                  ease: EASE_OUT_EXPO,
                  delay: 1.8 + i * 0.2,
                }}
                style={{
                  fontSize: "1.2rem",
                  fontWeight: 300,
                  letterSpacing: "0.05em",
                  color: ink.primary,
                  opacity: 0.7,
                  textAlign: "center",
                  margin: 0,
                }}
              >
                {lineText}
              </motion.p>
            </div>
          ))}
        </div>
      </div>



      {/* ── SECURITY HALLMARK ── */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={phase === "idle" ? { opacity: 0.3 } : {}}
        style={{
          position: "absolute",
          bottom: "32px",
          left: "32px",
          zIndex: 10,
        }}
      >
        <span
          style={{
            fontSize: "10px",
            fontWeight: 300,
            letterSpacing: "0.3em",
            color: ink.tertiary,
          }}
        >
          Encrypted, always.
        </span>
      </motion.div>
    </div>
  );
}
