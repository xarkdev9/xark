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
import { colors, opacity, timing, layout, text, surface, ink } from "@/lib/theme";
import { makeUserId } from "@/lib/user-id";
import { UserMenu } from "@/components/os/UserMenu";
import { Avatar } from "@/components/os/Avatar";
import { isPlaygroundMode, getPlaygroundSpaces, isPlaygroundSpace } from "@/lib/playground";
import { fetchPersonalChats } from "@/lib/awareness";
import type { PersonalChat } from "@/lib/awareness";
import { supabase } from "@/lib/supabase";

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
  const [mounted, setMounted] = useState(false);
  useEffect(() => { setMounted(true); }, []);

  const userId = user?.uid ?? makeUserId("name", userName);

  // Dream input state
  const [dream, setDream] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Known contacts — derived from space members
  const [knownContacts, setKnownContacts] = useState<string[]>([]);
  const [firstChatDone, setFirstChatDone] = useState(false);
  // Playground spaces — computed client-side only (uses Date.now())
  const [pgSpaces, setPgSpaces] = useState<ReturnType<typeof getPlaygroundSpaces>>([]);
  useEffect(() => { setPgSpaces(getPlaygroundSpaces()); }, []);

  useEffect(() => {
    if (!userId) return;
    // Fetch unique contact names from all spaces
    supabase
      .from("space_members")
      .select("user_id")
      .neq("user_id", userId)
      .then(({ data }) => {
        if (data) {
          const ids = [...new Set(data.map((r) => r.user_id))];
          // Get display names
          supabase
            .from("users")
            .select("display_name")
            .in("id", ids)
            .then(({ data: users }) => {
              if (users) {
                setKnownContacts(users.map((u) => u.display_name).filter(Boolean));
              }
            });
        }
      });
    // Check if user has ever created a chat
    if (typeof window !== "undefined") {
      setFirstChatDone(!!localStorage.getItem("xark_first_chat"));
    }
  }, [userId]);

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

  const handleSpaceTap = (spaceId: string, viewMode?: "decide") => {
    const viewParam = viewMode ? `&view=${viewMode}` : "";
    const playgroundParam = isPlaygroundSpace(spaceId) ? "&playground=true" : "";
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}${viewParam}${playgroundParam}`);
  };

  const handlePersonTap = (spaceId: string) => {
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
  };

  // Start a chat with a contact (People tab)
  const startChat = useCallback((contactName: string) => {
    setIsCreating(true);
    const title = `chat with ${contactName}`;
    const spaceId = getOptimisticSpaceId(title);
    handlePersonTap(spaceId);
    createSpace(title, userId, contactName).catch(() => {});
    setDream("");
    setIsCreating(false);
    if (typeof window !== "undefined") localStorage.setItem("xark_first_chat", "1");
    setFirstChatDone(true);
  }, [userId, handlePersonTap]);

  const manifestDream = useCallback(async () => {
    const raw = dream.trim();
    if (!raw || isCreating) return;
    setIsCreating(true);

    // People tab: treat input as a contact name → create sanctuary
    if (activeTab === "people") {
      startChat(raw);
      return;
    }

    // Plans tab: strip "@xark create group/space/trip" prefix — preserve place names like "New York"
    const txt = raw
      .replace(/^@xark\s+(?:create|make|start|new)\s+(?:group|space|trip|plan)\s*/i, "")
      .replace(/^@xark\s+/i, "")
      .trim() || raw;

    const spaceId = getOptimisticSpaceId(txt);
    setDream("");
    setIsCreating(false);
    handleSpaceTap(spaceId);
    createSpace(txt, userId).catch(() => {});
  }, [dream, isCreating, userId, activeTab, startChat]);

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
    <div className="relative" style={{ height: "100dvh", overflow: "hidden", display: "flex", flexDirection: "column", background: surface.chrome }}>
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

      {/* ── Tab header — chrome surface ── */}
      <div
        className="relative z-10 px-6"
        style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 48px)", flexShrink: 0, paddingBottom: "8px" }}
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
        style={{ flex: 1, overflowY: "auto", paddingTop: "16px", paddingBottom: "120px" }}
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
                playgroundSpaces={pgSpaces}
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

      {/* ── Tab-aware dream input ── */}
      <div
        className="fixed inset-x-0 z-[20]"
        style={{
          bottom: "56px",
          background: `linear-gradient(to top, ${surface.canvas}, ${surface.canvas} 80%, transparent)`,
          paddingTop: "8px",
          paddingBottom: "12px",
        }}
      >
        <div className="mx-auto px-6" style={{ maxWidth: layout.maxWidth }}>

          {/* ── Zero-State Contact Reveal — appears on focus, People tab ── */}
          {mounted && activeTab === "people" && inputFocused && dream.length === 0 && knownContacts.length > 0 && (
            <div
              style={{
                display: "flex",
                gap: "16px",
                overflowX: "auto",
                paddingBottom: "12px",
                scrollbarWidth: "none",
              }}
            >
              {knownContacts.slice(0, 8).map((name) => (
                <div
                  key={name}
                  role="button"
                  tabIndex={0}
                  onMouseDown={(e) => { e.preventDefault(); startChat(name); }}
                  className="cursor-pointer outline-none"
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    gap: "4px",
                    flexShrink: 0,
                  }}
                >
                  <Avatar name={name} size={44} />
                  <span style={{ fontSize: "11px", fontWeight: 400, color: ink.secondary }}>
                    {name}
                  </span>
                </div>
              ))}
            </div>
          )}

          {/* ── Actionable contact suggestion — when typing a name on People tab ── */}
          {mounted && activeTab === "people" && dream.length > 0 && (() => {
            const q = dream.toLowerCase();
            const matches = knownContacts.filter((n) => n.toLowerCase().includes(q));
            if (matches.length === 0) return null;
            return (
              <div style={{ paddingBottom: "8px" }}>
                {matches.slice(0, 3).map((name) => (
                  <div
                    key={name}
                    role="button"
                    tabIndex={0}
                    onMouseDown={(e) => { e.preventDefault(); startChat(name); }}
                    className="cursor-pointer outline-none"
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "10px",
                      padding: "8px 0",
                    }}
                  >
                    <Avatar name={name} size={32} />
                    <span style={{ fontSize: "15px", fontWeight: 400, color: ink.primary }}>
                      start chat with {name}
                    </span>
                    <span style={{ marginLeft: "auto", fontSize: "14px", color: ink.tertiary }}>
                      →
                    </span>
                  </div>
                ))}
              </div>
            );
          })()}

          {/* ── Input row ── */}
          <div className="flex items-end gap-3">
            {/* Persistent ghost prefix on People tab */}
            {mounted && activeTab === "people" && inputFocused && (
              <span style={{ fontSize: "18px", fontWeight: 300, color: ink.tertiary, flexShrink: 0, marginBottom: "2px" }}>
                chat:
              </span>
            )}

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
                placeholder={
                  activeTab === "people"
                    ? "type a name to start chatting..."
                    : "a trip, a dinner, a plan..."
                }
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
                  fontSize: "18px",
                  fontWeight: 300,
                  letterSpacing: "0.02em",
                  color: colors.white,
                  caretColor: colors.cyan,
                  opacity: isCreating ? 0.3 : 1,
                  lineHeight: 1.5,
                  maxHeight: "100px",
                  overflow: "hidden",
                  textShadow: dream.length > 0 ? "0 2px 12px rgba(20,20,20,0.08)" : "none",
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

          {/* ── First-time training whisper (People tab only, dismisses after first chat) ── */}
          {mounted && activeTab === "people" && !firstChatDone && !inputFocused && (
            <p
              style={{
                fontSize: "12px",
                fontWeight: 300,
                color: ink.tertiary,
                marginTop: "6px",
                animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
              }}
            >
              tap here and type a name to start chatting
            </p>
          )}
        </div>
      </div>

      {/* ── Void fill below input ── */}
      <div
        className="fixed inset-x-0 z-[19]"
        style={{ bottom: 0, height: "56px", background: surface.canvas, transition: "background 0.3s ease" }}
      />

      <style jsx>{`
        @keyframes meshPulse {
          0%, 100% { opacity: 0; }
          50% { opacity: 1; }
        }
        textarea::placeholder {
          color: var(--xark-ink-tertiary);
          opacity: 1;
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
