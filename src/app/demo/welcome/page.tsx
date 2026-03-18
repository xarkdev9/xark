"use client";

// XARK OS — Kinetic Welcome (Ad Demo)
// Apple-style: spring physics wordmark slam + CSS-only vertical reel.
// Dark OLED. No particles. No glitch. Pure typography and motion.
// Route: /demo/welcome

import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";

// ── The words — escalating from mundane to meaningful ──
const WORDS = [
  { text: "text.", color: "rgba(255,255,255,0.3)" },
  { text: "chat.", color: "rgba(255,255,255,0.4)" },
  { text: "plan.", color: "rgba(255,255,255,0.55)" },
  { text: "group chat.", color: "#40E0FF" },
  { text: "group planning.", color: "#F5A623" },
  { text: "deciding.", color: "#FFD700" },
  { text: "group execution.", color: "#10B981" },
  { text: "living.", color: "#FF6B35" },
  { text: "memories.", color: "#FF6B35" },
];

const ITEM_HEIGHT = 52;
const REEL_HEIGHT = 56;
const WORD_COUNT = WORDS.length;
const SPEED_PER_WORD = 0.5; // seconds
const TOTAL_DURATION = SPEED_PER_WORD * WORD_COUNT;

export default function DemoWelcomePage() {
  const [showReel, setShowReel] = useState(false);
  const [showCta, setShowCta] = useState(false);

  useEffect(() => {
    const t1 = setTimeout(() => setShowReel(true), 1600);
    const t2 = setTimeout(() => setShowCta(true), 2800);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, []);

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        background: "#050508",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        overflow: "hidden",
        fontFamily: "Inter, system-ui, sans-serif",
        userSelect: "none",
      }}
    >
      {/* ── Ambient radial — barely there ── */}
      <div
        style={{
          position: "absolute",
          width: "80vw",
          height: "80vw",
          maxWidth: "600px",
          maxHeight: "600px",
          borderRadius: "50%",
          background: "radial-gradient(circle, rgba(255,107,53,0.03), transparent 70%)",
          pointerEvents: "none",
        }}
      />

      {/* ── Wordmark — spring slam from 3x scale ── */}
      <div style={{ overflow: "hidden", padding: "20px 0" }}>
        <motion.h1
          initial={{ scale: 3, opacity: 0, y: 40 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          transition={{
            type: "spring",
            stiffness: 70,
            damping: 12,
            mass: 1.3,
            delay: 0.3,
          }}
          style={{
            fontSize: "clamp(7rem, 22vw, 16rem)",
            fontWeight: 300,
            letterSpacing: "-0.06em",
            lineHeight: 0.85,
            color: "#fff",
            textAlign: "center",
            textTransform: "lowercase",
            margin: 0,
          }}
        >
          xark
        </motion.h1>
      </div>

      {/* ── "redefining" + Vertical Reel ── */}
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={showReel ? { opacity: 1, y: 0 } : {}}
        transition={{
          type: "spring",
          stiffness: 100,
          damping: 18,
          delay: 0.1,
        }}
        style={{
          marginTop: "20px",
          display: "flex",
          alignItems: "center",
          gap: "12px",
        }}
      >
        {/* Static prefix */}
        <span
          style={{
            fontSize: "1.25rem",
            fontWeight: 300,
            letterSpacing: "0.1em",
            color: "rgba(255,255,255,0.35)",
            whiteSpace: "nowrap",
          }}
        >
          redefining
        </span>

        {/* ── CSS-only vertical marquee ── */}
        <style>{`
          @keyframes xark-reel {
            to { translate: 0 var(--dest); }
          }
        `}</style>
        <div
          style={{
            overflow: "hidden",
            height: `${REEL_HEIGHT}px`,
            position: "relative",
            minWidth: "240px",
            mask: "linear-gradient(rgba(0,0,0,0) 0%, rgb(0,0,0) 30%, rgb(0,0,0) 70%, rgba(0,0,0,0) 100%)",
            WebkitMask: "linear-gradient(rgba(0,0,0,0) 0%, rgb(0,0,0) 30%, rgb(0,0,0) 70%, rgba(0,0,0,0) 100%)",
          }}
        >
          <div style={{ position: "relative", height: "100%" }}>
            {WORDS.map((word, index) => (
              <div
                key={word.text}
                style={{
                  height: `${ITEM_HEIGHT}px`,
                  display: "flex",
                  alignItems: "center",
                  translate: `0 calc((${WORD_COUNT} - ${index}) * 100%)`,
                  animation: `xark-reel ${TOTAL_DURATION}s calc((${TOTAL_DURATION}s / ${WORD_COUNT}) * ${index} - ${TOTAL_DURATION}s) infinite linear`,
                  ["--dest" as string]: `calc((${index} + 1) * -100%)`,
                }}
              >
                <span
                  style={{
                    fontSize: "1.4rem",
                    fontWeight: 300,
                    letterSpacing: "0.04em",
                    color: word.color,
                    whiteSpace: "nowrap",
                    textShadow: word.color.startsWith("#")
                      ? `0 0 24px ${word.color}50, 0 0 48px ${word.color}20`
                      : "none",
                  }}
                >
                  {word.text}
                </span>
              </div>
            ))}
          </div>
        </div>
      </motion.div>

      {/* ── Horizontal reveal line ── */}
      <motion.div
        initial={{ scaleX: 0, opacity: 0 }}
        animate={showReel ? { scaleX: 1, opacity: 1 } : {}}
        transition={{ duration: 1.2, ease: [0.22, 1, 0.36, 1], delay: 0.3 }}
        style={{
          width: "min(280px, 60vw)",
          height: "1px",
          background: "linear-gradient(90deg, transparent, rgba(255,107,53,0.2), transparent)",
          marginTop: "32px",
          transformOrigin: "center",
        }}
      />

      {/* ── Bottom: "begin" + hallmark ── */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={showCta ? { opacity: 1, y: 0 } : {}}
        transition={{
          type: "spring",
          stiffness: 80,
          damping: 16,
        }}
        style={{
          position: "absolute",
          bottom: "56px",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: "24px",
        }}
      >
        <motion.span
          animate={{ opacity: [0.25, 0.55, 0.25] }}
          transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut" }}
          style={{
            fontSize: "0.85rem",
            fontWeight: 300,
            letterSpacing: "0.4em",
            color: "#FF6B35",
            textTransform: "lowercase",
            cursor: "pointer",
          }}
        >
          begin
        </motion.span>
        <span
          style={{
            fontSize: "9px",
            fontWeight: 300,
            letterSpacing: "0.3em",
            color: "rgba(255,255,255,0.12)",
            textTransform: "uppercase",
          }}
        >
          encrypted, always.
        </span>
      </motion.div>
    </div>
  );
}
