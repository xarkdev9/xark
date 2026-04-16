"use client";

// hello OS v2.0 — GALAXY PAGE
// Tab toggle: People | Plans. Dream input fixed above ControlCaret.

import { Suspense, useState, useCallback, useRef, useEffect, type TouchEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { AwarenessStream } from "@/components/os/AwarenessStream";
import { PeopleDock } from "@/components/os/PeopleDock";
import { MemoriesTab } from "@/components/os/MemoriesTab";
import { useAuth } from "@/hooks/useAuth";
import { createSpace } from "@/lib/spaces";
import { colors, layout, text, surface, ink } from "@/lib/theme";
import { makeUserId } from "@/lib/user-id";
import { UserMenu } from "@/components/os/UserMenu";
import { getPlaygroundSpaces, isPlaygroundSpace } from "@/lib/playground";
import { supabase, getSupabaseToken } from "@/lib/supabase";
import { InviteSurface, generateAndShareInvite } from "@/components/os/InviteSurface";
import { useE2EE } from "@/hooks/useE2EE";

type GalaxyTab = "chats" | "groups" | "memories";

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
  const [activeTab, setActiveTab] = useState<GalaxyTab>("chats");
  const [tabDirection, setTabDirection] = useState(0);

  const userId = user?.uid ?? makeUserId("name", userName);

  // ── E2EE key registration at app boot — ensures keys exist before any chat ──
  useE2EE(userId ?? null);

  const [isCreating, setIsCreating] = useState(false);
  // ── Legacy migration: prompt users stuck with numeric display_name ──
  const [showNamePrompt, setShowNamePrompt] = useState(false);
  const [newDisplayName, setNewDisplayName] = useState("");
  useEffect(() => {
    const dn = user?.displayName ?? userName;
    if (dn && (/^\d{1,4}$/.test(dn) || dn === "new user")) setShowNamePrompt(true);
  }, [user, userName]);

  // New chat/group flow
  const [showNewSheet, setShowNewSheet] = useState(false);

  // ── Listen for Thumb Arc 'Compose' trigger ──
  useEffect(() => {
    const handleCompose = () => setShowNewSheet(true);
    if (typeof window !== "undefined") {
      window.addEventListener("hello-compose", handleCompose);
      return () => window.removeEventListener("hello-compose", handleCompose);
    }
  }, []);
  const [showPhoneInput, setShowPhoneInput] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [contactCheckStatus, setContactCheckStatus] = useState<"idle" | "checking" | "found" | "not_found" | "error">("idle");
  const [showGroupInput, setShowGroupInput] = useState(false);
  const [groupName, setGroupName] = useState("");
  // Spaces count (for onboarding)
  const [spacesCount, setSpacesCount] = useState<number | null>(null);
  // Playground spaces — computed client-side only (uses Date.now())
  // Playground spaces disabled — real onboarding replaces ghost demo
  const pgSpaces: ReturnType<typeof getPlaygroundSpaces> = [];

  useEffect(() => {
    if (!userId) return;
    // Fetch only the total space count (lightning fast head query) to determine UI empty state
    supabase.from('space_members')
      .select('space_id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .then(({ count }) => {
        setSpacesCount(count ?? 0);
      });
  }, [userId]);

  // Detect Contact Picker API support (Android Chrome)
  const hasContactPicker = typeof navigator !== "undefined" && "contacts" in navigator && "ContactsManager" in window;

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
      setContactCheckStatus("error");
    }
  }, [handlePersonTap]);

  // Handle Contact Picker API result (Android)
  const handleContactPick = useCallback(async () => {
    try {
      // Guard: Contact Picker API is not available on all browsers
      if (!('contacts' in navigator) || !(navigator as any).contacts?.select) {
        // Fallback: show phone input instead
        setShowPhoneInput(true);
        return;
      }

      const contacts = await (navigator as any).contacts.select(
        ["name", "tel"],
        { multiple: false }
      );
      if (!contacts?.[0]) return;

      const contact = contacts[0];
      const contactName = (contact.name?.[0] ?? "").trim();
      const phone = contact.tel?.[0] ?? "";
      if (!phone) return;

      // Progressive Sync: save contact name to local IndexedDB cache
      if (contactName && phone) {
        const cleanPhone = phone.replace(/\D/g, "").slice(-10);
        import("@/lib/crypto/keystore").then(({ keyStore }) => {
          keyStore.saveLocalContact(cleanPhone, contactName).catch(() => {});
        });
      }

      await checkPhoneAndChat(phone, contactName);
    } catch {
      // User cancelled, API not supported, or browser crashed — fallback to phone input
      setShowPhoneInput(true);
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

  // ── Swipe to switch tabs ──
  const tabs: GalaxyTab[] = ["chats", "groups", "memories"];
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
      {/* ── Header: UserMenu row + Tab row ── */}
      <div
        className="relative z-10 px-6"
        style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 16px)", flexShrink: 0 }}
      >
        <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
          {/* ── Title Row: hello brand + UserMenu ── */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingBottom: "12px" }}>
            <span className="hello-text-led" style={{
              fontSize: "28px",
              fontWeight: 400,
              letterSpacing: "-0.03em",
            }}>
              hello
            </span>
            <UserMenu userName={userName} userId={userId} />
          </div>

          {/* ── Tabs: People | Plans | Memories — Liquid Fire underline ── */}
          <div className="flex gap-6" style={{ alignItems: "center", paddingBottom: "8px" }}>
          {(["chats", "groups", "memories"] as GalaxyTab[]).map((tab) => {
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
                  position: "relative",
                  color: isActive ? ink.primary : ink.tertiary,
                  opacity: isActive ? 1 : 0.6,
                  fontWeight: 400,
                  fontSize: "15px",
                  letterSpacing: "0.06em",
                  transition: "all 0.3s ease",
                  paddingBottom: "10px",
                  textTransform: "capitalize",
                }}
              >
                {tab}
                <span
                  className={isActive ? "hello-bg-led" : ""}
                  style={{
                    position: "absolute",
                    bottom: 0,
                    left: "5%",
                    width: "90%",
                    height: "2.5px",
                    borderRadius: "2px",
                    background: isActive ? undefined : "transparent",
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
        style={{ flex: 1, overflowY: "auto", paddingTop: "12px", paddingBottom: "100px" }}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
      >
        <AnimatePresence mode="wait" custom={tabDirection}>
          {activeTab === "chats" && (
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
          {activeTab === "groups" && (
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

      {/* ── Legacy Name Migration Prompt ── */}
      {showNamePrompt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ backgroundColor: "rgba(0,0,0,0.8)" }}>
          <div style={{ background: surface.canvas, borderRadius: "16px", padding: "24px", margin: "24px", maxWidth: "320px", width: "100%" }}>
            <p style={{ fontSize: "17px", fontWeight: 400, color: ink.primary, marginBottom: "4px" }}>what should people call you?</p>
            <p style={{ fontSize: "13px", color: ink.tertiary, marginBottom: "16px" }}>this name will appear in chats</p>
            <form onSubmit={async (e) => {
              e.preventDefault();
              const trimmed = newDisplayName.trim().toLowerCase();
              if (!trimmed || trimmed.length < 2) return;
              try {
                const { supabase: supa } = await import("@/lib/supabase");
                await supa.from("users").update({ display_name: trimmed }).eq("id", userId);
                setShowNamePrompt(false);
                // Reload to pick up new name
                window.location.reload();
              } catch { /* silent */ }
            }}>
              <input
                type="text"
                value={newDisplayName}
                onChange={(e) => setNewDisplayName(e.target.value)}
                placeholder="your name"
                autoFocus
                className="w-full outline-none"
                style={{
                  fontSize: "16px", fontWeight: 400, color: ink.primary,
                  backgroundColor: surface.recessed, borderRadius: "10px",
                  padding: "10px 14px", marginBottom: "12px",
                }}
              />
              <button
                type="submit"
                style={{
                  width: "100%", padding: "10px", borderRadius: "10px",
                  backgroundColor: "#FF6B35", color: "#FFFFFF",
                  fontSize: "15px", fontWeight: 400, border: "none", cursor: "pointer",
                }}
              >
                save
              </button>
            </form>
          </div>
        </div>
      )}

      {/* ── Bottom Bar: Search + Compose — iMessage style ── */}
      <div
        className="fixed inset-x-0"
        style={{
          bottom: 0,
          zIndex: 40,
          display: showNewSheet ? "none" : undefined,
          paddingBottom: "max(env(safe-area-inset-bottom, 0px), 8px)",
          paddingTop: "8px",
          paddingLeft: "16px",
          paddingRight: "16px",
          background: `linear-gradient(to top, ${surface.canvas} 70%, transparent)`,
        }}
      >
        <div className="mx-auto flex items-center gap-3" style={{ maxWidth: layout.maxWidth }}>
          <div style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            gap: "8px",
            backgroundColor: surface.recessed,
            borderRadius: "20px",
            padding: "10px 14px",
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={ink.tertiary} strokeWidth="2" strokeLinecap="round">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="search..."
              className="w-full bg-transparent outline-none"
              style={{
                fontSize: "15px",
                fontWeight: 400,
                color: ink.primary,
                letterSpacing: "0.02em",
              }}
            />
          </div>
          <button
            onClick={() => window.dispatchEvent(new CustomEvent("hello-compose"))}
            className="hello-bg-led outline-none cursor-pointer flex items-center justify-center"
            style={{
              flexShrink: 0,
              width: "44px",
              height: "44px",
              borderRadius: "50%",
              fontSize: "24px",
              fontWeight: 300,
              lineHeight: 1,
              boxShadow: "0 2px 12px rgba(255, 107, 53, 0.3)",
              WebkitTapHighlightColor: "transparent",
              border: "none",
            }}
          >
            +
          </button>
        </div>
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
                  <div style={{ display: "flex", flexDirection: "column", gap: "0" }}>
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
                    <form
                      onSubmit={(e) => {
                        e.preventDefault();
                        if (phoneNumber.replace(/\D/g, "").length >= 3 && contactCheckStatus !== "checking") {
                          checkPhoneAndChat(phoneNumber);
                        }
                      }}
                      style={{ display: "flex", gap: "10px", alignItems: "center" }}
                    >
                      <input
                        type="tel"
                        value={phoneNumber}
                        onChange={(e) => { setPhoneNumber(e.target.value); setContactCheckStatus("idle"); }}
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
                      {phoneNumber.replace(/\D/g, "").length >= 3 && contactCheckStatus !== "checking" && (
                        <button
                          type="submit"
                          style={{
                            background: "none",
                            border: "none",
                            padding: 0,
                            cursor: "pointer",
                            outline: "none"
                          }}
                        >
                          <SendIcon color="#FF6B35" size={28} />
                        </button>
                      )}
                    </form>
                    {contactCheckStatus === "checking" && (
                      <p style={{ ...text.hint, color: ink.tertiary, marginTop: "8px" }}>checking...</p>
                    )}
                    {contactCheckStatus === "error" && (
                      <p style={{ ...text.hint, color: colors.amber, marginTop: "8px" }}>network error — please try again</p>
                    )}
                    {contactCheckStatus === "not_found" && (
                      <div style={{ marginTop: "12px" }}>
                        <p style={{ ...text.hint, color: ink.secondary, marginBottom: "12px" }}>Not on Hello yet</p>
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
                    <form
                      onSubmit={(e) => {
                        e.preventDefault();
                        if (groupName.trim()) handleNewGroup();
                      }}
                      style={{ display: "flex", gap: "10px", alignItems: "center" }}
                    >
                      <input
                        type="text"
                        value={groupName}
                        onChange={(e) => setGroupName(e.target.value)}
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
                        <button
                          type="submit"
                          style={{
                            background: "none",
                            border: "none",
                            padding: 0,
                            cursor: "pointer",
                            outline: "none"
                          }}
                        >
                          <SendIcon color="#FF6B35" size={28} />
                        </button>
                      )}
                    </form>
                  </div>
                )}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>


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
