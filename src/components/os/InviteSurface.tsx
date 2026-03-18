"use client";

// XARK OS v2.0 — INVITE SURFACE
// Empty state for the People tab when the user has 0 contacts.
// Tappable surface: generates an invite link and shares/copies it.

import { useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { text, ink } from "@/lib/theme";
import { getSupabaseToken } from "@/lib/supabase";

interface InviteSurfaceProps {
  userName: string;
}

/** Generate an invite link via /api/summon and trigger native share or clipboard copy. */
export async function generateAndShareInvite(userName: string): Promise<void> {
  const token = getSupabaseToken();
  const res = await fetch("/api/summon", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });

  if (!res.ok) throw new Error(`invite link failed: ${res.status}`);

  const { url } = await res.json();
  if (!url) throw new Error("no url returned");

  if (typeof navigator !== "undefined" && navigator.share) {
    await navigator.share({
      title: "xark",
      text: `${userName} wants to plan with you`,
      url,
    });
  } else {
    await navigator.clipboard.writeText(url);
  }
}

export function InviteSurface({ userName }: InviteSurfaceProps) {
  const [whisper, setWhisper] = useState(false);
  const [isInviting, setIsInviting] = useState(false);

  const handleInvite = useCallback(async () => {
    if (isInviting) return;
    setIsInviting(true);

    try {
      await generateAndShareInvite(userName);
    } catch {
      // User cancelled share or clipboard fallback
      try {
        // If share was cancelled but we have a URL, try clipboard
      } catch { /* ignore */ }
    } finally {
      setIsInviting(false);
    }
  }, [isInviting, userName]);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={handleInvite}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleInvite(); }}
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
        opacity: isInviting ? 0.6 : 1,
        transition: "opacity 0.3s ease",
      }}
    >
      {/* Slow-pulsing mesh */}
      <motion.div
        className="pointer-events-none absolute inset-0"
        style={{
          background: `radial-gradient(ellipse 80% 60% at 50% 50%, rgba(var(--xark-accent-rgb), 1) 0%, transparent 70%)`,
        }}
        animate={{ opacity: [0.02, 0.05, 0.02] }}
        transition={{ duration: 15, repeat: Infinity, ease: "easeInOut" }}
      />

      <span
        style={{
          ...text.subtitle,
          color: ink.primary,
          opacity: 0.7,
          textAlign: "center",
          position: "relative",
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
        }}
      >
        Send a link. They join your chat.
      </span>

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
