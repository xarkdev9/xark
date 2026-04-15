# CLAUDE.md — hello Monorepo

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It is auto-loaded at every session start. Fresh agents read this file before their first response — keep it accurate.

**Last refreshed:** 2026-04-11 (via multi-agent audit, see `docs/CHANGELOG.md`)

---

## ⚠️ Critical Landmines (READ BEFORE TOUCHING CODE)

1. **`app/lib/views/home/decision_board/` is the home screen.** `app/lib/demov2/` referenced in older docs no longer exists. The "decide-first group UX with Netflix swim lanes" narrative is superseded.

2. **`kUseMockData = true` is hardcoded** in `app/lib/providers/mock_data.dart`. The Flutter home feed NEVER touches the real engine while this flag is set. Every feed provider has a `if (kUseMockData) return mock...` branch. Flipping to `false` is the only way to get live data.

3. **Engine bootstrap:** `ChatEngine.initialize(...)` does NOT exist on the abstract class. It is a static factory on `ChatEngineImpl`. Call `ChatEngineImpl.initialize(config)`. The barrel exports `ChatEngineImpl` explicitly for this reason. `deviceId` is `int`, not `String`.

4. **`xpensly/xpensly_ui/` is live** (restored 2026-04-11, commit `2a1e66c`). Contains 9 themed Flutter widgets, theme layer, formatters, and 16 widget tests across 6 files. `cd xpensly/xpensly_ui && flutter test` now works. Recovery path: `ui_backup_2026-04-10/flutter/xpensly_ui/` is retained as a backup if the live directory ever regresses.

5. **PQXDH Kyber-1024 is STUBBED.** `crypto/pqxdh/kyber.dart` contains `StubKyber` using 32-byte random arrays, not real Kyber-1024 (1568-byte public keys). The PQXDH protocol layer is correct; the KEM isn't wired. Any code checking or persisting key sizes will break on real-Kyber swap.

6. **Next.js 16 renamed `middleware.ts` → `proxy.ts`.** The rate-limiting edge handler is at `web/src/proxy.ts`, not `middleware.ts`. Do not create a `middleware.ts` — Next.js 16 will ignore it.

7. **`--hello-white = #111111` (dark near-black) and `--hello-void = #FAFAFA` (light near-white).** CSS variable names in `web/src/app/globals.css` are semantically inverted from their values. Confusing. Read the actual hex, not the name.

8. **WebGL Context Loss (OOM limit):** CanvasKit WebGL will fatally crash if `BackdropFilter` sigmas exceed heavy loads on deep lists. **Never use a blur radius > 30px** inside scrolling or transitioning views (legacy screens had 100px and crashed the browser instantly).

9. **Stack Index Differencing Bug:** Never use `if (condition) Positioned(...)` dynamically inside a Flutter Stack wrapped around custom gesture recognizers (e.g. `LiquidIntentLayer`). It shifts child indices, forcing Flutter to unmount the widget and destroying internal AnimationControllers. Always render `Positioned` and return `SizedBox.shrink()` internally instead.

10. **`ChromaticAtmosphere` sigma cap.** The atmosphere itself uses `whisperSigma = 14` internally. **Never wrap it in a `BackdropFilter` with sigma > 24.** Stacking additional blur above the atmosphere compounds into the WebGL OOM ceiling (see landmine #8) and will fatal-crash CanvasKit.

11. **Palette extraction MUST run on the main isolate.** `PaletteExtractor` uses `palette_generator` which relies on `dart:ui` objects (`Image`, `ImageProvider`) that **cannot cross isolate boundaries**. Never `compute()` or `Isolate.spawn` a `PaletteGenerator` call — it will throw at send-port boundary. The extractor already downscales via `ResizeImage(100×100)` so main-isolate cost is bounded.

12. **Detail pages MUST pass `routeAnimation` to `FocusSource`.** Push `FocusSource(..., routeAnimation: ModalRoute.of(context)?.animation)` when pushing routes onto the focus stack. Without it, iOS swipe-back interruption snaps the ambient palette instead of cross-fading back to the parent context. The stack listens to `routeAnimation.status` to reverse gracefully.

13. **Atmosphere NEVER fires haptics.** Haptics originate at tap sites (user intent — see `HelloHaptic` in `app/lib/utils/haptics.dart`), not in the atmosphere system. Palette changes are ambient, not event-ful. Adding haptics to `ChromaticAtmosphere` or its providers will mis-fire during passive scroll-driven palette shifts.

14. **Signature palettes use Oklch, not HSL.** HSL has non-uniform perceived brightness across hues — yellow HSL(60) reads brighter than blue HSL(240) at the same "L" value. `app/lib/services/oklch.dart` provides the Oklch↔RGB conversion used by `signature_color.dart`. Do not substitute `HSLColor` from `dart:ui` for signature generation.

15. **Dither noise PNG opacity is locked at 0.015 (1.5%).** `assets/textures/dither_noise.png` is overlaid on the atmosphere to prevent OLED banding. **Any higher than 1.5% becomes visible stippling; any lower fails to dither.** Regenerating the noise (via `scripts/generate_dither_noise.dart`) must keep the asset itself neutral — tune opacity only at the composite site in `ChromaticAtmosphere`. The atmosphere's pulse signal (2026-04-14, cosmos-home) bumps this to 0.025 briefly during a `Maybe` reward — that's intentional and bounded.

16. **Cosmos Home uses in-place state expansion, NOT `OpenContainer`.** Tapping an avatar on Home must NOT push a `ModalRoute` — it cross-fades Home's own `Stack` via `AnimatedOpacity`. A pushed route traps the queue + atmosphere underneath and shatters the 1700ms reward choreography. See `docs/superpowers/specs/2026-04-14-cosmos-home-design.md` Principle 8.

17. **Plasma infusion on `HologramAvatar` uses `BlendMode.srcATop`, NEVER `BlendMode.srcIn`.** `srcIn` discards destination pixels and leaves a faceless plasma blob where the photo was. `srcATop` overlays color on top of existing pixels only where the PNG has alpha — face features stay intact. Also: never wrap `HologramAvatar` in a second `ShaderMask` — that's a double `saveLayer` and tanks frame rate over the 120fps atmosphere. Use `ColorFiltered` for the transient infusion layer. `PlasmaTint` still uses `srcIn` but only on Text — that's the correct use case (letters fill with plasma gradient).

18. **Home's foreground + queue are locked on a snapshot during reward animations.** `_HomePageState.build()` reads from `_rewardController.lockedForeground / lockedQueue` when the reward phase is not idle. Both providers (`freshestPendingSenderProvider`, `pendingSendersQueueProvider`) remain watched unconditionally (Riverpod subscription lifecycle), but displayed values branch on the lock. Reading directly from the providers' current values during the 1700ms reward sequence flashes the next person mid-animation — the optimistic mutation already re-emitted. Lock releases at t=1700ms.

19. **`RewardController` is vsynced via `Ticker`, not `Timer.periodic`.** On 120Hz ProMotion (8.33ms refresh), an event-loop Timer guarantees micro-stutters and frame tearing. `_HomePageState` mixes in `SingleTickerProviderStateMixin` and passes `vsync: this` to `RewardController`'s constructor. Never replace with a Timer.

---

## Chromatic Atmosphere System (Night Shift #3, 2026-04-14)

**What it is:** A global content-responsive ambient color system. Every screen breathes with whatever content is in focus — card, detail page, route transition, or default tab signature — by resolving a priority-sorted focus stack into a single `AmbientPalette` that drives the full-bleed renderer. **Replaces** the older `AmbientMesh` in `atmosphere.dart`.

**Architecture:**
- `ambientPaletteProvider` (`Provider<AmbientPalette>`) — single source of truth; read by `ChromaticAtmosphere` and adaptive surfaces.
- `focusSourcesProvider` (`StateNotifierProvider<FocusSourceStack, List<FocusSource>>`) — priority-sorted stack of current focus contributors (card in viewport, pushed detail route, default tab). Priority convention: 100=sheet, 50=detail page, 20=Home foreground, 10=tab feed, 1=tab fallback.
- `ambientSurfaceTierProvider` (`Provider<AmbientSurfaceTier>`) — derives adaptive card surface from current palette luminance (WCAG-aware) and platform brightness.
- `ambientPalettePulseProvider` (new 2026-04-14 cosmos-home) — transient 800ms reward modulation: `affirm` (saturation +15%), `negate` (saturation -15% + brightness -10%), `hesitate` (dither 0.015 → 0.025), `none` (base).
- `ChromaticAtmosphere` widget — full-bleed renderer with slow drift, cross-fade between palettes, idle sleep (pause animation when no focus change), OLED-dither noise overlay at 1.5% opacity, consumes pulse signal.
- `PaletteExtractor` service — main-isolate extraction via `palette_generator` + `ResizeImage(100×100)` downscale. Asset-manifest lookup falls through to a network LRU cache (`shared_preferences`-backed).
- `Oklch` color space — perceptually uniform signature generation (NOT HSL — see landmine #14).

**Files:**
- `app/lib/models/ambient_palette.dart` — `AmbientPalette` immutable model
- `app/lib/services/oklch.dart` — Oklch↔RGB conversion
- `app/lib/services/signature_color.dart` — deterministic signature from string seed (IDs, kinds)
- `app/lib/services/palette_extractor.dart` — main-isolate palette extraction + caching
- `app/lib/providers/focus_sources_provider.dart` — `FocusSource` + `FocusSourceStack` notifier
- `app/lib/providers/ambient_palette_provider.dart` — `ambientPaletteProvider` + `ambientSurfaceTierProvider` + `ambientPalettePulseProvider`
- `app/lib/views/home/decision_board/chromatic_atmosphere.dart` — renderer widget (replaces `AmbientMesh`)
- `app/assets/textures/dither_noise.png` — 1.5%-opacity noise PNG (locked — see landmine #15)
- `app/assets/palettes.json` — precomputed palettes for shipped asset images (speeds cold-start)
- `scripts/generate_dither_noise.dart` — regenerates the dither PNG
- `scripts/precompute_palettes.dart` — regenerates `palettes.json` from `app/assets/images/`

**Dependencies added:** `palette_generator ^0.3.3+4`, `crclib ^3.0.0`, `shared_preferences ^2.2.0`, `image ^4.1.0` (dev-only, for the scripts).

**Rules:**
- Atmosphere sigma is effectively `whisperSigma` (14). Never stack `BackdropFilter > 24` above it (landmine #10).
- Palette extraction is main-isolate only (landmine #11).
- Detail pages MUST pass `routeAnimation` (landmine #12).
- Atmosphere is silent — no haptics (landmine #13).
- Signature generation uses Oklch (landmine #14).
- Dither PNG stays at 0.015 opacity (landmine #15).

---

## Cosmos Home System (2026-04-14)

**What it is:** Home replaces the old masonry-of-decisions grid with a floating-avatar surface. Transparent-PNG avatars (built via `app/apply_rembg.py`) hover in the chromatic atmosphere, one foreground at 140px + a recency-sorted queue of 6 × 48px. Tapping any avatar cross-fades in-place to a text-action surface. Action taps trigger a 1700ms vsynced reward sequence.

**Architecture:**
- `pages/home_page.dart` — cosmos Stack orchestrator with Ambient/Expanded/Rewarding state machine
- `pages/home/cosmos_sender_model.dart` — `PendingSender` + `MessageKind` + `pendingSenderFromFeedItem` extractor
- `pages/home/foreground_avatar.dart` — 140×140 with reward-aware levitation + plasma infusion (ColorFiltered srcATop) + ascent guillotine flip
- `pages/home/queue_row.dart` — horizontal 6×48px row + `QueuePromotionAvatar` (Transform.translate from queue Y to foreground Y)
- `pages/home/context_label.dart` — `Message · "subject"` (DM) or `{group} · "subject"` (group)
- `pages/home/action_word.dart` — single text-as-action (no container, transparent-fill Container for full-slot hit zone)
- `pages/home/action_words_row.dart` — shape-adaptive: `Yes/No/Maybe`, `Love/Works/Pass`, `Pay now/Later`, reply TextField
- `pages/home/reward_controller.dart` — vsynced `Ticker` (NOT `Timer.periodic`) driving 1700ms timeline

**Providers (in `filtered_feed_providers.dart`):**
- `freshestPendingSenderProvider` — newest pending item's sender (foreground)
- `pendingSendersQueueProvider` — next 6 by recency, queue excludes foreground

**Principles:**
- Zero-box (no container chrome on any widget)
- No counts on Home (counts create obligation/stress, not dopamine)
- Floating feel (transparent PNGs only, no rings/halos/discs/shadows)
- Text IS the action (no glyph-buttons — `Love/Works/Pass`, not `♥/✓/✗`)
- 3-second rule (who/where/what readable without memory work — no DM exceptions)
- One-tap to action (tap avatar → inflate → tap word)
- Every tap rewards (levitation + plasma infusion + atmosphere pulse + ascent + handoff)

**Spec:** `docs/superpowers/specs/2026-04-14-cosmos-home-design.md`
**Plan:** `docs/superpowers/plans/2026-04-14-cosmos-home-plan.md`

---

## Structure

- **engine/** — Headless E2EE chat SDK (package: `e2ee_chat_sdk`). Barrel: `engine/lib/e2ee_chat.dart`. ~150 Dart source files in `engine/lib/src/`. 33 test files across 10 categories. Contains a `discovery/` subsystem (taste-ranked feed pipeline) in addition to crypto/transport/sync.
- **app/** — Flutter app shell (package: `hello_app`, imports `e2ee_chat_sdk` via path). Light theme. 4-tab home scaffold. Liquid plasma brand system. `kUseMockData = true` hardcoded.
- **web/** — Next.js 16 + React 19 web app. 53 API route handlers (33 non-xpensly + 20 xpensly). Rate limiting in `proxy.ts` (Next.js 16 middleware rename). Xpensly REST API under `api/xpensly/`.
- **algo/** — Standalone TypeScript decision engine, hexagonal architecture, 232 tests (Vitest). Algorithms are **copy-ported** into `web/src/lib/heart-sort.ts` + `web/src/lib/state-flows.ts` — NOT imported as a live dependency.
- **xpensly/** — Expense-splitting SDK. Both layers live: `xpensly_core/` (pure Dart, 30 source files, 69 tests) + `xpensly_ui/` (Flutter widgets, 9 components, 16 tests, restored 2026-04-11 from `ui_backup_2026-04-10/flutter/xpensly_ui/`).
- **docs/** — Architecture specs, plans, test results, CHANGELOG, handoff docs.

---

## SDK Identity
- **Package name:** `e2ee_chat_sdk` (renamed from `hello_engine` — no remaining references in source or guardrails)
- **Barrel file:** `engine/lib/e2ee_chat.dart` (backward-compat: `engine/lib/chat_engine.dart` re-exports)
- **Bootstrap:** `ChatEngineImpl.initialize(ChatEngineConfig)` — NOT `ChatEngine.initialize`
- **BrandConfig:** White-label via `BrandConfig(appName, aiName, aiEndpoint, pushChannelId)`
- **Default brand:** `appName: 'hello'`, `aiName: '@hello'`, `aiEndpoint: '/api/hello'`

---

## Terminology
| Term | Meaning | Old name |
|------|---------|----------|
| group | Shared conversation space | space |
| dm | 1:1 direct message | sanctuary |
| home | Main screen | galaxy |
| hello | The AI assistant (configurable via BrandConfig) | xark, @xark |
| group_id | FK to groups table | space_id |
| invite | Join link | summon |
| suggestions | Proactive hints | whispers |
| consensus | Voting module | handshake |
| MessageType.ai | AI assistant message type | MessageType.hello |

**Exception:** HKDF crypto info strings (`XarkE2EE-*`) intentionally retain the "Xark" prefix — these are cryptographic constants and must not be renamed.

---

## Commands
```bash
# engine
cd engine && flutter test             # 33 test files, 10 categories (crypto/, discovery/, transport/, etc.)
cd engine && dart analyze
cd engine && dart run build_runner build --delete-conflicting-outputs

# app (Flutter)
cd app    && flutter run -d chrome --web-port 8080
cd app    && dart analyze lib/        # lib/ only — test/ has one stale broken file (see below)

# web (Next.js 16 / React 19)
cd web    && npm run dev              # Port 3000
cd web    && npm run build
cd web    && npm test                 # vitest
cd web    && npx tsx tests/sdk-validation.ts  # 100 SDK validation tests (standalone script, NOT vitest)

# algo (TypeScript decision engine)
cd algo   && npm test                 # vitest run — 232 tests across 12 files

# xpensly_core (pure Dart)
cd xpensly/xpensly_core && dart test       # 69 tests
cd xpensly/xpensly_core && dart analyze

# xpensly_ui (Flutter, restored 2026-04-11)
cd xpensly/xpensly_ui && flutter test      # 16 widget tests across 6 files
cd xpensly/xpensly_ui && flutter analyze
```

**Known broken:** `app/test/discover/discovery_widgets_test.dart` imports from the deleted `app/lib/views/discover/` directory. Delete the file or rewrite against current UI. `dart analyze lib/` avoids it; `dart analyze` full project will show ~30 errors from this one file.

---

## Architecture Blueprint
9 loosely coupled services: Auth, Group, Intelligence, Decision Engine, Messaging, Media, Notification, Settlement, Itinerary.
- **Event bus:** Supabase Realtime (Postgres NOTIFY/LISTEN → WebSocket). Channel: `chat:{groupId}`.
- **Scope:** Solo (1 user) + Small Group (2–15 members). Large group deferred.
- **Two-step commitment:** consensus lock (automated at >80%) → claim + purchase (manual, owner + proof).
- **@hello AI:** Silent by default. Three-tier: gemini-local (~7-10s), gemini-search (~40-50s), apify (15-50s).
- **Privacy:** @hello context = grounding state map + last 15 messages on invocation ONLY. No passive listening.

---

## Security Boundary (Iron Rule)
**The Flutter UI NEVER talks to the backend directly.** All data flows through the engine.
```
FORBIDDEN:  supabase.from('users').select(...)     // NEVER from UI
REQUIRED:   engine.getProfile(userId)               // Always through engine
FORBIDDEN:  http.post(Uri.parse('/api/hello'))      // NEVER from UI
REQUIRED:   engine.streamHelloResponse(...)         // Always through engine
```
The engine is the API. Supabase and Firebase are implementation details the UI never sees.

---

## Key Constraints
- **E2EE is absolute law.** No plaintext fallback. If encryption fails, the message does not send. If a feature cannot work with E2EE, the feature does not ship.
- **No-bold mandate.** `font-weight: 400` (primary), 300 (secondary). Weights 500–900 are forbidden.
- **Brand color restraint.** Brand color (`HelloColors.accent` / plasma) applies only to ~28 action/dopamine surfaces. Lists, chat bubbles, and passive content stay grayscale.
- engine/ is headless — zero UI code. UI lives in app/.
- User IDs are text format (e.g., `name_ram`), not UUIDs.
- RLS uses `auth.jwt()->>'sub'` (not `auth.uid()`).
- Port 3000 only for web dev server.
- Database encrypted via SQLCipher (key from platform Keychain).

---

## App Architecture (Flutter — `app/lib/`)

**Entry point:** `app/lib/main.dart` → `UncontrolledProviderScope` → `HelloApp` (`ConsumerStatefulWidget`) → `PlasmaClock(child: MaterialApp)`. `engineProvider` starts throwing and is overridden post-auth via `_container.updateOverrides(...)`.

**Root widget tree:**
```
PlasmaClock
  └── MaterialApp (scrollBehavior: _DragEverywhereScrollBehavior)
        ├── home: HomeLayout → DecisionBoardPage (4-tab scaffold)
        └── /auth: AuthFlowPage
```

**4-tab home scaffold (`decision_board/decision_board_page.dart`):**
- HOME · CHATS · GROUPS · PLANS — `TabBarView` driven by `TabController`
- Full-bleed `AmbientMesh` background (`atmosphere.dart`) — 5 radial blobs on `#FAFAFA` base, primary blob lerps between tab signature colors during swipe
- `BottomBar` glass pill at bottom: `TabChip` (popover switcher) + search field + mic/send + compose `[+]`
- `TabHeader` top-left: floating avatar on HOME, large title on others
- All 4 pages use `AutomaticKeepAliveClientMixin`

**Tab signature colors:** HOME `#7C3AED`, CHATS `#8B5CF6`, GROUPS `#F97316`, PLANS `#4A90E2`.

**Decision board structure (`app/lib/views/home/decision_board/`):**
- `decision_board_page.dart` — 4-tab scaffold root
- `atmosphere.dart` — `AmbientMesh` tab-color-lerp background
- `bottom_bar.dart` — glass pill with plasma-migrated send/compose
- `tab_header.dart`, `tab_chip.dart`, `tab_popover.dart` — tab switcher UI
- `chat_bubble.dart` — glassmorphic bubble with swipe-to-reply, width-capped via LayoutBuilder
- `message_input_bar.dart` — in-sheet message input
- `masonry_grid.dart` — `SliverMasonryGrid.count` (2-col, 12px spacing)
- `_card_factory.dart` — maps 10 `FeedItem` subtypes to cards + sheet openers
- `pages/` — 4 tab content widgets
- `cards/` — 11 card widgets (`_card_shell`, `dm_card`, `group_card`, `decision_card_small`, `decision_card_hero`, `focus_hero_card`, `trip_card`, `settlement_card`, `itinerary_card`, `memory_card`, `ai_nudge_card`)
- `sheets/` — 7 bottom sheets (`dm_sheet`, `group_sheet`, `new_chat_sheet`, `search_sheet`, `decision_sheet`, `settlement_sheet`, `attachment_sheet`)
- `plasma/` — 7-file liquid plasma brand system (see next section)

**Unified feed:** `feedProvider` merges DMs, groups, decisions, trips, settlements, itinerary, memories, AI nudges into one `List<FeedItem>`. Tab-filtered projections: `homeFeedProvider`, `chatsFeedProvider`, `groupsFeedProvider`, `plansFeedProvider`. The focus trip is pinned at index 0.

**State (Riverpod 3.3.1):** Providers in `app/lib/providers/`:
- `engineProvider` (throws until post-auth override)
- `feedProvider` + tab-filtered siblings
- `focusTripProvider`, `focusTripIdProvider` (default: `swiss_jun_2026`)
- `activeTabIndexProvider`, `activeTabProvider`, `tabAnimationProvider` (updated per-frame during swipe)
- `centeredFeedItemIdProvider`, `centeredFeedItemKindProvider` (viewport midline winner → drives atmosphere color)
- `conversationsStreamProvider`, `directMessagesProvider`, `groupChatsProvider` (engine-or-mock)
- `activeDecisionsProvider` (cross-group merge)

**Dead code flags:**
- `_ResumeSession` defined in `main.dart` but not in route table.
- `homeActiveCardIndexProvider` — stale 0–2 relic from pre-4-tab card design.
- `engine_error_listener.dart::setupHeadlessErrorBus` — empty body.
- `app/lib/views/chat/`, `finance/`, `group/`, `media/`, `plan/`, `settings/` — scaffolded stubs, not in route table. Only `/home` and `/auth` are registered.
- `HelloGlass.fill = 0x0AFFFFFF` / `border = 0x0FFFFFFF` — white-alpha values, nearly invisible on `#FAFAFA`. `BottomBar` bypasses them with explicit `Colors.white.withValues(alpha: 0.92)` + black border. Holdover from dark era.

**Theme tokens (`app/lib/theme.dart`):**
- `voidBg = #FAFAFA` · `surfaceDeep = #FFFFFF` · `recessed = #F0F0F0`
- `accent = #FF4D00` (plasma flat stand-in; animated surfaces use plasma widgets — see next section)
- `inkPrimary = #1A1A1A` · `inkSecondary = #6B6B78` · `inkTertiary = #8A8A94`
- Focus trip colors: `focusAlpine #4A90E2` · `focusOcean #14B8A6` · `focusSunset #FF9B6E` · `focusViolet #7C3AED`
- `liveGreen = #047857` · `gold = #8B6914` · `error = #C43D08`

**No bundled fonts in pubspec.** Inter is referenced as `fontFamily: 'Inter'` but must be system-provided or loaded externally. Potential gap for native targets.

---

## Liquid Plasma Brand System (`app/lib/views/home/decision_board/plasma/`)

**What it is:** An animated 4-color gradient that replaces the flat Rausch accent across ~28 action/dopamine surfaces (send arrows, voting chips, CTAs, unread indicators, progress bars, eyebrow labels). All 28 surfaces read from a single shared `AnimationController` so they animate in perfect unison.

**Palette (warm sweep):** `#FF0055` → `#FF0000` → `#FF4D00` → `#FF8C00`
**Cycle:** 5 seconds diagonal sweep. Reduced-motion-aware: `MediaQuery.disableAnimationsOf(context)` freezes the phase at 0.5.
**Flat fallback:** `HelloColors.accent = #FF4D00` for surfaces that can't animate.

**7 files:**
1. `plasma.dart` — barrel
2. `plasma_gradient.dart` — `kPlasmaColors`, `kPlasmaStops`, `kPlasmaCycle`, `buildPlasmaGradient(phase, {alpha})`
3. `plasma_clock.dart` — `PlasmaClock` (StatefulWidget, wraps app root) + `PlasmaClockScope` (InheritedWidget) → `ValueListenable<double>`
4. `plasma_fill.dart` — `PlasmaFill({child, borderRadius, alpha, shape, width, height})` replaces `BoxDecoration(color: accent)`
5. `plasma_tint.dart` — `PlasmaTint({child})` — ShaderMask (BlendMode.srcIn) for Text/Icon
6. `plasma_stroke.dart` — `PlasmaStroke({child, width, borderRadius})` — CustomPaint foreground border
7. `plasma_progress_bar.dart` — `PlasmaProgressBar({value, height, backgroundColor})` replaces `LinearProgressIndicator`

**Wiring rule:** `PlasmaClock` must be the outermost widget above `MaterialApp`. Any plasma widget without a `PlasmaClockScope` ancestor will assertion-fail. Isolated widget tests must wrap in `PlasmaClock(child: ...)`.

**Plasma vs. per-trip color rule:** Plasma wins on action surfaces. Per-trip accents (`focusAlpine`/`focusOcean`/`focusSunset`) stay on passive identity surfaces (atmosphere, hero backdrop) only.

**Spec:** `docs/superpowers/specs/2026-04-11-liquid-plasma-brand-design.md`
**Plan:** `docs/superpowers/plans/2026-04-11-liquid-plasma-brand-plan.md`

---

## Engine Public API (`e2ee_chat_sdk`)

### Bootstrap
```dart
// MUST call the impl class — ChatEngine abstract has no initialize method
final engine = await ChatEngineImpl.initialize(ChatEngineConfig(
  authToken: authToken,       // String
  userId: userId,             // String (not UUID)
  deviceId: deviceId,         // int (NOT String)
  pushToken: pushToken,       // String
  serverBaseUrl: serverUrl,   // Uri
  supabaseAnonKey: anonKey,   // String — required for PostgREST
  brand: BrandConfig(appName: 'hello', aiName: '@hello'),
));
```

### ChatEngine (streams + actions)
```dart
// Streams
engine.conversations           // Stream<List<Conversation>>
engine.connectionState         // Stream<EngineConnectionState>
engine.totalUnreadCount        // Stream<int>
engine.errors                  // Stream<ChatEngineError>

// Profile / devices / push
engine.getProfile(userId)
engine.updateProfile(displayName: ..., photoUrl: ...)
engine.getDevices()                                 // List<DeviceInfo>
engine.unlinkDevice(int deviceId)
engine.getDisplayName(userId)                       // cached
engine.updatePushToken(newToken)                    // REQUIRED on FCM/APNs token rotation

// Groups / DMs / invites
engine.createGroup(title: ..., atmosphere: ...)
engine.findOrCreateChat(peerId)                     // DM bootstrap
engine.generateInvite()
engine.claimInvite(code)

// Contact discovery
engine.discoverContacts(List<String> hashes)

// AI
engine.streamHelloResponse(prompt: ..., groupId: ...)

// Per-conversation handle
engine.getSession('group_123')  // ChatSession

// Lifecycle
engine.suspend() / engine.resume() / engine.dispose()
```

### ChatSession
```dart
session.messages      // Stream<List<Message>>
session.typing        // Stream<List<TypingIndicator>>
session.receipts      // Stream<List<Receipt>>
session.presence      // Stream<PresenceState>
session.sendText(plaintext)
session.sendMedia(MediaPayload(...))
session.sendTyping()
session.markRead(messageId)
session.react(messageId, emoji)
session.deleteForMe(messageId)
session.deleteForEveryone(messageId)
session.loadMore(limit: 50)
session.getKeyFingerprint()
```

### Optional mixin: `ChatEngineDecisions`
```dart
if (engine is ChatEngineDecisions) {
  engine.getDecisionItems(groupId)
  engine.reactToItem(itemId, signal)
  engine.lockItem(itemId, proof)
  engine.addDecisionItem(...)
  engine.encryptPayload(...)
  engine.decryptPayload(...)
}
```

### Auth (separate service, called BEFORE engine)
```dart
final auth = AuthService(serverBaseUrl);
final result = await auth.authenticateWithFirebase(firebaseIdToken: token);
// result.accessToken → feed into ChatEngineConfig.authToken
```

---

## Engine Architecture (`engine/lib/src/`)

Top-level `src/` files: `chat_engine_impl.dart`, `chat_session_impl.dart` (NOT in `public_api/` — impls live one level up).

Subdirectories:
- `public_api/` — abstract `ChatEngine`, `ChatSession`, `ChatEngineConfig`
- `adapters/` — Supabase/Firebase/SSE adapter implementations
- `auth/` — AuthService, AppLockManager
- `config/` — BrandConfig
- `contacts/` — Private contact discovery (truncated SHA-256)
- **`crypto/`** — Signal Protocol (X3DH, Double Ratchet, Sender Keys, PQXDH)
  - `keys/` — Key management, hardware key store, Ed25519↔Curve25519 conversion, database key manager
  - `media/` — Streaming AEAD (AES-256-GCM, 64KB chunks), BlurHash
  - `pqxdh/` — Post-quantum hybrid (X25519 + **stubbed** Kyber-1024 — see landmine #5)
  - `ratchet/` — Double Ratchet with 1000-entry skipped-key dict, header encryption
  - `sender_keys/` — Group cipher, SQLite-backed sender key store, SK recovery
  - `x3dh/` — X3DH + 3-DH fallback on OTK exhaustion
  - `franking/` — MessageFranking abstract interface (no concrete impl yet)
  - `profile/` — Profile key encryption
- `devices/` — DeviceRegistry + DeviceLinking (abstract interfaces only — no concrete impl)
- **`discovery/`** — Taste-ranked discovery feed (undocumented in older CLAUDE.md). Subdirs: `cache/`, `feedback/`, `models/`, `ranking/`. Exports `DiscoveryMixin`, `CarouselCard`, `TasteProfile`, `TasteRanker` via the barrel.
- `domain/` — Freezed models (Message, Conversation, Receipt, etc.) + use cases
- `extensions/` — `ChatEngineDecisions` mixin
- `intelligence/` — `OnDeviceSLM` abstract + `FallbackSLM` (regex) impl only — no CoreML/NNAPI yet
- `media/` — Background uploader, link unfurling
- `notifications/` — `push_decryptor.dart` (working) + `interactive_actions.dart` (stub handler bodies)
- `observer/` — ChatEngineObserver, E2EE metrics
- `persistence/` — Drift ORM + SQLCipher, repositories, local feed. `DatabaseFactory` uses conditional imports: `database_factory_native.dart` is SQLCipher-encrypted; **`database_factory_stub.dart` throws `UnsupportedError` on `createDatabase()`** — the web build hard-crashes at database init, not silently degrades. Any web deployment that needs persistence must provide a custom `createDatabase` implementation (e.g. IndexedDB-backed).
- `ports/` — Transport interfaces (MessageGateway, RealtimeGateway, TransientQueue, PushAdapter, AIAdapter)
- `sync/` — SyncCoordinator, OutboxWorker, WatermarkSync, ConflictResolver
- `transport/` — SupabaseClientWrapper, RealtimeListener, typing indicators, realtime receipts

**Tests:** 33 files across `test/crypto/` (10), `test/discovery/` (10), `test/transport/` (4), `test/domain/` (2), `test/interop/` (2), `test/integration/` (1), `test/media/` (1), `test/persistence/` (1), `test/sync/` (1), `test/` root (1).

---

## E2EE Architecture

Signal Protocol implementation with post-quantum upgrade path:
- **L1:** Key management (identity keys, signed pre-keys, OTKs, Kyber pre-keys)
- **L2:** Message encryption (zero-knowledge — server never sees plaintext)
- **L3:** Structured intelligence (AI reads only server_content, never E2EE payloads)
- **1:1 (dm):** Double Ratchet with X3DH key agreement (3-DH fallback when no OTK)
- **Groups (2–15):** Sender Keys with Ed25519 message signing + ACK-based distribution
- **Post-quantum:** PQXDH hybrid X25519 + Kyber-1024 — **protocol layer works, Kyber KEM is currently `StubKyber` (32-byte stub, NOT real Kyber-1024)**. See landmine #5.
- **Multi-device:** Sesame protocol (5 devices, fan-out encryption, QR linking) — abstract interfaces defined, no concrete registry impl yet
- **Media:** Streaming AEAD (64KB chunks, up to 2GB, AES-256-GCM)
- **Push:** iOS NSE + Android Service + Web SW (fallback: "You may have new messages"). `push_decryptor.dart` is working; `interactive_actions.dart` has stub handler bodies.
- **Primitives:** XChaCha20-Poly1305 AEAD, Ed25519, Curve25519 DH, HKDF-SHA-256, Argon2id
- **Runtime (web):** libsodium-wrappers-sumo (WASM), client-side only
- **Runtime (engine):** `cryptography` package (pure Dart, cross-platform)
- **HKDF info strings use `XarkE2EE-*` prefix** — crypto constants, do not rename
- **Crypto isolate:** Dedicated background isolate, TransferableTypedData, 10s watchdog, 3 max respawns

---

## Web Infrastructure (`web/src/lib/`)
- `postgres-pool.ts` — TCP connection pool singleton
- `rate-limit-edge.ts` + `rate-limit.ts` — Upstash Redis rate limiting
- `key-cache.ts` — Key bundle Redis cache
- `jwt-replay.ts` — JWT replay protection
- `appcheck.ts` + `appcheck-verify.ts` — Firebase AppCheck device attestation
- `crypto/` — 24 TypeScript crypto modules (mutex, uuidv7, pqxdh, kyber, sk-recovery, streaming-aead, message-franking, device-registry, etc.)
- `ports/` — Strangler Fig interfaces (MessageGateway, RealtimeGateway, TransientQueue)
- `discovery/` — Taste-ranked discovery backend with provider registry and Gemini/Apify scraping adapters
- `intelligence/` — 18 modules (orchestrator, async-queue, searchapi-client, flight-cache, ai-provider-factory, itinerary-generator, taste-intersection, deep-links, geospatial, conflict-resolver, search-cache, global-semaphore, etc.)
- `proxy.ts` — Next.js 16 middleware entry point (renamed from `middleware.ts`). Rate limiting runs here.

**API routes:** 53 total
- 33 non-xpensly routes (including undocumented `/api/discovery/*` group of 8 routes + `/api/cron/warm`)
- 20 xpensly routes (10 stateless calculation + 10 stateful trip management)
- 8 helper modules in `web/src/app/api/xpensly/lib/`

**Tests:** `tests/sdk-validation.ts` (100 tests, standalone tsx script), vitest unit tests in `src/lib/__tests__/`, Playwright e2e tests in `tests/e2e/`, orchestrator stress tests in `tests/orchestrator-stress/`, discovery API test.

---

## Database Migrations (Fortress)
- `group_sequences` — O(1) per-group monotonic sequence counters
- `send_e2ee_message` — Atomic RPC (membership + clock skew + sequence + idempotent insert + ciphertext fan-out)
- `read_watermarks` — Replaces unread_counts (no deadlocks)
- `sk_acknowledgments` — O(1) sender key distribution tracking
- `uuidv7_to_timestamptz` — Extract timestamp from UUIDv7 for partition pruning
- `tombstone_message` — GDPR deletion with partition-pruned ciphertext removal
- PQXDH columns on `key_bundles` and `one_time_pre_keys` (nullable, backward-compat)
- `user_devices` — Multi-device registry (5-device limit trigger)

---

## Xpensly SDK (Expense Splitting)

**Three-layer architecture — all layers live:**

**`xpensly_core`** (pure Dart, live at `xpensly/xpensly_core/`) — 30 source files, 69 tests
- Modules: `split_calculator`, `settlement_engine`, `debt_simplifier`, `currency_converter`, `recurrence_expander`, `trip_aggregator`
- Ports: `XpenslyDataSource`, `XpenslyPaymentProvider`, `RateProvider`
- Adapters: `InMemoryDataSource` (only live data source — `SupabaseDataSource` does NOT exist, not even as a stub file)
- Payment providers: `VenmoPayment`, `UpiPayment`, `PaypalPayment`, `StripePayment`, `RazorpayPayment` (all live)
- Rate provider: `FixedRateProvider`
- Split modes: `equal`, `exact`, `percentage`, `shares`
- Barrel: `lib/xpensly_core.dart`

**`xpensly_ui`** (Flutter, live at `xpensly/xpensly_ui/`, restored 2026-04-11 from `ui_backup_2026-04-10/flutter/xpensly_ui/`) — 9 themed widgets, theme layer, formatters, 16 widget tests across 6 files.
- Widgets: `ExpenseEntry`, `SettlementCard`, `DebtCard`, `PaymentButton`, `ExpenseList`, `BalanceBar`, `TripSummaryWidget`, `SplitModeToggle`, `XpenslyDashboard`
- Theme: `XpenslyTheme` (InheritedWidget) + `XpenslyThemeData` with presets `hello()`, `material()`, `minimal()`
- Utilities: `formatters.dart` (currency/date formatting)
- Depends on `xpensly_core` via `path: ../xpensly_core`

**REST API** (`web/src/app/api/xpensly/`) — 20 route handlers (10 stateless + 10 stateful) + 8 helper modules in `lib/`

**Spec:** `docs/superpowers/specs/2026-04-02-xpensly-sdk-design.md`
**DB tables:** `xpensly_trips`, `xpensly_trip_members`, `xpensly_expenses`, `xpensly_expense_payers`, `xpensly_expense_splits`, `xpensly_settlements`, `xpensly_refunds`, `xpensly_exchange_rates`

---

## Pluggable Adapters (White-Label SDK)
The engine uses port interfaces — implementations are swappable:
- **TransportAdapter:** `MessageGateway`, `RealtimeGateway`, `TransientQueue` (default: Supabase)
- **PushAdapter:** `FirebasePushAdapter` / `NoopPushAdapter` (default: Firebase)
- **AIAdapter:** `SSEAIAdapter` / `NoopAIAdapter` (default: SSE to brand's `aiEndpoint`)
- Supabase and Firebase are optional — customers can provide their own adapters

---

## Infrastructure Lock (Default Stack)
| Service | Provider | Purpose |
|---------|----------|---------|
| Auth (Phone OTP) | Firebase Auth | Phone verification, identity |
| Database | Supabase Postgres | All data, decision engine, RLS |
| Realtime | Supabase Realtime | WebSocket event bus |
| Storage (E2EE) | Firebase Storage | Encrypted media blobs |
| Push | Firebase Cloud Messaging | iOS/Android/Web push |
| Intelligence | Gemini 2.5 Flash | @hello AI, intent parsing |
| Rate Limiting | Upstash Redis | Edge rate limiting, key cache, JWT replay |

**FORBIDDEN:** Supabase Auth, Firestore, direct Supabase queries from Flutter UI.

---

## Signal System (Reaction Vocabulary)
Defined in `algo/src/models/types.ts`:
- **LoveIt:** weight `+5`. Color: plasma / `var(--hello-accent)` in web.
- **WorksForMe:** weight `+1`. Color: gray.
- **NotForMe:** weight `-3`. Color: orange.
- One reaction per user per item. Last reaction wins. Score can go negative.

**Agreement score rule:** `NotForMe` **IS counted** in the agreement percentage. The agreement score is the fraction of group members who have ANY reaction on an item — all three reaction types (LoveIt, WorksForMe, NotForMe) contribute to the unique-reactor count that determines the percentage. This is consistent across the algo source of truth and the web port (see `web/src/lib/heart-sort.ts:178-179, 189-190` for the authoritative implementation comment). The `weightedScore` (ranking signal, uses the +5/+1/-3 weights) is a **separate** computation from the `agreementScore` (consensus signal, a participation count).

---

## State Machine (4 Preset Flows)
Defined in `algo/src/engine/state-flows.ts`:
- **BOOKING_FLOW** (default): `proposed` → `ranked` → `locked`. **Web port extends:** `locked` → `claimed` → `purchased` (extension lives in `web/src/lib/state-flows.ts`, NOT in algo canonical source).
- **PURCHASE_FLOW:** `researching` → `shortlisted` → `negotiating` → `purchased`
- **SIMPLE_VOTE_FLOW:** `nominated` → `ranked` → `chosen`
- **SOLO_DECISION_FLOW:** `considering` → `leaning` → `decided`

---

## RLS Policies
- `auth_user_group_ids()`: SECURITY DEFINER function, returns group_ids for the authenticated user.
- All tables filter via this function.
- **IMPORTANT:** `auth.uid()` requires UUID. Our IDs are text (e.g., `name_ram`), so use `auth.jwt()->>'sub'`.

---

## Deployment
- **GitHub:** `git@github.com:xarkdev9/xark.git` (remote: new-origin)
- **Vercel:** project under scope `xarks-projects-700da30e`
- **Production URL:** https://gethello.ai
- Push: `GH_TOKEN=$(gh auth token) git -c "http.https://github.com/.extraheader=Authorization: basic $(echo -n "x-access-token:$(gh auth token)" | base64)" push new-origin main`

---

## CSS Variables (Web)
All theme tokens use `--hello-*` prefix, defined in `web/src/app/globals.css` `:root`. See `web/CLAUDE.md` for the grouped list.

**⚠️ Naming landmine:** `--hello-white = #111111` (dark near-black) and `--hello-void = #FAFAFA` (light near-white). Values are semantically inverted from the variable names. Read the hex, not the name. `--hello-cyan` is aliased to `--hello-accent` (same `#FF6B35` value — not a separate color).

---

## Design System
See `DESIGN.md` — refreshed 2026-04-11 to reflect the light theme + Liquid Plasma brand system. Covers aesthetic direction, light color tokens, plasma palette, focus trip + tab signature colors, chat bubble spec, AmbientMesh atmosphere, 4-tab layout, glass hierarchy, and motion/haptic rules. Read DESIGN.md before any visual/UI decision.

**Enforcement rules (doctrines — non-negotiable):** No-Bold (max weight 400), Zero-Box (no card borders on content; glass only for functional containers), brand color restraint (~28 action surfaces only), plasma wins on action surfaces (overrides trip tint).

---

## Changelog

Project changelog lives at `docs/CHANGELOG.md`. **Append-only**, newest entries on top, one entry per spec→plan→implementation cycle (not per commit). Each entry: one-line summary, why, commit range, architecture notes, spec/plan paths, gotchas, out-of-scope. Retroactive entries for prior work are short; new entries use the full template.

**Auto-librarian wired (2026-04-11):** A `Stop` hook at `docs/hooks/update-guardrails.sh` automatically refreshes this `CLAUDE.md` and `docs/CHANGELOG.md` whenever a Claude Code session ends with new source commits. The librarian runs as a `claude --print --bare` headless session — surgical edits only, append-only changelog, never rewrites philosophy. See `docs/hooks/README.md` for design principles, gates, and debugging. Manual override: `touch /tmp/hello-librarian-skip` to suppress the next fire.

---

## Key Documents
- `docs/CHANGELOG.md` — Append-only project history, newest first
- `docs/hooks/` — Stop-hook auto-librarian (script + locked prompt + design README)
- `docs/superpowers/specs/2026-04-11-liquid-plasma-brand-design.md` — Plasma brand spec
- `docs/superpowers/plans/2026-04-11-liquid-plasma-brand-plan.md` — Plasma plan (3 waves, 12 tasks)
- `docs/superpowers/specs/2026-04-03-decide-first-group-ux-design.md` — Superseded UX spec (archived, do not use as current)
- `docs/superpowers/specs/2026-04-02-xpensly-sdk-design.md` — Xpensly SDK design spec
- `docs/FRONTEND_HANDOFF.md`, `docs/FRONTEND_TO_BACKEND_HANDOFF.md` — Earlier integration handoffs
- `PHASE_1_FRONTEND_MANIFEST.md` — Phase 1 UI completion state
- `crypto.md` — 50-task engineering checklist
- `docs/4PM_Goal.md` — 42-step planet-scale blueprint
- `app/CLAUDE.md` — Per-package Flutter app guidance (entry flow, 4-tab scaffold, plasma wiring, providers, dead code inventory)
- `engine/CLAUDE.md` — Per-package E2EE SDK guidance (public API, critical stubs, test infrastructure)
- `web/CLAUDE.md` — Per-package Next.js 16 web guidance (full 53-route inventory, CSS variable inversion, request flow)
- `algo/CLAUDE.md` — Per-package TypeScript decision engine guidance (hexagonal architecture, state flows, signal vocabulary)
- `xpensly/CLAUDE.md`, `xpensly/xpensly_core/CLAUDE.md`, `xpensly/xpensly_ui/CLAUDE.md` — Per-package Xpensly SDK guidance
