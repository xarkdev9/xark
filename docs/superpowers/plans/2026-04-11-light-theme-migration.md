# Light Theme Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`

**Goal:** Replace the dark theme with the archived light theme across every widget on the home surface, per `docs/superpowers/specs/2026-04-11-light-theme-migration-design.md`.

**Architecture:** Token flip in `theme.dart` handles most widgets automatically. Parallel tracks flip the remaining hardcoded `Colors.white`/`Color(0xFF…)` references in CardShell, atmosphere, hero cards, chrome widgets, and sheets. A new `ChatBubble` widget is ported verbatim from the archive. All 7 sheets get a `Material(type: MaterialType.transparency)` ancestor to fix the "No Material widget" error.

**Tech stack:** Flutter, Riverpod 3.x, no new dependencies.

---

## Wave 1 — 7 parallel tracks

### Track 1: Theme tokens + atmosphere rewrite

**Files:**
- Modify `app/lib/theme.dart`
- Rewrite `app/lib/views/home/decision_board/atmosphere.dart`

#### Task 1.1: theme.dart token flip

Read the existing file first. Replace the `HelloColors` class body entirely with these values (keeping the class name + class structure):

```dart
class HelloColors {
  // Light theme — archived ui_backup_2026-04-10/flutter/theme.dart
  static const Color voidBg = Color(0xFFFAFAFA); // off-white base
  static const Color surfaceDeep = Color(0xFFFFFFFF); // elevated surfaces
  static const Color recessed = Color(0xFFF0F0F0); // subtle gray (chips, avatars)
  static const Color white = Color(0xFFFFFFFF); // explicit white for bubbles

  // Brand / accent (unchanged from dark theme)
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)

  // Focus trip accents (unchanged)
  static const Color focusViolet = Color(0xFF7C3AED);
  static const Color focusAlpine = Color(0xFF4A90E2); // Swiss
  static const Color focusOcean = Color(0xFF14B8A6); // Goa
  static const Color focusSunset = Color(0xFFFF9B6E); // Bali

  static const Color liveGreen = Color(0xFF047857); // darker green for light bg

  static const Color primary = Color(0xFFD4536B); // kept for backward compat

  // Ink — dark text on light backgrounds
  static const Color inkPrimary = Color(0xFF1A1A1A); // near-black
  static const Color inkSecondary = Color(0xFF6B6B78); // medium gray
  static const Color inkTertiary = Color(0xFF8A8A94); // light gray

  static const Color gold = Color(0xFF8B6914); // darker gold for light bg
  static const Color error = Color(0xFFC43D08); // archive error orange
}
```

Keep any other classes (HelloText, HelloGlass) intact — only the HelloColors class gets rewritten.

#### Task 1.2: atmosphere.dart rewrite

Read the existing file first. Overwrite with the following. The file keeps its existing provider bindings (`focusTripProvider`, `centeredFeedItemKindProvider`, `tabAnimationProvider`) and the 26-second animation controller — only the color math and layering changes.

```dart
// Home atmosphere — light focus-tinted wash.
//
// Off-white base (#FAFAFA) with a very faint radial wash in the
// current focus trip's accent color. Lerps smoothly during tab
// swipes via [tabAnimationProvider]. Preserves the "living field"
// concept in a light-appropriate way: you feel the background
// shift more than you see it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/tabs_provider.dart';
import '../../../providers/viewport_focus_provider.dart';

const Color _base = Color(0xFFFAFAFA);
const Color _defaultPrimary = Color(0xFF7C3AED); // deep violet
const Color _teal = Color(0xFF14B8A6);
const Color _rose = Color(0xFFD4536B);
const Color _gold = Color(0xFFC8A84E);

Color? _primaryForKind(String? kind) {
  if (kind == null) return null;
  return switch (kind) {
    'dm' => const Color(0xFF8B5CF6),
    'group' => const Color(0xFFF97316),
    'decision' => const Color(0xFF10B981),
    'trip' => const Color(0xFF4A90E2),
    'settlement' => const Color(0xFFFACC15),
    'itinerary' => const Color(0xFF14B8A6),
    'memory' => const Color(0xFFFF9B6E),
    'ai' => const Color(0xFF4A90E2),
    _ => null,
  };
}

/// Lerps between the 4 tab signature colors based on the live
/// fractional tab animation value (0.0 — 3.0).
Color _primaryForTabAnimation(double value) {
  final clamped = value.clamp(0.0, HomeTab.values.length - 1.0);
  final lowerIndex = clamped.floor();
  final upperIndex = (lowerIndex + 1).clamp(0, HomeTab.values.length - 1);
  final t = clamped - lowerIndex;
  final lower = HomeTab.values[lowerIndex].signatureColor;
  final upper = HomeTab.values[upperIndex].signatureColor;
  return Color.lerp(lower, upper, t) ?? lower;
}

class AmbientMesh extends ConsumerStatefulWidget {
  const AmbientMesh({super.key});

  @override
  ConsumerState<AmbientMesh> createState() => _AmbientMeshState();
}

class _AmbientMeshState extends ConsumerState<AmbientMesh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(focusTripProvider);
    final centeredKind = ref.watch(centeredFeedItemKindProvider);
    final tabAnimation = ref.watch(tabAnimationProvider);

    final tabColor = _primaryForTabAnimation(tabAnimation);
    final primary = tabColor != HomeTab.values[0].signatureColor
        ? tabColor
        : (_primaryForKind(centeredKind) ??
            focus?.accentColor ??
            _defaultPrimary);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final dx1 = math.sin(t * 2 * math.pi) * 28;
        final dy1 = math.cos(t * 2 * math.pi) * 36;
        final dx2 = math.cos(t * 2 * math.pi) * 34;
        final dy2 = math.sin(t * 2 * math.pi) * 26;

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Base — solid off-white
              const ColoredBox(color: _base),
              // Primary focus wash — top left, very faint
              Positioned(
                left: -60 + dx1,
                top: -80 + dy1,
                width: 560,
                height: 460,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: primary),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, color, _) {
                    return _LightBlob(
                      color: color ?? primary,
                      opacity: 0.08,
                    );
                  },
                ),
              ),
              // Teal wash — right mid
              Positioned(
                right: -80 + dx2,
                top: 200 + dy2,
                width: 500,
                height: 460,
                child: const _LightBlob(color: _teal, opacity: 0.04),
              ),
              // Rose wash — bottom left
              Positioned(
                left: -100 - dx1,
                bottom: -60 - dy1,
                width: 520,
                height: 420,
                child: const _LightBlob(color: _rose, opacity: 0.03),
              ),
              // Gold wash — center bottom
              Positioned(
                left: 40,
                right: 40,
                bottom: -140 + dy2.abs(),
                height: 380,
                child: const _LightBlob(color: _gold, opacity: 0.025),
              ),
              // Top-right highlight — "light source"
              Positioned(
                right: -80,
                top: -80,
                width: 400,
                height: 400,
                child: _LightBlob(
                  color: Colors.white,
                  opacity: 0.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LightBlob extends StatelessWidget {
  final Color color;
  final double opacity;
  const _LightBlob({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}
```

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/theme.dart lib/views/home/decision_board/atmosphere.dart
```

Expected: `No issues found!`

```bash
cd /Users/ramchitturi/hello
git add app/lib/theme.dart app/lib/views/home/decision_board/atmosphere.dart
git commit -m "feat(theme): flip tokens to light + atmosphere becomes focus-tinted light wash"
```

---

### Track 2: CardShell glass for light theme

**File:** Modify `app/lib/views/home/decision_board/cards/_card_shell.dart`

Read the existing file first. This is a surgical edit — only the visual painting pieces change. Keep everything else (focus-lift, ring, spring tap, kind overlay, ambient pulse, key registry).

**Changes:**

1. The base gradient fill (`Colors.white.withValues(alpha: 0.07)` / `0.02`) → replace with solid `Colors.white`
2. The rim color (`(accentColor ?? Colors.white).withValues(alpha: 0.10)`) → change to `(accentColor ?? Colors.black).withValues(alpha: 0.06)`
3. The focus ring color (white) → change to black at same opacity
4. The ambient unread pulse ring stays Rausch (unchanged — brand color survives flip)
5. Add a subtle drop shadow to the outer ClipRRect container

**Specific diffs:**

**Find:**
```dart
    final rimColor =
        (widget.accentColor ?? Colors.white).withValues(alpha: 0.10);
```

**Replace with:**
```dart
    final rimColor =
        (widget.accentColor ?? Colors.black).withValues(alpha: 0.06);
```

**Find the DecoratedBox with the `gradient: LinearGradient(... Colors.white.withValues(alpha: 0.07) ... 0.02 ...)` fill (inside the BackdropFilter block) and replace the `gradient` property with `color: Colors.white`. Keep the `border` line that uses `rimColor`:**

**Find:**
```dart
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.07),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                              border: Border.all(color: rimColor, width: 1),
                            ),
```

**Replace with:**
```dart
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white,
                              border: Border.all(color: rimColor, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
```

**Find the focus ring `Border.all` with `Colors.white.withValues(alpha: _ringOpacity.value)`:**

**Find:**
```dart
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: _ringOpacity.value),
                                width: 1,
                              ),
                            ),
```

**Replace with:**
```dart
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.black
                                    .withValues(alpha: _ringOpacity.value * 0.5),
                                width: 1,
                              ),
                            ),
```

(The `* 0.5` attenuates the pulse so a dark ring on light cards doesn't scream.)

Leave the ambient pulse ring (`HelloColors.accent` / Rausch) unchanged — Rausch works on both themes.

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/_card_shell.dart
```

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/_card_shell.dart
git commit -m "feat(theme): CardShell glass for light — white fill + dark rim + drop shadow"
```

---

### Track 3: Chrome widgets

**Files (6):**
- Modify `app/lib/views/home/decision_board/bottom_bar.dart`
- Modify `app/lib/views/home/decision_board/tab_popover.dart`
- Modify `app/lib/views/home/decision_board/message_input_bar.dart`
- Modify `app/lib/views/home/decision_board/conversation_list_row.dart`
- `tab_chip.dart`, `tab_header.dart`, `floating_avatar.dart` — verify no hardcoded refs (should auto-flip via theme tokens, no edits expected)

#### `bottom_bar.dart`

Find the `Container` inside `BackdropFilter` with the gradient fill using `Colors.white.alpha(0.08 → 0.03)` and replace the gradient with solid `Colors.white.alpha(0.92)` + flip the border to dark:

**Find:**
```dart
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
```

**Replace with:**
```dart
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withValues(alpha: 0.92),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
```

#### `tab_popover.dart`

Find the `_TabPopoverCard`'s `Container` decoration:

**Find:**
```dart
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
```

**Replace with:**
```dart
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
```

#### `message_input_bar.dart`

Find the `_MessageInputBarState`'s inner text-field container:

**Find:**
```dart
            decoration: BoxDecoration(
              color: HelloColors.recessed,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
```

**Replace with:**
```dart
            decoration: BoxDecoration(
              color: HelloColors.recessed,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
```

#### `conversation_list_row.dart`

Find the bottom border line:

**Find:**
```dart
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
```

**Replace with:**
```dart
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
```

Also find the InkWell splash / highlight colors if they use white:

**Find:**
```dart
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.02),
```

**Replace with:**
```dart
        splashColor: Colors.black.withValues(alpha: 0.04),
        highlightColor: Colors.black.withValues(alpha: 0.02),
```

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/bottom_bar.dart lib/views/home/decision_board/tab_popover.dart lib/views/home/decision_board/message_input_bar.dart lib/views/home/decision_board/conversation_list_row.dart
```

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/bottom_bar.dart app/lib/views/home/decision_board/tab_popover.dart app/lib/views/home/decision_board/message_input_bar.dart app/lib/views/home/decision_board/conversation_list_row.dart
git commit -m "feat(theme): chrome widgets — flip hardcoded white refs to dark for light bg"
```

---

### Track 4: Text cards (no photo backgrounds)

**Files (7):**
- `app/lib/views/home/decision_board/cards/dm_card.dart`
- `app/lib/views/home/decision_board/cards/group_card.dart`
- `app/lib/views/home/decision_board/cards/decision_card_small.dart`
- `app/lib/views/home/decision_board/cards/ai_nudge_card.dart`
- `app/lib/views/home/decision_board/cards/settlement_card.dart`
- `app/lib/views/home/decision_board/cards/itinerary_card.dart`
- `app/lib/views/home/decision_board/cards/memory_card.dart`

For each file, **read it first**, then check for these patterns and flip them:

- `Colors.white.withValues(alpha: ...)` for internal separators, backgrounds, or borders → flip to `Colors.black.withValues(alpha: ...)` at similar or slightly lower alpha
- `Color(0xFFF0EFF4)` for text → replace with `Color(0xFF1A1A1A)`
- `HelloColors.inkPrimary.withValues(alpha: X)` → unchanged (token auto-flips)
- `HelloColors.inkPrimary` → unchanged (auto-flips)
- `HelloColors.accent` (Rausch) → unchanged
- `HelloColors.recessed` → unchanged (auto-flips to light gray)

**Most of these cards use theme tokens exclusively.** A grep expected: most files need 0-2 line changes. Scan each file, apply changes, commit batch.

Special notes:

**`decision_card_small.dart` — _VoteButton:**
The vote button's active background uses `HelloColors.accent.withValues(alpha: 0.18)` — keep as-is. The inactive background uses `HelloColors.recessed` — keep as-is (auto-flips).

**`memory_card.dart`:**
Uses `HelloColors.surfaceDeep` for the photo fallback. In the new theme surfaceDeep is `#FFFFFF` — fine.

**`itinerary_card.dart`:**
Uses `HelloColors.liveGreen` — auto-flips to `#047857` which has good contrast on light bg.

**`settlement_card.dart`:**
The PAY button uses `HelloColors.accent` — unchanged. The PAY button text is `Color(0xFFF0EFF4)` — flip to `Color(0xFFFFFFFF)` (white text on Rausch background is correct).

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/dm_card.dart lib/views/home/decision_board/cards/group_card.dart lib/views/home/decision_board/cards/decision_card_small.dart lib/views/home/decision_board/cards/ai_nudge_card.dart lib/views/home/decision_board/cards/settlement_card.dart lib/views/home/decision_board/cards/itinerary_card.dart lib/views/home/decision_board/cards/memory_card.dart
```

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/dm_card.dart app/lib/views/home/decision_board/cards/group_card.dart app/lib/views/home/decision_board/cards/decision_card_small.dart app/lib/views/home/decision_board/cards/ai_nudge_card.dart app/lib/views/home/decision_board/cards/settlement_card.dart app/lib/views/home/decision_board/cards/itinerary_card.dart app/lib/views/home/decision_board/cards/memory_card.dart
git commit -m "feat(theme): text cards — flip hardcoded white text refs for light bg"
```

---

### Track 5: Hero cards (photo backgrounds)

**Files (3):**
- `app/lib/views/home/decision_board/cards/decision_card_hero.dart`
- `app/lib/views/home/decision_board/cards/trip_card.dart`
- `app/lib/views/home/decision_board/cards/focus_hero_card.dart`

Each hero card has:
1. A photo background (`Image.network`)
2. A dark tint overlay (`ColoredBox(color: Color(0x55000000))` or `Colors.black.alpha(0.30)`)
3. A scrim gradient (`transparent → Color(0xCC000000)`)
4. White text overlaid on top (`Color(0xFFF0EFF4)`)

For each file, **read it first**, then apply these 3 flips:

#### Flip 1: darken overlay → remove or use very faint white

**Find patterns like:**
```dart
const ColoredBox(color: Color(0x55000000)),
```

or

```dart
ColoredBox(color: Colors.black.withValues(alpha: 0.30)),
```

or

```dart
ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
```

**Replace with:**
```dart
const SizedBox.shrink(),
```

(or remove the line entirely from the Stack children list — the scrim flip in step 2 handles contrast)

#### Flip 2: scrim gradient → white instead of black

**Find patterns like:**
```dart
const DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0xCC000000)],
      stops: [0.45, 1.0],
    ),
  ),
),
```

**Replace with:**
```dart
const DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00FFFFFF), Color(0xE6FFFFFF)],
      stops: [0.40, 1.0],
    ),
  ),
),
```

For `focus_hero_card.dart` which has slightly different gradient stops (`[0.35, 1.0]` with alpha `0x22000000 → 0xDD000000`), use:

```dart
colors: [Color(0x00FFFFFF), Color(0xE6FFFFFF)],
stops: [0.35, 1.0],
```

#### Flip 3: all occurrences of `Color(0xFFF0EFF4)` text → `Color(0xFF1A1A1A)`

In each hero card, find all `Color(0xFFF0EFF4)` text color references (for title, subtitle, meta text, labels) and replace with `Color(0xFF1A1A1A)`.

Use `replace_all: true` on the Edit tool for each file — the replacement is consistent.

Also find any `.withValues(alpha: X)` applied to `Color(0xFFF0EFF4)` — flip them to `Color(0xFF1A1A1A)` too.

Example:
```dart
color: const Color(0xFFF0EFF4).withValues(alpha: 0.75),
```

becomes:
```dart
color: const Color(0xFF1A1A1A).withValues(alpha: 0.75),
```

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/decision_card_hero.dart lib/views/home/decision_board/cards/trip_card.dart lib/views/home/decision_board/cards/focus_hero_card.dart
```

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/decision_card_hero.dart app/lib/views/home/decision_board/cards/trip_card.dart app/lib/views/home/decision_board/cards/focus_hero_card.dart
git commit -m "feat(theme): hero cards — flip scrims dark→light + text white→dark"
```

---

### Track 6: ChatBubble port (new widget)

**File:** Create `app/lib/views/home/decision_board/chat_bubble.dart`

Port the widget from `ui_backup_2026-04-10/flutter/widgets/chat_bubble.dart`. **Read that archived file first** to see the exact source, then create the new file with the same content but with this one import change:

**Archive imports:**
```dart
import '../theme.dart';
```

**New imports (adjust relative path):**
```dart
import '../../../theme.dart';
```

All other code (ChatBubble class, _ChatBubbleState, _senderNames map, spring physics, drag handlers, long-press reaction picker, `_buildTextContent`, smart corner radii) is copied verbatim. The archive was written for the light theme — it already uses `Colors.white.alpha(0.85)` bubble fills + `HelloColors.inkPrimary` text (which is dark `#1A1A1A` in the new light theme).

**Double check after paste:** confirm the imports resolve, the widget compiles, and `HelloColors.inkPrimary` / `HelloColors.inkTertiary` / `HelloColors.inkSecondary` references are unchanged. No other edits.

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/chat_bubble.dart
```

Expected: `No issues found!`

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/chat_bubble.dart
git commit -m "feat(home): port ChatBubble widget from archive — glass bubble + swipe-to-reply"
```

---

### Track 7: Sheets — Material ancestor + ChatBubble integration

**Files (7):**
- `app/lib/views/home/decision_board/sheets/dm_sheet.dart`
- `app/lib/views/home/decision_board/sheets/group_sheet.dart`
- `app/lib/views/home/decision_board/sheets/decision_sheet.dart`
- `app/lib/views/home/decision_board/sheets/settlement_sheet.dart`
- `app/lib/views/home/decision_board/sheets/search_sheet.dart`
- `app/lib/views/home/decision_board/sheets/new_chat_sheet.dart`
- `app/lib/views/home/decision_board/sheets/attachment_sheet.dart`

#### Task 7.1: Wrap every sheet root Container in a Material ancestor

For each sheet, find the top-level `Container(height: height, decoration: ..., child: Column(...))` that's the direct child of the `BackdropFilter`. Wrap its `child:` in a `Material(type: MaterialType.transparency, child: ...)`.

**Pattern — find:**
```dart
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
```

**Pattern — replace with (flipping voidBg alpha to a brighter white-dominant fill and wrapping the child in Material):**

For this, do two edits per file:

**Edit 1: bump the sheet background alpha** — find every `HelloColors.voidBg.withValues(alpha: 0.72)` in the sheets and replace with `HelloColors.voidBg.withValues(alpha: 0.94)` (near-opaque off-white so the sheet reads clearly on the light feed).

**Edit 2: wrap content in Material** — find:

```dart
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: HelloColors.voidBg.withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Column(
```

**Replace with:**
```dart
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: HelloColors.voidBg.withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
```

And add the corresponding closing `),` before the matching `Container` close. You must close the Material widget tree correctly — each sheet has slightly different nesting.

**The simplest approach:** find the outermost `Column(children: [...])` inside the sheet's `Container(child: ...)` and wrap the entire `Column(...)` in `Material(type: MaterialType.transparency, child: Column(...))`.

#### Task 7.2: DM sheet — swap mock bubbles for real ChatBubble

In `dm_sheet.dart`:

**Find** the mock message class and list builder:
```dart
class _MockMessage {
  final String text;
  final bool fromMe;
  const _MockMessage({required this.text, required this.fromMe});
}

class _MessageBubble extends StatelessWidget {
  final _MockMessage msg;
  const _MessageBubble({required this.msg});
  // ... existing build method
}
```

**Keep** the `_MockMessage` class, **delete** the `_MessageBubble` class, and **change the `ListView.separated` itemBuilder** from:

```dart
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _MessageBubble(msg: messages[i]),
      ),
```

**to:**
```dart
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final msg = messages[i];
          return ChatBubble(
            text: msg.text,
            isOutbound: msg.fromMe,
            isFirstInGroup: true,
            isLastInGroup: true,
          );
        },
      ),
```

Also add the import: `import '../chat_bubble.dart';`

#### Task 7.3: Group sheet — no inline chat yet, just Material fix

In `group_sheet.dart`, only the Material wrapper is needed. The group sheet shows stat chips + activity blurb, not a message thread — no ChatBubble integration required for v1.

Apply only Task 7.1's Material fix.

#### Verify + commit

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/sheets/
```

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/sheets/
git commit -m "feat(theme): sheets — Material ancestor + DmSheet uses real ChatBubble"
```

---

## Wave 2 — Integration (primary agent)

### Task I.1: Run full analyze

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/ 2>&1 | grep -E "error|warning"
```

Expected: no errors, no warnings. Fix any inline before continuing.

### Task I.2: Verify decision_board_page.dart still compiles

The tab scaffold shouldn't need changes (uses only theme tokens + the widgets listed above). Read it to verify and tweak if needed.

### Task I.3: Commit Wave 2

```bash
cd /Users/ramchitturi/hello
git status --short
git commit --allow-empty -m "feat(theme): light theme migration complete"
```

### Task I.4: Kill + relaunch Flutter

Stop the current flutter background task, clear port 8765, relaunch, wait for DevTools line.

### Task I.5: Manual verification

- Home screen renders on an off-white background with faint focus-tinted wash
- Dark text is readable everywhere
- Tap a DM card → sheet opens WITHOUT the red "No Material widget" error
- DM sheet shows real ChatBubble widgets
- Long-press a bubble → emoji picker appears
- Swipe left on a bubble → reply indicator fades in
- Tab swipes smoothly and atmosphere wash lerps between tab colors
- Rausch accent only on unread pills, CTAs, and action buttons

### Task I.6: Report back

---

## Rollback

If this migration breaks catastrophically, `git reset --hard 90c52a5` restores the last known-good dark theme state (the tab scaffold commit).
