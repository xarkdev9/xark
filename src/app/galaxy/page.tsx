"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { motion } from "framer-motion";
import { createSpace, getOptimisticSpaceId } from "@/lib/spaces";
import {
  fetchAwareness,
  awarenessOpacity,
  getDemoAwareness,
} from "@/lib/awareness";
import type { AwarenessEvent } from "@/lib/awareness";
import { recencyLabel } from "@/lib/space-data";
import { colors, opacity, timing, layout, text, textColor } from "@/lib/theme";
import { useAuth } from "@/hooks/useAuth";

function GalaxyContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const userName = searchParams.get("name") ?? "";
  const { user } = useAuth(userName || undefined);
  const [mounted, setMounted] = useState(false);
  const [events, setEvents] = useState<AwarenessEvent[]>([]);
  const [dream, setDream] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!user) return;
    fetchAwareness(user.uid)
      .then((result) => setEvents(result.length > 0 ? result : getDemoAwareness()))
      .catch(() => setEvents(getDemoAwareness()));
  }, [user]);

  const hasEvents = events.length > 0;

  // Check if any event had activity in last 15 min — drives amber swell
  const recentActivity = events.some(
    (e) => Date.now() - e.timestamp < 900_000
  );

  const manifestDream = useCallback(async () => {
    const txt = dream.trim();
    if (!txt || isCreating) return;
    setIsCreating(true);
    const resolvedId = user?.uid ?? `name_${userName}`;
    const spaceId = getOptimisticSpaceId(txt);
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
    createSpace(txt, resolvedId).catch(() => {});
  }, [dream, isCreating, router, userName]);

  return (
    <div className="relative flex min-h-svh flex-col">
      {/* ── Spectrum Wash — amber swell intensifies when activity is recent ── */}
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

      {/* ── Content ── */}
      <motion.div
        className="flex-1 overflow-y-auto px-6"
        style={{ paddingTop: "80px", paddingBottom: "140px" }}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.6 }}
      >
        <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
          {/* ── Awareness Stream — living feed of cross-space activity ── */}
          {hasEvents && (
            <div>
              {events.map((event, index) => {
                const eventOpacity = awarenessOpacity(event.priority);

                return (
                  <motion.div
                    key={event.id}
                    role="button"
                    tabIndex={0}
                    onClick={() =>
                      router.push(`/space/${event.spaceId}?name=${encodeURIComponent(userName)}`)
                    }
                    onKeyDown={(e) => {
                      if (e.key === "Enter")
                        router.push(`/space/${event.spaceId}?name=${encodeURIComponent(userName)}`);
                    }}
                    className="cursor-pointer outline-none"
                    style={{ paddingBottom: "20px" }}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{
                      delay: 0.15 + index * timing.staggerDelay,
                      duration: 0.5,
                      ease: [0.22, 1, 0.36, 1],
                    }}
                  >
                    {/* ── Whisper text — the event itself ── */}
                    <p
                      style={{
                        ...text.body,
                        color: colors.white,
                        opacity: eventOpacity,
                        lineHeight: 1.6,
                      }}
                    >
                      {event.text}
                    </p>

                    {/* ── Space context — which plan this belongs to ── */}
                    <p
                      className="mt-0.5"
                      style={{
                        ...text.recency,
                        color: textColor(Math.min(0.25, eventOpacity * 0.35)),
                      }}
                    >
                      {event.spaceTitle} · {recencyLabel(new Date(event.timestamp))}
                    </p>
                  </motion.div>
                );
              })}
            </div>
          )}

          {/* ── Empty state — new user ── */}
          {!hasEvents && mounted && (
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

      {/* ── Input Zone — 96px from bottom, solid void ── */}
      <div
        className="fixed inset-x-0 bottom-0 px-6 pt-4"
        style={{
          paddingBottom: layout.inputBottom,
          background: colors.void,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
          {/* ── Top ambient line — content boundary ── */}
          <div
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: 0.15,
              marginBottom: "12px",
            }}
          />
          <div className="relative">
            <input
              type="text"
              value={dream}
              onChange={(e) => setDream(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") manifestDream();
              }}
              placeholder="a trip, a dinner, an idea..."
              disabled={isCreating}
              spellCheck={false}
              autoComplete="off"
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              className="w-full bg-transparent outline-none"
              style={{
                ...text.body,
                color: colors.white,
                caretColor: colors.cyan,
                opacity: isCreating ? 0.3 : 1,
              }}
            />
            <div
              className="absolute -bottom-2 left-0 h-px w-full"
              style={{
                background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                opacity: inputFocused ? opacity.focusUnderline : opacity.rule,
                transition: `opacity ${timing.transition} ease`,
              }}
            />
          </div>
        </div>
      </div>

      <style jsx>{`
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.whisper};
          letter-spacing: 0.12em;
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
