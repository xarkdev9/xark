"use client";

import { motion } from "framer-motion";
import type { ConsensusState } from "@/lib/heart-sort";
import { colors } from "@/lib/theme";

interface ConsensusMarkProps {
  agreementScore: number;
  state: ConsensusState;
  size?: number;
}

export function ConsensusMark({ agreementScore, state, size = 32 }: ConsensusMarkProps) {
  const r = size / 2 - 2;
  const cx = size / 2;
  const cy = size / 2;
  const circumference = 2 * Math.PI * r;

  if (state === "seeking") {
    return (
      <motion.svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}
        animate={{ scale: [1, 1.12, 1] }}
        transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], repeat: Infinity, repeatDelay: 1.4 }}>
        <motion.circle cx={cx} cy={cy} r={r}
          style={{ fill: "none", stroke: colors.amber, strokeWidth: 1.5,
            strokeDasharray: `${circumference * 0.12} ${circumference * 0.08}`,
            opacity: 0.6 + agreementScore, transformOrigin: "center" }}
          animate={{ rotate: 360 }}
          transition={{ duration: 8, ease: "linear", repeat: Infinity }} />
      </motion.svg>
    );
  }

  if (state === "steady") {
    return (
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={cx} cy={cy} r={r} style={{ fill: "none", stroke: colors.amber, strokeWidth: 1, opacity: 0.5 }} />
        <motion.circle cx={cx} cy={cy} r={3} style={{ fill: colors.cyan }}
          animate={{ opacity: [0.4, 1, 0.4] }}
          transition={{ duration: 4.5, ease: "easeInOut", repeat: Infinity }} />
      </svg>
    );
  }

  const flareCount = 6;
  const flares = Array.from({ length: flareCount }, (_, i) => {
    const angle = (i / flareCount) * Math.PI * 2;
    const flareR = r + 4;
    return { x: cx + Math.cos(angle) * flareR, y: cy + Math.sin(angle) * flareR, delay: i * 0.15 };
  });

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <motion.circle cx={cx} cy={cy} r={r}
        style={{ fill: "none", stroke: colors.gold, strokeWidth: 1.5 }}
        animate={{ opacity: [0.6, 1, 0.6] }}
        transition={{ duration: 2, ease: "easeInOut", repeat: Infinity }} />
      {flares.map((f, i) => (
        <motion.circle key={i} cx={f.x} cy={f.y} r={1.5} style={{ fill: colors.gold }}
          animate={{ opacity: [0, 0.8, 0], scale: [0.5, 1.2, 0.5] }}
          transition={{ duration: 1.8, delay: f.delay, ease: "easeInOut", repeat: Infinity }} />
      ))}
      <circle cx={cx} cy={cy} r={3} style={{ fill: colors.gold, opacity: 0.9 }} />
    </svg>
  );
}
