# CLAUDE.md — app/ (hello_app Flutter package)

Per-package guidance for agents working exclusively in `app/`. Read the root
`/CLAUDE.md` first — this file expands on it, does not replace it.

---

## LANDMINES — Read before touching anything

1. **`mock_data.dart` has been renamed to `seed_data.dart`.** The `kUseMockData`
   flag was deleted — all providers now read from the real engine. If the engine
   is uninitialized (pre-auth), providers return empty lists via `engineOrNull()`
   in `providers/engine_helpers.dart`. Empty state widgets (`HelloEmptyState`)
   handle the visual.

2. **Only `/home` and `/auth` are registered routes.** `app/lib/views/chat/`,
   `finance/`, `group/`, `media/`, `plan/`, `settings/` exist as directories
   but are NOT wired into the route table in `main.dart`. They are stubs or
   reached via `Navigator.push` from sheets/cards — not named routes.

3. **`app/test/discover/discovery_widgets_test.dart` is broken.** It imports
   from `app/lib/views/discover/` which was deleted. Run
   `dart analyze lib/` (not `dart analyze .`) to avoid ~30 noise errors from
   this one file. `flutter test` will currently fail because of it.

4. **`PlasmaClockScope` is required.** Every plasma widget (`PlasmaFill`,
   `PlasmaTint`, `PlasmaStroke`, `PlasmaProgressBar`) requires an ancestor
   `PlasmaClock`. `PlasmaClock` already wraps `MaterialApp` in `main.dart`, so
   the app is covered. Widget tests must wrap the widget under test in
   `PlasmaClock(child: ...)` or they will throw.

5. **`engine_error_listener.dart::setupHeadlessErrorBus` is dead code.**
   The call was removed from `initializeEngine` in `main.dart`. The file
   itself still defines the function but nothing invokes it. When a real
   consumer is wired, re-add the call site.

6. **Inter font is bundled** in `app/assets/fonts/` (Regular 400 + Light 300).
   Declared in `pubspec.yaml` under `fonts:`. All platforms render identically.

7. **`HelloGlass` uses a 3-tier system:** `whisperSigma` (14), `veilSigma` (20),
   `curtainSigma` (24). Fill colors (`whisperFill`, `veilFill`, `curtainFill`)
   are brightness-aware getters. Chat bubbles use `bubbleOutboundSigma` (20) and
   `bubbleInboundSigma` (8). Never exceed `curtainSigma` — WebGL crash ceiling
   is 30.

8. **`ChromaticAtmosphere` is the new `AmbientMesh` (Night Shift #3).** Mounted
   at `decision_board_page.dart` via
   `const Positioned.fill(child: ChromaticAtmosphere())`. The old `AmbientMesh`
   class in `atmosphere.dart` is dead code — do not reference it. Kind-token
   tint selection has been replaced by the content-responsive focus-source stack.

9. **`AtmosphereDensityScope` gates saturation.** List pages (`HomePage`,
   `ChatsPage`, `PlansPage`) wrap their body in
   `AtmosphereDensityScope(density: AtmosphereDensity.dense, ...)` — 0.6×
   saturation multiplier preserves scan speed. Detail pages use
   `AtmosphereDensity.focus` — 1.0× full saturation. Always wrap page bodies
   in the correct density scope or the atmosphere will read the wrong tier.

10. **Detail pages must push/pop focus sources with `routeAnimation`.** Every
    detail page (dm, group, decision, trip, settlement, itinerary) binds to
    `ModalRoute.of(context)?.animation`, pushes a `FocusSource` with that
    animation, and uses `_onRouteTick` → `focusSourcesProvider.notifier.touch()`
    to re-emit during iOS edge-swipe-back. Without this, swipe-back snaps
    instead of cross-fading.

11. **`PaletteExtractor.init()` must be called at app startup.** Happens in
    `main.dart` after `WidgetsFlutterBinding.ensureInitialized()`. Loads the
    asset palette manifest (`assets/palettes.json`) and warms the network LRU
    cache. Missing the init call means the atmosphere will fall back to
    kind-token colors and network thumbnails will block on first extraction.

12. **`Conversation.peerId` does NOT exist.** Use `conversation.id` for both
    DM and group focus source identifiers. Gotcha from NS3 Wave C — do not
    try to access a `peerId` field.

13. **`BottomBar`, `TabChip`, `TabPopover`, `StatusOverview`, `DecisionCardSmall`,
    `FocusCardWidget` are deleted (2026-04-14, cosmos-home).** Do not
    re-introduce. BottomBar's role is owned by the scaffold-level
    `LiquidIntentLayer` in `decision_board_page.dart`. StatusOverview's counts
    violated the "no counts on Home" rule. DecisionCardSmall's symbol-square
    buttons violated zero-box. FocusCardWidget was subsumed inline into
    `home_page.dart`'s in-place expansion layer.

14. **`LiquidIntentLayer` is mounted ONCE at the scaffold level**
    (`decision_board_page.dart`, wrapping the entire `TabBarView`). Do not
    add a local mount inside any tab or page widget — that causes ghost-
    indicator desync and double-tracking. Prior local mount in `group_page.dart`
    was removed 2026-04-14.

15. **Cosmos Home animation lock.** `_HomePageState.build()` reads
    `_rewardController.lockedForeground / lockedQueue` when
    `_rewardController.isAnimating`, NOT from
    `freshestPendingSenderProvider` / `pendingSendersQueueProvider`. Both
    providers are still watched unconditionally (Riverpod subscription
    lifecycle), but the displayed foreground/queue branches on the lock.
    Swapping to direct provider reads during the 1700ms reward sequence
    will flash the next person mid-animation — the optimistic mutation has
    already re-emitted.

16. **Cosmos Home uses in-place state expansion, NOT `OpenContainer` / route
    push.** Tapping an avatar on Home flips `_focusedSender` and cross-fades
    two `AnimatedOpacity` layers on Home's own Stack. Pushing a `ModalRoute`
    (via `OpenContainer` or `Navigator.push`) traps the queue + atmosphere
    under the transition and shatters the 1700ms reward choreography. The
    reward plays on the native Home canvas with queue + foreground mounted.

17. **Plasma infusion on `HologramAvatar` uses `BlendMode.srcATop`, NEVER
    `BlendMode.srcIn`.** `srcIn` discards destination pixels and leaves a
    faceless plasma blob. `srcATop` overlays color on top of existing pixels
    where the PNG has alpha — face features stay intact. Also: never wrap
    `HologramAvatar` in a second `ShaderMask` — that's a double `saveLayer`
    and tanks frame rate over the 120fps atmosphere. Use `ColorFiltered`
    (cheaper, single layer) for the infusion layer. The internal
    `_CustomGuillotineAvatar` used during the ascending reward phase
    *replaces* HologramAvatar (it's not wrapped around it).

18. **`RewardController` uses a `Ticker` via `TickerProvider`, NOT
    `Timer.periodic`.** The 1700ms reward sequence must stay synced to
    display vsync. On 120Hz ProMotion displays (8.33ms refresh), an event-
    loop Timer guarantees micro-stutters and frame tearing. `_HomePageState`
    mixes in `SingleTickerProviderStateMixin` to serve as the vsync source.

19. **Action-tap handler awaits 500ms before collapsing Expanded.**
    `ActionWord` runs a 500ms plasma-sweep animation on tap. If
    `_focusedSender = null` fires immediately, the 180ms Expanded-layer
    fade-out will hide the sweep before it completes. `_onActionTap` and
    `_onReplySubmit` are `async` and `await Future.delayed(500ms)` before
    the collapse setState — do not remove this await.

---

## Package identity

| Field | Value |
|-------|-------|
| Package name | `hello_app` |
| SDK constraint | `^3.11.3` (Dart / Flutter ≥ 3.11.3) |
| State management | `flutter_riverpod ^3.3.1` |
| Engine dep | `e2ee_chat_sdk` via `path: ../engine` |
| Grid | `flutter_staggered_grid_view ^0.7.0` |
| Push | `flutter_local_notifications ^18.0.0` |
| Auth | `firebase_core ^3.12.1`, `firebase_auth ^5.5.1` |
| Assets | `assets/decide/`, `assets/memories/`, `assets/images/` (transparent PNG avatars), `assets/textures/` (OLED dither), `assets/palettes.json` |

### Commands

```bash
# Web dev
cd app && flutter run -d chrome --web-port 8080

# Static analysis — lib only (avoids broken test file)
cd app && dart analyze lib/

# Tests — currently fails on broken discovery test
cd app && flutter test

# Specific test file (works despite broken global test suite)
cd app && flutter test test/providers/cosmos_home_providers_test.dart

# Codegen lives in engine/, not app/
# cd engine && dart run build_runner build --delete-conflicting-outputs
```

---

## Entry point + root widget tree

```
main() ──► Firebase.initializeApp()
        ──► PaletteExtractor.init()              // warms palette manifest
        ──► _container = ProviderContainer()
        ──► runApp(
              UncontrolledProviderScope(container: _container,
                child: HelloApp()  // ConsumerStatefulWidget
              )
            )

HelloApp.build() ──► PlasmaClock(          // MUST be above MaterialApp
                       child: MaterialApp(
                         scrollBehavior: _DragEverywhereScrollBehavior(),
                         routes: { '/home': HomeLayout, '/auth': AuthFlowPage },
                         home: HomeLayout(),
                       )
                     )
```

**Deferred engine init:** `engineProvider` starts as `throw UnimplementedError()`.
After the user completes Firebase OTP + AuthService JWT exchange, `initializeEngine()`
calls `_container.updateOverrides([engineProvider.overrideWithValue(engine)])`.
Until that happens, any `ref.watch(engineProvider)` will throw — use
`engineOrNull(ref)` from `providers/engine_helpers.dart` to null-guard.

`_DragEverywhereScrollBehavior` extends `MaterialScrollBehavior` and adds
`mouse`, `trackpad`, and `stylus` to `dragDevices` so `TabBarView` swipe works
on Flutter Web.

---

## 3-tab home scaffold (Home / Chats / Plans)

```
HomeLayout  (passthrough to DecisionBoardPage)
└── DecisionBoardPage (ConsumerStatefulWidget + SingleTickerProviderStateMixin)
    ├── TabController(length: 3)
    └── Scaffold(backgroundColor: HelloColors.voidBg)
        └── Stack(fit: StackFit.expand)
            ├── Positioned.fill ──► ChromaticAtmosphere()   // palette-drenched bg
            ├── SafeArea ──► LiquidIntentLayer(              // scaffold-level handle
            │         child: TabBarView(controller: _tabController,
            │           children: [HomePage, ChatsPage, PlansPage])
            │       )
            └── Positioned(top, left: 20) ──► TabHeader()    // floating avatar / title
```

**Tab signature colors:**

| Index | Label | Color | Hex |
|-------|-------|-------|-----|
| 0 | Home  | focusViolet | `#7C3AED` |
| 1 | Chats | —           | `#8B5CF6` |
| 2 | Plans | focusAlpine | `#4A90E2` |

(Chats absorbed Groups on 2026-04-15 — iMessage-style merged DMs + Groups list. The legacy Groups signature `#F97316` is preserved as `HelloColors.kindGroup` for group-kind card tints, just no longer a tab accent.)

- All 3 page widgets use `AutomaticKeepAliveClientMixin` (call `super.build(context)` at top of `build`).
- `TabHeader`: floating avatar on Home (index 0), large title on Chats / Plans; 220 ms crossfade.
- `LiquidIntentLayer` (scaffold-level as of 2026-04-14): thin plasma line at idle, blooms to `TextField + mic + +` on tap / drag. Replaces the deleted `BottomBar`.
- Ghost-indicator labels `Home · Chats · Plans` render just above the plasma line; the active one is highlighted via `tabAnimationProvider` (ranges `< 0.5` / `[0.5, 1.5]` / `> 1.5`).

---

## Decision board file map

```
app/lib/views/home/decision_board/
├── decision_board_page.dart     # Scaffold root (3-tab controller + LiquidIntentLayer wrap)
├── chromatic_atmosphere.dart    # Full-bleed atmosphere; consumes pulse signal
├── liquid_intent_handle.dart    # The LiquidIntentLayer (scaffold-level)
├── atmosphere.dart              # DEAD (old AmbientMesh widget)
├── tab_header.dart              # Floating top-left header
├── _card_factory.dart           # FeedItem → card mapping (DecisionSmallFeedItem now a shrink sentinel)
├── chat_bubble.dart, conversation_list_row.dart, message_input_bar.dart, floating_avatar.dart
├── empty_state.dart
├── masonry_grid.dart            # Used by the Plans tab only (Home is cosmos, Chats is ListView)
├── consensus_watcher.dart       # Banner overlay watching for decision locks
├── consensus_banner.dart
├── pages/
│   ├── home_page.dart           # Cosmos Home (2026-04-14)
│   ├── chats_page.dart          # iMessage-style merged DMs + Groups list (2026-04-15)
│   ├── plans_page.dart
│   ├── dm_page.dart, group_page.dart (no local LiquidIntentLayer — scaffold owns it)
│   ├── decision_page.dart, settlement_page.dart, trip_page.dart, itinerary_page.dart
│   └── home/                    # Cosmos Home components (2026-04-14)
│       ├── cosmos_sender_model.dart    # PendingSender + MessageKind + extractor
│       ├── foreground_avatar.dart      # 140px w/ reward layers
│       ├── queue_row.dart              # 6×48px + QueuePromotionAvatar
│       ├── context_label.dart          # below-avatar text
│       ├── action_word.dart            # single text-as-action
│       ├── action_words_row.dart       # shape-adaptive row
│       └── reward_controller.dart      # 1700ms vsynced reward orchestrator
├── cards/                       # 10 card widgets (DecisionCardSmall + FocusCardWidget deleted)
│   ├── _card_shell.dart         # Shared shell (uses cardKeyRegistry)
│   ├── dm_card.dart, group_card.dart
│   ├── decision_card_hero.dart
│   ├── focus_hero_card.dart
│   ├── trip_card.dart, settlement_card.dart, itinerary_card.dart
│   ├── memory_card.dart
│   └── ai_nudge_card.dart
├── sheets/                      # 6 bottom sheets (new_chat/search sheets orphaned after BottomBar deletion)
│   ├── dm_sheet.dart, group_sheet.dart
│   ├── decision_sheet.dart, settlement_sheet.dart
│   ├── attachment_sheet.dart
│   ├── new_chat_sheet.dart      # Orphaned; to be rewired to LiquidIntentLayer +
│   └── search_sheet.dart         # Orphaned; same
└── plasma/                      # Liquid Plasma system (7 files)
    ├── plasma.dart              # barrel export
    ├── plasma_gradient.dart     # kPlasmaColors + buildPlasmaGradient()
    ├── plasma_clock.dart        # root AnimationController (PlasmaClock / PlasmaClockScope)
    ├── plasma_fill.dart         # full-bleed animated gradient surface
    ├── plasma_tint.dart         # lower-alpha plasma tint overlay
    ├── plasma_stroke.dart       # animated gradient border
    └── plasma_progress_bar.dart # progress bar with plasma fill
```

### Night Shift #3 ambient palette system

```
app/lib/models/ambient_palette.dart               # AmbientPalette + FocusSource + AmbientSurfaceTier models
app/lib/services/oklch.dart                       # OKLCH color-space conversion + perceptual lerp
app/lib/services/signature_color.dart             # Per-entity signature color derivation
app/lib/services/palette_extractor.dart           # Asset palette manifest + network image LRU extractor
app/lib/providers/focus_sources_provider.dart     # FocusSourceStack StateNotifier
app/lib/providers/ambient_palette_provider.dart   # Derived AmbientPalette + AmbientPalettePulse transient
app/lib/views/home/decision_board/chromatic_atmosphere.dart  # Content-responsive atmosphere renderer
app/assets/textures/dither_noise.png              # Dither noise texture for banding-free gradients
app/assets/palettes.json                          # Bundled palette manifest for seeded assets
```

---

## Liquid Plasma brand system

The full spec is in the root `CLAUDE.md` → "Liquid Plasma Brand System".

**Short version:**
- 5-second diagonal sweep cycling through 4 warm hues:
  `#FF0055` → `#FF0000` → `#FF4D00` → `#FF8C00`
- One shared `AnimationController` per widget tree, owned by `PlasmaClock`.
- `buildPlasmaGradient(phase, {alpha})` in `plasma_gradient.dart` constructs
  the `LinearGradient` for a given animation phase in `[0, 1)`.
- Reduced-motion-aware: check `MediaQuery.of(context).disableAnimations`.

**App-specific wiring rules:**
- `PlasmaClock` **must** be above `MaterialApp` in the widget tree.
  It already is in `main.dart` — do not move it.
- All 4 plasma widgets require an ancestor `PlasmaClockScope` (provided by
  `PlasmaClock`). Never use them outside that scope.
- Widget tests: wrap the widget under test in `PlasmaClock(child: ...)`.
- `HelloColors.accent` (`#FF4D00`) is the flat fallback for non-animated
  surfaces only. Animated surfaces must use the plasma widgets, not a static
  color.

---

## State management (providers)

All providers live in `app/lib/providers/`. All providers read from the real
engine. Pre-auth, `engineOrNull(ref)` (from `engine_helpers.dart`) returns `null`
and providers fall back to empty lists. `seed_data.dart` (formerly `mock_data.dart`)
contains seed/playground data only — no longer gated by a flag.

| Provider | Type | Purpose |
|----------|------|---------|
| `engineProvider` | `Provider<ChatEngine>` | Throws until `initializeEngine()` runs |
| `feedProvider` | `Provider<List<FeedItem>>` | Unified feed (DMs + groups + decisions + trips + settlements + itinerary + memories + AI nudges) |
| `homeFeedProvider` | `Provider<List<FeedItem>>` | Home tab filtered feed (deprecated on cosmos Home — uses the pending-sender providers below instead) |
| `chatsFeedProvider` | `Provider<List<FeedItem>>` | Chats tab filtered feed — iMessage-style merged DMs + Groups, sorted by recency (2026-04-15) |
| `plansFeedProvider` | `Provider<List<FeedItem>>` | Plans tab filtered feed |
| `freshestPendingSenderProvider` | `Provider<PendingSender?>` | Cosmos Home foreground — newest pending item's sender |
| `pendingSendersQueueProvider` | `Provider<List<PendingSender>>` | Cosmos Home queue — next 6 pending senders by recency |
| `focusTripIdProvider` | `StateProvider<String>` | Default: `kMockFocusTripId = 'swiss_jun_2026'` |
| `focusTripProvider` | derived | Trip object for the focus trip |
| `activeTabIndexProvider` | `StateProvider<int>` | Current tab index (0–3) |
| `activeTabProvider` | derived | Enum variant of active tab |
| `tabAnimationProvider` | `StateProvider<double>` | Raw `TabController.animation.value` |
| `centeredFeedItemIdProvider` | `StateProvider<String?>` | ID of the card currently centered in viewport |
| `conversationsStreamProvider` | `StreamProvider` | Live conversations from engine |
| `conversationControllerProvider` | `Provider.family` | Per-conversation message stream |
| `directMessagesProvider` / `groupChatsProvider` | derived | DM / group split |
| `dmUnreadCountProvider` / `groupUnreadCountProvider` | derived | Unread totals |
| `activeDecisionsProvider` | `FutureProvider` | Cross-group merged decision items |
| `focusSourcesProvider` | `StateNotifierProvider<FocusSourceStack, List<FocusSource>>` | Priority-sorted stack (100=sheet, 50=detail, 20=Home foreground, 10=tab fallback) |
| `ambientPaletteProvider` | `Provider<AmbientPalette>` | Derived from focus stack. Drives `ChromaticAtmosphere`. |
| `ambientSurfaceTierProvider` | `Provider<AmbientSurfaceTier>` | WCAG-luminance + saturation → whisper/veil/curtain |
| `ambientPalettePulseProvider` | `StateNotifierProvider<AmbientPalettePulseController, AmbientPalettePulse>` | Transient 800ms reward pulse (affirm/negate/hesitate/none) |
| `playgroundDecisionsProvider` | `NotifierProvider` | Local seed-data vote state |

**`cardKeyRegistry`** — plain global `Map<String, GlobalKey>` (NOT a provider).
Defined in `app/lib/providers/viewport_focus_provider.dart:21`.

---

## Theme tokens (exact values)

From `app/lib/theme.dart` — `HelloColors` class:

| Token | Hex | Usage |
|-------|-----|-------|
| `voidBg` | `#FAFAFA` | Scaffold background (off-white base) |
| `surfaceDeep` | `#FFFFFF` | Elevated surfaces |
| `recessed` | `#F0F0F0` | Chips, avatar backgrounds |
| `white` | `#FFFFFF` | Explicit white (message bubbles) |
| `accent` | `#FF4D00` | Plasma flat fallback only — do not use for animated surfaces |
| `inkPrimary` | `#1A1A1A` | Near-black text |
| `inkSecondary` | `#6B6B78` | Medium gray text |
| `inkTertiary` | `#8A8A94` | Light gray text |
| `focusViolet` | `#7C3AED` | Home tab + Swiss trip accent |
| `focusAlpine` | `#4A90E2` | Plans tab + Alpine trip accent |
| `focusOcean` | `#14B8A6` | Goa trip accent |
| `focusSunset` | `#FF9B6E` | Bali trip accent |
| `liveGreen` | `#047857` | Online presence, live indicators |
| `gold` | `#8B6914` | Consensus lock, premium state |
| `error` | `#C43D08` | Error states |
| `primary` | `#D4536B` | BACKWARD COMPAT ONLY — do not use in new code |

`HelloColors` and `HelloText` are brightness-aware getters (not `static const`).
`HelloThemeMode` enum supports `auto`, `light`, `dark`.

**No-bold mandate:** max `fontWeight: FontWeight.w400` (primary), `w300` (secondary).
Weights 500–900 are forbidden.

---

## Dead code inventory

| Symbol | File | Status |
|--------|------|--------|
| `_ResumeSession` | `main.dart` | Defined but not registered in route table. Dead. |
| `homeActiveCardIndexProvider` | `home_state_provider.dart` | Stale 0–2 relic from an older card-selection design. Not consumed anywhere. Delete when convenient. |
| `setupHeadlessErrorBus` | `engine_error_listener.dart` | Defined but no longer called from `main.dart`. Re-add call site when a real consumer is wired. |
| `mock_data.dart` | `providers/mock_data.dart` | Now a 3-line re-export shim pointing to `seed_data.dart`. Safe to delete once all stale imports are updated. |
| `AmbientMesh` | `views/home/decision_board/atmosphere.dart` | Replaced by `ChromaticAtmosphere` in NS3. `decision_board_page.dart` now mounts `ChromaticAtmosphere()` — the `AmbientMesh` widget is no longer referenced anywhere. File can be deleted in a future cleanup pass. |
| `openNewChatSheet`, `openSearchSheet` | `sheets/new_chat_sheet.dart`, `sheets/search_sheet.dart` | Orphaned after BottomBar deletion (2026-04-14). To be rewired to `LiquidIntentLayer`'s `+` action, or deleted. |

---

## Utilities (`app/lib/utils/`)

| File | Export | Purpose |
|------|--------|---------|
| `haptics.dart` | `HelloHaptic` | 5 semantic methods: `tap()` (lightImpact), `confirm()` (mediumImpact), `celebrate()` (heavyImpact), `select()` (selectionClick), `warning()` (heavyImpact). Wired to all interactive surfaces. |
| `semantics.dart` | `HelloSemantics` | Convenience `StatelessWidget` wrapping Flutter's `Semantics`. |

**Shared provider helper:** `app/lib/providers/engine_helpers.dart` exports
`engineOrNull(Ref ref)` — returns `ChatEngine?` instead of throwing. Used by all
providers that need to gracefully handle the pre-auth state.

---

## Testing status

**Broken test:** `app/test/discover/discovery_widgets_test.dart` imports from
`app/lib/views/discover/` which no longer exists. Options:
1. Delete the test file (safe — the module it tested is gone).
2. Rewrite it against the current decision board UI.

**Workaround for static analysis:**
```bash
cd app && dart analyze lib/   # analyzes lib/ only — 0 errors target
# NOT: dart analyze .         # includes test/ — ~30 errors from broken test
```

**Workaround for running tests:**
```bash
# Either delete the broken test first, or run a specific test file:
cd app && flutter test test/providers/cosmos_home_providers_test.dart
```

---

## Cross-references

- **Root guidance:** `/CLAUDE.md` — Security boundary, E2EE law, no-bold mandate,
  brand color restraint, engine public API, infrastructure lock
- **Design system:** `/DESIGN.md` — Read before any visual/UI decision
- **Cosmos Home spec:** `docs/superpowers/specs/2026-04-14-cosmos-home-design.md`
- **Cosmos Home plan:** `docs/superpowers/plans/2026-04-14-cosmos-home-plan.md`
- **Chromatic Atmosphere spec:** `docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md`
- **Decide-first UX spec:** `docs/superpowers/specs/2026-04-03-decide-first-group-ux-design.md`
- **Decide-first UX plan:** `docs/superpowers/plans/2026-04-03-decide-first-ux-plan.md`
- **Mode chip home design:** `docs/superpowers/specs/2026-04-11-mode-chip-home-design.md`
- **Engine public API:** root `CLAUDE.md` → "Engine Public API" section
- **Web layer:** `web/CLAUDE.md`
