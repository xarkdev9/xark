"use client";

import { useState } from "react";
import { TravelBlock } from "./TravelBlock";
import { SlotAlternatives } from "./SlotAlternatives";

// ── Types ──

interface SlotData {
  date: string;
  time: string;
  type: string;
  label: string;
  query?: string;
  title?: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  bookingUrl?: string;
  rating?: number;
  source?: string;
  recentReview?: string;
  note?: string;
  // Travel block
  durationMinutes?: number;
  mode?: string;
  mapsUrl?: string;
  fromLocation?: string;
  toLocation?: string;
  // Alternatives
  alternatives?: Array<{
    title: string;
    price?: string;
    imageUrl?: string;
    description?: string;
    externalUrl?: string;
    rating?: number;
    source?: string;
  }>;
}

interface TimelineDayProps {
  date: string; // "2026-06-10" or "Day 1"
  label: string; // "Arrival Day"
  slots: SlotData[];
  isExpanded?: boolean;
  onSlotVote?: (slotIndex: number, reaction: string) => void;
}

// ── Time slot color/icon ──

const TIME_STYLES: Record<string, { color: string; icon: React.ReactNode }> = {
  morning: {
    color: "var(--hello-amber)",
    icon: (
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
        <circle cx="12" cy="12" r="4" /><path d="M12 2v2m0 16v2M4.93 4.93l1.41 1.41m11.32 11.32l1.41 1.41M2 12h2m16 0h2M4.93 19.07l1.41-1.41m11.32-11.32l1.41-1.41" />
      </svg>
    ),
  },
  afternoon: {
    color: "var(--hello-orange)",
    icon: (
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
        <circle cx="12" cy="12" r="5" /><path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2" />
      </svg>
    ),
  },
  evening: {
    color: "var(--hello-accent)",
    icon: (
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
        <path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z" />
      </svg>
    ),
  },
};

// ── Component ──

export function TimelineDay({ date, label, slots, isExpanded: defaultExpanded = true, onSlotVote }: TimelineDayProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  // Parse date for display
  const isRealDate = /^\d{4}-\d{2}-\d{2}$/.test(date);
  const displayDate = isRealDate
    ? new Date(date + "T12:00:00").toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })
    : date; // "Day 1", "Day 2" etc.

  const nonTravelSlots = slots.filter((s) => s.type !== "travel");

  return (
    <div style={{ marginBottom: 20 }}>
      {/* Day header — collapsible */}
      <button
        onClick={() => setExpanded(!expanded)}
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          width: "100%",
          padding: "8px 0",
          border: "none",
          background: "transparent",
          cursor: "pointer",
          fontFamily: "inherit",
          textAlign: "left",
        }}
      >
        {/* Expand/collapse chevron */}
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="var(--hello-ink-tertiary)"
          strokeWidth="2"
          style={{
            transform: expanded ? "rotate(90deg)" : "rotate(0)",
            transition: "transform 0.15s ease",
            flexShrink: 0,
          }}
        >
          <polyline points="9 6 15 12 9 18" />
        </svg>

        {/* Date + label */}
        <div>
          <div style={{ fontSize: 14, fontWeight: 400, color: "var(--hello-ink-primary)" }}>
            {displayDate}
          </div>
          <div style={{ fontSize: 11, fontWeight: 300, color: "var(--hello-ink-tertiary)", marginTop: 1 }}>
            {label} · {nonTravelSlots.length} spot{nonTravelSlots.length !== 1 ? "s" : ""}
          </div>
        </div>
      </button>

      {/* Slots */}
      {expanded && (
        <div style={{ paddingLeft: 8, borderLeft: "1px solid rgba(255,255,255,0.06)" }}>
          {slots.map((slot, idx) => {
            // Travel blocks render as TravelBlock
            if (slot.type === "travel") {
              return (
                <TravelBlock
                  key={`travel-${idx}`}
                  durationMinutes={slot.durationMinutes || 0}
                  mode={(slot.mode || "drive") as "drive" | "walk" | "transit"}
                  fromLocation={slot.fromLocation || ""}
                  toLocation={slot.toLocation || ""}
                  mapsUrl={slot.mapsUrl || "#"}
                  note={slot.note}
                />
              );
            }

            const timeStyle = TIME_STYLES[slot.time] || TIME_STYLES.morning;

            return (
              <div key={`slot-${idx}`} style={{ marginBottom: 8 }}>
                {/* Slot card */}
                <div
                  style={{
                    display: "flex",
                    gap: 10,
                    padding: "10px 12px",
                    borderRadius: 12,
                    background: "var(--hello-surface-chrome)",
                    border: "1px solid rgba(255,255,255,0.06)",
                    transition: "border-color 0.15s ease",
                  }}
                >
                  {/* Time indicator */}
                  <div
                    style={{
                      display: "flex",
                      flexDirection: "column",
                      alignItems: "center",
                      gap: 2,
                      paddingTop: 2,
                      color: timeStyle.color,
                      flexShrink: 0,
                      width: 40,
                    }}
                  >
                    {timeStyle.icon}
                    <span style={{ fontSize: 9, fontWeight: 400, textTransform: "capitalize" }}>
                      {slot.time}
                    </span>
                  </div>

                  {/* Image thumbnail */}
                  {slot.imageUrl ? (
                    <img
                      src={slot.imageUrl}
                      alt=""
                      width={48}
                      height={48}
                      style={{
                        borderRadius: 8,
                        objectFit: "cover",
                        flexShrink: 0,
                        background: "rgba(255,255,255,0.04)",
                      }}
                    />
                  ) : null}

                  {/* Content */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      style={{
                        fontSize: 13,
                        fontWeight: 400,
                        color: "var(--hello-ink-primary)",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {slot.title || slot.query}
                    </div>

                    {slot.description ? (
                      <div
                        style={{
                          fontSize: 11,
                          fontWeight: 300,
                          color: "var(--hello-ink-secondary)",
                          marginTop: 2,
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                        }}
                      >
                        {slot.description}
                      </div>
                    ) : null}

                    {/* Price + rating + verified */}
                    <div style={{ display: "flex", gap: 6, alignItems: "center", marginTop: 3 }}>
                      {slot.price ? (
                        <span style={{ fontSize: 11, fontWeight: 400, color: "var(--hello-ink-primary)" }}>
                          {slot.price}
                        </span>
                      ) : null}
                      {slot.rating ? (
                        <span style={{ fontSize: 10, color: "var(--hello-ink-tertiary)", fontWeight: 300 }}>
                          {slot.rating}★
                        </span>
                      ) : null}
                      {slot.recentReview ? (
                        <span style={{ fontSize: 9, color: "var(--hello-green, #22C55E)", fontWeight: 400 }}>
                          Verified Recent
                        </span>
                      ) : null}
                    </div>

                    {/* Recent review snippet */}
                    {slot.recentReview ? (
                      <div style={{ fontSize: 10, color: "var(--hello-ink-tertiary)", fontWeight: 300, fontStyle: "italic", marginTop: 2 }}>
                        "{slot.recentReview}"
                      </div>
                    ) : null}
                  </div>

                  {/* Booking link */}
                  {(slot.bookingUrl || slot.externalUrl) ? (
                    <a
                      href={slot.bookingUrl || slot.externalUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      onClick={(e) => e.stopPropagation()}
                      style={{
                        alignSelf: "center",
                        padding: "4px 10px",
                        borderRadius: 12,
                        background: "var(--hello-accent)",
                        color: "white",
                        fontSize: 10,
                        fontWeight: 400,
                        textDecoration: "none",
                        flexShrink: 0,
                      }}
                    >
                      Book
                    </a>
                  ) : null}
                </div>

                {/* Alternatives (collapsed overflow) */}
                {slot.alternatives && slot.alternatives.length > 0 ? (
                  <SlotAlternatives alternatives={slot.alternatives} />
                ) : null}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
