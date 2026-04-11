# CLAUDE.md — app/ (hello_app Flutter package)

Per-package guidance for agents working exclusively in `app/`. Read the root
`/CLAUDE.md` first — this file expands on it, does not replace it.

---

## LANDMINES — Read before touching anything

1. **`kUseMockData = true` is hardcoded** in `app/lib/providers/mock_data.dart`
   (line 16). The home feed NEVER hits the real engine. Every provider has an
   `if (kUseMockData) return mock...` branch. If the UI looks wrong with a real
   engine, flip this flag. It is THE biggest gotcha in this package.

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

6. **No bundled Inter font.** `pubspec.yaml` has no `fonts:` section for Inter.
   `fontFamily: 'Inter'` in `ThemeData` and `HelloText` relies on system font
   availability. On native targets where Inter is absent, the system default
   renders instead — no crash, but visual drift.

7. **`HelloGlass.fill` and `HelloGlass.border` are dark-era holdovers.**
   Values are `0x0AFFFFFF` (4% white) and `0x0FFFFFFF` (6% white) — nearly
   invisible on the `#FAFAFA` light background. Do not use in new code.

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
| Assets | `assets/decide/`, `assets/memories/` |

### Commands

```bash
# Web dev
cd app && flutter run -d chrome --web-port 8080

# Static analysis — lib only (avoids broken test file)
cd app && dart analyze lib/

# Tests — currently fails on broken discovery test
cd app && flutter test

# Codegen lives in engine/, not app/
# cd engine && dart run build_runner build --delete-conflicting-outputs
```

---

## Entry point + root widget tree

```
main() ──► Firebase.initializeApp()
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
Until that happens, any `ref.watch(engineProvider)` will throw — guard reads with
`try/catch` or check `kUseMockData`.

`_DragEverywhereScrollBehavior` extends `MaterialScrollBehavior` and adds
`mouse`, `trackpad`, and `stylus` to `dragDevices` so `TabBarView` swipe works
on Flutter Web.

---

## 4-tab home scaffold

```
HomeLayout  (passthrough to DecisionBoardPage)
└── DecisionBoardPage (ConsumerStatefulWidget + SingleTickerProviderStateMixin)
    ├── TabController(length: 4)
    └── Scaffold(backgroundColor: HelloColors.voidBg)
        └── Stack(fit: StackFit.expand)
            ├── Positioned.fill ──► AmbientMesh()        // atmosphere bg
            ├── SafeArea ──► TabBarView(controller: _tabController)
            │   ├── [0] HomePage()
            │   ├── [1] ChatsPage()
            │   ├── [2] GroupsPage()
            │   └── [3] PlansPage()
            ├── Positioned(top, left: 20) ──► TabHeader() // floating avatar / title
            └── Align(bottomCenter) ──► BottomBar()       // glass pill
```

**Tab signature colors:**

| Index | Label | Color | Hex |
|-------|-------|-------|-----|
| 0 | HOME | focusViolet | `#7C3AED` |
| 1 | CHATS | — | `#8B5CF6` |
| 2 | GROUPS | — | `#F97316` |
| 3 | PLANS | focusAlpine | `#4A90E2` |

- All 4 page widgets use `AutomaticKeepAliveClientMixin` (call `super.build(context)` at top of `build`).
- `TabHeader`: floating avatar on HOME (index 0), large title on others; 220 ms crossfade.
- `BottomBar`: glass pill with `TabChip` (mode chip), search field, mic/send button, `[+]` compose.

---

## Decision board file map

```
app/lib/views/home/decision_board/
├── decision_board_page.dart     # Scaffold root (4-tab controller)
├── atmosphere.dart              # AmbientMesh background widget
├── bottom_bar.dart              # Glass pill bottom bar
├── tab_header.dart              # Floating header (avatar / title)
├── tab_chip.dart                # Mode chip inside BottomBar
├── tab_popover.dart             # Tab chip popover
├── masonry_grid.dart            # SliverMasonryGrid.count 2-col
├── _card_factory.dart           # FeedItem → card widget mapping
├── chat_bubble.dart
├── conversation_list_row.dart
├── message_input_bar.dart
├── floating_avatar.dart
├── pages/
│   ├── home_page.dart
│   ├── chats_page.dart
│   ├── groups_page.dart
│   └── plans_page.dart
├── cards/                       # 11 card widgets
│   ├── _card_shell.dart         # Shared shell (uses cardKeyRegistry)
│   ├── dm_card.dart
│   ├── group_card.dart
│   ├── decision_card_small.dart
│   ├── decision_card_hero.dart
│   ├── focus_hero_card.dart
│   ├── trip_card.dart
│   ├── settlement_card.dart
│   ├── itinerary_card.dart
│   ├── memory_card.dart
│   └── ai_nudge_card.dart
├── sheets/                      # 7 bottom sheets
│   ├── dm_sheet.dart
│   ├── group_sheet.dart
│   ├── new_chat_sheet.dart
│   ├── search_sheet.dart
│   ├── decision_sheet.dart
│   ├── settlement_sheet.dart
│   └── attachment_sheet.dart
└── plasma/                      # Liquid Plasma system (7 files)
    ├── plasma.dart              # barrel export
    ├── plasma_gradient.dart     # palette + buildPlasmaGradient()
    ├── plasma_clock.dart        # root AnimationController (PlasmaClock / PlasmaClockScope)
    ├── plasma_fill.dart         # full-bleed animated gradient surface
    ├── plasma_tint.dart         # lower-alpha plasma tint overlay
    ├── plasma_stroke.dart       # animated gradient border
    └── plasma_progress_bar.dart # progress bar with plasma fill
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

All providers live in `app/lib/providers/`. Every provider with a feed branch
checks `kUseMockData` first (see Landmine #1).

| Provider | Type | Purpose |
|----------|------|---------|
| `engineProvider` | `Provider<ChatEngine>` | Throws until `initializeEngine()` runs |
| `feedProvider` | `Provider<List<FeedItem>>` | Unified feed: DMs + groups + decisions + trips + settlements + itinerary + memories + AI nudges |
| `homeFeedProvider` | `Provider<List<FeedItem>>` | HOME tab filtered feed |
| `chatsFeedProvider` | `Provider<List<FeedItem>>` | CHATS tab filtered feed |
| `groupsFeedProvider` | `Provider<List<FeedItem>>` | GROUPS tab filtered feed |
| `plansFeedProvider` | `Provider<List<FeedItem>>` | PLANS tab filtered feed |
| `focusTripIdProvider` | `StateProvider<String>` | Default: `kMockFocusTripId = 'swiss_jun_2026'` |
| `focusTripProvider` | derived | Trip object for the focus trip; pinned at index 0 of HOME feed |
| `activeTabIndexProvider` | `StateProvider<int>` | Current tab index (0–3) |
| `activeTabProvider` | derived | Enum variant of active tab |
| `tabAnimationProvider` | `StateProvider<double>` | Raw `TabController.animation.value` — updated per-frame during swipe |
| `centeredFeedItemIdProvider` | `StateProvider<String?>` | ID of the card currently centered in viewport |
| `centeredFeedItemProvider` | derived | `FeedItem` for the centered card |
| `centeredFeedItemKindProvider` | derived | `String?` — kind label of the centered card (e.g. `"dm"`, `"group"`, `"decision"`, `"trip"`). There is no `FeedItemKind` enum; the provider returns a plain nullable string used by `atmosphere.dart` to pick a tint. |
| `conversationsStreamProvider` | `StreamProvider` | Live conversations from engine |
| `directMessagesProvider` | derived | DMs only |
| `groupChatsProvider` | derived | Group chats only |
| `dmUnreadCountProvider` | derived | Total DM unread count |
| `groupUnreadCountProvider` | derived | Total group unread count |
| `activeDecisionsProvider` | `FutureProvider` | Cross-group merged decision items |

**`cardKeyRegistry`** — plain global `Map<String, GlobalKey>` (NOT a provider).
Defined in `app/lib/providers/viewport_focus_provider.dart:21`, used by
`_CardShell` (in `cards/_card_shell.dart`) to register widget keys for
scroll-to-card animations.

Provider files:
`conversations_provider.dart`, `decisions_provider.dart`, `engine_error_listener.dart`,
`feed_provider.dart`, `filtered_feed_providers.dart`, `focus_provider.dart`,
`home_state_provider.dart`, `itinerary_provider.dart`, `mock_data.dart`,
`settlements_provider.dart`, `tabs_provider.dart`, `trips_provider.dart`,
`viewport_focus_provider.dart`

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
| `focusViolet` | `#7C3AED` | HOME tab + Swiss trip accent |
| `focusAlpine` | `#4A90E2` | PLANS tab + Alpine trip accent |
| `focusOcean` | `#14B8A6` | Goa trip accent |
| `focusSunset` | `#FF9B6E` | Bali trip accent |
| `liveGreen` | `#047857` | Online presence, live indicators |
| `gold` | `#8B6914` | Consensus lock, premium state |
| `error` | `#C43D08` | Error states |
| `primary` | `#D4536B` | BACKWARD COMPAT ONLY — do not use in new code |

`HelloGlass.fill = 0x0AFFFFFF`, `HelloGlass.border = 0x0FFFFFFF` —
dark-era holdovers, nearly invisible on `#FAFAFA`. Do not use.

**No-bold mandate:** max `fontWeight: FontWeight.w400` (primary), `w300` (secondary).
Weights 500–900 are forbidden. See root `CLAUDE.md` for full policy.

---

## Dead code inventory

| Symbol | File | Status |
|--------|------|--------|
| `_ResumeSession` | `main.dart` | Defined but not registered in route table. Dead. |
| `homeActiveCardIndexProvider` | `home_state_provider.dart` | Stale 0–2 relic from pre-4-tab design. Not consumed. Delete when convenient. |
| `setupHeadlessErrorBus` | `engine_error_listener.dart` | Defined but no longer called from `main.dart` (call removed 2026-04-11). Re-add call site when a real consumer is wired. |

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
cd app && flutter test test/widget_test.dart
```

---

## Cross-references

- **Root guidance:** `/CLAUDE.md` — Security boundary, E2EE law, no-bold mandate,
  brand color restraint, engine public API, infrastructure lock
- **Design system:** `/DESIGN.md` — Read before any visual/UI decision
- **Decide-first UX spec:** `docs/superpowers/specs/2026-04-03-decide-first-group-ux-design.md`
- **Decide-first UX plan:** `docs/superpowers/plans/2026-04-03-decide-first-ux-plan.md`
- **Mode chip home design:** `docs/superpowers/specs/2026-04-11-mode-chip-home-design.md`
- **Engine public API:** root `CLAUDE.md` → "Engine Public API" section
- **Web layer:** `web/CLAUDE.md`
