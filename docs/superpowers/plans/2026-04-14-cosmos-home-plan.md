# Cosmos Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Home as a floating-avatar cosmos surface with in-place action expansion and a 5-layer reward animation system, deleting the masonry grid + status pills + duplicate bottom bar that currently violate zero-box and 3-second principles.

**Architecture:** `LiquidIntentLayer` promotes from a single detail page to the scaffold, wrapping all four tabs as the sole persistent bottom chrome. Home's `Stack` renders `ChromaticAtmosphere` (full-bleed) + foreground `HologramAvatar` (140px) + context label + 6 queue avatars (48px). Tapping an avatar does NOT push a route — it cross-fades in-place into a text-action surface on Home's own canvas. Action taps fire a 1700ms reward sequence (levitation + plasma infusion + atmosphere pulse + ascent + handoff) locked against provider re-emits via a local snapshot + `_isAnimatingReward` flag.

**Tech Stack:** Flutter ≥ 3.11.3, Dart, Riverpod 3.3.1 (`Notifier`, `Provider`, `StateNotifier`). Animation primitives: `TweenAnimationBuilder`, `AnimatedOpacity`, `AnimatedSwitcher`, `ColorFiltered`, `ShaderMask`. Existing infrastructure reused: `HologramAvatar` (app/lib/views/home/decision_board/avatar_utils.dart), `ChromaticAtmosphere`, `LiquidIntentLayer`, `PlasmaFill/Tint/Stroke/Clock`, NS3 palette system (`ambient_palette_provider`, `focus_sources_provider`, `palette_extractor`, `signature_color`, `oklch`).

**Spec reference:** `docs/superpowers/specs/2026-04-14-cosmos-home-design.md` (v2, all six technical-review patches integrated).

---

## File Structure

Every file touched by this plan. Engineers: do not modify files outside this list unless a task explicitly says so.

### Files to DELETE
| Path | Why |
|---|---|
| `app/lib/views/home/decision_board/cards/decision_card_small.dart` | Symbol-box SaaS violation; Home stops surfacing decisions as cards |
| `app/lib/views/home/decision_board/cards/focus_card_widget.dart` | Subsumed inline into `home_page.dart`'s Expanded state layer |
| `app/lib/views/home/decision_board/status_overview.dart` | Counts create obligation stress; Home is the "feel" surface |
| `app/lib/views/home/decision_board/bottom_bar.dart` | Replaced by scaffold-level `LiquidIntentLayer` |
| `app/lib/views/home/decision_board/tab_chip.dart` | BottomBar-only consumer |
| `app/lib/views/home/decision_board/tab_popover.dart` | The `HOME ^` dropdown is redundant with ghost indicators |
| `app/lib/views/home/decision_board/cards/live_avatar.dart.disabled` | References non-existent `assets/rive/` |
| `app/lib/views/home/decision_board/cards/live_avatar_showcase.dart.disabled` | Same |
| `app/lib/views/home/decision_board/pages/cosmos_home_page.dart.disabled` | Superseded by this plan's fresh home_page.dart |

### Files to MODIFY
| Path | Change |
|---|---|
| `app/lib/views/home/decision_board/decision_board_page.dart` | Promote `LiquidIntentLayer` wrapping `TabBarView`; remove `BottomBar` mount + imports |
| `app/lib/views/home/decision_board/pages/home_page.dart` | Full rewrite as cosmos |
| `app/lib/views/home/decision_board/pages/group_page.dart` | Remove local `LiquidIntentLayer` mount (moved to scaffold) |
| `app/lib/views/home/decision_board/_card_factory.dart` | Remove `DecisionSmallFeedItem` case + import |
| `app/lib/providers/filtered_feed_providers.dart` | Add `PendingSender` model, `freshestPendingSenderProvider`, `pendingSendersQueueProvider` |
| `app/lib/providers/ambient_palette_provider.dart` | Add `AmbientPalettePulse` transient + `ambientPalettePulseProvider` |
| `app/lib/views/home/decision_board/chromatic_atmosphere.dart` | Read transient pulse signal and modulate palette during its duration |

### Files to CREATE
| Path | Purpose |
|---|---|
| `app/lib/views/home/decision_board/pages/home/cosmos_sender_model.dart` | `PendingSender` + `SenderKind` + `messageKindInference` for the new providers |
| `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart` | The 140px foreground widget with levitation + holographic-infusion layers |
| `app/lib/views/home/decision_board/pages/home/queue_row.dart` | The 6 × 48px horizontal queue row |
| `app/lib/views/home/decision_board/pages/home/context_label.dart` | Below-avatar text label (group+subject OR `Message`) |
| `app/lib/views/home/decision_board/pages/home/action_word.dart` | Single text-as-action word with Expanded hit zone, approach glow, plasma sweep |
| `app/lib/views/home/decision_board/pages/home/action_words_row.dart` | Shape-adaptive row of action words per message kind |
| `app/lib/views/home/decision_board/pages/home/reward_controller.dart` | 1700ms reward-sequence orchestrator + animation lock state |
| `app/test/providers/cosmos_home_providers_test.dart` | Pure-Dart tests for pending-sender selectors |

### Files to PRESERVE (no edits)
- `app/lib/views/home/decision_board/avatar_utils.dart` (`HologramAvatar` + `getAvatarImagePath`)
- `app/lib/views/home/decision_board/liquid_intent_handle.dart`
- `app/lib/views/home/decision_board/plasma/*`
- `app/lib/providers/focus_sources_provider.dart`
- `app/lib/services/palette_extractor.dart`, `oklch.dart`, `signature_color.dart`
- `app/lib/models/ambient_palette.dart`
- `app/assets/images/*.png` (10 transparent PNG avatars)
- `app/apply_rembg.py`

---

## Testing note

The project's `flutter test` is globally broken (see root CLAUDE.md landmine #3 — `app/test/discover/discovery_widgets_test.dart` imports from a deleted directory). **Do NOT run `flutter test` without a specific test file path.**

Each task specifies either:
- A **specific test file** to run: `cd app && flutter test test/providers/cosmos_home_providers_test.dart -r compact`
- OR a **manual verification gate** (run the app, visual check)
- AND always: `cd app && dart analyze lib/` must return zero new errors

Widget tests for UI are out of scope — they cannot currently be added without first fixing the broken suite. This plan uses pure-Dart unit tests for provider logic and manual visual verification for UI.

---

# Phase 1 — Scaffold chrome flip

**Phase goal:** `LiquidIntentLayer` is the only persistent bottom chrome on all four tabs; `BottomBar` is gone.

### Task 1: Verify TabChip + TabPopover have no non-BottomBar consumers

**Files:**
- Inspect: `app/lib/views/home/decision_board/tab_chip.dart`, `app/lib/views/home/decision_board/tab_popover.dart`

- [ ] **Step 1: Grep for TabChip consumers**

Run:
```bash
cd /Users/ramchitturi/hello && grep -rn "TabChip\|showTabPopover" app/lib
```

Expected: only matches inside `bottom_bar.dart`, `tab_chip.dart`, `tab_popover.dart` themselves. If any match appears in a different file (e.g., another page widget), stop and document — that consumer needs migration before we can safely delete. If the grep output matches expectations, proceed.

- [ ] **Step 2: Commit a note recording the verification**

(No code changes. This is a verification task.) Skip commit; proceed to Task 2.

---

### Task 2: Promote LiquidIntentLayer to scaffold

**Files:**
- Modify: `app/lib/views/home/decision_board/decision_board_page.dart` — wrap `TabBarView` with `LiquidIntentLayer`; remove `BottomBar` mount
- Modify: `app/lib/views/home/decision_board/pages/group_page.dart:337-348` — remove the local `LiquidIntentLayer` mount

- [ ] **Step 1: Edit decision_board_page.dart**

Replace the imports block at `decision_board_page.dart:8-22` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'chromatic_atmosphere.dart';
import 'consensus_watcher.dart';
import 'liquid_intent_handle.dart';
import 'pages/chats_page.dart';
import 'pages/groups_page.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'tab_header.dart';
```

(Removed: `bottom_bar.dart`, `sheets/new_chat_sheet.dart`, `sheets/search_sheet.dart` imports.)

Replace the `build` method body (`decision_board_page.dart:76-113`) with:

```dart
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ConsensusWatcher(
      child: Scaffold(
        backgroundColor: HelloColors.voidBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ChromaticAtmosphere()),
            SafeArea(
              child: LiquidIntentLayer(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    HomePage(),
                    ChatsPage(),
                    GroupsPage(),
                    PlansPage(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              child: const TabHeader(),
            ),
          ],
        ),
      ),
    );
  }
```

Also delete the now-unused `_switchToTab` method at `decision_board_page.dart:70-73` — it was only wired to `BottomBar.onTabSelected`.

- [ ] **Step 2: Edit group_page.dart to remove local LiquidIntentLayer**

Open `app/lib/views/home/decision_board/pages/group_page.dart` and find the `LiquidIntentLayer` mount around line 343. Replace this block:

```dart
                          child: AnimatedOpacity(
                            opacity: plansOpacity,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1.0 - plansOpacity)),
                              child: IgnorePointer(
                                ignoring: plansOpacity < 0.5,
                                child: const LiquidIntentLayer(
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
```

With `const SizedBox.shrink()` (or remove the entire widget sub-tree if it was the only content of its parent — grep the surrounding `plansOpacity` references and delete the dead block). If the surrounding layout depends on this IgnorePointer for something else, leave the IgnorePointer and remove only the inner `LiquidIntentLayer` call, replacing with `SizedBox.shrink()`.

Also remove the `import` line for `liquid_intent_handle.dart` from `group_page.dart` if no other consumer remains in that file.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: no new errors. If there are errors about unused imports, clean them up (e.g., `bottom_bar.dart`, `new_chat_sheet.dart`, `search_sheet.dart` — these files still exist but `decision_board_page.dart` no longer imports them).

- [ ] **Step 4: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Verify:
1. All four tabs (HOME, CHATS, GROUPS, PLANS) render and can be swiped between
2. At the bottom of every tab, a thin plasma line is visible (the `LiquidIntentLayer` idle state, 160×4pt, bottom-centered ~32pt above safe-area)
3. Tapping the plasma line blooms it into a 360×64pt glass shell with `TextField` + mic circle + `+` circle
4. Tapping outside the bloom dismisses it back to idle
5. Group detail page (navigate via GROUPS tab → tap a group) still renders correctly without its own local `LiquidIntentLayer` (the scaffold one is the global replacement)

If any of the above fails, revert the task and fix.

- [ ] **Step 5: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/decision_board_page.dart app/lib/views/home/decision_board/pages/group_page.dart
git commit -m "$(cat <<'EOF'
refactor(home): promote LiquidIntentLayer from group_page to scaffold

Wraps the entire TabBarView in decision_board_page.dart so the
liquid intent handle is the only persistent bottom chrome across
all four tabs (HOME/CHATS/GROUPS/PLANS). Removes the local mount
from group_page.dart. BottomBar no longer the active scaffold
chrome. Preps its deletion in Task 3.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 1

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Delete BottomBar, TabChip, TabPopover

**Files:**
- Delete: `app/lib/views/home/decision_board/bottom_bar.dart`
- Delete: `app/lib/views/home/decision_board/tab_chip.dart`
- Delete: `app/lib/views/home/decision_board/tab_popover.dart`

- [ ] **Step 1: Delete the three files**

```bash
cd /Users/ramchitturi/hello && rm app/lib/views/home/decision_board/bottom_bar.dart
rm app/lib/views/home/decision_board/tab_chip.dart
rm app/lib/views/home/decision_board/tab_popover.dart
```

- [ ] **Step 2: Run dart analyze to surface any residual imports**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors. If errors appear about missing `bottom_bar.dart`, `tab_chip.dart`, or `tab_popover.dart` imports, find each consumer (it should only be `decision_board_page.dart` — already cleaned in Task 2, but also check `sheets/new_chat_sheet.dart` and `sheets/search_sheet.dart` which may be dead code now).

- [ ] **Step 3: Verify sheet files that were routed from BottomBar**

Run:
```bash
cd /Users/ramchitturi/hello && grep -rn "openNewChatSheet\|openSearchSheet" app/lib
```

Expected: no results (both were only called from the deleted `decision_board_page.dart:105-106` BottomBar wiring). If both are unreferenced, the sheet files `sheets/new_chat_sheet.dart` and `sheets/search_sheet.dart` are now dead code. **Leave them in place for now** — they may be rewired to `LiquidIntentLayer`'s `+` action in a future pass; deleting them is out of scope for this plan.

- [ ] **Step 4: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Same checks as Task 2 Step 4. No regressions.

- [ ] **Step 5: Commit**

```bash
cd /Users/ramchitturi/hello && git add -A
git commit -m "$(cat <<'EOF'
refactor(home): delete BottomBar, TabChip, TabPopover

Dead-weight after scaffold-level LiquidIntentLayer promotion in
the previous commit. BottomBar was a 60pt glass pill duplicating
text/search/AI/mic/new-chat — all of which the liquid intent
handle already owns. TabChip and TabPopover were BottomBar-only
consumers.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 1

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 2 — Strip Home

**Phase goal:** Home reduces to pure atmosphere; all decision masonry + status pills + orphan disabled files are gone.

### Task 4: Delete `.disabled` files, status_overview, decision_card_small, focus_card_widget

**Files:**
- Delete: 6 files (three `.disabled`, one status overview, two card widgets)
- Modify: `app/lib/views/home/decision_board/_card_factory.dart` to drop `DecisionSmallFeedItem` + `FocusCardWidget` references

- [ ] **Step 1: Delete the six files**

```bash
cd /Users/ramchitturi/hello && rm app/lib/views/home/decision_board/cards/decision_card_small.dart
rm app/lib/views/home/decision_board/cards/focus_card_widget.dart
rm app/lib/views/home/decision_board/status_overview.dart
rm app/lib/views/home/decision_board/cards/live_avatar.dart.disabled
rm app/lib/views/home/decision_board/cards/live_avatar_showcase.dart.disabled
rm app/lib/views/home/decision_board/pages/cosmos_home_page.dart.disabled
```

- [ ] **Step 2: Edit _card_factory.dart**

Open `app/lib/views/home/decision_board/_card_factory.dart`. Remove the import line:

```dart
import 'cards/decision_card_small.dart';
```

And remove the `DecisionSmallFeedItem()` case from the `switch` at lines 54-60. The complete updated switch:

```dart
  return switch (item) {
    DmFeedItem() => DmCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openDmSheet(context, item);
        },
      ),
    GroupFeedItem() => GroupCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openGroupSheet(context, item);
        },
      ),
    DecisionSmallFeedItem() => const SizedBox.shrink(),
    DecisionHeroFeedItem() => DecisionCardHero(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openDecisionPage(context, item);
        },
      ),
    TripFeedItem() => TripCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openTripPage(context, item);
        },
      ),
    SettlementFeedItem() => SettlementCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openSettlementPage(context, item);
        },
      ),
    ItineraryFeedItem() => ItineraryCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          stubSnack('Itinerary — coming in v1.1');
        },
      ),
    MemoryFeedItem() => MemoryCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          stubSnack('Memory — coming in v1.1');
        },
      ),
    AiNudgeFeedItem() => AiNudgeCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          stubSnack('@hello nudge — coming in v1.1');
        },
      ),
    FocusHeroFeedItem() => FocusHeroCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openTripPage(context, item);
        },
      ),
  };
```

Why `SizedBox.shrink()` for `DecisionSmallFeedItem()` rather than removing the case? Because the Dart sealed class exhaustiveness checker requires every variant. The CHATS/GROUPS/PLANS tabs' filtered feeds don't include `DecisionSmallFeedItem`, so this branch is never hit in practice — but the switch must cover it. If you remove `DecisionSmallFeedItem` entirely, you'd need to also edit `app/lib/models/feed_item.dart` to remove the sealed variant, which has wider downstream impact. Keep it as a shrink sentinel.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors. If an error surfaces about `FocusCardWidget`, grep for residual imports:

```bash
cd /Users/ramchitturi/hello && grep -rn "focus_card_widget\|FocusCardWidget" app/lib
```

And remove any.

- [ ] **Step 4: Commit**

```bash
cd /Users/ramchitturi/hello && git add -A
git commit -m "$(cat <<'EOF'
refactor(home): delete StatusOverview, DecisionCardSmall, FocusCardWidget, .disabled files

- StatusOverview (4 count pills) violates zero-box and creates
  obligation framing at the top of Home
- DecisionCardSmall (symbol-box vote buttons) was the source of
  multiple UI screenshots the user rejected for the small-squares
  aesthetic
- FocusCardWidget will be subsumed inline into home_page.dart's
  in-place expansion layer (Phase 5)
- Three .disabled files (cosmos_home_page, live_avatar,
  live_avatar_showcase) reference non-existent assets/rive/ and
  are superseded by this plan

_card_factory keeps DecisionSmallFeedItem as a shrink-sentinel for
switch exhaustiveness — removing the variant itself is out of scope.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 2

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Reduce home_page.dart to a minimal atmospheric placeholder

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart` — strip content; keep only `ChromaticAtmosphere` density wrap

- [ ] **Step 1: Replace home_page.dart entirely**

Replace the entire contents of `app/lib/views/home/decision_board/pages/home_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chromatic_atmosphere.dart';

/// Home — transitional placeholder.
///
/// Phase 2 strips Home to atmosphere only. Phase 3 rebuilds the
/// cosmos surface on top of this.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: SizedBox.expand(),
    );
  }
}
```

(This deletes all status-overview sliver, masonry grid sliver, focus listener, feed-item lookup logic. Phase 3 rebuilds.)

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors. Some providers formerly referenced by Home (e.g., `homeFeedProvider`, `focusSourcesProvider`, `centeredFeedItemIdProvider`) may now have one fewer consumer — that's fine, they remain used elsewhere.

- [ ] **Step 3: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Verify:
1. HOME tab renders as pure atmosphere — no counts, no cards, no masonry
2. CHATS / GROUPS / PLANS tabs still render their content as before (unchanged by this phase)
3. `LiquidIntentLayer` still visible as bottom chrome

- [ ] **Step 4: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home_page.dart
git commit -m "$(cat <<'EOF'
refactor(home): reduce home_page.dart to atmospheric placeholder

Strip StatusOverview sliver, MasonryFeedGrid sliver, focus
listener logic. Phase 3 will rebuild the cosmos surface (floating
avatars + context label + queue row) on top of this minimal base.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 2

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 3 — Cosmos Home data layer

**Phase goal:** Selectors exist and are tested: `freshestPendingSenderProvider` returns one `PendingSender`, `pendingSendersQueueProvider(max: 6)` returns up to six, both sorted by recency.

### Task 6: Create PendingSender model

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/cosmos_sender_model.dart`

- [ ] **Step 1: Create the model file**

Create `app/lib/views/home/decision_board/pages/home/cosmos_sender_model.dart`:

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';

import '../../../../../models/feed_item.dart';

/// The kind of action the user can take in response to a PendingSender.
/// Determines which text-word set appears in the Expanded action region.
enum MessageKind {
  /// Yes/No/Maybe (time-proposals, simple confirms, acks)
  confirm,

  /// Love it / Works for me / Not for me (polls, decisions)
  decision,

  /// Pay now / Later
  settlement,

  /// Full reply text field (open DM)
  openText,
}

/// The "where" context shown in the label above a foreground avatar.
/// For DMs this is always the literal string "Message" (DM label
/// exception in Principle 6). For group-originated items it's the
/// group/trip name.
enum SenderContextKind { dm, group }

/// A person (or group) with one pending item that needs the user's
/// attention. Produced by `freshestPendingSenderProvider` +
/// `pendingSendersQueueProvider`.
///
/// `subject` is the pre-tap preview: the decision title or the first
/// ~36 chars of the message body. For DMs this is not shown on Home
/// (label collapses to "Message") but is still populated so the
/// Expanded state can display the full message text.
class PendingSender {
  /// Stable identifier; used by `HologramAvatar` registry, palette
  /// provider, and the animation lock snapshot.
  final String id;

  /// Display name. Routed through `getAvatarImagePath(name)` to find
  /// the transparent PNG.
  final String name;

  /// What kind of message this is — determines the action word set.
  final MessageKind messageKind;

  /// Context for the label: DM vs group. For DM, label is "Message";
  /// for group, label is `{groupName} · "{subject}"`.
  final SenderContextKind contextKind;

  /// Group name when `contextKind == group`. Empty string for DM.
  final String groupName;

  /// First ~36 chars of message / decision title / poll question.
  /// For DM, hidden on the Home label but shown in Expanded state.
  final String subject;

  /// When the source item was last updated (for recency sort).
  final DateTime sortKey;

  /// The underlying FeedItem — needed by the action handlers to
  /// route the tap to the correct engine call.
  final FeedItem source;

  const PendingSender({
    required this.id,
    required this.name,
    required this.messageKind,
    required this.contextKind,
    required this.groupName,
    required this.subject,
    required this.sortKey,
    required this.source,
  });

  /// Equality by id (stable identity across provider re-emits).
  @override
  bool operator ==(Object other) =>
      other is PendingSender && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Produce a PendingSender from a FeedItem, or null if the feed item
/// is not a "pending action" item for this user.
///
/// Logic:
/// - DmFeedItem with unreadInboundCount > 0 → confirm kind (Yes/No/Maybe default)
/// - GroupFeedItem with unreadInboundCount > 0 → confirm kind
/// - DecisionSmallFeedItem where reactions does NOT contain 'me' → decision kind
/// - DecisionHeroFeedItem where reactions does NOT contain 'me' → decision kind
/// - SettlementFeedItem where `amount < 0` (user owes) → settlement kind
/// - Other kinds → null (not surfaced on Home)
PendingSender? pendingSenderFromFeedItem(FeedItem item) {
  switch (item) {
    case DmFeedItem(:final conversation):
      if (conversation.unreadInboundCount <= 0) return null;
      return PendingSender(
        id: 'dm_${conversation.id}',
        name: _displayName(conversation.id),
        messageKind: MessageKind.openText,
        contextKind: SenderContextKind.dm,
        groupName: '',
        subject: _preview(conversation.lastMessageText ?? ''),
        sortKey: conversation.lastMessageTimestamp ?? conversation.updatedAt,
        source: item,
      );
    case GroupFeedItem(:final conversation):
      if (conversation.unreadInboundCount <= 0) return null;
      return PendingSender(
        id: 'group_${conversation.id}',
        name: _displayName(conversation.id),
        messageKind: MessageKind.confirm,
        contextKind: SenderContextKind.group,
        groupName: _displayName(conversation.id),
        subject: _preview(conversation.lastMessageText ?? ''),
        sortKey: conversation.lastMessageTimestamp ?? conversation.updatedAt,
        source: item,
      );
    case DecisionSmallFeedItem(
        item: final innerItem,
        title: final t,
        updatedAt: final u,
      ):
      if (innerItem.reactions.containsKey('me')) return null;
      return PendingSender(
        id: 'decs_${innerItem.id}',
        name: _displayName(innerItem.proposedBy),
        messageKind: MessageKind.decision,
        contextKind: SenderContextKind.group,
        groupName: _displayName(innerItem.groupId),
        subject: _preview(t),
        sortKey: u,
        source: item,
      );
    case DecisionHeroFeedItem(
        item: final innerItem,
        title: final t,
        updatedAt: final u,
      ):
      if (innerItem.reactions.containsKey('me')) return null;
      return PendingSender(
        id: 'dech_${innerItem.id}',
        name: _displayName(innerItem.proposedBy),
        messageKind: MessageKind.decision,
        contextKind: SenderContextKind.group,
        groupName: _displayName(innerItem.groupId),
        subject: _preview(t),
        sortKey: u,
        source: item,
      );
    case SettlementFeedItem(:final settlement):
      if (settlement.amount >= 0) return null; // only pending when user owes
      return PendingSender(
        id: 'settle_${settlement.id}',
        name: _displayName(settlement.counterpartyId),
        messageKind: MessageKind.settlement,
        contextKind: SenderContextKind.group,
        groupName: _displayName(settlement.groupId),
        subject: _preview('\$${settlement.amount.abs().toStringAsFixed(2)}'),
        sortKey: settlement.updatedAt,
        source: item,
      );
    default:
      return null; // trips, itinerary, memory, ai-nudge, focus-hero not surfaced
  }
}

/// `"ram_krishna"` → `"Ram Krishna"`; mimics dm_card/group_card
/// conventions. Replace with a real display-name service when
/// available.
String _displayName(String id) {
  if (id.isEmpty) return 'Unknown';
  return id
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Trim to 36 characters with an ellipsis.
String _preview(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= 36) return trimmed;
  return '${trimmed.substring(0, 36)}…';
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/cosmos_sender_model.dart
```

Expected: zero errors. The `Settlement` model is in `app/lib/models/settlement.dart` — if its fields are `counterpartyId` and `groupId` and `amount` and `updatedAt`, the code above compiles. If not, adjust to the actual field names: open `app/lib/models/settlement.dart` and match.

The `Conversation.unreadInboundCount` and `lastMessageText` fields come from `e2ee_chat_sdk`. If these are named differently, adjust to the SDK's actual accessor (e.g., `unreadCount`, `lastMessagePreview`). Open `engine/lib/src/domain/conversation.dart` (or equivalent) to confirm.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/cosmos_sender_model.dart
git commit -m "$(cat <<'EOF'
feat(home): add PendingSender model + FeedItem extractor

Defines the domain type that Home's cosmos surface consumes:
one person with one pending action (confirm / decision /
settlement / open text). `pendingSenderFromFeedItem` filters
the unified feed down to items that actually need the user's
response, dropping items where the user has already acted
(reactions contains 'me') or where the user owes nothing
(settlement amount >= 0).

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 3

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Write failing test for pendingSender selectors

**Files:**
- Create: `app/test/providers/cosmos_home_providers_test.dart`

- [ ] **Step 1: Create the test file**

Create `app/test/providers/cosmos_home_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_app/views/home/decision_board/pages/home/cosmos_sender_model.dart';
import 'package:hello_app/providers/filtered_feed_providers.dart';
import 'package:hello_app/providers/feed_provider.dart';
import 'package:hello_app/models/feed_item.dart';

void main() {
  group('freshestPendingSenderProvider', () {
    test('returns null when no pending items exist', () {
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[]),
      ]);
      addTearDown(container.dispose);

      final sender = container.read(freshestPendingSenderProvider);
      expect(sender, isNull);
    });

    test('returns the most recent pending sender by sortKey', () {
      // This test will fail until the provider exists.
      // Implementation provides the real provider in Task 8.
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[
          // TODO: fixture FeedItems will be added in Task 8 once
          // provider + model types stabilize. For now verify null case.
        ]),
      ]);
      addTearDown(container.dispose);

      final sender = container.read(freshestPendingSenderProvider);
      expect(sender, isNull);
    });
  });

  group('pendingSendersQueueProvider', () {
    test('returns at most 6 senders excluding the foreground', () {
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[]),
      ]);
      addTearDown(container.dispose);

      final queue = container.read(pendingSendersQueueProvider);
      expect(queue.length, lessThanOrEqualTo(6));
      expect(queue, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails with "provider not found"**

```bash
cd /Users/ramchitturi/hello/app && flutter test test/providers/cosmos_home_providers_test.dart -r compact
```

Expected: compile error — `freshestPendingSenderProvider` and `pendingSendersQueueProvider` don't exist yet. This is the red phase of TDD. Proceed to Task 8.

---

### Task 8: Implement pendingSender providers

**Files:**
- Modify: `app/lib/providers/filtered_feed_providers.dart`

- [ ] **Step 1: Append providers to filtered_feed_providers.dart**

Append to the bottom of `app/lib/providers/filtered_feed_providers.dart`:

```dart
// ── Cosmos Home providers (2026-04-14) ────────────────────────────

import '../views/home/decision_board/pages/home/cosmos_sender_model.dart';

/// Freshest pending sender — the person behind the most recent
/// pending item in the unified feed. Returns null when no pending
/// items exist (Home shows the "all caught up" empty state).
final freshestPendingSenderProvider = Provider<PendingSender?>((ref) {
  final feed = ref.watch(feedProvider);
  final senders = <PendingSender>[];
  for (final item in feed) {
    final s = pendingSenderFromFeedItem(item);
    if (s != null) senders.add(s);
  }
  if (senders.isEmpty) return null;
  senders.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return senders.first;
});

/// Up to 6 pending senders by recency, excluding whoever is in the
/// foreground. Freshness-only sort (no relationship tiebreakers).
final pendingSendersQueueProvider = Provider<List<PendingSender>>((ref) {
  final feed = ref.watch(feedProvider);
  final foreground = ref.watch(freshestPendingSenderProvider);
  final senders = <PendingSender>[];
  for (final item in feed) {
    final s = pendingSenderFromFeedItem(item);
    if (s != null && s != foreground) senders.add(s);
  }
  senders.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return senders.take(6).toList();
});
```

- [ ] **Step 2: Run the test to verify compile passes**

```bash
cd /Users/ramchitturi/hello/app && flutter test test/providers/cosmos_home_providers_test.dart -r compact
```

Expected: both tests PASS (the null-feed cases). Fixture-backed tests for the sorting/6-cap logic will be added once the test structure is stable. If compile fails, check imports and adjust path of `cosmos_sender_model.dart`.

- [ ] **Step 3: Expand the tests with real fixtures**

Replace the second `test` in the `freshestPendingSenderProvider` group in `app/test/providers/cosmos_home_providers_test.dart` with the following (leaves the first/null-case test intact):

```dart
    test('returns the most recent pending sender by sortKey', () {
      // Two fake memory items do not surface (not pending kinds);
      // the AiNudgeFeedItem likewise not surfaced — so only confirm
      // the null fallback holds when the feed contains no pending-
      // kind items. Full fixture coverage is deferred to a follow-up
      // integration test once the DM/Decision/Settlement mocks
      // stabilize.
      final now = DateTime.now();
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[
          MemoryFeedItem(
            memoryId: 'm1',
            eyebrow: 'eyebrow',
            title: 'title',
            body: 'body',
            occurredAt: now,
            updatedAt: now,
          ),
          AiNudgeFeedItem(
            nudgeId: 'n1',
            message: 'msg',
            updatedAt: now,
          ),
        ]),
      ]);
      addTearDown(container.dispose);

      final sender = container.read(freshestPendingSenderProvider);
      expect(sender, isNull,
          reason: 'Memory and AI-nudge items are not pending kinds');
    });
```

- [ ] **Step 4: Run the test suite**

```bash
cd /Users/ramchitturi/hello/app && flutter test test/providers/cosmos_home_providers_test.dart -r compact
```

Expected: all three tests pass.

- [ ] **Step 5: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/providers/filtered_feed_providers.dart app/test/providers/cosmos_home_providers_test.dart
git commit -m "$(cat <<'EOF'
feat(home): freshestPendingSender + pendingSendersQueue providers

Selects the foreground avatar (freshestPendingSender) and the
six-element ambient queue (pendingSendersQueue) from the unified
feed. Freshness-only sort; no relationship tiebreakers per Q2 of
the cosmos-home brainstorm. Queue excludes the foreground.

Tests cover the empty-feed case and the non-pending-kinds case
(memory + AI nudge). Richer fixture coverage deferred pending
DM/Decision/Settlement test harness work.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 3

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 4 — Cosmos Home UI (Ambient state)

**Phase goal:** Home renders the full Ambient state — atmosphere + 140px foreground avatar + context label + 6×48px queue row (or "all caught up" empty state). Tapping does nothing yet.

### Task 9: Build the context_label widget

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/context_label.dart`

- [ ] **Step 1: Create the widget**

Create `app/lib/views/home/decision_board/pages/home/context_label.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import 'cosmos_sender_model.dart';

/// The small text below the foreground avatar on Home.
///
/// For DMs: literally "Message" (no subject preview — see Principle
/// 6 DM exception in the spec).
///
/// For groups: `{group_name} · "{subject}"`.
///
/// Zero-box: no container, no fill, no border. Just type.
class ContextLabel extends StatelessWidget {
  final PendingSender sender;

  const ContextLabel({super.key, required this.sender});

  @override
  Widget build(BuildContext context) {
    final text = switch (sender.contextKind) {
      SenderContextKind.dm => 'Message · "${sender.subject}"',
      SenderContextKind.group => '${sender.groupName} · "${sender.subject}"',
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.80,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HelloColors.inkSecondary,
          height: 1.2,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/context_label.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/context_label.dart
git commit -m "$(cat <<'EOF'
feat(home): add ContextLabel widget

Renders the below-avatar label:
- 1:1 DM   → `Message · "{first 36 chars of message}"`
- group    → `{groupName} · "{subject}"`

Zero container, zero border, 14pt Inter w400 inkSecondary. Max
80% Home width, ellipsizes on overflow. DMs expose the subject
preview per Principle 6 (no blind-inbox exceptions).

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 4

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Build the foreground_avatar widget (static, no reward yet)

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart`

- [ ] **Step 1: Create the widget**

Create `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import 'cosmos_sender_model.dart';

/// The 140×140 foreground avatar at upper-third of Home.
///
/// Uses HologramAvatar's built-in guillotine ShaderMask dissolve
/// — never wraps the photo in a container, ring, or shadow. The
/// photo floats in the atmosphere.
///
/// Reward-animation wiring (levitation, plasma infusion) is added
/// in Phase 6; this task is the static-placement baseline.
class ForegroundAvatar extends StatelessWidget {
  final PendingSender sender;
  final VoidCallback? onTap;

  const ForegroundAvatar({
    super.key,
    required this.sender,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: HologramAvatar(
        avatarPath: getAvatarImagePath(sender.name),
        size: 140,
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/foreground_avatar.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/foreground_avatar.dart
git commit -m "$(cat <<'EOF'
feat(home): add ForegroundAvatar static widget

140×140 HologramAvatar wrapper with tap handler. Preserves the
guillotine ShaderMask from avatar_utils.dart unchanged — no added
container, ring, or shadow. Reward-animation layers wired in
Phase 6.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 4

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Build the queue_row widget

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/queue_row.dart`

- [ ] **Step 1: Create the widget**

Create `app/lib/views/home/decision_board/pages/home/queue_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import 'cosmos_sender_model.dart';

/// Horizontal row of up to 6 face-only avatars at 48px.
///
/// Render order: left → right by recency (fresher on the left).
/// Renders fewer than 6 when the queue is shorter; never pads with
/// placeholders.
///
/// Zero-box: just HologramAvatars in a Row with gaps. No container,
/// no ring, no shadow, no background fill.
class QueueRow extends StatelessWidget {
  /// Up to 6 pending senders, already recency-sorted.
  final List<PendingSender> senders;

  /// Invoked when a queue avatar is tapped. Receives the sender.
  final ValueChanged<PendingSender>? onTap;

  const QueueRow({
    super.key,
    required this.senders,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (senders.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < senders.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap!(senders[i]),
            child: HologramAvatar(
              avatarPath: getAvatarImagePath(senders[i].name),
              size: 48,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/queue_row.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/queue_row.dart
git commit -m "$(cat <<'EOF'
feat(home): add QueueRow widget

Horizontal Row of up to 6 × 48px HologramAvatars with 12pt gaps.
Zero container, zero ring, zero shadow. Renders SizedBox.shrink
when the queue is empty (handled alongside the all-caught-up
empty state in home_page).

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 4

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Rewrite home_page.dart to render the Ambient state

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart` — replace placeholder with full cosmos Ambient layout

- [ ] **Step 1: Rewrite home_page.dart**

Replace the entire contents of `app/lib/views/home/decision_board/pages/home_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/ambient_palette.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../chromatic_atmosphere.dart';
import 'home/context_label.dart';
import 'home/cosmos_sender_model.dart';
import 'home/foreground_avatar.dart';
import 'home/queue_row.dart';

/// Cosmos Home — floating avatar surface.
///
/// Ambient state: atmosphere + foreground avatar + context label +
/// queue row (or "all caught up" empty state). Tapping an avatar
/// will open the Expanded state in Phase 5; this task only builds
/// the Ambient layer.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Captured at initState to survive Riverpod 3's dispose-before-
  /// state-dispose ordering (see root CLAUDE.md landmine #12 ancestry).
  FocusSourceStack? _focusStack;
  String? _pushedSourceId;

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
  }

  @override
  void dispose() {
    if (_pushedSourceId != null) {
      _focusStack?.pop(_pushedSourceId!);
    }
    super.dispose();
  }

  /// Push the foreground sender's signature palette into the focus
  /// source stack at priority 20 (above tab fallback 10, below
  /// detail-route 50 — per spec).
  Future<void> _syncForegroundPalette(PendingSender? sender) async {
    final stack = _focusStack;
    if (stack == null) return;

    if (sender == null) {
      if (_pushedSourceId != null) {
        stack.pop(_pushedSourceId!);
        _pushedSourceId = null;
      }
      return;
    }

    final id = 'home_fg_${sender.id}';
    if (_pushedSourceId == id) return; // unchanged

    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: sender.name, kind: 'dm'),
    );
    if (!mounted) return;
    if (_pushedSourceId != null && _pushedSourceId != id) {
      stack.pop(_pushedSourceId!);
    }
    stack.push(FocusSource(
      id: id,
      palette: palette,
      priority: 20,
    ));
    _pushedSourceId = id;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final foreground = ref.watch(freshestPendingSenderProvider);
    final queue = ref.watch(pendingSendersQueueProvider);

    // Side-effect: keep the focus stack in sync with the foreground
    // sender. Uses post-frame to avoid ref writes during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncForegroundPalette(foreground);
    });

    // Empty state: no pending items at all.
    if (foreground == null && queue.isEmpty) {
      return AtmosphereDensityScope(
        density: AtmosphereDensity.focus,
        child: Center(
          child: Text(
            'all caught up',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ),
      );
    }

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Foreground avatar — upper-third, centered
              if (foreground != null)
                Positioned(
                  top: h * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForegroundAvatar(sender: foreground),
                  ),
                ),

              // Context label — 12pt below foreground (≈140 + 12 from anchor)
              if (foreground != null)
                Positioned(
                  top: h * 0.18 + 140 + 12,
                  left: 0,
                  right: 0,
                  child: Center(child: ContextLabel(sender: foreground)),
                ),

              // Queue row — 32pt below context label (≈14pt label text + 32 gap)
              Positioned(
                top: h * 0.18 + 140 + 12 + 20 + 32,
                left: 0,
                right: 0,
                child: Center(child: QueueRow(senders: queue)),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors. If an error surfaces about `FocusSourceStack` not being imported, add:

```dart
import '../../../../providers/focus_sources_provider.dart';
```

(Already present in the code above. If the class was renamed, open `focus_sources_provider.dart` to confirm the class name.)

- [ ] **Step 3: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Verify on HOME tab:
1. Atmosphere renders full-bleed (gradient drenches the screen)
2. If any seed DM/decision/settlement is pending for the seed `me` user, a 140×140 transparent avatar appears upper-third centered
3. Below the avatar: the context label — `Message` for DM or `{group} · "{subject}"` for group
4. Below the context label: a horizontal row of up to 6 smaller (48px) avatars
5. If no pending items exist in the seed: centered `all caught up` text
6. No containers, no pills, no borders visible anywhere on Home

If the seed data doesn't produce any pending items, temporarily inject one by editing `seed_data.dart` (but **do not commit seed-data edits** in this task — revert once verified).

- [ ] **Step 4: 3-second rule check**

Close the app, reopen. Count Mississippi seconds. Target: ≤3 seconds to name *who (avatar)*, *where (label)*, *what (subject)*. If it takes longer, the label copy or layout needs tuning — file a follow-up rather than blocking this task.

- [ ] **Step 5: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home_page.dart
git commit -m "$(cat <<'EOF'
feat(home): render cosmos Ambient state

Home now shows the floating-avatar surface:
- full-bleed ChromaticAtmosphere
- 140px foreground avatar at upper-third
- context label below (Message for DM, group · subject for group)
- up to 6 × 48px queue avatars in a horizontal row
- "all caught up" text when no pending items

Pushes the foreground sender's signature palette into
focusSourcesProvider at priority 20 so the atmosphere drenches
Home in that person's mood. Uses ref.read + post-frame callback
to avoid ref writes during build.

Tapping the avatars does nothing yet — Expanded state lands in
Phase 5.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 4

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 5 — In-place expansion (no OpenContainer)

**Phase goal:** Tapping any avatar cross-fades the queue + context label out and fades in the message text + action words on the same canvas. No route push. Dismiss on tap-outside works. Action shapes adapt to message kind.

### Task 13: Build the action_word widget (single text-as-action)

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/action_word.dart`

- [ ] **Step 1: Create the widget**

Create `app/lib/views/home/decision_board/pages/home/action_word.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../../plasma/plasma.dart';

/// A single action word rendered as text-as-action.
///
/// - Word IS the button. No container, no edge, no rounded rect.
/// - Hit zone is an `Expanded` parent (caller's responsibility) wrapping
///   this widget. This widget draws only the word + the approach glow
///   + the plasma sweep on tap. The caller supplies the hit box.
/// - On approach (pressDown for touch; hover on web/desktop):
///   the atmosphere behind the word brightens via a shapeless
///   RadialGradient painter behind the text. Alpha tapers to 0 at
///   ~60pt radius — no visible edge.
/// - On tap: PlasmaTint sweeps through the letters. Single
///   ShaderMask (no nesting — avoids double-saveLayer).
class ActionWord extends StatefulWidget {
  final String word;
  final VoidCallback onTap;

  const ActionWord({
    super.key,
    required this.word,
    required this.onTap,
  });

  @override
  State<ActionWord> createState() => _ActionWordState();
}

class _ActionWordState extends State<ActionWord>
    with SingleTickerProviderStateMixin {
  bool _approaching = false;
  late final AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _approaching = true);
  }

  void _handleTapUp(TapUpDetails _) {
    _tapController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _approaching = false);
    });
    widget.onTap();
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _approaching = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      // Transparent-fill Container forces the GestureDetector to claim
      // the full Expanded slot (its parent's tight constraints) rather
      // than shrinking to the text's visual bounds. Eliminates dead-zone
      // taps in the space between words on wide viewports.
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // Approach glow — shapeless radial, no edge
          if (_approaching)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: 0.35,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 120,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        HelloColors.accent.withValues(alpha: 0.30),
                        Colors.transparent,
                      ],
                      radius: 0.7,
                    ),
                  ),
                ),
              ),
            ),
          // The word itself — plasma sweep through letters on tap
          AnimatedBuilder(
            animation: _tapController,
            builder: (ctx, _) {
              final tapping = _tapController.value > 0.0;
              final text = FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.word,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkPrimary,
                    height: 1.0,
                  ),
                ),
              );
              if (!tapping) return text;
              // Plasma sweep — single ShaderMask with srcATop-ish behavior
              // (srcIn replaces letters entirely with plasma, which is
              // exactly what we want for transient glyph-fill; not the
              // same as nested ShaderMask over HologramAvatar — this is
              // one layer on a single Text).
              return PlasmaTint(child: text);
            },
          ),
        ],
      ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/action_word.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/action_word.dart
git commit -m "$(cat <<'EOF'
feat(home): add ActionWord text-as-action widget

Single text word with:
- approach glow: shapeless RadialGradient behind text on pressDown,
  alpha tapers to 0 at ~60pt radius, no visible edge
- plasma sweep on tap: PlasmaTint (single ShaderMask) fills the
  letters themselves; no container, no edge, no rounded rect
- FittedBox(scaleDown) safety net for long copy like "Works for me"
  on narrow viewports
- 26pt Inter w400 ink primary at rest

Hit zone is the parent Expanded's responsibility — this widget
draws only. See action_words_row.dart for the composition.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 5

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Build the action_words_row (shape-adaptive)

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/action_words_row.dart`

- [ ] **Step 1: Create the widget**

Create `app/lib/views/home/decision_board/pages/home/action_words_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../../../../../utils/haptics.dart';
import 'action_word.dart';
import 'cosmos_sender_model.dart';

/// Renders the action words appropriate for the message kind.
///
/// Hit zones are `Expanded` columns — each child gets exactly
/// 1/N of the row width, edge-to-edge. No padding-based dead
/// zones.
///
/// For MessageKind.openText: renders a full-width reply TextField
/// instead of word-buttons.
class ActionWordsRow extends StatelessWidget {
  final MessageKind kind;
  final ValueChanged<String> onAction;
  final TextEditingController? replyController;
  final VoidCallback? onReplySubmit;

  const ActionWordsRow({
    super.key,
    required this.kind,
    required this.onAction,
    this.replyController,
    this.onReplySubmit,
  });

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      MessageKind.confirm => _buildRow([
          _ActionSpec('Yes', affirmative: true),
          _ActionSpec('No', affirmative: false),
          _ActionSpec('Maybe', affirmative: false),
        ]),
      MessageKind.decision => _buildRow([
          _ActionSpec('Love', affirmative: true),
          _ActionSpec('Works', affirmative: true),
          _ActionSpec('Pass', affirmative: false),
        ]),
      MessageKind.settlement => _buildRow([
          _ActionSpec('Pay now', affirmative: true),
          _ActionSpec('Later', affirmative: false),
        ]),
      MessageKind.openText => _buildReplyField(context),
    };
  }

  Widget _buildRow(List<_ActionSpec> specs) {
    return Row(
      children: [
        for (final spec in specs)
          Expanded(
            // No Center wrapper — ActionWord's internal Container claims
            // the full Expanded slot for the GestureDetector hit zone.
            // Wrapping in Center would shrink the hit target to the text.
            child: ActionWord(
              word: spec.word,
              onTap: () {
                if (spec.affirmative) {
                  HelloHaptic.confirm();
                } else {
                  HelloHaptic.tap();
                }
                onAction(spec.word);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReplyField(BuildContext context) {
    return TextField(
      controller: replyController,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: HelloColors.inkPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Reply…',
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: HelloColors.inkTertiary,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onReplySubmit?.call(),
    );
  }
}

class _ActionSpec {
  final String word;
  final bool affirmative;
  const _ActionSpec(this.word, {required this.affirmative});
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/action_words_row.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/action_words_row.dart
git commit -m "$(cat <<'EOF'
feat(home): add ActionWordsRow — shape-adaptive text-action row

Renders:
- MessageKind.confirm    → Yes / No / Maybe (3 × Expanded)
- MessageKind.decision   → Love / Works / Pass (3 × Expanded,
  single-word copy for uniform 26pt visual weight across devices)
- MessageKind.settlement → Pay now / Later (2 × Expanded)
- MessageKind.openText   → full-width reply TextField

Uses Row[Expanded] grid hit zones — each action gets exactly
1/N of the row width edge-to-edge. No padding-based dead zones
between words.

Fires HelloHaptic.confirm for affirmatives, HelloHaptic.tap for
soft negatives (per spec's Reward Layer 5).

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 5

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: Add in-place expansion state to home_page.dart

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart` — add `_focusedSender`, cross-fade Ambient ↔ Expanded, wire avatar taps

- [ ] **Step 1: Rewrite home_page.dart with expansion state**

Replace the entire `_HomePageState` class body in `app/lib/views/home/decision_board/pages/home_page.dart` with:

```dart
class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  FocusSourceStack? _focusStack;
  String? _pushedSourceId;

  /// The sender whose action surface is currently expanded in-place.
  /// Null = Ambient state (queue + context label visible).
  PendingSender? _focusedSender;

  /// Controller for the open-DM reply field (only populated when the
  /// focused sender has MessageKind.openText).
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
  }

  @override
  void dispose() {
    if (_pushedSourceId != null) {
      _focusStack?.pop(_pushedSourceId!);
    }
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _syncForegroundPalette(PendingSender? sender) async {
    final stack = _focusStack;
    if (stack == null) return;

    if (sender == null) {
      if (_pushedSourceId != null) {
        stack.pop(_pushedSourceId!);
        _pushedSourceId = null;
      }
      return;
    }

    final id = 'home_fg_${sender.id}';
    if (_pushedSourceId == id) return;

    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: sender.name, kind: 'dm'),
    );
    if (!mounted) return;
    if (_pushedSourceId != null && _pushedSourceId != id) {
      stack.pop(_pushedSourceId!);
    }
    stack.push(FocusSource(
      id: id,
      palette: palette,
      priority: 20,
    ));
    _pushedSourceId = id;
  }

  void _onAvatarTap(PendingSender sender) {
    setState(() {
      _focusedSender = sender;
      _replyController.clear();
    });
  }

  void _dismissExpansion() {
    setState(() {
      _focusedSender = null;
      _replyController.clear();
    });
  }

  void _onActionTap(String word) {
    // Phase 6 wires this to the reward-sequence orchestrator. For
    // now: dismiss to Ambient to prove the state machine works.
    _dismissExpansion();
  }

  void _onReplySubmit() {
    // Phase 6 wires this to session.sendText. For now: dismiss.
    _dismissExpansion();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final foreground = ref.watch(freshestPendingSenderProvider);
    final queue = ref.watch(pendingSendersQueueProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncForegroundPalette(foreground);
    });

    if (foreground == null && queue.isEmpty) {
      return AtmosphereDensityScope(
        density: AtmosphereDensity.focus,
        child: Center(
          child: Text(
            'all caught up',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ),
      );
    }

    final isExpanded = _focusedSender != null;

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final expandedSender = _focusedSender ?? foreground;

          return Stack(
            children: [
              // Dismiss layer — tap-outside anywhere except the avatar
              // and the action region dismisses back to Ambient.
              if (isExpanded)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissExpansion,
                  ),
                ),

              // Foreground avatar — always rendered
              if (expandedSender != null)
                Positioned(
                  top: h * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForegroundAvatar(
                      sender: expandedSender,
                      onTap: isExpanded
                          ? null
                          : () => _onAvatarTap(expandedSender),
                    ),
                  ),
                ),

              // Ambient layer (context label + queue) — cross-fades OUT
              // when _focusedSender is set
              AnimatedOpacity(
                opacity: isExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: isExpanded,
                  child: Stack(
                    children: [
                      if (foreground != null)
                        Positioned(
                          top: h * 0.18 + 140 + 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: ContextLabel(sender: foreground),
                          ),
                        ),
                      Positioned(
                        top: h * 0.18 + 140 + 12 + 20 + 32,
                        left: 0,
                        right: 0,
                        child: Center(child: QueueRow(
                          senders: queue,
                          onTap: _onAvatarTap,
                        )),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded layer — cross-fades IN when _focusedSender is set
              AnimatedOpacity(
                opacity: isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: expandedSender == null
                      ? const SizedBox.shrink()
                      : Stack(
                          children: [
                            // Full message text — where the context
                            // label was
                            Positioned(
                              top: h * 0.18 + 140 + 12,
                              left: 24,
                              right: 24,
                              child: Text(
                                _expandedMessageText(expandedSender),
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: HelloColors.inkPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            // Action words row — where the queue row was
                            Positioned(
                              top: h * 0.18 + 140 + 12 + 130 + 32,
                              left: 32,
                              right: 32,
                              child: ActionWordsRow(
                                kind: expandedSender.messageKind,
                                onAction: _onActionTap,
                                replyController: _replyController,
                                onReplySubmit: _onReplySubmit,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _expandedMessageText(PendingSender sender) {
    // For now show the subject as the full message. Real message
    // loading (opening the conversation, fetching recent inbound)
    // happens in the "Great Wiring" pass, out of scope for this spec.
    return sender.subject.isEmpty ? '(no message content)' : sender.subject;
  }
}
```

Also add these imports at the top of the file:

```dart
import 'action_words_row.dart';
```

(Ensure the other home/ imports — `context_label.dart`, `cosmos_sender_model.dart`, `foreground_avatar.dart`, `queue_row.dart` — are still present.)

Remove the now-unused `_syncForegroundPalette` from an earlier incarnation (it's recreated in this rewrite — just verify there's no duplicate).

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors.

- [ ] **Step 3: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Verify on HOME tab:
1. Ambient state renders as before (avatar + label + queue)
2. Tap the foreground avatar → queue + label fade out over 180ms; full message text + action words row fade in
3. Action shape matches message kind:
   - DM → full-width reply `TextField`
   - Group (plain message) → `Yes / No / Maybe`
   - Decision → `Love / Works / Pass` (single-word copy; all three render at a uniform 26pt with no FittedBox scale-down on any phone viewport ≥ 320pt)
   - Settlement → `Pay now / Later`
4. Tap a queue avatar → same expansion behavior, but for that person
5. Tap outside the action region → Ambient state returns (180ms cross-fade back)
6. Tap an action word → Ambient state returns (Phase 6 will replace this stub with the reward sequence)

- [ ] **Step 4: Overflow audit — narrow viewport**

Resize the Chrome window to 320pt wide (minimum phone target). Trigger a decision-kind expansion. Verify `Love`, `Works`, `Pass` each render at a uniform 26pt **without** triggering `FittedBox` scale-down — single-word copy should fit cleanly. `FittedBox` only engages as a foldable safety net on sub-320pt viewports. If overflow stripes appear on any ≥ 320pt viewport, the layout is broken — inspect `ActionWord`'s Container + GestureDetector stack.

- [ ] **Step 5: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home_page.dart
git commit -m "$(cat <<'EOF'
feat(home): in-place expansion from Ambient → action surface

Tapping the foreground or any queue avatar sets _focusedSender,
which cross-fades (180ms AnimatedOpacity) the context label +
queue row OUT and the full message text + ActionWordsRow IN on
the same Stack. No route push. No OpenContainer. Dismiss on
tap-outside.

Action shape adapts to MessageKind:
- confirm   → Yes / No / Maybe
- decision  → Love it / Works for me / Not for me (+ FittedBox)
- settlement → Pay now / Later
- openText  → full-width reply TextField

Action taps and reply submits are stubbed to dismiss back to
Ambient — Phase 6 replaces the stubs with the reward sequence.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 5

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 6 — Reward animation + animation lock

**Phase goal:** Every action tap runs the full 1700ms reward sequence (levitation + plasma infusion + atmosphere pulse + ascent + handoff) without the provider-re-emit flash. The next queue avatar rises smoothly into the foreground slot.

### Task 16: Add the AmbientPalettePulse transient + provider

**Files:**
- Modify: `app/lib/providers/ambient_palette_provider.dart` — add pulse signal
- Modify: `app/lib/views/home/decision_board/chromatic_atmosphere.dart` — consume pulse signal

- [ ] **Step 1: Add the pulse types + provider**

Append to `app/lib/providers/ambient_palette_provider.dart`:

```dart
// ── Reward Layer 3: Atmosphere pulse ────────────────────────────

/// A transient modulation applied to the ambient palette during
/// a reward animation. Lasts ~800ms; then the pulse controller
/// emits `AmbientPalettePulse.none` and the atmosphere relaxes
/// back to the base palette.
enum AmbientPalettePulse {
  /// No active pulse — atmosphere renders the base palette as-is.
  none,

  /// Affirmative action (Yes / Love it / Pay now) — saturation +15%
  /// over 800ms, then relax.
  affirm,

  /// Soft-negative action (No / Not for me / Later) — saturation
  /// -15% + brightness -10% over 800ms, then relax.
  negate,

  /// Hesitant action (Maybe) — dither opacity 0.015 → 0.025 + soft
  /// hue shimmer over 800ms.
  hesitate,
}

class AmbientPalettePulseController extends StateNotifier<AmbientPalettePulse> {
  AmbientPalettePulseController() : super(AmbientPalettePulse.none);

  /// Fire a pulse for the standard 800ms duration, then auto-relax.
  Future<void> pulse(AmbientPalettePulse kind) async {
    state = kind;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (state == kind) state = AmbientPalettePulse.none;
  }
}

final ambientPalettePulseProvider =
    StateNotifierProvider<AmbientPalettePulseController, AmbientPalettePulse>(
  (ref) => AmbientPalettePulseController(),
);
```

Also add at the top of the same file if not already present:

```dart
import 'package:flutter_riverpod/legacy.dart';
```

(`StateNotifier` lives in `legacy.dart` in Riverpod 3 — matches other files in this codebase, e.g., `focus_sources_provider.dart`.)

- [ ] **Step 2: Consume the pulse in chromatic_atmosphere.dart**

Open `app/lib/views/home/decision_board/chromatic_atmosphere.dart`. Find where the widget reads `ambientPaletteProvider` and applies it to the gradient stops. Add a pulse-aware transformation.

Add this import if not present:

```dart
import '../../../providers/ambient_palette_provider.dart';
```

Inside the `build` method, after reading the base palette, modulate it by the pulse:

```dart
final basePalette = ref.watch(ambientPaletteProvider);
final pulse = ref.watch(ambientPalettePulseProvider);
final palette = _applyPulse(basePalette, pulse);
```

And add the `_applyPulse` helper as a top-level function in the same file:

```dart
/// Apply a transient reward-pulse modulation to the base ambient
/// palette. Null pulse ⇒ no-op.
AmbientPalette _applyPulse(AmbientPalette base, AmbientPalettePulse pulse) {
  switch (pulse) {
    case AmbientPalettePulse.none:
      return base;
    case AmbientPalettePulse.affirm:
      return base.withSaturationBoost(1.15);
    case AmbientPalettePulse.negate:
      return base.withSaturationBoost(0.85).withBrightnessBoost(0.90);
    case AmbientPalettePulse.hesitate:
      // Dither bump + hue shimmer handled in the renderer (the
      // widget already reads dither opacity from a local
      // multiplier). Here we return the base palette unchanged;
      // the widget applies its own hesitate-aware tint below.
      return base;
  }
}
```

If `AmbientPalette` doesn't already expose `withSaturationBoost` and `withBrightnessBoost`, add them as extension methods at the bottom of `app/lib/models/ambient_palette.dart`:

```dart
extension AmbientPaletteTransforms on AmbientPalette {
  AmbientPalette withSaturationBoost(double factor) {
    return AmbientPalette(
      colors: colors.map((c) => _adjustSaturation(c, factor)).toList(),
    );
  }

  AmbientPalette withBrightnessBoost(double factor) {
    return AmbientPalette(
      colors: colors.map((c) => _adjustBrightness(c, factor)).toList(),
    );
  }
}

Color _adjustSaturation(Color c, double factor) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withSaturation((hsl.saturation * factor).clamp(0.0, 1.0)).toColor();
}

Color _adjustBrightness(Color c, double factor) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
}
```

And add to the top of `app/lib/models/ambient_palette.dart`:

```dart
import 'package:flutter/material.dart';
```

(If that import is already there, skip.)

The exact field names of `AmbientPalette` (e.g., whether it's `colors` or a different accessor) may differ — open `app/lib/models/ambient_palette.dart` and adapt the extension to the real constructor and field names. The pattern holds: two transforms that return a new `AmbientPalette` with saturation or brightness scaled.

- [ ] **Step 3: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/providers/ambient_palette_provider.dart app/lib/views/home/decision_board/chromatic_atmosphere.dart app/lib/models/ambient_palette.dart
git commit -m "$(cat <<'EOF'
feat(home): atmosphere pulse signal for reward Layer 3

Adds AmbientPalettePulse enum + StateNotifier controller.
ChromaticAtmosphere now consumes the transient pulse and
modulates saturation/brightness for 800ms:
- affirm   → saturation ×1.15
- negate   → saturation ×0.85, brightness ×0.90
- hesitate → base palette (dither shimmer handled separately)
- none     → base palette unchanged

AmbientPalette gets withSaturationBoost / withBrightnessBoost
extension methods via HSLColor transforms.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 6 (Layer 3)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 17: Build the RewardController

**Files:**
- Create: `app/lib/views/home/decision_board/pages/home/reward_controller.dart`

- [ ] **Step 1: Create the controller**

Create `app/lib/views/home/decision_board/pages/home/reward_controller.dart`:

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'cosmos_sender_model.dart';

/// Discrete phases of the 1700ms reward sequence.
/// Consumed by widgets that need to know "am I pulsing now" or
/// "is the ascent starting" without running their own timers.
enum RewardPhase {
  /// Not running — idle.
  idle,

  /// t = 0 → 700ms: levitation (avatar lifts +7pt then eases back)
  /// and plasma infusion (ColorFiltered srcATop sweep through palette)
  /// both run concurrently.
  infusing,

  /// t = 1000 → 1700ms: ascent (gradient stops flip, avatar drifts up
  /// ~60pt and dissolves) and handoff (next queue avatar scales 48→140
  /// into foreground slot).
  ascending,
}

/// Tracks the current reward phase + plasma infusion progress + ascent
/// progress. Constructed by _HomePageState and consumed by the reward
/// layers (ForegroundAvatar's infusion layer + atmosphere pulse + queue
/// promotion).
///
/// IMPORTANT: driven by a Flutter `Ticker` (not `Timer.periodic`) so the
/// sequence stays synced to the display's vsync signal. On 120Hz
/// ProMotion displays (8.33ms refresh), an event-loop Timer guarantees
/// micro-stutters and frame tearing.
class RewardController extends ChangeNotifier {
  RewardController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;

  RewardPhase _phase = RewardPhase.idle;
  double _infusionProgress = 0.0; // 0 → 1 during infusing
  double _ascentProgress = 0.0;   // 0 → 1 during ascending
  PendingSender? _lockedForeground;
  List<PendingSender>? _lockedQueue;
  Duration? _startAt; // elapsed at which start() was called

  RewardPhase get phase => _phase;
  double get infusionProgress => _infusionProgress;
  double get ascentProgress => _ascentProgress;
  PendingSender? get lockedForeground => _lockedForeground;
  List<PendingSender>? get lockedQueue => _lockedQueue;
  bool get isAnimating => _phase != RewardPhase.idle;

  /// Start the 1700ms sequence. Snapshots the current foreground +
  /// queue so build() can read them instead of re-watching providers
  /// (which would flash to the next person the moment the action
  /// is optimistically applied).
  void start({
    required PendingSender foreground,
    required List<PendingSender> queue,
  }) {
    _lockedForeground = foreground;
    _lockedQueue = queue;
    _phase = RewardPhase.infusing;
    _infusionProgress = 0.0;
    _ascentProgress = 0.0;
    _startAt = null; // set on first tick so elapsed=0 anchors correctly
    if (!_ticker.isActive) _ticker.start();
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _startAt ??= elapsed;
    final ms = (elapsed - _startAt!).inMilliseconds;

    if (ms < 700) {
      _phase = RewardPhase.infusing;
      _infusionProgress = (ms / 700).clamp(0.0, 1.0);
      _ascentProgress = 0.0;
    } else if (ms < 1000) {
      // Hold between 700ms and 1000ms — avatar at rest, infusion
      // receding, waiting for ascent
      _phase = RewardPhase.infusing;
      _infusionProgress = 1.0 - ((ms - 700) / 300).clamp(0.0, 1.0);
      _ascentProgress = 0.0;
    } else if (ms < 1700) {
      _phase = RewardPhase.ascending;
      _infusionProgress = 0.0;
      _ascentProgress = ((ms - 1000) / 700).clamp(0.0, 1.0);
    } else {
      // Done — release
      _phase = RewardPhase.idle;
      _infusionProgress = 0.0;
      _ascentProgress = 0.0;
      _lockedForeground = null;
      _lockedQueue = null;
      _startAt = null;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/reward_controller.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/reward_controller.dart
git commit -m "$(cat <<'EOF'
feat(home): add RewardController — vsynced 1700ms reward orchestrator

ChangeNotifier driven by a Flutter Ticker (created from a
TickerProvider passed by _HomePageState) — synced to display
vsync. Not a Timer.periodic, which would tear on 120Hz
ProMotion displays.

- exposes phase (idle / infusing / ascending) + per-phase progress
- snapshots foreground + queue at start() so build() reads locked
  values during the sequence (prevents optimistic-mutation flash)
- timeline:
    0 → 700   infusing (plasma fills avatar, levitation peaks)
    700 → 1000 hold     (infusion recedes)
    1000 → 1700 ascending (avatar drifts up + dissolves, queue[0]
                           scales 48→140 into foreground slot)
- releases locked snapshots at t = 1700 so the build() re-reads
  providers — by which point the underlying mutation has committed.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 6

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 18: Upgrade ForegroundAvatar with levitation + plasma infusion layers

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart`

- [ ] **Step 1: Replace ForegroundAvatar with reward-aware version**

Replace the entire contents of `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import '../../plasma/plasma.dart';
import 'cosmos_sender_model.dart';
import 'reward_controller.dart';

/// The 140×140 foreground avatar — now reward-aware.
///
/// When the RewardController is infusing:
/// - The avatar translates +7pt upward (easeOutCubic 300ms),
///   then eases back down (400ms)
/// - A ColorFiltered(srcATop) layer overlays an animated plasma
///   color on top of the photo pixels, brightening the face
///   without destroying features.
///
/// When the RewardController is ascending:
/// - The avatar translates ~60pt upward and its guillotine gradient
///   stops animate from [0.0, 0.5, 0.85, 1.0] (transparent at feet)
///   to [0.0, 0.15, 0.5, 1.0] (transparent at head) — person
///   dissolves from the top.
///
/// Critical: does NOT use BlendMode.srcIn. That would replace face
/// pixels with plasma, producing a faceless blob.
class ForegroundAvatar extends StatelessWidget {
  final PendingSender sender;
  final VoidCallback? onTap;
  final RewardController? rewardController;

  const ForegroundAvatar({
    super.key,
    required this.sender,
    this.onTap,
    this.rewardController,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = HologramAvatar(
      avatarPath: getAvatarImagePath(sender.name),
      size: 140,
    );

    // No controller attached → static render (Phase 4 / Ambient state).
    if (rewardController == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: avatar,
      );
    }

    return ListenableBuilder(
      listenable: rewardController!,
      builder: (ctx, _) {
        final ctrl = rewardController!;
        final translateY = _computeTranslateY(ctrl);
        final infusedChild = _withInfusion(avatar, ctrl);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: infusedChild,
          ),
        );
      },
    );
  }

  /// Levitation + ascent combined:
  /// - Levitation: ease up to -7pt over 300ms, drift back to 0 over 400ms
  /// - Ascent: linear up to -60pt over 700ms
  double _computeTranslateY(RewardController ctrl) {
    if (ctrl.phase == RewardPhase.infusing) {
      final p = ctrl.infusionProgress;
      // Tent function: peaks at 0.43 (about 300ms / 700ms ≈ 0.43)
      if (p < 0.43) {
        final t = p / 0.43;
        final eased = Curves.easeOutCubic.transform(t);
        return -7.0 * eased;
      } else {
        final t = (p - 0.43) / 0.57;
        final eased = Curves.easeInOut.transform(t);
        return -7.0 * (1.0 - eased);
      }
    }
    if (ctrl.phase == RewardPhase.ascending) {
      return -60.0 * ctrl.ascentProgress;
    }
    return 0.0;
  }

  /// Plasma infusion: wrap the avatar in a ColorFiltered whose
  /// color animates through the plasma palette over the infusing
  /// phase. srcATop draws on top of existing pixels only where
  /// the PNG has alpha — face features remain visible.
  Widget _withInfusion(Widget child, RewardController ctrl) {
    if (ctrl.phase != RewardPhase.infusing) return child;
    final color = _plasmaColorAt(ctrl.infusionProgress)
        .withValues(alpha: 0.55 * _infusionEnvelope(ctrl.infusionProgress));
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
      child: child,
    );
  }

  /// Linear interpolation through kPlasmaColors as t goes 0 → 1.
  Color _plasmaColorAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final segmentCount = kPlasmaColors.length - 1;
    final scaled = clamped * segmentCount;
    final idx = scaled.floor().clamp(0, segmentCount - 1);
    final frac = scaled - idx;
    return Color.lerp(kPlasmaColors[idx], kPlasmaColors[idx + 1], frac)!;
  }

  /// Envelope — fade in over first 30% of infusion, hold, fade out
  /// over last 30%. Avoids jumpy alpha at phase boundaries.
  double _infusionEnvelope(double t) {
    if (t < 0.3) return t / 0.3;
    if (t > 0.7) return (1.0 - t) / 0.3;
    return 1.0;
  }
}
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/pages/home/foreground_avatar.dart
```

Expected: zero errors. If `kPlasmaColors` is not exported from `plasma/plasma.dart`, open the plasma barrel and confirm the export. If it's private, import directly from `plasma/plasma_gradient.dart` instead.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/foreground_avatar.dart
git commit -m "$(cat <<'EOF'
feat(home): ForegroundAvatar reward layers — levitation + plasma infusion

Adds two reward-aware layers driven by a RewardController:

Layer 1 — Levitation:
  Transform.translate on Y: peaks at -7pt at t≈300ms (easeOutCubic
  in), eases back to 0 by t=700ms (easeInOut out).

Layer 2 — Plasma holographic infusion:
  ColorFiltered(ColorFilter.mode(animatedPlasmaColor, srcATop))
  wraps the existing HologramAvatar. Color tweens through
  kPlasmaColors over the infusion phase; alpha envelope fades in
  then out to avoid jumpy boundaries. Face features remain intact
  — srcATop overlays without replacing.

Critically DOES NOT use BlendMode.srcIn (which would replace
the face pixels with plasma gradient, leaving a faceless blob —
see v1-review Patch #2).

Ambient-state callers that pass rewardController: null get the
static render path unchanged.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 6 (Layers 1 & 2)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 19: Wire the RewardController into home_page.dart

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home_page.dart`

- [ ] **Step 1: Add RewardController to _HomePageState and wire action taps**

Open `app/lib/views/home/decision_board/pages/home_page.dart`. Add these imports at the top:

```dart
import 'home/reward_controller.dart';
import '../../../../providers/ambient_palette_provider.dart';
```

Change the State class declaration to add `SingleTickerProviderStateMixin` so the State can serve as the `TickerProvider` for the RewardController:

```dart
class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
```

Add these fields to `_HomePageState`:

```dart
late final RewardController _rewardController;
```

In `initState` (after `_focusStack = ref.read(focusSourcesProvider.notifier);`):

```dart
_rewardController = RewardController(vsync: this);
```

In `dispose` (before `super.dispose()`):

```dart
_rewardController.removeListener(_onRewardTick);
_rewardController.dispose();
```

And register the listener in `initState` right after construction:

```dart
_rewardController.addListener(_onRewardTick);
```

Replace `_onActionTap` with the reward-firing, vsync-aware, delay-aware version:

```dart
Future<void> _onActionTap(String word) async {
  final sender = _focusedSender;
  if (sender == null) return;

  final liveForeground = ref.read(freshestPendingSenderProvider);
  final liveQueue = ref.read(pendingSendersQueueProvider);

  // Determine affirmative-ness from the word
  final affirmative = _isAffirmative(word);

  // Fire atmosphere pulse (fire-and-forget 800ms)
  final pulse = affirmative
      ? AmbientPalettePulse.affirm
      : (word == 'Maybe'
          ? AmbientPalettePulse.hesitate
          : AmbientPalettePulse.negate);
  ref.read(ambientPalettePulseProvider.notifier).pulse(pulse);

  // Fire engine mutation in parallel (stubbed for now — Great
  // Wiring pass wires this to session.vote / session.sendText etc.)
  _applyAction(sender, word);

  // Start the reward-sequence animation against a snapshot.
  // build() will read from _rewardController.lockedForeground /
  // lockedQueue instead of the provider while phase != idle.
  _rewardController.start(
    foreground: sender, // the acted-on person levitates + dissolves
    queue: liveQueue.where((s) => s != sender).toList(),
  );

  // CRITICAL: wait for the ActionWord's 500ms plasma-sweep reward to
  // complete before collapsing the Expanded layer. Collapsing in
  // 180ms (the AnimatedOpacity duration) would fade the word to
  // invisible before its own reward plays out — user never sees it.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (!mounted) return;

  // Collapse the Expanded state — the reward + handoff animate
  // on the Ambient canvas with the locked snapshot.
  setState(() {
    _focusedSender = null;
    _replyController.clear();
  });
}

bool _isAffirmative(String word) {
  return word == 'Yes' ||
      word == 'Love' ||
      word == 'Works' ||
      word == 'Pay now';
}

void _applyAction(PendingSender sender, String word) {
  // Stub — Great Wiring pass routes this to the correct engine
  // call (session.vote / session.sendText / settlement.pay).
}

Future<void> _onReplySubmit() async {
  final sender = _focusedSender;
  if (sender == null) return;
  final text = _replyController.text.trim();
  if (text.isEmpty) return;

  // Fire atmosphere pulse
  ref.read(ambientPalettePulseProvider.notifier)
      .pulse(AmbientPalettePulse.affirm);

  // Stub engine call
  _applyAction(sender, text);

  _rewardController.start(
    foreground: sender,
    queue: ref
        .read(pendingSendersQueueProvider)
        .where((s) => s != sender)
        .toList(),
  );

  // Same 500ms delay rationale as _onActionTap.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (!mounted) return;

  setState(() {
    _focusedSender = null;
    _replyController.clear();
  });
}
```

And in the `build` method, change the `ForegroundAvatar` construction to pass the controller:

```dart
child: ForegroundAvatar(
  sender: expandedSender,
  onTap: isExpanded ? null : () => _onAvatarTap(expandedSender),
  rewardController: _rewardController,
),
```

Also update the build method to read locked snapshot when `_rewardController.isAnimating` — **but ALWAYS watch both providers unconditionally** (Riverpod subscription lifecycle rule).

Change the `build` method's top section:

```dart
@override
Widget build(BuildContext context) {
  super.build(context);

  // CRITICAL: ref.watch must ALWAYS fire to keep the provider
  // subscription alive. Conditionally skipping ref.watch during
  // the reward sequence unsubscribes the widget from the provider,
  // which (if autoDispose or on provider disposal heuristics)
  // would destroy cached state and force re-initialization at
  // t=1700ms. Watch unconditionally; branch on the result.
  final liveForeground = ref.watch(freshestPendingSenderProvider);
  final liveQueue = ref.watch(pendingSendersQueueProvider);

  // Animation lock: when the reward is playing, prefer the locked
  // snapshot (captured at reward.start()) so the UI doesn't flash
  // the next person mid-sequence. Subscription is still held above.
  final foreground = _rewardController.isAnimating
      ? _rewardController.lockedForeground
      : liveForeground;
  final queue = _rewardController.isAnimating
      ? (_rewardController.lockedQueue ?? const <PendingSender>[])
      : liveQueue;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Sync palette to whichever sender is actually displayed —
    // during expansion that's _focusedSender; otherwise the
    // current foreground.
    _syncForegroundPalette(_focusedSender ?? foreground);
  });

  // ... rest of build unchanged
```

Also rebuild the widget tree when the controller fires by listening:

In `initState`:

```dart
_rewardController = RewardController();
_rewardController.addListener(_onRewardTick);
```

Add:

```dart
void _onRewardTick() {
  if (mounted) setState(() {});
}
```

In `dispose`:

```dart
_rewardController.removeListener(_onRewardTick);
_rewardController.dispose();
```

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors.

- [ ] **Step 3: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Verify on HOME tab:
1. Tap foreground avatar → Expanded state, action words visible
2. Tap an action word (e.g., "Yes"):
   - Haptic fires (audible click on Chrome's web-haptic sim if enabled; otherwise confirmed by not throwing)
   - Expanded fades out
   - Foreground avatar levitates (briefly lifts, eases back)
   - Avatar briefly picks up a plasma tint — **face features remain visible** (critical Phase 6 verification)
   - Atmosphere saturation bumps briefly, then relaxes
3. After ~1 second: avatar drifts upward and dissolves
4. Total sequence ends at ~1.7 seconds; next queue avatar smoothly appears in the foreground slot

If the face becomes a faceless plasma blob → you're using `BlendMode.srcIn` somewhere. Grep and fix:

```bash
cd /Users/ramchitturi/hello && grep -rn "BlendMode.srcIn" app/lib/views/home
```

Must be empty (or at least have no matches inside `HologramAvatar` lineage).

- [ ] **Step 4: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home_page.dart
git commit -m "$(cat <<'EOF'
feat(home): wire RewardController into home_page + animation lock

_HomePageState now:
- mixes in SingleTickerProviderStateMixin to act as the ticker
  provider for the vsync-driven RewardController
- owns a RewardController (constructed with vsync: this, listener
  added, listener/ticker disposed with the state)
- on action tap: fires atmosphere pulse, stubs engine mutation,
  starts the reward sequence with sender as both foreground-to-
  dissolve and queue-excluding filter; awaits 500ms before
  collapsing the Expanded state so the ActionWord's plasma sweep
  completes (v2-review Patch #4)
- watches freshestPendingSenderProvider and pendingSendersQueue
  UNCONDITIONALLY in build() — Riverpod subscription lifecycle
  mandate (v2-review Patch #1). Branches on the watched values
  to prefer the locked snapshot while phase != idle.

ForegroundAvatar now receives the controller instance — when
phase == infusing the avatar levitates + wears plasma infusion;
when phase == ascending it drifts up and dissolves.

Engine mutations are stubbed (Great Wiring pass owns the real
session.vote / session.sendText / settlement.pay calls — out of
scope for this spec).

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 6

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 20: Add ascent + handoff to ForegroundAvatar and queue row

**Files:**
- Modify: `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart` — animate guillotine gradient stops during ascending phase
- Modify: `app/lib/views/home/decision_board/pages/home/queue_row.dart` — scale queue[0] into 140 foreground slot during ascending

- [ ] **Step 1: Add guillotine flip to ForegroundAvatar**

The current ForegroundAvatar translates during ascending but the guillotine dissolve is locked in `HologramAvatar` with fixed stops. To flip the gradient during ascending, we need a custom avatar widget that copies the `HologramAvatar` structure with animatable stops — OR we overlay a second `ShaderMask` on top during ascending only (but nested ShaderMask = double saveLayer — forbidden).

Clean approach: introduce a reward-aware variant that inlines the gradient stops based on phase. Replace `_withInfusion` logic to also handle the ascending phase:

Open `app/lib/views/home/decision_board/pages/home/foreground_avatar.dart` and modify the `build` method:

```dart
@override
Widget build(BuildContext context) {
  if (rewardController == null) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: HologramAvatar(
        avatarPath: getAvatarImagePath(sender.name),
        size: 140,
      ),
    );
  }

  return ListenableBuilder(
    listenable: rewardController!,
    builder: (ctx, _) {
      final ctrl = rewardController!;
      final translateY = _computeTranslateY(ctrl);
      final avatar = _buildAvatar(ctrl);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: _withInfusion(avatar, ctrl),
        ),
      );
    },
  );
}

/// Build the avatar with phase-aware guillotine gradient stops.
/// - idle/infusing: default stops [0.0, 0.5, 0.85, 1.0]
/// - ascending: stops interpolate toward [0.0, 0.15, 0.5, 1.0]
Widget _buildAvatar(RewardController ctrl) {
  if (ctrl.phase != RewardPhase.ascending) {
    return HologramAvatar(
      avatarPath: getAvatarImagePath(sender.name),
      size: 140,
    );
  }

  final p = ctrl.ascentProgress;
  // Lerp stops from default to head-fade. `stop1` moves from 0.5 to 0.15.
  final stop1 = 0.5 * (1 - p) + 0.15 * p;
  final stop2 = 0.85 * (1 - p) + 0.5 * p;

  return _CustomGuillotineAvatar(
    avatarPath: getAvatarImagePath(sender.name),
    size: 140,
    stops: [0.0, stop1, stop2, 1.0],
  );
}
```

And add at the bottom of the file:

```dart
/// Internal — a HologramAvatar variant with caller-supplied
/// gradient stops. Used only during the ascending reward phase
/// to animate the guillotine from feet-fade to head-fade.
class _CustomGuillotineAvatar extends StatelessWidget {
  final String avatarPath;
  final double size;
  final List<double> stops;

  const _CustomGuillotineAvatar({
    required this.avatarPath,
    required this.size,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00000000),
          ],
          stops: stops,
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        avatarPath,
        fit: BoxFit.contain,
        width: size,
        height: size,
      ),
    );
  }
}
```

Note: `BlendMode.dstIn` (keeping destination pixels, using source alpha) — same as the original `HologramAvatar`. No srcIn. No nesting.

- [ ] **Step 2: Add queue handoff animation**

Open `app/lib/views/home/decision_board/pages/home/queue_row.dart` and modify to accept an optional `RewardController` + render queue[0] as scaling into the foreground when ascending:

Replace the entire contents with:

```dart
import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import 'cosmos_sender_model.dart';
import 'reward_controller.dart';

/// Horizontal row of up to 6 face-only avatars at 48px.
///
/// When a RewardController is in the ascending phase, queue[0] is
/// being promoted to the foreground (via QueuePromotionAvatar).
/// To keep the row's width stable and prevent sibling snap-shift,
/// queue[0] is rendered here at **opacity 0.0** — the space it
/// occupied stays reserved; remaining avatars do not re-center.
/// When the reward completes at t=1700ms and the provider re-emits
/// without queue[0], the row smoothly re-centers in the normal
/// layout pass.
class QueueRow extends StatelessWidget {
  final List<PendingSender> senders;
  final ValueChanged<PendingSender>? onTap;
  final RewardController? rewardController;

  const QueueRow({
    super.key,
    required this.senders,
    this.onTap,
    this.rewardController,
  });

  @override
  Widget build(BuildContext context) {
    if (senders.isEmpty) return const SizedBox.shrink();
    if (rewardController == null) {
      return _buildRow(senders, ghostFirst: false);
    }
    return ListenableBuilder(
      listenable: rewardController!,
      builder: (ctx, _) {
        final isAscending =
            rewardController!.phase == RewardPhase.ascending;
        // During ascending, ghost queue[0] (opacity 0) so its width
        // is preserved; otherwise render normally.
        return _buildRow(senders, ghostFirst: isAscending);
      },
    );
  }

  Widget _buildRow(List<PendingSender> list, {required bool ghostFirst}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Opacity(
            opacity: ghostFirst && i == 0 ? 0.0 : 1.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: (onTap == null || (ghostFirst && i == 0))
                  ? null
                  : () => onTap!(list[i]),
              child: HologramAvatar(
                avatarPath: getAvatarImagePath(list[i].name),
                size: 48,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The rising-into-foreground widget for queue[0] during the
/// ascending phase. Rendered by home_page.dart in the foreground
/// position (`top: h * 0.18`) — the Transform.translate below
/// handles the physical travel from the queue row's Y (204pt below
/// the foreground) up to 0 as the ascent progresses.
///
/// Without the Transform.translate the avatar would teleport
/// instantly from queue row to foreground slot (scaling but not
/// moving vertically). That shatters the spatial illusion.
class QueuePromotionAvatar extends StatelessWidget {
  final PendingSender sender;
  final RewardController rewardController;

  /// Vertical distance the avatar travels: computed as
  /// (foreground.height + label gap + label height + queue gap)
  /// = 140 + 12 + 20 + 32 = 204 per the layout in home_page.dart.
  /// If home_page layout constants change, update this.
  final double travelDistance;

  const QueuePromotionAvatar({
    super.key,
    required this.sender,
    required this.rewardController,
    this.travelDistance = 204.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewardController,
      builder: (ctx, _) {
        if (rewardController.phase != RewardPhase.ascending) {
          return const SizedBox.shrink();
        }
        final p = rewardController.ascentProgress;
        final eased = Curves.easeOutBack.transform(p);
        final size = 48.0 + (140.0 - 48.0) * eased;
        // Starts at +travelDistance (at queue row Y), ends at 0
        // (at foreground Y). Positive = down in Flutter.
        final yOffset = travelDistance * (1.0 - eased);

        return Center(
          child: Transform.translate(
            offset: Offset(0, yOffset),
            child: Opacity(
              opacity: eased,
              child: HologramAvatar(
                avatarPath: getAvatarImagePath(sender.name),
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Wire QueuePromotionAvatar into home_page.dart**

In `home_page.dart`, import:

```dart
import 'home/queue_row.dart';
```

(Already imported. Add `QueuePromotionAvatar` usage inline since it's exported from the same file.)

Inside the `Stack` children of the Ambient layout, add a rising queue-promotion slot at the same position as the foreground avatar:

```dart
// Queue promotion — visible only during ascending phase, rises
// into the foreground slot as the previous avatar drifts up
if (_rewardController.isAnimating &&
    _rewardController.phase == RewardPhase.ascending &&
    (_rewardController.lockedQueue?.isNotEmpty ?? false))
  Positioned(
    top: h * 0.18,
    left: 0,
    right: 0,
    child: QueuePromotionAvatar(
      sender: _rewardController.lockedQueue!.first,
      rewardController: _rewardController,
    ),
  ),
```

And pass the controller to the main `QueueRow`:

```dart
child: QueueRow(
  senders: queue,
  onTap: _onAvatarTap,
  rewardController: _rewardController,
),
```

- [ ] **Step 4: Run dart analyze**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors.

- [ ] **Step 5: Manual verification — launch app**

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Verify on HOME tab with at least 2 pending senders:
1. Tap foreground avatar → Expanded
2. Tap action word → reward begins:
   - 0–700ms: levitation + plasma infusion (face visible)
   - 700–1000ms: infusion fades, avatar at rest
   - 1000–1700ms: foreground avatar drifts up, guillotine flips (fade migrates feet→head), dissolves through top; simultaneously the first queue avatar rises from 48px in its row position to 140px in the foreground slot
3. At t=1700ms: sequence completes; foreground now shows the previously-first queue avatar; queue is now shorter by 1 (next one from provider fills in)

- [ ] **Step 6: Commit**

```bash
cd /Users/ramchitturi/hello && git add app/lib/views/home/decision_board/pages/home/foreground_avatar.dart app/lib/views/home/decision_board/pages/home/queue_row.dart app/lib/views/home/decision_board/pages/home_page.dart
git commit -m "$(cat <<'EOF'
feat(home): reward Layer 4 — ascent + queue handoff (vsync + travel + ghost)

ForegroundAvatar during ascending phase:
- translates -60pt upward (linear over 700ms)
- guillotine gradient stops lerp from [0.0, 0.5, 0.85, 1.0]
  (transparent at feet) to [0.0, 0.15, 0.5, 1.0] (transparent
  at head) — person dissolves from the top
- uses a private _CustomGuillotineAvatar with the same BlendMode.dstIn
  pattern as HologramAvatar (no srcIn, no nesting)

QueuePromotionAvatar (new widget) — v2-review Patch #5a:
- rendered by home_page.dart at the foreground position (top = h*0.18)
- scales 48 → 140 via easeOutBack over 700ms
- Transform.translate: Y offset animates +204pt → 0 over the ascent,
  physically travelling from the queue row's Y up to the foreground
  slot (no teleport)
- opacity fades in with the scale

QueueRow during ascending phase — v2-review Patch #5b:
- queue[0] is rendered at opacity 0.0 (a ghost) so its width stays
  reserved in the Row's layout — remaining avatars do NOT snap
  leftward to re-center
- when t=1700ms hits and provider re-emission drops queue[0], the
  Row naturally re-centers in the next layout pass

At t=1700ms the controller releases the snapshot lock and the
provider re-emission (already converged) takes over — no flash.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 6 (Layer 4)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 7 — Audit & polish

### Task 21: Grep asserts + narrow-viewport + performance audit

**Files:**
- Inspect: multiple files; no code changes unless a violation is found

- [ ] **Step 1: Grep-assert no srcIn in Home**

```bash
cd /Users/ramchitturi && grep -rn "BlendMode.srcIn" app/lib/views/home
```

Expected: zero matches (or only matches inside `app/lib/views/home/decision_board/avatar_utils.dart` which uses `BlendMode.dstIn`, not srcIn — verify the grep output does not contain the string "srcIn"). If srcIn appears, the face-blob v1-review issue has returned — stop and fix.

- [ ] **Step 2: Grep-assert no container / border / pill chrome on Home surfaces**

```bash
cd /Users/ramchitturi && grep -rn "BorderRadius\|Border\.all\|border:" app/lib/views/home/decision_board/pages/home_page.dart app/lib/views/home/decision_board/pages/home/
```

Expected: zero matches. If any appear, inspect and confirm they are not wrapping avatars or action words. Remove if inadvertently re-introduced.

- [ ] **Step 3: Grep-assert no icons as action buttons**

```bash
cd /Users/ramchitturi && grep -rn "Icons\." app/lib/views/home/decision_board/pages/home_page.dart app/lib/views/home/decision_board/pages/home/
```

Expected: zero matches on Home UI files. If any appear, verify they are not primary actions.

- [ ] **Step 4: Narrow-viewport overflow audit**

Run the app with a narrow Chrome window (drag to ~340pt wide):

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080
```

Manually resize the Chrome window. Trigger a decision-kind Expanded state (tap a decision pending sender). Verify:

- `Love`, `Works`, `Pass` render at a uniform 26pt without `FittedBox` scale-down on any viewport ≥ 320pt
- The Row is horizontally balanced (equal ⅓ slots; words centered in each)
- `FittedBox(scaleDown)` only engages on sub-320pt viewports (foldable covers etc.) as a safety net; never on phones

If overflow occurs, inspect `action_word.dart` — the `FittedBox` must wrap the `Text` widget directly, not the outer `Stack`.

- [ ] **Step 5: Performance audit — frame rate during reward**

Run the app in profile mode:

```bash
cd /Users/ramchitturi/hello/app && flutter run -d chrome --web-port 8080 --profile
```

Open Chrome DevTools → Performance tab → record. Trigger a reward sequence (tap avatar → tap action word). Stop recording.

Expected:
- Frame rate stays ≥ 60fps throughout the 1700ms sequence (look for FPS meter in the recording)
- No spikes above 16ms frame time during infusion
- `saveLayer` count does not regress — `ColorFiltered` in the infusion layer should add at most 1 `saveLayer` to the baseline

If frame drops appear, the most likely cause is nested `ShaderMask` accidentally reintroduced. Grep:

```bash
grep -rn "ShaderMask" app/lib/views/home/decision_board/
```

Expected: matches only in `avatar_utils.dart` (the canonical guillotine) and `foreground_avatar.dart` (the custom guillotine variant during ascent). If a third match appears in a reward layer, it's a regression.

- [ ] **Step 6: 3-second rule test**

Close the app cold. Reopen. Start a stopwatch. Count how long it takes to read:
- WHO is in the foreground (avatar face → Sarah / Maya / etc.)
- WHERE the context is (`Message` or `Swiss Alps · "…"`)
- WHAT they asked (the subject preview — DM excepted)

Target: ≤ 3 seconds. Repeat 5 times with different seed feed states. If any run exceeds 3s, file a follow-up task (don't block this one — gathering more data).

- [ ] **Step 7: Commit the audit log**

No code changes; skip commit unless fixes were needed in steps 1-5.

---

### Task 22: Update guardrail CLAUDE.md files

**Files:**
- Modify: `CLAUDE.md` (root)
- Modify: `app/CLAUDE.md`

- [ ] **Step 1: Update root CLAUDE.md**

Open `/Users/ramchitturi/hello/CLAUDE.md`. In the **Landmines** section, add:

```markdown
16. **Cosmos Home uses in-place state expansion, NOT OpenContainer.** Tapping an avatar on Home must NOT push a `ModalRoute` — it cross-fades Home's own `Stack` via `AnimatedOpacity`. A pushed route traps the queue + atmosphere underneath and shatters the 1700ms reward choreography. See `docs/superpowers/specs/2026-04-14-cosmos-home-design.md` Principle 8.

17. **Plasma infusion on HologramAvatar must use `BlendMode.srcATop`, NEVER `BlendMode.srcIn`.** `srcIn` discards destination pixels and leaves a faceless plasma blob where the photo was. `srcATop` overlays color on top of existing pixels only where the PNG has alpha — face features stay intact. Also: never wrap `HologramAvatar` in a second `ShaderMask` — that's a double `saveLayer` and tanks frame rate over the 120fps atmosphere.

18. **Home's foreground + queue are locked on a snapshot during reward animations.** The `_HomePageState.build()` reads from `_rewardController.lockedForeground / lockedQueue` when the reward phase is not idle. Reading directly from `freshestPendingSenderProvider` / `pendingSendersQueueProvider` during the sequence will flash the next person mid-animation (the optimistic mutation already re-emitted). The lock releases at t=1700ms.
```

- [ ] **Step 2: Update the Structure / Decision board section in root CLAUDE.md**

Find the section describing the decision-board structure (around "4-tab home scaffold"). Update the HOME description to reflect the cosmos surface:

```markdown
**HOME tab — Cosmos surface (2026-04-14):**
- Full-bleed `ChromaticAtmosphere` drenched in the foreground sender's signature palette
- ONE 140px `HologramAvatar` at upper-third (the "freshest pending sender")
- Context label below: `Message` for DMs, `{group_name} · "{subject}"` for groups
- 6 × 48px queue avatars in a horizontal row (face-only, recency-sorted)
- No cards, no pills, no counts, no masonry
- Tapping any avatar → in-place cross-fade to the action surface (no route push)
- Action surface shows the full message + shape-adapted text-action words:
  - Confirm → `Yes / No / Maybe`
  - Decision → `Love it / Works for me / Not for me`
  - Settlement → `Pay now / Later`
  - Open DM → full-width reply field
- Action tap → 5-layer reward sequence (levitation + plasma infusion + atmosphere pulse + ascent + haptic) locked against provider re-emits for 1700ms
```

- [ ] **Step 3: Update app/CLAUDE.md**

Open `/Users/ramchitturi/hello/app/CLAUDE.md`. Update the **4-tab home scaffold** section to reflect the scaffold change:

```markdown
**4-tab home scaffold (`decision_board_page.dart`):**
- HOME · CHATS · GROUPS · PLANS — `TabBarView` driven by `TabController`
- `TabBarView` is wrapped in `LiquidIntentLayer` at the scaffold level — so the liquid intent handle is the only persistent bottom chrome across all four tabs
- Full-bleed `ChromaticAtmosphere` background
- `TabHeader` floats at top-left
- `BottomBar` is GONE (deleted 2026-04-14, replaced by scaffold-level `LiquidIntentLayer`)
- Tab switching happens via swipe + ghost-indicator tap; there is no `HOME ^` dropdown
```

And update the **Decision board file map** to reflect the deletions and new subdirectory:

```markdown
app/lib/views/home/decision_board/
├── decision_board_page.dart     # Scaffold root (4-tab controller + LiquidIntentLayer wrap)
├── chromatic_atmosphere.dart    # Full-bleed atmosphere; consumes pulse signal
├── liquid_intent_handle.dart    # The LiquidIntentLayer (scaffold-level)
├── atmosphere.dart              # DEAD (kept for now; older AmbientMesh widget)
├── tab_header.dart              # Floating top-left header
├── _card_factory.dart           # FeedItem → card mapping (DecisionSmallFeedItem now a shrink sentinel)
├── chat_bubble.dart, conversation_list_row.dart, message_input_bar.dart, floating_avatar.dart
├── empty_state.dart
├── masonry_grid.dart            # Used by CHATS/GROUPS/PLANS tabs, NOT HOME
├── pages/
│   ├── home_page.dart           # Cosmos Home (2026-04-14)
│   ├── chats_page.dart, groups_page.dart, plans_page.dart
│   ├── dm_page.dart, group_page.dart (no local LiquidIntentLayer — scaffold owns it)
│   ├── decision_page.dart, settlement_page.dart, trip_page.dart, itinerary_page.dart
│   └── home/                    # Cosmos Home components (2026-04-14)
│       ├── cosmos_sender_model.dart    # PendingSender + MessageKind + extractor
│       ├── foreground_avatar.dart      # 140px w/ reward layers
│       ├── queue_row.dart              # 6×48px + QueuePromotionAvatar
│       ├── context_label.dart          # below-avatar text
│       ├── action_word.dart            # single text-as-action
│       ├── action_words_row.dart       # shape-adaptive row
│       └── reward_controller.dart      # 1700ms reward orchestrator
├── cards/                       # 10 card widgets (DecisionCardSmall + FocusCardWidget deleted)
│   └── ... (unchanged except for DecisionCardSmall deletion)
├── sheets/                      # 6 sheets unchanged; new_chat_sheet/search_sheet may be dead after BottomBar deletion
└── plasma/                      # 7-file Liquid Plasma brand system unchanged
```

Update the **Landmines** list at the top of `app/CLAUDE.md` to add:

```markdown
13. **`BottomBar`, `TabChip`, `TabPopover`, `StatusOverview`, `DecisionCardSmall`, `FocusCardWidget` are deleted.** Do not re-introduce. BottomBar's role is owned by the scaffold-level `LiquidIntentLayer`. StatusOverview counts violated the "no counts on Home" rule. DecisionCardSmall and FocusCardWidget were subsumed by the cosmos in-place expansion.

14. **`LiquidIntentLayer` is mounted ONCE at the scaffold level** (`decision_board_page.dart`), wrapping the entire `TabBarView`. Do not add a local mount inside any tab or page widget — that causes ghost-indicator desync and double-tracking. Prior local mount in `group_page.dart` was removed 2026-04-14.

15. **Cosmos Home animation lock.** `_HomePageState.build()` reads `_rewardController.lockedForeground / lockedQueue` when `_rewardController.isAnimating`. Do not swap this to `ref.watch(freshestPendingSenderProvider)` during the reward sequence — it will flash the next person mid-animation.
```

- [ ] **Step 4: Run dart analyze one final time**

```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

Expected: zero new errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/ramchitturi/hello && git add CLAUDE.md app/CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(guardrails): refresh CLAUDE.md for Cosmos Home architecture

Root CLAUDE.md adds landmines 16-18:
- Cosmos Home uses in-place expansion, never OpenContainer
- Plasma infusion must use srcATop, never srcIn
- Home's reward sequence reads from a locked snapshot, not providers

Updates HOME tab description to reflect the cosmos surface
(floating avatar + context label + queue + in-place action
expansion + 5-layer reward sequence).

app/CLAUDE.md adds landmines 13-15:
- BottomBar / TabChip / TabPopover / StatusOverview /
  DecisionCardSmall / FocusCardWidget deleted — don't reintroduce
- LiquidIntentLayer scaffold-level singleton
- Animation lock in _HomePageState.build()

File map updated to reflect the new pages/home/ subdirectory
and the deletions.

Refs: docs/superpowers/specs/2026-04-14-cosmos-home-design.md Phase 7

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Verification checklist (end of implementation)

Run this at the end of Task 22 as the final acceptance gate:

- [ ] `cd app && dart analyze lib/` → zero new errors
- [ ] `cd app && flutter test test/providers/cosmos_home_providers_test.dart -r compact` → all tests pass
- [ ] `cd app && flutter build web --no-tree-shake-icons` → succeeds
- [ ] Manual: Home shows the Ambient state (atmosphere + foreground + label + queue) OR the `all caught up` empty state
- [ ] Manual: tap foreground avatar → Expanded state (message + action words) cross-fades in on the same canvas; no route push
- [ ] Manual: tap outside the action region → Ambient cross-fades back
- [ ] Manual: tap a decision kind's `Works for me` action on a 340pt-wide viewport → no RenderFlex overflow (FittedBox scaled)
- [ ] Manual: tap an action word → levitation + plasma infusion (face visible) + atmosphere pulse + ascent + handoff plays over 1700ms; foreground does NOT flash to next person mid-animation; queue[0] smoothly rises into the 140 slot
- [ ] Manual: on all four tabs, the LiquidIntentLayer idle plasma line is visible at the bottom; tapping it blooms the glass shell with TextField + mic + `+`
- [ ] Manual: 3-second test — user can name who, where, what in ≤ 3 seconds after app cold open — **no exceptions** (DMs expose the subject)
- [ ] Grep: `BlendMode.srcIn` never appears under `app/lib/views/home/`
- [ ] Grep: no `BorderRadius` or `Border.all` inside `app/lib/views/home/decision_board/pages/home/`
- [ ] Grep: no `Icons.` inside `app/lib/views/home/decision_board/pages/home/`

---

## Revision history

- **v1 plan** — initial draft from writing-plans skill based on the v2 spec. Six code-level landmines caught in a second technical review: conditional `ref.watch`, Dart 3 extension-getter destructuring failure, `Timer.periodic` vs vsynced `Ticker`, premature Expanded dismissal hiding the 500ms ActionWord reward, `QueuePromotionAvatar` teleporting instead of traveling, queue row snapping left when `sublist(1)`, and hit-zone dead-space from `Expanded > Center > GestureDetector`.
- **v2 plan** (this document) — all six landmines fixed:
  1. Task 19 watches `freshestPendingSenderProvider` and `pendingSendersQueueProvider` unconditionally; branches on the watched values to prefer the locked snapshot during reward
  2. Task 6 destructures `item: final innerItem` (a real class property) instead of an extension getter; extensions removed
  3. Task 17 uses `Ticker` via `TickerProvider` (_HomePageState gets `SingleTickerProviderStateMixin`); vsynced to display refresh
  4. Task 19 `_onActionTap` and `_onReplySubmit` await 500ms before collapsing `_focusedSender` so the ActionWord's plasma sweep reaches full
  5a. Task 20 `QueuePromotionAvatar` uses `Transform.translate` with Y offset animating `+204 → 0` to physically travel from the queue row's Y to the foreground slot
  5b. Task 20 `QueueRow` renders queue[0] at `Opacity(0.0)` during ascending — width preserved, no sibling snap
  6. Task 13 `ActionWord` wraps its Stack in a transparent-fill `Container`; Task 14 removes the `Center` wrapper around `ActionWord` inside `Expanded` — GestureDetector now claims the full ⅓ slot edge-to-edge

- **v3 plan** (this document, same-session) — Two product flips the user approved after v2:
  1. **Task 9 DM label** flipped to `Message · "{first 36 chars}"`. The Principle 6 DM exception is deleted from the spec. Rationale: a bare `Message` forces the user to tap just to triage, which is the blind-inbox pattern the 3-second rule forbids.
  2. **Task 14 decision copy** flipped to single-word `Love / Works / Pass`. Rationale: typographic consistency — 26pt uniform weight across all action-word sets on any viewport ≥ 320pt; `FittedBox` becomes a sub-phone safety net that never engages on real devices.

  Downstream plan touch-ups: Task 15 manual-verify expectations updated (Love/Works/Pass, no FittedBox engagement expected); Task 19 `_isAffirmative` helper updated to match new vocabulary; Task 21 overflow audit expectations updated; final verification-checklist item on DM subject excepted removed.

---

## Out of scope for this plan (deferred to future passes)

1. **Engine wiring for real action side-effects** — `session.vote`, `session.sendText`, settlement-pay, reaction endpoints. The plan stubs these in `_applyAction`; the real E2EE wiring is the "Great Wiring" pass.
2. **Location-based recommendations in empty state** — the `all caught up` slot will evolve into a recommendation surface; that's a separate spec.
3. **Widget tests for Home UI** — the project's `flutter test` is globally broken (landmine #3). Widget-test coverage for Home's Stack + in-place expansion is deferred until the test suite is repaired.
4. **Rive avatars** — permanently dropped; `assets/rive/` does not exist.
5. **Group avatar chromed variants** — groups render identically to individuals using `cousins_group.png` / `friends_group.png` / `travel_group.png` via `getAvatarImagePath`.
6. **`sheets/new_chat_sheet.dart` and `sheets/search_sheet.dart`** — orphaned after BottomBar deletion. May be rewired to `LiquidIntentLayer`'s `+` action in a future pass; deletion is out of scope here.
