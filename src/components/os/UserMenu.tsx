"use client";

// XARK OS v2.0 — USER MENU
// 4-view drill-in sheet: main → profile, notifications, about.
// Props-based (userName, userId) — no longer reads from searchParams.
// Theme toggles inline on main (flat/vibe + light/dark).
// FCM wiring in notifications view. Theme persistence to Supabase.
// Profile view: immersive card-like layout with large centered avatar.

import { useState, useEffect, useRef, useCallback } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { useThemeContext } from "./ThemeProvider";
import { colors, opacity, timing, text, themes, layout, ink, accentColor } from "@/lib/theme";
import { supabase, setSupabaseToken } from "@/lib/supabase";
import { auth } from "@/lib/firebase";
import { getMessagingInstance } from "@/lib/firebase";
import { storageAdapter } from "@/lib/storage";
import type { ThemeName, ThemeStyle } from "@/lib/theme";

type SettingsView = "main" | "profile" | "notifications" | "about";

interface UserMenuProps {
  userName: string;
  userId: string;
}

const slideVariants = {
  enter: (dir: number) => ({ x: dir > 0 ? 60 : -60, opacity: 0 }),
  center: { x: 0, opacity: 1 },
  exit: (dir: number) => ({ x: dir > 0 ? -60 : 60, opacity: 0 }),
};

// Map style + mode to theme name
function resolveTheme(style: ThemeStyle, mode: "light" | "dark"): ThemeName {
  if (style === "flat" && mode === "light") return "hearth";
  if (style === "flat" && mode === "dark") return "hearth_dark";
  if (style === "depth" && mode === "light") return "vibe";
  return "vibe_dark";
}

export function UserMenu({ userName, userId }: UserMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [view, setView] = useState<SettingsView>("main");
  const [direction, setDirection] = useState(1);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [phone, setPhone] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [nameSaved, setNameSaved] = useState(false);
  const [photoUploading, setPhotoUploading] = useState(false);
  const [photoError, setPhotoError] = useState<string | null>(null);
  const [inviteCopied, setInviteCopied] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const router = useRouter();
  const { theme, setTheme } = useThemeContext();

  // Notifications state
  const [notificationsEnabled, setNotificationsEnabled] = useState(false);
  const [notifWhisper, setNotifWhisper] = useState<string | null>(null);
  const [mutedSpaces, setMutedSpaces] = useState<string[]>([]);
  const [userSpaces, setUserSpaces] = useState<Array<{ id: string; title: string }>>([]);
  const [spacesLoading, setSpacesLoading] = useState(false);

  const letter = (userName[0] ?? "?").toUpperCase();
  const displayName = userName ? userName.charAt(0).toUpperCase() + userName.slice(1) : "Anonymous";

  // Derive current style/mode from theme
  const currentStyle = themes[theme].style;
  const currentMode = themes[theme].mode;

  // ── Sync theme to Supabase (fresh-fetch-before-write) ──
  const syncThemeToDb = useCallback(async (newTheme: ThemeName) => {
    if (!userId) return;
    const { data: fresh } = await supabase
      .from("users")
      .select("preferences")
      .eq("id", userId)
      .single();
    const currentPrefs = (fresh?.preferences as Record<string, unknown>) ?? {};
    supabase.from("users").update({
      preferences: { ...currentPrefs, theme: newTheme }
    }).eq("id", userId).then(() => {});
  }, [userId]);

  // ── Theme toggle handlers ──
  const handleStyleToggle = useCallback((style: ThemeStyle) => {
    const newTheme = resolveTheme(style, currentMode);
    setTheme(newTheme);
    syncThemeToDb(newTheme);
  }, [currentMode, setTheme, syncThemeToDb]);

  const handleModeToggle = useCallback((mode: "light" | "dark") => {
    const newTheme = resolveTheme(currentStyle, mode);
    setTheme(newTheme);
    syncThemeToDb(newTheme);
  }, [currentStyle, setTheme, syncThemeToDb]);

  // Fetch profile data on mount
  useEffect(() => {
    if (!userId) return;
    supabase
      .from("users")
      .select("photo_url, phone, preferences")
      .eq("id", userId)
      .single()
      .then(({ data }) => {
        if (data?.photo_url) setPhotoUrl(data.photo_url);
        if (data?.phone) setPhone(data.phone);
        const prefs = data?.preferences as Record<string, unknown> | null;
        if (prefs?.muted_spaces && Array.isArray(prefs.muted_spaces)) {
          setMutedSpaces(prefs.muted_spaces as string[]);
        }
        // Cross-device theme sync: if localStorage is empty, use DB value
        const localTheme = localStorage.getItem("xark-theme");
        if (!localTheme && prefs?.theme) {
          setTheme(prefs.theme as ThemeName);
        }
      });
  }, [userId, setTheme]);

  // Check if notifications are enabled (has FCM token)
  useEffect(() => {
    if (!userId) return;
    supabase
      .from("user_devices")
      .select("fcm_token")
      .eq("user_id", userId)
      .then(({ data }) => {
        setNotificationsEnabled((data ?? []).length > 0);
      });
  }, [userId]);

  // Reset view on close
  useEffect(() => {
    if (!isOpen) {
      const t = setTimeout(() => {
        setView("main");
        setDirection(1);
      }, 300);
      return () => clearTimeout(t);
    } else {
      setEditName(userName);
    }
  }, [isOpen, userName]);

  // Fetch spaces when notifications view opens
  useEffect(() => {
    if (view !== "notifications" || !userId) return;
    setSpacesLoading(true);
    supabase
      .from("space_members")
      .select("space_id, spaces(title)")
      .eq("user_id", userId)
      .then(({ data, error }) => {
        if (error) {
          setSpacesLoading(false);
          return;
        }
        const spaces = (data ?? []).map((row: Record<string, unknown>) => ({
          id: row.space_id as string,
          title: ((row.spaces as Record<string, unknown>)?.title as string) ?? "untitled",
        }));
        setUserSpaces(spaces);
        setSpacesLoading(false);
      });
  }, [view, userId]);

  const drillIn = (target: SettingsView) => {
    setDirection(1);
    setView(target);
  };

  const drillBack = () => {
    setDirection(-1);
    setView("main");
  };

  const handleLogout = async () => {
    // ── CRYPTOGRAPHIC SHREDDING — clear ALL local key material before navigation ──
    // Without this, a shared device retains extractable private keys in IndexedDB.
    try {
      // 1. Clear the encrypted key store (identity keys, sessions, sender keys)
      const { keyStore } = await import("@/lib/crypto/keystore");
      await keyStore.clear();

      // 2. Delete the entire keystore database
      await new Promise<void>((resolve) => {
        const req = indexedDB.deleteDatabase('xark-keystore');
        req.onsuccess = () => resolve();
        req.onerror = () => resolve(); // Best-effort — don't block logout
        req.onblocked = () => resolve();
      });

      // 3. Delete the outbox database (may contain encrypted message envelopes)
      await new Promise<void>((resolve) => {
        const req = indexedDB.deleteDatabase('xark-outbox');
        req.onsuccess = () => resolve();
        req.onerror = () => resolve();
        req.onblocked = () => resolve();
      });

      // 4. Lock the encrypted store (zero wrapping key from RAM)
      try {
        const { lockStore } = await import("@/lib/crypto/encrypted-store");
        lockStore();
      } catch {}

      // 5. Clear localStorage crypto artifacts
      localStorage.removeItem('xark_store_salt');
      localStorage.removeItem('xark_user_id');

      console.log('[xark-privacy] Local cryptographic state shredded');
    } catch (err) {
      console.error('[xark-privacy] IDB shred failed:', err);
      // Continue with logout even if shredding fails — don't trap the user
    }

    // 6. Sign out of Firebase Auth
    try {
      if (auth) {
        const { signOut } = await import("firebase/auth");
        await signOut(auth);
      }
    } catch {}

    // 7. Clear Supabase JWT
    setSupabaseToken(null);

    // 8. Navigate to login — AFTER IDB deletion completes
    router.push("/login");
  };

  const handleNameSave = async () => {
    const trimmed = editName.trim();
    if (!trimmed || trimmed === userName) return;
    await supabase
      .from("users")
      .update({ display_name: trimmed })
      .eq("id", userId);
    setNameSaved(true);
    setTimeout(() => setNameSaved(false), 1500);
  };

  const handlePhotoSelect = async (file: File) => {
    if (file.size > 2 * 1024 * 1024) {
      setPhotoError("Too large");
      setTimeout(() => setPhotoError(null), 1500);
      return;
    }
    setPhotoUploading(true);
    setPhotoError(null);
    try {
      const storagePath = `profiles/${userId}/avatar`;
      const downloadUrl = await storageAdapter.upload(storagePath, file);
      await supabase
        .from("users")
        .update({ photo_url: downloadUrl })
        .eq("id", userId);
      setPhotoUrl(downloadUrl);
    } catch (err) {
      console.error("Photo upload failed:", err);
    }
    setPhotoUploading(false);
  };

  const handleInvite = async () => {
    const shareData = { title: "xark", text: "decide together, effortlessly.", url: "https://getxark.com" };
    if (typeof navigator !== "undefined" && navigator.share) {
      try { await navigator.share(shareData); } catch {}
    } else if (typeof navigator !== "undefined" && navigator.clipboard) {
      await navigator.clipboard.writeText("https://getxark.com");
      setInviteCopied(true);
      setTimeout(() => setInviteCopied(false), 1500);
    }
  };

  // ── FCM notification handlers ──
  const handleNotificationEnable = async () => {
    if (typeof Notification === "undefined") return;
    const permission = await Notification.requestPermission();
    if (permission !== "granted") {
      setNotifWhisper("Blocked by browser");
      setTimeout(() => setNotifWhisper(null), 1500);
      return;
    }

    const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
    if (!vapidKey) return;

    const instance = await getMessagingInstance();
    if (!instance) return;

    const { messaging, getToken: getTokenFn } = instance;
    try {
      const token = await getTokenFn(messaging, { vapidKey });
      await supabase.from("user_devices").upsert(
        { user_id: userId, fcm_token: token, platform: "web" },
        { onConflict: "user_id,fcm_token" }
      );
      setNotificationsEnabled(true);
    } catch {
      setNotifWhisper("Setup failed");
      setTimeout(() => setNotifWhisper(null), 1500);
    }
  };

  const handleNotificationDisable = async () => {
    await supabase.from("user_devices").delete().eq("user_id", userId);
    setNotificationsEnabled(false);
  };

  const toggleMuteSpace = async (spaceId: string, currentlyMuted: boolean) => {
    const newMuted = currentlyMuted
      ? mutedSpaces.filter((id) => id !== spaceId)
      : [...mutedSpaces, spaceId];
    setMutedSpaces(newMuted);

    const { data: fresh } = await supabase
      .from("users")
      .select("preferences")
      .eq("id", userId)
      .single();
    const currentPrefs = (fresh?.preferences as Record<string, unknown>) ?? {};

    await supabase
      .from("users")
      .update({ preferences: { ...currentPrefs, muted_spaces: newMuted } })
      .eq("id", userId);
  };

  const Avatar = ({ size }: { size: number }) => (
    <div
      className="overflow-hidden"
      style={{
        width: `${size}px`,
        height: `${size}px`,
        borderRadius: "50%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: photoUrl ? "transparent" : "rgba(var(--xark-white-rgb), 0.06)",
        flexShrink: 0,
      }}
    >
      {photoUrl ? (
        <img
          src={photoUrl}
          alt={userName}
          style={{
            width: `${size}px`,
            height: `${size}px`,
            borderRadius: "50%",
            objectFit: "cover",
          }}
        />
      ) : (
        <span
          style={{
            fontSize: `${Math.round(size * 0.4)}px`,
            color: colors.white,
            opacity: 0.5,
            letterSpacing: 0,
          }}
        >
          {letter}
        </span>
      )}
    </div>
  );

  // ── Sub-view: Main ──
  const MainView = (
    <motion.div
      key="main"
      custom={direction}
      variants={slideVariants}
      initial="enter"
      animate="center"
      exit="exit"
      transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
    >
      {/* Profile card — taps to drill into profile */}
      <div
        role="button"
        tabIndex={0}
        onClick={() => drillIn("profile")}
        onKeyDown={(e) => { if (e.key === "Enter") drillIn("profile"); }}
        className="flex items-center gap-3 cursor-pointer outline-none"
      >
        <Avatar size={48} />
        <div>
          <p style={{ ...text.body, color: ink.primary }}>
            {displayName}
          </p>
          {phone && (
            <p style={{ ...text.recency, color: ink.tertiary }}>
              {phone}
            </p>
          )}
        </div>
      </div>

      {/* Theme toggles — inline */}
      <div style={{ marginTop: "18px", display: "flex", flexDirection: "column", gap: "6px" }}>
        {/* Style axis: Flat · Vibe */}
        <div className="flex items-center gap-3">
          {(["flat", "depth"] as ThemeStyle[]).map((s) => {
            const isActive = currentStyle === s;
            const label = s === "depth" ? "Vibe" : "Flat";
            return (
              <span
                key={s}
                role="button"
                tabIndex={0}
                onClick={() => handleStyleToggle(s)}
                onKeyDown={(e) => { if (e.key === "Enter") handleStyleToggle(s); }}
                className="cursor-pointer outline-none"
                style={{
                  ...text.recency,
                  color: isActive ? colors.cyan : ink.tertiary,
                  transition: `color ${timing.transition} ease`,
                }}
              >
                {label}
              </span>
            );
          })}
        </div>
        {/* Mode axis: Light · Dark */}
        <div className="flex items-center gap-3">
          {(["light", "dark"] as const).map((m) => {
            const isActive = currentMode === m;
            return (
              <span
                key={m}
                role="button"
                tabIndex={0}
                onClick={() => handleModeToggle(m)}
                onKeyDown={(e) => { if (e.key === "Enter") handleModeToggle(m); }}
                className="cursor-pointer outline-none"
                style={{
                  ...text.recency,
                  color: isActive ? colors.cyan : ink.tertiary,
                  transition: `color ${timing.transition} ease`,
                }}
              >
                {m.charAt(0).toUpperCase() + m.slice(1)}
              </span>
            );
          })}
        </div>
      </div>

      {/* Menu rows */}
      <div style={{ marginTop: "14px", display: "flex", flexDirection: "column", gap: "6px" }}>
        <span
          role="button"
          tabIndex={0}
          onClick={() => drillIn("notifications")}
          onKeyDown={(e) => { if (e.key === "Enter") drillIn("notifications"); }}
          className="cursor-pointer outline-none"
          style={{
            ...text.body,
            color: ink.secondary,
            transition: `color ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.color = ink.primary; }}
          onMouseLeave={(e) => { e.currentTarget.style.color = ink.secondary; }}
        >
          Notifications
        </span>

        <span
          role="button"
          tabIndex={0}
          onClick={handleInvite}
          onKeyDown={(e) => { if (e.key === "Enter") handleInvite(); }}
          className="cursor-pointer outline-none"
          style={{
            ...text.body,
            color: inviteCopied ? colors.cyan : ink.secondary,
            transition: `color ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { if (!inviteCopied) e.currentTarget.style.color = ink.primary; }}
          onMouseLeave={(e) => { if (!inviteCopied) e.currentTarget.style.color = ink.secondary; }}
        >
          {inviteCopied ? "Link copied" : "Invite a friend"}
        </span>

        <span
          role="button"
          tabIndex={0}
          onClick={() => drillIn("about")}
          onKeyDown={(e) => { if (e.key === "Enter") drillIn("about"); }}
          className="cursor-pointer outline-none"
          style={{
            ...text.body,
            color: ink.secondary,
            transition: `color ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.color = ink.primary; }}
          onMouseLeave={(e) => { e.currentTarget.style.color = ink.secondary; }}
        >
          About
        </span>
      </div>

      {/* Log out */}
      <span
        role="button"
        tabIndex={0}
        onClick={handleLogout}
        onKeyDown={(e) => { if (e.key === "Enter") handleLogout(); }}
        className="cursor-pointer outline-none"
        style={{
          ...text.recency,
          display: "inline-block",
          marginTop: "14px",
          color: ink.tertiary,
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = ink.secondary; }}
        onMouseLeave={(e) => { e.currentTarget.style.color = ink.tertiary; }}
      >
        Log out
      </span>
    </motion.div>
  );

  // ── Sub-view: Profile (immersive card-like layout) ──
  const ProfileView = (
    <motion.div
      key="profile"
      custom={direction}
      variants={slideVariants}
      initial="enter"
      animate="center"
      exit="exit"
      transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
    >
      <span
        role="button"
        tabIndex={0}
        onClick={drillBack}
        onKeyDown={(e) => { if (e.key === "Enter") drillBack(); }}
        className="cursor-pointer outline-none"
        style={{
          ...text.recency,
          color: ink.tertiary,
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = ink.secondary; }}
        onMouseLeave={(e) => { e.currentTarget.style.color = ink.tertiary; }}
      >
        Back
      </span>

      {/* Profile hero — centered avatar with ambient glow ring */}
      <div style={{
        marginTop: "24px",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: "16px",
      }}>
        {/* Avatar with glow ring */}
        <div
          role="button"
          tabIndex={0}
          onClick={() => fileRef.current?.click()}
          onKeyDown={(e) => { if (e.key === "Enter") fileRef.current?.click(); }}
          className="cursor-pointer outline-none"
          style={{ position: "relative" }}
        >
          {/* Ambient glow ring */}
          <div
            className="pointer-events-none"
            style={{
              position: "absolute",
              inset: "-8px",
              borderRadius: "50%",
              background: `radial-gradient(circle, ${accentColor(0.12)} 40%, transparent 70%)`,
              animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
            }}
          />
          {/* Outer ring */}
          <div
            className="pointer-events-none"
            style={{
              position: "absolute",
              inset: "-3px",
              borderRadius: "50%",
              background: `linear-gradient(135deg, ${accentColor(0.3)}, transparent 60%)`,
            }}
          />
          <Avatar size={88} />

          {/* Camera overlay on hover */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              background: "rgba(0, 0, 0, 0.3)",
              opacity: 0,
              transition: `opacity ${timing.transition} ease`,
            }}
            onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
            onMouseLeave={(e) => { e.currentTarget.style.opacity = "0"; }}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              <circle cx="12" cy="13" r="4" stroke="white" strokeWidth="1.5"/>
            </svg>
          </div>
        </div>

        {/* Hidden file input */}
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handlePhotoSelect(file);
            e.target.value = "";
          }}
        />

        {/* Upload status / change photo */}
        {photoUploading ? (
          <div className="flex items-center gap-3">
            <div
              style={{
                width: "6px",
                height: "6px",
                borderRadius: "50%",
                backgroundColor: colors.cyan,
                animation: "ambientBreath 4.5s ease-in-out infinite",
              }}
            />
            <span style={{ ...text.hint, color: ink.tertiary }}>
              Uploading
            </span>
          </div>
        ) : photoError ? (
          <span style={{ ...text.hint, color: colors.orange }}>
            {photoError}
          </span>
        ) : (
          <span
            role="button"
            tabIndex={0}
            onClick={() => fileRef.current?.click()}
            onKeyDown={(e) => { if (e.key === "Enter") fileRef.current?.click(); }}
            className="cursor-pointer outline-none"
            style={{
              ...text.hint,
              color: ink.tertiary,
              transition: `color ${timing.transition} ease`,
            }}
            onMouseEnter={(e) => { e.currentTarget.style.color = ink.secondary; }}
            onMouseLeave={(e) => { e.currentTarget.style.color = ink.tertiary; }}
          >
            Change photo
          </span>
        )}
      </div>

      {/* Name + phone section */}
      <div style={{ marginTop: "24px", display: "flex", flexDirection: "column", gap: "8px" }}>
        {/* Name input */}
        <div className="relative">
          <input
            type="text"
            value={editName}
            onChange={(e) => setEditName(e.target.value)}
            onBlur={handleNameSave}
            onKeyDown={(e) => { if (e.key === "Enter") handleNameSave(); }}
            spellCheck={false}
            autoComplete="off"
            className="w-full bg-transparent outline-none"
            style={{
              ...text.listTitle,
              color: ink.primary,
              caretColor: colors.cyan,
            }}
          />
          <div
            className="absolute -bottom-1 left-0 h-px"
            style={{
              width: "100%",
              background: `linear-gradient(90deg, ${colors.cyan}, transparent)`,
              opacity: opacity.rule,
            }}
          />
        </div>

        {/* Saved whisper */}
        <span
          style={{
            ...text.hint,
            color: colors.cyan,
            opacity: nameSaved ? 1 : 0,
            transition: `opacity ${timing.transition} ease`,
          }}
        >
          Saved
        </span>

        {/* Phone display (read-only) */}
        {phone && (
          <p style={{ ...text.body, color: ink.tertiary }}>
            {phone}
          </p>
        )}
      </div>
    </motion.div>
  );

  // ── Sub-view: Notifications ──
  const NotificationsView = (
    <motion.div
      key="notifications"
      custom={direction}
      variants={slideVariants}
      initial="enter"
      animate="center"
      exit="exit"
      transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
    >
      <span
        role="button"
        tabIndex={0}
        onClick={drillBack}
        onKeyDown={(e) => { if (e.key === "Enter") drillBack(); }}
        className="cursor-pointer outline-none"
        style={{
          ...text.recency,
          color: ink.tertiary,
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = ink.secondary; }}
        onMouseLeave={(e) => { e.currentTarget.style.color = ink.tertiary; }}
      >
        Back
      </span>

      {/* Master toggle */}
      <div className="flex items-center gap-3" style={{ marginTop: "14px" }}>
        {(["on", "off"] as const).map((opt) => {
          const isActive = opt === "on" ? notificationsEnabled : !notificationsEnabled;
          return (
            <span
              key={opt}
              role="button"
              tabIndex={0}
              onClick={() => opt === "on" ? handleNotificationEnable() : handleNotificationDisable()}
              onKeyDown={(e) => { if (e.key === "Enter") { opt === "on" ? handleNotificationEnable() : handleNotificationDisable(); }}}
              className="cursor-pointer outline-none"
              style={{
                ...text.recency,
                color: isActive ? colors.cyan : ink.tertiary,
                transition: `color ${timing.transition} ease`,
              }}
            >
              {opt.charAt(0).toUpperCase() + opt.slice(1)}
            </span>
          );
        })}
      </div>

      {/* Whisper */}
      {notifWhisper && (
        <span style={{ ...text.hint, color: ink.tertiary, marginTop: "6px", display: "block" }}>
          {notifWhisper}
        </span>
      )}

      {/* Per-space mute list — only when enabled */}
      {notificationsEnabled && (
        <div style={{ marginTop: "14px" }}>
          <span style={{ ...text.recency, color: ink.tertiary }}>
            Spaces
          </span>
          <div style={{ marginTop: "8px", display: "flex", flexDirection: "column", gap: "6px" }}>
            {spacesLoading ? (
              <div className="flex items-center gap-3">
                <div
                  style={{
                    width: "6px",
                    height: "6px",
                    borderRadius: "50%",
                    backgroundColor: colors.cyan,
                    animation: "ambientBreath 4.5s ease-in-out infinite",
                  }}
                />
                <span style={{ ...text.hint, color: ink.tertiary }}>
                  Loading
                </span>
              </div>
            ) : userSpaces.length === 0 ? (
              <span style={{ ...text.hint, color: ink.tertiary }}>
                No spaces yet
              </span>
            ) : (
              userSpaces.map((space) => {
                const isMuted = mutedSpaces.includes(space.id);
                return (
                  <div key={space.id} className="flex items-center justify-between">
                    <span style={{ ...text.body, color: ink.primary }}>
                      {space.title}
                    </span>
                    <span
                      role="button"
                      tabIndex={0}
                      onClick={() => toggleMuteSpace(space.id, isMuted)}
                      onKeyDown={(e) => { if (e.key === "Enter") toggleMuteSpace(space.id, isMuted); }}
                      className="cursor-pointer outline-none"
                      style={{
                        ...text.recency,
                        color: isMuted ? colors.orange : ink.tertiary,
                        transition: `color ${timing.transition} ease`,
                      }}
                    >
                      {isMuted ? "Muted" : "On"}
                    </span>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}
    </motion.div>
  );

  // ── Sub-view: About ──
  const AboutView = (
    <motion.div
      key="about"
      custom={direction}
      variants={slideVariants}
      initial="enter"
      animate="center"
      exit="exit"
      transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
    >
      <span
        role="button"
        tabIndex={0}
        onClick={drillBack}
        onKeyDown={(e) => { if (e.key === "Enter") drillBack(); }}
        className="cursor-pointer outline-none"
        style={{
          ...text.recency,
          color: ink.tertiary,
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = ink.secondary; }}
        onMouseLeave={(e) => { e.currentTarget.style.color = ink.tertiary; }}
      >
        Back
      </span>

      <div style={{ marginTop: "14px", display: "flex", flexDirection: "column", gap: "4px" }}>
        <span style={{ ...text.body, color: ink.primary }}>
          xark os
        </span>
        <span style={{ ...text.recency, color: ink.tertiary }}>
          v2.0
        </span>
      </div>

      <span
        role="button"
        tabIndex={0}
        onClick={() => window.open("mailto:feedback@xark.app")}
        onKeyDown={(e) => { if (e.key === "Enter") window.open("mailto:feedback@xark.app"); }}
        className="cursor-pointer outline-none"
        style={{
          ...text.body,
          display: "inline-block",
          marginTop: "14px",
          color: ink.secondary,
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = ink.primary; }}
        onMouseLeave={(e) => { e.currentTarget.style.color = ink.secondary; }}
      >
        Feedback
      </span>
    </motion.div>
  );

  return (
    <>
      {/* ── Avatar trigger — inline in Galaxy header, ambient glow ── */}
      <div
        role="button"
        tabIndex={0}
        onClick={() => setIsOpen(true)}
        onKeyDown={(e) => { if (e.key === "Enter") setIsOpen(true); }}
        className="cursor-pointer outline-none"
        style={{
          position: "relative",
          opacity: isOpen ? 0 : 0.8,
          pointerEvents: isOpen ? "none" : "auto",
          transition: `opacity ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
        onMouseLeave={(e) => { if (!isOpen) e.currentTarget.style.opacity = "0.8"; }}
      >
        {/* Ambient glow behind avatar */}
        <div
          className="pointer-events-none"
          style={{
            position: "absolute",
            inset: "-6px",
            borderRadius: "50%",
            background: `radial-gradient(circle, rgba(var(--xark-accent-rgb), 0.15) 0%, transparent 70%)`,
            animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
          }}
        />
        <Avatar size={32} />
      </div>

      {/* ── Settings sheet — portaled to body to escape parent stacking context ── */}
      {typeof document !== "undefined" && createPortal(
        <AnimatePresence>
          {isOpen && (
            <>
              {/* Overlay */}
              <motion.div
                className="fixed inset-0 z-[60]"
                style={{ background: colors.overlay }}
                initial={{ opacity: 0 }}
                animate={{ opacity: opacity.overlay }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.25 }}
                onClick={() => setIsOpen(false)}
              />

              {/* Sheet — full width, slides from top */}
              <motion.div
                className="fixed left-0 right-0 top-0 safe-top"
                style={{
                  zIndex: 65,
                  background: colors.void,
                  maxHeight: "80vh",
                  overflowY: "auto",
                }}
                initial={{ y: "-100%" }}
                animate={{ y: 0 }}
                exit={{ y: "-100%" }}
                transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
              >
                <div
                  className="mx-auto px-6 py-4"
                  style={{ maxWidth: layout.maxWidth }}
                >
                  <AnimatePresence mode="wait" custom={direction}>
                    {view === "main" && MainView}
                    {view === "profile" && ProfileView}
                    {view === "notifications" && NotificationsView}
                    {view === "about" && AboutView}
                  </AnimatePresence>
                </div>
              </motion.div>
            </>
          )}
        </AnimatePresence>,
        document.body
      )}
    </>
  );
}
