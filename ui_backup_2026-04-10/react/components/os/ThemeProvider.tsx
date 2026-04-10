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
  root.style.setProperty("--hello-accent", t.accent);
  root.style.setProperty("--hello-accent-rgb", hexToRgb(t.accent));
  root.style.setProperty("--hello-cyan", t.cyan);
  root.style.setProperty("--hello-cyan-rgb", hexToRgb(t.cyan));
  root.style.setProperty("--hello-white", t.text);
  root.style.setProperty("--hello-white-rgb", hexToRgb(t.text));
  root.style.setProperty("--hello-void", t.bg);
  root.style.setProperty("--hello-void-rgb", hexToRgb(t.bg));

  // Engine signal colors — adjusted per theme for contrast
  root.style.setProperty("--hello-amber", t.amber);
  root.style.setProperty("--hello-amber-rgb", hexToRgb(t.amber));
  root.style.setProperty("--hello-gold", t.gold);
  root.style.setProperty("--hello-gold-rgb", hexToRgb(t.gold));
  root.style.setProperty("--hello-green", t.green);
  root.style.setProperty("--hello-green-rgb", hexToRgb(t.green));
  root.style.setProperty("--hello-orange", t.orange);
  root.style.setProperty("--hello-orange-rgb", hexToRgb(t.orange));
  root.style.setProperty("--hello-gray", t.gray);
  root.style.setProperty("--hello-gray-rgb", hexToRgb(t.gray));

  // Solid ink colors — for high-readability contexts
  root.style.setProperty("--hello-ink-primary", t.inkPrimary);
  root.style.setProperty("--hello-ink-secondary", t.inkSecondary);
  root.style.setProperty("--hello-ink-tertiary", t.inkTertiary);
  root.style.setProperty("--hello-ink-sender", t.inkSender);

  // 3-tone surface system — depth without borders
  root.style.setProperty("--hello-surface-chrome", t.surfaceChrome);
  root.style.setProperty("--hello-surface-canvas", t.surfaceCanvas);
  root.style.setProperty("--hello-surface-recessed", t.surfaceRecessed);

  // Chat bubble colors
  root.style.setProperty("--hello-bubble-received", t.bubbleReceived);
  root.style.setProperty("--hello-bubble-sent", t.bubbleSent);
  root.style.setProperty("--hello-bubble-text-received", t.bubbleTextReceived);
  root.style.setProperty("--hello-bubble-text-sent", t.bubbleTextSent);

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
    localStorage.setItem("hello-theme", DEFAULT_THEME);
    setThemeState(DEFAULT_THEME);
    applyTheme(DEFAULT_THEME);
  }, []);

  const setTheme = useCallback((name: ThemeName) => {
    setThemeState(name);
    applyTheme(name);
    localStorage.setItem("hello-theme", name);
  }, []);

  const style = themes[theme].style;
  const isVibe = style === "depth";

  return (
    <ThemeContext.Provider value={{ theme, style, isVibe, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
