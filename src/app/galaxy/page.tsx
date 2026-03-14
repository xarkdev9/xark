"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { motion } from "framer-motion";
import { createSpace, getOptimisticSpaceId } from "@/lib/spaces";
import {
  fetchAwareness,
  awarenessOpacity,
  getDemoAwareness,
  summaryText,
} from "@/lib/awareness";
import type { SpaceAwareness } from "@/lib/awareness";
import { recencyLabel } from "@/lib/space-data";
import { supabase } from "@/lib/supabase";
import { colors, opacity, timing, layout, text, textColor } from "@/lib/theme";
import { useAuth } from "@/hooks/useAuth";
import { Avatar } from "@/components/os/Avatar";
import { Whisper, dismissOnboardingWhisper } from "@/components/os/OnboardingWhispers";
import { VideoBackground } from "@/components/os/VideoBackground";
import { useThemeContext } from "@/components/os/ThemeProvider";

// ── People icon for contact picker trigger ──
function PeopleIcon({ color, size = 20 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4-4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 00-3-3.87" />
      <path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  );
}

function GalaxyContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const userName = searchParams.get("name") ?? "";
  const { user } = useAuth(userName || undefined);
  const { theme } = useThemeContext();
  const isVideoTheme = theme === "aurora" || theme === "coast";
  const videoSrc = theme === "aurora" ? "/themes/aurora-loop.mp4" : "/themes/coast-loop.mp4";
  const posterSrc = theme === "aurora" ? "/themes/aurora-poster.webp" : "/themes/coast-poster.webp";
  const [mounted, setMounted] = useState(false);
  const [spaces, setSpaces] = useState<SpaceAwareness[]>([]);
  const [dream, setDream] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);
  const [contactName, setContactName] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Fetch awareness on mount
  useEffect(() => {
    if (!user) return;
    fetchAwareness(user.uid)
      .then((result) => setSpaces(result.length > 0 ? result : getDemoAwareness()))
      .catch(() => setSpaces(getDemoAwareness()));
  }, [user]);

  // Real-time: refetch when user is added to a new space
  useEffect(() => {
    if (!user) return;
    const channel = supabase
      .channel(`galaxy:${user.uid}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "space_members",
          filter: `user_id=eq.${user.uid}`,
        },
        () => {
          // New membership detected — refetch
          fetchAwareness(user.uid)
            .then((result) => setSpaces(result.length > 0 ? result : getDemoAwareness()))
            .catch(() => {});
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [user]);

  const hasSpaces = spaces.length > 0;
  const allPeaceful = hasSpaces && spaces.every((s) => !s.actionNeeded);

  const recentActivity = spaces.some(
    (s) => Date.now() - s.lastActivityAt < 900_000
  );

  // ── Contact Picker API ──
  const pickContact = useCallback(async () => {
    if ("contacts" in navigator && "ContactsManager" in window) {
      try {
        const contacts = await (navigator as unknown as { contacts: { select: (props: string[], opts: { multiple: boolean }) => Promise<Array<{ name: string[]; tel?: string[] }>> } }).contacts.select(
          ["name", "tel"],
          { multiple: false }
        );
        if (contacts.length > 0) {
          const name = contacts[0].name?.[0] ?? "";
          if (name) {
            setContactName(name);
            setDream(`@${name} `);
            inputRef.current?.focus();
          }
        }
      } catch {
        // User cancelled or API failed
      }
    } else {
      setDream("@");
      inputRef.current?.focus();
    }
  }, []);

  // ── Smart input: detect @ prefix ──
  const handleInputChange = useCallback((value: string) => {
    setDream(value);
    if (contactName && !value.startsWith(`@${contactName}`)) {
      setContactName(null);
    }
  }, [contactName]);

  const manifestDream = useCallback(async () => {
    const txt = dream.trim();
    if (!txt || isCreating) return;
    setIsCreating(true);

    dismissOnboardingWhisper("galaxy_input");

    // Detect @name from typed input (if contactName wasn't set by picker)
    let resolvedContact = contactName;
    if (!resolvedContact && txt.startsWith("@")) {
      const match = txt.match(/^@(\S+)/);
      if (match) resolvedContact = match[1];
    }

    const spaceTitle = resolvedContact
      ? txt.replace(`@${resolvedContact}`, "").trim() || `chat with ${resolvedContact}`
      : txt;

    const resolvedId = user?.uid ?? `name_${userName}`;
    const spaceId = getOptimisticSpaceId(spaceTitle);
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
    createSpace(spaceTitle, resolvedId, resolvedContact ?? undefined).catch(() => {});
  }, [dream, isCreating, router, userName, user, contactName]);

  const handleSpaceTap = useCallback((spaceId: string) => {
    dismissOnboardingWhisper("galaxy_tap");
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
  }, [router, userName]);

  return (
    <div className="relative flex min-h-svh flex-col">
      {/* ── Background: Video (aurora/coast) or Spectrum Wash (hearth) ── */}
      {isVideoTheme ? (
        <div className="fixed inset-0" style={{ zIndex: 0 }}>
          <VideoBackground videoSrc={videoSrc} posterSrc={posterSrc}>
            {/* Shelf gradient — solid ground for items */}
            <div
              className="absolute inset-0"
              style={{
                background: theme === "aurora"
                  ? "linear-gradient(180deg, transparent 0%, transparent 38%, rgba(4,8,16,0.5) 48%, rgba(4,8,16,0.9) 58%, #040810 68%)"
                  : "linear-gradient(180deg, transparent 0%, transparent 38%, rgba(240,232,218,0.5) 48%, rgba(240,232,218,0.9) 58%, #F0E8DA 68%)",
                zIndex: 2,
              }}
            />
          </VideoBackground>
        </div>
      ) : (
        <>
          {/* ── Spectrum Wash (hearth) ── */}
          <div
            className="pointer-events-none fixed inset-0"
            style={{
              background: [
                `radial-gradient(ellipse 70% 50% at 30% 30%, rgba(var(--xark-accent-rgb), ${opacity.meshCyan}) 0%, transparent 60%)`,
                `radial-gradient(ellipse 60% 40% at 70% 60%, rgba(var(--xark-amber-rgb), ${recentActivity ? 0.05 : opacity.meshAmber}) 0%, transparent 50%)`,
              ].join(", "),
            }}
          />
          {/* ── Mesh Pulse ── */}
          <div
            className="pointer-events-none fixed inset-0"
            style={{
              background: `radial-gradient(ellipse 80% 60% at 50% 40%, rgba(var(--xark-white-rgb), 0.03) 0%, transparent 100%)`,
              animation: `meshPulse ${timing.meshPulse} ease-in-out infinite`,
            }}
          />
        </>
      )}

      {/* ── Content ── */}
      <motion.div
        className="flex-1 overflow-y-auto px-6"
        style={{ paddingTop: "80px", paddingBottom: "140px" }}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.6 }}
      >
        <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
          {/* ── Peace state — everything is calm ── */}
          {allPeaceful && (
            <motion.p
              className="mb-8"
              style={{
                ...text.subtitle,
                color: textColor(0.35),
              }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3, duration: 0.8 }}
            >
              you're good. your trips are moving along.
            </motion.p>
          )}

          {/* ── Space Summaries ── */}
          {hasSpaces && (
            <div>
              {spaces.map((space, index) => {
                const spaceOpacity = awarenessOpacity(space.priority);
                const summary = summaryText(space);

                return (
                  <motion.div
                    key={space.spaceId}
                    role="button"
                    tabIndex={0}
                    onClick={() => handleSpaceTap(space.spaceId)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") handleSpaceTap(space.spaceId);
                    }}
                    className="cursor-pointer outline-none"
                    style={{ paddingBottom: "24px" }}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{
                      delay: 0.15 + index * timing.staggerDelay,
                      duration: 0.5,
                      ease: [0.22, 1, 0.36, 1],
                    }}
                  >
                    <div className="flex items-start gap-3">
                      {/* ── Space Avatar ── */}
                      <div style={{ marginTop: "2px" }}>
                        <Avatar
                          name={space.spaceTitle}
                          size={24}
                        />
                      </div>

                      <div className="min-w-0 flex-1">
                        {/* ── Space title ── */}
                        <p
                          style={{
                            ...text.listTitle,
                            color: colors.white,
                            opacity: spaceOpacity,
                          }}
                        >
                          {space.spaceTitle}
                        </p>

                        {/* ── Consensus summary ── */}
                        <p
                          className="mt-0.5"
                          style={{
                            ...text.recency,
                            color: space.actionNeeded
                              ? textColor(Math.min(0.5, spaceOpacity * 0.7))
                              : textColor(Math.min(0.3, spaceOpacity * 0.4)),
                          }}
                        >
                          {summary} · {recencyLabel(new Date(space.lastActivityAt))}
                        </p>
                      </div>
                    </div>
                  </motion.div>
                );
              })}

              {/* ── Onboarding whisper ── */}
              <Whisper whisperKey="galaxy_tap" delay={2.5}>
                tap any space to jump in
              </Whisper>
            </div>
          )}

          {/* ── Empty state — new user ── */}
          {!hasSpaces && mounted && (
            <motion.div
              className="mt-16"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5, duration: 0.8 }}
            >
              <p
                style={{
                  ...text.listTitle,
                  color: colors.white,
                  opacity: opacity.tertiary,
                }}
              >
                who are you planning with?
              </p>
            </motion.div>
          )}
        </div>
      </motion.div>

      {/* ── Input Zone ── */}
      <div
        className="fixed inset-x-0 z-20 px-6"
        style={{
          bottom: "56px",
          paddingBottom: "12px",
          background: colors.void,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
          {/* ── Top ambient line ── */}
          <div
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: 0.15,
              marginBottom: "10px",
            }}
          />

          <div className="flex items-center gap-3">
            {/* ── People icon — triggers Contact Picker ── */}
            <span
              role="button"
              tabIndex={0}
              onClick={pickContact}
              onKeyDown={(e) => { if (e.key === "Enter") pickContact(); }}
              className="cursor-pointer outline-none"
              style={{
                flexShrink: 0,
                opacity: 0.35,
                transition: `opacity ${timing.transition} ease`,
              }}
              onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.7"; }}
              onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.35"; }}
            >
              <PeopleIcon color={colors.white} />
            </span>

            {/* ── Smart input ── */}
            <div className="flex-1 relative">
              <div className="flex items-center">
                {contactName && dream.startsWith(`@${contactName}`) && (
                  <span
                    style={{
                      ...text.input,
                      color: colors.cyan,
                      position: "absolute",
                      left: 0,
                      pointerEvents: "none",
                      opacity: 0.9,
                    }}
                  >
                    @{contactName}
                  </span>
                )}
                <input
                  ref={inputRef}
                  type="text"
                  value={dream}
                  onChange={(e) => handleInputChange(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") manifestDream();
                  }}
                  placeholder="a trip, a dinner... or @name"
                  disabled={isCreating}
                  spellCheck={false}
                  autoComplete="off"
                  onFocus={() => setInputFocused(true)}
                  onBlur={() => setInputFocused(false)}
                  className="w-full bg-transparent outline-none"
                  style={{
                    ...text.input,
                    color: contactName && dream.startsWith(`@${contactName}`)
                      ? "transparent"
                      : colors.white,
                    caretColor: colors.cyan,
                    opacity: isCreating ? 0.3 : 1,
                  }}
                />
              </div>

              {contactName && dream.startsWith(`@${contactName}`) && (
                <span
                  style={{
                    ...text.input,
                    color: colors.white,
                    position: "absolute",
                    left: 0,
                    top: 0,
                    pointerEvents: "none",
                    opacity: 0.9,
                  }}
                >
                  <span style={{ visibility: "hidden" }}>@{contactName}</span>
                  <span>{dream.slice(`@${contactName}`.length)}</span>
                </span>
              )}
            </div>
          </div>

          {/* ── Onboarding whisper: input hint ── */}
          <div className="mt-2">
            <Whisper whisperKey="galaxy_input" delay={3}>
              type a plan, or @ a friend
            </Whisper>
          </div>

          {/* ── Living ambient line ── */}
          <div
            style={{
              marginTop: "4px",
              height: "1px",
              width: dream.length > 0
                ? `min(${Math.max(dream.length * 6, 40)}px, 100%)`
                : inputFocused ? "60px" : "0px",
              background: `linear-gradient(90deg, ${colors.cyan}, transparent)`,
              opacity: dream.length > 0 ? 0.4 : 0.2,
              animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
              transition: `width 0.3s ease, opacity ${timing.transition} ease`,
            }}
          />
        </div>
      </div>

      {/* ── Void fill below input ── */}
      <div
        className="fixed inset-x-0 z-[19]"
        style={{ bottom: 0, height: "56px", background: colors.void }}
      />

      <style jsx>{`
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.whisper};
          letter-spacing: 0.04em;
        }
        @keyframes meshPulse {
          0%, 100% { opacity: 0; }
          50% { opacity: 1; }
        }
      `}</style>
    </div>
  );
}

export default function GalaxyPage() {
  return (
    <Suspense>
      <GalaxyContent />
    </Suspense>
  );
}
