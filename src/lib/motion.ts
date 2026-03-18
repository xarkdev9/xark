// XARK OS v2.0 — Physics Engine (Framer Motion Tokens)
// ALL transitions in the app must use these spring configs.
// CSS ease/linear transitions are BANNED. Everything is physical.
//
// Usage: import { spring, ambient } from "@/lib/motion"
//   <motion.div transition={spring.snappy} />
//   <motion.div animate={ambient.breathe} transition={ambient.breatheTiming} />

import type { Transition } from "framer-motion";

// ── Spring Configs ─────────────────────────────────────────────────────────
// Every UI motion in Xark uses one of these. No exceptions.

export const spring = {
  /** Button taps, micro-interactions, instant responses. Heavy feel. */
  snappy: {
    type: "spring" as const,
    stiffness: 400,
    damping: 25,
  },

  /** Sheet slides, panels, large surface movements. Weighted momentum. */
  fluid: {
    type: "spring" as const,
    stiffness: 200,
    damping: 20,
    mass: 0.8,
  },

  /** Soft enter/exit for overlays, fades with body. */
  gentle: {
    type: "spring" as const,
    stiffness: 120,
    damping: 18,
    mass: 1,
  },

  /** Card entrances, staggered reveals. Deliberate weight. */
  entrance: {
    type: "spring" as const,
    stiffness: 100,
    damping: 20,
  },
} satisfies Record<string, Transition>;

// ── Ambient Animations ─────────────────────────────────────────────────────
// Infinite loops for living UI. Breathing, pulsing, glowing.

export const ambient = {
  /** Breathing opacity cycle — the resting heartbeat of the app */
  breathe: {
    opacity: [0.7, 0.9, 0.7],
  },
  breatheTiming: {
    repeat: Infinity,
    repeatType: "mirror" as const,
    duration: 2,
    ease: "easeInOut" as const,
  },

  /** Cyan whisper pulse — faster, more urgent breathing for pending state */
  whisperPulse: {
    opacity: [0.5, 1, 0.5],
    scale: [1, 1.08, 1],
  },
  whisperPulseTiming: {
    repeat: Infinity,
    repeatType: "mirror" as const,
    duration: 1.5,
    ease: "easeInOut" as const,
  },

  /** Gold consensus glow — steady confident pulse */
  goldPulse: {
    opacity: [0.6, 1, 0.6],
  },
  goldPulseTiming: {
    repeat: Infinity,
    repeatType: "mirror" as const,
    duration: 2.5,
    ease: "easeInOut" as const,
  },

  /** Scouting dot — rapid cyan blink for active AI work */
  scoutDot: {
    opacity: [0.3, 1, 0.3],
    scale: [0.8, 1.2, 0.8],
  },
  scoutDotTiming: {
    repeat: Infinity,
    duration: 0.8,
    ease: "easeInOut" as const,
  },
};

// ── Exit Presets ────────────────────────────────────────────────────────────
// Exit animations are 60-70% of enter duration (Material motion principle).

export const exit = {
  /** Ghost text shatter — scale up, blur out, vanish */
  shatter: {
    opacity: 0,
    scale: 1.05,
    filter: "blur(4px)",
  },
  shatterTiming: {
    duration: 0.15,
  },

  /** Soft fade out */
  fade: {
    opacity: 0,
  },
  fadeTiming: {
    duration: 0.12,
  },
};

// ── Tap Presets ─────────────────────────────────────────────────────────────
// Physical press feedback. Every tappable element gets one.

export const tap = {
  /** Heavy key press — for primary interactive elements */
  heavy: {
    scale: 0.92,
  },

  /** Light press — for secondary elements */
  light: {
    scale: 0.96,
  },

  /** Micro press — for inline text buttons */
  micro: {
    scale: 0.98,
    opacity: 0.7,
  },
};
