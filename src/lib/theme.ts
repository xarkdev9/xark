// XARK OS v2.0 — SINGLE SOURCE OF TRUTH FOR ALL VISUAL TOKENS
// Every component imports from here. No local color/timing/opacity constants.
// ALL colors are CSS variables — changed by ThemeProvider per theme.
// Font: Inter globally. No per-theme fonts. Consistency = quality.

// ── THEME PRESETS ───────────────────────────────────────────────────────────
// 3 light + 3 dark. Hearth is default.

export type ThemeName = "hearth" | "cloud" | "sage" | "signal" | "noir" | "haze";

export interface ThemeConfig {
  label: string;
  mode: "light" | "dark";
  accent: string;       // identity color (dots, underlines, @xark labels)
  text: string;         // foreground text (hierarchy via opacity)
  bg: string;           // background canvas
  // Engine signal colors — adjusted per mode for contrast
  amber: string;        // seeking / anticipation / "love it"
  gold: string;         // social reward / handshake confirm
  green: string;        // finality
  orange: string;       // rejection / "not for me"
  gray: string;         // neutral / "works for me"
}

export const themes: Record<ThemeName, ThemeConfig> = {
  hearth: {
    label: "hearth",
    mode: "light",
    accent: "#FF6B35",      // Action Orange — warm hearth glow
    text: "#141414",         // Ink on paper
    bg: "#F0EEE9",          // Warm off-white canvas (Low Cortisol Canvas)
    amber: "#9E6A06",       // ~5:1 contrast on #F0EEE9
    gold: "#8B6914",
    green: "#047857",
    orange: "#C43D08",
    gray: "#57576A",
  },
  cloud: {
    label: "cloud",
    mode: "light",
    accent: "#4F46E5",      // Indigo — clean, professional
    text: "#1E293B",         // Slate-800
    bg: "#F8FAFC",          // Slate-50 — cool clean white
    amber: "#92600A",       // Darkened for brighter bg
    gold: "#7D5A10",
    green: "#047857",
    orange: "#B53808",
    gray: "#4E4E62",
  },
  sage: {
    label: "sage",
    mode: "light",
    accent: "#166534",      // Deep forest green — natural, earthy
    text: "#1C1917",         // Stone-900 — warm ink
    bg: "#F5F5F0",          // Natural linen
    amber: "#9E6A06",
    gold: "#8B6914",
    green: "#047857",
    orange: "#C43D08",
    gray: "#57576A",
  },
  signal: {
    label: "signal",
    mode: "dark",
    accent: "#40E0FF",      // Intelligence Cyan
    text: "#E0E8F0",        // Cool silver — desaturated, premium readability
    bg: "#080C14",          // Midnight navy — atmospheric depth for cyan
    amber: "#F5A623",
    gold: "#FFCF40",        // Rich gold
    green: "#34D399",       // Bright emerald
    orange: "#F0652A",
    gray: "#7E8C9A",        // Blue-steel neutral
  },
  noir: {
    label: "noir",
    mode: "dark",
    accent: "#E8C47C",      // Champagne gold — spotlight warmth
    text: "#EDE8E0",        // Warm cream parchment
    bg: "#0A0908",          // Warm near-black
    amber: "#F5A623",
    gold: "#FFD040",
    green: "#34D399",
    orange: "#F0652A",
    gray: "#9A9488",        // Warm earthy neutral
  },
  haze: {
    label: "haze",
    mode: "dark",
    accent: "#A78BFA",      // Gen-Z violet
    text: "#E4E0EE",        // Lavender-white
    bg: "#0A0812",          // Deep indigo-black
    amber: "#F5A623",
    gold: "#E8C840",        // Soft gold
    green: "#34D399",
    orange: "#F0652A",
    gray: "#8A82A0",        // Violet-neutral
  },
};

// Hex to "r, g, b" string for rgba() usage in gradients
export function hexToRgb(hex: string): string {
  const h = hex.replace("#", "");
  const n = parseInt(h, 16);
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}

// ── COLORS ──────────────────────────────────────────────────────────────────
// ALL colors are CSS variables — theme-aware across light and dark.
export const colors = {
  white: "var(--xark-white)",       // text/foreground
  cyan: "var(--xark-accent)",       // accent/identity
  void: "var(--xark-void)",         // background/canvas
  overlay: "#000000",               // always black (dimming scrim)
  // Engine signals — now CSS variables for light/dark contrast
  amber: "var(--xark-amber)",
  gold: "var(--xark-gold)",
  green: "var(--xark-green)",
  orange: "var(--xark-orange)",
  gray: "var(--xark-gray)",
} as const;

// ── OPACITY HIERARCHY ───────────────────────────────────────────────────────
export const opacity = {
  primary: 0.9,
  secondary: 0.6,
  tertiary: 0.4,
  quaternary: 0.25,
  whisper: 0.2,
  ghost: 0.12,
  rule: 0.1,
  wash: 0.05,
  meshCyan: 0.03,
  meshAmber: 0.02,
  meshGlow: 0.02,
  overlay: 0.8,
  focusUnderline: 0.6,
} as const;

// ── TIMING ──────────────────────────────────────────────────────────────────
export const timing = {
  breath: "4.5s",
  meshPulse: "15s",
  transition: "0.4s",
  layoutEase: [0.22, 1, 0.36, 1] as readonly number[],
  layoutDuration: 0.3,
  staggerDelay: 0.06,
  goldBurst: 3,
  transit: 1.2,
} as const;

// ── GLOBAL TYPE SCALE ────────────────────────────────────────────────────────
// Single source of truth. Every component spreads these into style={{}}.
// To scale for accessibility: multiply all fontSizes here.
export const text = {
  hero: {
    fontSize: "1.5rem",
    fontWeight: 400 as const,
    lineHeight: 1.6,
    letterSpacing: "-0.01em",
  },
  spaceTitle: {
    fontSize: "clamp(1.25rem, 3vw, 1.5rem)",
    fontWeight: 400 as const,
    lineHeight: 1.6,
    letterSpacing: "-0.01em",
  },
  listTitle: {
    fontSize: "1rem",
    fontWeight: 400 as const,
    lineHeight: 1.6,
    letterSpacing: "-0.01em",
  },
  body: {
    fontSize: "0.75rem",
    fontWeight: 400 as const,
    lineHeight: 1.5,
    letterSpacing: "0.01em",
  },
  subtitle: {
    fontSize: "0.65rem",
    fontWeight: 300 as const,
    lineHeight: 1.5,
    letterSpacing: "0.02em",
  },
  label: {
    fontSize: "0.6rem",
    fontWeight: 300 as const,
    lineHeight: 1.4,
    letterSpacing: "0.2em",
    textTransform: "uppercase" as const,
  },
  recency: {
    fontSize: "0.5rem",
    fontWeight: 300 as const,
    lineHeight: 1.4,
    letterSpacing: "0.15em",
  },
  timestamp: {
    fontSize: "0.45rem",
    fontWeight: 300 as const,
    lineHeight: 1.4,
  },
  input: {
    fontSize: "clamp(0.9rem, 2vw, 1.05rem)",
    fontWeight: 400 as const,
    letterSpacing: "0.04em",
  },
  hint: {
    fontSize: "0.6rem",
    fontWeight: 300 as const,
    letterSpacing: "0.15em",
  },
} as const;

// ── LAYOUT ──────────────────────────────────────────────────────────────────
export const layout = {
  maxWidth: "640px",
  inputBottom: "96px",
  caretBottom: "32px",
  caretSize: "10px",
  emberSize: "4px",
  letterSpacing: {
    tight: "-0.01em",
    wide: "0.15em",
    wider: "0.2em",
  },
} as const;

// ── FOVEAL OPACITY ──────────────────────────────────────────────────────────
export const foveal = {
  xark: [0.9, 0.7, 0.5, 0.35, 0.25] as readonly number[],
  user: [0.6, 0.45, 0.35, 0.25] as readonly number[],
  floor: 0.2,
  roleCap: 0.4,
  timestampFactor: 0.3,
  timestampCap: 0.25,
} as const;

// ── NEURO SIGNALS ───────────────────────────────────────────────────────────
export const neuro = {
  amber: { hex: colors.amber, signal: "Seeking / Anticipation", bind: "weightedScore" },
  gold: { hex: colors.gold, signal: "Social Gold", bind: "agreementScore", bloomThreshold: 0.8 },
  green: { hex: colors.green, signal: "Finality", bind: "isLocked", settlesTo: colors.white },
  cyan: { hex: colors.cyan, signal: "@xark Intelligence", breathDuration: timing.breath },
} as const;

// ── REACTION WEIGHTS ────────────────────────────────────────────────────────
export const reactions = {
  loveIt: { weight: 5, color: colors.amber, label: "Love it" },
  worksForMe: { weight: 1, color: colors.gray, label: "Works for me" },
  notForMe: { weight: -3, color: colors.orange, label: "Not for me" },
} as const;

// ── UTILITY FUNCTIONS ───────────────────────────────────────────────────────

export function amberWash(weightedScore: number): string {
  const clamped = Math.max(0, Math.min(1, weightedScore));
  return `rgba(var(--xark-amber-rgb), ${(clamped * 0.6 + 0.1).toFixed(2)})`;
}

export function goldBloom(agreementScore: number): string | undefined {
  if (agreementScore > neuro.gold.bloomThreshold) {
    const intensity = (agreementScore - neuro.gold.bloomThreshold) / (1 - neuro.gold.bloomThreshold);
    return `radial-gradient(circle, rgba(var(--xark-gold-rgb), ${(intensity * 0.5).toFixed(2)}) 0%, transparent 70%)`;
  }
  return undefined;
}

export function fovealOpacity(index: number, total: number, role: "user" | "xark"): number {
  const distanceFromEnd = total - 1 - index;
  const steps = role === "xark" ? foveal.xark : foveal.user;
  return steps[Math.min(distanceFromEnd, steps.length - 1)] ?? foveal.floor;
}

// ── TEXT COLOR WITH BAKED OPACITY ─────────────────────────────────────────────
export function textColor(alpha: number): string {
  return `rgba(var(--xark-white-rgb), ${alpha})`;
}

export function accentColor(alpha: number): string {
  return `rgba(var(--xark-accent-rgb), ${alpha})`;
}

// Backwards compatibility
export const NEURO = neuro;
export const SURFACES = {
  void: colors.void,
  cloudDancer: colors.white,
  atmospheric: "transparent",
} as const;
