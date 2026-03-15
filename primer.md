# XARK OS — Session Primer

> **For AI agents**: Read this FIRST before any code work. It tells you what changed recently and what to watch for. Updated after every session.

## Last Session: Mar 14-15, 2026

### What was built (continuation)
11. **Memories tab** — Third Galaxy tab (people/plans/memories). Aggregates photos across all spaces. Masonry grid. Demo Unsplash photos.
12. **4-appearance theme system** — hearth (flat light), hearth_dark (flat dark), vibe (depth light), vibe_dark (depth dark). ThemeStyle "flat"|"depth". Components use isVibe boolean. Loosely coupled — add theme = 2 file changes.
13. **Solid ink color system** — ink.primary/secondary/tertiary/sender via CSS variables. All readable text uses solid colors (never opacity). Applied across all 10+ screens.
14. **Login page theme-aware** — all hardcoded #111111/#F8F7F4 replaced with colors.*/ink.* tokens.
15. **Swipe between Galaxy tabs** — horizontal swipe > 60px switches people ↔ plans ↔ memories.
16. **Zero-Box enforcement** — vibe-row containers explored and reverted. Depth comes from avatar shadows + ambient glow only.
17. **@xark intelligence upgrades** — (a) Internal monologue via responseSchema + _thought_process, (b) self-healing retry on empty Apify results, (c) context-aware synthesis with grounding, (d) optimistic "thinking..." UI.
18. **Zero Compromise** — (a) BLOCK_LOW_AND_ABOVE safety filters on all 4 harm categories, (b) Social EQ: protect minorities silently, (c) empathy synthesis rules, (d) gridlock breaker, (e) deadpan easter eggs, (f) boundaries (no coding/essays/personal calendar), (g) smart follow-up: fixed slice bug + eavesdropping bug + 3-minute time decay + context injection.
19. **Enterprise migration TODO** — docs/todo-enterprise-migration.md with pre-migration, day-of, and post-migration checklists.
20. **Sunlight readability** — background #F8F7F4 (brighter), text #111111 (darker), distinct gray #8A8A94 for secondary text. WhatsApp/iMessage reference colors applied.

### Files created this session (continuation)
- `src/components/os/MemoriesTab.tsx` — Galaxy memories tab
- `docs/todo-enterprise-migration.md` — Enterprise migration checklist
- `primer.md` — This file (session changelog)

### Architecture decisions made (continuation)
- Zero-Box strictly enforced: vibe depth = avatar shadows only, never row containers
- Opacity banned for readable text: ink.* solid colors everywhere, textColor(alpha) only for atmospheric elements
- Smart follow-up: question detection + 3-minute time decay + context injection (no eavesdropping)
- Safety: max strictness on all Gemini harm categories, deadpan rejections

---

## Previous Session: Mar 13-14, 2026

### What was built
1. **Netflix-style Decide page** — PossibilityHorizon rewrite with horizontal card rails, DecisionCard component (3 sizes), Unsplash hero banner (destination photo from Firebase Storage), Framer Motion entrance choreography, shimmer loading, smooth momentum scroll.

2. **Login redesign** — Two-screen flow: brand screen ("people, plans and memories. decide together, effortlessly. encrypted, always.") → magic field (phone/OTP/name/photo all morph in same position via AnimatePresence). Country code selector with auto-detect.

3. **4-appearance theme system** — hearth (light flat), hearth_dark (dark flat), vibe (light depth), vibe_dark (dark depth). Style token: `ThemeStyle = "flat" | "depth"`. Components use `isVibe` from ThemeContext, not theme names. Architecture supports unlimited themes — just add to theme.ts + UserMenu THEME_NAMES.

4. **Solid ink color system** — `ink.primary` (#000000), `ink.secondary` (#6B6B78), `ink.tertiary` (#8A8A94), `ink.sender` (#9E6A06). All readable text uses solid colors, never opacity. Survives direct sunlight on $50 Android for 70-year-old users.

5. **Memories tab** — Third Galaxy tab (people/plans/memories). Aggregates photos across all spaces. Masonry grid with hero 2×2 + small tiles. Demo data with real Unsplash photos.

6. **Swipe between Galaxy tabs** — Horizontal swipe > 60px switches people ↔ plans ↔ memories.

7. **Sunlight readability overhaul** — Background #F0EEE9 → #F8F7F4 (brighter). Text #141414 → #111111 (darker). All screens updated: PeopleDock, AwarenessStream, UserMenu, ControlCaret, SpacePicker, OnboardingWhispers, login, join, share pages.

8. **Hero image pipeline** — Unsplash API → download blob → upload to Firebase Storage → store Firebase CDN URL in spaces.metadata.hero_url. Next.js `<Image>` with Vercel edge optimization. Demo fallback images for all spaces.

9. **useDeviceTier hook** — Detects $50 Android (deviceMemory ≤ 2, hardwareConcurrency ≤ 4, prefers-reduced-motion). Returns "high" | "low".

10. **Security fix** — `generateId()` infinite recursion bug in spaces.ts (was calling itself instead of `crypto.randomUUID()`).

### Files created this session
- `src/components/os/DecisionCard.tsx` — 3-size card component
- `src/components/os/VideoBackground.tsx` — HTML5 video with device tier fallback (kept for future use)
- `src/components/os/MemoriesTab.tsx` — Galaxy memories tab
- `src/lib/unsplash.ts` — Unsplash API + Firebase Storage upload
- `src/hooks/useDeviceTier.ts` — Low-end device detection
- `src/types/navigator.d.ts` — deviceMemory type declaration
- `docs/superpowers/specs/2026-03-13-decide-page-themes-design.md`
- `docs/superpowers/plans/2026-03-13-decide-page-themes.md`

### Files significantly modified
- `src/lib/theme.ts` — 4 themes, ThemeStyle, ink system, isVibeStyle helper
- `src/components/os/ThemeProvider.tsx` — ink CSS vars, data-style attribute, isVibe in context
- `src/app/login/page.tsx` — Complete rewrite, fully theme-aware
- `src/components/os/PossibilityHorizon.tsx` — Netflix rails rewrite
- `src/app/galaxy/page.tsx` — 3 tabs, swipe gestures
- `src/components/os/Avatar.tsx` — shape prop (circle/square)
- `src/lib/spaces.ts` — Firebase Storage hero upload, generateId fix
- `src/app/globals.css` — ink CSS vars, shimmer keyframe
- `src/components/os/UserMenu.tsx` — 4 theme picker
- `src/components/os/PeopleDock.tsx` — ink colors, vibe depth avatars
- `src/components/os/AwarenessStream.tsx` — ink colors, vibe depth avatars
- `next.config.ts` — Unsplash + Firebase Storage image domains

### Architecture decisions made
- **Zero-Box Doctrine** strictly enforced — vibe style explored with row containers, then reverted. Depth comes from avatar shadows + ambient glow only, never row containers.
- **Opacity banned for readable text** — `textColor(alpha)` kept only for atmospheric elements (mesh wash, chat foveal dimming). All list text uses solid `ink.*` colors.
- **WhatsApp/iMessage reference** — People tab uses same font sizes (name 17px, preview 14px, time 11px, avatar 46px) and solid color hierarchy.
- **Theme architecture is loosely coupled** — components check `style` field, not theme names. Adding a theme = 2 file changes (theme.ts + UserMenu).

### Known issues
- Unsplash API key not configured (needs `NEXT_PUBLIC_UNSPLASH_ACCESS_KEY` in .env.local)
- VideoBackground component exists but no video themes currently active
- PWA: missing offline support, maskable icons, splash screens (see pwacheck.md)
- XarkChat still uses foveal opacity (intentional for chat, but review if it's readable enough)

### What to do next
- Run Supabase migration 013 (daily use features)
- Configure Firebase for production
- First real users
- PWA production blockers (offline, icons, splash)
