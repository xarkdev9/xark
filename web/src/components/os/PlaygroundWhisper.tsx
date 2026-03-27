"use client";

// XARK OS v2.0 — Diegetic Playground Whisper
// Environmental coaching text. NOT a tooltip. Breathes at 30→60% opacity.
// Fades out on interaction. Feels like a secret, not an instruction.

import { motion, AnimatePresence } from "framer-motion";
import { ink } from "@/lib/theme";

interface PlaygroundWhisperProps {
  text: string;
  visible: boolean;
}

export function PlaygroundWhisper({ text, visible }: PlaygroundWhisperProps) {
  return (
    <AnimatePresence>
      {visible && (
        <motion.span
          initial={{ opacity: 0 }}
          animate={{ opacity: [0.3, 0.6, 0.3] }}
          exit={{ opacity: 0 }}
          transition={{
            opacity: { duration: 4, repeat: Infinity, ease: "easeInOut" },
          }}
          style={{
            fontSize: "13px",
            fontWeight: 300,
            letterSpacing: "0.04em",
            color: ink.tertiary,
            display: "inline-block",
          }}
        >
          {text}
        </motion.span>
      )}
    </AnimatePresence>
  );
}
