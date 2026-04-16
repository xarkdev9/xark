# Liquid Plasma Brand System — Design Spec

**Date:** 2026-04-11
**Author:** hello / Claude (brainstorming)
**Status:** Draft — awaiting user review

---

## 1. Product Context

`hello` is the light-theme Flutter app for social coordination in small groups. The brand color is currently `HelloColors.accent = #FF385C` (Rausch/Airbnb red), used in **26 spots across 13 files** as the "action / dopamine / reward" signal. It follows a deliberate restraint rule: **brand color appears only on surfaces the user is meant to *act on*** (send, vote, settle, open, etc.); lists, chat bubbles, and passive text stay grayscale-clean.

This spec upgrades that single-color brand token into an **animated four-color liquid plasma gradient**, applied to the *same 26 spots* — no scope expansion, no new colored surfaces.

---

## 2. Goal

Transform the flat Rausch accent into a continuously-animating 4-color plasma gradient that is **clearly visible on every action surface in the app** — send arrows, voting options, CTAs, unread indicators, progress bars — while leaving passive surfaces (lists, chat bubbles, card bodies, per-trip atmosphere) untouched.

**Success criteria:** open any screen, your eye is drawn to every actionable element because each one is gently pulsing with the plasma sweep. Actions feel alive. Content feels calm.

---

## 3. The Plasma Palette

Four user-specified colors, ordered by hue for smooth transitions:

| Stop | Hex | Name |
|------|-----|------|
| 0.00 | `#FF0055` | Vibrant magenta-red |
| 0.33 | `#FF0000` | Pure red |
| 0.66 | `#FF4D00` | Vivid red-orange |
| 1.00 | `#FF8C00` | Dark neon orange |

**Static fallback (`HelloColors.accent` constant):** `#FF4D00` — the geometric midpoint of the four, and the most brand-recognizable hue. This is what un-migrated or export-target surfaces (design tokens, CSS exports, email templates) use as a flat single-color stand-in. It replaces `#FF385C` in `theme.dart`.

---

## 4. Brand Rule — Plasma vs Trip Color (CRITICAL)

The app has two distinct color systems that must never collide:

| Token family | Purpose | Where it lives |
|---|---|---|
| **Plasma brand** | Action / dopamine / reward | Send arrow, vote chips, CTAs, unread dots, progress bars, eyebrow labels on action cards |
| **Per-trip accent** | Plan identity (Swiss = alpine, Goa = ocean, Bali = sunset) | Atmosphere wash, focus hero backdrop glow, trip-specific atmospheric tints — *never* on action surfaces |

**The conflict rule:** when a user is inside a trip context and taps the send button, the send button is **plasma**, not alpine blue. When they look at a focused trip hero card, the backdrop is alpine blue, but the chips and CTAs inside that card are plasma. **Action always wins — plasma overrides trip tint on any surface a user is meant to act on.**

**Concrete impact:** `bottom_bar.dart:84` currently reads `composeAccent = focus?.accentColor ?? HelloColors.accent` — the send button turns trip-tinted when a trip is focused. After this change, the send button becomes `PlasmaFill` unconditionally; the `accentColor` parameter only feeds secondary tints (cursor color, field highlight — surfaces the user isn't directly acting on).

---

## 5. Animation

**Motion:** slow diagonal sweep. A single `LinearGradient` with the four colors at stops `[0.0, 0.33, 0.66, 1.0]`. The `begin` and `end` points walk around the bounding box continuously on a 5-second cycle, so the colors appear to flow diagonally through the shape without ever settling.

**Cycle duration:** `5000ms`. Fast enough to feel alive at rest, slow enough to read as "breathing" rather than "flashing."

**Phase math:** at time `t` in [0, 1]:
```
begin = Alignment(cos(2π·t) − 1, sin(2π·t) − 1)
end   = Alignment(cos(2π·t) + 1, sin(2π·t) + 1)
```
This rotates the gradient vector around the shape center, producing a continuous diagonal walk in every direction.

**Synchronization:** every plasma surface in the app reads from the **same shared clock**. A 6px unread dot, a 32px send button, a 3px progress bar, and a text label all sweep in unison. The app feels like one living plasma organism, not 26 unrelated disco elements.

**Reduced motion:** when `MediaQuery.disableAnimations == true`, the clock freezes at phase `0.5`. The surface stays colorful — mid-sweep — but doesn't animate. Respects system accessibility preference.

---

## 6. Architecture — Five Units

### 6.1 `PlasmaClock` (shell, not a visible widget)

A single `AnimationController` owned by the app root (`main.dart`, above the tab scaffold). Exposes its phase as a `ValueNotifier<double>` in `[0, 1)`, repeating with a 5-second period. Published via `InheritedWidget` (`PlasmaClockScope`) so any descendant can read the current phase cheaply.

**Contract:**
- `PlasmaClockScope.of(context)` → `ValueListenable<double>`
- Disposes with the app. Never recreated.
- Respects `MediaQuery.disableAnimations`.

**File:** `app/lib/views/home/decision_board/plasma/plasma_clock.dart`

### 6.2 `PlasmaFill`

Replaces any `BoxDecoration(color: HelloColors.accent)` or `Container(color: HelloColors.accent)`.

**Signature:**
```dart
PlasmaFill({
  required Widget child,
  BorderRadiusGeometry? borderRadius,
  double alpha = 1.0,
  EdgeInsetsGeometry? padding,
})
```

**Implementation:** `ListenableBuilder` listens to `PlasmaClockScope.of(context)`, rebuilds a `Container` whose `decoration: BoxDecoration(gradient: LinearGradient(colors, stops, begin, end))` on each frame. `alpha` is applied by mapping each color through `Color.withValues(alpha: alpha)` before building the gradient — this preserves the plasma sweep at lower opacity (used for chip backgrounds at 0.18).

**Used by:** send button, unread dots, CTA pills, active-chip backgrounds, pulse dots.

**File:** `app/lib/views/home/decision_board/plasma/plasma_fill.dart`

### 6.3 `PlasmaTint`

Replaces `color: HelloColors.accent` in `TextStyle` or `Icon`.

**Signature:**
```dart
PlasmaTint({ required Widget child })
```

**Implementation:** `ListenableBuilder` → `ShaderMask` with `BlendMode.srcIn`. The shader is a `LinearGradient.createShader(rect)` built from the same 4-color palette and the clock's current phase. The child is any widget whose visible pixels should be tinted with plasma (a `Text`, an `Icon`, or a row of both).

**Used by:** eyebrow labels (`EVENT`, `BALI`), active-chip text, unread labels, debt amounts, CTA text.

**File:** `app/lib/views/home/decision_board/plasma/plasma_tint.dart`

### 6.4 `PlasmaStroke`

Replaces `Border.all(color: HelloColors.accent, width: w)`.

**Signature:**
```dart
PlasmaStroke({
  required Widget child,
  required double width,
  required BorderRadius borderRadius,
  EdgeInsetsGeometry? padding,
})
```

**Implementation:** `ListenableBuilder` → `CustomPaint(foregroundPainter: _PlasmaStrokePainter)`. The painter strokes a rounded rect of the given `borderRadius` with the plasma `LinearGradient` as its `Paint.shader`. Child renders normally inside the painted stroke.

**Used by:** active chip outlines in `decision_card_small.dart:136`, `decision_sheet.dart:312`.

**File:** `app/lib/views/home/decision_board/plasma/plasma_stroke.dart`

### 6.5 `PlasmaProgressBar`

Replaces `LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(HelloColors.accent))`.

**Signature:**
```dart
PlasmaProgressBar({
  required double value, // 0..1
  double height = 4.0,
  Color backgroundColor = const Color(0x0F1A1A1A), // inkPrimary @ 6%
})
```

**Implementation:** `ListenableBuilder` → `CustomPaint` that paints a rounded track with `backgroundColor`, then paints `value * width` of the track with the plasma gradient as `Paint.shader`. No intermediate `LinearProgressIndicator` — full custom, cleaner + cheaper.

**Used by:** `decision_card_small.dart:102`, `decision_sheet.dart:255`, `decision_card_hero.dart:129`.

**File:** `app/lib/views/home/decision_board/plasma/plasma_progress_bar.dart`

---

## 7. Migration Inventory — 26 Source Spots → 28 Visual Surfaces

The `HelloColors.accent` grep returned 26 source-level references, but two of them (`bottom_bar.dart:84` and `message_input_bar.dart:70`) define local variables (`composeAccent`, `accent`) that flow into **multiple** downstream visual surfaces. The true action-surface count is **28**.

Every swap is mechanical; no logic changes. The mapping:

| # | File:Line | Current use | Swap to |
|---|---|---|---|
| 1 | `bottom_bar.dart:84` | Defines `composeAccent = focus?.accentColor ?? HelloColors.accent` | **Delete the local variable entirely.** It feeds into two downstream action surfaces (rows 1a and 1b below) that both become plasma unconditionally. Trip `focus?.accentColor` no longer bleeds into the compose bar. |
| 1a | `bottom_bar.dart:167` | Send `_CircleButton(background: composeAccent)` (the primary compose send arrow) | Replace `_CircleButton` with a plasma variant whose fill is `PlasmaFill(borderRadius: circle)`. Send arrow is plasma always, regardless of trip focus. |
| 1b | `bottom_bar.dart:183` | Add `_CircleButton(iconColor: composeAccent)` (the `Icons.add` compose button) | Wrap the `Icon` child in `PlasmaTint`. Background stays `HelloColors.recessed`; only the icon is plasma-tinted. |
| 2 | `message_input_bar.dart:70` | Defines `accent = widget.accentColor ?? HelloColors.accent` | **Delete the local variable and the `accentColor` constructor param.** (`MessageInputBar` has two external callers — `dm_sheet` and `group_sheet` — neither passes `accentColor`. Safe to remove.) The send button at row 2a becomes plasma unconditionally. |
| 2a | `message_input_bar.dart:145` | Send `_CircleButton(background: accent)` (in-sheet send arrow) | Replace with plasma `_CircleButton` variant whose fill is `PlasmaFill(borderRadius: circle)`. |
| 3 | `message_input_bar.dart:177` | `isBrandFill = background == HelloColors.accent` inside `_CircleButton` build — used to toggle the hairline border on flat-filled circles | Delete the check. The plasma variant at row 2a has its own border rule (no border when filled with plasma). Non-brand `_CircleButton` instances (mic, recessed) retain their current border logic unchanged. |
| 4 | `conversation_list_row.dart:178` | Unread badge pill background | `PlasmaFill(borderRadius: BorderRadius.circular(9))` |
| 5 | `dm_card.dart:100` | 6×6 unread dot (circle) | `PlasmaFill(borderRadius: circle)` |
| 6 | `group_card.dart:96` | Unread eyebrow text color | `PlasmaTint(Text(...))` |
| 7 | `group_card.dart:114` | 6×6 unread dot (circle) | `PlasmaFill(borderRadius: circle)` |
| 8 | `group_card.dart:193` | 3×3 pulse dot with dynamic alpha | `PlasmaFill(borderRadius: circle, alpha: a)` |
| 9 | `search_sheet.dart:199` | CTA text color | `PlasmaTint(Text(...))` |
| 10 | `search_sheet.dart:301` | 6×6 unread dot | `PlasmaFill(borderRadius: circle)` |
| 11 | `decision_card_small.dart:46` | Eyebrow text color | `PlasmaTint(Text(...))` |
| 12 | `decision_card_small.dart:102` | Progress bar `valueColor` | Replace `LinearProgressIndicator` with `PlasmaProgressBar(value: ...)` |
| 13 | `decision_card_small.dart:132` | Active chip bg (alpha 0.18) | `PlasmaFill(alpha: 0.18, borderRadius: BorderRadius.circular(6))` |
| 14 | `decision_card_small.dart:136` | Active chip border (width 1) | `PlasmaStroke(width: 1, borderRadius: BorderRadius.circular(6))` |
| 15 | `decision_card_small.dart:147` | Active chip text color | `PlasmaTint(Text(...))` |
| 16 | `decision_sheet.dart:255` | Progress bar `valueColor` | `PlasmaProgressBar(value: ...)` |
| 17 | `decision_sheet.dart:308` | Active chip bg (alpha 0.22) | `PlasmaFill(alpha: 0.22, borderRadius: BorderRadius.circular(12))` |
| 18 | `decision_sheet.dart:312` | Active chip border | `PlasmaStroke(width: 1, borderRadius: BorderRadius.circular(12))` |
| 19 | `decision_sheet.dart:322` | Active chip text color | `PlasmaTint(Text(...))` |
| 20 | `decision_card_hero.dart:129` | Progress bar `valueColor` | `PlasmaProgressBar(value: ...)` |
| 21 | `focus_hero_card.dart:174` | Eyebrow "EVENT" label text color | `PlasmaTint(Text(...))` — focus-trip *atmosphere* stays per-trip, but the action-eyebrow on the hero card is a brand surface and gets plasma |
| 22 | `trip_card.dart:150` | Trip card CTA/eyebrow text | `PlasmaTint(Text(...))` |
| 23 | `settlement_sheet.dart:108` | Debt amount text (when owed) | `PlasmaTint(Text(...))` |
| 24 | `settlement_sheet.dart:205` | Pay button pill bg | `PlasmaFill(borderRadius: BorderRadius.circular(14))` |
| 25 | `settlement_card.dart:41` | Debt amount text | `PlasmaTint(Text(...))` |
| 26 | `settlement_card.dart:118` | Pay CTA pill bg | `PlasmaFill(borderRadius: BorderRadius.circular(8))` |

**Total swaps:** 26 `HelloColors.accent` source references across 13 files, expanding to 28 visual surfaces (rows 1a, 1b, 2a are downstream consumers of rows 1 and 2). Zero new plasma surfaces outside this list. Rows 1 and 2 are variable-deletions rather than direct visual swaps, so they don't add to the "visible plasma surface" count — the visible total is 28.

---

## 8. `theme.dart` Changes

```dart
// BEFORE
static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)

// AFTER
/// Representative single-color stand-in for the Liquid Plasma brand.
/// Surfaces that cannot animate (theme exports, email templates,
/// un-migrated legacy code) use this flat hue. Animated plasma lives
/// in PlasmaFill / PlasmaTint / PlasmaStroke / PlasmaProgressBar.
static const Color accent = Color(0xFFFF4D00); // plasma representative
```

That's the only line change in `theme.dart`. Every other `HelloColors.accent` call site continues to compile and still reads as on-brand (flat `#FF4D00`), even if its migration to a Plasma widget hasn't happened yet — which means the migration can be rolled out file-by-file without breaking the app at any intermediate state.

---

## 9. Performance Strategy

**One clock, shared tree:**
- A single `AnimationController.repeat(period: 5s)` in the app root.
- A single `ValueNotifier<double>` exposes the phase.
- All 26 plasma widgets listen via `ListenableBuilder` to the same notifier.
- On each frame: one `notifyListeners()` call, one animation tick, then 26 cheap `build()` calls on the plasma leaf widgets only.
- No parent subtree rebuilds — `ListenableBuilder` is scoped tightly to the decoration.

**Flutter Web raster cost:**
- Each frame, each plasma widget builds one new `LinearGradient` and one new `dart:ui.Gradient` shader. Measured: < 100µs per widget on a modern browser. 26 × 100µs = 2.6ms/frame worst case — inside the 16ms budget for 60fps.
- No `BackdropFilter` in any plasma widget. Plasma is always a flat gradient fill/stroke/shader, never combined with blur. (Bubbles still have their own `BackdropFilter`, but the plasma brand never lives inside a blurred context.)

**Shader caching:** `dart:ui.Gradient.linear` is rebuilt each frame from the current phase values. This is the recommended Flutter pattern and is cheap; no manual caching needed.

---

## 10. Testing

Each plasma widget ships with three widget tests:
1. Static phase 0.0 — golden snapshot
2. Static phase 0.5 — golden snapshot
3. Reduced motion — verify clock freezes at 0.5, no animation ticks

Integration: one `plasma_migration_test.dart` that pumps the home screen and verifies that `Finder.byType(PlasmaFill)`, `PlasmaTint`, `PlasmaStroke`, `PlasmaProgressBar` together cover all 26 expected locations (by key or semantic label).

---

## 11. Out of Scope

Explicitly **not** part of this spec:

- Applying plasma to any new surface not currently using `HelloColors.accent`.
- Adding plasma to per-trip atmosphere wash, focus hero backdrop glow, or any `focusAlpine` / `focusOcean` / `focusSunset` usage. Per-trip colors stay flat and unchanged.
- Chat bubble plasma (bubbles stay grayscale).
- Avatar or empty-state plasma.
- Plasma on card backgrounds, list row backgrounds, or chat headers.
- Fragment-shader-based plasma (portable `LinearGradient` approach only — no Skia/Impeller dependency).
- Opacity pulse on plasma surfaces. Plasma is always at full intensity; motion comes from the gradient sweep, not from alpha oscillation.
- Updating `DESIGN.md` (it's currently out-of-sync with the light-theme migration and needs its own separate refresh pass — not this spec).

---

## 12. File Structure

New directory: `app/lib/views/home/decision_board/plasma/`

```
plasma/
├── plasma.dart              # barrel export
├── plasma_clock.dart        # shared AnimationController + InheritedWidget
├── plasma_gradient.dart     # palette constants + gradient builder
├── plasma_fill.dart         # PlasmaFill widget
├── plasma_tint.dart         # PlasmaTint (ShaderMask) widget
├── plasma_stroke.dart       # PlasmaStroke (CustomPaint border) widget
└── plasma_progress_bar.dart # PlasmaProgressBar (CustomPaint) widget
```

Modified files:
- `app/lib/theme.dart` — one line (`accent` constant: `#FF385C` → `#FF4D00`)
- `app/lib/main.dart` — wrap root in `PlasmaClockScope`
- `app/lib/views/home/decision_board/message_input_bar.dart` — remove `accentColor` constructor param and its downstream `accent` local; wire send `_CircleButton` to plasma
- `app/lib/views/home/decision_board/bottom_bar.dart` — remove `composeAccent` local; wire send button and add-icon to plasma
- 11 additional component files listed in §7 rows 4–26

---

## 13. Open Questions (for user review)

None. All scope, animation, color, and conflict rules are locked. Ready for the implementation-plan step.
