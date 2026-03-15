"use client";

// XARK OS v2.0 — AWARENESS STREAM
// Extracted from Galaxy page. Renders space awareness items with opacity, summary, recency.
// Includes space creation flow (dream input + send icon).
// Independent data fetching + real-time subscription.

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import {
  fetchAwareness,
  getDemoAwareness,
  summaryText,
} from "@/lib/awareness";
import type { SpaceAwareness } from "@/lib/awareness";
import { recencyLabel } from "@/lib/space-data";
import { supabase } from "@/lib/supabase";
import { colors, ink, timing, layout, text } from "@/lib/theme";
import { useThemeContext } from "@/components/os/ThemeProvider";
import { Avatar } from "@/components/os/Avatar";
import { Whisper, dismissOnboardingWhisper } from "@/components/os/OnboardingWhispers";

interface AwarenessStreamProps {
  userId: string;
  userName: string;
  onSpaceTap: (spaceId: string, viewMode?: "decide") => void;
}

export function AwarenessStream({ userId, userName, onSpaceTap }: AwarenessStreamProps) {
  const { isVibe } = useThemeContext();
  const [spaces, setSpaces] = useState<SpaceAwareness[]>([]);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Fetch awareness on mount
  useEffect(() => {
    if (!userId) return;
    fetchAwareness(userId)
      .then((result) => setSpaces(result.length > 0 ? result : getDemoAwareness()))
      .catch(() => setSpaces(getDemoAwareness()));
  }, [userId]);

  // Real-time: refetch when user is added to a new space
  useEffect(() => {
    if (!userId) return;
    const channel = supabase
      .channel(`awareness:${userId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "space_members",
          filter: `user_id=eq.${userId}`,
        },
        () => {
          fetchAwareness(userId)
            .then((result) => setSpaces(result.length > 0 ? result : getDemoAwareness()))
            .catch(() => {});
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [userId]);

  const allPeaceful = spaces.length > 0 && spaces.every((s) => !s.actionNeeded);

  const handleSpaceTap = useCallback((spaceId: string) => {
    dismissOnboardingWhisper("galaxy_tap");
    onSpaceTap(spaceId, "decide");
  }, [onSpaceTap]);

  return (
    <div className="px-6">
      <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
        {/* ── Awareness items ── */}
        {spaces.length > 0 && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6 }}
          >
            {spaces.map((space, index) => {
              const summary = summaryText(space);

              return (
                <motion.div
                  key={space.spaceId}
                  role="button"
                  tabIndex={0}
                  onClick={() => handleSpaceTap(space.spaceId)}
                  onKeyDown={(e) => { if (e.key === "Enter") handleSpaceTap(space.spaceId); }}
                  className={`cursor-pointer outline-none ${isVibe ? "vibe-row" : ""}`}
                  style={{ paddingBottom: isVibe ? "0" : "20px", marginBottom: isVibe ? "8px" : "0" }}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{
                    delay: 0.1 + index * timing.staggerDelay,
                    duration: 0.5,
                    ease: [0.22, 1, 0.36, 1],
                  }}
                >
                  <div className="flex items-center gap-3">
                    <div style={isVibe ? {
                      borderRadius: "14px",
                      boxShadow: "0 4px 14px rgba(0,0,0,0.12), 0 1px 4px rgba(0,0,0,0.08)",
                      overflow: "hidden",
                      transform: "translateZ(0)",
                    } : undefined}>
                      <Avatar name={space.spaceTitle} size={isVibe ? 44 : 36} shape={isVibe ? "square" : "circle"} />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline justify-between">
                        <p style={{ ...text.listTitle, color: ink.primary }}>
                          {space.spaceTitle}
                        </p>
                        <p style={{ ...text.timestamp, color: ink.tertiary }}>
                          {recencyLabel(new Date(space.lastActivityAt))}
                        </p>
                      </div>
                      <p
                        style={{
                          ...text.recency,
                          color: space.actionNeeded
                            ? colors.amber
                            : ink.secondary,
                        }}
                      >
                        {summary}
                      </p>
                    </div>
                  </div>
                </motion.div>
              );
            })}

            {/* Peace state */}
            {allPeaceful && (
              <motion.p
                className="mt-8"
                style={{ ...text.subtitle, color: ink.tertiary }}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.5, duration: 0.8 }}
              >
                you're good. your trips are moving along.
              </motion.p>
            )}

            <Whisper whisperKey="galaxy_tap" delay={2.5}>
              tap any plan to jump in
            </Whisper>
          </motion.div>
        )}

        {/* ── Empty state ── */}
        {spaces.length === 0 && mounted && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5, duration: 0.8 }}
          >
            <p style={{ ...text.subtitle, color: ink.secondary }}>
              no active plans yet
            </p>
            <p
              className="mt-2"
              style={{ ...text.recency, color: ink.tertiary }}
            >
              start a plan below to get going
            </p>
          </motion.div>
        )}

      </div>
    </div>
  );
}
