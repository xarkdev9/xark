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
        <div style={{ overflow: "hidden", padding: "16px 0" }}>
          <motion.h1
            initial={{ y: "100%", opacity: 0, skewY: 10 }}
            animate={phase !== "spark" ? { y: 0, opacity: 1, skewY: 0 } : {}}
            transition={{ duration: 1.2, ease: EASE_OUT_EXPO, delay: 0.2 }}
            style={{
              fontSize: "clamp(6rem, 20vw, 16rem)",
              fontWeight: 800,
              letterSpacing: "-0.04em",
              lineHeight: 0.8,
              color: ink.primary,
              textAlign: "center",
              margin: 0,
            }}
          >
            Xark
          </motion.h1>
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

      {/* ── BEGIN — buttonless trigger ── */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={phase === "idle" ? { opacity: 1, y: 0 } : {}}
        transition={{ duration: 1 }}
        style={{ position: "absolute", bottom: "96px", zIndex: 20 }}
      >
        <motion.div
          onMouseEnter={() => setIsHovered(true)}
          onMouseLeave={() => setIsHovered(false)}
          onTouchStart={() => setIsHovered(true)}
          onTouchEnd={() => setIsHovered(false)}
          whileHover={{ letterSpacing: "0.6em" }}
          animate={{
            opacity: isHovered ? 1 : 0.4,
            scale: isHovered ? 1.1 : 1,
          }}
          onClick={onBegin}
          style={{
            fontSize: "1rem",
            fontWeight: 600,
            letterSpacing: "0.1em",
            color: "#FFFFFF",
            backgroundColor: colors.accent,
            borderRadius: "99px",
            cursor: "pointer",
            padding: "16px 48px",
            transition: "all 0.5s ease",
            WebkitTapHighlightColor: "transparent",
            boxShadow: "0 8px 32px rgba(255, 69, 0, 0.3)",
          }}
        >
          Begin
        </motion.div>
      </motion.div>

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
