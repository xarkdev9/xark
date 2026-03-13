"use client";

import { useState, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { useThemeContext } from "./ThemeProvider";
import { colors, opacity, timing, layout, text, themes } from "@/lib/theme";
import { supabase } from "@/lib/supabase";
import type { ThemeName } from "@/lib/theme";

const THEME_NAMES: ThemeName[] = ["hearth", "signal", "ember"];

export function UserMenu() {
  const [isOpen, setIsOpen] = useState(false);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const searchParams = useSearchParams();
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

  return (
    <>
      {/* ── Avatar — fixed top-left, no border, no box ── */}
      <div
        className="fixed left-6 top-6 z-[70]"
      >
        <div
          role="button"
          tabIndex={0}
          onClick={() => setIsOpen((prev) => !prev)}
          onKeyDown={(e) => {
            if (e.key === "Enter") setIsOpen((prev) => !prev);
          }}
          className="cursor-pointer outline-none overflow-hidden"
          style={{
            width: "32px",
            height: "32px",
            borderRadius: "50%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: photoUrl ? "transparent" : "rgba(var(--xark-white-rgb), 0.06)",
            transition: `opacity ${timing.transition} ease`,
            opacity: isOpen ? 1 : 0.6,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
          onMouseLeave={(e) => { if (!isOpen) e.currentTarget.style.opacity = "0.6"; }}
        >
          {photoUrl ? (
            <img
              src={photoUrl}
              alt={userName}
              style={{
                width: "32px",
                height: "32px",
                borderRadius: "50%",
                objectFit: "cover",
              }}
            />
          ) : (
            <span
              style={{
                fontSize: "13px",
                color: colors.white,
                opacity: 0.5,
                letterSpacing: 0,
              }}
            >
              {letter}
            </span>
          )}
        </div>
      </div>

      {/* ── Settings Panel — slides down from top ── */}
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
              transition={{ duration: 0.3 }}
              onClick={() => setIsOpen(false)}
            />

            {/* Panel */}
            <motion.div
              className="fixed left-0 top-0 px-6 pt-16 pb-10"
              style={{
                zIndex: 65,
                width: "min(320px, 85vw)",
                background: colors.void,
              }}
              initial={{ x: "-100%" }}
              animate={{ x: 0 }}
              exit={{ x: "-100%" }}
              transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
            >
              {/* ── Profile section ── */}
              <div className="flex items-center gap-4">
                <div
                  className="overflow-hidden"
                  style={{
                    width: "48px",
                    height: "48px",
                    borderRadius: "50%",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    backgroundColor: photoUrl ? "transparent" : "rgba(var(--xark-white-rgb), 0.06)",
                  }}
                >
                  {photoUrl ? (
                    <img
                      src={photoUrl}
                      alt={userName}
                      style={{
                        width: "48px",
                        height: "48px",
                        borderRadius: "50%",
                        objectFit: "cover",
                      }}
                    />
                  ) : (
                    <span
                      style={{
                        fontSize: "20px",
                        color: colors.white,
                        opacity: 0.5,
                      }}
                    >
                      {letter}
                    </span>
                  )}
                </div>
                <div>
                  <p
                    style={{
                      ...text.listTitle,
                      color: colors.white,
                      opacity: opacity.primary,
                    }}
                  >
                    {userName || "anonymous"}
                  </p>
                  <p
                    style={{
                      ...text.label,
                      color: colors.white,
                      opacity: opacity.quaternary,
                    }}
                  >
                    profile
                  </p>
                </div>
              </div>

              {/* ── Divider ── */}
              <div
                className="my-8"
                style={{
                  height: "1px",
                  backgroundColor: colors.white,
                  opacity: opacity.rule,
                }}
              />

              {/* ── Theme selector ── */}
              <p
                style={{
                  ...text.label,
                  color: colors.white,
                  opacity: opacity.tertiary,
                  marginBottom: "16px",
                }}
              >
                theme
              </p>

              {THEME_NAMES.map((name) => {
                const t = themes[name];
                const isActive = theme === name;
                return (
                  <div
                    key={name}
                    role="button"
                    tabIndex={0}
                    onClick={() => setTheme(name)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") setTheme(name);
                    }}
                    className="flex cursor-pointer items-center gap-4 py-3 outline-none"
                  >
                    {/* Color swatch */}
                    <div
                      style={{
                        width: "10px",
                        height: "10px",
                        borderRadius: "50%",
                        backgroundColor: t.accent,
                        opacity: isActive ? 1 : 0.5,
                        transition: `opacity ${timing.transition} ease`,
                      }}
                    />
                    <span
                      style={{
                        ...text.body,
                        color: isActive ? t.accent : colors.white,
                        opacity: isActive ? opacity.primary : opacity.tertiary,
                        transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                      }}
                    >
                      {t.label}
                    </span>
                  </div>
                );
              })}

              {/* ── Close ── */}
              <div className="mt-8">
                <span
                  role="button"
                  tabIndex={0}
                  onClick={() => setIsOpen(false)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") setIsOpen(false);
                  }}
                  className="cursor-pointer outline-none"
                  style={{
                    ...text.label,
                    color: colors.white,
                    opacity: opacity.tertiary,
                    transition: `opacity ${timing.transition} ease`,
                  }}
                  onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.7"; }}
                  onMouseLeave={(e) => { e.currentTarget.style.opacity = String(opacity.tertiary); }}
                >
                  close
                </span>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}
