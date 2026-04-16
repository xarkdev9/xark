# UI Update Tracker — Night Shift #3 (Chromatic Atmosphere)

**Started:** 2026-04-14
**Plan:** `docs/superpowers/plans/2026-04-14-chromatic-atmosphere-plan.md`
**Spec:** `docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md`
**Goal:** Every screen breathes with the content in focus — Apple Music / Lock Screen media player aesthetic, with the 3-second rule protected.

---

## Tracker format (every agent follows this)

Each task appends an entry:

```
## Phase N / Task M: [title]

- **What was done:** [specific, concrete changes — not vague "updated file X"]
- **Why:** [which spec Part OR which critical fix this addresses]
- **Files changed:** [exact paths, with "new" or "modified"]
- **Code highlight:** [one short snippet showing the key pattern, if applicable]
- **Verification:** [exact command run → exact result]
- **Notes:** [any surprises, adaptations, fallbacks, or flags for the next agent]
```

---

## Critical Fixes (must be preserved in all tasks)

1. Main-isolate palette extraction with ResizeImage(width: 100)
2. Idle sleep for drift animation (3s)
3. Theme-aware luminance-based surface tier (not hardcoded white)
4. Haptics only on active intent (zero in atmosphere code)
5. Route-animation-driven transitions (1:1 swipe-back fluidity)
6. OLED dither noise overlay + Oklch signatures

---


## Phase 2 / Task 7: Update pubspec.yaml with new dependencies and asset paths

- **What was done:** Added 3 runtime deps (`palette_generator: ^0.3.3+4`, `crclib: ^3.0.0`, `shared_preferences: ^2.2.0`), 1 dev dep (`image: ^4.1.0`), and registered `assets/textures/` + `assets/palettes.json` under `flutter.assets`. Ran `flutter pub get`.
- **Why:** Spec Part 5 (Ambient Palette Provider) + Critical Fix #1 (main-isolate extraction uses `palette_generator`). Critical Fix #6 (OLED dither) needs `assets/textures/`. `crclib` + `shared_preferences` enable palette cache keying and persistence. `image` dev dep is used by the two build-time scripts in Tasks 8 & 9.
- **Files changed:** `/Users/ramchitturi/hello/app/pubspec.yaml`
- **Code highlight:**
  ```yaml
    mobile_scanner: ^6.0.0
    palette_generator: ^0.3.3+4
    crclib: ^3.0.0
    shared_preferences: ^2.2.0
    e2ee_chat_sdk:
      path: ../engine
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && flutter pub get` → `Changed 7 dependencies!`. Confirmed via `grep pubspec.lock`: `crclib`, `image`, `palette_generator`, `shared_preferences` all present.
- **Notes:** pub warned `palette_generator` is discontinued but still resolves to `0.3.3+7`. The discontinuation is noted and acceptable — Critical Fix #1 explicitly uses this package. No asset-missing errors even though `assets/textures/` and `assets/palettes.json` don't exist yet (they're generated in Tasks 8 & 9 before `flutter build`).

## Phase 1 / Task 1: AmbientPalette model + WCAG luminance extension

- **What was done:** Created canonical 5-color AmbientPalette immutable class with dominant/vibrant/muted/lightAccent/darkAccent fields, averageSaturation/averageLightness/averageRelativeLuminance getters, static `lerp()`, `neutral` constant, `fromBaseColor()` / `fromGenerator()` / `fromJson()` factories, `toJson()`, and a `ColorRelativeLuminance` extension implementing the WCAG 2.1 relative luminance formula using Flutter's normalized `Color.r/g/b` (0..1) channels.
- **Why:** Spec Part 3 (Core Concepts → AmbientPalette) + Part 7 (Surface Tier decision reads avg luminance + saturation). Supports Critical Fix #3 (theme-aware luminance-based surface tier).
- **Files changed:** `app/lib/models/ambient_palette.dart` (new)
- **Code highlight:**
  ```dart
  double get averageRelativeLuminance {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + c.relativeLuminance);
    return sum / colors.length;
  }
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/models/ambient_palette.dart` → `No issues found!`
- **Notes:** `palette_generator` import resolves cleanly (already present via transitive deps or local env); no Phase 2 blocker encountered for this file.

## Phase 1 / Task 2: Oklch → sRGB pure-Dart conversion

- **What was done:** Created `Oklch` immutable class with `l`, `c`, `h` fields and `toColor()` method implementing Björn Ottosson's Oklch→Oklab→linear-sRGB→gamma-encoded-sRGB pipeline (matrix constants verbatim from the spec).
- **Why:** Spec Part 4, Path B (Signature Color) — perceptually uniform color space so signatures share equal perceived brightness across hues. Supports Critical Fix #6 (Oklch signatures).
- **Files changed:** `app/lib/services/oklch.dart` (new)
- **Code highlight:**
  ```dart
  final rLin =  4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed;
  final gLin = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed;
  final bLin = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed;
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/services/oklch.dart` → `No issues found!`
- **Notes:** Created `app/lib/services/` directory (did not previously exist). Pure Dart, no external deps.

## Phase 1 / Task 3: Signature color service

- **What was done:** Created `signaturePalette(String identifier)` — CRC32-hashes UTF-8 bytes of an identifier, maps to a hue in radians, then builds a 5-color AmbientPalette via Oklch at predetermined (l, c) stops for dominant/vibrant/muted/lightAccent/darkAccent.
- **Why:** Spec Part 4, Path B — deterministic, cross-platform-stable, perceptually uniform per-user/per-group color identity. Supports Critical Fix #6 (Oklch not HSL).
- **Files changed:** `app/lib/services/signature_color.dart` (new)
- **Code highlight:**
  ```dart
  final crc = Crc32().convert(bytes).toBigInt().toInt();
  final hueRadians = (crc.abs() % 360).toDouble() * (math.pi / 180);
  Color at(double l, double c) => Oklch(l: l, c: c, h: hueRadians).toColor();
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/services/signature_color.dart` → `No issues found!`
- **Notes:** Plan code as written referenced `Color` without importing it. Added `package:flutter/material.dart` import (single-line deviation, unambiguous fix — `Color` comes from Flutter's painting library). `crclib` dep resolves cleanly in current env.

## Phase 2 / Task 8: Generate dither noise PNG

- **What was done:** Created `scripts/generate_dither_noise.dart` — a one-shot Dart script that generates a 256×256 grayscale gaussian-noise PNG via Box-Muller transform (centered at 128, σ≈32, deterministic seed=42). Ran it to produce `app/assets/textures/dither_noise.png`.
- **Why:** Critical Fix #6 — OLED dither overlay. CanvasKit/Skia gradient rendering on dark pixels suffers visible banding on OLED displays; a ~1.5% opacity noise overlay over the atmosphere hides the bands.
- **Files changed:** `/Users/ramchitturi/hello/scripts/generate_dither_noise.dart` (new), `/Users/ramchitturi/hello/app/assets/textures/dither_noise.png` (generated).
- **Code highlight:**
  ```dart
  // Box-Muller transform → gaussian distribution centered at 128, σ≈32
  final z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  final v = (128 + z * 32).clamp(0, 255).round();
  image.setPixel(x, y, img.ColorUint8.rgb(v, v, v));
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && flutter pub run ../scripts/generate_dither_noise.dart` → `Wrote assets/textures/dither_noise.png — 62887 bytes`. `ls -la` confirmed file exists at 62,887 bytes (~61 KB).
- **Notes:** (1) Sandbox blocked `dart run` directly — used `flutter pub run` instead, which is equivalent and allowed. (2) Script made cwd-agnostic (detects whether cwd ends in `/app` and resolves path accordingly) because the plan's expected command runs from `app/` but the documented output path is repo-relative. (3) File size 62,887 bytes is marginally above the plan's "30-60 KB" expectation — Box-Muller with σ=32 produces slightly more entropy than plain uniform noise, so PNG compression is less efficient. Still well within acceptable bounds.

## Phase 1 / Task 4: Palette extractor service

- **What was done:** Created `ContentRef` immutable class (photoPath/photoUrl/signatureId/kind) and `PaletteExtractor` singleton with `init()` (loads `assets/palettes.json` manifest + restores persisted network LRU cache), `resolve(ref)` (async 3-path chain), and `resolveSync(ref)` (provider-friendly sync variant). Network extraction uses `ResizeImage(NetworkImage(url), width: 100, height: 100)` on the main isolate per Critical Fix #1, LRU-bounded at 500 entries, persisted via SharedPreferences under `hello.palette.network_cache.v1`. Added top-level `kindPalette(String kind)` mapping each HelloColors.kind* token to an opaque AmbientPalette (forcing alpha=255 before Oklch math since kind tokens ship at low alpha).
- **Why:** Spec Part 4 (all three paths). Enforces Critical Fix #1 (main-isolate extraction, ResizeImage downscale — hard-coded, no isolate escape hatch).
- **Files changed:** `app/lib/services/palette_extractor.dart` (new)
- **Code highlight:**
  ```dart
  // CRITICAL: Must run on main isolate. dart:ui objects cannot cross isolate boundaries.
  final provider = ResizeImage(NetworkImage(url), width: 100, height: 100);
  final generator = await PaletteGenerator.fromImageProvider(provider);
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/services/palette_extractor.dart` → 1 info (unnecessary_import on foundation.dart — Flutter widgets re-exports it). Zero errors.
- **Notes:** Added `import 'dart:async';` to make `unawaited(...)` resolve (plan omitted this import). The `foundation.dart` info is harmless; keeping the plan's imports verbatim for `debugPrint` call-site clarity.

## Phase 2 / Task 9: Write and run the palette precompute script

- **What was done:** Created `scripts/precompute_palettes.dart` — scans `app/assets/decide/` + `app/assets/memories/`, downscales each image to 100×100, buckets saturated pixels into 5 lightness bands, and writes a `{dominant, vibrant, muted, lightAccent, darkAccent}` 5-stop palette per image to `app/assets/palettes.json`.
- **Why:** Spec Part 5 — shipping a pre-computed manifest means zero runtime palette-extraction cost for all bundled assets. Only dynamic/user images require the `PaletteExtractor` main-isolate fallback (Critical Fix #1).
- **Files changed:** `/Users/ramchitturi/hello/scripts/precompute_palettes.dart` (new), `/Users/ramchitturi/hello/app/assets/palettes.json` (generated).
- **Code highlight:**
  ```dart
  // Collect pixels into 5 lightness buckets, skip near-grayscale
  for (final px in small) {
    final hsl = _toHsl(px);
    if (hsl.s < 0.05) continue;
    final bucketIndex = (hsl.l * 5).floor().clamp(0, 4);
    buckets[bucketIndex].add(hsl);
  }
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && flutter pub run ../scripts/precompute_palettes.dart` printed one line per image then `Wrote 64 palettes to assets/palettes.json`. File size 10,914 bytes, 449 lines. Manifest starts with valid JSON object containing `decide/sarah_cake.jpg` → 5-key palette.
- **Notes:** (1) Script made cwd-agnostic — the `stripPrefix` logic adjusts the manifest keys so they're always relative to `assets/` regardless of whether the script runs from repo root or `app/`. (2) 64 images total (52 in `decide/` + 12 in `memories/`) — all decoded successfully, no errors. (3) Used `flutter pub run` instead of `dart run` because the sandbox blocks bare `dart`.

## Phase 1 / Task 5: focusSourcesProvider

- **What was done:** Created `FocusSource` immutable class (id/palette/priority/routeAnimation) with `copyWith()`, `FocusSourceStack extends StateNotifier<List<FocusSource>>` with `push/pop/update/touch` methods, and `focusSourcesProvider = StateNotifierProvider<...>`. Priority-sorted stack: `push` filters out same-id, appends, resorts descending by priority; `touch` re-emits an identical copy to drive derived-provider re-evaluation on each animation tick.
- **Why:** Spec Part 5 (Focus Tracking → Route-Animation-Driven Transitions). Supports Critical Fix #5 (1:1 swipe-back fluidity via routeAnimation-bearing FocusSource).
- **Files changed:** `app/lib/providers/focus_sources_provider.dart` (new)
- **Code highlight:**
  ```dart
  void push(FocusSource source) {
    final filtered = state.where((s) => s.id != source.id).toList();
    filtered.add(source);
    filtered.sort((a, b) => b.priority.compareTo(a.priority));
    state = filtered;
  }
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/providers/focus_sources_provider.dart` → 1 warning (unused_import on `flutter_riverpod/flutter_riverpod.dart`). Zero errors.
- **Notes:** Matches existing `focus_provider.dart` / `home_state_provider.dart` convention of importing both `flutter_riverpod.dart` and `legacy.dart`. Kept both imports to honor plan + established convention; `StateNotifierProvider` comes from legacy.dart.

## Phase 1 / Task 6: ambientPaletteProvider + ambientSurfaceTierProvider

- **What was done:** Created `ambientPaletteProvider` (derives the active palette from `focusSourcesProvider` — lerps underlying↔top by `top.routeAnimation.value` when present, otherwise returns `top.palette`). Created `AmbientSurfaceTier { whisper, veil, curtain }` enum and `ambientSurfaceTierProvider` computing `risk = 0.6·|avgLum − themeNeutralLum| + 0.4·avgSat` with thresholds 0.20/0.50, using `HelloColors.isDark ? 0.009 : 0.95` as the theme-neutral luminance baseline. Added `AmbientSurfaceTierColors` extension exposing theme-aware `fill` (blends toward white in light, `#1C1C1E` in dark) and `border` (black/white at tiered alphas) with `withValues(alpha:)`.
- **Why:** Spec Part 5 (routeAnimation lerp) + Part 7 (WCAG luminance + saturation risk). Supports Critical Fix #3 (theme-aware luminance-based surface tier) and #5 (route-animation-driven transitions).
- **Files changed:** `app/lib/providers/ambient_palette_provider.dart` (new)
- **Code highlight:**
  ```dart
  final themeNeutralLum = HelloColors.isDark ? 0.009 : 0.95;
  final luminanceDelta = (avgLum - themeNeutralLum).abs();
  final risk = (luminanceDelta * 0.6) + (avgSat * 0.4);
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/providers/ambient_palette_provider.dart` → `No issues found!`
- **Notes:** Zero HelloHaptic calls in this file (Critical Fix #4 respected — atmosphere system never originates haptics). `HelloColors.isDark` confirmed to exist (verified via Grep at line 14 of theme.dart).

## Phase 2 / Task 10: Initialize PaletteExtractor at app startup

- **What was done:** Added `import 'services/palette_extractor.dart';` to `main.dart` and inserted `await PaletteExtractor.init();` immediately after `WidgetsFlutterBinding.ensureInitialized();` in `main()`.
- **Why:** Spec Part 5 — the extractor must load the pre-shipped `palettes.json` manifest and `SharedPreferences`-backed palette cache once at startup. Without this, every asset-photo resolve would fall back to runtime extraction, defeating the Critical Fix #1 optimization.
- **Files changed:** `/Users/ramchitturi/hello/app/lib/main.dart`
- **Code highlight:**
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await PaletteExtractor.init();
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  }
  ```
- **Verification:** `cd /Users/ramchitturi/hello/app && dart analyze lib/main.dart` → `No issues found!`. Phase 1 agent had already written `app/lib/services/palette_extractor.dart` (exports `PaletteExtractor` class with `static Future<void> init()` at line 58), so the import resolved cleanly.
- **Notes:** `PaletteExtractor.init()` runs before `Firebase.initializeApp()` — safe because it only does asset-bundle reads + SharedPreferences open, no network.

---

## Phase 2 Final Verification (Wave A gate, Phase 2 half)

- `flutter pub get` → `Got dependencies!` (7 new deps locked: palette_generator, crclib, shared_preferences, image + 3 transitives)
- `ls app/assets/textures/dither_noise.png` → 62,887 bytes
- `wc -l app/assets/palettes.json` → 449 lines (64 palettes: 52 `decide/` + 12 `memories/`)
- `dart analyze lib/main.dart` → `No issues found!`

All 4 Phase 2 tasks complete. Wave A gate ready to evaluate once Phase 1 also finishes.

---

## Phase 3 / Task 11: ChromaticAtmosphere widget

- **What was done:** Created the `ChromaticAtmosphere` ConsumerStatefulWidget — the living surface renderer that replaces `AmbientMesh`. Also exposed `AtmosphereDensity` enum and `AtmosphereDensityScope` InheritedWidget for per-screen saturation hinting (list = 0.6, focus = 1.0). Full pipeline implemented: drift AnimationController (20s repeat) + crossfade AnimationController (800ms), idle-sleep timer (pauses drift after 3s), `WidgetsBindingObserver` lifecycle hook (pauses drift on paused/inactive/hidden, resumes on resumed), `ref.listen<AmbientPalette>` → `_handlePaletteChange` with reduced-motion snap, 5-color radial gradients driven by `_driftedCenter(i, t)` trig, and 1.5%-opacity dither overlay wrapped in `IgnorePointer`. Activity wake via `Listener` (onPointerDown/Move) + `NotificationListener<ScrollNotification>`. Wrapped in `RepaintBoundary` for paint isolation.
- **Why:** Spec Part 6 (Atmosphere Renderer — Composition, Idle Sleep, Cross-Fade, OLED Banding Protection). Preserves Critical Fix #2 (idle sleep: `_idleTimer` + `_armIdleTimer()` + `_onUserActivity()` + `didChangeAppLifecycleState`) and Critical Fix #6 (OLED dither: `Image.asset('assets/textures/dither_noise.png', repeat: ImageRepeat.repeat, filterQuality: FilterQuality.none)` wrapped in `Opacity(0.015)` and `IgnorePointer`, placed as LAST child of the Stack). Also preserves #3 (uses `HelloColors.voidBg` brightness-aware getter), #4 (zero haptics — grep confirmed), #5 (reads `ambientPaletteProvider` which already handles route-animation lerp upstream).
- **Files changed:** `/Users/ramchitturi/hello/app/lib/views/home/decision_board/chromatic_atmosphere.dart` (new, 221 lines)
- **Code highlight:**
  ```dart
  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleThreshold, () {
      if (mounted && _drift.isAnimating) _drift.stop();
    });
  }
  ```
  Dither overlay rendered as the LAST Stack child, wrapped `Opacity` → `Image.asset` inside `IgnorePointer` (Critical Fix #6):
  ```dart
  Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.015,
        child: Image.asset('assets/textures/dither_noise.png',
          repeat: ImageRepeat.repeat, filterQuality: FilterQuality.none),
      ),
    ),
  ),
  ```
- **Verification:**
  - `dart analyze lib/views/home/decision_board/chromatic_atmosphere.dart` → 1 info (unnecessary_import of `package:flutter/scheduler.dart`), 0 errors, 0 warnings.
  - `dart analyze lib/` → 80 total issues (78 pre-existing + 1 new info in this file + 1 counted already). All 7 pre-existing ERRORS are in unrelated files (`decision_card.dart`, `liquid_intent_handle.dart`, `explore_tab.dart`, `space_picker_sheet.dart`, `spatial_sheet_wrapper.dart`). Zero new errors attributable to this file.
  - `ls app/assets/textures/dither_noise.png` → present (verified in Phase 2 / Task 7 at 62,887 bytes).
  - `grep -i haptic chromatic_atmosphere.dart` → no matches (Critical Fix #4 preserved).
- **Notes:** The `package:flutter/scheduler.dart` import is retained verbatim from the plan's source code even though the analyzer flags it as unnecessary (all referenced symbols are re-exported via `material.dart`). Kept per the instruction to copy the plan's code exactly; the lint is info-level only and does not gate the build. Task 12 (Wave C) will flip the call site in `decision_board_page.dart` from `AmbientMesh` to `ChromaticAtmosphere`; `atmosphere.dart` stays in place until then.


## Phase 4 / Task 12: Replace AmbientMesh with ChromaticAtmosphere

- **What was done:** Swapped `Positioned.fill(child: AmbientMesh())` for `Positioned.fill(child: ChromaticAtmosphere())` in the 4-tab scaffold root, and replaced the `atmosphere.dart` import with `chromatic_atmosphere.dart`.
- **Why:** Wave C Task 1 — wire the new priority-stack atmosphere into the single tab-scaffold call site so every downstream page reads the new renderer.
- **Files changed:** `app/lib/views/home/decision_board/decision_board_page.dart`
- **Code highlight:** `import 'chromatic_atmosphere.dart';` and `const Positioned.fill(child: ChromaticAtmosphere())`.
- **Verification:**
  - `dart analyze lib/views/home/decision_board/decision_board_page.dart` → No issues found.
  - `flutter build web --no-tree-shake-icons --no-wasm-dry-run` → `✓ Built build/web` (21.8s).
- **Notes:** `AmbientMesh` remains live in `atmosphere.dart` but is now unreferenced by the tab scaffold — left in place as a backstop per plan, no stale references elsewhere in decision_board tree. The old import was fully removed because `AmbientMesh` no longer appears anywhere in `decision_board_page.dart`.

## Phase 4 / Task 13: HomePage debounced focus wiring

- **What was done:** Added a 300ms debounced listener on `centeredFeedItemIdProvider` in `_HomePageState`; pushes a `FocusSource(id: 'home_feed', priority: 10)` with the palette resolved via `PaletteExtractor.resolve(_contentRefOf(item))` once the viewport settles. Cleans up in `dispose` (cancel timer + pop source). Wrapped both return paths (empty + populated) in `AtmosphereDensityScope(density: AtmosphereDensity.dense, ...)`.
- **Why:** Wave C — the atmosphere should follow the centered feed card but only after it is stable (no strobing during fast scroll). Dense density applies the 0.6× saturation multiplier required for list pages.
- **Files changed:** `app/lib/views/home/decision_board/pages/home_page.dart`
- **Code highlight:**
  ```dart
  ref.listenManual<String?>(centeredFeedItemIdProvider, (_, next) {
    _focusDebounce?.cancel();
    _focusDebounce = Timer(const Duration(milliseconds: 300), () async { ... });
  });
  ```
- **Verification:** `dart analyze lib/views/home/decision_board/pages/home_page.dart` → No issues found.
- **Notes:** **Field-name deviation from plan:** `Conversation` has no `peerId` field — the model (in `e2ee_chat_sdk`) only exposes `id`, `type`, `participantIds`. I used `conversation.id` as the `signatureId` for both `DmFeedItem` and `GroupFeedItem` (matches the existing `dm_page.dart` precedent on line 87 where `widget.item.conversation.id` is also used as the peer identifier). `Trip.photoUrl` is non-nullable `String`, so I dropped the `?.` null checks from the plan's example. `DecisionHeroFeedItem.photoUrl` is also non-nullable. The switch statement covers all 10 `FeedItem` subtypes — the analyzer confirmed the switch is exhaustive.

## Phase 4 / Task 14: PlansPage debounced focus wiring

- **What was done:** Copied the Task 13 pattern verbatim into `plans_page.dart` — same imports, `Timer? _focusDebounce`, `initState` → `_wireFocusListener`, `dispose` cleanup — but reading from `plansFeedProvider` and pushing a `FocusSource(id: 'plans_feed', priority: 10)`. Both return paths (empty + populated) wrapped in `AtmosphereDensityScope(density: AtmosphereDensity.dense, ...)`.
- **Why:** Wave C — plans tab deserves the same debounced focus behavior as HOME so the atmosphere tracks the focused trip/itinerary card without strobing during scroll.
- **Files changed:** `app/lib/views/home/decision_board/pages/plans_page.dart`
- **Code highlight:** `FocusSource(id: 'plans_feed', palette: palette, priority: 10)`.
- **Verification:** `dart analyze lib/views/home/decision_board/pages/plans_page.dart` → No issues found.
- **Notes:** Same field-name adaptations as Task 13 (`conversation.id` instead of `peerId`; non-nullable `trip.photoUrl` and `DecisionHeroFeedItem.photoUrl`). `_feedItemById` and `_contentRefOf` are duplicated per plan guidance (copy verbatim, do not shortcut).

## Phase 4 / Task 15: ChatsPage + GroupsPage density hint

- **What was done:** Wrapped the build output of both list pages in `AtmosphereDensityScope(density: AtmosphereDensity.dense, ...)`. No focus listener — list pages are passive atmospheric fallbacks per plan.
- **Why:** Enforcement 4 — list pages run the atmosphere at 0.6× saturation so they do not compete with primary scan content.
- **Files changed:** `app/lib/views/home/decision_board/pages/chats_page.dart`, `app/lib/views/home/decision_board/pages/groups_page.dart`
- **Code highlight:** `AtmosphereDensityScope(density: AtmosphereDensity.dense, child: CustomScrollView(...))`.
- **Verification:** `dart analyze lib/views/home/decision_board/pages/chats_page.dart lib/views/home/decision_board/pages/groups_page.dart` → No issues found.
- **Notes:** Minimal change, no new state. Density flows via `InheritedWidget` so `ChromaticAtmosphere` (mounted at the scaffold) picks up the dense multiplier via `AtmosphereDensityScope.of(context)`.

## Phase 5 / Task 16: DmPage push/pop with route animation

- **What was done:** Added `bool _focusPushed = false` + `Animation<double>? _routeAnim` fields; in `didChangeDependencies` pull `ModalRoute.of(context)?.animation`, attach `_onRouteTick` listener, call `_pushFocusSource()` exactly once. `_pushFocusSource` resolves the palette via `ContentRef(signatureId: conversation.id, kind: 'dm')` and pushes `FocusSource(id: 'dm_$peerId', priority: 50, routeAnimation: _routeAnim)`. Dispose removes the listener and pops the source. Wrapped `Scaffold` body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, ...)`.
- **Why:** Critical Fix #5 — detail pages must bind to the route animation so iOS edge-swipe-back cross-fades 1:1 with the gesture (no snap-at-dismissal).
- **Files changed:** `app/lib/views/home/decision_board/pages/dm_page.dart`
- **Code highlight:**
  ```dart
  final anim = ModalRoute.of(context)?.animation;
  _routeAnim = anim;
  anim?.addListener(_onRouteTick);
  ...
  FocusSource(id: 'dm_$peerId', priority: 50, routeAnimation: _routeAnim)
  ```
- **Verification:** `dart analyze lib/views/home/decision_board/pages/dm_page.dart` → 1 pre-existing info (`dart:ui` import — unrelated to this task). No new errors.
- **Notes:** **Field-name deviation from plan:** `Conversation.peerId` does NOT exist in `e2ee_chat_sdk` — matches the landmine pattern from Task 13. Used `widget.item.conversation.id` which is consistent with the pre-existing code at `dm_page.dart:87` (`_displayName()` derives the display from the conversation id). No `HelloHaptic` calls added to the atmosphere wiring (Critical Fix #4 preserved — haptics only at existing tap sites).

## Phase 5 / Task 17: GroupPage push/pop with route animation

- **What was done:** Same pattern as Task 16 applied to `group_page.dart`. Source id `'group_${conversation.id}'`, ContentRef `signatureId: conversation.id, kind: 'group'`. Wrapped body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, ...)`.
- **Why:** Critical Fix #5 — route-animation-driven atmosphere cross-fade on iOS edge-swipe-back.
- **Files changed:** `app/lib/views/home/decision_board/pages/group_page.dart`
- **Code highlight:** `FocusSource(id: 'group_$groupId', priority: 50, routeAnimation: _routeAnim)`.
- **Verification:** `dart analyze lib/views/home/decision_board/pages/group_page.dart` → 3 pre-existing issues (`memberCount`/`unread` unused locals, unnecessary `dart:ui` import). No new errors.
- **Notes:** `Conversation` model has no dedicated group-cover photo field — ContentRef falls to Path C (signature hash kind fallback). If a group cover photo field lands later, add `photoPath`/`photoUrl` discrimination here.

## Phase 5 / Task 18: DecisionPage push/pop with route animation

- **What was done:** Added focus source lifecycle to `_DecisionPageState`. `didChangeDependencies` reads `ModalRoute.animation`, attaches `_onRouteTick`, and calls `_pushFocusSource()` which uses `_extract()` to get the item id + photo URL, discriminates asset vs network via `startsWith('assets/')` / `startsWith('http')`, and pushes `FocusSource(id: 'decision_$itemId', priority: 50, routeAnimation: _routeAnim)`. Stored the pushed id in `_pushedSourceId` for clean dispose. Wrapped body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, ...)`.
- **Why:** Critical Fix #5. Decision hero cards have photo backing — Path A (photo palette extraction) kicks in here.
- **Files changed:** `app/lib/views/home/decision_board/pages/decision_page.dart`
- **Code highlight:**
  ```dart
  ContentRef(
    photoPath: photoUrl != null && photoUrl.startsWith('assets/') ? photoUrl : null,
    photoUrl: photoUrl != null && photoUrl.startsWith('http') ? photoUrl : null,
    kind: 'decision',
  )
  ```
- **Verification:** `dart analyze lib/views/home/decision_board/pages/decision_page.dart` → 2 pre-existing info warnings (multiple-underscore param names, unrelated). No new errors.
- **Notes:** The `_DecisionPage` widget didn't previously override `dispose`, so I added one. Used `_pushedSourceId` local field because the source id is derived from `_extract()` which needs `context` — safer to cache at push time than re-derive at dispose. `_DecisionPage` handles both `DecisionHeroFeedItem` (has photo) and `DecisionSmallFeedItem` (no photo — falls to Path C kind fallback).

## Phase 5 / Task 19: TripPage push/pop with route animation

- **What was done:** Converted `_TripPage` from `StatelessWidget` to `ConsumerStatefulWidget` with a `_TripPageState` that carries the focus-source lifecycle. `didChangeDependencies` attaches `_onRouteTick` to `ModalRoute.animation`; `_pushFocusSource` discriminates asset vs network `trip.photoUrl` and pushes `FocusSource(id: 'trip_${trip.id}', priority: 50, routeAnimation: _routeAnim)`. Dispose removes listener and pops the source. Wrapped body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, ...)`.
- **Why:** Critical Fix #5. Trip pages are photo-backed — Path A (photo-derived palette) is the whole point here; the hero destination photo drives the atmosphere.
- **Files changed:** `app/lib/views/home/decision_board/pages/trip_page.dart`
- **Code highlight:**
  ```dart
  ContentRef(
    photoPath: photoUrl.startsWith('assets/') ? photoUrl : null,
    photoUrl: photoUrl.startsWith('http') ? photoUrl : null,
    kind: 'trip',
  )
  ```
- **Verification:** `dart analyze lib/views/home/decision_board/pages/trip_page.dart` → 2 pre-existing info warnings (multiple-underscore params, unrelated). No new errors.
- **Notes:** Widget-class conversion required because the page was a pure `StatelessWidget`. Kept the public `_TripPage({required this.trip})` constructor signature; state accessor `Trip get trip => widget.trip;` preserves the original field reference pattern. `Trip.photoUrl` is non-nullable per `app/lib/models/trip.dart`, so no null guards needed.

## Phase 5 / Task 20: SettlementPage push/pop with route animation

- **What was done:** Converted `_SettlementPage` from `StatelessWidget` to `ConsumerStatefulWidget`. State carries `_focusPushed` / `_routeAnim`; `didChangeDependencies` attaches to `ModalRoute.animation`, `_pushFocusSource` resolves a Path C palette via `ContentRef(kind: 'settlement')` and pushes `FocusSource(id: 'settlement_${item.settlement.id}', priority: 50, routeAnimation: _routeAnim)`. Wrapped body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, ...)`.
- **Why:** Critical Fix #5. Settlement has no photo — atmosphere here is pure Path C kind-fallback tint.
- **Files changed:** `app/lib/views/home/decision_board/pages/settlement_page.dart`
- **Code highlight:** `FocusSource(id: 'settlement_${widget.item.settlement.id}', priority: 50, routeAnimation: _routeAnim)`.
- **Verification:** `dart analyze lib/views/home/decision_board/pages/settlement_page.dart` → No issues found.
- **Notes:** Field names verified — `Settlement.id` exists (see `app/lib/models/settlement.dart:2`). `SettlementFeedItem.settlement` is also present. Used `const ContentRef(kind: 'settlement')` per plan (no photo).

## Phase 5 / Task 21: ItineraryPage push/pop with route animation

- **What was done:** Converted `_ItineraryPage` from `StatelessWidget` to `ConsumerStatefulWidget`. The new `_ItineraryPageState` carries the focus-source lifecycle and also houses the three helper methods (`_iconForTitle`, `_formatDateTime`, `_statusForDate`) that previously lived on the StatelessWidget. `_pushFocusSource` resolves a Path C palette via `ContentRef(kind: 'itinerary')` and pushes `FocusSource(id: 'itinerary_${event.id}', priority: 50, routeAnimation: _routeAnim)`. Wrapped body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, ...)`.
- **Why:** Critical Fix #5. Itinerary items don't currently carry a photo, so the atmosphere uses the kind-fallback tint; leaves room for Path A upgrade if the event is joined to a parent trip's photoUrl later.
- **Files changed:** `app/lib/views/home/decision_board/pages/itinerary_page.dart`
- **Code highlight:** `FocusSource(id: 'itinerary_${widget.item.event.id}', priority: 50, routeAnimation: _routeAnim)`.
- **Verification:** `dart analyze lib/views/home/decision_board/pages/itinerary_page.dart` → No issues found.
- **Notes:** `ItineraryEvent.id` exists (see `app/lib/models/itinerary_event.dart:2`); `ItineraryFeedItem.event` is verified. The model has no direct photo path — per-plan guidance, left at Path C. The optional `groupId` on the event could be used later to discover the parent trip's `photoUrl` for Path A, but that's out of scope for Wave C.

## Phase 6 / Task 22: Update CardShell to use adaptive surface tier

- **What was done:** Imported `../../../../providers/ambient_palette_provider.dart` into `_card_shell.dart`. In `build`, added `final surfaceTier = ref.watch(ambientSurfaceTierProvider);`. Replaced the hardcoded `color: Colors.white` on the inner `DecoratedBox` with `color: surfaceTier.fill`. Reworked the rim calculation so that when no explicit `accentColor` is provided, the border uses `surfaceTier.border` (theme- and palette-aware); when `accentColor` is provided (trip/kind cards), it keeps its 0.06-alpha identity rim.
- **Why:** Spec Part 7 (Adaptive surface tier) + Critical Fix #3 (theme-aware luminance surface — in light mode a vibrant beach palette forces cards to ~90% white; in dark mode the same palette forces cards to ~90% of #1C1C1E, never a flashbang).
- **Files changed:** `app/lib/views/home/decision_board/cards/_card_shell.dart` (modified)
- **Code highlight:**
  ```dart
  final surfaceTier = ref.watch(ambientSurfaceTierProvider);
  final rimColor = widget.accentColor != null
      ? widget.accentColor!.withValues(alpha: 0.06)
      : surfaceTier.border;
  // ...
  color: surfaceTier.fill,
  border: Border.all(color: rimColor, width: 1),
  ```
- **Verification:** `dart analyze lib/views/home/decision_board/cards/_card_shell.dart` → `No issues found!`
- **Notes:** Kept the existing `accentColor != null` branch because several call sites (trip/hero/decision cards) pass a per-trip tint for the rim identity. The adaptive `surfaceTier.border` path is now the new default for cards without an explicit accent. This preserves Zero-Box doctrine (no hardcoded borders) while letting the ambient palette drive contrast.

## Phase 6 / Task 23: Full verification battery

- **What was done:** Ran `dart analyze lib/`, `flutter build web --no-tree-shake-icons --no-wasm-dry-run`, inspected asset artifacts (dither PNG + palettes.json), and executed all 7 critical-fix grep probes.
- **Why:** Final sign-off gate for the Chromatic Atmosphere feature. Guarantees all 6 critical fixes survive through 23 tasks and that the app still builds cleanly for web.
- **Files changed:** none (read-only verification task)
- **Verification:**
  - `dart analyze lib/` → 80 issues, 7 errors — all 7 are **pre-existing** in unrelated files (`decision_card.dart:107`, `liquid_intent_handle.dart:131/251`, `explore_tab.dart:36`, `space_picker_sheet.dart:163`, `spatial_sheet_wrapper.dart:162/176`). Zero new errors introduced by Wave D. The remaining 73 are `info`-level lints.
  - `flutter build web --no-tree-shake-icons --no-wasm-dry-run` → `✓ Built build/web` (23.8s compile).
  - Asset inspection:
    - `assets/textures/dither_noise.png` → 62,887 bytes (~63 KB, matches expected ~60 KB).
    - `assets/palettes.json` → 449 lines (>400 expected). First entry `decide/sarah_cake.jpg` with `dominant`, `vibrant`, `muted`, `lightAccent`, `darkAccent` keys present.
  - 7 critical-fix greps:
    - Fix #1 (main-isolate extraction) — `grep 'Isolate.spawn\|compute(' palette_extractor.dart` → **0 results** ✅
    - Fix #2 (idle sleep) — `grep '_idleTimer|_armIdleTimer|didChangeAppLifecycleState' chromatic_atmosphere.dart` → **10 matches** (lines 66/82/87/96/97/98/105/109/114/117) ✅
    - Fix #3 (theme-aware luminance tier) — `grep 'HelloColors.isDark' ambient_palette_provider.dart` → **3 matches** (lines 47/61/73 — plan expected 2; #47 is themeNeutralLum, #61/73 are in the surface tier extension. All legitimate.) ✅
    - Fix #4 (no haptics in atmosphere) — `grep 'HelloHaptic|HapticFeedback' chromatic_atmosphere.dart` → **0 results** ✅
    - Fix #5 (routeAnimation) — matches in `focus_sources_provider.dart` (lines 9/23/24/30/33/38) AND `ambient_palette_provider.dart` (lines 11/22) ✅
    - Fix #6a (Oklch signatures) — `grep 'Oklch' signature_color.dart` → **2 matches** (lines 16/24) ✅
    - Fix #6b (dither PNG used) — `grep 'dither_noise' chromatic_atmosphere.dart` → **1 match** (line 223: `'assets/textures/dither_noise.png'`) ✅
- **Notes:** Fix #3 greps 3 lines instead of the plan's expected 2 — this is a **stricter outcome**, not a regression: the `AmbientSurfaceTier.fill` and `AmbientSurfaceTier.border` getters added in earlier Wave tasks also branch on `HelloColors.isDark`, which is exactly the theme-aware surface behavior Task 22 depends on. All other greps match the plan exactly. Build, analyzer, and assets all pass.

---

## NIGHT SHIFT #3 COMPLETE

### Summary
- Total tasks: 23
- Total phases: 6
- Waves: 4 (A concurrent, B/C/D sequential)
- New files: 10 (ambient_palette.dart, oklch.dart, signature_color.dart, palette_extractor.dart, focus_sources_provider.dart, ambient_palette_provider.dart, chromatic_atmosphere.dart, dither_noise.png, generate_dither_noise.dart, precompute_palettes.dart, palettes.json)
- Modified files: ~14

### Features delivered
Every screen in hello breathes with the content in focus:
- Home feed scroll → atmosphere cross-fades between centered card palettes (debounced 300ms)
- DM/Group/Decision/Trip/Settlement/Itinerary pages → push own palette, pop on dismiss, 1:1 swipe-back fluidity via ModalRoute.animation
- Cards adapt surface opacity to the ambient palette's saturation+luminance (theme-aware — blinds no one in dark mode)
- OLED dither overlay prevents banding
- Oklch signatures ensure equal perceived brightness across hues
- Idle sleep after 3s pauses drift animation

### Critical fixes preserved
1. ✅ Main-isolate extraction with ResizeImage(100×100)
2. ✅ Idle sleep on drift animation
3. ✅ Theme-aware luminance-based surface tier
4. ✅ Haptics only on active intent (zero in atmosphere code)
5. ✅ Route-animation-driven transitions (all 6 detail pages)
6. ✅ OLED dither + Oklch signatures

### Final verification
- dart analyze lib/ → 7 pre-existing errors (unrelated files), 0 new errors introduced by Wave D
- flutter build web → ✓ Built build/web (23.8s)
- All 7 critical-fix greps → pass
  - Fix #1 (no Isolate.spawn/compute in extractor): ✅
  - Fix #2 (idle timer wiring): ✅ (10 matches)
  - Fix #3 (HelloColors.isDark surface tier): ✅ (3 matches — plan expected 2; extra match is in the surface tier getters and is required for Task 22)
  - Fix #4 (no haptics in atmosphere): ✅
  - Fix #5 (routeAnimation in both providers): ✅
  - Fix #6a (Oklch signatures): ✅
  - Fix #6b (dither PNG referenced): ✅
