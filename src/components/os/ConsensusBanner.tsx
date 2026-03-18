"use client";

// XARK OS v2.0 — CONSENSUS BANNER
// Pinned system banner that appears above chat when a decision item's
// consensus countdown is active (lock_deadline set, not yet locked).
// Constitutional: no borders, no bold, theme tokens only, zero-box.

import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { colors, text as textTokens, ink, surface } from "@/lib/theme";
import type { RealtimeChannel } from "@supabase/supabase-js";

interface ConsensusBannerProps {
  spaceId: string;
}

interface ActiveItem {
  id: string;
  title: string;
  lock_deadline: string;
}

export function ConsensusBanner({ spaceId }: ConsensusBannerProps) {
  const [activeItem, setActiveItem] = useState<ActiveItem | null>(null);
  const channelRef = useRef<RealtimeChannel | null>(null);

  useEffect(() => {
    let cancelled = false;

    // Initial fetch — first item with an active deadline
    async function fetchActiveDeadline() {
      const { data, error } = await supabase
        .from("decision_items")
        .select("id, title, lock_deadline")
        .eq("space_id", spaceId)
        .eq("is_locked", false)
        .not("lock_deadline", "is", null)
        .order("lock_deadline", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (cancelled) return;
      if (error || !data) {
        setActiveItem(null);
        return;
      }
      setActiveItem({ id: data.id, title: data.title, lock_deadline: data.lock_deadline });
    }

    fetchActiveDeadline();

    // Realtime subscription — react to decision_items changes in this space
    const channel = supabase
      .channel(`consensus-banner:${spaceId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "decision_items",
          filter: `space_id=eq.${spaceId}`,
        },
        (payload) => {
          if (cancelled) return;
          const row = payload.new as {
            id: string;
            title: string;
            lock_deadline: string | null;
            is_locked: boolean;
          };

          // If updated item has an active deadline and is not locked, show it
          if (row.lock_deadline && !row.is_locked) {
            setActiveItem({ id: row.id, title: row.title, lock_deadline: row.lock_deadline });
            return;
          }

          // If the currently displayed item is now locked or deadline cleared, dismiss
          setActiveItem((prev) => {
            if (prev && prev.id === row.id) return null;
            return prev;
          });
        }
      )
      .subscribe();

    channelRef.current = channel;

    return () => {
      cancelled = true;
      supabase.removeChannel(channel);
      channelRef.current = null;
    };
  }, [spaceId]);

  return (
    <AnimatePresence>
      {activeItem && (
        <motion.div
          key={activeItem.id}
          initial={{ y: -40, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -40, opacity: 0 }}
          transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
          style={{
            position: "sticky",
            top: 0,
            zIndex: 20,
            background: surface.chrome,
            display: "flex",
            alignItems: "center",
            gap: "10px",
            padding: "10px 20px",
          }}
        >
          {/* Breathing gold dot */}
          <motion.div
            animate={{ opacity: [0.5, 1, 0.5] }}
            transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
            style={{
              width: 6,
              height: 6,
              borderRadius: "50%",
              background: colors.gold,
              flexShrink: 0,
            }}
          />

          {/* Banner text */}
          <span
            style={{
              ...textTokens.label,
              color: ink.secondary,
              letterSpacing: "0.04em",
              textTransform: "lowercase",
            }}
          >
            consensus on {activeItem.title.toLowerCase()}. auto-locking soon.
          </span>

          {/* Gradient separator — replaces border */}
          <div
            style={{
              position: "absolute",
              bottom: 0,
              left: 0,
              right: 0,
              height: 1,
              background: `linear-gradient(90deg, transparent, ${colors.gold}, transparent)`,
              opacity: 0.25,
            }}
          />
        </motion.div>
      )}
    </AnimatePresence>
  );
}
