# Night Shift Design System Overhaul — Spec

**Date:** 2026-04-14
**Scope:** 12-phase sequential overhaul — design foundations + engine wiring + accessibility + dark mode + new pages + performance
**Input:** `apr14.md` (Steve Jobs critique), `9PM_Goal.md` (full code audit)
**Outcome:** Every color named and dark-mode-ready, every text style codified, every blur tier documented, every animation justified, every data screen state-complete, every brand reference correct, one real end-to-end chat conversation working, VoiceOver/TalkBack navigable, dark mode toggleable, frame budget measured on web.

---

## Ground Truth (verified 2026-04-14 23:00)

These facts were confirmed by reading every file referenced in this spec. The spec does NOT rely on earlier review snapshots — several items have been fixed since those reviews.

**Already correct (do NOT re-do):**
- `decision_board_page.dart`: TabController length is 4. BottomBar is mounted (lines 101-106). All four pages wired.
- `home_page.dart` (53 lines): Already `ConsumerStatefulWidget` with `AutomaticKeepAliveClientMixin`.
- No-bold mandate: zero `FontWeight.w500+` violations found across all lib/ files.
- `tabs_provider.dart`: 4-tab enum `HomeTab { home, chats, groups, plans }` is correct.

**Still broken (this spec fixes):**
- `theme.dart` (79 lines): Only 4 of 8 documented text styles. `HelloGlass` has dark-era values (4% white fill, 40px blur).
- Inter font not bundled in `pubspec.yaml`.
- ~50 orphan hex color literals across 25 files.
- `error_card.dart:73`: references `HelloColors.surfaceChrome` which does not exist. Compile error.
- `group_expense_page.dart:32`: only `.withOpacity()` call in codebase. Deprecated.
- `group_expense_page.dart:27,32` and `create_group_page.dart:24`: use deprecated `HelloColors.primary`.
- `device_listing.dart`: 4 lines use `Colors.white` for text on `#FAFAFA` background (invisible).
- `feedback_sheet.dart`: 3 lines use `Colors.white` for text on light background (invisible).
- `_card_shell.dart:105,113`: `_ringController` and `_unreadController` call `.repeat(reverse: true)` in `initState` unconditionally. Every card runs 2 unnecessary tickers.
- Zero `HapticFeedback` calls anywhere in the app.
- Zero loading/empty/error states on any data-driven screen.
- Brand name `'xark'` appears in `auth_flow_page.dart:226`, `group_chat_page.dart:64`, `invite_surface.dart:18`.
- Deprecated terminology: `'Sanctuary'` in `direct_message_page.dart:17`, `'The Summoning'` in `create_group_page.dart:18`.

---

## Execution Architecture

12 phases. Parallelized where dependencies allow. Each phase is one agent invocation. Phases within the same wave run as concurrent agents. No wave starts until the previous wave's phases all pass verification.

```
WAVE A (concurrent — no shared file dependencies):
  Phase 1:  Color System             → theme.dart + 13 consumer files
  Phase 2:  Typography System        → pubspec.yaml + theme.dart + ~15 inline TextStyle files
  Phase 6:  Information Architecture → 8 files with brand/terminology fixes + _card_factory.dart

  ⚠ CONFLICT: Phases 1 and 2 both write to theme.dart.
  Resolution: Phase 1 adds HelloColors tokens. Phase 2 adds HelloText styles.
  Phase 1 writes ABOVE the HelloText class. Phase 2 writes INSIDE HelloText.
  No overlapping line ranges. Both agents read the file first and write
  only to their designated section. Phase 2 also writes pubspec.yaml
  (no conflict — Phase 1 does not touch pubspec).

WAVE B (sequential — depends on Wave A's theme.dart being complete):
  Phase 3:  Glass Hierarchy          → theme.dart HelloGlass rewrite + 10 BackdropFilter files

WAVE C (concurrent — no shared dependencies after Wave B):
  Phase 4:  Animation + Haptics      → _card_shell.dart + haptics.dart (new) + ~12 interactive files
  Phase 5:  State Transitions        → 6 new skeleton/empty files + 6 page/sheet files
  Phase 7:  Accessibility            → Semantics on all cards + interactive widgets + hit targets

WAVE D (sequential — depends on Wave C's haptics + state widgets):
  Phase 8:  Engine Wiring            → DM/Group pages + sheets → delete kUseMockData, burn the boats

WAVE E (concurrent):
  Phase 9:  Navigation Model         → Decision/Settlement/Trip pages + _card_factory routing
  Phase 10: New Pages                → Itinerary page + Discovery detail + Device linking (real scanner)

WAVE F (sequential — depends on all tokens being final):
  Phase 11: Dark Mode                → HelloColors const→getter, OS auto-detection, glass inversion

WAVE G (sequential — final validation):
  Phase 12: Performance + Web        → Frame profiling + WebGL BackdropFilter testing + fixes
```

**Parallelization rationale (Elon critique):** Independent phases that touch disjoint file sets run concurrently. Phases 1+2+6 share only `theme.dart` with non-overlapping write regions. Phases 4+5+7 touch different widget files. Phases 9+10 create new files that don't conflict. This cuts the 12-phase serial timeline to 7 waves.

**Verification gate (runs after every phase):**
```bash
cd app && dart analyze lib/
```
Must return zero errors. If it fails, the agent fixes issues before marking the phase complete.

**Tracker discipline:**
After completing each task within a phase, the agent appends to `/Users/ramchitturi/hello/nightshifttracker.md`:
```
## Phase N — Task M: [title]
- **What was done:** [specific changes]
- **Why:** [which apr14.md critique this addresses]
- **Files changed:** [list with line ranges]
- **Verification:** dart analyze lib/ → [result]
```

---

## Phase 1: Color System

**Addresses:** apr14.md section "The Color Situation Is a Mess"

**Goal:** Every color in the app has a name in HelloColors. Zero orphan hex literals. Zero deprecated tokens in new code. Zero invisible-text-on-background bugs.

### Task 1.1 — Register card kind gradient colors

**File:** `app/lib/theme.dart`
**What:** Add 7 named constants for card kind tint gradients. These are the semi-transparent overlays in `_card_shell.dart` lines 18-48 that identify card type. They use colors derived from existing theme tokens (tab signatures, trip accents) at low alpha.

Add to `HelloColors`:
```dart
// Card kind tints — semi-transparent overlays identifying card type in feed
static const Color kindDm         = Color(0x2B8B5CF6); // violet, chats signature
static const Color kindDmFade     = Color(0x143B82F6);
static const Color kindGroup      = Color(0x2BF97316); // orange, groups signature
static const Color kindGroupFade  = Color(0x14EC4899);
static const Color kindDecision   = Color(0x2B10B981); // green, decisioning
static const Color kindDecisionFade = Color(0x1406B6D4);
static const Color kindSettlement = Color(0x1EFACC15); // yellow, financial
static const Color kindSettlementFade = Color(0x0E10B981);
static const Color kindItinerary  = Color(0x2B14B8A6); // teal, planning
static const Color kindItineraryFade = Color(0x143B82F6);
static const Color kindMemory     = Color(0x2BFF9B6E); // sunset, nostalgia
static const Color kindMemoryFade = Color(0x14D4536B);
static const Color kindAiNudge    = Color(0x2B4A90E2); // blue, intelligence
static const Color kindAiNudgeFade = Color(0x148B5CF6);
```

**Then update** `_card_shell.dart` lines 18-48: replace all 14 inline `Color(0x...)` values with references to the new `HelloColors.kind*` constants.

### Task 1.2 — Register orphan utility colors

**File:** `app/lib/theme.dart`
**What:** Add named constants for colors that appear in multiple files but are not in the theme.

```dart
// Utility colors — registered to prevent orphan hex literals
static const Color chrome       = Color(0xFFF0EFF4); // lavender gray, dividers, icon tint
static const Color pulse        = Color(0xFFFF385C); // plasma pulse ring, compose icon
static const Color scoreHigh    = Color(0xFF40E0D0); // turquoise, agreement >= 50%
static const Color scoreLow     = Color(0xFFFFA000); // amber, agreement < 50%
static const Color warmPeach    = Color(0xFFFFB380); // constellation hero accent
```

### Task 1.3 — Replace orphan hex values in consumer files

For each file, replace the hardcoded `Color(0x...)` with the corresponding `HelloColors` reference:

| File | Line | Old Value | New Value |
|------|------|-----------|-----------|
| `_card_shell.dart` | 247 | `Color(0xFFFF385C)` | `HelloColors.pulse` |
| `liquid_intent_handle.dart` | 335 | `Color(0xFFFF385C)` | `HelloColors.pulse` |
| `decision_card.dart` | 69 | `Color(0xFF40E0D0)` | `HelloColors.scoreHigh` |
| `decision_card.dart` | 70 | `Color(0xFFFFA000)` | `HelloColors.scoreLow` |
| `decision_sheet.dart` | 405 | `Color(0xFFFFB380)` | `HelloColors.warmPeach` |
| `bottom_bar.dart` | 166 | `Color(0xFFF0EFF4)` | `HelloColors.chrome` |
| `conversation_list_row.dart` | 188 | `Color(0xFFF0EFF4)` | `HelloColors.chrome` |
| `message_input_bar.dart` | 142 | `Color(0xFFF0EFF4)` | `HelloColors.chrome` |

### Task 1.4 — Mark HelloGlass for Phase 3 rewrite

**File:** `app/lib/theme.dart` lines 74-78

The current `HelloGlass` values (4% white fill, 6% white border, blurRadius 40.0) are dark-era holdovers that are invisible on the light theme and violate landmine #8. However, the full fix requires the 3-tier glass hierarchy defined in Phase 3.

**In Phase 1, do NOT rewrite HelloGlass.** Only add a deprecation comment:
```dart
class HelloGlass {
  /// @deprecated — will be replaced with 3-tier system in Phase 3.
  /// Do not use these values in new code.
  static const Color fill = Color(0x0AFFFFFF); // 4% white — invisible on light theme
  static const Color border = Color(0x0FFFFFFF); // 6% white — invisible on light theme
  static const double blurRadius = 40.0; // VIOLATES landmine #8 — do not use
}
```

Phase 3 will replace this entire class with the Whisper/Veil/Curtain system.

### Task 1.5 — Fix dark-on-light text visibility

**File: `device_listing.dart`** — Replace `Colors.white` with theme-correct colors:
- Line 21: `Colors.white` → `HelloColors.inkPrimary`
- Line 33: `Colors.white` → `HelloColors.inkPrimary`
- Line 55: `Colors.white` → `HelloColors.inkPrimary`
- Line 71: `Colors.white` → `HelloColors.inkSecondary` (non-current devices are secondary)

**File: `feedback_sheet.dart`** — Replace:
- Line 62: `Colors.white` → `HelloColors.inkPrimary`
- Line 69: `Colors.white` → `HelloColors.inkPrimary`
- Line 103: `Colors.white` → `HelloColors.inkPrimary`

### Task 1.6 — Fix deprecated token usage

**File: `group_expense_page.dart`**
- Line 27: `HelloColors.primary` → `HelloColors.accent`
- Line 32: `HelloColors.primary.withOpacity(0.1)` → `HelloColors.accent.withValues(alpha: 0.1)`

**File: `create_group_page.dart`**
- Line 24: `HelloColors.primary` → `HelloColors.accent`

### Task 1.7 — Fix error_card.dart compile error

**File: `error_card.dart`**
- Line 73: `HelloColors.surfaceChrome` → `HelloColors.recessed`

This is a compile blocker. Must be fixed.

### Phase 1 verification
```bash
cd app && dart analyze lib/
```
Expected: zero errors. The `surfaceChrome` compile error is the only one currently breaking analysis for this file.

---

## Phase 2: Typography System

**Addresses:** apr14.md section "You Have No Typography System"

**Goal:** Inter font bundled in the binary. 8-level type scale matching DESIGN.md. Zero inline TextStyle declarations that duplicate a named style.

### Task 2.1 — Bundle Inter font

**Action:** Download Inter Regular (400) and Inter Light (300) from Google Fonts. Place in `app/assets/fonts/`.

**File: `app/pubspec.yaml`** — Add after the existing `flutter:` section (which currently has no `fonts:` key):
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

Run `flutter pub get` after this change to ensure the asset is recognized.

### Task 2.2 — Complete the 8-level type scale

**File: `app/lib/theme.dart`** — The `HelloText` class currently defines 4 styles. DESIGN.md documents 8. Add the missing 4.

Add between `title` and `body`:
```dart
static const TextStyle heading = TextStyle(
  fontFamily: 'Inter',
  fontSize: 22,
  fontWeight: FontWeight.w400,
  letterSpacing: -0.01,
  height: 1.3,
  color: HelloColors.inkPrimary,
);
```

Add between `body` and `label`:
```dart
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
```

Add after `label`:
```dart
static const TextStyle mono = TextStyle(
  fontFamily: 'Inter',  // GeistMono when bundled; Inter monospace fallback for now
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.02,
  height: 1.4,
  color: HelloColors.inkPrimary,
);
```

Final HelloText class has 8 styles: `display`, `title`, `heading`, `body`, `small`, `caption`, `label`, `mono`.

### Task 2.3 — Replace inline TextStyles with named styles

The agent must grep for `TextStyle(` across all `app/lib/` files. For each occurrence, determine if it matches one of the 8 named styles (same fontSize and fontWeight). If it does, replace with `HelloText.xxx` or `HelloText.xxx.copyWith(color: ...)` if only the color differs.

**Matching rules:**
- fontSize 44, w300 → `HelloText.display`
- fontSize 28, w400 → `HelloText.title`
- fontSize 22, w400 → `HelloText.heading`
- fontSize 17, w400 → `HelloText.body`
- fontSize 15, w400 → `HelloText.small`
- fontSize 13, w300 → `HelloText.caption`
- fontSize 10, w400 → `HelloText.label`
- fontSize 13, w400, letterSpacing 0.02 → `HelloText.mono`

If an inline TextStyle has a fontSize/weight combo that matches but a different color, use `.copyWith(color: ...)`.

If an inline TextStyle has a fontSize/weight combo that does NOT match any named style, leave it but add a comment: `// Non-standard: justify why this size is needed`.

**Do NOT change text that uses `HelloText.xxx` already** — only touch raw `TextStyle(` declarations.

### Phase 2 verification
```bash
cd app && flutter pub get && dart analyze lib/
```

---

## Phase 3: Glass Hierarchy

**Addresses:** apr14.md section "Your Glass Hierarchy Is Incoherent"

**Goal:** Three documented blur tiers. Every BackdropFilter references a named constant. Zero raw `ImageFilter.blur` with inline sigma values.

### Task 3.1 — Rewrite HelloGlass as a 3-tier system

**File: `app/lib/theme.dart`** — Replace the entire deprecated `HelloGlass` class (Phase 1 Task 1.4 marked it deprecated but did not rewrite it) with the full 3-tier system:

```dart
/// Glass hierarchy — 3 tiers, each with a user-facing semantic.
///
/// Tier 1 "Whisper" — navigation chrome, card surfaces. Content behind
/// is recognizable. Safe in scrolling views.
///
/// Tier 2 "Veil" — sheet headers/footers, popover backgrounds.
/// Background is context, not content.
///
/// Tier 3 "Curtain" — full-attention modals, sheet bodies.
/// Background is dismissed. Max safe blur.
///
/// RULE: Never exceed curtainSigma (24). The WebGL crash ceiling is 30.
/// If a surface "needs more blur," add a tinted color fill instead.
/// RULE: Never use BackdropFilter inside Hero, PageView swipe, or
/// TabBarView transitions. Blur during transitions causes OOM.
class HelloGlass {
  // Tier 1 — Whisper
  static const double whisperSigma  = 14.0;
  static const Color  whisperFill   = Color(0xB3FFFFFF); // 70% white
  static const Color  whisperBorder = Color(0x1A000000); // 10% black

  // Tier 2 — Veil
  static const double veilSigma  = 20.0;
  static const Color  veilFill   = Color(0xCCFFFFFF); // 80% white
  static const Color  veilBorder = Color(0x1A000000); // 10% black

  // Tier 3 — Curtain
  static const double curtainSigma = 24.0;
  static const Color  curtainFill  = Color(0xE6FFFFFF); // 90% white
  // No border — curtain surfaces are full-attention, borders add noise.

  // Chat bubble special case — asymmetric blur is a design choice, not a tier
  static const double bubbleOutboundSigma = 20.0;
  static const double bubbleInboundSigma  = 8.0;
}
```

### Task 3.2 — Replace all raw BackdropFilter sigma values

The agent must find every `ImageFilter.blur(sigmaX:` in `app/lib/` and replace with the appropriate tier constant.

**Mapping (from audit):**

| Current sigma | Tier | Files |
|--------------|------|-------|
| 14 | `HelloGlass.whisperSigma` | `dm_sheet.dart:26`, `group_sheet.dart:26`, `decision_sheet.dart:21`, `settlement_sheet.dart:24`, `attachment_sheet.dart:19`, `new_chat_sheet.dart:19`, `search_sheet.dart:31` |
| 20 | `HelloGlass.veilSigma` | `_card_shell.dart:198` |
| 24 | `HelloGlass.curtainSigma` | `dm_sheet.dart:129`, `group_sheet.dart:156`, `decision_sheet.dart:107`, `settlement_sheet.dart:69`, `attachment_sheet.dart:68`, `new_chat_sheet.dart:80`, `search_sheet.dart:128`, `bottom_bar.dart:92`, `tab_popover.dart:68` |
| Variable (20/8) | `HelloGlass.bubbleOutboundSigma` / `bubbleInboundSigma` | `chat_bubble.dart:276-277` |

For each file, replace `ImageFilter.blur(sigmaX: 14, sigmaY: 14)` with `ImageFilter.blur(sigmaX: HelloGlass.whisperSigma, sigmaY: HelloGlass.whisperSigma)`, and similarly for the other tiers.

For `chat_bubble.dart`, the existing `blurSigma` variable (which is 20.0 for outbound, 8.0 for inbound) should reference `HelloGlass.bubbleOutboundSigma` and `HelloGlass.bubbleInboundSigma` respectively.

### Phase 3 verification
```bash
cd app && dart analyze lib/
```

Also verify: `grep -rn 'ImageFilter.blur' app/lib/ | grep -v HelloGlass` should return zero results (no raw sigma values remain).

---

## Phase 4: Animation Audit + Haptics

**Addresses:** apr14.md sections "You're Building Effects, Not Interactions" and "The 40+ Always-Running AnimationControllers"

**Goal:** Animations start only when needed, stop when not needed. Every interactive element produces haptic feedback.

### Task 4.1 — Fix CardShell lazy animation

**File: `_card_shell.dart`**

Current (line 105): `_ringController` calls `.repeat(reverse: true)` in `initState`.
Current (line 113): `_unreadController` calls `.repeat(reverse: true)` in `initState`.

**Change `initState`:** Remove both `.repeat()` calls. The controllers are created but not started.

**Add a `didChangeDependencies` or build-time check** that starts/stops each controller based on the actual state:

For `_ringController` — start when `isFocused` is true (determined by `ref.watch(centeredFeedItemIdProvider) == widget.id`), stop when false:
```dart
// In build(), after computing isFocused:
if (isFocused && !_ringController.isAnimating) {
  _ringController.repeat(reverse: true);
} else if (!isFocused && _ringController.isAnimating) {
  _ringController.stop();
  _ringController.value = 0.0;
}
```

For `_unreadController` — start only when `widget.ambientPulse` is true:
```dart
if (widget.ambientPulse && !_unreadController.isAnimating) {
  _unreadController.repeat(reverse: true);
} else if (!widget.ambientPulse && _unreadController.isAnimating) {
  _unreadController.stop();
  _unreadController.value = 0.0;
}
```

**Net effect:** From ~40 tickers on 20 cards down to 2-4 tickers (1 focused card + 1-2 unread cards + PlasmaClock).

### Task 4.2 — Create haptics utility

**New file: `app/lib/utils/haptics.dart`**

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

### Task 4.3 — Wire haptics to interactive widgets

The agent must add `HelloHaptic` calls to every interactive callback. The import `import 'package:hello_app/utils/haptics.dart';` (or relative path) is added to each file.

**Specific wiring points:**

| File | Interaction | Haptic |
|------|------------|--------|
| `_card_factory.dart` | Every card `onTap` callback | `HelloHaptic.tap()` |
| `message_input_bar.dart` | Send button `onTap` | `HelloHaptic.confirm()` |
| `chat_bubble.dart` | Swipe-to-reply crossing threshold | `HelloHaptic.confirm()` |
| `chat_bubble.dart` | Long-press to show reactions | `HelloHaptic.tap()` |
| `chat_bubble.dart` | Selecting a reaction emoji | `HelloHaptic.tap()` |
| `decision_card_small.dart` | Vote button tap | `HelloHaptic.tap()` |
| `decision_sheet.dart` | Vote button tap | `HelloHaptic.tap()` |
| `tab_chip.dart` | Tab selection | `HelloHaptic.select()` |
| `tab_popover.dart` | Tab option tap | `HelloHaptic.select()` |
| `bottom_bar.dart` | Compose [+] tap | `HelloHaptic.tap()` |
| `bottom_bar.dart` | Mic button tap | `HelloHaptic.tap()` |
| `conversation_list_row.dart` | Row tap | `HelloHaptic.tap()` |
| `dm_page.dart` | Send in MessageInputBar | `HelloHaptic.confirm()` |
| `group_page.dart` | Send in MessageInputBar | `HelloHaptic.confirm()` |
| `user_settings_page.dart` | Device revoke swipe | `HelloHaptic.warning()` |
| `search_sheet.dart` | Row tap (jump to conversation) | `HelloHaptic.tap()` |

Each haptic call is placed as the FIRST line inside the `onTap`/`onPressed` callback, before any other logic. This ensures the user feels the response instantly.

### Task 4.4 — Self-terminating breathe animation

**File: `dm_page.dart`** (line 41) and **`group_page.dart`** (line 42)

Currently: `_breatheController..repeat(reverse: true);`

Change to:
```dart
_breatheController.repeat(reverse: true);
// Breathe hint plays for 2 full cycles (4 half-cycles), then stops.
// User either noticed the swipe hint or didn't. Infinite loop is nagging.
Future.delayed(const Duration(seconds: 4), () {
  if (mounted) _breatheController.stop();
});
```

### Phase 4 verification
```bash
cd app && dart analyze lib/
```

Also verify: `grep -rn 'HapticFeedback\.' app/lib/` should return zero results (all haptics go through `HelloHaptic`, never raw `HapticFeedback`). And `grep -rn 'HelloHaptic\.' app/lib/` should return 16+ results (one per wiring point above).

---

## Phase 5: State Transitions

**Addresses:** apr14.md section "What Billion-Dollar Apps Actually Have That You Don't" — state transitions

**Goal:** Every data-driven screen handles loading, loaded, empty, and error. No blank white screens.

### Task 5.1 — Build shimmer skeleton widgets

**New directory:** `app/lib/views/home/decision_board/skeletons/`

**New file: `shimmer_card.dart`** (~40 lines)
A single card-shaped skeleton that matches `CardShell` dimensions. Uses `AnimatedContainer` or a `TweenAnimationBuilder` with a single shared controller to pulse opacity between 0.04 and 0.10 on a `HelloColors.recessed` base. Rounded corners at 42px (matching `CardShell`'s `ContinuousRectangleBorder`).

```dart
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 180.0});
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.04, end: 0.10),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Container(
        height: height,
        decoration: BoxDecoration(
          color: HelloColors.inkPrimary.withValues(alpha: value),
          borderRadius: BorderRadius.circular(42),
        ),
      ),
    );
  }
}
```

Note: `TweenAnimationBuilder` with a single `Tween` only animates once. To loop, use `onEnd: () => setState` to toggle the tween direction. Or use a `RepaintBoundary` + `AnimationController` in a `StatefulWidget`. The agent should implement whichever pattern correctly produces a continuous pulse with a SINGLE shared ticker (NOT one per card — use an `InheritedWidget` or a shared `AnimationController` from the parent).

**New file: `shimmer_row.dart`** (~35 lines)
A 74px-tall row skeleton matching `ConversationListRow`: 50px circle on the left, two rectangles on the right (name-width and preview-width). Same pulse animation. Same `HelloColors.recessed` base.

**New file: `shimmer_grid.dart`** (~20 lines)
Renders 6 `ShimmerCard` items in a 2-column masonry-style layout. Uses `SliverMasonryGrid.count` from `flutter_staggered_grid_view` with alternating heights (180, 140, 200, 160, 180, 140) to simulate a real feed.

**New file: `shimmer_list.dart`** (~15 lines)
Renders 8 `ShimmerRow` items in a `SliverList` with 8px vertical spacing.

### Task 5.2 — Build empty state widget

**New file: `app/lib/views/home/decision_board/empty_state.dart`** (~50 lines)

```dart
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
                onTap: () { HelloHaptic.tap(); onCta!(); },
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

### Task 5.3 — Fix error_card.dart compile error

**File: `error_card.dart` line 73**
Replace `HelloColors.surfaceChrome` with `HelloColors.recessed`.

(This was already specified in Phase 1 Task 1.7. If Phase 1 has already been completed, this is a no-op verification. If not, fix it here.)

### Task 5.4 — Wire state transitions into tab pages

Each tab page currently renders content directly from a synchronous provider. The providers return `List<FeedItem>` (not `AsyncValue`). For the mock data path (`kUseMockData = true`), the data is always available synchronously, so the loading state would never show.

**Strategy:** Wrap each page's content in a conditional check. For now (while `kUseMockData = true`), the loading and error states are reachable only via an explicit delay simulation or when `kUseMockData = false` and the engine is involved. The empty state IS reachable — it triggers when the filtered list has 0 items.

**For each page, add the empty state:**

**`chats_page.dart`:**
After computing the `dms` list, before the `SliverList`:
```dart
if (dms.isEmpty)
  SliverFillRemaining(
    child: HelloEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      headline: 'No conversations yet',
      body: 'Start chatting with someone',
    ),
  )
else
  SliverList.builder(...)
```

**`groups_page.dart`:** Same pattern:
```dart
HelloEmptyState(
  icon: Icons.people_outline_rounded,
  headline: 'No groups yet',
  body: 'Create a group or accept an invite',
)
```

**`plans_page.dart`:** Same pattern:
```dart
HelloEmptyState(
  icon: Icons.map_outlined,
  headline: 'No plans yet',
  body: 'Start planning a trip or event',
)
```

**`home_page.dart`:** If the feed is empty (unlikely in mock mode but possible in live):
```dart
HelloEmptyState(
  icon: Icons.home_rounded,
  headline: 'All caught up',
  body: 'Nothing needs your attention right now',
)
```

**For sheets (`dm_sheet.dart`, `group_sheet.dart`):** The mock message lists are hardcoded so they are never empty. Add a comment marking where the empty state check should go when real data is wired:
```dart
// TODO(engine-wire): When messages come from ChatSession.messages stream,
// check for empty list and show HelloEmptyState here.
```

This is the one place a TODO is acceptable — it marks a future engine integration point, not a missing UI component.

### Phase 5 verification
```bash
cd app && dart analyze lib/
```

Also manually verify: each page correctly renders the empty state when its data list is empty. The shimmer widgets should compile and render correctly in isolation.

---

## Phase 6: Information Architecture

**Addresses:** apr14.md sections "The Core Problem" and "What Billion-Dollar Apps Actually Have"

**Goal:** Correct brand identity. Correct terminology. Predictable navigation. Visible SnackBars. Every stub communicates honestly.

### Task 6.1 — Fix brand name references

| File | Line | Old | New |
|------|------|-----|-----|
| `auth_flow_page.dart` | 226 | `'xark'` | `'hello'` |
| `group_chat_page.dart` | 64 | `'ask xark anything...'` | `'ask @hello anything...'` |
| `invite_surface.dart` | 18 | `'INVITE TO XARK'` | `'INVITE TO HELLO'` |

### Task 6.2 — Fix deprecated terminology

| File | Line | Old | New |
|------|------|-----|-----|
| `direct_message_page.dart` | 17 | `'Sanctuary'` | `'Messages'` |
| `create_group_page.dart` | 18 | `'The Summoning'` | `'Create Group'` |

### Task 6.3 — Fix SnackBar visibility

**File: `_card_factory.dart`**
Current (line 28): `SnackBar(backgroundColor: HelloColors.recessed)` — the default SnackBar text color is white, which is invisible on the `#F0F0F0` recessed background.

Fix: Add explicit `content` text styling with `HelloColors.inkPrimary`:
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    backgroundColor: HelloColors.recessed,
    content: Text(
      'Coming in v1.1',
      style: HelloText.small.copyWith(color: HelloColors.inkPrimary),
    ),
  ),
);
```

Apply to ALL stub SnackBars in the file (there are multiple for itinerary, memory, ai_nudge card types).

### Task 6.4 — Verify navigation predictability

The agent must verify the current navigation model by reading `_card_factory.dart` and confirming:
- DM cards → `openDmPage()` (full screen) — correct, keep
- Group cards → `openGroupPage()` (full screen) — correct, keep
- Decision cards → `openDecisionSheet()` (sheet) — acceptable for now, document as follow-up
- Settlement cards → `openSettlementSheet()` (sheet) — acceptable for now
- Search sheet row taps → `openDmPage()` / `openGroupPage()` — correct, keep

No code changes needed here — just verification that the model is consistent. Document any inconsistencies in `nightshifttracker.md`.

### Phase 6 verification
```bash
cd app && dart analyze lib/
```

Also verify: `grep -rn 'xark' app/lib/` should return zero results (all brand references updated). `grep -rn 'Sanctuary' app/lib/` should return zero. `grep -rn 'Summoning' app/lib/` should return zero.

---

---

## Phase 7: Accessibility / Semantics

**Addresses:** apr14.md section "Accessibility. Zero Semantics widgets in ~65 files."

**Goal:** Every interactive widget has a `Semantics` wrapper. VoiceOver and TalkBack can navigate the entire app. Hit targets meet 44pt minimum.

### Task 7.1 — Create HelloSemantics wrapper

**New file: `app/lib/utils/semantics.dart`** (~30 lines)

A thin convenience wrapper that combines `Semantics` with a descriptive label:
```dart
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

### Task 7.2 — Add Semantics to all cards

The agent must wrap every card widget's outermost `GestureDetector` (or the card root) with `Semantics`:

| Card | Semantic label pattern |
|------|----------------------|
| `dm_card.dart` | `'{name}, {unread} unread messages, last message: {preview}'` |
| `group_card.dart` | `'{name} group, {members} members, {unread} unread'` |
| `decision_card_small.dart` | `'Decision: {title}, {score}% agreement'` |
| `decision_card_hero.dart` | `'Decision: {title}, {voted} of {total} voted'` |
| `focus_hero_card.dart` | `'{destination} trip, {days} days away, {pending} pending decisions'` |
| `settlement_card.dart` | `'Settlement: you owe {name} {amount}' or '{name} owes you {amount}'` |
| `trip_card.dart` | `'{destination} trip'` |
| `itinerary_card.dart` | `'Itinerary: {title}'` |
| `memory_card.dart` | `'Memory: {title}'` |
| `ai_nudge_card.dart` | `'Suggestion from @hello: {title}'` |

Each label is constructed from the card's actual data properties at build time. The `Semantics` widget wraps the `GestureDetector` (or `CardShell`) with `button: true` since cards are tappable.

### Task 7.3 — Add Semantics to interactive widgets

| Widget | File | Semantic |
|--------|------|----------|
| Send button | `message_input_bar.dart` | `Semantics(label: 'Send message', button: true)` |
| Mic button | `message_input_bar.dart` | `Semantics(label: 'Voice input', button: true)` |
| Compose [+] | `bottom_bar.dart` | `Semantics(label: 'New conversation', button: true)` |
| Search field | `bottom_bar.dart` | `Semantics(label: 'Search', textField: true)` |
| Tab chip | `tab_chip.dart` | `Semantics(label: '{tab name} tab', button: true)` |
| Avatar | `floating_avatar.dart` | `Semantics(label: 'Your profile', button: true)` |
| Conversation row | `conversation_list_row.dart` | `Semantics(label: '{name}, {preview}, {time}', button: true)` |
| Chat bubble | `chat_bubble.dart` | `Semantics(label: '{sender}: {text}')` |
| Vote buttons | `decision_card_small.dart` | `Semantics(label: 'Love it' / 'Works for me' / 'Not for me', button: true)` |
| Reaction emoji | `chat_bubble.dart` | `Semantics(label: 'React with {emoji}', button: true)` |

### Task 7.4 — Fix sub-minimum hit targets

Minimum tap target: 44x44 points (Apple HIG).

| Widget | Current size | Fix |
|--------|-------------|-----|
| `FloatingAvatar` | 36px | Wrap in `SizedBox(width: 44, height: 44)` with the 36px avatar centered |
| `_VoteButton` in `decision_card_small.dart` | 30x26px | Increase to `SizedBox(width: 44, height: 44)` with content centered |
| Unread dot in `search_sheet.dart` | 6px | The dot itself stays 6px (it's an indicator, not a tap target) — but the parent row is already 74px tall and tappable, so this is OK. No change needed. |

### Phase 7 verification
```bash
cd app && dart analyze lib/
```
Also: `grep -rn 'Semantics(' app/lib/` should return 20+ results.

---

## Phase 8: Engine Wiring — Burn the Boats

**Addresses:** The core gap identified in the full audit — "nothing works, everything is mock."

**Philosophy (Elon critique):** `kUseMockData` is a crutch that lets the team lie to themselves. Delete it. Every provider reads from the real engine. If the engine isn't initialized (pre-auth), providers return empty lists via the existing `_engineOrNull()` guard in `conversations_provider.dart`. The empty state widgets from Phase 5 handle the visual. No mock data. No fallback arrays. No safety net.

**Goal:** Delete `kUseMockData`. Every provider reads from the engine or returns empty. DM and Group pages render real messages from `ChatSession`. Send actually calls `session.sendText()`. The app works with the engine or shows honest empty states — never fake data.

### Task 8.1 — Delete kUseMockData and all mock branches

**File: `app/lib/providers/mock_data.dart`**
- Delete `const bool kUseMockData = true;` (line 16)
- Keep `kMockFocusTripId` (used for focus trip pinning, not mock data)
- Keep the mock data LISTS themselves (`mockConversations`, `mockTrips`, etc.) — they become seed data for the `onboarding/playground` path, not the default path. Rename the file to `seed_data.dart` to reflect its new purpose.

**File: `app/lib/providers/conversations_provider.dart`**
- Remove the `if (kUseMockData)` branch (line 27-28). The provider now always reads from the engine via `_engineOrNull(ref)`. If engine is null (pre-auth), it returns `Stream.value(const [])`.
- The empty state widgets from Phase 5 handle the visual for empty lists.

**File: `app/lib/providers/feed_provider.dart`**
- Remove all `if (kUseMockData)` branches. The feed provider reads from `conversationsStreamProvider` and other real providers. If they return empty, the feed is empty, and the empty state widget renders.

**All other provider files** that reference `kUseMockData`:
- `decisions_provider.dart`, `trips_provider.dart`, `settlements_provider.dart`, `itinerary_provider.dart`, `focus_provider.dart`, `home_state_provider.dart`
- For each: remove the `if (kUseMockData)` branch. The real provider path handles the null-engine case via `_engineOrNull()` or `try/catch`.

**Grep verification:** After this task, `grep -rn 'kUseMockData' app/lib/` returns zero results.

### Task 8.2 — Wire DmPage to ChatSession.messages

**File: `dm_page.dart`**

Currently: 12 hardcoded `_MockMessage` entries built inline in `build()`.

Change: The page must become a `ConsumerStatefulWidget` (if not already). Watch the real message stream:

```dart
final messagesAsync = ref.watch(conversationControllerProvider(widget.item.conversation.id));
```

The `conversationControllerProvider` already exists in `conversations_provider.dart` (line 85-88) and returns `engine.getSession(spaceId).messages`.

Render using `messagesAsync.when()`:
- `loading:` → `ShimmerList()` (from Phase 5)
- `error:` → `HelloEmptyState(icon: Icons.error_outline, headline: 'Could not load messages', ...)`
- `data:` → the existing `ListView.builder` with `ChatBubble` widgets

Map `Message` fields to `ChatBubble` props:
- `message.content` → `text`
- `message.senderId == currentUserId` → `isOutbound`
- `message.senderId` → `senderId`
- `message.status` → `status`
- `message.createdAt` → derive `showTimeHeader` from time gaps between consecutive messages (>5 min gap = show header)

Delete the `_MockMessage` class and hardcoded list entirely. No fallback.

### Task 8.3 — Wire MessageInputBar to session.sendText()

**File: `dm_page.dart`**

Currently: `onSend` shows a SnackBar.

Replace:
```dart
onSend: (text) {
  HelloHaptic.confirm();
  final engine = ref.read(engineProvider);
  engine.getSession(widget.item.conversation.id).sendText(text);
},
```

No mock path. No SnackBar. The message goes to the engine. The engine encrypts and sends. The `conversationControllerProvider` stream emits the new message. The UI updates automatically.

If the engine throws (not initialized), the `try/catch` in `_engineOrNull` handles it gracefully. The message simply doesn't appear — and the error state from Phase 5 can surface if needed.

### Task 8.4 — Wire GroupPage to ChatSession.messages

Same pattern as Task 8.2 but for `group_page.dart`. Delete `_GroupMessage` class and hardcoded list.

### Task 8.5 — Wire GroupPage MessageInputBar to session.sendText()

Same pattern as Task 8.3 but for `group_page.dart`.

### Task 8.6 — Wire DmSheet and GroupSheet to real messages

**Files: `dm_sheet.dart`, `group_sheet.dart`**

Delete hardcoded `_MockMessage` / `_GroupMessage` lists. Convert to `ConsumerStatefulWidget` (if not already). Watch `conversationControllerProvider(conversation.id)`. Render with `.when()`:
- `loading:` → shimmer
- `error:` → error state
- `data:` → existing `ChatBubble` list

### Task 8.7 — Verify auth_flow_page.dart calls initializeEngine

**File: `auth_flow_page.dart`**

Read the file. The existing 401-line auth flow MUST call `initializeEngine()` after successful OTP verification. Verify this is already the case. If not, add the call after the Firebase auth succeeds:

```dart
await initializeEngine(ref, authToken: result.accessToken, userId: result.userId);
```

The `initializeEngine` function already exists in `main.dart` and calls `ChatEngineImpl.initialize(...)` + `_container.updateOverrides(...)`.

**Do NOT rewrite the auth flow.** Only verify the engine bootstrap call exists at the right point.

### Task 8.8 — Delete inline mock messages from all remaining files

Grep for `_MockMessage`, `_GroupMessage`, `ZenithMock`, and any `const <...>[` hardcoded message arrays across `app/lib/views/`. Every inline mock message list must be deleted and replaced with a provider watch or an empty state.

**The only place seed/demo data is permitted** is in the renamed `seed_data.dart` file, and it is only consumed via a `playground` provider for first-time onboarding (not the default path).

### Phase 8 verification
```bash
cd app && dart analyze lib/
grep -rn 'kUseMockData' app/lib/  # must return zero results
grep -rn '_MockMessage\|_GroupMessage\|ZenithMock' app/lib/  # must return zero results
```

### Phase 8 verification
```bash
cd app && dart analyze lib/
```
Also: with `kUseMockData = true`, the app should behave exactly as before (mock data in lists). With `kUseMockData = false` (manual flip for testing), the DM page should attempt to load real messages from the engine.

---

## Phase 9: Navigation Model — Decision Page vs. Sheet

**Addresses:** "Predictability. In iMessage, every conversation row behaves identically."

**Goal:** Establish a single, documented navigation rule and make the codebase follow it.

### Task 9.1 — Define the navigation rule

The rule: **Content viewing = full-screen page. Creation/configuration = bottom sheet.**

| Action | Type | Target |
|--------|------|--------|
| Tap DM card | View content | `openDmPage()` — full screen |
| Tap Group card | View content | `openGroupPage()` — full screen |
| Tap Decision card | View content | **NEW: `openDecisionPage()`** — full screen |
| Tap Settlement card | View content | **NEW: `openSettlementPage()`** — full screen |
| Tap Trip card | View content | **NEW: `openTripPage()`** — full screen |
| Tap [+] compose | Create | `openNewChatSheet()` — bottom sheet |
| Tap search | Navigate | `openSearchSheet()` — bottom sheet |
| Tap attachment | Configure | `openAttachmentSheet()` — bottom sheet |

### Task 9.2 — Create DecisionPage (full screen)

**New file: `app/lib/views/home/decision_board/pages/decision_page.dart`** (~150 lines)

Port the content from `decision_sheet.dart` into a full-screen `CupertinoPageRoute` page. The page has:
- Back button (top-left)
- Photo or constellation hero (reuse from decision_sheet)
- Title, eyebrow, consensus score
- Vote buttons (reuse `_BigVoteButton` from decision_sheet)
- `PlasmaProgressBar` for agreement score

The sheet version (`decision_sheet.dart`) stays as-is for now — it can be deprecated later. The page is the canonical viewing path.

### Task 9.3 — Update _card_factory.dart routing

Replace decision card tap handlers:
```dart
// Old:
DecisionSmallFeedItem() => openDecisionSheet(context, item),
DecisionHeroFeedItem() => openDecisionSheet(context, item),

// New:
DecisionSmallFeedItem() => openDecisionPage(context, item),
DecisionHeroFeedItem() => openDecisionPage(context, item),
```

### Task 9.4 — Create stub pages for Settlement and Trip

**New file: `app/lib/views/home/decision_board/pages/settlement_page.dart`** (~80 lines)

Full-screen page showing settlement details. Port key content from `settlement_sheet.dart`:
- Back button
- Counterparty name + avatar
- Amount (large display)
- Reason
- Pay/Remind button (PlasmaFill CTA)

**New file: `app/lib/views/home/decision_board/pages/trip_page.dart`** (~80 lines)

Full-screen page for trip details:
- Back button
- Trip photo hero
- Destination + dates
- Member list
- Pending decision count
- "Enter Plans" CTA → navigates to PlansView

### Task 9.5 — Update _card_factory.dart for settlement and trip

Replace SnackBar stubs with real page navigation:
```dart
SettlementFeedItem() => openSettlementPage(context, item),
TripFeedItem() => openTripPage(context, item),
```

Itinerary, Memory, and AiNudge card taps keep the SnackBar stub (but with the visible text fix from Phase 6).

### Phase 9 verification
```bash
cd app && dart analyze lib/
```
Verify: every card type in `_card_factory.dart` either opens a full-screen page or shows a visible "Coming soon" SnackBar. No silent failures.

---

## Phase 10: New Page Creation

**Addresses:** Missing pages identified in the full audit — itinerary, discovery detail, device linking QR.

**Goal:** Build three new pages that fill the biggest content gaps.

### Task 10.1 — ItineraryPage

**New file: `app/lib/views/home/decision_board/pages/itinerary_page.dart`** (~120 lines)

A day-by-day itinerary view for a trip. Reference: React's `ItineraryView.tsx` (200 lines).

Structure:
- Back button + trip name header
- Vertical list of day sections
- Each day: date header + list of `_ItineraryBlock` widgets (flight/hotel/activity)
- Each block: icon (plane/hotel/flag), title, time range, status indicator (booked/pending)

Data source: `ItineraryFeedItem` from the feed, which has `itineraryEvent` with `title`, `type`, `startDate`, `endDate`, `status`.

For mock mode: render from the mock itinerary events in `mock_data.dart`.

Wire into `_card_factory.dart`: `ItineraryFeedItem() => openItineraryPage(context, item)`.

### Task 10.2 — DiscoveryDetailSheet (reusable detail view)

**New file: `app/lib/views/home/decision_board/sheets/discovery_detail_sheet.dart`** (~200 lines)

Reference: Gen 3 `discovery_detail_sheet.dart` (504 lines). Simplified version.

Structure:
- Image hero at top (uses `Image.network` with error/loading builders)
- Title + location + category
- Description text
- "@hello says" AI summary section (placeholder text for now)
- "Add to Group" CTA button (PlasmaFill, onTap shows stub)

This sheet is opened from the explore tab grid items and from AI suggestion cards.

### Task 10.3 — DeviceLinkingPage with real camera scanner

**Philosophy (Steve critique):** "Building a simulated QR scanner is building theater, not a product. Put the camera package in and make it actually read a code."

**Step 10.3a — Add mobile_scanner dependency**

**File: `app/pubspec.yaml`**
Add under `dependencies:`:
```yaml
  mobile_scanner: ^6.0.0
```

Run `flutter pub get`.

**Platform permissions:**
- iOS: Add `NSCameraUsageDescription` to `app/ios/Runner/Info.plist`: `"hello needs camera access to link your other devices securely."`
- Android: Add `<uses-permission android:name="android.permission.CAMERA"/>` to `app/android/app/src/main/AndroidManifest.xml`
- Web: `mobile_scanner` uses `getUserMedia` — no manifest change needed, browser prompts automatically.

**Step 10.3b — Build the page**

**New file: `app/lib/views/settings/device_linking_page.dart`** (~160 lines)

Reference: Gen 3 `device_linking_page.dart` (191 lines). Upgraded from simulated to real.

Structure:
- Full-screen dark background with animated gradient (from Gen 3)
- `MobileScanner` widget filling a centered 250px square viewfinder window
- `CustomClipper` with `PathFillType.evenOdd` masks everything outside the viewfinder (the viewfinder mask technique from Gen 3 — this is the one thing that made that screen technically interesting)
- Instruction text: "Point camera at the QR code on your other device"
- `onDetect: (BarcodeCapture capture)` callback:
  - Extract the first barcode value
  - `HelloHaptic.celebrate()` — heavy impact on successful scan
  - Brief white flash overlay (100ms `AnimatedOpacity`)
  - Display "Device linked" confirmation text
  - Auto-dismiss after 1.5s via `Future.delayed` + `Navigator.pop()`
- If no barcode detected after 30s, show subtle hint: "Make sure the QR code is fully visible"

The actual Sesame protocol handshake (engine.linkDevice) is NOT called — the barcode value is captured and logged but the E2EE device linking logic is a separate engine concern. The page proves the camera works and the UX flow is complete.

Wire into `device_listing.dart`: the "LINK NEW DEVICE" button's empty `onPressed` → `Navigator.push(DeviceLinkingPage())`.

### Phase 10 verification
```bash
cd app && dart analyze lib/
```

---

## Phase 11: Dark Mode Token System

**Addresses:** apr14.md color section — "Build a dark-mode-ready token system now."

**Philosophy (Steve critique):** The app should seamlessly inherit the OS-level system setting by default. A manual toggle is offered as an override — Auto / Light / Dark — exactly like iOS Settings > Display & Brightness. "Auto" is the default. The user never has to configure anything unless they want to.

**Goal:** Every `HelloColors` value resolves through a brightness check. The app auto-detects the OS brightness via `MediaQuery.platformBrightnessOf(context)`. A 3-way settings override (Auto / Light / Dark) persists to local storage.

### Task 11.1 — Convert HelloColors to brightness-aware getters with OS auto-detection

**File: `app/lib/theme.dart`**

Replace `static const Color` with `static Color get` that reads from a brightness source. The brightness source is a `ValueNotifier` that auto-detects from the OS and allows user override:

```dart
/// Theme mode preference — persisted to SharedPreferences.
enum HelloThemeMode { auto, light, dark }

class HelloColors {
  static HelloThemeMode _themeMode = HelloThemeMode.auto;
  static Brightness _platformBrightness = Brightness.light;

  /// Called once from the app root's didChangeDependencies:
  /// HelloColors.updatePlatformBrightness(MediaQuery.platformBrightnessOf(context));
  static void updatePlatformBrightness(Brightness b) => _platformBrightness = b;

  /// Called from settings when user picks Auto / Light / Dark.
  static void setThemeMode(HelloThemeMode mode) => _themeMode = mode;

  /// The resolved brightness — auto reads OS, explicit overrides.
  static bool get isDark => switch (_themeMode) {
    HelloThemeMode.auto => _platformBrightness == Brightness.dark,
    HelloThemeMode.light => false,
    HelloThemeMode.dark => true,
  };

  // Canvas
  static Color get canvas => isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA);
  static Color get surfaceDeep => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  static Color get recessed => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

  // Ink
  static Color get inkPrimary => isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1A1A);
  static Color get inkSecondary => isDark ? const Color(0xFF9E9EA8) : const Color(0xFF6B6B78);
  static Color get inkTertiary => isDark ? const Color(0xFF6B6B78) : const Color(0xFF8A8A94);

  // Brand — same in both themes
  static const Color accent = Color(0xFFFF4D00);

  // Focus trip — same in both themes
  static const Color focusViolet = Color(0xFF7C3AED);
  static const Color focusAlpine = Color(0xFF4A90E2);
  static const Color focusOcean = Color(0xFF14B8A6);
  static const Color focusSunset = Color(0xFFFF9B6E);

  // Status — adjust for contrast
  static Color get liveGreen => isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
  static Color get gold => isDark ? const Color(0xFFD4A520) : const Color(0xFF8B6914);
  static Color get error => isDark ? const Color(0xFFEF6C50) : const Color(0xFFC43D08);

  // Utility — from Phase 1
  static Color get chrome => isDark ? const Color(0xFF2D2D35) : const Color(0xFFF0EFF4);
  static const Color pulse = Color(0xFFFF385C);
  static const Color scoreHigh = Color(0xFF40E0D0);
  static const Color scoreLow = Color(0xFFFFA000);
  static const Color warmPeach = Color(0xFFFFB380);

  // Card kind tints — same in both themes (already low alpha)
  static const Color kindDm = Color(0x2B8B5CF6);
  // ... (all kind* constants stay const — they're semi-transparent overlays)

  // Backward compat
  static const Color primary = Color(0xFFD4536B);

  // Legacy aliases
  static Color get voidBg => canvas;
  static Color get white => surfaceDeep;
}
```

**CRITICAL:** `HelloText` styles reference `HelloColors.inkPrimary` etc. Since those are now getters instead of const, `HelloText` styles can no longer be `const`. Change them to `static TextStyle get`:

```dart
static TextStyle get body => TextStyle(
  fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w400,
  height: 1.5, color: HelloColors.inkPrimary,
);
```

This is a significant change. Every `const HelloText.body` in the codebase becomes `HelloText.body` (dropping `const`). The agent must grep for `const HelloText\.` and `const.*HelloText\.` and remove the `const` qualifier.

### Task 11.2 — OS auto-detection in app root

**File: `main.dart` — `_HelloAppState`**

In `didChangeDependencies`, read the OS brightness and push it to HelloColors:
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  HelloColors.updatePlatformBrightness(MediaQuery.platformBrightnessOf(context));
}
```

This runs automatically when the OS switches between light and dark mode. No user action needed. The app rebuilds because `didChangeDependencies` triggers `setState` via the existing `WidgetsBindingObserver.didChangePlatformBrightness`.

Add a `themeModeNotifier` `ValueNotifier<HelloThemeMode>` at the app root. `HelloApp` listens to it and calls `setState` when the user changes the preference. Default value: `HelloThemeMode.auto`.

### Task 11.3 — 3-way theme picker in user_menu.dart

**File: `user_menu.dart`**

The "Appearance (Plasma Engine)" menu item currently has `onTap: () {}`.

Replace with a 3-option picker (inline or via a small bottom sheet):

```dart
// Three tappable rows:
// [Auto]  — uses OS setting (default, highlighted)
// [Light] — forces light
// [Dark]  — forces dark

onTap: (HelloThemeMode mode) {
  HelloHaptic.select();
  HelloColors.setThemeMode(mode);
  themeModeNotifier.value = mode;
  // Persist to SharedPreferences for next app launch
},
```

The current mode is highlighted with a `PlasmaFill` background. The other two options are plain text. This matches iOS Settings > Display & Brightness exactly.

### Task 11.4 — Update glass tiers for dark mode

**File: `app/lib/theme.dart` — HelloGlass**

Glass fills need to invert for dark mode:
```dart
static Color get whisperFill => HelloColors.isDark
    ? const Color(0x33FFFFFF)   // 20% white on dark
    : const Color(0xB3FFFFFF);  // 70% white on light

static Color get veilFill => HelloColors.isDark
    ? const Color(0x4DFFFFFF)   // 30% white on dark
    : const Color(0xCCFFFFFF);  // 80% white on light

static Color get curtainFill => HelloColors.isDark
    ? const Color(0x66FFFFFF)   // 40% white on dark
    : const Color(0xE6FFFFFF);  // 90% white on light
```

### Phase 11 verification
```bash
cd app && dart analyze lib/
```
Also: toggle dark mode via the menu → verify the app renders with inverted colors. Canvas becomes dark, text becomes light, glass tints adjust.

---

## Phase 12: Performance Profiling + Web Testing

**Addresses:** apr14.md animation section and WebGL crash ceiling.

**Goal:** Measure actual frame performance. Identify and fix any BackdropFilter that crashes on Flutter Web with CanvasKit.

### Task 12.1 — Add performance overlay toggle

**File: `main.dart`**

Add a debug flag:
```dart
const bool kShowPerformanceOverlay = false; // flip for profiling

// In MaterialApp:
showPerformanceOverlay: kShowPerformanceOverlay,
```

### Task 12.2 — Profile scroll performance on masonry grid

The agent must:
1. Run the app: `cd app && flutter run -d chrome --web-port 8080`
2. Enable the performance overlay
3. Scroll through the HOME tab masonry grid
4. Record frame times in `nightshifttracker.md`: average frame time, worst frame time, whether any frames exceed 16.67ms

If frames exceed budget during passive scroll:
- Identify the heaviest widget via `debugPrintRebuildDirtyWidgets = true`
- If `CardShell`'s `BackdropFilter` is the bottleneck, reduce `veilSigma` from 20 to 14 for cards
- If `AmbientMesh` is the bottleneck, reduce the number of gradient circles from 5 to 3

### Task 12.3 — Test BackdropFilter on web CanvasKit

The agent must:
1. Run: `cd app && flutter run -d chrome --web-port 8080 --web-renderer canvaskit`
2. Navigate to each sheet (DM, Group, Decision, Search, Settlement, Attachment, NewChat)
3. Scroll inside each sheet
4. Verify no WebGL context loss (console error: "WebGL: CONTEXT_LOST_WEBGL")
5. Record results in `nightshifttracker.md`

If any WebGL context loss occurs:
- Identify which BackdropFilter is the culprit
- Reduce its sigma to `HelloGlass.whisperSigma` (14)
- If multiple filters are stacked (e.g., sheet overlay sigma 14 + sheet body sigma 24), remove the overlay's BackdropFilter and use a solid `Colors.black.withValues(alpha: 0.3)` scrim instead

### Task 12.4 — Test BackdropFilter in transitions

The agent must verify no BackdropFilter runs during page transitions:
1. Navigate from home → DM page (CupertinoPageRoute)
2. Navigate from home → Group page → swipe to Plans (PageView)
3. Navigate from Group → PlanDashboard (PortalPageRoute with Hero)

Check `group_chat_page.dart`'s `BackdropFilter(sigmaX: 40)` inside a Hero — this is the known violation. Fix: reduce to `HelloGlass.curtainSigma` (24) or remove the BackdropFilter from the Hero widget and add it back after the Hero animation completes using an `AnimatedBuilder` on the secondary animation.

### Phase 12 verification
`nightshifttracker.md` contains measured frame times and WebGL test results for every screen.

---

## Complete File Change Inventory

### New files (14)
```
app/assets/fonts/Inter-Regular.ttf
app/assets/fonts/Inter-Light.ttf
app/lib/utils/haptics.dart
app/lib/utils/semantics.dart
app/lib/views/home/decision_board/skeletons/shimmer_card.dart
app/lib/views/home/decision_board/skeletons/shimmer_row.dart
app/lib/views/home/decision_board/empty_state.dart
app/lib/views/home/decision_board/pages/decision_page.dart
app/lib/views/home/decision_board/pages/settlement_page.dart
app/lib/views/home/decision_board/pages/trip_page.dart
app/lib/views/home/decision_board/pages/itinerary_page.dart
app/lib/views/home/decision_board/sheets/discovery_detail_sheet.dart
app/lib/views/settings/device_linking_page.dart
nightshifttracker.md
```

### Modified files (~55)
```
Wave A — Phases 1, 2, 6 (concurrent):
  app/lib/theme.dart (Phase 1: new color tokens; Phase 2: new text styles)
  app/pubspec.yaml (Phase 2: fonts + mobile_scanner)
  app/lib/views/home/decision_board/cards/_card_shell.dart
  app/lib/views/home/decision_board/liquid_intent_handle.dart
  app/lib/views/home/decision_board/cards/decision_card.dart
  app/lib/views/home/decision_board/sheets/decision_sheet.dart
  app/lib/views/home/decision_board/bottom_bar.dart
  app/lib/views/home/decision_board/conversation_list_row.dart
  app/lib/views/home/decision_board/message_input_bar.dart
  app/lib/views/settings/device_listing.dart
  app/lib/views/os/feedback_sheet.dart
  app/lib/views/os/error_card.dart
  app/lib/views/finance/group_expense_page.dart
  app/lib/views/group/create_group_page.dart
  app/lib/views/auth/auth_flow_page.dart
  app/lib/views/chat/group_chat_page.dart
  app/lib/views/home/decision_board/pages/invite_surface.dart
  app/lib/views/chat/direct_message_page.dart
  app/lib/views/home/decision_board/_card_factory.dart
  ~15 files with inline TextStyle (identified by grep at execution time)

Wave B — Phase 3:
  app/lib/theme.dart (HelloGlass 3-tier rewrite)
  All 8 sheet files + _card_shell + bottom_bar + tab_popover + chat_bubble

Wave C — Phases 4, 5, 7 (concurrent):
  app/lib/views/home/decision_board/cards/_card_shell.dart (lazy animation)
  ~12 interactive files (haptics wiring)
  4 tab page files (empty state wiring)
  ~18 files (Semantics wrapping on all cards + interactive widgets)

Wave D — Phase 8 (burn the boats):
  app/lib/providers/mock_data.dart → renamed to seed_data.dart
  app/lib/providers/conversations_provider.dart (remove kUseMockData branches)
  app/lib/providers/feed_provider.dart (remove kUseMockData branches)
  app/lib/providers/decisions_provider.dart
  app/lib/providers/trips_provider.dart
  app/lib/providers/settlements_provider.dart
  app/lib/providers/itinerary_provider.dart
  app/lib/providers/focus_provider.dart
  app/lib/views/home/decision_board/pages/dm_page.dart (real ChatSession)
  app/lib/views/home/decision_board/pages/group_page.dart (real ChatSession)
  app/lib/views/home/decision_board/sheets/dm_sheet.dart (real messages)
  app/lib/views/home/decision_board/sheets/group_sheet.dart (real messages)
  app/lib/views/home/decision_board/pages/home_page.dart (delete ZenithMock)

Wave E — Phases 9, 10 (concurrent):
  app/lib/views/home/decision_board/_card_factory.dart (route to pages)
  app/lib/views/settings/device_listing.dart (wire to DeviceLinkingPage)

Wave F — Phase 11:
  app/lib/theme.dart (const→getter conversion)
  app/lib/main.dart (OS brightness auto-detect + themeModeNotifier)
  app/lib/views/settings/user_menu.dart (3-way picker)
  ~30 files (remove const from HelloText/HelloColors references)

Wave G — Phase 12:
  app/lib/main.dart (performance overlay flag)
  app/lib/views/chat/group_chat_page.dart (fix sigma 40 Hero violation)
```

### Deleted files (1)
```
app/lib/providers/mock_data.dart  → renamed to seed_data.dart (Phase 8)
```

### Renamed files (1)
```
app/lib/providers/mock_data.dart → app/lib/providers/seed_data.dart
```

---

## Success Criteria

After all 12 phases (7 waves) complete:

1. `cd app && dart analyze lib/` returns zero errors
2. `grep -rn 'Color(0x' app/lib/ | grep -v 'HelloColors\|theme\.dart\|plasma'` returns only Colors that have been deliberately kept with inline comments justifying why
3. `grep -rn 'ImageFilter.blur' app/lib/ | grep -v HelloGlass` returns zero results
4. `grep -rn 'xark' app/lib/` returns zero results
5. `grep -rn 'Sanctuary\|Summoning' app/lib/` returns zero results
6. `grep -rn 'HelloHaptic\.' app/lib/` returns 16+ results
7. `grep -rn '\.withOpacity(' app/lib/` returns zero results
8. `grep -rn 'HelloColors\.primary' app/lib/ | grep -v 'theme\.dart'` returns zero results
9. Every tab page has an empty state `HelloEmptyState` widget for the zero-items case
10. `grep -rn 'Semantics(' app/lib/` returns 20+ results
11. `grep -rn 'kUseMockData' app/lib/` returns **zero results** — mock data is deleted, boats are burned
12. `grep -rn '_MockMessage\|_GroupMessage\|ZenithMock' app/lib/` returns **zero results**
13. DM page and Group page render messages from `conversationControllerProvider` (real engine stream)
14. MessageInputBar `onSend` calls `session.sendText()` (real engine send)
15. Every card type in `_card_factory.dart` opens either a full-screen page or shows a visible SnackBar
16. Dark mode auto-detects from OS setting; 3-way override (Auto/Light/Dark) works
17. `mobile_scanner` package is in pubspec.yaml; DeviceLinkingPage opens a real camera viewfinder
18. `nightshifttracker.md` has performance measurements for scroll and WebGL
19. `nightshifttracker.md` has an entry for every task in every phase
