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
import { isPlaygroundMode, getPlaygroundSpaces, isPlaygroundSpace } from "@/lib/playground";
import { fetchPersonalChats } from "@/lib/awareness";
import type { PersonalChat } from "@/lib/awareness";
import { supabase, getSupabaseToken } from "@/lib/supabase";
import { InviteSurface, generateAndShareInvite } from "@/components/os/InviteSurface";

type GalaxyTab = "people" | "plans" | "memories";

// ── Invite Another — inline nudge below PeopleDock ──
function InviteAnother({ userName }: { userName: string }) {
  const handleInvite = useCallback(async () => {
    try {
      await generateAndShareInvite(userName);
    } catch { /* user cancelled or silent */ }
  }, [userName]);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={handleInvite}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleInvite(); }}
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

  // ── Listen for Thumb Arc 'Compose' trigger ──
  useEffect(() => {
    const handleCompose = () => setShowNewSheet(true);
    if (typeof window !== "undefined") {
      window.addEventListener("xark-compose", handleCompose);
      return () => window.removeEventListener("xark-compose", handleCompose);
    }
  }, []);
  const [showPhoneInput, setShowPhoneInput] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [contactCheckStatus, setContactCheckStatus] = useState<"idle" | "checking" | "found" | "not_found">("idle");
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

  // Detect Contact Picker API support (Android Chrome)
  const hasContactPicker = typeof navigator !== "undefined" && "contacts" in navigator && "ContactsManager" in window;

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

  // Check a phone number against /api/contacts/check and start chat or invite
  const checkPhoneAndChat = useCallback(async (phone: string, contactName?: string) => {
    const token = getSupabaseToken();
    setContactCheckStatus("checking");
    try {
      const res = await fetch("/api/contacts/check", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ phones: [phone] }),
      });
      if (!res.ok) throw new Error(`API error ${res.status}`);
      const { registered } = await res.json();

      if (registered?.length > 0) {
        // Registered — start chat via /api/chat/start
        setContactCheckStatus("found");
        const otherUserId = registered[0].userId;
        const chatRes = await fetch("/api/chat/start", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
          body: JSON.stringify({ otherUserId }),
        });
        if (!chatRes.ok) throw new Error(`chat/start error ${chatRes.status}`);
        const { spaceId } = await chatRes.json();
        if (!spaceId) throw new Error("No spaceId returned");
        setShowNewSheet(false);
        setShowPhoneInput(false);
        setPhoneNumber("");
        setContactCheckStatus("idle");
        handlePersonTap(spaceId);
      } else {
        // Not registered — offer invite
        setContactCheckStatus("not_found");
      }
    } catch (err) {
      console.error("[contacts] check failed:", err);
      setContactCheckStatus("idle");
    }
  }, [handlePersonTap]);

  // Handle Contact Picker API result (Android)
  const handleContactPick = useCallback(async () => {
    try {
      const contacts = await (navigator as any).contacts.select(
        ["name", "tel"],
        { multiple: false }
      );
      if (!contacts?.[0]) return;

      const contact = contacts[0];
      const contactName = (contact.name?.[0] ?? "").trim();
      const phone = contact.tel?.[0] ?? "";
      if (!phone) return;

      await checkPhoneAndChat(phone, contactName);
    } catch {
      // User cancelled or API not supported
    }
  }, [checkPhoneAndChat]);

  const handleNewChat = useCallback(async (contact: { id: string; display_name: string }) => {
    if (!contact.id) return; // No user ID — can't start chat
    setIsCreating(true);
    try {
      const token = getSupabaseToken();
      const res = await fetch("/api/chat/start", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ otherUserId: contact.id }),
      });

      if (!res.ok) throw new Error(`API error ${res.status}`);

      const { spaceId } = await res.json();
      if (!spaceId) throw new Error("No spaceId returned");

      setShowPhoneInput(false);
      setShowNewSheet(false);
      handlePersonTap(spaceId);
    } catch (err) {
      console.error("[chat] start failed:", err);
    } finally {
      setIsCreating(false);
    }
  }, [userId, handlePersonTap]);

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

  // Start a chat with a contact (People tab) — tries /api/chat/start first if user match found
  const startChat = useCallback(async (contactName: string) => {
    setIsCreating(true);
    try {
      // Try to match against known Xark users by display_name
      const { data: matchedUsers } = await supabase
        .from("users")
        .select("id, display_name")
        .ilike("display_name", contactName.trim())
        .neq("id", userId)
        .limit(1);

      const matched = matchedUsers?.[0];

      if (matched?.id) {
        // WhatsApp-style: find or create 1:1 chat via API
        const token = getSupabaseToken();
        const res = await fetch("/api/chat/start", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
          body: JSON.stringify({ otherUserId: matched.id }),
        });

        if (!res.ok) throw new Error(`API error ${res.status}`);
        const { spaceId } = await res.json();
        if (!spaceId) throw new Error("No spaceId returned");
        handlePersonTap(spaceId);
      } else {
        // No match — fall through to group space creation
        const title = `chat with ${contactName}`;
        const { spaceId } = await createSpace(title, userId, contactName);
        if (!spaceId) throw new Error("No spaceId returned");
        handlePersonTap(spaceId);
      }

      setDream("");
      if (typeof window !== "undefined") localStorage.setItem("xark_first_chat", "1");
      setFirstChatDone(true);
    } catch (err) {
      console.error("[chat] startChat failed:", err);
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
        style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 16px)", flexShrink: 0, paddingBottom: "8px" }}
      >
        <div className="mx-auto relative" style={{ maxWidth: layout.maxWidth }}>
          
          {/* ── User Profile: Anchored top-right above tabs ── */}
          <div style={{ position: "absolute", top: 0, right: 0, zIndex: 20 }}>
            <UserMenu userName={userName} userId={userId} />
          </div>

          <div className="flex gap-6" style={{ marginTop: "40px", alignItems: "center" }}>
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
                <InviteSurface userName={userName} />
              ) : (
                <>
                  <PeopleDock
                    userId={userId}
                    userName={userName}
                    onPersonTap={handlePersonTap}
                  />
                  <InviteAnother userName={userName} />
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
              onClick={() => { setShowNewSheet(false); setShowPhoneInput(false); setShowGroupInput(false); setPhoneNumber(""); setContactCheckStatus("idle"); }}
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

                {!showPhoneInput && !showGroupInput && (
                  <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
                    {/* Path A: Android — Contact Picker API */}
                    {hasContactPicker && (
                      <div
                        role="button"
                        tabIndex={0}
                        onClick={handleContactPick}
                        onKeyDown={(e) => { if (e.key === "Enter") handleContactPick(); }}
                        className="outline-none cursor-pointer"
                        style={{ padding: "14px 0", display: "flex", alignItems: "center", gap: "14px" }}
                      >
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={colors.accent} strokeWidth="1.5" strokeLinecap="round">
                          <rect x="3" y="4" width="18" height="18" rx="2" />
                          <circle cx="12" cy="10" r="3" />
                          <path d="M7 20v-1a5 5 0 0110 0v1" />
                        </svg>
                        <span style={{ ...text.body, color: colors.accent }}>Pick from Contacts</span>
                      </div>
                    )}
                    {/* Path B: Phone number input (iOS fallback + universal) */}
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={() => { setShowPhoneInput(true); setContactCheckStatus("idle"); }}
                      onKeyDown={(e) => { if (e.key === "Enter") { setShowPhoneInput(true); setContactCheckStatus("idle"); } }}
                      className="outline-none cursor-pointer"
                      style={{ padding: "14px 0", display: "flex", alignItems: "center", gap: "14px" }}
                    >
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={ink.primary} strokeWidth="1.5" strokeLinecap="round">
                        <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6A19.79 19.79 0 012.12 4.18 2 2 0 014.11 2h3a2 2 0 012 1.72 12.84 12.84 0 00.7 2.81 2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45 12.84 12.84 0 002.81.7A2 2 0 0122 16.92z" />
                      </svg>
                      <span style={{ ...text.body, color: ink.primary }}>New Chat</span>
                    </div>
                    {/* Invite link — always available */}
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={async () => {
                        try { await generateAndShareInvite(userName); } catch { /* cancelled */ }
                      }}
                      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") generateAndShareInvite(userName).catch(() => {}); }}
                      className="outline-none cursor-pointer"
                      style={{ padding: "14px 0", display: "flex", alignItems: "center", gap: "14px" }}
                    >
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={ink.primary} strokeWidth="1.5" strokeLinecap="round">
                        <path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71" />
                        <path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71" />
                      </svg>
                      <span style={{ ...text.body, color: ink.primary }}>Send Invite Link</span>
                    </div>
                    {/* New Group */}
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

                {/* Phone number input — check if registered */}
                {showPhoneInput && (
                  <div>
                    <p style={{ ...text.label, color: ink.tertiary, marginBottom: "12px", textTransform: "uppercase", letterSpacing: "0.05em" }}>Phone Number</p>
                    <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
                      <input
                        type="tel"
                        value={phoneNumber}
                        onChange={(e) => { setPhoneNumber(e.target.value); setContactCheckStatus("idle"); }}
                        onKeyDown={(e) => { if (e.key === "Enter" && phoneNumber.replace(/\D/g, "").length >= 7) checkPhoneAndChat(phoneNumber); }}
                        placeholder="+91 97417 83444"
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
                      {phoneNumber.replace(/\D/g, "").length >= 7 && contactCheckStatus !== "checking" && (
                        <div
                          role="button"
                          tabIndex={0}
                          onClick={() => checkPhoneAndChat(phoneNumber)}
                          className="outline-none cursor-pointer"
                        >
                          <SendIcon color="#FF6B35" size={28} />
                        </div>
                      )}
                    </div>
                    {contactCheckStatus === "checking" && (
                      <p style={{ ...text.hint, color: ink.tertiary, marginTop: "8px" }}>checking...</p>
                    )}
                    {contactCheckStatus === "not_found" && (
                      <div style={{ marginTop: "12px" }}>
                        <p style={{ ...text.hint, color: ink.secondary, marginBottom: "12px" }}>Not on Xark yet</p>
                        <div
                          role="button"
                          tabIndex={0}
                          onClick={async () => {
                            try { await generateAndShareInvite(userName); setShowNewSheet(false); setShowPhoneInput(false); setPhoneNumber(""); setContactCheckStatus("idle"); } catch { /* cancelled */ }
                          }}
                          onKeyDown={(e) => { if (e.key === "Enter") generateAndShareInvite(userName).catch(() => {}); }}
                          className="outline-none cursor-pointer"
                          style={{ padding: "10px 0", display: "flex", alignItems: "center", gap: "12px" }}
                        >
                          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={colors.accent} strokeWidth="1.5" strokeLinecap="round">
                            <path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71" />
                            <path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71" />
                          </svg>
                          <span style={{ ...text.body, color: colors.accent }}>Send invite link instead</span>
                        </div>
                      </div>
                    )}
                    {contactCheckStatus === "found" && (
                      <p style={{ ...text.hint, color: colors.accent, marginTop: "8px" }}>found — opening chat...</p>
                    )}
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
