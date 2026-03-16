"use client";

// XARK OS v2.0 — GALAXY PAGE
// Tab toggle: People | Plans. Dream input fixed above ControlCaret.

import { Suspense, useState, useCallback, useRef, useEffect, type TouchEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { AwarenessStream } from "@/components/os/AwarenessStream";
import { PeopleDock } from "@/components/os/PeopleDock";
import { MemoriesTab } from "@/components/os/MemoriesTab";
import { useAuth } from "@/hooks/useAuth";
import { createSpace, getOptimisticSpaceId } from "@/lib/spaces";
import { colors, opacity, timing, layout, text } from "@/lib/theme";
import { makeUserId } from "@/lib/user-id";
import { UserMenu } from "@/components/os/UserMenu";

// ── Time-of-day greeting ──
function getGreeting(name: string): string {
  const h = new Date().getHours();
  const first = name.split(" ")[0]?.toLowerCase() || "";
  if (h < 5) return `still up, ${first}?`;
  if (h < 12) return `morning, ${first}`;
  if (h < 17) return `hey ${first}`;
  if (h < 21) return `evening, ${first}`;
  return `night, ${first}`;
}

type GalaxyTab = "people" | "plans" | "memories";

// ── Send icon ──
function SendIcon({ color, size = 24 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="11" stroke={color} strokeWidth="1.5" />
      <path d="M12 16V8M12 8l-4 4M12 8l4 4" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function GalaxyContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const userName = searchParams.get("name") ?? "";
  const { user } = useAuth(userName || undefined);
  const [activeTab, setActiveTab] = useState<GalaxyTab>("people");
  const [tabDirection, setTabDirection] = useState(0);
  const [greetingVisible, setGreetingVisible] = useState(false);

  // Dream input state
  const [dream, setDream] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Auto-resize textarea (max ~4 lines)
  const autoResize = useCallback(() => {
    const el = inputRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 100)}px`;
  }, []);

  useEffect(() => {
    autoResize();
  }, [dream, autoResize]);

  const userId = user?.uid ?? makeUserId("name", userName);

  const handleSpaceTap = (spaceId: string, viewMode?: "decide") => {
    const viewParam = viewMode ? `&view=${viewMode}` : "";
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}${viewParam}`);
  };

  const handlePersonTap = (spaceId: string) => {
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
  };

  const manifestDream = useCallback(async () => {
    const raw = dream.trim();
    if (!raw || isCreating) return;
    setIsCreating(true);

    // Strip "@xark create group/space/trip" prefix — but preserve place names like "New York"
    // Only strip "create/make/start/new" when followed by "group", "space", "trip", "plan"
    const txt = raw
      .replace(/^@xark\s+(?:create|make|start|new)\s+(?:group|space|trip|plan)\s*/i, "")
      .replace(/^@xark\s+/i, "")
      .trim() || raw;

    const spaceId = getOptimisticSpaceId(txt);
    handleSpaceTap(spaceId);
    createSpace(txt, userId).catch(() => {});
  }, [dream, isCreating, userId]);

  // ── Swipe to switch tabs ──
  const tabs: GalaxyTab[] = ["people", "plans", "memories"];
  const touchStartX = useRef(0);
  const touchStartY = useRef(0);

  const handleTouchStart = useCallback((e: TouchEvent) => {
    touchStartX.current = e.touches[0].clientX;
    touchStartY.current = e.touches[0].clientY;
  }, []);

  const handleTouchEnd = useCallback((e: TouchEvent) => {
    const dx = e.changedTouches[0].clientX - touchStartX.current;
    const dy = e.changedTouches[0].clientY - touchStartY.current;
    // Only trigger if horizontal swipe is dominant and > 60px
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      const currentIdx = tabs.indexOf(activeTab);
      if (dx < 0 && currentIdx < tabs.length - 1) {
        setTabDirection(1);
        setActiveTab(tabs[currentIdx + 1]);
      } else if (dx > 0 && currentIdx > 0) {
        setTabDirection(-1);
        setActiveTab(tabs[currentIdx - 1]);
      }
    }
  }, [activeTab]);

  return (
    <div className="relative" style={{ height: "100dvh", overflow: "hidden", display: "flex", flexDirection: "column" }}>
      {/* ── Spectrum Wash — warmer, more present ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background: [
            `radial-gradient(ellipse 70% 50% at 25% 20%, rgba(var(--xark-accent-rgb), 0.06) 0%, transparent 60%)`,
            `radial-gradient(ellipse 60% 50% at 75% 70%, rgba(var(--xark-amber-rgb), 0.04) 0%, transparent 50%)`,
          ].join(", "),
        }}
      />

      {/* ── Mesh Pulse — slow, living ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background: `radial-gradient(ellipse 80% 60% at 50% 40%, rgba(var(--xark-white-rgb), 0.04) 0%, transparent 100%)`,
          animation: `meshPulse ${timing.meshPulse} ease-in-out infinite`,
        }}
      />

      {/* ── Tab header ── */}
      <div
        className="relative z-10 px-6"
        style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 48px)", flexShrink: 0 }}
      >
        <div
          className="mx-auto flex items-center"
          style={{ maxWidth: layout.maxWidth }}
        >
          <div className="flex gap-6">
          {(["people", "plans", "memories"] as GalaxyTab[]).map((tab) => {
            const isActive = activeTab === tab;
            return (
              <span
                key={tab}
                role="button"
                tabIndex={0}
                onClick={() => { setTabDirection(tabs.indexOf(tab) > tabs.indexOf(activeTab) ? 1 : -1); setActiveTab(tab); }}
                onKeyDown={(e) => { if (e.key === "Enter") { setTabDirection(tabs.indexOf(tab) > tabs.indexOf(activeTab) ? 1 : -1); setActiveTab(tab); } }}
                className="cursor-pointer outline-none"
                style={{
                  ...text.label,
                  position: "relative",
                  color: isActive ? colors.cyan : colors.white,
                  opacity: isActive ? 0.85 : 0.25,
                  transition: `opacity 0.4s ease, color 0.4s ease`,
                  paddingBottom: "10px",
                }}
              >
                {tab}
                {/* Ambient underline glow — wider, brighter */}
                <span
                  style={{
                    position: "absolute",
                    bottom: 0,
                    left: 0,
                    width: "100%",
                    height: "2px",
                    background: `linear-gradient(90deg, transparent 5%, ${colors.cyan} 50%, transparent 95%)`,
                    opacity: isActive ? 0.7 : 0,
                    transition: "opacity 0.4s ease",
                  }}
                />
                {/* Soft halo behind active tab */}
                <span
                  style={{
                    position: "absolute",
                    bottom: "-2px",
                    left: "-20%",
                    width: "140%",
                    height: "8px",
                    background: `radial-gradient(ellipse at center, rgba(var(--xark-accent-rgb), 0.25) 0%, transparent 70%)`,
                    opacity: isActive ? 1 : 0,
                    transition: "opacity 0.4s ease",
                    pointerEvents: "none",
                  }}
                />
              </span>
            );
          })}
          </div>
          <div style={{ marginLeft: "auto", paddingBottom: "10px" }}>
            <UserMenu userName={userName} userId={userId} />
          </div>
        </div>
      </div>

      {/* ── Scrollable content — crossfade + slide on tab switch ── */}
      <div
        className="relative z-10"
        style={{ flex: 1, overflowY: "auto", paddingTop: "12px", paddingBottom: "120px" }}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
      >
        <AnimatePresence mode="wait" custom={tabDirection}>
          {activeTab === "people" && (
            <motion.div
              key="people"
              custom={tabDirection}
              initial={{ opacity: 0, x: tabDirection * 30 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: tabDirection * -30 }}
              transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            >
              <PeopleDock
                userId={userId}
                userName={userName}
                onPersonTap={handlePersonTap}
              />
            </motion.div>
          )}
          {activeTab === "plans" && (
            <motion.div
              key="plans"
              custom={tabDirection}
              initial={{ opacity: 0, x: tabDirection * 30 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: tabDirection * -30 }}
              transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            >
              <AwarenessStream
                userId={userId}
                userName={userName}
                onSpaceTap={handleSpaceTap}
              />
            </motion.div>
          )}
          {activeTab === "memories" && (
            <motion.div
              key="memories"
              custom={tabDirection}
              initial={{ opacity: 0, x: tabDirection * 30 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: tabDirection * -30 }}
              transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            >
              <MemoriesTab userId={userId} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* ── Dream input — fixed above ControlCaret ── */}
      <div
        className="fixed inset-x-0 z-[20]"
        style={{
          bottom: "56px",
          background: colors.void,
          paddingTop: "8px",
          paddingBottom: "8px",
        }}
      >
        <div className="mx-auto px-6" style={{ maxWidth: layout.maxWidth }}>
          <div
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: inputFocused ? 0.3 : 0.12,
              marginBottom: "10px",
              transition: "opacity 0.4s ease",
            }}
          />

          <div className="flex items-end gap-3">
            <div className="flex-1">
              <textarea
                ref={inputRef}
                value={dream}
                onChange={(e) => setDream(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    manifestDream();
                  }
                }}
                placeholder="a trip, a dinner, a plan..."
                enterKeyHint="send"
                disabled={isCreating}
                spellCheck={false}
                autoComplete="off"
                autoCapitalize="sentences"
                rows={1}
                onFocus={() => setInputFocused(true)}
                onBlur={() => setInputFocused(false)}
                className="w-full bg-transparent outline-none resize-none"
                style={{
                  ...text.input,
                  color: colors.white,
                  caretColor: colors.cyan,
                  opacity: isCreating ? 0.3 : 1,
                  lineHeight: 1.4,
                  maxHeight: "100px",
                  overflow: "hidden",
                }}
              />
            </div>

            {dream.trim().length > 0 && (
              <span
                role="button"
                tabIndex={0}
                onClick={manifestDream}
                onKeyDown={(e) => { if (e.key === "Enter") manifestDream(); }}
                className="cursor-pointer outline-none"
                style={{
                  flexShrink: 0,
                  opacity: isCreating ? 0.3 : 0.6,
                  transition: `opacity ${timing.transition} ease`,
                }}
                onMouseEnter={(e) => { if (!isCreating) e.currentTarget.style.opacity = "0.9"; }}
                onMouseLeave={(e) => { if (!isCreating) e.currentTarget.style.opacity = "0.6"; }}
              >
                <SendIcon color={colors.cyan} />
              </span>
            )}
          </div>

          {/* Living ambient line */}
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
        @keyframes meshPulse {
          0%, 100% { opacity: 0; }
          50% { opacity: 1; }
        }
        textarea::placeholder {
          color: ${colors.white};
          opacity: ${opacity.whisper};
          letter-spacing: 0.04em;
        }
        @keyframes ambientBreath {
          0%, 100% { opacity: 0.6; }
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
