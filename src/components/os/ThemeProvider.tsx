"use client";
import { createContext, useContext, useState, useEffect } from "react";
import type { ThemeName } from "@/lib/theme";
import { themes, hexToRgb } from "@/lib/theme";

const ThemeContext = createContext<{ theme: ThemeName; setTheme: (t: ThemeName) => void }>({ theme: "hearth", setTheme: () => {} });

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<ThemeName>("hearth");
  useEffect(() => {
    const t = themes[theme];
    const root = document.documentElement;
    root.style.setProperty("--xark-white", t.text);
    root.style.setProperty("--xark-white-rgb", hexToRgb(t.text));
    root.style.setProperty("--xark-void", t.bg);
    root.style.setProperty("--xark-void-rgb", hexToRgb(t.bg));
    root.style.setProperty("--xark-accent", t.accent);
    root.style.setProperty("--xark-accent-rgb", hexToRgb(t.accent));
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
    root.setAttribute("data-theme", theme);
  }, [theme]);
  return <ThemeContext.Provider value={{ theme, setTheme }}>{children}</ThemeContext.Provider>;
}
export function useTheme() { return useContext(ThemeContext); }
export const useThemeContext = useTheme;
