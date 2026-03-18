"use client";

// XARK OS v2.0 — SUMMON SURFACE
// Empty state for the People tab when the user has 0 contacts.
// Tappable surface: generates a summon link and shares/copies it.

import { useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text, ink, surface } from "@/lib/theme";
import { getSupabaseToken } from "@/lib/supabase";

interface SummonSurfaceProps {
  userName: string;
}

export function SummonSurface({ userName }: SummonSurfaceProps) {
  const [whisper, setWhisper] = useState(false);
  const [isSummoning, setIsSummoning] = useState(false);

  const handleSummon = useCallback(async () => {
    if (isSummoning) return;
    setIsSummoning(true);

    try {
      const token = getSupabaseToken();
      const res = await fetch("/api/summon", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });

      if (!res.ok) {
        console.error("[summon] failed:", res.status);
        return;
      }

      const { url } = await res.json();
      if (!url) return;

      if (typeof navigator !== "undefined" && navigator.share) {
        try {
          await navigator.share({
            title: "xark",
            text: `${userName} wants to plan with you`,
            url,
          });
        } catch {
          // User cancelled share — no-op
        }
      } else {
        // Fallback: copy to clipboard + show whisper
        await navigator.clipboard.writeText(url);
        setWhisper(true);
        setTimeout(() => setWhisper(false), 2000);
      }
    } catch (err) {
      console.error("[summon] error:", err);
    } finally {
      setIsSummoning(false);
    }
  }, [isSummoning, userName]);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={handleSummon}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleSummon(); }}
      className="outline-none cursor-pointer"
      style={{
        position: "relative",
        minHeight: "280px",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: "10px",
        padding: "48px 32px",
        opacity: isSummoning ? 0.6 : 1,
        transition: "opacity 0.3s ease",
      }}
    >
      {/* Slow-pulsing mesh — cyan wash at 0.03 opacity */}
      <motion.div
        className="pointer-events-none absolute inset-0"
        style={{
          background: `radial-gradient(ellipse 80% 60% at 50% 50%, rgba(var(--xark-accent-rgb), 1) 0%, transparent 70%)`,
        }}
        animate={{ opacity: [0.02, 0.05, 0.02] }}
        transition={{ duration: 15, repeat: Infinity, ease: "easeInOut" }}
      />

      {/* Center text */}
      <span
        style={{
          ...text.subtitle,
          color: ink.primary,
          opacity: 0.7,
          textAlign: "center",
          position: "relative",
          textTransform: "capitalize",
        }}
      >
        Invite someone
      </span>

      <span
        style={{
          ...text.hint,
          color: ink.tertiary,
          textAlign: "center",
          position: "relative",
          textTransform: "none",
        }}
      >
        Send a link. They join your chat.
      </span>

      {/* "link copied" whisper — fades in and out */}
      <AnimatePresence>
        {whisper && (
          <motion.span
            key="whisper"
            initial={{ opacity: 0, y: 4 }}
            animate={{ opacity: 0.5 }}
            exit={{ opacity: 0, y: -4 }}
            transition={{ duration: 0.3 }}
            style={{
              ...text.hint,
              color: ink.tertiary,
              position: "absolute",
              bottom: "20px",
              left: 0,
              right: 0,
              textAlign: "center",
              pointerEvents: "none",
            }}
          >
            link copied
          </motion.span>
        )}
      </AnimatePresence>
    </div>
  );
}
