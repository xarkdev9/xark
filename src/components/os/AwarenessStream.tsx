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
import { fetchUnreadCounts } from "@/lib/unread";

interface AwarenessStreamProps {
  userId: string;
  userName: string;
  onSpaceTap: (spaceId: string, viewMode?: "decide") => void;
  playgroundSpaces?: SpaceAwareness[];
}

export function AwarenessStream({ userId, userName, onSpaceTap, playgroundSpaces }: AwarenessStreamProps) {
  const { isVibe } = useThemeContext();
  const [spaces, setSpaces] = useState<SpaceAwareness[]>([]);
  const [unreadCounts, setUnreadCounts] = useState<Record<string, number>>({});
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Fetch awareness + unread counts on mount
  useEffect(() => {
    if (!userId) return;
    fetchAwareness(userId)
      .then((result) => setSpaces(result))
      .catch(() => setSpaces([]));
    fetchUnreadCounts()
      .then(setUnreadCounts)
      .catch(() => {});
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
            .then((result) => setSpaces(result))
            .catch(() => {});
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [userId]);

  // Use playground spaces when real spaces are empty
  const displaySpaces = spaces.length > 0 ? spaces : (playgroundSpaces ?? []);
  const isPlayground = spaces.length === 0 && (playgroundSpaces ?? []).length > 0;
  const allPeaceful = displaySpaces.length > 0 && displaySpaces.every((s) => !s.actionNeeded);

  const handleSpaceTap = useCallback((spaceId: string) => {
    dismissOnboardingWhisper("galaxy_tap");
    onSpaceTap(spaceId);
  }, [onSpaceTap]);

  return (
    <div className="px-6">
      <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
        {/* ── Awareness items (real or playground) ── */}
        {displaySpaces.length > 0 && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6 }}
          >
            {displaySpaces.map((space, index) => {
              const summary = summaryText(space);

              return (
                <motion.div
                  key={space.spaceId}
                  role="button"
                  tabIndex={0}
                  onClick={() => handleSpaceTap(space.spaceId)}
                  onKeyDown={(e) => { if (e.key === "Enter") handleSpaceTap(space.spaceId); }}
                  className="cursor-pointer outline-none"
                  style={{ paddingBottom: "20px" }}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{
                    delay: 0.1 + index * timing.staggerDelay,
                    duration: 0.5,
                    ease: [0.22, 1, 0.36, 1],
                  }}
                >
                  <div className="flex items-center gap-3">
                    {/* Avatar — vibe: square with depth shadow + warm glow */}
                    <div style={{ position: "relative", flexShrink: 0 }}>
                      {isVibe && (
                        <div style={{
                          position: "absolute", inset: "-6px",
                          borderRadius: "18px",
                          background: "radial-gradient(circle, rgba(var(--xark-amber-rgb), 0.06) 0%, transparent 70%)",
                          pointerEvents: "none",
                        }} />
                      )}
                      <div style={isVibe ? {
                        borderRadius: "14px",
                        boxShadow: "0 4px 16px rgba(0,0,0,0.1), 0 1px 3px rgba(0,0,0,0.06)",
                        overflow: "hidden",
                      } : undefined}>
                        <Avatar name={space.spaceTitle} size={isVibe ? 46 : 36} shape={isVibe ? "square" : "circle"} />
                      </div>
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline justify-between">
                        <p style={{ ...text.listTitle, color: ink.primary }}>
                          {space.spaceTitle}
                        </p>
                        <div className="flex items-center gap-2">
                          <p style={{ ...text.timestamp, color: ink.tertiary }}>
                            {recencyLabel(new Date(space.lastActivityAt))}
                          </p>
                          {(unreadCounts[space.spaceId] ?? 0) > 0 && (
                            <span style={{
                              display: "inline-flex",
                              alignItems: "center",
                              justifyContent: "center",
                              minWidth: "18px",
                              height: "18px",
                              borderRadius: "9px",
                              padding: "0 5px",
                              fontSize: "11px",
                              fontWeight: 400,
                              color: "#fff",
                              backgroundColor: "#FF6B35",
                            }}>
                              {unreadCounts[space.spaceId] > 99 ? "99+" : unreadCounts[space.spaceId]}
                            </span>
                          )}
                        </div>
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

        {/* ── Empty state — inviting, not hollow ── */}
        {spaces.length === 0 && mounted && (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
            className="py-8"
          >
            <p style={{ ...text.listTitle, color: ink.primary }}>
              where to?
            </p>
            <p
              className="mt-3"
              style={{ ...text.subtitle, color: ink.secondary }}
            >
              type a dream below — a trip, dinner tonight, something to buy together
            </p>
            <Whisper whisperKey="galaxy_input" delay={3}>
              try "weekend in napa" or "dinner tonight"
            </Whisper>
          </motion.div>
        )}

      </div>
    </div>
  );
}
