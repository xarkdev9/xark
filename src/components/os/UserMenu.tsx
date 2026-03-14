"use client";

import { useState, useEffect, useRef } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { useThemeContext } from "./ThemeProvider";
import { colors, opacity, timing, text, themes, layout, textColor } from "@/lib/theme";
import { supabase, setSupabaseToken } from "@/lib/supabase";
import { auth, storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import type { ThemeName } from "@/lib/theme";

const THEME_NAMES: ThemeName[] = ["hearth"];

type SettingsView = "main" | "profile" | "system";

const slideVariants = {
  enter: (dir: number) => ({ x: dir > 0 ? 60 : -60, opacity: 0 }),
  center: { x: 0, opacity: 1 },
  exit: (dir: number) => ({ x: dir > 0 ? -60 : 60, opacity: 0 }),
};

export function UserMenu() {
  const [isOpen, setIsOpen] = useState(false);
  const [view, setView] = useState<SettingsView>("main");
  const [direction, setDirection] = useState(1);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [nameSaved, setNameSaved] = useState(false);
  const [photoUploading, setPhotoUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const searchParams = useSearchParams();
  const router = useRouter();
  const userName = searchParams.get("name") ?? "";
  const { theme, setTheme } = useThemeContext();

  const letter = (userName[0] ?? "?").toUpperCase();

  // Fetch profile photo if available
  useEffect(() => {
    if (!userName) return;
    const userId = `name_${userName.toLowerCase()}`;
    supabase
      .from("users")
      .select("photo_url")
      .eq("id", userId)
      .single()
      .then(({ data }) => {
        if (data?.photo_url) setPhotoUrl(data.photo_url);
      });
  }, [userName]);

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

  const drillIn = (target: SettingsView) => {
    setDirection(1);
    setView(target);
  };

  const drillBack = () => {
    setDirection(-1);
    setView("main");
  };

  const handleLogout = async () => {
    try {
      if (auth) {
        const { signOut } = await import("firebase/auth");
        await signOut(auth);
      }
    } catch {}
    setSupabaseToken(null);
    router.push("/login");
  };

  const handleNameSave = async () => {
    const trimmed = editName.trim();
    if (!trimmed || trimmed === userName) return;
    const userId = `name_${userName.toLowerCase()}`;
    await supabase
      .from("users")
      .update({ display_name: trimmed })
      .eq("id", userId);
    setNameSaved(true);
    setTimeout(() => setNameSaved(false), 1500);
  };

  const handlePhotoSelect = async (file: File) => {
    if (!storage) return;
    if (file.size > 2 * 1024 * 1024) {
      console.warn("Photo too large (max 2MB)");
      return;
    }
    setPhotoUploading(true);
    try {
      const userId = `name_${userName.toLowerCase()}`;
      const storagePath = `profiles/${userId}/avatar`;
      const storageRef = ref(storage, storagePath);
      await uploadBytes(storageRef, file);
      const downloadUrl = await getDownloadURL(storageRef);
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
      <div className="flex items-center gap-3">
        <Avatar size={28} />
        <p
          style={{
            ...text.body,
            color: colors.white,
            opacity: opacity.primary,
          }}
        >
          {userName || "anonymous"}
        </p>
      </div>

      <div style={{ marginTop: "14px", display: "flex", flexDirection: "column", gap: "6px" }}>
        <span
          role="button"
          tabIndex={0}
          onClick={() => drillIn("profile")}
          onKeyDown={(e) => { if (e.key === "Enter") drillIn("profile"); }}
          className="cursor-pointer outline-none"
          style={{
            ...text.body,
            color: textColor(0.5),
            transition: `color ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.8); }}
          onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.5); }}
        >
          profile
        </span>

        <span
          role="button"
          tabIndex={0}
          onClick={() => drillIn("system")}
          onKeyDown={(e) => { if (e.key === "Enter") drillIn("system"); }}
          className="cursor-pointer outline-none"
          style={{
            ...text.body,
            color: textColor(0.5),
            transition: `color ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.8); }}
          onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.5); }}
        >
          system
        </span>
      </div>

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
          color: colors.white,
          opacity: opacity.quaternary,
          transition: `opacity ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.opacity = String(opacity.tertiary); }}
        onMouseLeave={(e) => { e.currentTarget.style.opacity = String(opacity.quaternary); }}
      >
        log out
      </span>
    </motion.div>
  );

  // ── Sub-view: Profile ──
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
          color: textColor(0.25),
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.4); }}
        onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.25); }}
      >
        back
      </span>

      <div style={{ marginTop: "14px", display: "flex", flexDirection: "column", gap: "12px" }}>
        <Avatar size={48} />

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

        {!photoUploading ? (
          <span
            role="button"
            tabIndex={0}
            onClick={() => fileRef.current?.click()}
            onKeyDown={(e) => { if (e.key === "Enter") fileRef.current?.click(); }}
            className="cursor-pointer outline-none"
            style={{
              ...text.hint,
              color: colors.white,
              opacity: 0.35,
              transition: `opacity ${timing.transition} ease`,
            }}
            onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.6"; }}
            onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.35"; }}
          >
            change photo
          </span>
        ) : (
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
            <span
              style={{
                ...text.hint,
                color: colors.white,
                opacity: 0.4,
              }}
            >
              uploading
            </span>
          </div>
        )}

        {/* Name input */}
        <div className="relative" style={{ marginTop: "4px" }}>
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
              ...text.input,
              color: colors.white,
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
            color: colors.white,
            opacity: nameSaved ? 0.4 : 0,
            transition: `opacity ${timing.transition} ease`,
          }}
        >
          saved
        </span>
      </div>
    </motion.div>
  );

  // ── Sub-view: System ──
  const SystemView = (
    <motion.div
      key="system"
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
          color: textColor(0.25),
          transition: `color ${timing.transition} ease`,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.4); }}
        onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.25); }}
      >
        back
      </span>

      <div
        className="flex flex-wrap items-center gap-x-4 gap-y-1"
        style={{ marginTop: "14px" }}
      >
        {THEME_NAMES.map((name) => {
          const t = themes[name];
          const isActive = theme === name;
          return (
            <div
              key={name}
              role="button"
              tabIndex={0}
              onClick={() => setTheme(name)}
              onKeyDown={(e) => { if (e.key === "Enter") setTheme(name); }}
              className="flex cursor-pointer items-center gap-1.5 outline-none"
              style={{ padding: "4px 0" }}
            >
              <div
                style={{
                  width: "5px",
                  height: "5px",
                  borderRadius: "50%",
                  backgroundColor: t.accent,
                  opacity: isActive ? 1 : 0.35,
                  transition: `opacity ${timing.transition} ease`,
                  flexShrink: 0,
                }}
              />
              <span
                style={{
                  ...text.recency,
                  color: isActive ? t.accent : colors.white,
                  opacity: isActive ? 0.8 : opacity.tertiary,
                  transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                }}
              >
                {t.label}
              </span>
            </div>
          );
        })}
      </div>
    </motion.div>
  );

  return (
    <>
      {/* ── Avatar trigger — hidden when sheet is open ── */}
      <div
        className="fixed left-6 top-6 z-[70]"
        style={{
          opacity: isOpen ? 0 : 0.6,
          pointerEvents: isOpen ? "none" : "auto",
          transition: `opacity ${timing.transition} ease`,
        }}
      >
        <div
          role="button"
          tabIndex={0}
          onClick={() => setIsOpen(true)}
          onKeyDown={(e) => {
            if (e.key === "Enter") setIsOpen(true);
          }}
          className="cursor-pointer outline-none"
          onMouseEnter={(e) => {
            e.currentTarget.parentElement!.style.opacity = "1";
          }}
          onMouseLeave={(e) => {
            if (!isOpen) e.currentTarget.parentElement!.style.opacity = "0.6";
          }}
        >
          <Avatar size={32} />
        </div>
      </div>

      {/* ── Settings sheet — slides down from top ── */}
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
                overflow: "hidden",
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
                  {view === "system" && SystemView}
                </AnimatePresence>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}
