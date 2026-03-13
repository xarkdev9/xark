"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { ItineraryView } from "./ItineraryView";
import { colors, text, textColor, timing } from "@/lib/theme";

// ── Photo from Supabase ──
interface MemoryPhoto {
  id: string;
  url: string;
  caption: string | null;
  taken_at: string;
  uploaded_by: string | null;
}

interface MemoriesViewProps {
  spaceId: string;
}

type MemoriesMode = "memories" | "details";

function formatDateGroup(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
}

export function MemoriesView({ spaceId }: MemoriesViewProps) {
  const [photos, setPhotos] = useState<MemoryPhoto[]>([]);
  const [loading, setLoading] = useState(true);
  const [mode, setMode] = useState<MemoriesMode>("memories");
  const scrollRef = useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [dragStartX, setDragStartX] = useState(0);
  const [dragScrollLeft, setDragScrollLeft] = useState(0);

  useEffect(() => {
    async function fetchPhotos() {
      try {
        const { data } = await supabase
          .from("media")
          .select("id, url, caption, taken_at, uploaded_by")
          .eq("space_id", spaceId)
          .eq("type", "photo")
          .order("taken_at", { ascending: true });

        if (data) setPhotos(data as MemoryPhoto[]);
      } catch {
        // Silent — empty state handles this
      }
      setLoading(false);
    }

    fetchPhotos();
  }, [spaceId]);

  // ── Pointer-based drag for horizontal scroll ──
  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    if (!scrollRef.current) return;
    setIsDragging(true);
    setDragStartX(e.clientX);
    setDragScrollLeft(scrollRef.current.scrollLeft);
    scrollRef.current.setPointerCapture(e.pointerId);
  }, []);

  const handlePointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!isDragging || !scrollRef.current) return;
      const dx = e.clientX - dragStartX;
      scrollRef.current.scrollLeft = dragScrollLeft - dx;
    },
    [isDragging, dragStartX, dragScrollLeft]
  );

  const handlePointerUp = useCallback(() => {
    setIsDragging(false);
  }, []);

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
      </div>
    );
  }

  // Group photos by date
  const grouped = photos.reduce<Record<string, MemoryPhoto[]>>((acc, photo) => {
    const dateKey = photo.taken_at.split("T")[0] || "unknown";
    if (!acc[dateKey]) acc[dateKey] = [];
    acc[dateKey].push(photo);
    return acc;
  }, {});

  const dateKeys = Object.keys(grouped).sort();

  return (
    <div className="relative pt-32 pb-24">
      {/* ── Memories / Details toggle ── */}
      <div className="px-6">
        <div className="mx-auto flex items-center gap-6" style={{ maxWidth: "640px" }}>
          <span
            role="button"
            tabIndex={0}
            onClick={() => setMode("memories")}
            onKeyDown={(e) => {
              if (e.key === "Enter") setMode("memories");
            }}
            className="outline-none"
            style={{
              ...text.label,
              color: mode === "memories" ? colors.cyan : colors.white,
              opacity: mode === "memories" ? 0.9 : 0.4,
              cursor: "pointer",
              transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
            }}
          >
            memories
          </span>
          <span
            role="button"
            tabIndex={0}
            onClick={() => setMode("details")}
            onKeyDown={(e) => {
              if (e.key === "Enter") setMode("details");
            }}
            className="outline-none"
            style={{
              ...text.label,
              color: mode === "details" ? colors.cyan : colors.white,
              opacity: mode === "details" ? 0.9 : 0.4,
              cursor: "pointer",
              transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
            }}
          >
            details
          </span>
        </div>
      </div>

      {/* ── Details mode: ItineraryView ── */}
      {mode === "details" && <ItineraryView spaceId={spaceId} />}

      {/* ── Memories mode: photo stream ── */}
      {mode === "memories" && (
        <>
          {photos.length === 0 ? (
            <div
              className="flex items-center justify-center pt-24"
              style={{ opacity: 0.2 }}
            >
              <p style={{ ...text.label, color: textColor(0.5) }}>
                no photos yet
              </p>
            </div>
          ) : (
            <div className="mt-8">
              {dateKeys.map((dateKey, groupIndex) => {
                const groupPhotos = grouped[dateKey];
                const dateLabel = formatDateGroup(dateKey);

                return (
                  <motion.div
                    key={dateKey}
                    className="mb-12"
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{
                      duration: 0.5,
                      delay: groupIndex * 0.1,
                      ease: "easeOut",
                    }}
                  >
                    {/* ── Date label ── */}
                    <p
                      className="mb-4 px-6"
                      style={{
                        ...text.recency,
                        color: textColor(0.3),
                        textTransform: "uppercase",
                      }}
                    >
                      {dateLabel}
                    </p>

                    {/* ── Horizontal photo scroll ── */}
                    <div
                      ref={groupIndex === 0 ? scrollRef : undefined}
                      onPointerDown={handlePointerDown}
                      onPointerMove={handlePointerMove}
                      onPointerUp={handlePointerUp}
                      onPointerCancel={handlePointerUp}
                      className="memories-scroll flex snap-x snap-mandatory gap-3 overflow-x-auto px-6"
                      style={{
                        cursor: isDragging ? "grabbing" : "grab",
                        WebkitOverflowScrolling: "touch",
                      }}
                    >
                      <AnimatePresence>
                        {groupPhotos.map((photo, photoIndex) => (
                          <motion.div
                            key={photo.id}
                            className="relative flex-shrink-0 snap-center"
                            style={{
                              width: "80vw",
                              maxWidth: "420px",
                              aspectRatio: "4 / 5",
                            }}
                            initial={{ opacity: 0, scale: 0.98 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{
                              duration: 0.4,
                              delay: photoIndex * timing.staggerDelay,
                            }}
                          >
                            {/* ── Edge-to-edge image ── */}
                            <div
                              className="absolute inset-0"
                              style={{
                                backgroundImage: `url(${photo.url})`,
                                backgroundSize: "cover",
                                backgroundPosition: "center",
                              }}
                            />

                            {/* ── Bottom vignette ── */}
                            <div
                              className="absolute inset-0"
                              style={{
                                background:
                                  "linear-gradient(to top, rgba(var(--xark-void-rgb), 0.85) 0%, rgba(var(--xark-void-rgb), 0.3) 30%, transparent 60%)",
                              }}
                            />

                            {/* ── Caption overlay ── */}
                            {photo.caption && (
                              <div className="absolute inset-x-0 bottom-0 px-5 pb-5">
                                <p
                                  style={{
                                    ...text.body,
                                    color: textColor(0.7),
                                    lineHeight: 1.5,
                                  }}
                                >
                                  {photo.caption}
                                </p>
                              </div>
                            )}
                          </motion.div>
                        ))}
                      </AnimatePresence>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          )}
        </>
      )}

      <style jsx>{`
        .memories-scroll::-webkit-scrollbar {
          display: none;
        }
        .memories-scroll {
          scrollbar-width: none;
          -ms-overflow-style: none;
        }
      `}</style>
    </div>
  );
}
