"use client";

// XARK OS v2.0 — Onboarding Whispers
// Atmospheric floating hints for first 3 days.
// Disappear after user performs the action or 3 days pass.

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text, textColor } from "@/lib/theme";

const THREE_DAYS_MS = 3 * 24 * 60 * 60 * 1000;

type WhisperKey =
  | "galaxy_input"
  | "galaxy_tap"
  | "space_chat"
  | "space_mic";

function getFirstSeen(): number {
  if (typeof window === "undefined") return Date.now();
  const stored = localStorage.getItem("xark_first_seen");
  if (stored) return parseInt(stored, 10);
  const now = Date.now();
  localStorage.setItem("xark_first_seen", String(now));
  return now;
}

function isDismissed(key: WhisperKey): boolean {
  if (typeof window === "undefined") return false;
  return localStorage.getItem(`xark_whisper_${key}`) === "done";
}

function dismissWhisper(key: WhisperKey) {
  if (typeof window === "undefined") return;
  localStorage.setItem(`xark_whisper_${key}`, "done");
}

function isWithinOnboarding(): boolean {
  return Date.now() - getFirstSeen() < THREE_DAYS_MS;
}

interface WhisperProps {
  whisperKey: WhisperKey;
  children: string;
  align?: "left" | "center" | "right";
  delay?: number;
}

export function Whisper({ whisperKey, children, align = "left", delay = 1.5 }: WhisperProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!isWithinOnboarding() || isDismissed(whisperKey)) return;
    const t = setTimeout(() => setVisible(true), delay * 1000);
    return () => clearTimeout(t);
  }, [whisperKey, delay]);

  if (!visible) return null;

  return (
    <AnimatePresence>
      <motion.p
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -4 }}
        transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
        style={{
          ...text.recency,
          color: textColor(0.2),
          textAlign: align,
        }}
      >
        {children}
      </motion.p>
    </AnimatePresence>
  );
}

export function dismissOnboardingWhisper(key: WhisperKey) {
  dismissWhisper(key);
}
