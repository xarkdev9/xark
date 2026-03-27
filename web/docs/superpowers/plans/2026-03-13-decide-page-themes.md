# Decide Page Redesign + Two Natural Themes — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Decide page as a Netflix-fluid card rail system and replace the 6-theme system with 3 themes (hearth, aurora, coast) where aurora and coast feature HD video backgrounds on the Galaxy home screen.

**Architecture:** Theme reduction (6→3) in theme.ts. New DecisionCard component with 3 size variants. PossibilityHorizon rewrite with Framer Motion entrance choreography + virtualized horizontal rails. VideoBackground component for Galaxy page. Unsplash API integration for space hero images. Device tier detection for performance scaling.

**Tech Stack:** React 19, Next.js, Framer Motion 12, TypeScript 5, Tailwind CSS 4, Unsplash API, HTML5 Video, CSS scroll-snap, IntersectionObserver.

**Spec:** `docs/superpowers/specs/2026-03-13-decide-page-themes-design.md`

---

## Chunk 1: Theme System (3 themes only)

### Task 1: Reduce themes to hearth + aurora + coast in theme.ts

**Files:**
- Modify: `src/lib/theme.ts`

- [ ] **Step 1: Update ThemeName type and themes record**

Remove cloud, sage, signal, noir, haze. Add aurora and coast. In `src/lib/theme.ts`:

```typescript
export type ThemeName = "hearth" | "aurora" | "coast";

export const themes: Record<ThemeName, ThemeConfig> = {
  hearth: {
    label: "hearth",
    mode: "light",
    accent: "#FF6B35",
    text: "#141414",
    bg: "#F0EEE9",
    amber: "#9E6A06",
    gold: "#8B6914",
    green: "#047857",
    orange: "#C43D08",
    gray: "#57576A",
  },
  aurora: {
    label: "aurora",
    mode: "dark",
    accent: "#34D399",       // Aurora green
    text: "#E0EEF0",         // Cool silver
    bg: "#040810",           // Deep night
    amber: "#F5A623",
    gold: "#FFCF40",
    green: "#34D399",
    orange: "#F0652A",
    gray: "#7E8C9A",
  },
  coast: {
    label: "coast",
    mode: "light",
    accent: "#C88A3C",       // Golden hour amber
    text: "#1C1812",         // Warm dark ink
    bg: "#F0E8DA",           // Warm linen
    amber: "#9E6A06",
    gold: "#8B6914",
    green: "#047857",
    orange: "#C43D08",
    gray: "#57576A",
  },
};
```

- [ ] **Step 2: Verify no type errors**

Run: `npx tsc --noEmit`
Expected: No errors related to removed theme names.

- [ ] **Step 3: Commit**

```bash
git add src/lib/theme.ts
git commit -m "feat: reduce themes to hearth + aurora + coast"
```

### Task 2: Update ThemeProvider

**Files:**
- Modify: `src/components/os/ThemeProvider.tsx`

- [ ] **Step 1: Update resolveTheme fallback**

The `resolveTheme` function already falls back to `DEFAULT_THEME` for unknown names. Users with saved "signal" or "noir" in localStorage will auto-migrate to hearth. No code change needed — verify this is the case by reading the function.

- [ ] **Step 2: Verify ThemeProvider compiles**

Run: `npx tsc --noEmit`
Expected: PASS — ThemeProvider reads from `themes` record which now only has 3 entries.

- [ ] **Step 3: Commit** (if any changes were needed)

### Task 3: Update UserMenu theme picker

**Files:**
- Modify: `src/components/os/UserMenu.tsx`

- [ ] **Step 1: Update THEME_NAMES array**

Change line 13 from:
```typescript
const THEME_NAMES: ThemeName[] = ["hearth", "cloud", "sage", "signal", "noir", "haze"];
```
To:
```typescript
const THEME_NAMES: ThemeName[] = ["hearth", "aurora", "coast"];
```

- [ ] **Step 2: Verify build**

Run: `npx tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add src/components/os/UserMenu.tsx
git commit -m "feat: theme picker shows hearth, aurora, coast only"
```

### Task 4: Update globals.css default variables

**Files:**
- Modify: `src/app/globals.css`

- [ ] **Step 1: Verify `:root` defaults are hearth values**

The existing `:root` block already sets hearth defaults. No change needed — hearth remains the default theme. Confirm by reading the file.

- [ ] **Step 2: Commit** (skip if no changes)

---

## Chunk 2: Device Tier Detection

### Task 5: Create useDeviceTier hook

**Files:**
- Create: `src/hooks/useDeviceTier.ts`

- [ ] **Step 1: Write the hook**

```typescript
"use client";

import { useState, useEffect } from "react";

export type DeviceTier = "high" | "low";

export function useDeviceTier(): DeviceTier {
  const [tier, setTier] = useState<DeviceTier>("high");

  useEffect(() => {
    const isLow =
      (navigator.deviceMemory !== undefined && navigator.deviceMemory <= 2) ||
      (navigator.hardwareConcurrency !== undefined && navigator.hardwareConcurrency <= 4) ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (isLow) setTier("low");
  }, []);

  return tier;
}
```

- [ ] **Step 2: Add type declaration for navigator.deviceMemory**

Create `src/types/navigator.d.ts`:
```typescript
interface Navigator {
  deviceMemory?: number;
}
```

- [ ] **Step 3: Verify build**

Run: `npx tsc --noEmit`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/hooks/useDeviceTier.ts src/types/navigator.d.ts
git commit -m "feat: add useDeviceTier hook for performance scaling"
```

---

## Chunk 3: Video Background Component

### Task 6: Create VideoBackground component

**Files:**
- Create: `src/components/os/VideoBackground.tsx`

- [ ] **Step 1: Write the component**

```typescript
"use client";

import { useEffect, useState, useRef } from "react";
import { useDeviceTier } from "@/hooks/useDeviceTier";

interface VideoBackgroundProps {
  videoSrc: string;
  posterSrc: string;
  children?: React.ReactNode;
}

export function VideoBackground({ videoSrc, posterSrc, children }: VideoBackgroundProps) {
  const tier = useDeviceTier();
  const [canPlay, setCanPlay] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    // Skip video on low-end devices
    if (tier === "low") return;

    // Skip video on low battery
    if ("getBattery" in navigator) {
      (navigator as unknown as { getBattery: () => Promise<{ level: number }> })
        .getBattery()
        .then((battery) => {
          if (battery.level > 0.2) setCanPlay(true);
        })
        .catch(() => setCanPlay(true));
    } else {
      setCanPlay(true);
    }
  }, [tier]);

  return (
    <div className="absolute inset-0" style={{ zIndex: 1 }}>
      {canPlay ? (
        <video
          ref={videoRef}
          autoPlay
          muted
          loop
          playsInline
          poster={posterSrc}
          className="absolute inset-0 h-full w-full object-cover"
        >
          <source src={videoSrc} type="video/mp4" />
        </video>
      ) : (
        <img
          src={posterSrc}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
      )}
      {children}
    </div>
  );
}
```

- [ ] **Step 2: Verify build**

Run: `npx tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add src/components/os/VideoBackground.tsx
git commit -m "feat: add VideoBackground component with device tier fallback"
```

### Task 7: Add video assets to public

**Files:**
- Create: `public/themes/aurora-loop.mp4`
- Create: `public/themes/aurora-poster.webp`
- Create: `public/themes/coast-loop.mp4`
- Create: `public/themes/coast-poster.webp`

- [ ] **Step 1: Download northern lights video**

Source a free northern lights video from Pexels (e.g., search "northern lights" or "aurora borealis"). Download 720p MP4. Trim to 10-15s seamless loop. Compress to <3MB. Save as `public/themes/aurora-loop.mp4`. Extract a poster frame as WebP: `public/themes/aurora-poster.webp`.

- [ ] **Step 2: Download California beach video**

Source a free California sunset/beach video from Pexels (e.g., search "california sunset beach" or "golden hour ocean"). Same process. Save as `public/themes/coast-loop.mp4` and `public/themes/coast-poster.webp`.

- [ ] **Step 3: Commit**

```bash
git add public/themes/
git commit -m "feat: add aurora + coast video loops and poster fallbacks"
```

---

## Chunk 4: Galaxy Page — Video Background + Left-Stacked Items

### Task 8: Update Galaxy page with video background and left-stacked layout

**Files:**
- Modify: `src/app/galaxy/page.tsx`

- [ ] **Step 1: Import VideoBackground and theme context**

Add imports at top:
```typescript
import { VideoBackground } from "@/components/os/VideoBackground";
import { useThemeContext } from "@/components/os/ThemeProvider";
```

- [ ] **Step 2: Add video background behind content**

Inside `GalaxyContent`, after the `useAuth` hook, read the theme:
```typescript
const { theme } = useThemeContext();
const isVideoTheme = theme === "aurora" || theme === "coast";
const videoSrc = theme === "aurora" ? "/themes/aurora-loop.mp4" : "/themes/coast-loop.mp4";
const posterSrc = theme === "aurora" ? "/themes/aurora-poster.webp" : "/themes/coast-poster.webp";
```

Wrap the existing content. Replace the Spectrum Wash + Mesh Pulse background divs with:
```tsx
{isVideoTheme ? (
  <VideoBackground videoSrc={videoSrc} posterSrc={posterSrc}>
    {/* Shelf gradient — solid ground for items */}
    <div
      className="absolute inset-0"
      style={{
        background: theme === "aurora"
          ? "linear-gradient(180deg, transparent 0%, transparent 40%, rgba(4,8,16,0.5) 50%, rgba(4,8,16,0.9) 60%, #040810 70%)"
          : "linear-gradient(180deg, transparent 0%, transparent 40%, rgba(240,232,218,0.5) 50%, rgba(240,232,218,0.9) 60%, #F0E8DA 70%)",
        zIndex: 2,
      }}
    />
  </VideoBackground>
) : (
  <>
    {/* Existing Spectrum Wash for hearth */}
    <div className="pointer-events-none fixed inset-0" style={{...existing spectrum wash styles...}} />
    <div className="pointer-events-none fixed inset-0" style={{...existing mesh pulse styles...}} />
  </>
)}
```

- [ ] **Step 3: Update awareness event styles for theme awareness**

The existing events use `colors.white` and `textColor()` which are theme-aware via CSS variables. These will automatically work with aurora and coast since ThemeProvider sets the CSS variables. No change needed for individual event styling.

- [ ] **Step 4: Update the left-stacked item layout**

The awareness stream items are already left-aligned. The key change: on aurora/coast themes, items should render with the size+opacity cascade from the spec (26px → 19px → 15px → 13px → 12px for space names).

This is the existing awareness stream — it already uses `awarenessOpacity(event.priority)` for opacity and `text.body` for size. The current layout works. The video + shelf gradient handle the visual transformation. No structural change to the event rendering needed.

- [ ] **Step 5: Verify the page renders**

Run: `npm run dev` on port 3000. Navigate to Galaxy. Toggle theme to aurora/coast in UserMenu.
Expected: Video plays in top half, items readable on solid shelf below.

- [ ] **Step 6: Commit**

```bash
git add src/app/galaxy/page.tsx
git commit -m "feat: galaxy page video background for aurora + coast themes"
```

---

## Chunk 5: DecisionCard Component

### Task 9: Create shared DecisionCard component

**Files:**
- Create: `src/components/os/DecisionCard.tsx`

- [ ] **Step 1: Write the DecisionCard component**

A single component that renders at 3 sizes: `hero`, `standard`, `mini`. Accepts size as a prop. No borders. Photo top 40%, gradient bridge, solid dark data zone, consensus % as brightest element, reactions at bottom (hidden on mini).

```typescript
"use client";

import { useCallback } from "react";
import { motion } from "framer-motion";
import { getConsensusState } from "@/lib/heart-sort";
import type { ConsensusState } from "@/lib/heart-sort";
import { colors, text, textColor, amberWash, timing } from "@/lib/theme";
import type { ReactionType } from "@/hooks/useReactions";

type CardSize = "hero" | "standard" | "mini";

const DIMENSIONS: Record<CardSize, { w: number; h: number; pctSize: number; titleSize: string; showReactions: boolean }> = {
  hero: { w: 150, h: 220, pctSize: 28, titleSize: "12px", showReactions: true },
  standard: { w: 130, h: 195, pctSize: 20, titleSize: "11px", showReactions: true },
  mini: { w: 100, h: 130, pctSize: 16, titleSize: "9px", showReactions: false },
};

// Category fallback gradients when no image
const CATEGORY_GRADIENTS: Record<string, string> = {
  hotel: "linear-gradient(160deg, #8a6a4a 0%, #5a4030 50%, #2a1a10 100%)",
  flight: "linear-gradient(180deg, #1a2940 0%, #0d1520 60%, #060a10 100%)",
  dining: "linear-gradient(180deg, #2a1215 0%, #1a0a0c 60%, #0a0405 100%)",
  restaurant: "linear-gradient(180deg, #2a1215 0%, #1a0a0c 60%, #0a0405 100%)",
  activity: "linear-gradient(160deg, #1a3a2a 0%, #0a2015 60%, #050f0a 100%)",
  experience: "linear-gradient(160deg, #1a3a2a 0%, #0a2015 60%, #050f0a 100%)",
  general: "linear-gradient(160deg, #2a2a3a 0%, #1a1a28 60%, #0a0a14 100%)",
};

function consensusColor(state: ConsensusState): string {
  if (state === "ignited") return colors.gold;
  if (state === "steady") return colors.cyan;
  return colors.amber;
}

interface DecisionCardProps {
  id: string;
  title: string;
  imageUrl?: string;
  category?: string;
  price?: string;
  source?: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  size?: CardSize;
  activeReaction?: ReactionType;
  onReact?: (itemId: string, signal: ReactionType) => void;
  onClick?: () => void;
  entranceDelay?: number;
}

const SIGNALS: { type: ReactionType; label: string; color: string }[] = [
  { type: "love_it", label: "love", color: colors.amber },
  { type: "works_for_me", label: "okay", color: colors.gray },
  { type: "not_for_me", label: "pass", color: colors.orange },
];

export function DecisionCard({
  id,
  title,
  imageUrl,
  category = "general",
  price,
  source,
  weightedScore,
  agreementScore,
  size = "standard",
  activeReaction,
  onReact,
  onClick,
  entranceDelay = 0,
}: DecisionCardProps) {
  const dim = DIMENSIONS[size];
  const consensusState = getConsensusState(agreementScore);
  const pct = Math.round(agreementScore * 100);
  const cColor = consensusColor(consensusState);
  const fallbackGradient = CATEGORY_GRADIENTS[category.toLowerCase()] ?? CATEGORY_GRADIENTS.general;

  const handleReact = useCallback(
    (signal: ReactionType) => {
      if (onReact) onReact(id, signal);
    },
    [id, onReact]
  );

  return (
    <motion.div
      className="relative flex-shrink-0 snap-start overflow-hidden"
      style={{
        width: `${dim.w}px`,
        height: `${dim.h}px`,
        borderRadius: "14px",
        boxShadow: size === "hero"
          ? `0 0 28px rgba(255,207,64,0.08), 0 4px 24px rgba(0,0,0,0.15)`
          : "0 4px 24px rgba(0,0,0,0.12)",
        cursor: onClick ? "pointer" : "default",
        willChange: "transform",
      }}
      initial={{ opacity: 0, x: 60, scale: 0.92 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      transition={{
        delay: entranceDelay,
        duration: 0.5,
        ease: [0.22, 1, 0.36, 1],
      }}
      whileHover={{ scale: 1.08, y: -6 }}
      onClick={onClick}
    >
      {/* Photo zone — top 42% */}
      <div
        className="absolute left-0 right-0 top-0"
        style={{
          height: "42%",
          backgroundImage: imageUrl ? `url(${imageUrl})` : fallbackGradient,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />

      {/* Gradient bridge — photo dissolves into solid dark */}
      <div
        className="absolute inset-0"
        style={{
          background: "linear-gradient(180deg, transparent 30%, rgba(10,10,16,0.85) 48%, #0a0a10 58%)",
        }}
      />

      {/* Amber wash */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background: `linear-gradient(to top, ${amberWash(weightedScore)} 0%, transparent 40%)`,
        }}
      />

      {/* Data zone */}
      <div className="absolute inset-x-0 bottom-0 px-2.5" style={{ paddingBottom: dim.showReactions ? "34px" : "8px" }}>
        {/* Consensus % */}
        <div style={{ marginBottom: "4px" }}>
          <span
            style={{
              fontSize: `${dim.pctSize}px`,
              fontWeight: 400,
              lineHeight: 1,
              letterSpacing: "-0.03em",
              color: cColor,
              textShadow: size === "hero" ? `0 0 30px ${cColor}40` : "none",
              opacity: consensusState === "ignited" ? 0.95 : 0.7,
            }}
          >
            {pct > 0 ? pct : "—"}
          </span>
          {pct > 0 && (
            <span style={{ fontSize: `${Math.round(dim.pctSize * 0.4)}px`, color: cColor, opacity: 0.35, verticalAlign: "super", marginLeft: "1px" }}>
              %
            </span>
          )}
          <div style={{ marginTop: "3px", height: "2px", position: "relative" }}>
            <div
              style={{
                position: "absolute", left: 0, top: 0, height: "2px",
                width: `${pct}%`,
                backgroundColor: cColor,
                opacity: consensusState === "ignited" ? 0.6 : 0.3,
                borderRadius: "1px",
                transition: "width 0.8s cubic-bezier(0.22, 1, 0.36, 1)",
              }}
            />
          </div>
        </div>

        {/* Title */}
        <p style={{
          fontSize: dim.titleSize,
          fontWeight: 400,
          color: colors.white,
          opacity: 0.85,
          lineHeight: 1.3,
          overflow: "hidden",
          textOverflow: "ellipsis",
          whiteSpace: size === "mini" ? "nowrap" : "normal",
        }}>
          {title}
        </p>

        {/* Price */}
        {price && size !== "mini" && (
          <span style={{ fontSize: "9px", fontWeight: 300, color: colors.white, opacity: 0.3, display: "inline-block", marginTop: "2px" }}>
            {price}{source ? ` · ${source}` : ""}
          </span>
        )}
        {price && size === "mini" && (
          <span style={{ fontSize: "8px", fontWeight: 300, color: colors.white, opacity: 0.25, display: "inline-block", marginTop: "1px" }}>
            {price}
          </span>
        )}
      </div>

      {/* Reactions — hero + standard only */}
      {dim.showReactions && (
        <div className="absolute inset-x-0 bottom-0 flex items-center justify-between px-2.5" style={{ height: "30px" }}>
          {SIGNALS.map((signal) => {
            const isActive = activeReaction === signal.type;
            return (
              <span
                key={signal.type}
                role="button"
                tabIndex={0}
                onClick={(e) => { e.stopPropagation(); handleReact(signal.type); }}
                onKeyDown={(e) => { if (e.key === "Enter") { e.stopPropagation(); handleReact(signal.type); } }}
                className="outline-none"
                style={{
                  ...text.subtitle,
                  fontSize: size === "hero" ? "11px" : "10px",
                  color: isActive ? signal.color : colors.white,
                  opacity: isActive ? 1 : activeReaction ? 0.12 : 0.4,
                  cursor: "pointer",
                  textShadow: isActive ? `0 0 12px ${signal.color}, 0 0 4px ${signal.color}` : "0 1px 3px rgba(0,0,0,0.4)",
                  transition: `opacity ${timing.transition} ease, color ${timing.transition} ease, text-shadow ${timing.transition} ease`,
                }}
              >
                {signal.label}
              </span>
            );
          })}
        </div>
      )}
    </motion.div>
  );
}
```

- [ ] **Step 2: Verify build**

Run: `npx tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add src/components/os/DecisionCard.tsx
git commit -m "feat: add shared DecisionCard component with 3 size variants"
```

---

## Chunk 6: PossibilityHorizon Rewrite (Netflix Rails)

### Task 10: Rewrite PossibilityHorizon with Netflix rails

**Files:**
- Modify: `src/components/os/PossibilityHorizon.tsx`

- [ ] **Step 1: Rewrite CategorySection to use DecisionCard + horizontal rail**

Import the new `DecisionCard` component. Replace the inline card rendering with `<DecisionCard>` instances inside a horizontal scroll track with CSS `scroll-snap-type: x mandatory`, `-webkit-overflow-scrolling: touch`, `scrollbar-width: none`.

Add rail header with category name (left) + vital stat (right):
- If all items ignited: `"92% on #1 · 5 of 47 rated"` in gold
- If items need votes: `"needs votes"` in amber
- If streaming: `"loading N of ~M..."` in cyan with breathing dot

Use `DecisionCard` with `size="hero"` for the first item (highest consensus per category) and `size="standard"` for the rest.

Pass `entranceDelay` to each card: base delay (rail index × 0.2s) + card index × 0.1s.

Add compressed tail: when items.length > 6, show a "+{N} more" indicator after the 6th card.

- [ ] **Step 2: Add shimmer placeholder for loading state**

Replace the existing loading indicator (breathing dot + "loading" text) with shimmer card placeholders:

```tsx
function ShimmerCard() {
  return (
    <div
      className="flex-shrink-0 snap-start"
      style={{
        width: "130px",
        height: "195px",
        borderRadius: "14px",
        background: "linear-gradient(90deg, rgba(255,255,255,0.02) 0%, rgba(255,255,255,0.06) 50%, rgba(255,255,255,0.02) 100%)",
        backgroundSize: "200px 100%",
        animation: "shimmer 1.5s ease-in-out infinite",
      }}
    />
  );
}
```

Add shimmer keyframe to globals.css:
```css
@keyframes shimmer {
  0% { background-position: -200px 0; }
  100% { background-position: 200px 0; }
}
```

- [ ] **Step 3: Add Framer Motion rail entrance**

Wrap each `CategorySection` in a `motion.div` with staggered entrance:
```tsx
<motion.div
  initial={{ opacity: 0, y: 40 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{
    delay: 0.2 + categoryIndex * 0.2,
    duration: 0.6,
    ease: [0.22, 1, 0.36, 1],
  }}
>
  <CategorySection ... />
</motion.div>
```

- [ ] **Step 4: Verify the page renders with demo data**

Run: `npm run dev` on port 3000. Navigate to a space with demo items (san-diego-trip). Switch to Decide view.
Expected: Category rails appear with staggered entrance. Cards cascade in. Horizontal scroll works.

- [ ] **Step 5: Commit**

```bash
git add src/components/os/PossibilityHorizon.tsx src/app/globals.css
git commit -m "feat: rewrite PossibilityHorizon with Netflix-style fluid rails"
```

---

## Chunk 7: Unsplash Integration

### Task 11: Create Unsplash API client

**Files:**
- Create: `src/lib/unsplash.ts`

- [ ] **Step 1: Write the client**

```typescript
const UNSPLASH_ACCESS_KEY = process.env.NEXT_PUBLIC_UNSPLASH_ACCESS_KEY;

interface UnsplashResult {
  imageUrl: string;
  photographerName: string;
  photographerUrl: string;
}

export async function fetchDestinationPhoto(query: string): Promise<UnsplashResult | null> {
  if (!UNSPLASH_ACCESS_KEY) return null;

  try {
    const res = await fetch(
      `https://api.unsplash.com/photos/random?query=${encodeURIComponent(query)}&orientation=landscape`,
      { headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` } }
    );
    if (!res.ok) return null;

    const data = await res.json();
    return {
      imageUrl: data.urls?.regular ?? "",
      photographerName: data.user?.name ?? "",
      photographerUrl: data.user?.links?.html ?? "",
    };
  } catch {
    return null;
  }
}
```

- [ ] **Step 2: Integrate into space creation**

In `src/lib/spaces.ts`, after `createSpace()` inserts the space row, call `fetchDestinationPhoto(dream)` and update `spaces.metadata` with `hero_url`, `hero_photographer`, `hero_photographer_url`.

- [ ] **Step 3: Commit**

```bash
git add src/lib/unsplash.ts src/lib/spaces.ts
git commit -m "feat: fetch Unsplash hero photo on space creation"
```

### Task 12: Add hero image to Decide page

**Files:**
- Modify: `src/components/os/PossibilityHorizon.tsx`

- [ ] **Step 1: Fetch hero_url from space metadata**

Add a `useEffect` that fetches `spaces.metadata` for the current `spaceId`:
```typescript
const [heroUrl, setHeroUrl] = useState<string | null>(null);

useEffect(() => {
  supabase
    .from("spaces")
    .select("metadata")
    .eq("id", spaceId)
    .single()
    .then(({ data }) => {
      if (data?.metadata?.hero_url) setHeroUrl(data.metadata.hero_url);
    });
}, [spaceId]);
```

- [ ] **Step 2: Render hero image at top of Decide page**

Above the category rails, render the hero with progressive fade:
```tsx
{heroUrl && (
  <div className="absolute inset-x-0 top-0" style={{ height: "45%", zIndex: 0 }}>
    <img src={heroUrl} alt="" className="h-full w-full object-cover" />
    <div
      className="absolute inset-0"
      style={{
        background: `linear-gradient(180deg, rgba(0,0,0,0.25) 0%, transparent 30%, rgba(var(--xark-void-rgb),0.7) 65%, var(--xark-void) 85%)`,
      }}
    />
  </div>
)}
```

- [ ] **Step 3: Commit**

```bash
git add src/components/os/PossibilityHorizon.tsx
git commit -m "feat: display Unsplash hero image on Decide page"
```

---

## Chunk 8: Update Guardrail Files

### Task 13: Update .xark-state.json and CLAUDE.md

**Files:**
- Modify: `.xark-state.json`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update .xark-state.json**

Update `theme_system.themes` to `["hearth (light, default)", "aurora (dark, northern lights video)", "coast (light, california beach video)"]`.

Add `video_backgrounds` key:
```json
"video_backgrounds": {
  "aurora": "/themes/aurora-loop.mp4",
  "coast": "/themes/coast-loop.mp4",
  "fallback": "static WebP poster when video cannot play"
}
```

Update `component_registry` to include `DecisionCard`, `VideoBackground`, `useDeviceTier`.

- [ ] **Step 2: Update CLAUDE.md**

Update THEME SYSTEM section: "3 themes — hearth (light default), aurora (dark, northern lights), coast (light, California beach)". Remove references to cloud, sage, signal, noir, haze.

Add VideoBackground section documenting the component and performance fallbacks.

Add DecisionCard section documenting the 3 size variants.

- [ ] **Step 3: Commit**

```bash
git add .xark-state.json CLAUDE.md
git commit -m "docs: update guardrail files for 3-theme system + new components"
```
