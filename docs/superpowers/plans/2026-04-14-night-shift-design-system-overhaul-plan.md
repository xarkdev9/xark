# Night Shift Design System Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the hello Flutter app from a visual prototype into an engineering-grade design system — every color named, every text style codified, every blur tier documented, every animation justified, every screen state-complete, mock data deleted, engine wired, dark mode working, accessibility navigable, performance measured.

**Architecture:** 12 phases organized into 7 waves for maximum parallelism. Waves A/C/E run concurrent agents on disjoint file sets. Every phase ends with `cd app && dart analyze lib/` returning zero errors. Every task appends to `nightshifttracker.md`.

**Tech Stack:** Flutter 3.11+, Dart, Riverpod 3.3.1, e2ee_chat_sdk (engine), mobile_scanner 6.0, Inter font (bundled)

**Spec:** `docs/superpowers/specs/2026-04-14-night-shift-design-system-overhaul-design.md`

---

## Pre-Flight: Agent Context Protocol

Every agent MUST execute these steps before any code change:

```
1. Read this plan file completely
2. Read the spec file: docs/superpowers/specs/2026-04-14-night-shift-design-system-overhaul-design.md
3. Read app/lib/theme.dart (the shared source of truth — changes across waves)
4. Read app/CLAUDE.md (landmines, dead code flags, provider inventory)
5. Read CLAUDE.md root (security boundary, no-bold mandate, brand color restraint)
6. Read nightshifttracker.md to see what previous waves completed
7. Read EVERY file you will modify BEFORE modifying it
```

After every task:
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```
Must return zero errors. If it fails, fix before proceeding.

After every task, append to `/Users/ramchitturi/hello/nightshifttracker.md`:
```markdown
## Phase N — Task M: [title]
- **What was done:** [specific changes]
- **Why:** [which apr14.md critique this addresses]
- **Files changed:** [list with line ranges]
- **Verification:** dart analyze lib/ → [result]
```

---

## WAVE A — Foundation (Phases 1, 2, 6 run concurrently)

### ⚠ Conflict Resolution for theme.dart

Phases 1 and 2 both write to `app/lib/theme.dart`. They MUST write to non-overlapping regions:
- **Phase 1** writes ONLY inside `class HelloColors { ... }` (lines 3-34). Adds new color constants AFTER line 33 (before the closing brace).
- **Phase 2** writes ONLY inside `class HelloText { ... }` (lines 36-71). Adds new text styles between existing styles.
- **Neither phase** touches `class HelloGlass` (lines 73-79). That is Wave B's territory.

---

## Phase 1: Color System

### Task 1: Register card kind gradient colors in HelloColors

**Files:**
- Modify: `app/lib/theme.dart` (inside `class HelloColors`, after line 33)

- [ ] **Step 1: Read theme.dart**

Read the full file. Confirm `HelloColors` class ends at line 34. Confirm the last token before the closing brace is `static const Color error = Color(0xFFC43D08);` at line 33.

- [ ] **Step 2: Add card kind tint colors**

Insert after line 33 (`error` constant), before the closing `}` of `HelloColors`:

```dart
  // Card kind tints — semi-transparent overlays identifying card type in feed
  static const Color kindDm             = Color(0x2B8B5CF6);
  static const Color kindDmFade         = Color(0x143B82F6);
  static const Color kindGroup          = Color(0x2BF97316);
  static const Color kindGroupFade      = Color(0x14EC4899);
  static const Color kindDecision       = Color(0x2B10B981);
  static const Color kindDecisionFade   = Color(0x1406B6D4);
  static const Color kindSettlement     = Color(0x1EFACC15);
  static const Color kindSettlementFade = Color(0x0E10B981);
  static const Color kindItinerary      = Color(0x2B14B8A6);
  static const Color kindItineraryFade  = Color(0x143B82F6);
  static const Color kindMemory         = Color(0x2BFF9B6E);
  static const Color kindMemoryFade     = Color(0x14D4536B);
  static const Color kindAiNudge        = Color(0x2B4A90E2);
  static const Color kindAiNudgeFade    = Color(0x148B5CF6);

  // Utility colors — registered to eliminate orphan hex literals
  static const Color chrome    = Color(0xFFF0EFF4); // lavender gray, dividers, icon tint
  static const Color pulse     = Color(0xFFFF385C); // plasma pulse ring, compose icon
  static const Color scoreHigh = Color(0xFF40E0D0); // turquoise, agreement >= 50%
  static const Color scoreLow  = Color(0xFFFFA000); // amber, agreement < 50%
  static const Color warmPeach = Color(0xFFFFB380); // constellation hero accent
```

- [ ] **Step 3: Mark HelloGlass as deprecated**

Replace lines 74-78 (the HelloGlass class body) with:

```dart
class HelloGlass {
  /// @deprecated — replaced with 3-tier Whisper/Veil/Curtain system in Phase 3.
  /// Do not reference these values in new code.
  static const Color fill = Color(0x0AFFFFFF);
  static const Color border = Color(0x0FFFFFFF);
  static const double blurRadius = 40.0;
}
```

- [ ] **Step 4: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero errors (adding constants cannot break anything).

- [ ] **Step 5: Update nightshifttracker.md**

### Task 2: Replace orphan hex values in consumer files

**Files:**
- Modify: `app/lib/views/home/decision_board/cards/_card_shell.dart`
- Modify: `app/lib/views/home/decision_board/liquid_intent_handle.dart`
- Modify: `app/lib/views/home/decision_board/cards/decision_card.dart`
- Modify: `app/lib/views/home/decision_board/sheets/decision_sheet.dart`
- Modify: `app/lib/views/home/decision_board/bottom_bar.dart`
- Modify: `app/lib/views/home/decision_board/conversation_list_row.dart`
- Modify: `app/lib/views/home/decision_board/message_input_bar.dart`

- [ ] **Step 1: Read each file and locate the orphan colors**

For each file, read it fully. Find the exact line with the hardcoded color. The spec provides line numbers but they may have shifted — match on the hex value, not the line number.

- [ ] **Step 2: Replace orphan hex values**

In each file, replace the `Color(0x...)` literal with the corresponding `HelloColors` reference. Add `import '../../theme.dart';` (or the correct relative path) if not already imported.

Replacements:
- `_card_shell.dart`: All 14 inline gradient colors in the `_kindGradient` map (lines 18-48) → replace with `HelloColors.kindDm`, `HelloColors.kindDmFade`, etc. Also replace `Color(0xFFFF385C)` (line 247) → `HelloColors.pulse`
- `liquid_intent_handle.dart`: `Color(0xFFFF385C)` (line 335) → `HelloColors.pulse`
- `decision_card.dart`: `Color(0xFF40E0D0)` (line 69) → `HelloColors.scoreHigh`; `Color(0xFFFFA000)` (line 70) → `HelloColors.scoreLow`
- `decision_sheet.dart`: `Color(0xFFFFB380)` (line 405) → `HelloColors.warmPeach`
- `bottom_bar.dart`: `Color(0xFFF0EFF4)` (line 166) → `HelloColors.chrome`
- `conversation_list_row.dart`: `Color(0xFFF0EFF4)` (line 188) → `HelloColors.chrome`
- `message_input_bar.dart`: `Color(0xFFF0EFF4)` (line 142) → `HelloColors.chrome`

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

### Task 3: Fix compile error, deprecated tokens, dark-on-light text, withOpacity

**Files:**
- Modify: `app/lib/views/os/error_card.dart`
- Modify: `app/lib/views/finance/group_expense_page.dart`
- Modify: `app/lib/views/group/create_group_page.dart`
- Modify: `app/lib/views/settings/device_listing.dart`
- Modify: `app/lib/views/os/feedback_sheet.dart`

- [ ] **Step 1: Fix compile error in error_card.dart**

Read `error_card.dart`. Find line 73: `HelloColors.surfaceChrome`. Replace with `HelloColors.recessed`.

```dart
// OLD:
color: widget.isError ? HelloColors.accent : HelloColors.surfaceChrome,
// NEW:
color: widget.isError ? HelloColors.accent : HelloColors.recessed,
```

- [ ] **Step 2: Fix deprecated HelloColors.primary in group_expense_page.dart**

Read `group_expense_page.dart`. Replace:
- Line 27: `HelloColors.primary` → `HelloColors.accent`
- Line 32: `HelloColors.primary.withOpacity(0.1)` → `HelloColors.accent.withValues(alpha: 0.1)`

- [ ] **Step 3: Fix deprecated HelloColors.primary in create_group_page.dart**

Read `create_group_page.dart`. Line 24: `HelloColors.primary` → `HelloColors.accent`

- [ ] **Step 4: Fix invisible white text in device_listing.dart**

Read `device_listing.dart`. Replace every `Colors.white` used as text/icon color with the appropriate `HelloColors` token:
- Line 21: `color: Colors.white` → `color: HelloColors.inkPrimary`
- Line 33: `color: Colors.white` → `color: HelloColors.inkPrimary`
- Line 55: `color: Colors.white` → `color: HelloColors.inkPrimary`
- Line 71: `color: Colors.white` → `color: HelloColors.inkSecondary`

Ensure `import '../../theme.dart';` (correct relative path) is present.

- [ ] **Step 5: Fix invisible white text in feedback_sheet.dart**

Read `feedback_sheet.dart`. Replace:
- Line 62: `color: Colors.white` → `color: HelloColors.inkPrimary`
- Line 69: `color: Colors.white` → `color: HelloColors.inkPrimary`
- Line 103: `color: Colors.white` → `color: HelloColors.inkPrimary`

- [ ] **Step 6: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero errors. The `surfaceChrome` error is resolved.

- [ ] **Step 7: Verify with grep**

```bash
cd /Users/ramchitturi/hello && grep -rn '\.withOpacity(' app/lib/
# Expected: zero results

cd /Users/ramchitturi/hello && grep -rn 'HelloColors\.primary' app/lib/ | grep -v 'theme\.dart'
# Expected: zero results (only the definition in theme.dart remains)
```

- [ ] **Step 8: Update nightshifttracker.md**

---

## Phase 2: Typography System

### Task 4: Bundle Inter font

**Files:**
- Create: `app/assets/fonts/Inter-Regular.ttf`
- Create: `app/assets/fonts/Inter-Light.ttf`
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Download Inter font files**

```bash
mkdir -p /Users/ramchitturi/hello/app/assets/fonts
cd /Users/ramchitturi/hello/app/assets/fonts
curl -L "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip" -o inter.zip
unzip -o inter.zip "Inter-Regular.ttf" "Inter-Light.ttf" 2>/dev/null || true
```

If the direct file extraction fails (zip structure varies), find and copy the correct files:
```bash
unzip -l inter.zip | grep -i "regular\|light"
# Then extract the correct paths
```

If curl/unzip is not available or fails, create placeholder font files and note in nightshifttracker.md that real fonts need manual download from https://fonts.google.com/specimen/Inter

- [ ] **Step 2: Update pubspec.yaml**

Read `app/pubspec.yaml`. The `flutter:` section starts at line 61. The `assets:` section is at lines 68-70. There is no `fonts:` key currently.

Add `assets/fonts/` to the assets list, and add the fonts section. The `flutter:` section should become:

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/decide/
    - assets/memories/
    - assets/fonts/

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Light.ttf
          weight: 300
```

Remove all the commented-out example font text that currently occupies lines 78-95.

- [ ] **Step 3: Run flutter pub get**

```bash
cd /Users/ramchitturi/hello/app && flutter pub get
```

- [ ] **Step 4: Update nightshifttracker.md**

### Task 5: Complete the 8-level type scale

**Files:**
- Modify: `app/lib/theme.dart` (inside `class HelloText` only — Phase 1 handles HelloColors)

- [ ] **Step 1: Read theme.dart**

Confirm `HelloText` class currently has 4 styles: `display` (line 37-44), `title` (line 46-53), `body` (line 55-61), `label` (line 63-70).

- [ ] **Step 2: Add 4 missing text styles**

Insert `heading` between `title` and `body`. Insert `small` and `caption` between `body` and `label`. Insert `mono` after `label`.

The complete `HelloText` class becomes:

```dart
class HelloText {
  static const TextStyle display = TextStyle(
    fontFamily: 'Inter',
    fontSize: 44,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.03,
    height: 1.1,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.02,
    height: 1.2,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.01,
    height: 1.3,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle small = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w300,
    height: 1.5,
    color: HelloColors.inkSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: HelloColors.inkTertiary,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.02,
    height: 1.4,
    color: HelloColors.inkPrimary,
  );
}
```

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

### Task 6: Replace inline TextStyles with named styles

**Files:**
- Modify: ~15 files identified by grep

- [ ] **Step 1: Find all inline TextStyle declarations**

```bash
cd /Users/ramchitturi/hello && grep -rn 'TextStyle(' app/lib/ | grep -v 'theme.dart' | grep -v 'HelloText' | grep 'fontSize'
```

- [ ] **Step 2: For each match, apply replacement rules**

Matching rules (match on fontSize + fontWeight):
- `fontSize: 44, w300` → `HelloText.display` or `.copyWith(color: ...)`
- `fontSize: 28, w400` → `HelloText.title` or `.copyWith(color: ...)`
- `fontSize: 22, w400` → `HelloText.heading` or `.copyWith(color: ...)`
- `fontSize: 17, w400` → `HelloText.body` or `.copyWith(color: ...)`
- `fontSize: 15, w400` → `HelloText.small` or `.copyWith(color: ...)`
- `fontSize: 13, w300` → `HelloText.caption` or `.copyWith(color: ...)`
- `fontSize: 10, w400` → `HelloText.label` or `.copyWith(color: ...)`

If the inline TextStyle exactly matches a named style (same size, weight, and color), replace entirely.
If it matches size+weight but has a different color, use `.copyWith(color: ...)`.
If it does not match any named style, leave it with a comment: `// Non-standard size — intentional for [reason]`.

Add `import` for theme.dart if not already present in the file.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

---

## Phase 6: Information Architecture

### Task 7: Fix brand names and deprecated terminology

**Files:**
- Modify: `app/lib/views/auth/auth_flow_page.dart`
- Modify: `app/lib/views/chat/group_chat_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/invite_surface.dart`
- Modify: `app/lib/views/chat/direct_message_page.dart`
- Modify: `app/lib/views/group/create_group_page.dart`

- [ ] **Step 1: Fix brand name 'xark' → 'hello'**

Read each file. Find and replace:
- `auth_flow_page.dart` line 226: `'xark'` → `'hello'`
- `group_chat_page.dart` line 64: `'ask xark anything...'` → `'ask @hello anything...'`
- `invite_surface.dart` line 18: `'INVITE TO XARK'` → `'INVITE TO HELLO'`

- [ ] **Step 2: Fix deprecated terminology**

- `direct_message_page.dart` line 17: `'Sanctuary'` → `'Messages'`
- `create_group_page.dart` line 18: `'The Summoning'` → `'Create Group'`

- [ ] **Step 3: Verify with grep**

```bash
cd /Users/ramchitturi/hello && grep -rn 'xark' app/lib/
# Expected: zero results

cd /Users/ramchitturi/hello && grep -rn 'Sanctuary\|Summoning' app/lib/
# Expected: zero results
```

- [ ] **Step 4: Update nightshifttracker.md**

### Task 8: Fix SnackBar visibility

**Files:**
- Modify: `app/lib/views/home/decision_board/_card_factory.dart`

- [ ] **Step 1: Read _card_factory.dart**

Find every `SnackBar(backgroundColor: HelloColors.recessed` occurrence. The default SnackBar text is white, invisible on #F0F0F0.

- [ ] **Step 2: Add explicit text styling to all SnackBars**

For every SnackBar in the file, ensure the `content:` parameter uses visible text:

```dart
SnackBar(
  backgroundColor: HelloColors.recessed,
  content: Text(
    'Coming in v1.1',
    style: HelloText.small.copyWith(color: HelloColors.inkPrimary),
  ),
)
```

Apply to ALL stub SnackBars in the file.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

---

## WAVE A GATE

All three Phase 1, 2, and 6 agents must complete. Then run:

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Zero errors required before Wave B begins.

---

## WAVE B — Glass Hierarchy (Phase 3, sequential)

### Task 9: Rewrite HelloGlass as 3-tier system

**Files:**
- Modify: `app/lib/theme.dart` (HelloGlass class only)

- [ ] **Step 1: Read theme.dart**

Confirm HelloGlass class exists (now with deprecation comment from Phase 1). Replace the ENTIRE class.

- [ ] **Step 2: Replace HelloGlass**

Delete the existing `class HelloGlass { ... }` and replace with:

```dart
/// Glass hierarchy — 3 tiers with user-facing semantics.
///
/// Tier 1 "Whisper" — navigation chrome, card surfaces.
/// Tier 2 "Veil" — sheet headers/footers, popover backgrounds.
/// Tier 3 "Curtain" — full-attention modals, sheet bodies.
///
/// RULE: Never exceed curtainSigma (24). WebGL crash ceiling is 30.
/// RULE: Never use BackdropFilter inside Hero, PageView, or TabBarView transitions.
class HelloGlass {
  static const double whisperSigma  = 14.0;
  static const Color  whisperFill   = Color(0xB3FFFFFF);
  static const Color  whisperBorder = Color(0x1A000000);

  static const double veilSigma  = 20.0;
  static const Color  veilFill   = Color(0xCCFFFFFF);
  static const Color  veilBorder = Color(0x1A000000);

  static const double curtainSigma = 24.0;
  static const Color  curtainFill  = Color(0xE6FFFFFF);

  static const double bubbleOutboundSigma = 20.0;
  static const double bubbleInboundSigma  = 8.0;
}
```

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

### Task 10: Replace all raw BackdropFilter sigma values

**Files:**
- Modify: All 8 sheet files, `_card_shell.dart`, `bottom_bar.dart`, `tab_popover.dart`, `chat_bubble.dart`

- [ ] **Step 1: Find all raw ImageFilter.blur calls**

```bash
cd /Users/ramchitturi/hello && grep -rn 'ImageFilter.blur' app/lib/
```

- [ ] **Step 2: Replace sigma 14 → HelloGlass.whisperSigma**

In every file where `sigmaX: 14` appears, replace with `sigmaX: HelloGlass.whisperSigma, sigmaY: HelloGlass.whisperSigma`.

Files: `dm_sheet.dart`, `group_sheet.dart`, `decision_sheet.dart`, `settlement_sheet.dart`, `attachment_sheet.dart`, `new_chat_sheet.dart`, `search_sheet.dart`

Ensure each file imports theme.dart.

- [ ] **Step 3: Replace sigma 20 → HelloGlass.veilSigma**

In `_card_shell.dart`, replace the `sigmaX: 20, sigmaY: 20` with `sigmaX: HelloGlass.veilSigma, sigmaY: HelloGlass.veilSigma`.

- [ ] **Step 4: Replace sigma 24 → HelloGlass.curtainSigma**

In every file where `sigmaX: 24` appears: `dm_sheet.dart`, `group_sheet.dart`, `decision_sheet.dart`, `settlement_sheet.dart`, `attachment_sheet.dart`, `new_chat_sheet.dart`, `search_sheet.dart`, `bottom_bar.dart`, `tab_popover.dart`.

- [ ] **Step 5: Replace chat bubble variable sigmas**

In `chat_bubble.dart`, find where `blurSigma` is set to 20.0 (outbound) and 8.0 (inbound). Replace with `HelloGlass.bubbleOutboundSigma` and `HelloGlass.bubbleInboundSigma`.

- [ ] **Step 6: Verify no raw sigmas remain**

```bash
cd /Users/ramchitturi/hello && grep -rn 'ImageFilter.blur' app/lib/ | grep -v HelloGlass
# Expected: zero results
```

- [ ] **Step 7: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 8: Update nightshifttracker.md**

---

## WAVE C — Interactions + States + Accessibility (Phases 4, 5, 7 concurrent)

## Phase 4: Animation + Haptics

### Task 11: Fix CardShell lazy animation

**Files:**
- Modify: `app/lib/views/home/decision_board/cards/_card_shell.dart`

- [ ] **Step 1: Read _card_shell.dart**

Find `_ringController` `.repeat(reverse: true)` in `initState` (line 105) and `_unreadController` `.repeat(reverse: true)` (line 113).

- [ ] **Step 2: Remove unconditional .repeat() calls from initState**

Delete the `..repeat(reverse: true)` from both controller initializations. The controllers are still created, just not started.

- [ ] **Step 3: Add conditional start/stop in build()**

In the `build()` method, after `isFocused` is computed from `ref.watch(centeredFeedItemIdProvider)`, add:

```dart
if (isFocused && !_ringController.isAnimating) {
  _ringController.repeat(reverse: true);
} else if (!isFocused && _ringController.isAnimating) {
  _ringController.stop();
  _ringController.value = 0.0;
}

if (widget.ambientPulse && !_unreadController.isAnimating) {
  _unreadController.repeat(reverse: true);
} else if (!widget.ambientPulse && _unreadController.isAnimating) {
  _unreadController.stop();
  _unreadController.value = 0.0;
}
```

Place this logic BEFORE the `return` statement in `build()`, after the `isFocused` variable is defined.

- [ ] **Step 4: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 5: Update nightshifttracker.md**

### Task 12: Create haptics utility

**Files:**
- Create: `app/lib/utils/haptics.dart`

- [ ] **Step 1: Create the utils directory if needed**

```bash
mkdir -p /Users/ramchitturi/hello/app/lib/utils
```

- [ ] **Step 2: Write haptics.dart**

```dart
import 'package:flutter/services.dart';

/// Semantic haptic feedback. Every interactive element calls one of these.
/// Named by user intent, not by haptic engine level.
class HelloHaptic {
  /// Light tap — card taps, button presses, icon taps
  static void tap() => HapticFeedback.lightImpact();

  /// Confirm — send message, cast vote, save setting
  static void confirm() => HapticFeedback.mediumImpact();

  /// Celebrate — consensus reached, item locked, onboarding complete
  static void celebrate() => HapticFeedback.heavyImpact();

  /// Select — tab switch, picker change, category filter
  static void select() => HapticFeedback.selectionClick();

  /// Warning — destructive action (delete, revoke, dismiss)
  static void warning() => HapticFeedback.heavyImpact();
}
```

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

### Task 13: Wire haptics to all interactive widgets

**Files:**
- Modify: `_card_factory.dart`, `message_input_bar.dart`, `chat_bubble.dart`, `decision_card_small.dart`, `decision_sheet.dart`, `tab_chip.dart`, `tab_popover.dart`, `bottom_bar.dart`, `conversation_list_row.dart`, `dm_page.dart`, `group_page.dart`, `user_settings_page.dart`, `search_sheet.dart`

- [ ] **Step 1: Add HelloHaptic import to each file**

Add at the top of each file:
```dart
import '../../utils/haptics.dart';
```
(Adjust relative path based on the file's location)

- [ ] **Step 2: Add haptic calls as FIRST line in each onTap/onPressed**

For each file, read it, find every `onTap:`, `onPressed:`, `onDismissed:` callback, and add the appropriate `HelloHaptic.*()` call as the first line:

| File | Callback location | Insert |
|------|-------------------|--------|
| `_card_factory.dart` | Every card `onTap:` in the switch | `HelloHaptic.tap();` |
| `message_input_bar.dart` | Send button onTap | `HelloHaptic.confirm();` |
| `chat_bubble.dart` | Long-press handler | `HelloHaptic.tap();` |
| `chat_bubble.dart` | Reaction emoji onTap | `HelloHaptic.tap();` |
| `decision_card_small.dart` | Vote button onTap | `HelloHaptic.tap();` |
| `decision_sheet.dart` | Vote button onTap | `HelloHaptic.tap();` |
| `tab_chip.dart` | Tab selection onTap | `HelloHaptic.select();` |
| `tab_popover.dart` | Tab option onTap | `HelloHaptic.select();` |
| `bottom_bar.dart` | [+] compose onTap | `HelloHaptic.tap();` |
| `bottom_bar.dart` | Mic button onTap | `HelloHaptic.tap();` |
| `conversation_list_row.dart` | Row InkWell onTap | `HelloHaptic.tap();` |
| `dm_page.dart` | MessageInputBar onSend | `HelloHaptic.confirm();` |
| `group_page.dart` | MessageInputBar onSend | `HelloHaptic.confirm();` |
| `user_settings_page.dart` | Device revoke onDismissed | `HelloHaptic.warning();` |
| `search_sheet.dart` | Row onTap | `HelloHaptic.tap();` |

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Verify haptics wiring**

```bash
cd /Users/ramchitturi/hello && grep -rn 'HelloHaptic\.' app/lib/ | wc -l
# Expected: 16 or more
```

- [ ] **Step 5: Update nightshifttracker.md**

### Task 14: Self-terminating breathe animation

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/dm_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/group_page.dart`

- [ ] **Step 1: Read dm_page.dart and group_page.dart**

Find `_breatheController..repeat(reverse: true);` (dm_page line 41, group_page line 42).

- [ ] **Step 2: Add self-termination**

In both files, after the `.repeat(reverse: true)` line, add:

```dart
Future.delayed(const Duration(seconds: 4), () {
  if (mounted) _breatheController.stop();
});
```

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

---

## Phase 5: State Transitions

### Task 15: Build shimmer and empty state widgets

**Files:**
- Create: `app/lib/views/home/decision_board/skeletons/shimmer_card.dart`
- Create: `app/lib/views/home/decision_board/skeletons/shimmer_row.dart`
- Create: `app/lib/views/home/decision_board/empty_state.dart`

- [ ] **Step 1: Create skeletons directory**

```bash
mkdir -p /Users/ramchitturi/hello/app/lib/views/home/decision_board/skeletons
```

- [ ] **Step 2: Write shimmer_card.dart**

```dart
import 'package:flutter/material.dart';
import '../../../../theme.dart';

class ShimmerCard extends StatefulWidget {
  const ShimmerCard({super.key, this.height = 180.0});
  final double height;

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.04, end: 0.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: HelloColors.inkPrimary.withValues(alpha: _opacity.value),
          borderRadius: BorderRadius.circular(42),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write shimmer_row.dart**

```dart
import 'package:flutter/material.dart';
import '../../../../theme.dart';

class ShimmerRow extends StatefulWidget {
  const ShimmerRow({super.key});

  @override
  State<ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<ShimmerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.04, end: 0.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => SizedBox(
        height: 74,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HelloColors.inkPrimary.withValues(alpha: _opacity.value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: HelloColors.inkPrimary.withValues(alpha: _opacity.value),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: HelloColors.inkPrimary.withValues(alpha: _opacity.value),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write empty_state.dart**

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../utils/haptics.dart';
import 'plasma/plasma.dart';

class HelloEmptyState extends StatelessWidget {
  const HelloEmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String headline;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: HelloColors.inkTertiary),
            const SizedBox(height: 16),
            Text(headline, style: HelloText.heading, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: HelloText.small.copyWith(color: HelloColors.inkSecondary), textAlign: TextAlign.center),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HelloHaptic.tap();
                  onCta!();
                },
                child: PlasmaFill(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Text(ctaLabel!, style: HelloText.small.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 6: Update nightshifttracker.md**

### Task 16: Wire empty states into tab pages

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/chats_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/groups_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/plans_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart`

- [ ] **Step 1: Read each tab page**

- [ ] **Step 2: Add empty state to chats_page.dart**

After the `dms` list is computed, wrap the SliverList in a conditional:

```dart
if (dms.isEmpty)
  const SliverFillRemaining(
    child: HelloEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      headline: 'No conversations yet',
      body: 'Start chatting with someone',
    ),
  )
else
  SliverList.builder(/* existing code */)
```

Add import: `import '../empty_state.dart';`

- [ ] **Step 3: Add empty state to groups_page.dart**

Same pattern with group-specific copy:
```dart
HelloEmptyState(
  icon: Icons.people_outline_rounded,
  headline: 'No groups yet',
  body: 'Create a group or accept an invite',
)
```

- [ ] **Step 4: Add empty state to plans_page.dart**

```dart
HelloEmptyState(
  icon: Icons.map_outlined,
  headline: 'No plans yet',
  body: 'Start planning a trip or event',
)
```

- [ ] **Step 5: Add empty state to home_page.dart**

```dart
HelloEmptyState(
  icon: Icons.home_rounded,
  headline: 'All caught up',
  body: 'Nothing needs your attention right now',
)
```

- [ ] **Step 6: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 7: Update nightshifttracker.md**

---

## Phase 7: Accessibility

### Task 17: Create HelloSemantics utility

**Files:**
- Create: `app/lib/utils/semantics.dart`

- [ ] **Step 1: Write semantics.dart**

```dart
import 'package:flutter/material.dart';

class HelloSemantics extends StatelessWidget {
  const HelloSemantics({
    super.key,
    required this.label,
    this.hint,
    this.isButton = false,
    this.isHeader = false,
    required this.child,
  });

  final String label;
  final String? hint;
  final bool isButton;
  final bool isHeader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      header: isHeader,
      child: child,
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

- [ ] **Step 3: Update nightshifttracker.md**

### Task 18: Add Semantics to all cards and interactive widgets

**Files:**
- Modify: All 10 card files in `cards/`, `message_input_bar.dart`, `bottom_bar.dart`, `tab_chip.dart`, `floating_avatar.dart`, `conversation_list_row.dart`, `chat_bubble.dart`

- [ ] **Step 1: Read each card file**

- [ ] **Step 2: Wrap each card's root GestureDetector or CardShell with Semantics**

For each card, add a `Semantics` widget wrapping the outermost tappable widget. Use the card's actual data properties to construct the label:

Example for `dm_card.dart`:
```dart
Semantics(
  label: '${_displayName()}, ${item.conversation.unreadCount} unread',
  button: true,
  child: CardShell(/* existing code */),
)
```

Apply similar patterns to all 10 card files per the spec table in Phase 7 Task 7.2.

- [ ] **Step 3: Add Semantics to interactive widgets**

Per the spec table in Phase 7 Task 7.3:
- Send button: `Semantics(label: 'Send message', button: true)`
- Mic button: `Semantics(label: 'Voice input', button: true)`
- Compose [+]: `Semantics(label: 'New conversation', button: true)`
- Tab chip: `Semantics(label: '${tab.label} tab', button: true)`
- Avatar: `Semantics(label: 'Your profile', button: true)`
- Conversation row: `Semantics(label: '${name}, ${preview}', button: true)`
- Chat bubble: `Semantics(label: '${sender}: ${text}')`

- [ ] **Step 4: Fix sub-minimum hit targets**

- `floating_avatar.dart`: Wrap the 36px avatar in `SizedBox(width: 44, height: 44)` with `Center` child
- `decision_card_small.dart` vote buttons: Wrap in `SizedBox(width: 44, height: 44)` with `Center` child

- [ ] **Step 5: Verify Semantics count**

```bash
cd /Users/ramchitturi/hello && grep -rn 'Semantics(' app/lib/ | wc -l
# Expected: 20+
```

- [ ] **Step 6: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 7: Update nightshifttracker.md**

---

## WAVE D — Engine Wiring (Phase 8, sequential)

### Task 19: Delete kUseMockData and all mock branches

**Files:**
- Modify: `app/lib/providers/mock_data.dart` (rename to `seed_data.dart`)
- Modify: `app/lib/providers/conversations_provider.dart`
- Modify: `app/lib/providers/feed_provider.dart`
- Modify: All provider files referencing `kUseMockData`

- [ ] **Step 1: Rename mock_data.dart to seed_data.dart**

```bash
cd /Users/ramchitturi/hello/app/lib/providers
mv mock_data.dart seed_data.dart
```

- [ ] **Step 2: Delete kUseMockData constant**

In `seed_data.dart`, delete line 16: `const bool kUseMockData = true;`

Keep `kMockFocusTripId` and all the mock data lists — they become seed/playground data.

- [ ] **Step 3: Update all imports of mock_data.dart**

```bash
cd /Users/ramchitturi/hello && grep -rn "mock_data.dart" app/lib/
```

For each file, change `import 'mock_data.dart'` to `import 'seed_data.dart'`.

- [ ] **Step 4: Remove all kUseMockData branches**

In each provider file, find `if (kUseMockData)` blocks and remove them. The provider should always read from the engine via `_engineOrNull(ref)`. If engine is null, return empty.

Key file: `conversations_provider.dart` line 27-28 — remove the mock branch. The provider always streams from the engine.

- [ ] **Step 5: Verify no kUseMockData references remain**

```bash
cd /Users/ramchitturi/hello && grep -rn 'kUseMockData' app/lib/
# Expected: zero results
```

- [ ] **Step 6: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Fix any errors caused by removed imports or missing references.

- [ ] **Step 7: Update nightshifttracker.md**

### Task 20: Wire DM and Group pages to real engine

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/dm_page.dart`
- Modify: `app/lib/views/home/decision_board/pages/group_page.dart`
- Modify: `app/lib/views/home/decision_board/sheets/dm_sheet.dart`
- Modify: `app/lib/views/home/decision_board/sheets/group_sheet.dart`

- [ ] **Step 1: Read each file**

- [ ] **Step 2: Wire dm_page.dart to ChatSession.messages**

If not already a `ConsumerStatefulWidget`, convert it. Replace the hardcoded `_MockMessage` list with:

```dart
final messagesAsync = ref.watch(
  conversationControllerProvider(widget.item.conversation.id),
);
```

Render with `.when()`:
- `loading:` → `const Center(child: CircularProgressIndicator())`
- `error:` → `HelloEmptyState(icon: Icons.error_outline, headline: 'Could not load messages', body: 'Check your connection')`
- `data: (messages)` → existing `ListView.builder` with `ChatBubble`

Delete `_MockMessage` class and hardcoded list.

Replace `onSend` SnackBar with:
```dart
onSend: (text) {
  HelloHaptic.confirm();
  try {
    ref.read(engineProvider).getSession(widget.item.conversation.id).sendText(text);
  } catch (_) {
    // Engine not initialized — silently fail, empty state handles it
  }
},
```

- [ ] **Step 3: Wire group_page.dart identically**

Same pattern. Delete `_GroupMessage` class and hardcoded list.

- [ ] **Step 4: Wire dm_sheet.dart and group_sheet.dart**

Same pattern — replace hardcoded message lists with `conversationControllerProvider` watch.

- [ ] **Step 5: Delete all remaining mock message classes**

```bash
cd /Users/ramchitturi/hello && grep -rn '_MockMessage\|_GroupMessage\|ZenithMock' app/lib/
# Expected: zero results
```

- [ ] **Step 6: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 7: Update nightshifttracker.md**

### Task 21: Verify auth flow calls initializeEngine

**Files:**
- Read: `app/lib/views/auth/auth_flow_page.dart`

- [ ] **Step 1: Read auth_flow_page.dart**

Search for `initializeEngine` call. It must exist after successful OTP verification.

- [ ] **Step 2: If missing, add the call**

After Firebase auth succeeds (the line where the JWT is obtained), add:
```dart
await initializeEngine(ref, authToken: token, userId: userId);
```

If it already exists, document in nightshifttracker.md that no change was needed.

- [ ] **Step 3: Run dart analyze**

- [ ] **Step 4: Update nightshifttracker.md**

---

## WAVE E — Navigation + New Pages (Phases 9, 10 concurrent)

## Phase 9: Navigation Model

### Task 22: Create DecisionPage, SettlementPage, TripPage

**Files:**
- Create: `app/lib/views/home/decision_board/pages/decision_page.dart`
- Create: `app/lib/views/home/decision_board/pages/settlement_page.dart`
- Create: `app/lib/views/home/decision_board/pages/trip_page.dart`

- [ ] **Step 1: Write decision_page.dart**

Port key content from `decision_sheet.dart` into a full-screen page with `CupertinoPageRoute`. Include: back button, photo/constellation hero, title, eyebrow, consensus score, vote buttons, PlasmaProgressBar. Read `decision_sheet.dart` first to understand the existing structure.

Create a top-level `openDecisionPage(BuildContext context, FeedItem item)` function.

- [ ] **Step 2: Write settlement_page.dart**

Full-screen page: back button, counterparty avatar+name, amount display, reason, Pay/Remind PlasmaFill CTA. Create `openSettlementPage(BuildContext context, FeedItem item)`.

- [ ] **Step 3: Write trip_page.dart**

Full-screen page: back button, trip photo hero, destination+dates, member list, pending count, "Enter Plans" CTA. Create `openTripPage(BuildContext context, FeedItem item)`.

- [ ] **Step 4: Update _card_factory.dart routing**

Read `_card_factory.dart`. Replace:
- Decision card handlers → `openDecisionPage(context, item)`
- Settlement card handler → `openSettlementPage(context, item)`
- Trip card handler → `openTripPage(context, item)`

- [ ] **Step 5: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 6: Update nightshifttracker.md**

## Phase 10: New Pages

### Task 23: Create ItineraryPage

**Files:**
- Create: `app/lib/views/home/decision_board/pages/itinerary_page.dart`

- [ ] **Step 1: Write itinerary_page.dart**

Day-by-day itinerary view. Back button + trip name header. Vertical list of day sections. Each day: date header + list of itinerary blocks (icon + title + time range + status). Create `openItineraryPage(BuildContext context, FeedItem item)`.

Wire into `_card_factory.dart`: `ItineraryFeedItem() => openItineraryPage(context, item)`.

- [ ] **Step 2: Run dart analyze**

- [ ] **Step 3: Update nightshifttracker.md**

### Task 24: Create DiscoveryDetailSheet

**Files:**
- Create: `app/lib/views/home/decision_board/sheets/discovery_detail_sheet.dart`

- [ ] **Step 1: Write discovery_detail_sheet.dart**

Bottom sheet with: image hero, title+location+category, description, "@hello says" placeholder section, "Add to Group" PlasmaFill CTA.

- [ ] **Step 2: Run dart analyze**

- [ ] **Step 3: Update nightshifttracker.md**

### Task 25: Create DeviceLinkingPage with real camera

**Files:**
- Modify: `app/pubspec.yaml` (add mobile_scanner)
- Create: `app/lib/views/settings/device_linking_page.dart`
- Modify: `app/lib/views/settings/device_listing.dart`

- [ ] **Step 1: Add mobile_scanner dependency**

In `pubspec.yaml`, add under dependencies:
```yaml
  mobile_scanner: ^6.0.0
```

```bash
cd /Users/ramchitturi/hello/app && flutter pub get
```

- [ ] **Step 2: Add platform permissions**

iOS `app/ios/Runner/Info.plist` — add:
```xml
<key>NSCameraUsageDescription</key>
<string>hello needs camera access to link your other devices securely.</string>
```

Android `app/android/app/src/main/AndroidManifest.xml` — add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

- [ ] **Step 3: Write device_linking_page.dart**

Full-screen dark background. `MobileScanner` widget in a 250px viewfinder. `CustomClipper` with `PathFillType.evenOdd` mask. `onDetect` callback: extract barcode, `HelloHaptic.celebrate()`, flash overlay, "Device linked" text, auto-dismiss 1.5s.

- [ ] **Step 4: Wire into device_listing.dart**

Replace the "LINK NEW DEVICE" button's empty `onPressed` with:
```dart
onPressed: () => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const DeviceLinkingPage()),
),
```

- [ ] **Step 5: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 6: Update nightshifttracker.md**

---

## WAVE F — Dark Mode (Phase 11, sequential)

### Task 26: Convert HelloColors to brightness-aware getters

**Files:**
- Modify: `app/lib/theme.dart` (major rewrite of HelloColors + HelloText)

- [ ] **Step 1: Read the current theme.dart**

After Waves A-E, theme.dart has been modified by Phases 1, 2, and 3. Read the CURRENT state.

- [ ] **Step 2: Add HelloThemeMode enum above HelloColors**

```dart
enum HelloThemeMode { auto, light, dark }
```

- [ ] **Step 3: Convert HelloColors static const → static Color get**

Replace every `static const Color` that needs dark mode inversion with `static Color get`. Keep colors that are the same in both themes as `static const`.

Follow the exact token list in the spec Phase 11 Task 11.1. The key conversions:
- `canvas`, `surfaceDeep`, `recessed` → brightness-aware getters
- `inkPrimary`, `inkSecondary`, `inkTertiary` → brightness-aware getters
- `liveGreen`, `gold`, `error`, `chrome` → brightness-aware getters
- `accent`, `focusViolet`, `focusAlpine`, `focusOcean`, `focusSunset` → stay const (same in both)
- All `kind*` colors → stay const (low alpha, same in both)
- `pulse`, `scoreHigh`, `scoreLow`, `warmPeach` → stay const

Add `voidBg` and `white` as legacy aliases:
```dart
static Color get voidBg => canvas;
static Color get white => surfaceDeep;
```

- [ ] **Step 4: Convert HelloText const → getter**

Since HelloText references `HelloColors.inkPrimary` etc. (now getters), HelloText styles can no longer be `const`. Change every `static const TextStyle` to `static TextStyle get`:

```dart
static TextStyle get display => TextStyle(
  fontFamily: 'Inter', fontSize: 44, fontWeight: FontWeight.w300,
  letterSpacing: -0.03, height: 1.1, color: HelloColors.inkPrimary,
);
// ... same for all 8 styles
```

- [ ] **Step 5: Convert HelloGlass fills to brightness-aware**

Per spec Phase 11 Task 11.4:
```dart
static Color get whisperFill => HelloColors.isDark
    ? const Color(0x33FFFFFF) : const Color(0xB3FFFFFF);
static Color get veilFill => HelloColors.isDark
    ? const Color(0x4DFFFFFF) : const Color(0xCCFFFFFF);
static Color get curtainFill => HelloColors.isDark
    ? const Color(0x66FFFFFF) : const Color(0xE6FFFFFF);
```

Sigma values and border colors stay const.

- [ ] **Step 6: Remove all const qualifiers on HelloText/HelloColors references across codebase**

```bash
cd /Users/ramchitturi/hello && grep -rn 'const HelloText\.' app/lib/
cd /Users/ramchitturi/hello && grep -rn 'const HelloColors\.' app/lib/ | grep -v theme.dart
```

For each match, remove the `const` keyword. Example: `const HelloText.body` → `HelloText.body`.

- [ ] **Step 7: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

This is the highest-risk step — many files change. Fix all errors before proceeding.

- [ ] **Step 8: Update nightshifttracker.md**

### Task 27: OS auto-detection and 3-way theme picker

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/lib/views/settings/user_menu.dart`

- [ ] **Step 1: Add OS brightness detection in main.dart**

In `_HelloAppState`, add to `didChangeDependencies`:
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  HelloColors.updatePlatformBrightness(MediaQuery.platformBrightnessOf(context));
}
```

Add a `themeModeNotifier` ValueNotifier and listen to it for rebuilds.

- [ ] **Step 2: Build 3-way picker in user_menu.dart**

Replace the empty `onTap` on "Appearance" with a picker showing Auto / Light / Dark options. The current mode is highlighted with PlasmaFill.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 4: Update nightshifttracker.md**

---

## WAVE G — Performance (Phase 12, sequential)

### Task 28: Performance profiling and WebGL testing

**Files:**
- Modify: `app/lib/main.dart` (add performance overlay flag)
- Modify: `app/lib/views/chat/group_chat_page.dart` (fix sigma 40 violation)

- [ ] **Step 1: Add performance overlay toggle**

In `main.dart`, add:
```dart
const bool kShowPerformanceOverlay = false;
```

In `MaterialApp`, add:
```dart
showPerformanceOverlay: kShowPerformanceOverlay,
```

- [ ] **Step 2: Fix sigma 40 violation in group_chat_page.dart**

Read `group_chat_page.dart`. Find `BackdropFilter(sigmaX: 40, sigmaY: 40)` (line 40). Replace with `HelloGlass.curtainSigma`:
```dart
filter: ImageFilter.blur(
  sigmaX: HelloGlass.curtainSigma,
  sigmaY: HelloGlass.curtainSigma,
),
```

- [ ] **Step 3: Run the app and profile scroll performance**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Navigate to HOME tab. Scroll through the masonry grid. Record observations in nightshifttracker.md.

If frame drops occur, document which widgets are heaviest and any fixes applied.

- [ ] **Step 4: Test BackdropFilter on web CanvasKit**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080 --web-renderer canvaskit
```

Open each sheet. Scroll inside each. Check browser console for `WebGL: CONTEXT_LOST_WEBGL`. Record results.

- [ ] **Step 5: Run final dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

- [ ] **Step 6: Final verification battery**

```bash
cd /Users/ramchitturi/hello

# Color discipline
grep -rn '\.withOpacity(' app/lib/
# Expected: 0 results

grep -rn 'HelloColors\.primary' app/lib/ | grep -v 'theme\.dart'
# Expected: 0 results

# Glass discipline
grep -rn 'ImageFilter.blur' app/lib/ | grep -v HelloGlass
# Expected: 0 results

# Brand discipline
grep -rn 'xark' app/lib/
# Expected: 0 results

grep -rn 'Sanctuary\|Summoning' app/lib/
# Expected: 0 results

# Haptics wired
grep -rn 'HelloHaptic\.' app/lib/ | wc -l
# Expected: 16+

# Accessibility wired
grep -rn 'Semantics(' app/lib/ | wc -l
# Expected: 20+

# Mock data burned
grep -rn 'kUseMockData' app/lib/
# Expected: 0 results

grep -rn '_MockMessage\|_GroupMessage\|ZenithMock' app/lib/
# Expected: 0 results
```

- [ ] **Step 7: Update nightshifttracker.md with final results**

---

## Plan Summary

| Wave | Phases | Tasks | Parallelism |
|------|--------|-------|-------------|
| A | 1, 2, 6 | 1-8 | 3 concurrent agents |
| B | 3 | 9-10 | Sequential |
| C | 4, 5, 7 | 11-18 | 3 concurrent agents |
| D | 8 | 19-21 | Sequential |
| E | 9, 10 | 22-25 | 2 concurrent agents |
| F | 11 | 26-27 | Sequential |
| G | 12 | 28 | Sequential |

**Total: 28 tasks across 7 waves.**
