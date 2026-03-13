"use client";

import { createContext, useContext, useState, useEffect, useCallback } from "react";
import { themes, hexToRgb } from "@/lib/theme";
import type { ThemeName } from "@/lib/theme";

const DEFAULT_THEME: ThemeName = "hearth";

interface ThemeContextValue {
  theme: ThemeName;
  setTheme: (name: ThemeName) => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  theme: DEFAULT_THEME,
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

  // Body background
  root.style.setProperty("background-color", t.bg);
}

// Migrate legacy theme names to new system
function resolveTheme(stored: string | null): ThemeName {
  if (stored && stored in themes) return stored as ThemeName;
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

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
