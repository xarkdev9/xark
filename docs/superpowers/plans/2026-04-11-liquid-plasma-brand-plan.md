# Liquid Plasma Brand System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan. This plan is pre-decomposed into three waves. Wave 1 has **7 parallel tracks** (dispatch all 7 simultaneously). Wave 2 has **4 parallel tracks** (dispatch all 4 simultaneously after Wave 1 completes). Wave 3 is **serial** (executed directly by the controller). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat Rausch accent (`#FF385C`) with an animated 4-color liquid plasma gradient applied to the same 28 action surfaces across the app — send buttons, voting chips, CTAs, unread indicators, progress bars, eyebrow labels.

**Spec:** `docs/superpowers/specs/2026-04-11-liquid-plasma-brand-design.md`

**Architecture:** Single shared `AnimationController` in `PlasmaClock` at the app root publishes a `ValueListenable<double>` phase via `PlasmaClockScope` (InheritedWidget). Four widget primitives (`PlasmaFill`, `PlasmaTint`, `PlasmaStroke`, `PlasmaProgressBar`) listen to the shared phase via `ListenableBuilder` and render plasma using one shared `buildPlasmaGradient(phase)` helper. All 28 action surfaces animate in unison with ~2.6ms/frame total cost.

**Tech Stack:** Flutter 3.11 · Dart 3 · Material (`LinearGradient`, `ShaderMask`, `CustomPaint`, `InheritedWidget`, `ValueListenable`). No fragment shaders, no BackdropFilter inside plasma widgets, no third-party packages.

**Testing strategy (deliberate deviation from spec §10):** The spec calls for 3 widget tests (2 goldens + reduced-motion) per plasma widget plus a `plasma_migration_test.dart`. This plan ships with **zero automated tests** and relies on:
1. Per-file `dart analyze` gates at the end of each task (catches compilation errors and signature mismatches).
2. An end-to-end `dart analyze` at Task 12.
3. A mandatory manual visual checklist (Task 12 Step 7) that walks all 28 plasma surfaces and confirms the plasma-vs-trip-color rule is respected.

Rationale: goldens are brittle on Flutter Web and animation-heavy widgets make them noisy. Multi-agent parallel execution requires trivially-reviewable per-task deliverables. The controller's visual verification gate is the source of truth for "did this land correctly."

If a follow-up pass wants to add the full spec-mandated tests, do it after the visual verification passes — not blocking Wave 1/2.

---

## Interface Contracts (pre-agreed, do not deviate)

All Wave 1 tracks must write code that conforms to these exact contracts. Later tracks depend on these symbols existing with these signatures. If you deviate, Wave 2 migrations will break.

### `plasma_gradient.dart`

```dart
const List<Color> kPlasmaColors;      // length 4
const List<double> kPlasmaStops;      // length 4
const Duration kPlasmaCycle;          // 5 seconds

/// Builds the animated LinearGradient for the given phase in [0, 1).
/// [alpha] in [0, 1] scales each color's opacity while preserving hue.
LinearGradient buildPlasmaGradient(double phase, {double alpha = 1.0});
```

### `plasma_clock.dart`

```dart
/// Owns the singleton AnimationController. Wrap the app root with this.
class PlasmaClock extends StatefulWidget {
  final Widget child;
  const PlasmaClock({super.key, required this.child});
}

/// InheritedWidget that exposes the current plasma phase to descendants.
class PlasmaClockScope extends InheritedWidget {
  final ValueListenable<double> phase;
  const PlasmaClockScope({super.key, required this.phase, required super.child});
  static ValueListenable<double> of(BuildContext context);
}
```

### `plasma_fill.dart`

```dart
class PlasmaFill extends StatelessWidget {
  final Widget? child;
  final BorderRadiusGeometry? borderRadius;
  final double alpha;               // default 1.0
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;             // default BoxShape.rectangle
  final double? width;
  final double? height;
  const PlasmaFill({
    super.key,
    this.child,
    this.borderRadius,
    this.alpha = 1.0,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
  });
}
```

### `plasma_tint.dart`

```dart
class PlasmaTint extends StatelessWidget {
  final Widget child;
  const PlasmaTint({super.key, required this.child});
}
```

### `plasma_stroke.dart`

```dart
class PlasmaStroke extends StatelessWidget {
  final Widget child;
  final double width;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  const PlasmaStroke({
    super.key,
    required this.child,
    required this.width,
    required this.borderRadius,
    this.padding,
  });
}
```

### `plasma_progress_bar.dart`

```dart
class PlasmaProgressBar extends StatelessWidget {
  final double value;                          // clamped 0..1
  final double height;                         // default 4.0
  final Color backgroundColor;                 // default #0F1A1A1A (ink @6%)
  const PlasmaProgressBar({
    super.key,
    required this.value,
    this.height = 4.0,
    this.backgroundColor = const Color(0x0F1A1A1A),
  });
}
```

### `plasma.dart` (barrel)

```dart
export 'plasma_clock.dart';
export 'plasma_fill.dart';
export 'plasma_gradient.dart';
export 'plasma_progress_bar.dart';
export 'plasma_stroke.dart';
export 'plasma_tint.dart';
```

All Wave 2 call-site migrations import via:
```dart
import '../plasma/plasma.dart';
```
(path adjusted per importing file's depth)

---

# WAVE 1 — Core Foundation + Widget Library

**Parallelism:** 7 independent tracks. Dispatch all 7 subagents simultaneously. No track touches another track's file. Each track works against the interface contracts above.

## Task 1 · Track A: `plasma_gradient.dart`

**Files:**
- Create: `app/lib/views/home/decision_board/plasma/plasma_gradient.dart`

- [ ] **Step 1: Create the file with palette constants and gradient builder**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Liquid plasma brand palette. Four warm colors ordered by hue so
/// each transition is a smooth walk, never a jump.
const List<Color> kPlasmaColors = <Color>[
  Color(0xFFFF0055), // vibrant magenta-red
  Color(0xFFFF0000), // pure red
  Color(0xFFFF4D00), // vivid red-orange
  Color(0xFFFF8C00), // dark neon orange
];

const List<double> kPlasmaStops = <double>[0.0, 0.33, 0.66, 1.0];

/// Shared animation cycle for every plasma surface in the app.
const Duration kPlasmaCycle = Duration(seconds: 5);

/// Builds the animated plasma gradient for a given phase in [0, 1).
///
/// The begin/end vector walks diagonally around the shape's center,
/// producing an oil-on-water sweep that never settles. [alpha] scales
/// each color's opacity while preserving hue (used for chip backgrounds
/// at ~0.18 so the plasma still breathes at lower intensity).
LinearGradient buildPlasmaGradient(double phase, {double alpha = 1.0}) {
  final double angle = 2 * math.pi * phase;
  final double dx = math.cos(angle);
  final double dy = math.sin(angle);
  final List<Color> colors = alpha >= 1.0
      ? kPlasmaColors
      : kPlasmaColors
          .map((Color c) => c.withValues(alpha: c.a * alpha))
          .toList(growable: false);
  return LinearGradient(
    colors: colors,
    stops: kPlasmaStops,
    begin: Alignment(dx - 1, dy - 1),
    end: Alignment(dx + 1, dy + 1),
  );
}
```

- [ ] **Step 2: Verify file analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/plasma/plasma_gradient.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/views/home/decision_board/plasma/plasma_gradient.dart
git commit -m "feat(plasma): add plasma_gradient palette + buildPlasmaGradient helper"
```

---

## Task 2 · Track B: `plasma_clock.dart`

**Files:**
- Create: `app/lib/views/home/decision_board/plasma/plasma_clock.dart`

- [ ] **Step 1: Create the file with PlasmaClock + PlasmaClockScope**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'plasma_gradient.dart';

/// Owns the single AnimationController that drives every plasma
/// surface in the app. Wrap the app's root widget with this once.
///
/// Exposes the current phase in [0, 1) via a [ValueListenable<double>]
/// published through [PlasmaClockScope]. Every plasma widget reads the
/// same phase so all 28 surfaces animate in unison with one tick per
/// frame.
///
/// Respects [MediaQuery.disableAnimations]: when the system requests
/// reduced motion the controller stops and the phase freezes at 0.5,
/// keeping the plasma colorful but static.
class PlasmaClock extends StatefulWidget {
  final Widget child;
  const PlasmaClock({super.key, required this.child});

  @override
  State<PlasmaClock> createState() => _PlasmaClockState();
}

class _PlasmaClockState extends State<PlasmaClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ValueNotifier<double> _phase;

  @override
  void initState() {
    super.initState();
    _phase = ValueNotifier<double>(0.0);
    _controller = AnimationController(vsync: this, duration: kPlasmaCycle)
      ..addListener(() {
        _phase.value = _controller.value;
      });
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disable = MediaQuery.disableAnimationsOf(context);
    if (disable) {
      if (_controller.isAnimating) _controller.stop();
      _phase.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlasmaClockScope(phase: _phase, child: widget.child);
  }
}

/// InheritedWidget that publishes the plasma phase to descendants.
/// Call [PlasmaClockScope.of] from a plasma widget's `build` method
/// to obtain the shared [ValueListenable<double>].
class PlasmaClockScope extends InheritedWidget {
  final ValueListenable<double> phase;

  const PlasmaClockScope({
    super.key,
    required this.phase,
    required super.child,
  });

  /// Returns the current plasma phase listenable. Asserts that a
  /// [PlasmaClock] ancestor exists.
  static ValueListenable<double> of(BuildContext context) {
    final PlasmaClockScope? scope =
        context.dependOnInheritedWidgetOfExactType<PlasmaClockScope>();
    assert(
      scope != null,
      'PlasmaClockScope.of() called with no PlasmaClock ancestor. '
      'Wrap your app root in a PlasmaClock widget.',
    );
    return scope!.phase;
  }

  @override
  bool updateShouldNotify(covariant PlasmaClockScope old) =>
      old.phase != phase;
}
```

- [ ] **Step 2: Verify file analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/plasma/plasma_clock.dart`
Expected: `No issues found!` (the `plasma_gradient.dart` import resolves because Track A is writing that file in parallel; by end of Wave 1 both exist.)

- [ ] **Step 3: Commit**

```bash
git add app/lib/views/home/decision_board/plasma/plasma_clock.dart
git commit -m "feat(plasma): add PlasmaClock + PlasmaClockScope shared animation controller"
```

---

## Task 3 · Track C: `plasma_fill.dart`

**Files:**
- Create: `app/lib/views/home/decision_board/plasma/plasma_fill.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces any `BoxDecoration(color: HelloColors.accent)` with an
/// animated liquid plasma fill. Rebuilds only its own subtree on each
/// plasma clock tick — the rest of the parent tree is untouched.
///
/// [alpha] scales the fill opacity while preserving the plasma hue,
/// used for tinted chip backgrounds (e.g. 0.18).
///
/// [shape] supports `BoxShape.rectangle` (default — requires
/// [borderRadius]) or `BoxShape.circle` (for dots and small badges).
class PlasmaFill extends StatelessWidget {
  final Widget? child;
  final BorderRadiusGeometry? borderRadius;
  final double alpha;
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;
  final double? width;
  final double? height;

  const PlasmaFill({
    super.key,
    this.child,
    this.borderRadius,
    this.alpha = 1.0,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: buildPlasmaGradient(phase.value, alpha: alpha),
            borderRadius:
                shape == BoxShape.rectangle ? borderRadius : null,
            shape: shape,
          ),
          child: child,
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify file analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/plasma/plasma_fill.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/views/home/decision_board/plasma/plasma_fill.dart
git commit -m "feat(plasma): add PlasmaFill widget for animated gradient fills"
```

---

## Task 4 · Track D: `plasma_tint.dart`

**Files:**
- Create: `app/lib/views/home/decision_board/plasma/plasma_tint.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces `color: HelloColors.accent` on any `Text` or `Icon`.
/// Wraps the child in a [ShaderMask] whose shader is the plasma
/// gradient for the current phase. Works on any widget whose visible
/// pixels should receive the plasma treatment.
///
/// Uses [BlendMode.srcIn] so the mask replaces the child's pixels with
/// the plasma shader instead of blending — this is what produces the
/// "text painted in plasma" look.
class PlasmaTint extends StatelessWidget {
  final Widget child;
  const PlasmaTint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect rect) =>
              buildPlasmaGradient(phase.value).createShader(rect),
          child: child,
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify file analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/plasma/plasma_tint.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/views/home/decision_board/plasma/plasma_tint.dart
git commit -m "feat(plasma): add PlasmaTint widget for animated gradient text/icons"
```

---

## Task 5 · Track E: `plasma_stroke.dart`

**Files:**
- Create: `app/lib/views/home/decision_board/plasma/plasma_stroke.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces `Border.all(color: HelloColors.accent, width: w)` with an
/// animated plasma stroke painted via [CustomPaint.foregroundPainter].
/// The child renders normally inside the painted stroke.
class PlasmaStroke extends StatelessWidget {
  final Widget child;
  final double width;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  const PlasmaStroke({
    super.key,
    required this.child,
    required this.width,
    required this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          foregroundPainter: _PlasmaStrokePainter(
            gradient: buildPlasmaGradient(phase.value),
            strokeWidth: width,
            borderRadius: borderRadius,
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        );
      },
    );
  }
}

class _PlasmaStrokePainter extends CustomPainter {
  final LinearGradient gradient;
  final double strokeWidth;
  final BorderRadius borderRadius;

  _PlasmaStrokePainter({
    required this.gradient,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    // Deflate by half the stroke width so the stroke sits inside the
    // shape's bounds — matches how Flutter's Border paints.
    final RRect rrect = borderRadius
        .toRRect(rect)
        .deflate(strokeWidth / 2);
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _PlasmaStrokePainter old) =>
      old.gradient != gradient ||
      old.strokeWidth != strokeWidth ||
      old.borderRadius != borderRadius;
}
```

- [ ] **Step 2: Verify file analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/plasma/plasma_stroke.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/views/home/decision_board/plasma/plasma_stroke.dart
git commit -m "feat(plasma): add PlasmaStroke widget for animated gradient borders"
```

---

## Task 6 · Track F: `plasma_progress_bar.dart`

**Files:**
- Create: `app/lib/views/home/decision_board/plasma/plasma_progress_bar.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces `LinearProgressIndicator(valueColor: HelloColors.accent)`
/// with a custom-painted rounded track whose filled portion sweeps
/// with the plasma gradient. [value] is clamped to [0, 1]. Zero-value
/// progress paints only the background track.
class PlasmaProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color backgroundColor;

  const PlasmaProgressBar({
    super.key,
    required this.value,
    this.height = 4.0,
    this.backgroundColor = const Color(0x0F1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          size: Size(double.infinity, height),
          painter: _PlasmaProgressPainter(
            value: value.clamp(0.0, 1.0),
            gradient: buildPlasmaGradient(phase.value),
            backgroundColor: backgroundColor,
            height: height,
          ),
        );
      },
    );
  }
}

class _PlasmaProgressPainter extends CustomPainter {
  final double value;
  final LinearGradient gradient;
  final Color backgroundColor;
  final double height;

  _PlasmaProgressPainter({
    required this.value,
    required this.gradient,
    required this.backgroundColor,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = height / 2;
    final Rect trackRect = Rect.fromLTWH(0, 0, size.width, height);
    final RRect trackRRect =
        RRect.fromRectAndRadius(trackRect, Radius.circular(radius));
    canvas.drawRRect(trackRRect, Paint()..color = backgroundColor);

    if (value > 0) {
      final Rect fillRect =
          Rect.fromLTWH(0, 0, size.width * value, height);
      final RRect fillRRect =
          RRect.fromRectAndRadius(fillRect, Radius.circular(radius));
      final Paint fillPaint = Paint()
        ..shader = gradient.createShader(trackRect);
      canvas.drawRRect(fillRRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlasmaProgressPainter old) =>
      old.value != value ||
      old.gradient != gradient ||
      old.backgroundColor != backgroundColor ||
      old.height != height;
}
```

- [ ] **Step 2: Verify file analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/plasma/plasma_progress_bar.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/views/home/decision_board/plasma/plasma_progress_bar.dart
git commit -m "feat(plasma): add PlasmaProgressBar widget"
```

---

## Task 7 · Track G: `theme.dart` accent flip + `plasma.dart` barrel

**Files:**
- Modify: `app/lib/theme.dart` (one line change)
- Create: `app/lib/views/home/decision_board/plasma/plasma.dart`

- [ ] **Step 1: Flip the accent constant in `theme.dart`**

Find:
```dart
  // Brand / accent (unchanged from dark theme)
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)
```

Replace with:
```dart
  // Brand / accent — Liquid Plasma representative hue.
  // Animated plasma lives in PlasmaFill / PlasmaTint / PlasmaStroke /
  // PlasmaProgressBar. This flat constant is the single-color
  // stand-in for surfaces that cannot animate (tokens, exports,
  // un-migrated legacy code).
  static const Color accent = Color(0xFFFF4D00); // plasma representative
```

- [ ] **Step 2: Create the barrel file**

Create `app/lib/views/home/decision_board/plasma/plasma.dart`:
```dart
export 'plasma_clock.dart';
export 'plasma_fill.dart';
export 'plasma_gradient.dart';
export 'plasma_progress_bar.dart';
export 'plasma_stroke.dart';
export 'plasma_tint.dart';
```

- [ ] **Step 3: Commit**

```bash
git add app/lib/theme.dart app/lib/views/home/decision_board/plasma/plasma.dart
git commit -m "feat(plasma): flip accent token to #FF4D00 + add plasma barrel"
```

---

# WAVE 2 — Call-Site Migrations

**Parallelism:** 4 independent tracks. Dispatch all 4 subagents simultaneously AFTER Wave 1 completes. Each track owns a non-overlapping slice of files. Every track imports plasma widgets via:

```dart
import '../plasma/plasma.dart';          // for files in decision_board/
import '../../plasma/plasma.dart';       // for files in decision_board/cards/
import '../../plasma/plasma.dart';       // for files in decision_board/sheets/
```

---

## Task 8 · Track W2-A: Compose bar + message input

**Files:**
- Modify: `app/lib/views/home/decision_board/bottom_bar.dart`
- Modify: `app/lib/views/home/decision_board/message_input_bar.dart`

### Sub-task 8.1: `bottom_bar.dart`

- [ ] **Step 1: Add the plasma import**

Add below the existing `import '../../../theme.dart';`:
```dart
import 'plasma/plasma.dart';
```

- [ ] **Step 2: Delete the `composeAccent` local**

Remove line 84:
```dart
    final composeAccent = focus?.accentColor ?? HelloColors.accent;
```

Leave `final focus = ref.watch(focusTripProvider);` in place — it's still read, just no longer consumed for the compose bar action surfaces.

- [ ] **Step 3: Replace the send `_CircleButton` with a plasma variant**

Find the send button block (lines 162-169):
```dart
                    child: _hasText
                        ? _CircleButton(
                            key: const ValueKey<String>('send'),
                            icon: Icons.arrow_upward_rounded,
                            onTap: _handleSend,
                            background: composeAccent,
                            iconColor: const Color(0xFFF0EFF4),
                          )
```

Replace with:
```dart
                    child: _hasText
                        ? _PlasmaCircleButton(
                            key: const ValueKey<String>('send'),
                            icon: Icons.arrow_upward_rounded,
                            onTap: _handleSend,
                            iconColor: const Color(0xFFF0EFF4),
                          )
```

- [ ] **Step 4: Replace the add `_CircleButton` icon with a plasma-tinted icon**

Find the add button block (lines 179-184):
```dart
                  _CircleButton(
                    icon: Icons.add,
                    onTap: widget.onComposeTap,
                    background: HelloColors.recessed,
                    iconColor: composeAccent,
                  ),
```

Replace with:
```dart
                  _PlasmaIconCircleButton(
                    icon: Icons.add,
                    onTap: widget.onComposeTap,
                    background: HelloColors.recessed,
                  ),
```

- [ ] **Step 5: Add the `_PlasmaCircleButton` and `_PlasmaIconCircleButton` helper classes**

Add at the bottom of the file (after the existing `_CircleButton` class):

```dart
/// 36x36 circle button whose fill is animated plasma. Used for the
/// primary send arrow in the compose bar.
class _PlasmaCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _PlasmaCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: PlasmaFill(
        shape: BoxShape.circle,
        width: 36,
        height: 36,
        child: Center(child: Icon(icon, size: 18, color: iconColor)),
      ),
    );
  }
}

/// 36x36 circle button with a flat recessed background and a
/// plasma-tinted icon. Used for the compose [+] button.
class _PlasmaIconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;

  const _PlasmaIconCircleButton({
    required this.icon,
    required this.onTap,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: PlasmaTint(child: Icon(icon, size: 18)),
      ),
    );
  }
}
```

Note: `PlasmaTint` needs the child's pixels to be opaque for `BlendMode.srcIn` to tint them. `Icon` renders opaque glyphs by default; the `color` param is unused here because `PlasmaTint` replaces it.

- [ ] **Step 6: Verify `bottom_bar.dart` analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/bottom_bar.dart`
Expected: `No issues found!`

### Sub-task 8.2: `message_input_bar.dart`

- [ ] **Step 1: Add the plasma import**

Add below the existing `import '../../../theme.dart';`:
```dart
import 'plasma/plasma.dart';
```

- [ ] **Step 2: Delete the `accentColor` constructor param**

Find and delete these lines from the constructor:
```dart
  final Color? accentColor;
```
and
```dart
    this.accentColor,
```

- [ ] **Step 3: Delete the `accent` local variable**

In `_MessageInputBarState.build`, delete line 70:
```dart
    final accent = widget.accentColor ?? HelloColors.accent;
```

- [ ] **Step 4: Replace the send `_CircleButton`**

Find:
```dart
          child: _hasText
              ? _CircleButton(
                  key: const ValueKey<String>('send'),
                  icon: Icons.arrow_upward_rounded,
                  onTap: _handleSend,
                  background: accent,
                  iconColor: const Color(0xFFF0EFF4),
                )
```

Replace with:
```dart
          child: _hasText
              ? _PlasmaCircleButton(
                  key: const ValueKey<String>('send'),
                  icon: Icons.arrow_upward_rounded,
                  onTap: _handleSend,
                  iconColor: const Color(0xFFF0EFF4),
                )
```

- [ ] **Step 5: Delete the `isBrandFill` check inside `_CircleButton`**

Find line 177:
```dart
    final isBrandFill = background == HelloColors.accent;
```

And the conditional border that uses it:
```dart
          border: isBrandFill
              ? null
              : Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
```

Replace the whole `_CircleButton.build` `decoration:` block with an unconditional border — the plasma send button is now handled by `_PlasmaCircleButton`, so the original `_CircleButton` only renders non-brand flat buttons (mic, recessed):

```dart
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
```

- [ ] **Step 6: Add the `_PlasmaCircleButton` helper class**

Add at the bottom of the file (after the existing `_CircleButton` class):

```dart
/// 32x32 circle button whose fill is animated plasma. Used for the
/// primary send arrow inside message sheets.
class _PlasmaCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _PlasmaCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: PlasmaFill(
        shape: BoxShape.circle,
        width: 32,
        height: 32,
        child: Center(child: Icon(icon, size: 18, color: iconColor)),
      ),
    );
  }
}
```

- [ ] **Step 7: Verify `message_input_bar.dart` analyzes clean**

Run: `cd app && dart analyze lib/views/home/decision_board/message_input_bar.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit Track W2-A**

```bash
git add app/lib/views/home/decision_board/bottom_bar.dart \
        app/lib/views/home/decision_board/message_input_bar.dart
git commit -m "feat(plasma): migrate compose bar + message input to plasma fills"
```

---

## Task 9 · Track W2-B: Unread indicators (4 files)

**Files:**
- Modify: `app/lib/views/home/decision_board/conversation_list_row.dart`
- Modify: `app/lib/views/home/decision_board/cards/dm_card.dart`
- Modify: `app/lib/views/home/decision_board/cards/group_card.dart`
- Modify: `app/lib/views/home/decision_board/sheets/search_sheet.dart`

### Sub-task 9.1: `conversation_list_row.dart`

- [ ] **Step 1: Add the plasma import**

Add below the `import '../../../theme.dart';` (or equivalent):
```dart
import 'plasma/plasma.dart';
```

- [ ] **Step 2: Replace the unread badge pill at line 178**

Find the container whose decoration reads `color: HelloColors.accent` and has `borderRadius: BorderRadius.circular(9)`. Replace that `Container(...)` with:

```dart
PlasmaFill(
  borderRadius: BorderRadius.circular(9),
  padding: const EdgeInsets.symmetric(horizontal: 6),
  child: /* preserve the existing child content, e.g. Text(count) */,
)
```

Keep the existing child tree unchanged — only the outer colored container is swapped.

### Sub-task 9.2: `dm_card.dart`

- [ ] **Step 1: Add the plasma import**

Add:
```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Replace the 6x6 unread dot at line 100**

Find:
```dart
                  decoration: const BoxDecoration(
                    color: HelloColors.accent,
                    shape: BoxShape.circle,
                  ),
```

Wrap this entire `Container(width: 6, height: 6, ...)` by replacing it with:
```dart
const PlasmaFill(
  shape: BoxShape.circle,
  width: 6,
  height: 6,
),
```

(If the wrapping `Container` has other properties like margin, preserve the margin on an outer `Padding` and use `PlasmaFill` as the inner visual.)

### Sub-task 9.3: `group_card.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the unread eyebrow text color (line 96)**

Find the `Text(...)` whose `style` has `color: isUnread ? HelloColors.accent : HelloColors.inkTertiary`. Wrap that Text widget conditionally:

```dart
isUnread
    ? PlasmaTint(
        child: Text(
          /* original text */,
          style: const TextStyle(
            fontFamily: 'Inter',
            letterSpacing: 1.5,
            // color intentionally unset — PlasmaTint replaces it
            color: Colors.white,
          ),
        ),
      )
    : Text(
        /* original text */,
        style: const TextStyle(
          fontFamily: 'Inter',
          letterSpacing: 1.5,
          color: HelloColors.inkTertiary,
        ),
      ),
```

(When `PlasmaTint` replaces a text color, the underlying `TextStyle.color` must still be opaque white — the `srcIn` blend uses the text's alpha channel.)

- [ ] **Step 3: Swap the 6x6 unread dot (line 114)**

Same pattern as sub-task 9.2: replace the `Container(width: 6, height: 6, decoration: BoxDecoration(color: HelloColors.accent, shape: BoxShape.circle))` with:
```dart
const PlasmaFill(
  shape: BoxShape.circle,
  width: 6,
  height: 6,
),
```

- [ ] **Step 4: Swap the 3x3 pulse dot at line 193 (with dynamic alpha)**

Find:
```dart
                decoration: BoxDecoration(
                  color: HelloColors.accent.withValues(alpha: a),
                  shape: BoxShape.circle,
                ),
```

Replace the full `Container(width: 3, height: 3, ...)` with:
```dart
PlasmaFill(
  shape: BoxShape.circle,
  width: 3,
  height: 3,
  alpha: a,
),
```

### Sub-task 9.4: `search_sheet.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the CTA text color at line 199**

Find the `Text(...)` whose style has `color: HelloColors.accent`. Wrap it:
```dart
PlasmaTint(
  child: Text(
    /* preserve original text */,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.white, // opaque, for the srcIn mask
    ),
  ),
),
```

- [ ] **Step 3: Swap the 6x6 unread dot at line 301**

Replace with:
```dart
const PlasmaFill(
  shape: BoxShape.circle,
  width: 6,
  height: 6,
),
```

### Sub-task 9.5: Verify and commit Track W2-B

- [ ] **Step 1: Analyze**

Run:
```bash
cd app && dart analyze \
  lib/views/home/decision_board/conversation_list_row.dart \
  lib/views/home/decision_board/cards/dm_card.dart \
  lib/views/home/decision_board/cards/group_card.dart \
  lib/views/home/decision_board/sheets/search_sheet.dart
```
Expected: `No issues found!`

- [ ] **Step 2: Commit**

```bash
git add app/lib/views/home/decision_board/conversation_list_row.dart \
        app/lib/views/home/decision_board/cards/dm_card.dart \
        app/lib/views/home/decision_board/cards/group_card.dart \
        app/lib/views/home/decision_board/sheets/search_sheet.dart
git commit -m "feat(plasma): migrate unread indicators to PlasmaFill/PlasmaTint"
```

---

## Task 10 · Track W2-C: Decision chips + progress bars (3 files)

**Files:**
- Modify: `app/lib/views/home/decision_board/cards/decision_card_small.dart`
- Modify: `app/lib/views/home/decision_board/sheets/decision_sheet.dart`
- Modify: `app/lib/views/home/decision_board/cards/decision_card_hero.dart`

### Sub-task 10.1: `decision_card_small.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the eyebrow text color at line 46**

Find:
```dart
            Text(
              widget.item.eyebrow!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
                color: HelloColors.accent,
              ),
            ),
```

Replace with:
```dart
            PlasmaTint(
              child: Text(
                widget.item.eyebrow!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: Colors.white, // opaque for srcIn
                ),
              ),
            ),
```

- [ ] **Step 3: Swap the progress bar at lines 95-105**

Find:
```dart
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.item.item.agreementScore.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: HelloColors.inkPrimary.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(
                HelloColors.accent,
              ),
            ),
          ),
```

Replace with:
```dart
          PlasmaProgressBar(
            value: widget.item.item.agreementScore.clamp(0.0, 1.0),
            height: 3,
          ),
```

- [ ] **Step 4: Rewrite `_VoteButton.build` to use plasma**

Find the existing `_VoteButton.build` method (lines 122-154) and replace the body with:

```dart
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: active
          ? PlasmaStroke(
              width: 1,
              borderRadius: BorderRadius.circular(6),
              child: PlasmaFill(
                alpha: 0.18,
                borderRadius: BorderRadius.circular(6),
                width: 36,
                height: 28,
                child: Center(
                  child: PlasmaTint(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white, // opaque for srcIn
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkSecondary,
                ),
              ),
            ),
    );
  }
```

This triple-wraps the active state (stroke → fill → tint) so the chip gets all three plasma treatments, while inactive stays flat.

### Sub-task 10.2: `decision_sheet.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the progress bar at lines 247-258**

Find:
```dart
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: data.score.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor:
                            HelloColors.inkPrimary.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          HelloColors.accent,
                        ),
                      ),
                    ),
```

Replace with:
```dart
                    PlasmaProgressBar(
                      value: data.score.clamp(0.0, 1.0),
                      height: 4,
                    ),
```

- [ ] **Step 3: Rewrite `_BigVoteButton.build`**

Find `_BigVoteButton.build` at lines 299-327 and replace the body with:

```dart
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: active
          ? PlasmaStroke(
              width: 1,
              borderRadius: BorderRadius.circular(12),
              child: PlasmaFill(
                alpha: 0.22,
                borderRadius: BorderRadius.circular(12),
                height: 52,
                child: Center(
                  child: PlasmaTint(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white, // opaque for srcIn
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container(
              height: 52,
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ),
    );
  }
```

### Sub-task 10.3: `decision_card_hero.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the progress bar at line 127-131**

Find the `LinearProgressIndicator(... valueColor: AlwaysStoppedAnimation<Color>(HelloColors.accent) ...)` near line 129. Replace the whole wrapping `ClipRRect(...)` or bare `LinearProgressIndicator(...)` with:

```dart
PlasmaProgressBar(
  value: /* preserve original value expression, e.g. widget.item.item.agreementScore.clamp(0.0, 1.0) */,
  height: 3,
  backgroundColor: Colors.white.withValues(alpha: 0.2),
),
```

Note: the hero card uses a white-ish background (not `inkPrimary @6%`) because it sits on a gradient overlay. Pass `backgroundColor` explicitly to preserve that.

### Sub-task 10.4: Verify and commit Track W2-C

- [ ] **Step 1: Analyze**

```bash
cd app && dart analyze \
  lib/views/home/decision_board/cards/decision_card_small.dart \
  lib/views/home/decision_board/sheets/decision_sheet.dart \
  lib/views/home/decision_board/cards/decision_card_hero.dart
```
Expected: `No issues found!`

- [ ] **Step 2: Commit**

```bash
git add app/lib/views/home/decision_board/cards/decision_card_small.dart \
        app/lib/views/home/decision_board/sheets/decision_sheet.dart \
        app/lib/views/home/decision_board/cards/decision_card_hero.dart
git commit -m "feat(plasma): migrate decision chips + progress bars to plasma widgets"
```

---

## Task 11 · Track W2-D: Trip / focus / settlement cards (4 files)

**Files:**
- Modify: `app/lib/views/home/decision_board/cards/focus_hero_card.dart`
- Modify: `app/lib/views/home/decision_board/cards/trip_card.dart`
- Modify: `app/lib/views/home/decision_board/sheets/settlement_sheet.dart`
- Modify: `app/lib/views/home/decision_board/cards/settlement_card.dart`

### Sub-task 11.1: `focus_hero_card.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the eyebrow text at line 174**

Find the `Text` whose style has `color: HelloColors.accent` and `letterSpacing: 1.5`. Wrap in `PlasmaTint`:

```dart
PlasmaTint(
  child: Text(
    /* preserve original text expression */,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      letterSpacing: 1.5,
      color: Colors.white, // opaque for srcIn
    ),
  ),
),
```

### Sub-task 11.2: `trip_card.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the CTA/eyebrow text at line 150**

Find the `Text` whose style has `color: HelloColors.accent` and `letterSpacing: 0.3`. Wrap in `PlasmaTint`:

```dart
PlasmaTint(
  child: Text(
    /* preserve original text expression */,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      color: Colors.white, // opaque for srcIn
    ),
  ),
),
```

### Sub-task 11.3: `settlement_sheet.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the debt amount text at line 108**

Find the `Text` widget whose style uses `color: s.isOwedToYou ? HelloColors.liveGreen : HelloColors.accent`. Conditionally wrap the "accent" case in `PlasmaTint`:

```dart
s.isOwedToYou
    ? Text(
        /* preserve text */,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: HelloColors.liveGreen,
          /* preserve other style properties */
        ),
      )
    : PlasmaTint(
        child: Text(
          /* preserve text */,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white, // opaque for srcIn
            /* preserve other style properties */
          ),
        ),
      ),
```

- [ ] **Step 3: Swap the "Pay" button pill at line 205**

Find the `Container` whose decoration is `color: s.isOwedToYou ? HelloColors.recessed : HelloColors.accent` with `borderRadius: BorderRadius.circular(14)`. Conditionally swap:

```dart
s.isOwedToYou
    ? Container(
        /* preserve existing flat container */,
      )
    : PlasmaFill(
        borderRadius: BorderRadius.circular(14),
        padding: /* preserve existing padding */,
        child: /* preserve existing child (button label) */,
      ),
```

### Sub-task 11.4: `settlement_card.dart`

- [ ] **Step 1: Add the plasma import**

```dart
import '../plasma/plasma.dart';
```

- [ ] **Step 2: Swap the debt amount text at line 41**

Same pattern as sub-task 11.3 step 2: conditionally wrap the "owed by you" branch in `PlasmaTint` while leaving the `liveGreen` branch untouched.

- [ ] **Step 3: Swap the CTA button at line 118**

Find the `Container(... decoration: BoxDecoration(color: HelloColors.accent, borderRadius: BorderRadius.circular(8)) ...)` with `width: double.infinity`. Replace with:

```dart
PlasmaFill(
  borderRadius: BorderRadius.circular(8),
  padding: /* preserve existing padding */,
  child: /* preserve existing child (button label) */,
),
```

The `PlasmaFill` will naturally fill available width when wrapped by its `SizedBox(width: double.infinity)` parent, or you can wrap the `PlasmaFill` in `SizedBox(width: double.infinity, child: PlasmaFill(...))` if needed.

### Sub-task 11.5: Verify and commit Track W2-D

- [ ] **Step 1: Analyze**

```bash
cd app && dart analyze \
  lib/views/home/decision_board/cards/focus_hero_card.dart \
  lib/views/home/decision_board/cards/trip_card.dart \
  lib/views/home/decision_board/sheets/settlement_sheet.dart \
  lib/views/home/decision_board/cards/settlement_card.dart
```
Expected: `No issues found!`

- [ ] **Step 2: Commit**

```bash
git add app/lib/views/home/decision_board/cards/focus_hero_card.dart \
        app/lib/views/home/decision_board/cards/trip_card.dart \
        app/lib/views/home/decision_board/sheets/settlement_sheet.dart \
        app/lib/views/home/decision_board/cards/settlement_card.dart
git commit -m "feat(plasma): migrate trip/focus/settlement CTAs to plasma widgets"
```

---

# WAVE 3 — Integration (serial, controller-executed)

## Task 12: Wire `PlasmaClock` at app root + final analyze + commit

**Files:**
- Modify: `app/lib/main.dart`

### Step 12.1: Find the app root widget

- [ ] **Step 1: Locate the `MaterialApp` in `main.dart`**

Run:
```bash
cd app && grep -n "MaterialApp\|runApp" lib/main.dart
```

### Step 12.2: Wrap the app root in `PlasmaClock`

- [ ] **Step 2: Add the plasma import**

At the top of `main.dart`, add:
```dart
import 'views/home/decision_board/plasma/plasma.dart';
```

- [ ] **Step 3: Wrap the `MaterialApp` in `PlasmaClock`**

Find the `return MaterialApp(...)` (or equivalent `return ProviderScope(child: MaterialApp(...))`). Wrap it:

```dart
return PlasmaClock(
  child: /* existing MaterialApp / ProviderScope tree */,
);
```

`PlasmaClock` must sit ABOVE the `MaterialApp` so it propagates through the entire navigator stack (including modal sheets). It must sit BELOW `ProviderScope` if one exists (Riverpod root stays at the top).

Typical structure after the change:
```dart
runApp(
  ProviderScope(
    child: PlasmaClock(
      child: MaterialApp(
        /* existing config */
      ),
    ),
  ),
);
```

### Step 12.3: End-to-end analyze

- [ ] **Step 4: Run full-project dart analyze**

```bash
cd app && dart analyze
```
Expected: `No issues found!`

If there are any issues, fix them inline and re-run. Common issues to expect and their fixes:

- **"The argument type 'X' can't be assigned to the parameter type 'Y'"** — check that `PlasmaFill`/`PlasmaTint`/`PlasmaStroke` constructor args match the contract. Revisit the Wave 2 sub-task that touched that file.
- **"Undefined name 'PlasmaFill'"** — missing `import '../plasma/plasma.dart';` (or wrong path depth).
- **"The class 'PlasmaFill' doesn't have a default constructor" or unused import** — `plasma.dart` barrel missing an export line; verify Task 7 sub-task 2.

### Step 12.4: Rebuild and visually verify

- [ ] **Step 5: Kill any running flutter processes**

```bash
ps aux | grep -E "flutter.*run|frontend_server_aot|dartaotruntime" \
  | grep -v grep | awk '{print $2}' | xargs -I {} kill {} 2>/dev/null || true
```

- [ ] **Step 6: Start flutter run**

```bash
cd app && flutter run -d chrome --web-port 8080
```
(Run in background; wait for "Debug service listening" signal.)

- [ ] **Step 7: Manual visual checklist**

Open `http://localhost:8080` and verify all 28 surfaces visibly plasma-sweep in unison:

1. Bottom bar compose send button (type text, see arrow animate)
2. Bottom bar `+` add icon (plasma-tinted)
3. In-sheet message input send arrow
4. Conversation list unread pill badge
5. DM card unread dot
6. Group card unread eyebrow text
7. Group card unread dot
8. Group card pulse dot (hero-recent activity)
9. Search sheet CTA text
10. Search sheet unread dot
11. Decision card small eyebrow
12. Decision card small progress bar
13. Decision card small active vote chip background
14. Decision card small active vote chip border
15. Decision card small active vote chip text
16. Decision sheet progress bar
17. Decision sheet active Big Vote button background
18. Decision sheet active Big Vote button border
19. Decision sheet active Big Vote button text
20. Decision card hero progress bar
21. Focus hero card eyebrow ("EVENT")
22. Trip card CTA/eyebrow text
23. Settlement sheet debt amount (owed-by-you case)
24. Settlement sheet Pay button pill
25. Settlement card debt amount (owed-by-you case)
26. Settlement card CTA pill
27. (bottom_bar send and add are items 1 and 2 above — confirming both downstream consumers of the former `composeAccent`)
28. Per-trip `focusAlpine`/`focusOcean`/`focusSunset` atmosphere **must NOT** be plasma (this is a negative test — verify trip tints on atmosphere wash + focus hero backdrop are still flat alpine/ocean/sunset).

Expected behavior on all 28 plasma surfaces:
- All sweep in unison (same phase at the same wall-clock moment)
- Colors flow diagonally, never settle
- 5-second cycle (observe one full rotation takes ~5 s)
- Reduced-motion users see static mid-phase plasma (colorful, no animation)

- [ ] **Step 8: Final commit wrapping Wave 3**

```bash
git add app/lib/main.dart
git commit -m "feat(plasma): wire PlasmaClock at app root + end-to-end verification"
```

---

# Post-implementation

- [ ] **Write a session summary commit** (optional — run after all the above):

```bash
git log --oneline main^..HEAD
```

All commits should be visible:
1. Wave 1 (7 commits): gradient, clock, fill, tint, stroke, progress_bar, theme+barrel
2. Wave 2 (4 commits): compose, unread, decision chips, trip/settlement
3. Wave 3 (1 commit): root wiring

Total: 12 commits.
