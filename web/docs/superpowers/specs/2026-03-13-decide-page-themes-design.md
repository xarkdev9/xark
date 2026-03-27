# Decide Page Redesign + Two Natural Themes — Design Spec

**Date:** 2026-03-13
**Status:** Locked

---

## 1. Overview

Two deliverables:
1. **Decide Page (PossibilityHorizon)** — Netflix-style fluid card rails, streaming entrance, smart density, hero entry transitions. Scales to 600+ items.
2. **Two New Themes** — Real HD video backgrounds on Galaxy home screen. Northern Lights (dark) + California Beach (light). Items left-stacked as floating text on a solid shelf below the video.

---

## 2. Decide Page — Netflix Fluid Rails

### 2.1 Card Architecture
- **No card borders.** Cards are `overflow: hidden` containers with `border-radius: 14px` and box-shadow for depth — but no border property.
- **Photo zone**: Top 40% of card. Real image from Apify `metadata.image_url`. Fallback: category-specific atmospheric gradient (sky tones for flights, warm earth for dining, green for activities).
- **Gradient bridge**: 15% transition zone. Photo dissolves into solid dark via CSS gradient.
- **Data zone**: Bottom 60%. Solid dark (`#0a0a10`). Consensus % is the brightest element. Title, price, source below.
- **Reaction zone**: Bottom 34px. love/okay/pass floating text. Active reaction glows in signal color.

### 2.2 Three Card Size Variants
- **Hero** (consensus leader per category): 150×220px. Consensus at 28px. Gold ambient box-shadow.
- **Standard**: 130×195px. Consensus at 20px.
- **Galaxy mini** (home screen): 100×130px. No reactions. Tap navigates.

### 2.3 Space-Level Hero Image
- Fetched from **Unsplash API** once at space creation. Stored in `spaces.metadata.hero_url`.
- Served via `next/image` with `priority` — auto WebP, srcset, edge-cached by Vercel CDN.
- **Two hero treatments** (user toggles in settings):
  - **Cinematic**: Sharp HD photo, top 45% of Decide page. Progressive gradient fade into void below.
  - **Atmospheric**: Same photo, `blur(30px) saturate(0.6)`, full-page color aura with heavy scrim.

### 2.4 Netflix Entrance Choreography (Framer Motion)
- **0ms**: Page mounts. Hero image loads via `next/image priority`. Data fetch begins.
- **200ms**: First rail header slides up (`translateY(40px) → 0`, 0.6s spring ease).
- **350ms**: Cards cascade in from right with 100ms stagger. Spring overshoot: `scale(0.92) → 1.01 → 1.0`. `translateX(60px) → -4px → 0`.
- **500ms**: Second rail materializes (300ms after first).
- **800ms+**: Remaining rails stagger at 200ms intervals. 6 categories fully loaded by ~1.4s.
- **Shimmer placeholders**: For still-loading data. Gradient animation `200px` sweep, 1.5s cycle.
- **New data arrives**: Shimmer morphs into real card with same slide-in animation.

### 2.5 Card Interactions
- **Hover/touch**: `scale(1.08) translateY(-6px)` with 0.35s spring. Box-shadow deepens. No layout shift (transform only).
- **Vote tap**: Three simultaneous signals — (1) reaction text glows + scale pulse, (2) consensus % ticks up with number animation, (3) bar fills with 0.8s spring.
- **Consensus ignition (>80%)**: Gold burst rings expand from card. Card gets gold ambient box-shadow. "group favorite" label appears. Number scales up and turns gold. Handshake whisper fires in chat.

### 2.6 Category Rails
- **Rail header**: Category name (left) + vital stat (right). "92% on #1 · 5 of 47 rated" / "needs votes" / "loading 34 of ~100..."
- **Horizontal scroll**: CSS `scroll-snap-type: x mandatory` + `-webkit-overflow-scrolling: touch`.
- **Smart density**: Hero card + 4-8 visible standard cards + compressed tail "+43 more". Tap tail to expand.
- **Settled categories**: Auto-collapse to green dot + name + locked item title (existing behavior, kept).
- **Streaming pulse**: Breathing cyan dot next to category name while agent is still fetching.

### 2.7 Virtualization
- Only render visible cards per rail (~8 cards in viewport + 2 buffer).
- `IntersectionObserver` triggers lazy loading of card images and off-screen card mounting.
- 600 items = ~30 DOM nodes total regardless of data size.

### 2.8 Low-End Device Tier ($50 Android)
- Detect: `navigator.deviceMemory <= 2` OR `navigator.hardwareConcurrency <= 4` OR `prefers-reduced-motion`.
- **Entrance**: Simple CSS `opacity 0→1` fade, 0.3s, no stagger.
- **Hover/tap**: `scale(1.04)` only, no shadow change.
- **Shadows**: Single `0 2px 8px rgba(0,0,0,0.2)` instead of multi-layer.
- **Gradients**: Combined single vignette per card instead of 3 layers.
- **Consensus animation**: Instant update, no spring.

---

## 3. Two Natural Themes — Galaxy Home Screen

### 3.1 Architecture
- **Only 3 themes total**: `hearth` (light, default), `aurora` (dark), `coast` (light).
- Remove cloud, sage, signal, noir, haze from `theme.ts` and all related code.
- `ThemeName` type: `"hearth" | "aurora" | "coast"`.
- Each gets a complete `ThemeConfig` entry (label, mode, accent, text, bg, amber, gold, green, orange, gray).
- User selects theme in UserMenu settings (3-option picker).
- When aurora or coast is active, the Galaxy page shows a looping HD video background. All pages use the theme's color system as CSS variables.
- Hearth remains the default. No video background on hearth.
- Fallback: Static WebP poster image when video can't play.

### 3.2 Theme: Aurora (Dark — Northern Lights)

**Video source**: Pexels / Coverr — real northern lights footage. 10-15s seamless loop, 720p, compressed to 1-3MB MP4+WebP poster.

**Implementation**:
```html
<video autoplay muted loop playsinline poster="/themes/aurora-poster.webp"
       class="absolute inset-0 w-full h-full object-cover">
  <source src="/themes/aurora-loop.mp4" type="video/mp4">
</video>
```

**Shelf**: Bottom 50% of screen fades to solid dark (`#040810`) via CSS gradient overlay on top of the video. Items live on this solid shelf — zero video animation behind them.

**Color palette**:
- accent: `#34D399` (aurora green)
- text: `#E0EEF0` (cool silver)
- bg: `#040810` (deep night)
- Amber/gold/green/orange/gray adjusted for dark background contrast.

**Text colors on shelf**: Primary `rgba(230,240,245,0.95)`, secondary `rgba(180,210,225,0.28)`, status green `rgba(52,211,153,0.5)`, status amber `rgba(245,166,35,0.4)`.

### 3.3 Theme: Coast (Light — California Beach/Sunset)

**Video source**: Pexels / Coverr — real California sunset or beach footage. Golden hour waves, coastal light. 10-15s seamless loop, 720p, 1-3MB.

**Implementation**: Same `<video>` pattern.

**Shelf**: Bottom 50% fades to warm paper (`#F0E8DA`) via CSS gradient. Dark ink items on warm ground. Readable in direct sunlight.

**Color palette**:
- accent: `#C88A3C` (golden hour amber)
- text: `#1C1812` (warm dark ink)
- bg: `#F0E8DA` (warm linen)
- Amber/gold/green/orange/gray adjusted for light background contrast.

**Text colors on shelf**: Primary `rgba(28,24,18,0.92)`, secondary `rgba(60,52,38,0.35)`, status green `rgba(4,100,70,0.55)`, status amber `rgba(140,90,5,0.5)`.

### 3.4 Home Screen Item Layout (Both Themes)
- **Left-aligned, vertically stacked.** One column. One scan direction.
- **Size cascade**: 26px → 19px → 15px → 13px → 12px (nearest → furthest trip).
- **Opacity cascade**: 0.95 → 0.6 → 0.35 → 0.18 → 0.08.
- **Content per item**: Space name (`.i-name`), date + countdown (`.i-when`), actionable status if needed (`.i-status`).
- **No borders, no boxes, no lines.** Pure floating text.
- **Hover**: `translateX(6px)` with 0.4s spring ease.
- **Tap**: Navigate to space.

### 3.5 Video Performance
- Videos stored in `public/themes/` — served directly by Vercel CDN.
- `<video>` element with `preload="auto"` on WiFi, `preload="none"` on cellular (via Network Information API).
- `poster` attribute shows static WebP immediately while video loads.
- Low-end device detection: skip video entirely, show poster only.
- Battery: `navigator.getBattery()` — if level < 20%, show poster only.

### 3.6 Unsplash Integration (Space Hero)
- Free API: register app, get access key.
- Fetch at space creation: `GET /photos/random?query={destination}&orientation=landscape`.
- Store `urls.regular` (1080w) in `spaces.metadata.hero_url`.
- Attribution: Unsplash requires photographer credit. Store `user.name` + `user.links.html` in metadata.
- Rate limit: 50 req/hr demo, 5000 req/hr production. One call per space creation = negligible.

---

## 4. Files Affected

### New Files
- `src/components/os/DecisionCard.tsx` — Shared card component (3 size variants)
- `src/lib/unsplash.ts` — Unsplash API client (fetch hero image)
- `src/hooks/useDeviceTier.ts` — Detect low-end device, reduced motion, battery
- `src/components/os/VideoBackground.tsx` — Video background with poster fallback
- `public/themes/aurora-loop.mp4` — Northern lights video
- `public/themes/aurora-poster.webp` — Static fallback
- `public/themes/coast-loop.mp4` — California beach video
- `public/themes/coast-poster.webp` — Static fallback

### Modified Files
- `src/components/os/PossibilityHorizon.tsx` — Complete rewrite (Netflix rails + entrance)
- `src/app/galaxy/page.tsx` — Video background + left-stacked items
- `src/lib/theme.ts` — Remove cloud/sage/signal/noir/haze. Keep hearth, add aurora + coast. `ThemeName = "hearth" | "aurora" | "coast"`
- `src/components/ThemeProvider.tsx` — Update to only map 3 themes (auto-handled since it reads from `themes` record)
- `src/components/os/UserMenu.tsx` — Theme picker shows 3 themes: hearth, aurora, coast
- `src/lib/spaces.ts` — Fetch Unsplash hero on space creation
- `src/app/globals.css` — Shimmer keyframes, new theme CSS variables

---

## 5. What's NOT In Scope
- Galaxy z-depth carousel / 3D interactions (explored, deferred)
- AI-generated images per item
- Reactions on Galaxy mini cards
- Galaxy mini card rails (explored, rejected — too busy)
- Per-card color extraction from images (deferred)
