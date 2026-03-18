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
import { createSpace } from "@/lib/spaces";
import { colors, opacity, timing, layout, text, surface, ink } from "@/lib/theme";
import { makeUserId } from "@/lib/user-id";
import { UserMenu } from "@/components/os/UserMenu";
import { Avatar } from "@/components/os/Avatar";
import { isPlaygroundMode, getPlaygroundSpaces, isPlaygroundSpace } from "@/lib/playground";
import { fetchPersonalChats } from "@/lib/awareness";
import type { PersonalChat } from "@/lib/awareness";
import { supabase, getSupabaseToken } from "@/lib/supabase";
import { SummonSurface } from "@/components/os/SummonSurface";

type GalaxyTab = "people" | "plans" | "memories";

// ── Summon Another — inline nudge below PeopleDock ──
function SummonAnother({ userName }: { userName: string }) {
  const handleSummon = useCallback(async () => {
    try {
      const token = getSupabaseToken();
      const res = await fetch("/api/summon", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) return;
      const { url } = await res.json();
      if (!url) return;
      if (typeof navigator !== "undefined" && navigator.share) {
        await navigator.share({ title: "xark", text: `${userName} wants to plan with you`, url }).catch(() => {});
      } else {
        await navigator.clipboard.writeText(url).catch(() => {});
      }
    } catch {
      // silent
    }
  }, [userName]);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={handleSummon}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleSummon(); }}
      className="outline-none cursor-pointer"
      style={{ textAlign: "center", padding: "20px 24px 8px" }}
    >
      <span style={{ ...text.hint, color: ink.tertiary, textTransform: "uppercase", letterSpacing: "0.1em" }}>
        Invite someone
      </span>
    </div>
  );
}

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
  const [firstChatDone, setFirstChatDone] = useState(false);
  // New chat/group flow
  const [showNewSheet, setShowNewSheet] = useState(false);
  const [showUserPicker, setShowUserPicker] = useState(false);

  // ── Listen for Thumb Arc 'Compose' trigger ──
  useEffect(() => {
    const handleCompose = () => setShowNewSheet(true);
    if (typeof window !== "undefined") {
      window.addEventListener("xark-compose", handleCompose);
      return () => window.removeEventListener("xark-compose", handleCompose);
    }
  }, []);
  const [allUsers, setAllUsers] = useState<Array<{ id: string; display_name: string }>>([]);
  const [showGroupInput, setShowGroupInput] = useState(false);
  const [groupName, setGroupName] = useState("");
  // Spaces count (for onboarding)
  const [spacesCount, setSpacesCount] = useState<number | null>(null);
  // Playground spaces — computed client-side only (uses Date.now())
  const [pgSpaces, setPgSpaces] = useState<ReturnType<typeof getPlaygroundSpaces>>([]);
  useEffect(() => { setPgSpaces(getPlaygroundSpaces()); }, []);

  useEffect(() => {
    if (!userId) return;
    // Fetch only the total space count (lightning fast head query) to determine UI empty state
    supabase.from('space_members')
      .select('space_id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .then(({ count }) => {
        setSpacesCount(count ?? 0);
      });
    // Check if user has ever created a chat
    if (typeof window !== "undefined") {
      setFirstChatDone(!!localStorage.getItem("xark_first_chat"));
    }
  }, [userId]);

  // Fetch all users for contact picker
  const fetchAllUsers = useCallback(async () => {
    const { data } = await supabase.from("users").select("id, display_name").neq("id", userId).order("display_name");
    if (data) setAllUsers(data.filter(u => u.display_name));
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

  const handleNewChat = useCallback(async (contact: { id: string; display_name: string }) => {
    setIsCreating(true);
    const title = `${userName} & ${contact.display_name}`;
    try {
      const { spaceId } = await createSpace(title, userId, contact.display_name, contact.id);
      if (!spaceId) throw new Error("No spaceId returned");
      setShowUserPicker(false);
      setShowNewSheet(false);
      handlePersonTap(spaceId);
    } catch {
      // Handle error visually if necessary
    } finally {
      setIsCreating(false);
    }
  }, [userId, userName, handlePersonTap]);

  const handleNewGroup = useCallback(async () => {
    const name = groupName.trim();
    if (!name) return;
    setIsCreating(true);
    try {
      const { spaceId } = await createSpace(name, userId);
      if (!spaceId) throw new Error("No spaceId returned");
      setShowGroupInput(false);
      setShowNewSheet(false);
      setGroupName("");
      handleSpaceTap(spaceId);
    } catch {
      // Handle error visually if necessary
    } finally {
      setIsCreating(false);
    }
  }, [groupName, userId, handleSpaceTap]);

  // Start a chat with a contact (People tab)
  const startChat = useCallback(async (contactName: string) => {
    setIsCreating(true);
    const title = `chat with ${contactName}`;
    try {
      const { spaceId } = await createSpace(title, userId, contactName);
      if (!spaceId) throw new Error("No spaceId returned");
      handlePersonTap(spaceId);
      setDream("");
      if (typeof window !== "undefined") localStorage.setItem("xark_first_chat", "1");
      setFirstChatDone(true);
    } catch {
      // Handle error visually if necessary
    } finally {
      setIsCreating(false);
    }
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

    try {
      const { spaceId } = await createSpace(txt, userId);
      if (!spaceId) throw new Error("No spaceId returned");
      setDream("");
      handleSpaceTap(spaceId);
    } catch {
      // Handle error visually
    } finally {
      setIsCreating(false);
    }
  }, [dream, isCreating, userId, activeTab, startChat, handleSpaceTap]);

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
    <div className="relative" style={{ height: "100dvh", overflow: "hidden", display: "flex", flexDirection: "column", background: "transparent" }}>
      {/* ── Tab header — glass surface ── */}
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
                  color: isActive ? ink.primary : ink.tertiary,
                  opacity: isActive ? 1 : 0.6,
                  fontWeight: isActive ? 600 : 400,
                  fontSize: isActive ? "20px" : "18px",
                  transition: `all 0.4s ease`,
                  paddingBottom: "10px",
                  textTransform: "capitalize",
                }}
              >
                {tab}
                {/* Ambient underline glow — wider, brighter */}
                <span
                  style={{
                    position: "absolute",
                    bottom: 0,
                    left: "10%",
                    width: "80%",
                    height: "3px",
                    borderRadius: "3px",
                    background: ink.primary,
                    opacity: isActive ? 1 : 0,
                    transition: "opacity 0.4s ease",
                  }}
                />
              </span>
            );
          })}
          </div>
          <div style={{ marginLeft: "auto", paddingBottom: "10px", display: "flex", gap: "16px", alignItems: "center" }}>
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
              {spacesCount === 0 ? (
                <SummonSurface userName={userName} />
              ) : (
                <>
                  <PeopleDock
                    userId={userId}
                    userName={userName}
                    onPersonTap={handlePersonTap}
                  />
                  <SummonAnother userName={userName} />
                </>
              )}
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

      {/* ── New chat/group sheet ── */}
      <AnimatePresence>
        {showNewSheet && (
          <>
            <motion.div
              className="fixed inset-0 z-[30]"
              style={{ background: "#000" }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.5 }}
              exit={{ opacity: 0 }}
              onClick={() => { setShowNewSheet(false); setShowUserPicker(false); setShowGroupInput(false); }}
            />
            <motion.div
              className="fixed inset-x-0 bottom-0 z-[31] px-6 pb-8"
              style={{ background: surface.chrome, borderRadius: "20px 20px 0 0", maxHeight: "70vh", overflowY: "auto" }}
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ type: "spring", damping: 25, stiffness: 300 }}
            >
              <div className="mx-auto pt-4 pb-2" style={{ maxWidth: layout.maxWidth }}>
                <div style={{ width: "36px", height: "4px", borderRadius: "2px", background: ink.tertiary, opacity: 0.3, margin: "0 auto 16px" }} />

                {!showUserPicker && !showGroupInput && (
                  <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={() => { setShowUserPicker(true); fetchAllUsers(); }}
                      onKeyDown={(e) => { if (e.key === "Enter") { setShowUserPicker(true); fetchAllUsers(); } }}
                      className="outline-none cursor-pointer"
                      style={{ padding: "14px 0", display: "flex", alignItems: "center", gap: "14px" }}
                    >
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={ink.primary} strokeWidth="1.5" strokeLinecap="round">
                        <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
                        <circle cx="12" cy="7" r="4" />
                      </svg>
                      <span style={{ ...text.body, color: ink.primary }}>New Chat</span>
                    </div>
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={() => setShowGroupInput(true)}
                      onKeyDown={(e) => { if (e.key === "Enter") setShowGroupInput(true); }}
                      className="outline-none cursor-pointer"
                      style={{ padding: "14px 0", display: "flex", alignItems: "center", gap: "14px" }}
                    >
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={ink.primary} strokeWidth="1.5" strokeLinecap="round">
                        <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
                        <circle cx="9" cy="7" r="4" />
                        <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
                      </svg>
                      <span style={{ ...text.body, color: ink.primary }}>New Group</span>
                    </div>
                  </div>
                )}

                {/* User picker — contacts API + Xark users */}
                {showUserPicker && (
                  <div>
                    {/* Contact Picker API button (Android Chrome) */}
                    {"contacts" in navigator && (
                      <div
                        role="button"
                        tabIndex={0}
                        onClick={async () => {
                          try {
                            const contacts = await (navigator as any).contacts.select(
                              ["name", "tel"],
                              { multiple: false }
                            );
                            if (contacts?.[0]) {
                              const contact = contacts[0];
                              const contactName = (contact.name?.[0] ?? "").trim();
                              if (!contactName) return;

                              // Just create a chat with this person's name
                              // If they're on Xark, they'll be matched by display_name
                              // If not, the space is created and they can join via invite
                              const firstName = contactName.split(" ")[0].toLowerCase();
                              handleNewChat({ id: "", display_name: firstName });
                            }
                          } catch {
                            // User cancelled or API not supported
                          }
                        }}
                        className="outline-none cursor-pointer"
                        style={{ padding: "14px 0", display: "flex", alignItems: "center", gap: "14px", marginBottom: "8px" }}
                      >
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#FF6B35" strokeWidth="1.5" strokeLinecap="round">
                          <rect x="3" y="4" width="18" height="18" rx="2" />
                          <circle cx="12" cy="10" r="3" />
                          <path d="M7 20v-1a5 5 0 0110 0v1" />
                        </svg>
                        <span style={{ ...text.body, color: colors.accent, fontWeight: 500 }}>Pick from Contacts</span>
                      </div>
                    )}

                    <p style={{ ...text.label, color: ink.tertiary, marginBottom: "8px", marginTop: "4px", textTransform: "uppercase", letterSpacing: "0.05em" }}>On Xark</p>
                    {allUsers.length === 0 && (
                      <p style={{ ...text.hint, color: ink.tertiary }}>No other users on Xark yet.</p>
                    )}
                    {allUsers.map((u) => (
                      <div
                        key={u.id}
                        role="button"
                        tabIndex={0}
                        onClick={() => handleNewChat(u)}
                        onKeyDown={(e) => { if (e.key === "Enter") handleNewChat(u); }}
                        className="outline-none cursor-pointer"
                        style={{ padding: "10px 0", display: "flex", alignItems: "center", gap: "12px" }}
                      >
                        <Avatar name={u.display_name} size={36} />
                        <span style={{ ...text.body, color: ink.primary }}>{u.display_name}</span>
                      </div>
                    ))}
                  </div>
                )}

                {/* Group name input */}
                {showGroupInput && (
                  <div>
                    <p style={{ ...text.label, color: ink.tertiary, marginBottom: "12px", textTransform: "uppercase", letterSpacing: "0.05em" }}>Group Name</p>
                    <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
                      <input
                        type="text"
                        value={groupName}
                        onChange={(e) => setGroupName(e.target.value)}
                        onKeyDown={(e) => { if (e.key === "Enter") handleNewGroup(); }}
                        placeholder="New York Trip"
                        autoFocus
                        className="outline-none"
                        style={{
                          ...text.body,
                          flex: 1,
                          color: ink.primary,
                          background: "transparent",
                          padding: "10px 0",
                          caretColor: "#FF6B35",
                        }}
                      />
                      {groupName.trim() && (
                        <div
                          role="button"
                          tabIndex={0}
                          onClick={handleNewGroup}
                          className="outline-none cursor-pointer"
                        >
                          <SendIcon color="#FF6B35" size={28} />
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>


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
