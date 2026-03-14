"use client";

import { useState, useEffect, useRef, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useRouter, useSearchParams, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";
import {
  fetchSpaceList,
  recencyLabel,
  recencyOpacity,
  decisionStateLabel,
  DEMO_SPACES,
} from "@/lib/space-data";
import type { SpaceListItem } from "@/lib/space-data";
import { colors, opacity, timing, layout, text, textColor } from "@/lib/theme";
import { useAuth } from "@/hooks/useAuth";
import { Avatar } from "@/components/os/Avatar";

// ── Search icon ──
function SearchIcon({ color, size = 18 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

// ── Demo presence ──
const DEMO_PRESENCE: Record<string, number> = {
  "space_san-diego-trip": 2,
  "space_ananya": 1,
};

export function ControlCaret() {
  const [isOpen, setIsOpen] = useState(false);
  const [spaces, setSpaces] = useState<SpaceListItem[]>([]);
  const [presence, setPresence] = useState<Record<string, number>>(DEMO_PRESENCE);
  const [searchQuery, setSearchQuery] = useState("");
  const searchRef = useRef<HTMLInputElement>(null);
  const router = useRouter();
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const userName = searchParams.get("name") ?? "";
  const { user } = useAuth(userName || undefined);
  const isInsideSpace = pathname.startsWith("/space/");

  useEffect(() => {
    const userId = user?.uid;
    fetchSpaceList(userId).then(setSpaces).catch(() => setSpaces(DEMO_SPACES));
  }, [user]);

  // ── Supabase Realtime Presence ──
  useEffect(() => {
    if (spaces.length === 0) return;

    const channels: ReturnType<typeof supabase.channel>[] = [];

    for (const space of spaces) {
      const channel = supabase.channel(`presence:${space.id}`, {
        config: { presence: { key: userName || "anonymous" } },
      });

      channel
        .on("presence", { event: "sync" }, () => {
          const state = channel.presenceState();
          const count = Object.keys(state).length;
          setPresence((prev) => ({ ...prev, [space.id]: count }));
        })
        .subscribe(async (status) => {
          if (status === "SUBSCRIBED") {
            await channel.track({ user: userName, online_at: new Date().toISOString() });
          }
        });

      channels.push(channel);
    }

    return () => {
      channels.forEach((ch) => supabase.removeChannel(ch));
    };
  }, [spaces, userName]);

  // ── Filtered spaces ──
  const filteredSpaces = useMemo(() => {
    if (!searchQuery.trim()) return spaces;
    const q = searchQuery.toLowerCase();
    return spaces.filter((s) =>
      s.title.toLowerCase().includes(q) ||
      s.members.some((m) => m.displayName.toLowerCase().includes(q))
    );
  }, [spaces, searchQuery]);

  // Focus search when panel opens
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => searchRef.current?.focus(), 400);
    } else {
      setSearchQuery("");
    }
  }, [isOpen]);

  function navigateToSpace(spaceId: string) {
    setIsOpen(false);
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
  }

  return (
    <>
      {/* ── The Dot ── */}
      <div
        className="fixed left-1/2 z-50"
        style={{ bottom: layout.caretBottom, transform: "translateX(-50%)" }}
      >
        <div
          role="button"
          tabIndex={0}
          onClick={() => {
            if (isInsideSpace) {
              router.push(`/galaxy?name=${encodeURIComponent(userName)}`);
            } else {
              setIsOpen((prev) => !prev);
            }
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              if (isInsideSpace) {
                router.push(`/galaxy?name=${encodeURIComponent(userName)}`);
              } else {
                setIsOpen((prev) => !prev);
              }
            }
          }}
          className="cursor-pointer outline-none"
        >
          <div
            style={{
              width: layout.caretSize,
              height: layout.caretSize,
              borderRadius: "50%",
              backgroundColor: colors.cyan,
              animation: isOpen ? "none" : `ambientBreath ${timing.breath} ease-in-out infinite`,
              opacity: isOpen ? 1 : undefined,
              transition: "opacity 0.3s ease",
            }}
          />
        </div>
      </div>

      {/* ── Galaxy Slide-Up ── */}
      <AnimatePresence>
        {isOpen && (
          <>
            {/* Overlay */}
            <motion.div
              className="fixed inset-0 z-40"
              style={{ background: colors.overlay }}
              initial={{ opacity: 0 }}
              animate={{ opacity: opacity.overlay }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
              onClick={() => setIsOpen(false)}
            />

            {/* Space list + search */}
            <motion.div
              className="fixed inset-x-0 bottom-0 z-45 flex flex-col overflow-hidden"
              style={{ zIndex: 45, maxHeight: "80vh", background: colors.void }}
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
            >
              {/* ── Scrollable space list ── */}
              <div className="flex-1 overflow-y-auto px-6 pt-8 pb-4">
                <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
                  {filteredSpaces.map((space, index) => {
                    const isSanctuary = space.atmosphere === "sanctuary";
                    const hasPresenceEmber = (presence[space.id] ?? 0) > 1;
                    const spaceOpacity = recencyOpacity(space.lastActivityAt);
                    const memberNames = space.members.map((m) => m.displayName).join(", ");
                    const stateLabel = isSanctuary
                      ? space.lastMessage?.content
                      : decisionStateLabel(space.decisionSummary);

                    return (
                      <motion.div
                        key={space.id}
                        role="button"
                        tabIndex={0}
                        onClick={() => navigateToSpace(space.id)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") navigateToSpace(space.id);
                        }}
                        className="cursor-pointer outline-none"
                        style={{ paddingBottom: "20px" }}
                        initial={{ opacity: 0, y: 16 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{
                          delay: index * timing.staggerDelay,
                          duration: 0.4,
                          ease: [0.22, 1, 0.36, 1],
                        }}
                      >
                        <div className="flex items-center gap-3">
                          {/* ── Avatar ── */}
                          <div className="relative">
                            {isSanctuary && space.members[0] ? (
                              <Avatar
                                name={space.members[0].displayName}
                                photoUrl={space.members[0].photoUrl}
                                size={36}
                              />
                            ) : (
                              <Avatar name={space.title} size={36} />
                            )}

                            {/* ── Presence Ember ── */}
                            {hasPresenceEmber && (
                              <div
                                style={{
                                  position: "absolute",
                                  bottom: -1,
                                  right: -1,
                                  width: layout.emberSize,
                                  height: layout.emberSize,
                                  borderRadius: "50%",
                                  backgroundColor: colors.cyan,
                                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                                }}
                              />
                            )}
                          </div>

                          {/* ── Text stack ── */}
                          <div className="min-w-0 flex-1">
                            <div className="flex items-baseline justify-between gap-3">
                              {/* Name — body size, high opacity (WhatsApp hierarchy) */}
                              <span
                                style={{
                                  ...text.listTitle,
                                  color: colors.white,
                                  opacity: spaceOpacity,
                                }}
                              >
                                {space.title}
                              </span>

                              <span
                                className="shrink-0"
                                style={{
                                  ...text.recency,
                                  color: textColor(opacity.quaternary),
                                }}
                              >
                                {recencyLabel(space.lastActivityAt)}
                              </span>
                            </div>

                            {/* Subtitle: member names + decision state */}
                            {(() => {
                              const parts: string[] = [];
                              if (!isSanctuary && memberNames) parts.push(memberNames);
                              if (stateLabel) parts.push(stateLabel);
                              const subtitle = parts.join(" · ");
                              return subtitle ? (
                                <p
                                  className="mt-0.5 truncate"
                                  style={{
                                    ...text.recency,
                                    color: textColor(0.3),
                                  }}
                                >
                                  {subtitle}
                                </p>
                              ) : null;
                            })()}
                          </div>
                        </div>
                      </motion.div>
                    );
                  })}

                  {/* ── No results ── */}
                  {searchQuery && filteredSpaces.length === 0 && (
                    <p style={{ ...text.subtitle, color: textColor(0.3) }}>
                      no matches for &ldquo;{searchQuery}&rdquo;
                    </p>
                  )}

                  {/* ── Initiation Seed ── */}
                  {!searchQuery && (
                    <motion.div
                      role="button"
                      tabIndex={0}
                      onClick={() => {
                        setIsOpen(false);
                        router.push(`/galaxy?name=${encodeURIComponent(userName)}`);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          setIsOpen(false);
                          router.push(`/galaxy?name=${encodeURIComponent(userName)}`);
                        }
                      }}
                      className="cursor-pointer pt-2 outline-none"
                      initial={{ opacity: 0, y: 16 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{
                        delay: spaces.length * timing.staggerDelay + 0.1,
                        duration: 0.4,
                        ease: [0.22, 1, 0.36, 1],
                      }}
                    >
                      <span
                        style={{
                          ...text.subtitle,
                          color: colors.white,
                          opacity: opacity.tertiary,
                        }}
                      >
                        invite a person
                      </span>
                    </motion.div>
                  )}
                </div>
              </div>

              {/* ═══ SEARCH BAR — at bottom, in thumb zone ═══ */}
              <div
                className="px-6 pb-20 pt-3"
                style={{ background: colors.void }}
              >
                <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
                  <div
                    style={{
                      height: "1px",
                      background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                      opacity: 0.1,
                      marginBottom: "10px",
                    }}
                  />
                  <div className="flex items-center gap-3">
                    <SearchIcon color={textColor(0.3)} />
                    <input
                      ref={searchRef}
                      type="text"
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      placeholder="search spaces or people"
                      spellCheck={false}
                      autoComplete="off"
                      className="w-full bg-transparent outline-none"
                      style={{
                        ...text.input,
                        color: colors.white,
                        caretColor: colors.cyan,
                      }}
                    />
                  </div>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <style jsx>{`
        input::placeholder {
          color: ${colors.white};
          opacity: 0.15;
          letter-spacing: 0.04em;
        }
      `}</style>
    </>
  );
}
