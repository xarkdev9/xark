"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { ConsensusMark } from "./ConsensusMark";
import { colors, text, textColor, timing } from "@/lib/theme";

// ── Committed item from Supabase ──
interface CommittedItem {
  id: string;
  title: string;
  category: string;
  state: string;
  weighted_score: number;
  agreement_score: number;
  metadata: {
    date?: string;
    check_in?: string;
    check_out?: string;
    price?: string;
    source?: string;
    image_url?: string;
  } | null;
  ownership: {
    ownerId: string;
    displayName?: string;
  } | null;
  locked_at: string | null;
}

interface ItineraryViewProps {
  spaceId: string;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

export function ItineraryView({ spaceId }: ItineraryViewProps) {
  const [items, setItems] = useState<CommittedItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchCommitted() {
      const { data } = await supabase
        .from("decision_items")
        .select(
          "id, title, category, state, weighted_score, agreement_score, metadata, ownership, locked_at"
        )
        .eq("space_id", spaceId)
        .in("state", ["purchased", "locked", "claimed", "chosen", "decided"])
        .order("locked_at", { ascending: true });

      if (data) {
        // Sort by date when available, fall back to locked_at
        const sorted = (data as CommittedItem[]).sort((a, b) => {
          const dateA = a.metadata?.check_in || a.metadata?.date || a.locked_at || "";
          const dateB = b.metadata?.check_in || b.metadata?.date || b.locked_at || "";
          return dateA.localeCompare(dateB);
        });
        setItems(sorted);
      }
      setLoading(false);
    }

    fetchCommitted();
  }, [spaceId]);

  if (loading) {
    return (
      <div
        className="flex items-center justify-center pt-32"
        style={{ opacity: 0.2 }}
      >
        <div
          style={{
            width: "6px",
            height: "6px",
            borderRadius: "50%",
            backgroundColor: colors.cyan,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
          }}
        />
        <p className="ml-4" style={{ ...text.label, color: textColor(0.4) }}>
          loading itinerary
        </p>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div
        className="flex items-center justify-center pt-32"
        style={{ opacity: 0.2 }}
      >
        <p style={{ ...text.label, color: textColor(0.5) }}>
          no confirmed plans yet
        </p>
      </div>
    );
  }

  // Group items by date for visual grouping
  let lastDateLabel = "";

  return (
    <div className="relative px-6 pt-32 pb-24">
      <div className="relative mx-auto" style={{ maxWidth: "640px" }}>
        {/* ── 1px vertical timeline — atmospheric anchor ── */}
        <div
          className="absolute top-0 left-3 h-full"
          style={{
            width: "1px",
            backgroundColor: colors.white,
            opacity: 0.1,
          }}
        />

        {items.map((item, index) => {
          const dateStr = item.metadata?.check_in || item.metadata?.date;
          const dateLabel = dateStr ? formatDate(dateStr) : "";
          const showDate = dateLabel && dateLabel !== lastDateLabel;
          if (showDate) lastDateLabel = dateLabel;

          const price = item.metadata?.price;
          const ownerName = item.ownership?.displayName || item.ownership?.ownerId;

          return (
            <motion.div
              key={item.id}
              className="relative pl-10 pb-12"
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: 0.5,
                delay: index * timing.staggerDelay,
                ease: "easeOut",
              }}
            >
              {/* ── Timeline node ── */}
              <div
                className="absolute left-1.5 top-1"
                style={{
                  width: "4px",
                  height: "4px",
                  borderRadius: "50%",
                  backgroundColor: colors.white,
                  opacity: 0.3,
                }}
              />

              {/* ── Date label — only on first item of each date ── */}
              {showDate && (
                <p
                  className="mb-3"
                  style={{
                    ...text.recency,
                    color: textColor(0.35),
                    textTransform: "uppercase",
                  }}
                >
                  {dateLabel}
                </p>
              )}

              {/* ── Content row: ConsensusMark + title + metadata ── */}
              <div className="flex items-start gap-3">
                <ConsensusMark agreementScore={1} state="ignited" size={20} />

                <div className="flex-1">
                  {/* ── Category ── */}
                  {item.category && (
                    <p
                      style={{
                        ...text.recency,
                        color: textColor(0.25),
                        textTransform: "uppercase",
                        marginBottom: "4px",
                      }}
                    >
                      {item.category}
                    </p>
                  )}

                  {/* ── Title ── */}
                  <p style={{ ...text.listTitle, color: textColor(0.9) }}>
                    {item.title}
                  </p>

                  {/* ── Cost + owner ── */}
                  <div className="mt-1 flex items-center gap-4">
                    {price && (
                      <span style={{ ...text.subtitle, color: textColor(0.4) }}>
                        {price}
                      </span>
                    )}
                    {ownerName && (
                      <span style={{ ...text.subtitle, color: textColor(0.25) }}>
                        {ownerName}
                      </span>
                    )}
                  </div>

                  {/* ── Check-in / check-out range ── */}
                  {item.metadata?.check_in && item.metadata?.check_out && (
                    <p
                      className="mt-1"
                      style={{ ...text.recency, color: textColor(0.2) }}
                    >
                      {formatDate(item.metadata.check_in)} — {formatDate(item.metadata.check_out)}
                    </p>
                  )}
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
