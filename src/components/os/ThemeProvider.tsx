"use client";

import { createContext, useContext, useState, useEffect, useCallback } from "react";
import { themes, hexToRgb, isVibeStyle } from "@/lib/theme";
import type { ThemeName, ThemeStyle } from "@/lib/theme";

const DEFAULT_THEME: ThemeName = "hearth";

interface ThemeContextValue {
  theme: ThemeName;
  style: ThemeStyle;
  isVibe: boolean;
  setTheme: (name: ThemeName) => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  theme: DEFAULT_THEME,
  style: "flat",
  isVibe: false,
  setTheme: () => {},
});

export function useThemeContext() {
  return useContext(ThemeContext);
}

function applyTheme(name: ThemeName) {
  const t = themes[name];
  const root = document.documentElement;

  // Core identity
  root.style.setProperty("--xark-accent", t.accent);
  root.style.setProperty("--xark-accent-rgb", hexToRgb(t.accent));
  root.style.setProperty("--xark-white", t.text);
  root.style.setProperty("--xark-white-rgb", hexToRgb(t.text));
  root.style.setProperty("--xark-void", t.bg);
  root.style.setProperty("--xark-void-rgb", hexToRgb(t.bg));

  // Engine signal colors — adjusted per theme for contrast
  root.style.setProperty("--xark-amber", t.amber);
  root.style.setProperty("--xark-amber-rgb", hexToRgb(t.amber));
  root.style.setProperty("--xark-gold", t.gold);
  root.style.setProperty("--xark-gold-rgb", hexToRgb(t.gold));
  root.style.setProperty("--xark-green", t.green);
  root.style.setProperty("--xark-green-rgb", hexToRgb(t.green));
  root.style.setProperty("--xark-orange", t.orange);
  root.style.setProperty("--xark-orange-rgb", hexToRgb(t.orange));
  root.style.setProperty("--xark-gray", t.gray);
  root.style.setProperty("--xark-gray-rgb", hexToRgb(t.gray));

  // Solid ink colors — for high-readability contexts
  root.style.setProperty("--xark-ink-primary", t.inkPrimary);
  root.style.setProperty("--xark-ink-secondary", t.inkSecondary);
  root.style.setProperty("--xark-ink-tertiary", t.inkTertiary);
  root.style.setProperty("--xark-ink-sender", t.inkSender);

  // Style class on root — components use [data-style="depth"] for vibe rendering
  root.dataset.style = t.style;

  // Body background
  root.style.setProperty("background-color", t.bg);

  // Color scheme — tells iOS Safari (keyboard, scrollbars, native controls)
  const colorScheme = t.mode === "dark" ? "dark" : "light";
  root.style.colorScheme = colorScheme;

  // Dynamic meta theme-color (keyboard + browser chrome + PWA title bar)
  const existingMeta = document.querySelector('meta[name="theme-color"]');
  if (existingMeta) {
    existingMeta.setAttribute("content", t.bg);
  } else {
    const meta = document.createElement("meta");
    meta.name = "theme-color";
    meta.content = t.bg;
    document.head.appendChild(meta);
  }

  // Inputs inherit colorScheme from root — no per-element override needed.
}

// Migrate legacy theme names to new system
function resolveTheme(stored: string | null): ThemeName {
  if (stored && stored in themes) return stored as ThemeName;
  // Legacy migration: "midnight" → "hearth_dark"
  if (stored === "midnight") return "hearth_dark";
  return DEFAULT_THEME;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemeName>(DEFAULT_THEME);

  // Read from localStorage on mount
  useEffect(() => {
    const saved = localStorage.getItem("xark-theme");
    const initial = resolveTheme(saved);
    setThemeState(initial);
    applyTheme(initial);
  }, []);

  const setTheme = useCallback((name: ThemeName) => {
    setThemeState(name);
    applyTheme(name);
    localStorage.setItem("xark-theme", name);
  }, []);

  const style = themes[theme].style;
  const isVibe = style === "depth";

  return (
    <ThemeContext.Provider value={{ theme, style, isVibe, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
