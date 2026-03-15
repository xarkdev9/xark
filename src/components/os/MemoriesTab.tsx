"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { text, ink, colors, timing } from "@/lib/theme";

interface SpaceMemory {
  spaceId: string;
  spaceTitle: string;
  photos: {
    id: string;
    url: string;
    caption: string | null;
    createdAt: string;
  }[];
  lastActivityAt: number;
}

interface MemoriesTabProps {
  userId: string;
}

// Demo memories for when Supabase is unreachable
function getDemoMemories(): SpaceMemory[] {
  return [
    {
      spaceId: "space_san-diego-trip",
      spaceTitle: "san diego trip",
      photos: [
        { id: "m1", url: "https://images.unsplash.com/photo-1538097304804-2a1b932466a9?w=400&h=400&fit=crop", caption: "coronado beach sunset", createdAt: "2025-08-20T18:30:00Z" },
        { id: "m2", url: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=300&h=300&fit=crop", caption: null, createdAt: "2025-08-19T14:00:00Z" },
        { id: "m3", url: "https://images.unsplash.com/photo-1502680390548-bdbac40e4a9f?w=300&h=300&fit=crop", caption: null, createdAt: "2025-08-18T10:00:00Z" },
      ],
      lastActivityAt: 1724000000000,
    },
    {
      spaceId: "space_bali-retreat",
      spaceTitle: "bali retreat",
      photos: [
        { id: "m4", url: "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&h=400&fit=crop", caption: "rice terraces at sunrise", createdAt: "2024-12-15T06:00:00Z" },
        { id: "m5", url: "https://images.unsplash.com/photo-1555400038-63f5ba517a47?w=300&h=300&fit=crop", caption: null, createdAt: "2024-12-14T16:00:00Z" },
      ],
      lastActivityAt: 1716000000000,
    },
  ];
}

function formatGroupDate(spaceTitle: string, iso: string): string {
  const d = new Date(iso);
  const month = d.toLocaleDateString(undefined, { month: "short" });
  const year = d.getFullYear();
  return `${spaceTitle} · ${month} ${year}`;
}

export function MemoriesTab({ userId }: MemoriesTabProps) {
  const [memories, setMemories] = useState<SpaceMemory[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchMemories() {
      try {
        // Get all spaces the user is a member of
        const { data: memberData } = await supabase
          .from("space_members")
          .select("space_id")
          .eq("user_id", userId);

        if (!memberData || memberData.length === 0) {
          setMemories(getDemoMemories());
          setLoading(false);
          return;
        }

        const spaceIds = memberData.map((m) => m.space_id);

        // Get space titles
        const { data: spacesData } = await supabase
          .from("spaces")
          .select("id, title")
          .in("id", spaceIds);

        const titleMap = new Map((spacesData ?? []).map((s) => [s.id, s.title]));

        // Get media for all spaces
        const { data: mediaData } = await supabase
          .from("media")
          .select("id, space_id, storage_url, caption, created_at")
          .in("space_id", spaceIds)
          .order("created_at", { ascending: false })
          .limit(100);

        if (!mediaData || mediaData.length === 0) {
          setMemories(getDemoMemories());
          setLoading(false);
          return;
        }

        // Group by space
        const grouped: Record<string, SpaceMemory> = {};
        for (const item of mediaData) {
          if (!grouped[item.space_id]) {
            grouped[item.space_id] = {
              spaceId: item.space_id,
              spaceTitle: titleMap.get(item.space_id) ?? item.space_id.replace(/^space_/, "").replace(/-/g, " "),
              photos: [],
              lastActivityAt: new Date(item.created_at).getTime(),
            };
          }
          grouped[item.space_id].photos.push({
            id: item.id,
            url: item.storage_url,
            caption: item.caption,
            createdAt: item.created_at,
          });
        }

        const sorted = Object.values(grouped).sort((a, b) => b.lastActivityAt - a.lastActivityAt);
        setMemories(sorted.length > 0 ? sorted : getDemoMemories());
      } catch {
        setMemories(getDemoMemories());
      }
      setLoading(false);
    }

    fetchMemories();
  }, [userId]);

  if (loading) {
    return (
      <div className="px-6 py-8">
        <p style={{ ...text.recency, color: ink.tertiary }}>loading memories...</p>
      </div>
    );
  }

  if (memories.length === 0) {
    return (
      <div className="px-6 py-12">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3, duration: 0.8 }}
        >
          <p style={{ ...text.subtitle, color: ink.secondary }}>
            no memories yet
          </p>
          <p style={{ ...text.recency, color: ink.tertiary, marginTop: "8px" }}>
            photos from your trips appear here after you go.
          </p>
        </motion.div>
      </div>
    );
  }

  return (
    <div style={{ paddingBottom: "40px" }}>
      {memories.map((space, sectionIdx) => (
        <motion.div
          key={space.spaceId}
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: sectionIdx * 0.15, duration: 0.5, ease: [0.22, 1, 0.36, 1] as const }}
          style={{
            marginBottom: "28px",
            opacity: sectionIdx > 1 ? 0.7 : 1,
          }}
        >
          {/* Section label */}
          <div style={{ padding: "0 20px", marginBottom: "10px" }}>
            <span style={{ ...text.recency, color: ink.tertiary }}>
              {formatGroupDate(space.spaceTitle, space.photos[0]?.createdAt ?? new Date().toISOString())}
            </span>
          </div>

          {/* Photo grid — hero + small tiles */}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "2fr 1fr",
              gridTemplateRows: "1fr 1fr",
              gap: "3px",
              padding: "0 12px",
            }}
          >
            {/* Hero photo — spans 2 rows */}
            {space.photos[0] && (
              <div
                style={{
                  gridRow: "1 / 3",
                  position: "relative",
                  overflow: "hidden",
                  borderRadius: "14px 0 0 14px",
                  cursor: "pointer",
                  minHeight: "200px",
                }}
              >
                <img
                  src={space.photos[0].url}
                  alt={space.photos[0].caption ?? ""}
                  loading={sectionIdx > 0 ? "lazy" : "eager"}
                  style={{ width: "100%", height: "100%", objectFit: "cover" }}
                />
                {space.photos[0].caption && (
                  <div
                    style={{
                      position: "absolute", bottom: 0, left: 0, right: 0,
                      padding: "8px 10px",
                      background: "linear-gradient(to top, rgba(0,0,0,0.5) 0%, transparent 100%)",
                    }}
                  >
                    <span style={{ fontSize: "11px", fontWeight: 300, color: "#fff", opacity: 0.8 }}>
                      {space.photos[0].caption}
                    </span>
                  </div>
                )}
              </div>
            )}

            {/* Top-right tile */}
            {space.photos[1] ? (
              <div
                style={{
                  position: "relative",
                  overflow: "hidden",
                  borderRadius: "0 14px 0 0",
                  cursor: "pointer",
                }}
              >
                <img
                  src={space.photos[1].url}
                  alt={space.photos[1].caption ?? ""}
                  loading="lazy"
                  style={{ width: "100%", height: "100%", objectFit: "cover" }}
                />
              </div>
            ) : (
              <div style={{ background: "rgba(0,0,0,0.03)", borderRadius: "0 14px 0 0" }} />
            )}

            {/* Bottom-right tile */}
            {space.photos[2] ? (
              <div
                style={{
                  position: "relative",
                  overflow: "hidden",
                  borderRadius: "0 0 14px 0",
                  cursor: "pointer",
                }}
              >
                <img
                  src={space.photos[2].url}
                  alt={space.photos[2].caption ?? ""}
                  loading="lazy"
                  style={{ width: "100%", height: "100%", objectFit: "cover" }}
                />
                {/* "+N more" overlay if more photos exist */}
                {space.photos.length > 3 && (
                  <div
                    style={{
                      position: "absolute", inset: 0,
                      background: "rgba(0,0,0,0.4)",
                      display: "flex", alignItems: "center", justifyContent: "center",
                    }}
                  >
                    <span style={{ fontSize: "14px", fontWeight: 400, color: "#fff", opacity: 0.9 }}>
                      +{space.photos.length - 3}
                    </span>
                  </div>
                )}
              </div>
            ) : (
              <div style={{ background: "rgba(0,0,0,0.03)", borderRadius: "0 0 14px 0" }} />
            )}
          </div>
        </motion.div>
      ))}

      {/* Gentle prompt */}
      <div style={{ padding: "16px 20px" }}>
        <p style={{ ...text.recency, color: ink.tertiary }}>
          photos from your trips appear here after you go.
        </p>
      </div>
    </div>
  );
}
