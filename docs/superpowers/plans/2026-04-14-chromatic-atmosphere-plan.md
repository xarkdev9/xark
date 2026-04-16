# Chromatic Atmosphere — Implementation Plan (Night Shift #3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Every screen in hello breathes with the content in focus. Photos, people, groups, decisions all carry a color identity; the atmosphere cross-fades smoothly as the user navigates.

**Architecture:** `ChromaticAtmosphere` widget replaces `AmbientMesh`. Global `ambientPaletteProvider` derived from a priority-sorted `focusSourcesProvider` stack. Colors resolved via Path A (photo extraction with ResizeImage downscale on main isolate), Path B (Oklch perceptually uniform signatures), or Path C (kind tokens). Card surfaces adapt to atmosphere saturation+luminance to guarantee WCAG AA contrast in both themes.

**Tech Stack:** Flutter 3.11+, Dart, Riverpod 3.3.1, `palette_generator ^0.3.3+4`, `crclib ^3.0.0`, `shared_preferences ^2.2.0`, `image ^4.1.0` (dev only, for dither noise generation)

**Spec:** `docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md`

**Tracker:** `/Users/ramchitturi/hello/3rdnightshift.md`

---

## Pre-Flight: Agent Context Protocol

Every agent MUST complete these steps before any code change:

```
1. Read this plan file completely
2. Read the spec: docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md (sections relevant to the task)
3. Read /Users/ramchitturi/hello/3rdnightshift.md for prior-wave context
4. Read EVERY file you will modify BEFORE modifying it
5. Read the six "Critical Fixes" at the end of this preflight — they are non-negotiable
```

### Six Critical Fixes (enforcement checklist for every task)

Any task that violates one of these fails review:

1. **Main-isolate extraction.** `PaletteGenerator.fromImageProvider` runs on the main isolate with `ResizeImage(width: 100, height: 100)`. Never across isolate boundaries — throws `Illegal argument in isolate message`.
2. **Idle sleep.** Drift animation pauses after 3s of no input, pauses when app is backgrounded. Resumes on activity or palette change.
3. **Theme-aware luminance-based surface tier.** Card fill blends toward theme's base surface (white in light, #1C1C1E in dark). Tier selection uses WCAG relative luminance + saturation, not saturation alone.
4. **Haptics on active intent only.** Scrolling fires ZERO haptics. Taps, sheet opens, tab swipes fire `HelloHaptic.select()`. The atmosphere system never originates haptics.
5. **Route-animation-driven transitions.** Detail-page FocusSources carry `routeAnimation`. `ambientPaletteProvider` lerps top-two when routeAnimation present. Swipe-back is 1:1 fluid with the gesture.
6. **OLED dither + Oklch signatures.** 256×256 noise PNG at 1.5% opacity over the atmosphere. Signature palettes generated in Oklch color space, not HSL — equal perceived brightness across hues.

### Tracker entry format

After every task, append to `/Users/ramchitturi/hello/3rdnightshift.md`:

```markdown
## Phase N / Task M: [title]
- **What was done:** [specific changes]
- **Why:** [which spec Part + which critical fix, if any]
- **Files changed:** [list with line ranges or "new file"]
- **Verification:** [exact command] → [result]
```

### Universal verification command (run after every task)

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero NEW errors. Pre-existing errors (documented in prior tracker) are acceptable but never increase.

---

## File Structure Map

### New files (9)
```
app/lib/models/ambient_palette.dart              (palette data model + WCAG luminance)
app/lib/services/oklch.dart                      (Oklch → sRGB pure-Dart conversion)
app/lib/services/signature_color.dart            (CRC32 hash → Oklch palette)
app/lib/services/palette_extractor.dart          (main-isolate extraction + cache + manifest loader)
app/lib/providers/focus_sources_provider.dart    (priority-sorted stack with routeAnimation)
app/lib/providers/ambient_palette_provider.dart  (derived provider + surface tier)
app/lib/views/home/decision_board/chromatic_atmosphere.dart  (the renderer widget)
app/assets/textures/dither_noise.png             (256×256 blue-noise PNG, generated)
scripts/precompute_palettes.dart                 (build-time palette manifest builder)
app/assets/palettes.json                         (generated — committed to repo)
```

### Modified files
```
app/pubspec.yaml                                  (+ deps, + assets/textures/, + palettes.json)
app/lib/views/home/decision_board/atmosphere.dart (AmbientMesh stays as thin wrapper → ChromaticAtmosphere, or replace call site and delete)
app/lib/views/home/decision_board/decision_board_page.dart (swap AmbientMesh for ChromaticAtmosphere)
app/lib/views/home/decision_board/pages/home_page.dart    (focus debounce wiring)
app/lib/views/home/decision_board/pages/plans_page.dart   (focus wiring)
app/lib/views/home/decision_board/pages/plans_view.dart   (focus wiring)
app/lib/views/home/decision_board/pages/chats_page.dart   (density hint)
app/lib/views/home/decision_board/pages/groups_page.dart  (density hint)
app/lib/views/home/decision_board/pages/dm_page.dart      (push/pop with routeAnimation)
app/lib/views/home/decision_board/pages/group_page.dart   (push/pop with routeAnimation)
app/lib/views/home/decision_board/pages/decision_page.dart(push/pop with routeAnimation)
app/lib/views/home/decision_board/pages/trip_page.dart    (push/pop with routeAnimation)
app/lib/views/home/decision_board/pages/settlement_page.dart (push/pop)
app/lib/views/home/decision_board/pages/itinerary_page.dart  (push/pop)
app/lib/views/home/decision_board/cards/_card_shell.dart  (adaptive surface tier)
```

---

## Execution Architecture

```
WAVE A (concurrent — no file conflicts):
  Phase 1: Foundation (Agent 1) — models + services + providers
  Phase 2: Assets (Agent 2)     — dither PNG + precompute script + palettes.json + pubspec

WAVE B (sequential — depends on Wave A):
  Phase 3: Renderer — ChromaticAtmosphere widget

WAVE C (sequential — depends on Wave B):
  Phase 4: Tab-level integration — swap AmbientMesh, wire debounced focus
  Phase 5: Detail-page focus sources + route animation binding

WAVE D (sequential — final):
  Phase 6: Adaptive card surface + verification battery
```

**Wave A conflict check:** Phase 1 touches only new files in `lib/models/`, `lib/services/`, `lib/providers/`. Phase 2 touches `pubspec.yaml`, new asset files, `scripts/`. The only potential conflict is `pubspec.yaml`. Phase 2 owns all pubspec changes — Phase 1 adds zero dependencies directly (Phase 2 adds them). If Phase 1 needs a dependency that's not yet added, the code compiles only AFTER Phase 2 completes `flutter pub get`. Fine — Phase 1 writes the code, Phase 2 adds deps, then Wave B runs and everything compiles together.

---

## Phase 1: Foundation (Wave A, Agent 1)

**Purpose:** Build the entire data and provider layer. No visual changes. After this phase, the atmosphere system's "brain" exists but nothing renders it yet.

**Files:** 6 new files, zero modifications.

### Task 1: AmbientPalette model + WCAG luminance extension

**Purpose:** The canonical 5-color palette type used everywhere. Includes WCAG relative-luminance math for the Surface Tier decision.

**Files:**
- Create: `app/lib/models/ambient_palette.dart`

- [ ] **Step 1: Read the spec**

Read `docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md` Part 3 (Core Concepts → AmbientPalette) and Part 7 (Theme-Aware + Luminance-Based Surface Tier) to understand why these exact fields and methods exist.

- [ ] **Step 2: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/models/ambient_palette.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// A 5-color palette representing a piece of content's color identity.
///
/// Sources:
/// - Path A: extracted from a photo via `palette_generator`
/// - Path B: generated from a user/group identifier via Oklch hash
/// - Path C: pre-computed per `HelloColors.kind*` token
///
/// Every AmbientPalette must expose `averageSaturation`,
/// `averageLightness`, and `averageRelativeLuminance` because
/// the surface tier decision reads these three metrics.
@immutable
class AmbientPalette {
  final Color dominant;
  final Color vibrant;
  final Color muted;
  final Color lightAccent;
  final Color darkAccent;

  const AmbientPalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.lightAccent,
    required this.darkAccent,
  });

  List<Color> get colors => [dominant, vibrant, muted, lightAccent, darkAccent];

  /// Average HSL saturation across all 5 colors (0.0 to 1.0).
  double get averageSaturation {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + HSLColor.fromColor(c).saturation);
    return sum / colors.length;
  }

  /// Average HSL lightness across all 5 colors (0.0 to 1.0).
  double get averageLightness {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + HSLColor.fromColor(c).lightness);
    return sum / colors.length;
  }

  /// Average WCAG 2.1 relative luminance across all 5 colors.
  /// 0.0 = pure black, 1.0 = pure white.
  double get averageRelativeLuminance {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + c.relativeLuminance);
    return sum / colors.length;
  }

  /// Linear interpolation between two palettes. Used for cross-fade animation.
  static AmbientPalette lerp(AmbientPalette a, AmbientPalette b, double t) {
    final tt = t.clamp(0.0, 1.0);
    return AmbientPalette(
      dominant: Color.lerp(a.dominant, b.dominant, tt) ?? a.dominant,
      vibrant: Color.lerp(a.vibrant, b.vibrant, tt) ?? a.vibrant,
      muted: Color.lerp(a.muted, b.muted, tt) ?? a.muted,
      lightAccent: Color.lerp(a.lightAccent, b.lightAccent, tt) ?? a.lightAccent,
      darkAccent: Color.lerp(a.darkAccent, b.darkAccent, tt) ?? a.darkAccent,
    );
  }

  /// Neutral fallback — used before any content is focused
  /// (e.g., splash, empty auth flow, settings pages).
  static const AmbientPalette neutral = AmbientPalette(
    dominant: Color(0xFFE5E5EA),
    vibrant: Color(0xFFD1D1D6),
    muted: Color(0xFFE5E5EA),
    lightAccent: Color(0xFFF2F2F7),
    darkAccent: Color(0xFFC7C7CC),
  );

  /// Build a palette from a single base color by varying HSL lightness.
  /// Used for Path C (kind tokens).
  factory AmbientPalette.fromBaseColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    HSLColor at(double s, double l) => HSLColor.fromAHSL(1.0, hsl.hue, s, l);
    return AmbientPalette(
      dominant:    base,
      vibrant:     at((hsl.saturation + 0.1).clamp(0.0, 1.0), (hsl.lightness + 0.05).clamp(0.0, 1.0)).toColor(),
      muted:       at((hsl.saturation - 0.2).clamp(0.0, 1.0), hsl.lightness).toColor(),
      lightAccent: at(hsl.saturation, (hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor(),
      darkAccent:  at(hsl.saturation, (hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
    );
  }

  /// Build a palette from a palette_generator result.
  /// Used for Path A (photo extraction).
  factory AmbientPalette.fromGenerator(PaletteGenerator generator) {
    final dominant = generator.dominantColor?.color
                  ?? generator.colors.firstOrNull
                  ?? AmbientPalette.neutral.dominant;
    final vibrant = generator.vibrantColor?.color
                 ?? generator.lightVibrantColor?.color
                 ?? dominant;
    final muted = generator.mutedColor?.color
               ?? generator.darkMutedColor?.color
               ?? dominant;
    final lightAccent = generator.lightVibrantColor?.color
                     ?? generator.lightMutedColor?.color
                     ?? vibrant;
    final darkAccent = generator.darkVibrantColor?.color
                    ?? generator.darkMutedColor?.color
                    ?? muted;
    return AmbientPalette(
      dominant: dominant,
      vibrant: vibrant,
      muted: muted,
      lightAccent: lightAccent,
      darkAccent: darkAccent,
    );
  }

  /// Serialize to JSON (for cache + manifest).
  Map<String, String> toJson() => {
    'dominant':    _hex(dominant),
    'vibrant':     _hex(vibrant),
    'muted':       _hex(muted),
    'lightAccent': _hex(lightAccent),
    'darkAccent':  _hex(darkAccent),
  };

  /// Deserialize from JSON.
  factory AmbientPalette.fromJson(Map<String, dynamic> json) => AmbientPalette(
    dominant:    _parseHex(json['dominant'] as String),
    vibrant:     _parseHex(json['vibrant'] as String),
    muted:       _parseHex(json['muted'] as String),
    lightAccent: _parseHex(json['lightAccent'] as String),
    darkAccent:  _parseHex(json['darkAccent'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is AmbientPalette &&
      other.dominant == dominant &&
      other.vibrant == vibrant &&
      other.muted == muted &&
      other.lightAccent == lightAccent &&
      other.darkAccent == darkAccent;

  @override
  int get hashCode => Object.hash(dominant, vibrant, muted, lightAccent, darkAccent);
}

String _hex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

Color _parseHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('ff$h', radix: 16));
}

/// WCAG 2.1 relative luminance formula.
/// Returns 0.0 (black) to 1.0 (white).
extension ColorRelativeLuminance on Color {
  double get relativeLuminance {
    double gamma(double c) {
      return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
    return 0.2126 * gamma(r) + 0.7152 * gamma(g) + 0.0722 * gamma(b);
  }
}
```

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/models/ambient_palette.dart
```

Expected: zero errors. (May warn about `palette_generator` import until Phase 2 runs `flutter pub get` — acceptable.)

- [ ] **Step 4: Update tracker**

Append to `/Users/ramchitturi/hello/3rdnightshift.md` per the format above.

---

### Task 2: Oklch → sRGB pure-Dart conversion

**Purpose:** Signature palettes (Path B) must be generated in Oklch color space to ensure equal perceived brightness across hues. HSL is mathematically uniform but optically flawed (yellow at L=0.55 is blinding; blue at L=0.55 is muddy). Oklch is perceptually uniform.

**Files:**
- Create: `app/lib/services/oklch.dart`

- [ ] **Step 1: Read the spec**

Spec Part 4, Path B — Signature Color. The Oklch math is from Björn Ottosson's 2020 specification: https://bottosson.github.io/posts/oklab/

- [ ] **Step 2: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/services/oklch.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Oklch (Oklab in polar coordinates) — perceptually uniform color space.
///
/// Reference: Björn Ottosson, 2020 — https://bottosson.github.io/posts/oklab/
///
/// Using Oklch instead of HSL guarantees that signatures at the same
/// `l` and `c` have equal perceived brightness regardless of `h`.
/// Yellow-Sarah and Blue-Alex look equally vibrant; neither blinding
/// nor muddy.
class Oklch {
  /// Lightness, 0.0 (black) to 1.0 (white). Perceptually linear.
  final double l;

  /// Chroma, 0.0 (gray) to ~0.4 (max displayable). Perceptually linear saturation.
  final double c;

  /// Hue in radians (0 to 2π).
  final double h;

  const Oklch({required this.l, required this.c, required this.h});

  /// Convert Oklch → sRGB Color.
  Color toColor() {
    // Polar → cartesian (Oklch → Oklab)
    final a = c * math.cos(h);
    final b = c * math.sin(h);

    // Oklab → linear sRGB (Ottosson's matrix)
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

    final lCubed = l_ * l_ * l_;
    final mCubed = m_ * m_ * m_;
    final sCubed = s_ * s_ * s_;

    final rLin =  4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed;
    final gLin = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed;
    final bLin = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed;

    // Linear sRGB → gamma-encoded sRGB
    double gamma(double x) {
      if (x <= 0.0031308) return 12.92 * x;
      return 1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055;
    }

    final r = gamma(rLin).clamp(0.0, 1.0);
    final g = gamma(gLin).clamp(0.0, 1.0);
    final bOut = gamma(bLin).clamp(0.0, 1.0);

    return Color.fromRGBO(
      (r * 255).round(),
      (g * 255).round(),
      (bOut * 255).round(),
      1.0,
    );
  }
}
```

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/services/oklch.dart
```

Expected: zero errors.

- [ ] **Step 4: Update tracker**

---

### Task 3: Signature color service

**Purpose:** Deterministic color assignment for people/groups without photos. Uses CRC32 hash → hue + Oklch for perceptual uniformity. Stable across platforms (CRC32 of UTF-8 bytes, not Dart's unstable `String.hashCode`).

**Files:**
- Create: `app/lib/services/signature_color.dart`

- [ ] **Step 1: Read the spec**

Spec Part 4, Path B — Signature Color.

- [ ] **Step 2: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/services/signature_color.dart`:

```dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:crclib/catalog.dart';

import '../models/ambient_palette.dart';
import 'oklch.dart';

/// Generate a deterministic AmbientPalette for a stable identifier
/// (userId, groupId). Same identifier always returns the same palette.
///
/// Uses CRC32 hashing of UTF-8 bytes for cross-platform stability
/// (Dart's String.hashCode is not stable across web vs native).
///
/// Uses Oklch color space for perceptually uniform output: every
/// identifier gets a palette with equal perceived brightness and
/// saturation, regardless of which hue it lands on.
AmbientPalette signaturePalette(String identifier) {
  final bytes = utf8.encode(identifier);
  final crc = Crc32().convert(bytes).toBigInt().toInt();
  final hueRadians = (crc.abs() % 360).toDouble() * (math.pi / 180);

  Color at(double l, double c) => Oklch(l: l, c: c, h: hueRadians).toColor();

  return AmbientPalette(
    dominant:    at(0.65, 0.12),
    vibrant:     at(0.72, 0.15),
    muted:       at(0.65, 0.06),
    lightAccent: at(0.85, 0.09),
    darkAccent:  at(0.45, 0.10),
  );
}
```

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/services/signature_color.dart
```

Expected: zero errors (after Phase 2 adds the `crclib` dependency — until then, `crclib/catalog.dart` import will be flagged as missing, which is acceptable).

- [ ] **Step 4: Update tracker**

---

### Task 4: Palette extractor service

**Purpose:** Central service for resolving any `ContentRef` to an `AmbientPalette`. Handles:
- Asset photos (pre-computed manifest lookup, instant)
- Network photos (main-isolate extraction with `ResizeImage(width: 100)` downscale, cached via `shared_preferences`)
- Person/group IDs (signature palette)
- Kind tokens (fallback)

**CRITICAL FIX #1:** Extraction MUST run on the main isolate. `dart:ui` objects cannot cross isolate boundaries. Downscale via `ResizeImage` provides both frame-budget safety (<5ms extraction) and memory safety.

**Files:**
- Create: `app/lib/services/palette_extractor.dart`

- [ ] **Step 1: Read the spec**

Spec Part 4, all three paths. Note the main-isolate rule (flagged ⚠ in the spec) — this is Critical Fix #1.

- [ ] **Step 2: Read existing theme tokens**

Read `app/lib/theme.dart` to confirm these exist: `HelloColors.kindDm`, `kindGroup`, `kindDecision`, `kindSettlement`, `kindItinerary`, `kindMemory`, `kindAiNudge`. These become the Path C fallback palettes.

- [ ] **Step 3: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/services/palette_extractor.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ambient_palette.dart';
import '../theme.dart';
import 'signature_color.dart';

/// Describes a content reference whose palette should be resolved.
///
/// Priority order for resolution:
/// 1. If `photoPath` or `photoUrl` is non-null → Path A (photo extraction)
/// 2. Else if `signatureId` is non-null → Path B (signature hash)
/// 3. Else → Path C (kind token)
@immutable
class ContentRef {
  /// Asset path, e.g. "assets/decide/bali_beach.jpg".
  final String? photoPath;

  /// Network URL for a photo.
  final String? photoUrl;

  /// Stable identifier for a person or group (used for signature fallback).
  final String? signatureId;

  /// Fallback kind: 'dm', 'group', 'decision', 'settlement', 'itinerary', 'memory', 'ai'.
  final String? kind;

  const ContentRef({
    this.photoPath,
    this.photoUrl,
    this.signatureId,
    this.kind,
  });
}

/// Global service for resolving palettes.
///
/// Lifecycle:
/// - `PaletteExtractor.init()` must be called once at app startup
///   to load the asset palette manifest.
/// - `PaletteExtractor.resolve(ref)` is the only public entry point.
class PaletteExtractor {
  static Map<String, AmbientPalette> _assetManifest = {};
  static Map<String, AmbientPalette> _networkCache = {};
  static bool _initialized = false;

  static const String _networkCacheKey = 'hello.palette.network_cache.v1';
  static const int _networkCacheMaxEntries = 500;

  /// Load the build-time asset palette manifest and warm the network cache.
  /// Call once at app startup, before any atmosphere is rendered.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Asset manifest — pre-computed by scripts/precompute_palettes.dart
    try {
      final raw = await rootBundle.loadString('assets/palettes.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _assetManifest = {
        for (final entry in map.entries)
          entry.key: AmbientPalette.fromJson(entry.value as Map<String, dynamic>),
      };
    } catch (e) {
      debugPrint('[PaletteExtractor] manifest missing or invalid: $e');
      _assetManifest = {};
    }

    // Network cache — LRU-bounded, persisted across app restarts
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_networkCacheKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _networkCache = {
          for (final entry in map.entries)
            entry.key: AmbientPalette.fromJson(entry.value as Map<String, dynamic>),
        };
      }
    } catch (e) {
      debugPrint('[PaletteExtractor] network cache load failed: $e');
      _networkCache = {};
    }
  }

  /// Resolve a ContentRef to an AmbientPalette using the 3-path chain.
  ///
  /// Returns synchronously from cache when possible. Network extraction
  /// is async but returns the kind-token fallback immediately if no cache hit;
  /// when the real extraction completes it cross-fades in via provider updates.
  static Future<AmbientPalette> resolve(ContentRef ref) async {
    // Path A — asset photo
    if (ref.photoPath != null) {
      final key = ref.photoPath!.replaceFirst('assets/', '');
      final cached = _assetManifest[key] ?? _assetManifest[ref.photoPath!];
      if (cached != null) return cached;
      // Asset not in manifest — fall through to runtime extract
      return await _extractFromAsset(ref.photoPath!);
    }

    // Path A — network photo
    if (ref.photoUrl != null) {
      final cached = _networkCache[ref.photoUrl!];
      if (cached != null) return cached;
      return await _extractFromNetwork(ref.photoUrl!);
    }

    // Path B — signature
    if (ref.signatureId != null) {
      return signaturePalette(ref.signatureId!);
    }

    // Path C — kind token
    if (ref.kind != null) {
      return kindPalette(ref.kind!);
    }

    return AmbientPalette.neutral;
  }

  /// Synchronous resolve for paths B/C (used in provider derivation
  /// where async is impractical).
  static AmbientPalette resolveSync(ContentRef ref) {
    if (ref.photoPath != null) {
      final key = ref.photoPath!.replaceFirst('assets/', '');
      return _assetManifest[key]
          ?? _assetManifest[ref.photoPath!]
          ?? (ref.kind != null ? kindPalette(ref.kind!) : AmbientPalette.neutral);
    }
    if (ref.photoUrl != null) {
      return _networkCache[ref.photoUrl!]
          ?? (ref.kind != null ? kindPalette(ref.kind!) : AmbientPalette.neutral);
    }
    if (ref.signatureId != null) return signaturePalette(ref.signatureId!);
    if (ref.kind != null) return kindPalette(ref.kind!);
    return AmbientPalette.neutral;
  }

  static Future<AmbientPalette> _extractFromAsset(String assetPath) async {
    // Asset images are low-res already in most cases; still downscale to 100px
    // to guarantee <5ms extraction.
    final provider = ResizeImage(AssetImage(assetPath), width: 100, height: 100);
    final generator = await PaletteGenerator.fromImageProvider(provider);
    final palette = AmbientPalette.fromGenerator(generator);
    _assetManifest[assetPath] = palette;
    return palette;
  }

  static Future<AmbientPalette> _extractFromNetwork(String url) async {
    // CRITICAL: Must run on main isolate. dart:ui objects cannot cross
    // isolate boundaries. Downscale to 100×100 gives <5ms extraction
    // and prevents RAM spikes on 4K source images.
    final provider = ResizeImage(NetworkImage(url), width: 100, height: 100);
    final generator = await PaletteGenerator.fromImageProvider(provider);
    final palette = AmbientPalette.fromGenerator(generator);
    _networkCache[url] = palette;
    _evictOldestIfOverflow();
    unawaited(_persistNetworkCache());
    return palette;
  }

  static void _evictOldestIfOverflow() {
    if (_networkCache.length <= _networkCacheMaxEntries) return;
    // Simple LRU: iteration order is insertion order in Dart Maps.
    final overflow = _networkCache.length - _networkCacheMaxEntries;
    final keysToRemove = _networkCache.keys.take(overflow).toList();
    for (final k in keysToRemove) {
      _networkCache.remove(k);
    }
  }

  static Future<void> _persistNetworkCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        for (final entry in _networkCache.entries) entry.key: entry.value.toJson(),
      };
      await prefs.setString(_networkCacheKey, jsonEncode(json));
    } catch (e) {
      debugPrint('[PaletteExtractor] network cache persist failed: $e');
    }
  }
}

/// Pre-computed palettes for each `HelloColors.kind*` token.
/// Used as Path C fallback when no photo and no signatureId.
AmbientPalette kindPalette(String kind) {
  final base = switch (kind) {
    'dm'         => HelloColors.kindDm,
    'group'      => HelloColors.kindGroup,
    'decision'   => HelloColors.kindDecision,
    'settlement' => HelloColors.kindSettlement,
    'itinerary'  => HelloColors.kindItinerary,
    'memory'     => HelloColors.kindMemory,
    'ai'         => HelloColors.kindAiNudge,
    _            => HelloColors.accent,
  };
  // kind* colors have low alpha (0x2B or 0x1E) by design. Force full opacity
  // before building the palette so Oklch calculations are meaningful.
  final opaque = Color.fromARGB(255, (base.r * 255).round(), (base.g * 255).round(), (base.b * 255).round());
  return AmbientPalette.fromBaseColor(opaque);
}
```

- [ ] **Step 4: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/services/palette_extractor.dart
```

Expected: zero errors (after Phase 2 adds `palette_generator` and `shared_preferences`; until then, imports flagged).

- [ ] **Step 5: Update tracker**

---

### Task 5: focusSourcesProvider

**Purpose:** Priority-sorted stack of focus sources. Top of stack drives the atmosphere. Detail pages carry `routeAnimation` so swipe-back is 1:1 fluid.

**CRITICAL FIX #5:** `FocusSource` carries optional `routeAnimation`. Derived provider uses it to lerp top-two sources during route transitions.

**Files:**
- Create: `app/lib/providers/focus_sources_provider.dart`

- [ ] **Step 1: Read the spec**

Spec Part 5 — Focus Tracking, especially the "Route-Animation-Driven Transitions" subsection.

- [ ] **Step 2: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/providers/focus_sources_provider.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/ambient_palette.dart';

/// A single focus source in the priority-sorted stack.
///
/// `routeAnimation`, when non-null, enables 1:1 swipe-back cross-fade
/// with the user's gesture (no snap at dismissal).
@immutable
class FocusSource {
  /// Stable identifier (e.g., "dm_sarah", "trip_swiss_jun_2026", "sheet_decision_abc").
  final String id;

  /// The palette this source contributes.
  final AmbientPalette palette;

  /// Priority — higher wins. 100=sheet, 50=detail page, 10=tab feed, 1=tab fallback.
  final int priority;

  /// If non-null, the atmosphere lerps `underlyingPalette → palette` by
  /// `routeAnimation.value`. When 1.0, fully on this source. When 0.0, dismissed.
  final Animation<double>? routeAnimation;

  const FocusSource({
    required this.id,
    required this.palette,
    required this.priority,
    this.routeAnimation,
  });

  FocusSource copyWith({AmbientPalette? palette, Animation<double>? routeAnimation}) {
    return FocusSource(
      id: id,
      palette: palette ?? this.palette,
      priority: priority,
      routeAnimation: routeAnimation ?? this.routeAnimation,
    );
  }
}

/// Priority-sorted stack of focus sources.
/// Use via [focusSourcesProvider].
class FocusSourceStack extends StateNotifier<List<FocusSource>> {
  FocusSourceStack() : super(const []);

  /// Push a new source. If a source with the same id exists, it is replaced.
  void push(FocusSource source) {
    final filtered = state.where((s) => s.id != source.id).toList();
    filtered.add(source);
    filtered.sort((a, b) => b.priority.compareTo(a.priority));
    state = filtered;
  }

  /// Pop the source with the given id.
  void pop(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  /// Update an existing source's palette (e.g., scrolling to a new centered card).
  void update(String id, AmbientPalette palette) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(palette: palette) else s,
    ];
  }

  /// Force a re-emit without mutating state — used by route-animation listeners
  /// to trigger derived-provider re-evaluation as the animation ticks.
  void touch() {
    state = List<FocusSource>.from(state);
  }
}

final focusSourcesProvider =
    StateNotifierProvider<FocusSourceStack, List<FocusSource>>(
  (ref) => FocusSourceStack(),
);
```

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/providers/focus_sources_provider.dart
```

Expected: zero errors.

- [ ] **Step 4: Update tracker**

---

### Task 6: ambientPaletteProvider + ambientSurfaceTierProvider

**Purpose:** The two global providers that every screen reads.

- `ambientPaletteProvider` — the currently active palette, with route-animation lerp
- `ambientSurfaceTierProvider` — the card surface tier derived from palette's risk score

**CRITICAL FIX #3:** Surface tier uses WCAG relative luminance + saturation (not saturation alone) and returns theme-aware opacity tiers (not hardcoded white).

**Files:**
- Create: `app/lib/providers/ambient_palette_provider.dart`

- [ ] **Step 1: Read the spec**

Spec Part 5 (derivation logic with routeAnimation) + Part 7 (theme-aware luminance-based tier selection).

- [ ] **Step 2: Read HelloColors.isDark**

Read `app/lib/theme.dart` to confirm `HelloColors.isDark` is a static getter. Section around Part 11 of the spec references this — it exists from Night Shift #1.

- [ ] **Step 3: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/providers/ambient_palette_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambient_palette.dart';
import '../theme.dart';
import 'focus_sources_provider.dart';

/// The currently active atmospheric palette.
///
/// Derived from `focusSourcesProvider`. If the top source has a
/// `routeAnimation` attached, the palette lerps between the top
/// and underlying sources based on the animation value — enabling
/// 1:1 swipe-back fluidity on iOS/Android edge-swipe dismissals.
final ambientPaletteProvider = Provider<AmbientPalette>((ref) {
  final sources = ref.watch(focusSourcesProvider);
  if (sources.isEmpty) return AmbientPalette.neutral;
  if (sources.length == 1) return sources.first.palette;

  final top = sources.first;
  final underlying = sources[1];

  final anim = top.routeAnimation;
  if (anim != null) {
    return AmbientPalette.lerp(underlying.palette, top.palette, anim.value);
  }
  return top.palette;
});

/// Card surface opacity tier.
///
/// Low risk (muted, near-neutral palette) → Whisper (70% surface)
/// Medium risk → Veil (80% surface)
/// High risk (vivid and luminance-far-from-theme) → Curtain (90% surface)
///
/// Risk = 0.6 × |paletteLuminance − themeNeutralLuminance| + 0.4 × paletteSaturation.
enum AmbientSurfaceTier { whisper, veil, curtain }

final ambientSurfaceTierProvider = Provider<AmbientSurfaceTier>((ref) {
  final palette = ref.watch(ambientPaletteProvider);

  final avgLum = palette.averageRelativeLuminance;
  final avgSat = palette.averageSaturation;

  // Theme's neutral base luminance:
  //   Light theme canvas #FAFAFA ≈ 0.95 relative luminance
  //   Dark theme canvas #111111  ≈ 0.009 relative luminance
  final themeNeutralLum = HelloColors.isDark ? 0.009 : 0.95;
  final luminanceDelta = (avgLum - themeNeutralLum).abs();

  final risk = (luminanceDelta * 0.6) + (avgSat * 0.4);

  if (risk < 0.20) return AmbientSurfaceTier.whisper;
  if (risk < 0.50) return AmbientSurfaceTier.veil;
  return AmbientSurfaceTier.curtain;
});

/// Theme-aware surface colors for each tier.
/// In light mode, blends toward white. In dark mode, blends toward #1C1C1E.
extension AmbientSurfaceTierColors on AmbientSurfaceTier {
  Color get fill {
    final base = HelloColors.isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFFFFFFF);
    final alpha = switch (this) {
      AmbientSurfaceTier.whisper => 0.70,
      AmbientSurfaceTier.veil    => 0.80,
      AmbientSurfaceTier.curtain => 0.90,
    };
    return base.withValues(alpha: alpha);
  }

  Color get border {
    final base = HelloColors.isDark ? Colors.white : Colors.black;
    final alpha = switch (this) {
      AmbientSurfaceTier.whisper => 0.06,
      AmbientSurfaceTier.veil    => 0.10,
      AmbientSurfaceTier.curtain => 0.14,
    };
    return base.withValues(alpha: alpha);
  }
}
```

- [ ] **Step 4: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/providers/ambient_palette_provider.dart
```

Expected: zero errors.

- [ ] **Step 5: Update tracker**

---

## Phase 2: Assets & Dependencies (Wave A, Agent 2)

**Purpose:** Add pubspec dependencies, generate the dither noise PNG, write and run the palette precompute script, commit `palettes.json`.

**Files:** 3 new files (+ 1 generated JSON + 1 generated PNG), 1 modification.

### Task 7: Update pubspec.yaml with new dependencies and asset paths

**Purpose:** Register the three new runtime dependencies (`palette_generator`, `crclib`, `shared_preferences`), the one dev dependency (`image`), and the two new asset paths (`assets/textures/`, `assets/palettes.json`).

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Read the current pubspec**

Read `/Users/ramchitturi/hello/app/pubspec.yaml` fully. Current state (verified):
- Dependencies ends at line 44 (`e2ee_chat_sdk: path: ../engine`)
- `dev_dependencies` block at lines 46-56
- `flutter.assets` block at lines 69-72 lists `assets/decide/`, `assets/memories/`, `assets/fonts/`

- [ ] **Step 2: Add runtime dependencies**

Find this block:
```yaml
  mobile_scanner: ^6.0.0
  e2ee_chat_sdk:
    path: ../engine
```

Replace with:
```yaml
  mobile_scanner: ^6.0.0
  palette_generator: ^0.3.3+4
  crclib: ^3.0.0
  shared_preferences: ^2.2.0
  e2ee_chat_sdk:
    path: ../engine
```

- [ ] **Step 3: Add dev dependency for image generation**

Find this block:
```yaml
  flutter_lints: ^6.0.0
  build_runner: ^2.13.1
```

Replace with:
```yaml
  flutter_lints: ^6.0.0
  build_runner: ^2.13.1
  image: ^4.1.0
```

- [ ] **Step 4: Register new asset paths**

Find this block:
```yaml
  assets:
    - assets/decide/
    - assets/memories/
    - assets/fonts/
```

Replace with:
```yaml
  assets:
    - assets/decide/
    - assets/memories/
    - assets/fonts/
    - assets/textures/
    - assets/palettes.json
```

- [ ] **Step 5: Run pub get**

```bash
cd /Users/ramchitturi/hello/app && flutter pub get
```

Expected: `Got dependencies!` or `Changed ${n} dependencies!` — no errors.

- [ ] **Step 6: Update tracker**

---

### Task 8: Generate dither noise PNG

**Purpose:** A 256×256 grayscale gaussian noise PNG used as a dither overlay over the atmosphere. Critical Fix #6: prevents visible banding on OLED displays.

**Files:**
- Create: `scripts/generate_dither_noise.dart`
- Create (generated): `app/assets/textures/dither_noise.png`

- [ ] **Step 1: Create the scripts directory if needed**

```bash
mkdir -p /Users/ramchitturi/hello/scripts
mkdir -p /Users/ramchitturi/hello/app/assets/textures
```

- [ ] **Step 2: Write the generator script**

Write this complete file to `/Users/ramchitturi/hello/scripts/generate_dither_noise.dart`:

```dart
// One-shot script: generates a 256×256 gaussian grayscale noise PNG.
// Used as dither overlay in ChromaticAtmosphere (prevents OLED banding).
//
// Run: cd app && dart run ../scripts/generate_dither_noise.dart
// Output: app/assets/textures/dither_noise.png

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const size = 256;
  final rng = math.Random(42); // deterministic — same output every run

  final image = img.Image(width: size, height: size, numChannels: 1);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      // Box-Muller transform → gaussian distribution centered at 128, σ≈32
      final u1 = rng.nextDouble().clamp(1e-9, 1.0);
      final u2 = rng.nextDouble();
      final z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
      final v = (128 + z * 32).clamp(0, 255).round();
      image.setPixel(x, y, img.ColorUint8.rgb(v, v, v));
    }
  }

  final out = File('app/assets/textures/dither_noise.png');
  out.writeAsBytesSync(img.encodePng(image));
  print('Wrote ${out.path} — ${out.lengthSync()} bytes');
}
```

- [ ] **Step 3: Run the script**

```bash
cd /Users/ramchitturi/hello/app && dart run ../scripts/generate_dither_noise.dart
```

Expected output: `Wrote app/assets/textures/dither_noise.png — [some number] bytes`. File size should be 30-60 KB.

- [ ] **Step 4: Verify the file exists**

```bash
ls -la /Users/ramchitturi/hello/app/assets/textures/dither_noise.png
```

Expected: file exists, non-zero size.

- [ ] **Step 5: Update tracker**

---

### Task 9: Write and run the palette precompute script

**Purpose:** At build time, scan all asset images in `assets/decide/` and `assets/memories/`, extract palettes, and write a JSON manifest. Ships with the app binary → zero runtime extraction cost for any pre-shipped asset.

**Files:**
- Create: `scripts/precompute_palettes.dart`
- Create (generated): `app/assets/palettes.json`

- [ ] **Step 1: Write the precompute script**

Write this complete file to `/Users/ramchitturi/hello/scripts/precompute_palettes.dart`:

```dart
// Build-time script: scans asset images and writes palettes.json manifest.
//
// Run: cd app && dart run ../scripts/precompute_palettes.dart
// Output: app/assets/palettes.json
//
// Format:
//   {
//     "decide/bali_beach.jpg": {
//       "dominant":    "#1a6b8f",
//       "vibrant":     "#e8b844",
//       "muted":       "#6b5a3d",
//       "lightAccent": "#a3c8d6",
//       "darkAccent":  "#0d3a4e"
//     },
//     ...
//   }

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final dirs = ['app/assets/decide', 'app/assets/memories'];
  final result = <String, Map<String, String>>{};

  for (final dirPath in dirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      print('[precompute] skipping missing dir: $dirPath');
      continue;
    }
    for (final entity in dir.listSync(recursive: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') &&
          !lower.endsWith('.png') && !lower.endsWith('.webp')) continue;

      final relPath = entity.path.replaceFirst('app/assets/', '');
      try {
        final bytes = entity.readAsBytesSync();
        final image = img.decodeImage(bytes);
        if (image == null) {
          print('[precompute] decode failed: ${entity.path}');
          continue;
        }
        final palette = _extractPalette(image);
        result[relPath] = palette;
        print('[precompute] $relPath → ${palette['dominant']}');
      } catch (e) {
        print('[precompute] error on ${entity.path}: $e');
      }
    }
  }

  final out = File('app/assets/palettes.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  print('\nWrote ${result.length} palettes to ${out.path}');
}

/// Lightweight palette extraction: downscale, k-means-like cluster across
/// 5 lightness bands, pick the most-saturated color from each band.
Map<String, String> _extractPalette(img.Image source) {
  // Downscale to 100×100 for speed and to dampen outliers
  final small = img.copyResize(source, width: 100, height: 100);

  // Collect pixels into 5 lightness buckets
  final buckets = List.generate(5, (_) => <_PixelHsl>[]);
  for (final px in small) {
    final hsl = _toHsl(px);
    if (hsl.s < 0.05) continue; // skip near-grayscale
    final bucketIndex = (hsl.l * 5).floor().clamp(0, 4);
    buckets[bucketIndex].add(hsl);
  }

  // Pick the most-saturated color from each bucket (fallback to avg)
  String colorOf(List<_PixelHsl> bucket, {double lFallback = 0.5}) {
    if (bucket.isEmpty) {
      return _hslToHex(0.0, 0.3, lFallback);
    }
    bucket.sort((a, b) => b.s.compareTo(a.s));
    final top = bucket.first;
    return _hslToHex(top.h, top.s, top.l);
  }

  // Overall dominant = most-saturated across all buckets
  final allPixels = buckets.expand((b) => b).toList();
  allPixels.sort((a, b) => b.s.compareTo(a.s));
  final dominant = allPixels.isEmpty
      ? _hslToHex(0.0, 0.2, 0.5)
      : _hslToHex(allPixels.first.h, allPixels.first.s, allPixels.first.l);

  return {
    'dominant':    dominant,
    'vibrant':     colorOf(buckets[3], lFallback: 0.6), // bright band
    'muted':       colorOf(buckets[2], lFallback: 0.5), // mid band
    'lightAccent': colorOf(buckets[4], lFallback: 0.8), // lightest band
    'darkAccent':  colorOf(buckets[1], lFallback: 0.3), // darker band
  };
}

class _PixelHsl {
  final double h, s, l;
  const _PixelHsl(this.h, this.s, this.l);
}

_PixelHsl _toHsl(img.Pixel px) {
  final r = px.r / 255.0;
  final g = px.g / 255.0;
  final b = px.b / 255.0;
  final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
  final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
  final l = (maxC + minC) / 2;
  if (maxC == minC) return _PixelHsl(0, 0, l);
  final d = maxC - minC;
  final s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC);
  double h;
  if (maxC == r) {
    h = ((g - b) / d) + (g < b ? 6 : 0);
  } else if (maxC == g) {
    h = ((b - r) / d) + 2;
  } else {
    h = ((r - g) / d) + 4;
  }
  h /= 6;
  return _PixelHsl(h, s, l);
}

String _hslToHex(double h, double s, double l) {
  double hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }
  double r, g, b;
  if (s == 0) {
    r = g = b = l;
  } else {
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  final ri = (r * 255).round();
  final gi = (g * 255).round();
  final bi = (b * 255).round();
  return '#${ri.toRadixString(16).padLeft(2, '0')}'
      '${gi.toRadixString(16).padLeft(2, '0')}'
      '${bi.toRadixString(16).padLeft(2, '0')}';
}
```

- [ ] **Step 2: Run the script**

```bash
cd /Users/ramchitturi/hello && dart run scripts/precompute_palettes.dart
```

Expected: script prints one line per image, then summary "Wrote N palettes to app/assets/palettes.json". N should match the count of asset images.

- [ ] **Step 3: Verify the manifest file**

```bash
head -20 /Users/ramchitturi/hello/app/assets/palettes.json
```

Expected: JSON object with keys like `decide/bali_beach.jpg` and nested color maps.

- [ ] **Step 4: Update tracker**

---

### Task 10: Initialize PaletteExtractor at app startup

**Purpose:** Load the asset palette manifest once before any atmosphere tries to render. Without this, every asset-photo resolve falls back to runtime extraction.

**Files:**
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Read main.dart**

Read `/Users/ramchitturi/hello/app/lib/main.dart`. Identify the `main()` function and where `Firebase.initializeApp()` is called.

- [ ] **Step 2: Add the initialization call**

Find:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
```

Add import at the top of the file (alongside other imports):
```dart
import 'services/palette_extractor.dart';
```

Then immediately after `WidgetsFlutterBinding.ensureInitialized();`, insert:
```dart
  await PaletteExtractor.init();
```

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/main.dart
```

Expected: zero new errors.

- [ ] **Step 4: Update tracker**

---

## WAVE A GATE

After both Phase 1 and Phase 2 agents complete:

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
cd /Users/ramchitturi/hello/app && flutter pub get
```

Must return zero new errors. Proceed to Wave B.

---

## Phase 3: Renderer — ChromaticAtmosphere Widget (Wave B)

**Purpose:** The visual core. A full-bleed widget that renders the current ambient palette as 5 drifting radial gradients, cross-fades smoothly on palette change, dithers against OLED banding, and sleeps when idle.

**CRITICAL FIXES #2, #6:** Idle sleep via pointer/scroll/lifecycle listeners. OLED dither noise overlay at 1.5% opacity.

**Files:** 1 new file.

### Task 11: Create ChromaticAtmosphere widget

**Files:**
- Create: `app/lib/views/home/decision_board/chromatic_atmosphere.dart`

- [ ] **Step 1: Read the spec**

Spec Part 6 (Atmosphere Renderer) — read fully, especially the Composition, Idle Sleep, Cross-Fade, and OLED Banding Protection subsections.

- [ ] **Step 2: Read the existing atmosphere.dart for comparison**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/atmosphere.dart` to see how the old `AmbientMesh` was structured. This new widget replaces it.

- [ ] **Step 3: Create the file**

Write this complete file to `/Users/ramchitturi/hello/app/lib/views/home/decision_board/chromatic_atmosphere.dart`:

```dart
// Chromatic Atmosphere — living surface renderer.
//
// Replaces the legacy AmbientMesh. Full-bleed, content-responsive,
// theme-aware, idle-sleeping, OLED-dithered background.
//
// Reads: ambientPaletteProvider (global content palette)
// Respects: MediaQuery.disableAnimationsOf (reduced motion)
//           WidgetsBindingObserver (app lifecycle)
//           pointer/scroll activity (idle sleep after 3s)
//
// See docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ambient_palette.dart';
import '../../../providers/ambient_palette_provider.dart';
import '../../../theme.dart';

/// Density hint — passed via InheritedWidget from each screen.
/// List pages use `dense` (saturation × 0.6). Detail pages use `focus` (× 1.0).
enum AtmosphereDensity { dense, focus }

class AtmosphereDensityScope extends InheritedWidget {
  final AtmosphereDensity density;
  const AtmosphereDensityScope({
    super.key,
    required this.density,
    required super.child,
  });

  static AtmosphereDensity of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AtmosphereDensityScope>();
    return scope?.density ?? AtmosphereDensity.focus;
  }

  @override
  bool updateShouldNotify(AtmosphereDensityScope old) => old.density != density;
}

/// Full-bleed living atmosphere. Place as the FIRST child of a Stack
/// wrapping the scaffold body.
class ChromaticAtmosphere extends ConsumerStatefulWidget {
  const ChromaticAtmosphere({super.key});

  @override
  ConsumerState<ChromaticAtmosphere> createState() => _ChromaticAtmosphereState();
}

class _ChromaticAtmosphereState extends ConsumerState<ChromaticAtmosphere>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Drift — slow background motion (20s cycle). Pauses when idle.
  late final AnimationController _drift;

  // Cross-fade — 800ms tween when palette changes.
  late final AnimationController _crossfade;

  AmbientPalette? _current;
  AmbientPalette? _previous;

  // Idle sleep — drift pauses after 3s of no user activity.
  Timer? _idleTimer;
  static const Duration _idleThreshold = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _crossfade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    WidgetsBinding.instance.addObserver(this);
    _armIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    _crossfade.dispose();
    super.dispose();
  }

  // ── Idle sleep ────────────────────────────────────────────────

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleThreshold, () {
      if (mounted && _drift.isAnimating) _drift.stop();
    });
  }

  void _onUserActivity() {
    if (!_drift.isAnimating) _drift.repeat();
    _armIdleTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _drift.stop();
      _idleTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _drift.repeat();
      _armIdleTimer();
    }
  }

  // ── Cross-fade on palette change ──────────────────────────────

  void _handlePaletteChange(AmbientPalette next) {
    if (_current == null) {
      _current = next;
      return;
    }
    if (next == _current) return;

    _previous = _current;
    _current = next;

    // Reduced motion → snap
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _crossfade.value = 1.0;
      setState(() {});
      return;
    }

    _crossfade
      ..reset()
      ..animateTo(1.0, curve: Curves.easeInOutCubic);

    // Wake drift — palette change = new content = greet the user
    _onUserActivity();
  }

  AmbientPalette get _displayPalette {
    if (_current == null) return AmbientPalette.neutral;
    if (_previous == null) return _current!;
    if (_crossfade.value >= 1.0) return _current!;
    return AmbientPalette.lerp(_previous!, _current!, _crossfade.value);
  }

  Alignment _driftedCenter(int index, double t) {
    final phase = t * 2 * math.pi + index * (2 * math.pi / 5);
    const baseX = [-0.5, 0.3, 0.7, -0.2, 0.0];
    const baseY = [-0.3, -0.5, 0.2, 0.5, 0.1];
    return Alignment(
      baseX[index] + 0.2 * math.sin(phase),
      baseY[index] + 0.2 * math.cos(phase * 0.7),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to palette changes — triggers _handlePaletteChange
    ref.listen<AmbientPalette>(ambientPaletteProvider, (prev, next) {
      _handlePaletteChange(next);
    });
    // Also seed _current on first build
    final initialPalette = ref.watch(ambientPaletteProvider);
    _current ??= initialPalette;

    final density = AtmosphereDensityScope.of(context);
    final saturationMultiplier = density == AtmosphereDensity.dense ? 0.6 : 1.0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      onPointerMove: (_) => _onUserActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _onUserActivity();
          return false;
        },
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_drift, _crossfade]),
            builder: (context, _) {
              final palette = _displayPalette;
              final colors = palette.colors;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Canvas base (brightness-aware)
                  ColoredBox(color: HelloColors.voidBg),

                  // 5 radial gradients — one per palette color
                  for (var i = 0; i < 5; i++)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: _driftedCenter(i, _drift.value),
                            radius: 0.9,
                            colors: [
                              colors[i].withValues(alpha: 0.40 * saturationMultiplier),
                              colors[i].withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // OLED dither overlay — 1.5% opacity noise breaks banding
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.015,
                        child: Image.asset(
                          'assets/textures/dither_noise.png',
                          repeat: ImageRepeat.repeat,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/chromatic_atmosphere.dart
```

Expected: zero errors.

- [ ] **Step 5: Smoke-test the widget compiles in isolation**

Confirm the file compiles as part of the full lib/ analysis:
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: no new errors attributable to this file.

- [ ] **Step 6: Update tracker**

---

## Phase 4: Tab-Level Integration (Wave C, Task 1)

**Purpose:** Swap the legacy `AmbientMesh` for `ChromaticAtmosphere` in the one call site (`decision_board_page.dart`). Wire debounced focus on HomePage and PlansPage. Set density hints on Chats/Groups.

**Files:** 5 modifications.

### Task 12: Replace AmbientMesh with ChromaticAtmosphere

**Files:**
- Modify: `app/lib/views/home/decision_board/decision_board_page.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/decision_board_page.dart`. Confirm line 84 contains `const Positioned.fill(child: AmbientMesh())`.

- [ ] **Step 2: Replace the AmbientMesh reference**

Find:
```dart
            const Positioned.fill(child: AmbientMesh()),
```

Replace with:
```dart
            const Positioned.fill(child: ChromaticAtmosphere()),
```

- [ ] **Step 3: Update imports**

Find the import:
```dart
import 'atmosphere.dart';
```

Replace with:
```dart
import 'atmosphere.dart' show AmbientMesh; // kept for backward-compat references, if any
import 'chromatic_atmosphere.dart';
```

If no `AmbientMesh` references remain in the file (check with a text search), remove the `atmosphere.dart` import entirely:

```bash
grep -n 'AmbientMesh' /Users/ramchitturi/hello/app/lib/views/home/decision_board/decision_board_page.dart
```

If the grep returns nothing, simplify the import to:
```dart
import 'chromatic_atmosphere.dart';
```

- [ ] **Step 4: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/decision_board_page.dart
```

Expected: zero new errors.

- [ ] **Step 5: Verify the app builds**

```bash
cd /Users/ramchitturi/hello/app && flutter build web --no-tree-shake-icons --no-wasm-dry-run 2>&1 | tail -5
```

Expected: `✓ Built build/web`. If this fails, the atmosphere replacement broke something — read the error and fix before proceeding.

- [ ] **Step 6: Update tracker**

---

### Task 13: Wire debounced focus on HomePage

**Purpose:** As the user scrolls the home feed, the atmosphere should follow the centered card — but only after it's been stable for 300ms (no strobe during fast scroll).

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/pages/home_page.dart`. Identify its state class.

- [ ] **Step 2: Read existing providers**

Confirm `centeredFeedItemIdProvider` exists:
```bash
grep -n 'centeredFeedItemIdProvider' /Users/ramchitturi/hello/app/lib/providers/viewport_focus_provider.dart
```

- [ ] **Step 3: Add imports**

At the top of `home_page.dart`, add these imports (alongside existing ones):

```dart
import 'dart:async';

import '../../../../models/ambient_palette.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../providers/viewport_focus_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../models/feed_item.dart';
import '../chromatic_atmosphere.dart';
```

Skip any that are already present (Read first, then Edit).

- [ ] **Step 4: Add debounced focus listener**

Inside the state class, add these members and methods:

```dart
  Timer? _focusDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireFocusListener();
    });
  }

  void _wireFocusListener() {
    ref.listenManual<String?>(centeredFeedItemIdProvider, (_, next) {
      _focusDebounce?.cancel();
      _focusDebounce = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted || next == null) return;
        final feed = ref.read(homeFeedProvider);
        final item = _feedItemById(feed, next);
        if (item == null) return;
        final palette = await PaletteExtractor.resolve(_contentRefOf(item));
        if (!mounted) return;
        ref.read(focusSourcesProvider.notifier).push(
          FocusSource(id: 'home_feed', palette: palette, priority: 10),
        );
      });
    });
  }

  FeedItem? _feedItemById(List<FeedItem> items, String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  ContentRef _contentRefOf(FeedItem item) {
    // Minimal mapping — sufficient for the home feed's top-level items.
    // Photo-backed items resolve via Path A; others fall to Path B/C.
    return switch (item) {
      DmFeedItem(:final conversation) => ContentRef(
          signatureId: conversation.peerId,
          kind: 'dm',
        ),
      GroupFeedItem(:final conversation) => ContentRef(
          signatureId: conversation.id,
          kind: 'group',
        ),
      DecisionHeroFeedItem(:final photoUrl) => ContentRef(
          photoPath: photoUrl?.startsWith('assets/') == true ? photoUrl : null,
          photoUrl: photoUrl?.startsWith('http') == true ? photoUrl : null,
          kind: 'decision',
        ),
      DecisionSmallFeedItem() => const ContentRef(kind: 'decision'),
      FocusHeroFeedItem(:final trip) => ContentRef(
          photoPath: trip.photoUrl?.startsWith('assets/') == true ? trip.photoUrl : null,
          photoUrl: trip.photoUrl?.startsWith('http') == true ? trip.photoUrl : null,
          kind: 'trip',
        ),
      TripFeedItem(:final trip) => ContentRef(
          photoPath: trip.photoUrl?.startsWith('assets/') == true ? trip.photoUrl : null,
          photoUrl: trip.photoUrl?.startsWith('http') == true ? trip.photoUrl : null,
          kind: 'trip',
        ),
      SettlementFeedItem() => const ContentRef(kind: 'settlement'),
      ItineraryFeedItem() => const ContentRef(kind: 'itinerary'),
      MemoryFeedItem() => const ContentRef(kind: 'memory'),
      AiNudgeFeedItem() => const ContentRef(kind: 'ai'),
    };
  }
```

Add to the existing `dispose` method:
```dart
  @override
  void dispose() {
    _focusDebounce?.cancel();
    ref.read(focusSourcesProvider.notifier).pop('home_feed');
    super.dispose();
  }
```

(If `dispose` already exists, insert the two new lines before `super.dispose();`.)

- [ ] **Step 5: Wrap the body in AtmosphereDensityScope**

Find the `build` method. Wrap the returned widget tree with `AtmosphereDensityScope(density: AtmosphereDensity.dense, child: ...)`.

Example pattern:
```dart
@override
Widget build(BuildContext context) {
  super.build(context); // if KeepAlive
  return AtmosphereDensityScope(
    density: AtmosphereDensity.dense,
    child: /* existing body */,
  );
}
```

- [ ] **Step 6: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home_page.dart
```

Expected: zero new errors. If field names like `peerId`, `trip.photoUrl` don't exist on the models, read `app/lib/models/feed_item.dart`, `app/lib/models/trip.dart`, and `app/lib/models/conversation` (via `e2ee_chat_sdk`) to find the correct field names, then adjust `_contentRefOf` accordingly.

- [ ] **Step 7: Update tracker**

---

### Task 14: Wire focus on PlansPage

**Purpose:** Same pattern as HomePage — debounce `centeredFeedItemIdProvider`, push `FocusSource(id: 'plans_feed', priority: 10)` with density=dense.

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/plans_page.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/pages/plans_page.dart`.

- [ ] **Step 2: Apply the same pattern as Task 13**

- Add same imports (`dart:async`, `focus_sources_provider`, `viewport_focus_provider`, `palette_extractor`, `feed_item`, `chromatic_atmosphere`).
- Add `Timer? _focusDebounce;` field.
- Add `initState` hook that calls `_wireFocusListener()` after first frame.
- Implement `_wireFocusListener` using `plansFeedProvider` instead of `homeFeedProvider`, and push `FocusSource(id: 'plans_feed', ..., priority: 10)`.
- Include the same `_feedItemById` and `_contentRefOf` helpers.
- Add cleanup in `dispose`: cancel timer, pop `'plans_feed'` source.
- Wrap `build` return value in `AtmosphereDensityScope(density: AtmosphereDensity.dense, ...)`.

(Copy the helper method bodies verbatim from Task 13 — do not "similar to Task 13" shortcut.)

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/plans_page.dart
```

Expected: zero new errors.

- [ ] **Step 4: Update tracker**

---

### Task 15: Set density hint on ChatsPage and GroupsPage

**Purpose:** List pages run at dense saturation (0.6× multiplier) — preserves scan speed per Enforcement 4.

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/chats_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/groups_page.dart`

- [ ] **Step 1: Read both files**

Read each file to identify the `build` method and its returned widget tree.

- [ ] **Step 2: Wrap each page's body**

For each file:

1. Add import at the top:
```dart
import '../chromatic_atmosphere.dart';
```

2. Wrap the `build` return value with:
```dart
return AtmosphereDensityScope(
  density: AtmosphereDensity.dense,
  child: /* existing body */,
);
```

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/chats_page.dart lib/views/home/decision_board/pages/groups_page.dart
```

Expected: zero new errors.

- [ ] **Step 4: Update tracker**

---

## Phase 5: Detail-Page Focus Sources with Route Animation (Wave C, Task 2)

**Purpose:** Every detail page pushes a FocusSource on mount, pops on dismiss, and binds to its `ModalRoute.animation` so edge-swipe-back is 1:1 fluid.

**CRITICAL FIX #5:** Every detail page must pass `routeAnimation: ModalRoute.of(context)?.animation`.

**Files:** 6 modifications.

### Task 16: DmPage push/pop with route animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/dm_page.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/pages/dm_page.dart`. Identify the state class and its `initState`/`dispose` methods.

- [ ] **Step 2: Add imports**

Add to the import block at the top (skip any already present):

```dart
import '../../../../models/ambient_palette.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../chromatic_atmosphere.dart';
```

- [ ] **Step 3: Add the focus-source push/pop lifecycle**

Inside the state class:

```dart
  bool _focusPushed = false;
  Animation<double>? _routeAnim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusPushed) return;
    final anim = ModalRoute.of(context)?.animation;
    _routeAnim = anim;
    anim?.addListener(_onRouteTick);
    _focusPushed = true;
    _pushFocusSource();
  }

  Future<void> _pushFocusSource() async {
    // widget.item is a DmFeedItem — pull peer id from it
    final peerId = widget.item.conversation.peerId;
    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: peerId, kind: 'dm'),
    );
    if (!mounted) return;
    ref.read(focusSourcesProvider.notifier).push(
      FocusSource(
        id: 'dm_$peerId',
        palette: palette,
        priority: 50,
        routeAnimation: _routeAnim,
      ),
    );
  }

  void _onRouteTick() {
    if (!mounted) return;
    ref.read(focusSourcesProvider.notifier).touch();
  }
```

Add to the existing `dispose` method (before `super.dispose()`):

```dart
    _routeAnim?.removeListener(_onRouteTick);
    final peerId = widget.item.conversation.peerId;
    ref.read(focusSourcesProvider.notifier).pop('dm_$peerId');
```

If `widget.item.conversation.peerId` doesn't exist as a field, use whichever conversation identifier is available (e.g., `widget.item.conversation.id`) — read `app/lib/models/feed_item.dart` first to determine the correct field.

- [ ] **Step 4: Wrap body in AtmosphereDensityScope (focus)**

In the `build` method, wrap the return value:

```dart
return AtmosphereDensityScope(
  density: AtmosphereDensity.focus,
  child: /* existing body */,
);
```

- [ ] **Step 5: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/dm_page.dart
```

Expected: zero new errors.

- [ ] **Step 6: Update tracker**

---

### Task 17: GroupPage push/pop with route animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/group_page.dart`

- [ ] **Step 1: Read the file**

- [ ] **Step 2: Apply the same pattern as Task 16**

Same imports. Same state fields (`_focusPushed`, `_routeAnim`). Same `didChangeDependencies`, `_pushFocusSource`, `_onRouteTick` methods. Same dispose additions.

Differences:
- Source id: `'group_${widget.item.conversation.id}'`
- ContentRef: `ContentRef(signatureId: widget.item.conversation.id, kind: 'group')` (add `photoPath` if group has a cover photo field)
- Wrap body in `AtmosphereDensityScope(density: AtmosphereDensity.focus, child: ...)`

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/group_page.dart
```

- [ ] **Step 4: Update tracker**

---

### Task 18: DecisionPage push/pop with route animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/decision_page.dart`

- [ ] **Step 1: Read the file**

- [ ] **Step 2: Apply the pattern**

Same imports + lifecycle methods.

Differences:
- Source id: `'decision_${_itemId()}'` where `_itemId()` extracts the id from the decision being viewed.
- ContentRef: pull photo if the decision has one (check `mockDecisionHero` map for photo URL), otherwise `ContentRef(kind: 'decision')`.
- Density: `focus`.

If the page already has logic to derive the item's photo URL, reuse it to build the ContentRef.

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/decision_page.dart
```

- [ ] **Step 4: Update tracker**

---

### Task 19: TripPage push/pop with route animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/trip_page.dart`

- [ ] **Step 1: Read the file**

- [ ] **Step 2: Apply the pattern**

Differences:
- Source id: `'trip_${widget.item.trip.id}'` (check actual field name — read trip.dart if unsure)
- ContentRef: `ContentRef(photoPath: photoUrlForAsset(trip), photoUrl: photoUrlForNetwork(trip), kind: 'trip')` where you discriminate asset vs network by prefix (`assets/` vs `http`).
- Density: `focus`.

- [ ] **Step 3: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/trip_page.dart
```

- [ ] **Step 4: Update tracker**

---

### Task 20: SettlementPage push/pop with route animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/settlement_page.dart`

- [ ] **Step 1: Read the file**

- [ ] **Step 2: Apply the pattern**

Differences:
- Source id: `'settlement_${widget.item.settlement.id}'` (check actual field)
- ContentRef: `ContentRef(kind: 'settlement')` — no photo.
- Density: `focus`.

- [ ] **Step 3: Verify**

- [ ] **Step 4: Update tracker**

---

### Task 21: ItineraryPage push/pop with route animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/itinerary_page.dart`

- [ ] **Step 1: Read the file**

- [ ] **Step 2: Apply the pattern**

Differences:
- Source id: `'itinerary_${widget.item.event.id}'` (check actual field)
- ContentRef: if the parent trip's photo is accessible from the itinerary item, use that (Path A). Otherwise `ContentRef(kind: 'itinerary')`.
- Density: `focus`.

- [ ] **Step 3: Verify**

- [ ] **Step 4: Update tracker**

---

## Phase 6: Adaptive Card Surface + Verification (Wave D)

**Purpose:** Make every card read `ambientSurfaceTierProvider` and use the tier's fill/border. Then run the full verification battery.

### Task 22: Update CardShell to use adaptive surface tier

**Purpose:** The base `CardShell` widget wraps all content cards. It must blend its fill with the atmosphere-derived tier to preserve WCAG contrast.

**Files:**
- Modify: `app/lib/views/home/decision_board/cards/_card_shell.dart`

- [ ] **Step 1: Read the file**

Read `/Users/ramchitturi/hello/app/lib/views/home/decision_board/cards/_card_shell.dart`. Find the `build` method and identify where the card's fill color and border are set.

- [ ] **Step 2: Add the provider import**

At the top of the file, add:

```dart
import '../../../../providers/ambient_palette_provider.dart';
```

- [ ] **Step 3: Read the tier in build**

Inside the `build` method (which is already a `ConsumerStatefulWidget`, so `ref` is available via `ref.watch`), add:

```dart
final surfaceTier = ref.watch(ambientSurfaceTierProvider);
```

- [ ] **Step 4: Apply the tier to the card's fill and border**

Find where the card's decoration is set (likely a `BoxDecoration` or `DecoratedBox` with a color and optional border). Replace the hardcoded fill color with `surfaceTier.fill` and the border color with `surfaceTier.border`.

Example pattern — if current code is:
```dart
decoration: BoxDecoration(
  color: HelloGlass.whisperFill,
  borderRadius: BorderRadius.circular(42),
  border: Border.all(color: HelloGlass.whisperBorder, width: 0.5),
),
```

Replace with:
```dart
decoration: BoxDecoration(
  color: surfaceTier.fill,
  borderRadius: BorderRadius.circular(42),
  border: Border.all(color: surfaceTier.border, width: 0.5),
),
```

If the file uses other fill/border references (e.g., `HelloGlass.veilFill`, `curtainFill`), unify all of them to `surfaceTier.fill` so every card responds to the ambient atmosphere.

- [ ] **Step 5: Verify**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/_card_shell.dart
```

Expected: zero new errors.

- [ ] **Step 6: Update tracker**

---

### Task 23: Full verification battery

**Files:**
- Read-only: everything

- [ ] **Step 1: Analyze the full lib**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero NEW errors. Count pre-existing errors from the tracker — this phase must not increase them.

- [ ] **Step 2: Build for web**

```bash
cd /Users/ramchitturi/hello/app && flutter build web --no-tree-shake-icons --no-wasm-dry-run 2>&1 | tail -5
```

Expected: `✓ Built build/web`.

- [ ] **Step 3: Verify precompute script runs clean**

```bash
cd /Users/ramchitturi/hello && dart run scripts/precompute_palettes.dart
```

Expected: completes in <10 seconds with "Wrote N palettes".

- [ ] **Step 4: Verify dither PNG exists and has non-zero size**

```bash
ls -la /Users/ramchitturi/hello/app/assets/textures/dither_noise.png
```

Expected: file exists, 30-60 KB.

- [ ] **Step 5: Verify palettes.json exists and has non-zero content**

```bash
cd /Users/ramchitturi/hello && wc -l app/assets/palettes.json && head -15 app/assets/palettes.json
```

Expected: >20 lines, valid JSON, contains entries for `decide/*.jpg` keys.

- [ ] **Step 6: Spec-driven success criteria spot checks**

Confirm each of these against the spec's Part 17:

- ✅ Main-isolate extraction (no Isolate.spawn, no compute() in palette_extractor.dart — confirmed via grep)
- ✅ Idle sleep (Timer in chromatic_atmosphere.dart — confirmed via grep)
- ✅ Theme-aware surface tier (HelloColors.isDark branching in ambient_palette_provider.dart — confirmed via grep)
- ✅ Haptics absent from chromatic_atmosphere.dart (grep 'HelloHaptic\|HapticFeedback' returns zero matches in the atmosphere code)
- ✅ routeAnimation field present in FocusSource
- ✅ Oklch conversion in services/oklch.dart (not HSL)
- ✅ Dither PNG rendered in ChromaticAtmosphere at 0.015 opacity (confirmed via code inspection)

Run these greps to confirm:

```bash
cd /Users/ramchitturi/hello
grep -n 'Isolate.spawn\|compute(' app/lib/services/palette_extractor.dart  # expect 0 results
grep -n '_idleTimer\|_armIdleTimer\|didChangeAppLifecycleState' app/lib/views/home/decision_board/chromatic_atmosphere.dart  # expect multiple matches
grep -n 'HelloColors.isDark' app/lib/providers/ambient_palette_provider.dart  # expect 2 matches
grep -n 'HelloHaptic\|HapticFeedback' app/lib/views/home/decision_board/chromatic_atmosphere.dart  # expect 0 results
grep -n 'routeAnimation' app/lib/providers/focus_sources_provider.dart app/lib/providers/ambient_palette_provider.dart  # expect matches in both
grep -n 'Oklch' app/lib/services/signature_color.dart  # expect match
grep -n 'dither_noise' app/lib/views/home/decision_board/chromatic_atmosphere.dart  # expect match
```

- [ ] **Step 7: Update tracker with the final summary**

Append to `/Users/ramchitturi/hello/3rdnightshift.md`:

```markdown
---

## NIGHT SHIFT #3 COMPLETE

### Summary
- Total tasks: 23
- Total phases: 6
- New files: 9 (ambient_palette.dart, oklch.dart, signature_color.dart, palette_extractor.dart, focus_sources_provider.dart, ambient_palette_provider.dart, chromatic_atmosphere.dart, dither_noise.png, 2 scripts)
- Modified files: ~10

### Critical fixes preserved:
1. ✅ Main-isolate extraction with ResizeImage downscale
2. ✅ Idle sleep on drift animation
3. ✅ Theme-aware luminance-based surface tier
4. ✅ Haptics only on active intent (none in atmosphere code)
5. ✅ Route-animation-driven transitions
6. ✅ OLED dither PNG + Oklch signatures

### Verification:
- dart analyze lib/ → [result]
- flutter build web → [result]
- precompute_palettes.dart → [N palettes]
- dither_noise.png → [size]
- palettes.json → [size, entries]
```

---

## Plan Summary

| Wave | Phase | Tasks | Parallelism |
|------|-------|-------|-------------|
| A | 1 + 2 | 1–10 | 2 concurrent agents |
| B | 3 | 11 | Sequential |
| C | 4 + 5 | 12–21 | Sequential |
| D | 6 | 22–23 | Sequential |

**Total: 23 tasks across 4 waves, 6 phases.**
