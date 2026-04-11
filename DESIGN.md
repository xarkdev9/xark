# Design System — hello

## Product Context
- **What this is:** A social operating system for real-life coordination. Chat stays clean. Plans become worlds.
- **Who it's for:** Gen Z / Gen Alpha friend groups who plan trips, birthdays, weddings, dinners, and parties together
- **Space/industry:** Social + Planning (not productivity, not project management, not travel booking)
- **Project type:** Mobile-first consumer app (Flutter + Next.js web)
- **One-line goal:** Make social planning feel as desirable as social media, without destroying the chat.

## Product Model
- **Chat** = Private 1:1 messages only
- **Groups** = WhatsApp-style group chats only
- **Plans** = Cross-group universe of all events (trips, birthdays, weddings, parties, dinners, ideas)

## The Core UX Promise
```
Open app → 4-tab scaffold. HOME tab shows the decision board.
Decisions surface at top level — not buried behind a group click.
Swipe tabs → CHATS, GROUPS, PLANS. Background primary blob lerps with you.
Tap a trip hero → atmosphere shifts to that trip's focus color.
Every action surface (send, vote, CTA, unread) breathes with the plasma sweep.

Chat is the heart. Plans are the brain. The home tab is where they meet.
```

---

## Aesthetic Direction
- **Direction:** Cinematic Light + Liquid Plasma — premium social coordination on a clean off-white canvas
- **Decoration level:** Intentional — depth is semantic (flat = passive, plasma-animated = interactive, gold = locked/consensus)
- **Mood:** Emotionally magnetic, cinematic, playful, premium. Zero enterprise energy. Zero dashboard energy. When someone opens it: "damn, this feels new."
- **Anti-mood:** SaaS dashboard, kanban planner, WhatsApp clone, travel booking app, spreadsheet for social life

---

## Design Doctrines

1. **No-Bold Mandate** — Max `font-weight: 400`. Hierarchy via size + opacity + color only. Weight 300 for secondary. Never 500+.
2. **Zero-Box Doctrine** — No card borders, no containers, no boxes for content. Content floats in atmospheric space. Glass containers ONLY for functional necessity (chat bubbles, modals, input bars).
3. **Portals, Not Pages** — Transitions between states are the product's signature. Tab swipes dissolve the background atmosphere. Plans crystallize from the feed.
4. **Plans Are Worlds** — Each plan has its own focus accent color. You don't navigate to a page, you ENTER a mood. The atmosphere shifts with you.
5. **Thumb-Zone Everything** — All primary interactions within thumb reach. Bottom 60% is interactive, top 40% is ambient/visual.
6. **Brand Color Restraint** — Plasma brand color appears only on ~28 action/dopamine surfaces (send, vote, CTA, unread). Lists, chat bubbles, and passive content stay grayscale-clean.

---

## Signature Interactions

### Liquid Plasma Brand Sweep
Every action surface in the app breathes in unison. Send arrows, voting chips, unread dots, progress bars, CTA pills — all sweep a 4-color diagonal gradient on a 5-second repeating cycle. A single `AnimationController` in the app root drives all 28 surfaces simultaneously via `PlasmaClockScope`. The app feels like one living organism, not 28 unrelated disco elements.

### Tab-Color Atmosphere Lerp
As the user swipes between tabs, the primary blob in the `AmbientMesh` background lerps between tab signature colors on every animation frame (`tabAnimationProvider` watches `TabController.animation`). HOME `#7C3AED` → CHATS `#8B5CF6` → GROUPS `#F97316` → PLANS `#4A90E2`. When settled on HOME, the atmosphere also responds to the centered feed item's kind and the focus trip's accent.

### Smart Corner Chat Bubbles
Consecutive same-sender messages fuse visually. Inner corner radius drops to 4px for mid-group bubbles; outer corners stay at 18px. Last-in-group: `18/18/4/18` (outbound) or `18/18/18/4` (inbound). Isolated message: `18/18/18/18`. Bubbles use spring snap-back physics for swipe-to-reply.

### Gold Burst on Consensus
When a decision item reaches ≥80% agreement, 40 gold particles (`GoldBurstOverlay`) explode from the action card. Heavy haptic + notification haptic. Gold is earned — `#8B6914` on light background, never decorative.

### Focus Hero Card
Full-width pinned card for the active focus trip, sits above the masonry feed on the HOME tab. The backdrop glow uses the trip's per-trip accent (e.g., `focusAlpine #4A90E2` for a Swiss trip). The chips and CTAs inside that card are plasma — action always wins over trip tint.

---

## Typography
- **Typeface:** Inter Variable (referenced in code as `'Inter'`) — system-available on modern iOS/Android/web. No bundled fonts in `pubspec.yaml`; relies on platform availability.
- **No-Bold Rule:** Max `font-weight: 400`. Weight 300 for secondary/caption text. Never 500+.
- **Data/Tables:** Geist Mono 400 — tabular figures, precision display.

### Type Scale
| Role | Size | Weight | Tracking | Line Height |
|------|------|--------|----------|-------------|
| Display | 44px | 300 | -0.03em | 1.1 |
| Title | 28px | 400 | -0.02em | 1.2 |
| Heading | 22px | 400 | -0.01em | 1.3 |
| Body | 17px | 400 | 0 | 1.5 |
| Small | 15px | 400 | 0 | 1.5 |
| Caption | 13px | 300 | 0 | 1.5 |
| Label / Micro | 10px | 400 | 0.1em | 1.4 |
| Mono | 13px | 400 | 0.02em | 1.4 |

---

## Color

### Light Theme Base

| Token | Value | Usage |
|-------|-------|-------|
| `voidBg` | `#FAFAFA` | Primary background — off-white base |
| `surfaceDeep` | `#FFFFFF` | Elevated surfaces (sheets, modals) |
| `recessed` | `#F0F0F0` | Subtle gray — chips, avatars, inline inputs |
| `inkPrimary` | `#1A1A1A` | Primary text |
| `inkSecondary` | `#6B6B78` | Secondary text, captions |
| `inkTertiary` | `#8A8A94` | Muted labels, timestamps |
| `gold` | `#8B6914` | Consensus locked, earned states — never decorative |
| `liveGreen` | `#047857` | Settled / owed-to-you positive states |
| `error` | `#C43D08` | Destructive states |

### Liquid Plasma Brand Palette
The animated brand system. All 28 action surfaces animate from this 4-stop gradient.

| Stop | Hex | Name |
|------|-----|------|
| 0.00 | `#FF0055` | Vibrant magenta-red |
| 0.33 | `#FF0000` | Pure red |
| 0.66 | `#FF4D00` | Vivid red-orange |
| 1.00 | `#FF8C00` | Dark neon orange |

**Static fallback (`HelloColors.accent`):** `#FF4D00` — geometric midpoint; used for un-migrated surfaces, design token exports, and email templates. Defined in `app/lib/theme.dart`.

**Plasma vs trip color rule:** Plasma wins on any surface a user acts on. Trip accent colors (focusAlpine, focusOcean, focusSunset) live only on atmosphere, backdrop glow, and passive identity — never on action surfaces.

### Focus Trip Accent Colors (Atmosphere Only)
| Token | Value | Trip context |
|-------|-------|-------------|
| `focusViolet` | `#7C3AED` | Events / HOME default |
| `focusAlpine` | `#4A90E2` | Swiss Alps trips |
| `focusOcean` | `#14B8A6` | Goa / beach trips |
| `focusSunset` | `#FF9B6E` | Bali / warm trips |

### Tab Signature Colors (AmbientMesh blob targets)
| Tab | Color |
|-----|-------|
| HOME | `#7C3AED` |
| CHATS | `#8B5CF6` |
| GROUPS | `#F97316` |
| PLANS | `#4A90E2` |

---

## Chat Bubble Colors

| Type | Fill | Border |
|------|------|--------|
| Outbound | `Colors.white` | `Colors.black @ 8%`, 1px |
| Inbound | `#F0F0F0` (`recessed`) | `Colors.black @ 8%`, 1px |
| @hello AI | `#F0F0F0` with top-edge specular | `Colors.black @ 6%`, 1px |

Width cap: `min(available * 0.72, 360px)` — measured from the ListView cell's actual constraint via LayoutBuilder (NOT screen width).

DM inbound: no avatar gutter. Group inbound: 34px left gutter (28px avatar + 6px spacer) with cluster behavior (avatar shows only on last-in-group).

Text: Inter 16px w400, `inkPrimary #1A1A1A` for both directions.

---

## Grain Texture
Subtle fractal noise overlay at 2.5% opacity on all backgrounds. Prevents flat digital feeling.

```css
/* data URI inline SVG with feTurbulence baseFrequency='0.65' */
opacity: 0.025;
pointer-events: none;
```

---

## Spacing
- **Base unit:** 4px
- **Density:** Spacious — Apple-grade breathing room. Premium = space, not density.
- **Scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64px

---

## Layout
- **Approach:** Gesture-first, tab-disciplined
- **Navigation:** 4 top-level tabs — HOME / CHATS / GROUPS / PLANS
- **Scaffold:** `TabController(length: 4)` + `TabBarView`. All pages use `AutomaticKeepAliveClientMixin` (no re-render on swipe).
- **Bottom bar:** Glass pill replaces `BottomNavigationBar`. Contains: `TabChip` (popover tab switcher) + search field + mic/send + compose `[+]`.
- **Tab header:** Floating avatar (HOME) / large title (other tabs) in top-left — `TabHeader` widget.
- **Web swipe:** `_DragEverywhereScrollBehavior` enables swipe on Flutter Web for mouse + trackpad.
- **Max content width:** Full-bleed on mobile. 440px max for content blocks on web.
- **Safe areas:** All primary touch targets away from Dynamic Island, gesture bar, and screen edges.

### Border Radius
| Element | Radius |
|---------|--------|
| Feed items, lists | 0px (Zero-Box) |
| Chat bubbles | 18px (smart corners: inner drops to 4px in consecutive groups) |
| Glass modals / sheets | 24px |
| Plan / decision tiles | 16px |
| Buttons (pill) | 9999px |
| Avatars | 9999px |
| Inputs | 14px standard, 9999px chat composer |
| Progress bars | 2px |

---

## Glass Treatment Hierarchy (Light Theme)
Glass on a light theme uses white-alpha fills at higher opacity than the dark-theme era, with inverted specular logic.

> **Do NOT use `HelloGlass.fill` or `HelloGlass.border`** in new code on the light theme. Those constants (`0x0A` / `0x0F` white-alpha) are dark-era holdovers and produce invisible surfaces on `#FAFAFA`.

| Level | Usage | Blur | Fill | Border |
|-------|-------|------|------|--------|
| Standard | Bubbles, chips, inline inputs | 8–20px | `Colors.white` or `#F0F0F0` | `Colors.black @ 8%`, 1px |
| Elevated | Modals, sheets, bottom bar | `sigmaX: 24, sigmaY: 24` | `Colors.white.withValues(alpha: 0.92)` | `Colors.black @ 6%`, 1px |
| Locked | Consensus items | 24px | `Colors.white.withValues(alpha: 0.95)` | `gold @ 30%`, 1px |

### Specular Highlights (Glass — Light Theme)
Still present, but with lower alpha than the dark era — the base surface is already bright.

```css
.glass::before {
  content: '';
  position: absolute;
  top: 0; left: 15%; right: 15%; height: 1px;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.08), transparent);
}
```

---

## Motion
- **Approach:** Expressive + spatial — motion is the product's signature
- **Physics:** Spring-based for all interactive elements

### Easing
| Purpose | Curve |
|---------|-------|
| Enter / appear | `cubic-bezier(0.16, 1, 0.3, 1)` — Expo.out |
| Exit / dismiss | `cubic-bezier(0.4, 0, 1, 1)` — ease-in |
| Interactive (hover, press) | `cubic-bezier(0.34, 1.56, 0.64, 1)` — spring overshoot |
| Spring modal | `damping: 20, stiffness: 90` |

### Duration
| Type | Duration |
|------|----------|
| Micro (press, ripple) | 80ms |
| Short (hover, state change) | 200ms |
| Medium (expand, collapse) | 350ms |
| Long (transition, morph) | 600ms |
| Ambient (breathing, drift) | 3000–5000ms |

### Signature Animations
| Animation | Where | Description |
|-----------|-------|-------------|
| Plasma sweep | All 28 action surfaces | 4-color diagonal gradient rotates on 5s cycle, all surfaces in unison |
| Tab-color atmosphere lerp | AmbientMesh background | Primary blob lerps between tab signature colors per-frame during swipe, 600ms settle |
| Gold burst | Consensus lock ≥80% | 40 gold particles explode from action card |
| Tile morph | Decision surface | Card expands from position to full-screen detail |
| AmbientMesh drift | Full-screen background | 5 radial gradient blobs, 26-second sinusoidal drift cycle |
| Breathing text | Vote countdown | Opacity oscillates 0.6→1.0 (3s cycle) |
| Scale press | All tappable elements | 0.97→1.0 with spring overshoot (stiffness 600, damping 28) |
| Stagger reveal | List items | 30ms delay per item on enter |

---

## Haptic Feedback
| Action | Haptic |
|--------|--------|
| Tap button / tile | Light impact |
| Vote cast | Medium impact |
| Consensus lock (gold burst) | Heavy impact + notification |
| Sheet open | Soft impact |
| Pull-to-refresh | Selection changed |

---

## Reduced Motion
All animations respect `MediaQuery.disableAnimations`. When enabled:
- Plasma sweep: clock freezes at phase `0.5` — surface remains colorful but static
- AmbientMesh drift: stops (static blobs at rest position)
- Tab-color lerp: instant swap, no interpolation
- Breathing text: static at full opacity
- Scale press: 200ms ease-out (no spring overshoot)
- Gold burst: instant fade (no particles)

---

## Screen Inventory

### Tier 1 (MVP)
1. **Auth** — Phone OTP entry + verification
2. **Home** — 4-tab decision board (HOME/CHATS/GROUPS/PLANS) with focus hero + masonry feed
3. **DM sheet** — 1:1 message thread, full E2EE
4. **Group sheet** — Group message thread, full E2EE
5. **Decision sheet** — Decision item detail with voting, progress, consensus lock
6. **Settlement sheet** — Expense splitting, pay CTA, debt overview

### Tier 2
7. **Group creation + invite** — QR code + link generation
8. **Settings + profile** — Name, photo, devices, encryption keys
9. **Contact discovery** — Privacy-preserving phone hash lookup
10. **Device management** — Linked devices, revoke

### Tier 3 (Post-launch)
11. **Xpensly** — Full expense splitting surface
12. **Memories** — Media gallery from past plans
13. **Itinerary View** — Timeline of committed decisions

---

## Implementation Rules

### Absolute Laws
1. Every screen calls the real engine API from the first commit. (`kUseMockData = true` is a temporary override — it will be removed.)
2. The Flutter UI never calls Supabase or Firebase directly. All data flows through the engine.
3. No-Bold: `font-weight: 400` max in all shipped code.
4. Zero-Box: No `border`, `background`, or `box-shadow` on feed items, lists, or content cards. Glass only for functional containers.
5. Brand color restraint: plasma widgets (`PlasmaFill`, `PlasmaTint`, `PlasmaStroke`, `PlasmaProgressBar`) only on the ~28 designated action surfaces.
6. Per-trip colors (`focusAlpine`, `focusOcean`, `focusSunset`) are atmosphere-only — never on action surfaces. Plasma wins on actions unconditionally.
7. Do NOT use `HelloGlass.fill` / `HelloGlass.border` in new code (dark-era constants, invisible on light theme).

### Plasma Primitive Locations
All four plasma primitives live in `app/lib/views/home/decision_board/plasma/`:
- `plasma_clock.dart` — shared `AnimationController` + `PlasmaClockScope` `InheritedWidget`
- `plasma_gradient.dart` — `kPlasmaColors`, `kPlasmaStops`, `buildPlasmaGradient(phase)`
- `plasma_fill.dart` — `PlasmaFill` (wraps `BoxDecoration` gradient)
- `plasma_tint.dart` — `PlasmaTint` (wraps `ShaderMask` with `BlendMode.srcIn`)
- `plasma_stroke.dart` — `PlasmaStroke` (wraps `CustomPaint` stroke)
- `plasma_progress_bar.dart` — `PlasmaProgressBar` (custom track + plasma fill)

### Tech Stack
| Platform | Stack |
|----------|-------|
| Web | Next.js 16 + React 19 + Tailwind + Framer Motion |
| Mobile | Flutter + Riverpod + e2ee_chat_sdk engine |
| Fonts | Inter Variable (system) + Geist Mono (web) |
| Icons | Lucide (web) / custom SVG (Flutter) — never emoji |
| Motion (web) | Framer Motion with spring physics |
| Motion (Flutter) | `Curves.easeOutExpo` + `SpringSimulation` |

---

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-10 | Per-plan focus accent colors | Plans are not pages — they're emotional spaces. Color identity makes each plan feel like a distinct world. |
| 2026-04-10 | No-Bold + Zero-Box preserved | These constraints force innovation in hierarchy (size, opacity, color) and prevent the product from looking like every other app. |
| 2026-04-10 | Glass tiles over vertical scroll | 2D tile surface with gravity-based layout keeps everything thumb-reachable without scrolling. |
| 2026-04-11 | Light theme migration | Social-coordination product, not a cinematic content player. Light theme reads as modern, clean, and premium without the "late night" energy of dark. |
| 2026-04-11 | Liquid Plasma Brand System | Replaces the flat `#FF385C` (Rausch) accent. Distinctive brand treatment across every action surface — animated in unison — while honoring the restraint rule. Static fallback: `#FF4D00`. |
| 2026-04-11 | Inter over Satoshi | `app/lib/theme.dart` uses `fontFamily: 'Inter'` throughout. No bundled fonts in `pubspec.yaml`. System availability is the deployment strategy. |
| 2026-04-11 | 4-tab home scaffold replaces group-interior decide-first UX | Decisions are more motivating when surfaced at top level, not buried behind a group click. HOME tab IS the decision board. |
| 2026-04-11 | AmbientMesh replaces Aurora Bridge | The Aurora Bridge lived inside a group chat header. The new AmbientMesh lives beneath the full scaffold and responds to tab swipes — a larger, quieter, more ambient signal. |
| 2026-04-11 | Plasma wins on actions over trip tint | Send button must be plasma unconditionally. Trip-tinted send arrow (`composeAccent = focus?.accentColor`) was a brand dilution bug; the compose bar is an action surface, not an atmosphere surface. |
