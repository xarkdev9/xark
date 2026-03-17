// XARK OS v2.0 — SINGLE SOURCE OF TRUTH FOR ALL VISUAL TOKENS
// Every component imports from here. No local color/timing/opacity constants.
// ALL colors are CSS variables — changed by ThemeProvider per theme.
// Font: Inter globally. No per-theme fonts. Consistency = quality.

// ── THEME PRESETS ───────────────────────────────────────────────────────────
// 4 appearances: hearth light/dark (flat) + vibe light/dark (depth + photos).
// Style: "flat" = clean WhatsApp-like. "depth" = floating shadows, HD photos, immersive.

export type ThemeName = "hearth" | "hearth_dark" | "vibe" | "vibe_dark";
export type ThemeStyle = "flat" | "depth";

export interface ThemeConfig {
  label: string;
  mode: "light" | "dark";
  style: ThemeStyle;    // flat = clean utility, depth = floating shadows + HD photos
  accent: string;       // identity color (dots, underlines, @xark labels)
  text: string;         // foreground text (hierarchy via opacity)
  bg: string;           // background canvas
  // Engine signal colors — adjusted per mode for contrast
  amber: string;        // seeking / anticipation / "love it"
  gold: string;         // social reward / handshake confirm
  green: string;        // finality
  orange: string;       // rejection / "not for me"
  gray: string;         // neutral / "works for me"
  // Solid ink colors — for high-readability contexts (chat lists, People tab)
  inkPrimary: string;   // names, titles — maximum contrast
  inkSecondary: string; // preview text, subtitles — distinct color, not opacity
  inkTertiary: string;  // timestamps, metadata — lighter but still readable
  inkSender: string;    // group message sender name
  // 3-tone surface system — depth without borders
  surfaceChrome: string;   // elevated UI (header, input area) — lightest
  surfaceCanvas: string;   // content area (chat list, feed) — mid tone
  surfaceRecessed: string; // recessed elements (avatars, wells) — darkest
}

export const themes: Record<ThemeName, ThemeConfig> = {
  // ── HEARTH: clean, flat, WhatsApp-like ──
  hearth: {
    label: "hearth",
    mode: "light",
    style: "flat",
    accent: "#FF6B35",
    text: "#111111",
    bg: "#F8F7F4",
    amber: "#9E6A06",
    gold: "#8B6914",
    green: "#047857",
    orange: "#C43D08",
    gray: "#8A8A94",
    inkPrimary: "#000000",
    inkSecondary: "#6B6B78",
    inkTertiary: "#8A8A94",
    inkSender: "#9E6A06",
    surfaceChrome: "#F8F7F3",    // warm off-white — header, input
    surfaceCanvas: "#EEEBE5",    // warm beige — content area
    surfaceRecessed: "#E3DCD1",  // deeper beige — avatars, wells
  },
  hearth_dark: {
    label: "hearth dark",
    mode: "dark",
    style: "flat",
    accent: "#40E0FF",
    text: "#E8E6E1",
    bg: "#0A0A0F",
    amber: "#D4A017",
    gold: "#C9A81E",
    green: "#10B981",
    orange: "#E8590C",
    gray: "#8A8A94",
    inkPrimary: "#FFFFFF",
    inkSecondary: "#9CA3AF",
    inkTertiary: "#6B7280",
    inkSender: "#D4A017",
    surfaceChrome: "#141418",    // slightly lighter dark — header, input
    surfaceCanvas: "#0A0A0F",    // deep dark — content area (same as bg)
    surfaceRecessed: "#060608",  // deepest — avatars, wells
  },
  // ── VIBE: floating depth, HD photos, immersive ──
  vibe: {
    label: "vibe",
    mode: "light",
    style: "depth",
    accent: "#E87040",       // warmer orange
    text: "#0F0F0F",
    bg: "#FAF9F6",           // slightly brighter warm canvas
    amber: "#B07820",
    gold: "#9A7A18",
    green: "#059669",
    orange: "#DC4A20",
    gray: "#7C7C88",
    inkPrimary: "#000000",
    inkSecondary: "#5A5A66",
    inkTertiary: "#7C7C88",
    inkSender: "#B07820",
    surfaceChrome: "#FAF9F6",    // bright warm — header, input
    surfaceCanvas: "#F0EDE6",    // warm parchment — content
    surfaceRecessed: "#E5E0D6",  // deeper warmth — avatars, wells
  },
  vibe_dark: {
    label: "vibe dark",
    mode: "dark",
    style: "depth",
    accent: "#FF6B35",       // Xark brand Action Orange
    text: "#ECE8E2",
    bg: "#08080C",           // deep warm black
    amber: "#E0A820",
    gold: "#D4A018",
    green: "#10B981",
    orange: "#F06030",
    gray: "#8A8A94",
    inkPrimary: "#FFFFFF",
    inkSecondary: "#A0A0AC",
    inkTertiary: "#6E6E7A",
    inkSender: "#E0A820",
    surfaceChrome: "#121216",    // lifted dark — header, input
    surfaceCanvas: "#08080C",    // deep — content (same as bg)
    surfaceRecessed: "#040406",  // deepest — avatars, wells
  },
};

// ── STYLE HELPERS ────────────────────────────────────────────────────────────
// Components use these to adapt rendering based on style (flat vs depth).
export function getStyle(themeName: ThemeName): ThemeStyle {
  return themes[themeName].style;
}

export function isVibeStyle(themeName: ThemeName): boolean {
  return themes[themeName].style === "depth";
}

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

// ── SURFACE TONES ────────────────────────────────────────────────────────────
// 3-tone depth system: chrome (elevated), canvas (content), recessed (wells).
// Replaces flat single-bg with warm surface hierarchy. No borders needed.
export const surface = {
  chrome: "var(--xark-surface-chrome)",     // header, input area, elevated panels
  canvas: "var(--xark-surface-canvas)",     // content area, chat list, feed
  recessed: "var(--xark-surface-recessed)", // avatars, input wells, recessed zones
} as const;

// ── SOLID TEXT COLORS ─────────────────────────────────────────────────────────
// For chat lists, people tab, and anywhere readable text must survive sunlight.
// These are SOLID COLORS — never opacity. Use instead of textColor(alpha) for
// high-readability contexts (People tab, Plans tab, list items).
// CSS variables — set by ThemeProvider per theme.
export const ink = {
  primary: "var(--xark-ink-primary)",       // names, titles — pure black/white
  secondary: "var(--xark-ink-secondary)",   // preview text, subtitles
  tertiary: "var(--xark-ink-tertiary)",     // timestamps, metadata
  sender: "var(--xark-ink-sender)",         // group message sender name
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
    fontSize: "1.625rem",
    fontWeight: 400 as const,
    lineHeight: 1.4,
    letterSpacing: "-0.01em",
  },
  spaceTitle: {
    fontSize: "clamp(1.25rem, 3vw, 1.5rem)",
    fontWeight: 400 as const,
    lineHeight: 1.4,
    letterSpacing: "-0.01em",
  },
  listTitle: {
    fontSize: "1.125rem",
    fontWeight: 400 as const,
    lineHeight: 1.4,
    letterSpacing: "-0.01em",
  },
  body: {
    fontSize: "1.0625rem",
    fontWeight: 400 as const,
    lineHeight: 1.45,
    letterSpacing: "0.01em",
  },
  subtitle: {
    fontSize: "1rem",
    fontWeight: 400 as const,
    lineHeight: 1.35,
    letterSpacing: "0em",
  },
  label: {
    fontSize: "0.8125rem",
    fontWeight: 300 as const,
    lineHeight: 1.4,
    letterSpacing: "0.12em",
    textTransform: "uppercase" as const,
  },
  recency: {
    fontSize: "0.75rem",
    fontWeight: 300 as const,
    lineHeight: 1.4,
    letterSpacing: "0.08em",
  },
  timestamp: {
    fontSize: "0.75rem",
    fontWeight: 300 as const,
    lineHeight: 1.4,
  },
  input: {
    fontSize: "1.0625rem",
    fontWeight: 400 as const,
    letterSpacing: "0.02em",
  },
  hint: {
    fontSize: "0.8125rem",
    fontWeight: 300 as const,
    letterSpacing: "0.08em",
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
  xark: [0.95, 0.90, 0.85, 0.80, 0.75] as readonly number[],
  user: [0.95, 0.90, 0.85, 0.78] as readonly number[],
  floor: 0.70,
  roleCap: 0.4,
  timestampFactor: 0.5,
  timestampCap: 0.38,
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
