# Mode Chip Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task.

**Goal:** Rebuild the home screen as a 4-tab scaffold (`TabController` + `TabBarView`) with a mode-chip bottom bar (`[HOME ▾] search 🎤/↑ [+]`), a floating top-left avatar (no top bar chrome), and per-tab filtered feed pages — per `docs/superpowers/specs/2026-04-11-mode-chip-home-design.md`.

**Architecture:** `DecisionBoardPage` owns a `TabController(length: 4)` and renders 4 page widgets in a `TabBarView`. Each page is a `ConsumerStatefulWidget` with `AutomaticKeepAliveClientMixin` and renders a masonry feed from its own filtered provider. A `BottomBar` widget at `bottomCenter` contains the tab chip, search field, mic/send button, and compose button. A `FloatingAvatar` sits at top-left.

**Tech stack:** Flutter, Riverpod 3.x (StateProvider via `legacy.dart`), `flutter_staggered_grid_view` (already installed), `e2ee_chat_sdk` (existing).

---

## File structure

| Path | Track | Purpose |
|---|---|---|
| `app/lib/providers/tabs_provider.dart` | 1 | `activeTabIndexProvider` + `HomeTab` enum |
| `app/lib/providers/filtered_feed_providers.dart` | 1 | `homeFeedProvider`, `chatsFeedProvider`, `groupsFeedProvider`, `plansFeedProvider` |
| `app/lib/views/home/decision_board/tab_chip.dart` | 2 | `[HOME ▾]` chip with caret, tap-to-open popover |
| `app/lib/views/home/decision_board/tab_popover.dart` | 2 | Overlay-based 4-row popover |
| `app/lib/views/home/decision_board/bottom_bar.dart` | 3 | Full glass pill: `[TabChip] search 🎤/↑ [+]` |
| `app/lib/views/home/decision_board/floating_avatar.dart` | 4 | 36px floating user avatar (no bar chrome) |
| `app/lib/views/home/decision_board/_card_factory.dart` | 5 | Shared `buildFeedItemCard(context, item)` switch |
| `app/lib/views/home/decision_board/pages/home_page.dart` | 5 | HOME tab page (full mixed feed + focus hero) |
| `app/lib/views/home/decision_board/pages/chats_page.dart` | 5 | CHATS tab page (DMs only) |
| `app/lib/views/home/decision_board/pages/groups_page.dart` | 5 | GROUPS tab page (groups only) |
| `app/lib/views/home/decision_board/pages/plans_page.dart` | 5 | PLANS tab page (focus + trips + itinerary) |
| `app/lib/views/home/decision_board/decision_board_page.dart` | **Wave 2** | Rewrite as TAB SCAFFOLD |
| `app/lib/views/home/decision_board/search_compose_bar.dart` | **Wave 2** | DELETE |
| `app/lib/views/home/decision_board/feed_header.dart` | **Wave 2** | DELETE |

---

## Shared interface contracts

All parallel tracks reference these contracts so they can write to agreement without reading each other's files.

### Contract A — `HomeTab` enum + tab index provider

```dart
// app/lib/providers/tabs_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum HomeTab { home, chats, groups, plans }

extension HomeTabDisplay on HomeTab {
  String get label => switch (this) {
    HomeTab.home => 'HOME',
    HomeTab.chats => 'CHATS',
    HomeTab.groups => 'GROUPS',
    HomeTab.plans => 'PLANS',
  };

  String get titleCase => switch (this) {
    HomeTab.home => 'Home',
    HomeTab.chats => 'Chats',
    HomeTab.groups => 'Groups',
    HomeTab.plans => 'Plans',
  };

  String get searchHint => switch (this) {
    HomeTab.home => 'Search or a name…',
    HomeTab.chats => 'Search chats or a name…',
    HomeTab.groups => 'Search groups…',
    HomeTab.plans => 'Search plans…',
  };

  Color get signatureColor => switch (this) {
    HomeTab.home => const Color(0xFF7C3AED),
    HomeTab.chats => const Color(0xFF8B5CF6),
    HomeTab.groups => const Color(0xFFF97316),
    HomeTab.plans => const Color(0xFF4A90E2),
  };

  IconData get icon => switch (this) {
    HomeTab.home => Icons.home_rounded,
    HomeTab.chats => Icons.chat_bubble_outline_rounded,
    HomeTab.groups => Icons.people_outline_rounded,
    HomeTab.plans => Icons.map_outlined,
  };
}

/// The active tab index. Updated by a TabController listener in
/// decision_board_page.dart.
final activeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Derived HomeTab enum from the index.
final activeTabProvider = Provider<HomeTab>((ref) {
  final index = ref.watch(activeTabIndexProvider);
  return HomeTab.values[index.clamp(0, HomeTab.values.length - 1)];
});
```

### Contract B — Filtered feed providers

```dart
// app/lib/providers/filtered_feed_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'feed_provider.dart';

/// HOME tab feed — the full unified feed, unchanged.
final homeFeedProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider);
});

/// CHATS tab feed — only DmFeedItem, sorted by recency.
final chatsFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  return feed.whereType<DmFeedItem>().cast<FeedItem>().toList()
    ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
});

/// GROUPS tab feed — only GroupFeedItem, sorted by recency.
final groupsFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  return feed.whereType<GroupFeedItem>().cast<FeedItem>().toList()
    ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
});

/// PLANS tab feed — focus hero + trips + itinerary events.
final plansFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  final items = <FeedItem>[];
  items.addAll(feed.whereType<FocusHeroFeedItem>());
  items.addAll(feed.whereType<TripFeedItem>());
  items.addAll(feed.whereType<ItineraryFeedItem>());
  return items;
});
```

### Contract C — TabChip + TabPopover (Track 2)

```dart
// app/lib/views/home/decision_board/tab_chip.dart

class TabChip extends ConsumerWidget {
  final VoidCallback onTap;
  const TabChip({super.key, required this.onTap});
  // Renders: [activeTab.label ▾] capsule. Watches activeTabProvider.
  // On tap → calls onTap (which opens the popover).
}

// app/lib/views/home/decision_board/tab_popover.dart

/// Shows the 4-tab popover above the given [anchorKey]'s render box.
/// Returns the selected tab index, or null if dismissed without selection.
Future<int?> showTabPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
});
```

### Contract D — BottomBar (Track 3)

```dart
// app/lib/views/home/decision_board/bottom_bar.dart

class BottomBar extends ConsumerStatefulWidget {
  final void Function(int index) onTabSelected;  // popover → switch tab
  final VoidCallback onSearchSubmit;              // send arrow tap
  final VoidCallback onComposeTap;                // + button tap
  const BottomBar({
    super.key,
    required this.onTabSelected,
    required this.onSearchSubmit,
    required this.onComposeTap,
  });
}
```

### Contract E — FloatingAvatar (Track 4)

```dart
// app/lib/views/home/decision_board/floating_avatar.dart

class FloatingAvatar extends StatelessWidget {
  const FloatingAvatar({super.key});
  // Renders a 36px circle with initial "R" at absolute top-left.
  // Positioned by the caller via Positioned or Align.
}
```

### Contract F — Card factory + pages (Track 5)

```dart
// app/lib/views/home/decision_board/_card_factory.dart

/// Shared switch from FeedItem variant → appropriate card widget.
/// Each card's onTap is wired to open the right sheet directly.
Widget buildFeedItemCard(BuildContext context, FeedItem item);

// app/lib/views/home/decision_board/pages/home_page.dart
class HomePage extends ConsumerStatefulWidget { const HomePage({super.key}); }

// app/lib/views/home/decision_board/pages/chats_page.dart
class ChatsPage extends ConsumerStatefulWidget { const ChatsPage({super.key}); }

// app/lib/views/home/decision_board/pages/groups_page.dart
class GroupsPage extends ConsumerStatefulWidget { const GroupsPage({super.key}); }

// app/lib/views/home/decision_board/pages/plans_page.dart
class PlansPage extends ConsumerStatefulWidget { const PlansPage({super.key}); }
```

Each page renders a `CustomScrollView` with a `SliverPadding` + `MasonryFeedGrid`, watches its own filtered feed provider, and uses `buildFeedItemCard` to render each item. Bottom padding ~96px to clear the bottom bar.

---

## Wave 1 — Parallel tracks (5 subagents)

Each track writes its own files and commits. Interface contracts above are the agreement.

### Track 1: Providers

**Files:**
- Create `app/lib/providers/tabs_provider.dart`
- Create `app/lib/providers/filtered_feed_providers.dart`

**Steps:**
- [ ] Step 1: Copy Contract A code verbatim into `tabs_provider.dart`
- [ ] Step 2: Copy Contract B code verbatim into `filtered_feed_providers.dart`
- [ ] Step 3: Verify `cd /Users/ramchitturi/hello/app && dart analyze lib/providers/tabs_provider.dart lib/providers/filtered_feed_providers.dart` → "No issues found!"
- [ ] Step 4: Commit
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/providers/tabs_provider.dart app/lib/providers/filtered_feed_providers.dart
  git commit -m "feat(home): add HomeTab enum + filtered feed providers"
  ```

---

### Track 2: TabChip + TabPopover

**Files:**
- Create `app/lib/views/home/decision_board/tab_chip.dart`
- Create `app/lib/views/home/decision_board/tab_popover.dart`

Depends on Track 1's `tabs_provider.dart` for `activeTabProvider`, `HomeTab`, `HomeTabDisplay`. Analyze may flag this as unresolved until Track 1 commits. Commit anyway.

#### `tab_chip.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';

/// The `[HOME ▾]` chip that lives on the BottomBar. Watches
/// [activeTabProvider] and shows the current tab's label + caret.
/// Tapping invokes [onTap] (which the BottomBar wires to open the
/// TabPopover).
class TabChip extends ConsumerWidget {
  final VoidCallback onTap;
  const TabChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(activeTabProvider);
    final accent = tab.signatureColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(
          color: HelloColors.recessed.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
                color: accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 14,
              color: accent.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### `tab_popover.dart`

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';

/// Shows a glass popover above the given [anchorKey]'s render box
/// with 4 tab rows. Returns the selected tab index (0-3) or null if
/// dismissed without selection.
Future<int?> showTabPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required int activeIndex,
}) async {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) return null;
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;

  final anchorOffset = renderBox.localToGlobal(Offset.zero);
  final anchorSize = renderBox.size;

  return showGeneralDialog<int?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'TabPopover',
    barrierColor: Colors.black.withValues(alpha: 0.04),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) {
      return Stack(
        children: [
          Positioned(
            left: anchorOffset.dx,
            top: anchorOffset.dy - 216,
            width: 200,
            child: _TabPopoverCard(activeIndex: activeIndex),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          alignment: Alignment.bottomLeft,
          child: child,
        ),
      );
    },
  );
}

class _TabPopoverCard extends StatelessWidget {
  final int activeIndex;
  const _TabPopoverCard({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < HomeTab.values.length; i++)
                _TabRow(
                  tab: HomeTab.values[i],
                  isActive: i == activeIndex,
                  onTap: () => Navigator.of(context).pop(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final HomeTab tab;
  final bool isActive;
  final VoidCallback onTap;
  const _TabRow({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tab.signatureColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                tab.icon,
                size: 16,
                color: tab.signatureColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tab.titleCase,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ),
            if (isActive)
              Icon(
                Icons.check_rounded,
                size: 16,
                color: tab.signatureColor,
              ),
          ],
        ),
      ),
    );
  }
}
```

**Steps:**
- [ ] Step 1: Create both files with the exact code above
- [ ] Step 2: Verify `dart analyze lib/views/home/decision_board/tab_chip.dart lib/views/home/decision_board/tab_popover.dart`. Any `undefined_identifier` for `HomeTab`, `activeTabProvider`, `HomeTabDisplay` is expected (cross-track) — commit anyway.
- [ ] Step 3: Commit
  ```
  git add app/lib/views/home/decision_board/tab_chip.dart app/lib/views/home/decision_board/tab_popover.dart
  git commit -m "feat(home): add TabChip + TabPopover widgets"
  ```

---

### Track 3: BottomBar

**File:**
- Create `app/lib/views/home/decision_board/bottom_bar.dart`

Depends on Track 2's `TabChip` and `showTabPopover`, Track 1's providers, Track 4's `FloatingAvatar` NOT needed. Analyze may flag cross-track deps; commit anyway.

```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'tab_chip.dart';
import 'tab_popover.dart';

/// The bottom glass pill. Layout (left → right):
///   [TabChip]   Search text field   mic/send   [+]
///
/// Mic morphs into a send arrow when text is present. `+` is the
/// compose button tinted by the focus trip's accent color.
class BottomBar extends ConsumerStatefulWidget {
  final void Function(int index) onTabSelected;
  final VoidCallback onSearchSubmit;
  final VoidCallback onComposeTap;

  const BottomBar({
    super.key,
    required this.onTabSelected,
    required this.onSearchSubmit,
    required this.onComposeTap,
  });

  @override
  ConsumerState<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<BottomBar> {
  final GlobalKey _chipKey = GlobalKey();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final next = _controller.text.isNotEmpty;
    if (next != _hasText) {
      setState(() => _hasText = next);
    }
  }

  Future<void> _openPopover() async {
    final activeIndex = ref.read(activeTabIndexProvider);
    final selected = await showTabPopover(
      context,
      anchorKey: _chipKey,
      activeIndex: activeIndex,
    );
    if (selected != null && selected != activeIndex) {
      widget.onTabSelected(selected);
    }
  }

  void _handleSend() {
    widget.onSearchSubmit();
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(activeTabProvider);
    final focus = ref.watch(focusTripProvider);
    final composeAccent = focus?.accentColor ?? HelloColors.accent;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyedSubtree(
                    key: _chipKey,
                    child: TabChip(onTap: _openPopover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 1,
                      cursorColor: HelloColors.inkPrimary,
                      cursorWidth: 1,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: tab.searchHint,
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: HelloColors.inkTertiary,
                        ),
                        isDense: true,
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _hasText
                        ? _CircleButton(
                            key: const ValueKey<String>('send'),
                            icon: Icons.arrow_upward_rounded,
                            onTap: _handleSend,
                            background: composeAccent,
                            iconColor: const Color(0xFFF0EFF4),
                          )
                        : _CircleButton(
                            key: const ValueKey<String>('mic'),
                            icon: Icons.mic_none_rounded,
                            onTap: () {},
                            background: HelloColors.recessed,
                            iconColor: HelloColors.inkSecondary,
                          ),
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    icon: Icons.add,
                    onTap: widget.onComposeTap,
                    background: HelloColors.recessed,
                    iconColor: composeAccent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;

  const _CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.iconColor,
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
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}
```

**Steps:**
- [ ] Step 1: Create the file with the exact code
- [ ] Step 2: Verify. Cross-track `undefined_identifier` OK.
- [ ] Step 3: Commit
  ```
  git add app/lib/views/home/decision_board/bottom_bar.dart
  git commit -m "feat(home): add BottomBar glass pill — chip + search + mic-send + compose"
  ```

---

### Track 4: FloatingAvatar

**File:**
- Create `app/lib/views/home/decision_board/floating_avatar.dart`

Self-contained, no cross-track deps beyond `theme.dart`.

```dart
import 'package:flutter/material.dart';

import '../../../theme.dart';

/// A 36px user avatar circle that floats at top-left, positioned by
/// the caller via `Positioned` or `Align`. Replaces the previous
/// `feed_header.dart` strip — no bar chrome around it, just the
/// avatar on top of the feed.
class FloatingAvatar extends StatelessWidget {
  const FloatingAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // v2: profile / settings
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HelloColors.recessed,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          'R',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
```

**Steps:**
- [ ] Step 1: Create file
- [ ] Step 2: Verify → "No issues found!"
- [ ] Step 3: Commit
  ```
  git add app/lib/views/home/decision_board/floating_avatar.dart
  git commit -m "feat(home): add FloatingAvatar — 36px top-left circle, no bar chrome"
  ```

---

### Track 5: Card factory + 4 pages

**Files:**
- Create `app/lib/views/home/decision_board/_card_factory.dart`
- Create `app/lib/views/home/decision_board/pages/home_page.dart`
- Create `app/lib/views/home/decision_board/pages/chats_page.dart`
- Create `app/lib/views/home/decision_board/pages/groups_page.dart`
- Create `app/lib/views/home/decision_board/pages/plans_page.dart`

Depends on Track 1's filtered feed providers. Cross-track analyze fails are OK.

#### `_card_factory.dart`

```dart
import 'package:flutter/material.dart';

import '../../../models/feed_item.dart';
import '../../../theme.dart';
import 'cards/ai_nudge_card.dart';
import 'cards/decision_card_hero.dart';
import 'cards/decision_card_small.dart';
import 'cards/dm_card.dart';
import 'cards/focus_hero_card.dart';
import 'cards/group_card.dart';
import 'cards/itinerary_card.dart';
import 'cards/memory_card.dart';
import 'cards/settlement_card.dart';
import 'cards/trip_card.dart';
import 'sheets/decision_sheet.dart';
import 'sheets/dm_sheet.dart';
import 'sheets/group_sheet.dart';
import 'sheets/settlement_sheet.dart';

/// Shared factory — maps a [FeedItem] variant to its widget and
/// wires its onTap to the correct sheet or route. Used by all 4
/// tab pages so each page has identical card rendering behavior.
Widget buildFeedItemCard(BuildContext context, FeedItem item) {
  void stubSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: HelloColors.recessed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void openTripRoute(String tripId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: HelloColors.voidBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: HelloColors.inkPrimary),
          ),
          body: Center(
            child: Text(
              'Trip · $tripId\n\nComing in v1.1',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  return switch (item) {
    DmFeedItem() => DmCard(
        item: item,
        onTap: () => openDmSheet(context, item),
      ),
    GroupFeedItem() => GroupCard(
        item: item,
        onTap: () => openGroupSheet(context, item),
      ),
    DecisionSmallFeedItem() => DecisionCardSmall(
        item: item,
        onTap: () => openDecisionSheet(context, item),
      ),
    DecisionHeroFeedItem() => DecisionCardHero(
        item: item,
        onTap: () => openDecisionSheet(context, item),
      ),
    TripFeedItem() => TripCard(
        item: item,
        onTap: () => openTripRoute(item.trip.id),
      ),
    SettlementFeedItem() => SettlementCard(
        item: item,
        onTap: () => openSettlementSheet(context, item),
      ),
    ItineraryFeedItem() => ItineraryCard(
        item: item,
        onTap: () => stubSnack('Itinerary — coming in v1.1'),
      ),
    MemoryFeedItem() => MemoryCard(
        item: item,
        onTap: () => stubSnack('Memory — coming in v1.1'),
      ),
    AiNudgeFeedItem() => AiNudgeCard(
        item: item,
        onTap: () => stubSnack('@hello nudge — coming in v1.1'),
      ),
    FocusHeroFeedItem() => FocusHeroCard(
        item: item,
        onTap: () => openTripRoute(item.trip.id),
      ),
  };
}
```

#### `pages/home_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../_card_factory.dart';
import '../masonry_grid.dart';

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
    final feed = ref.watch(homeFeedProvider);

    // Split out FocusHero for the top sliver; rest goes into masonry.
    final focusItems = feed.whereType<FocusHeroFeedItem>().toList();
    final focusItem = focusItems.isEmpty ? null : focusItems.first;
    final rest =
        feed.where((i) => i is! FocusHeroFeedItem).toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        if (focusItem != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: buildFeedItemCard(context, focusItem),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: MasonryFeedGrid(
            itemCount: rest.length,
            itemBuilder: (ctx, i) => buildFeedItemCard(ctx, rest[i]),
          ),
        ),
      ],
    );
  }
}
```

#### `pages/chats_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/filtered_feed_providers.dart';
import '../_card_factory.dart';
import '../masonry_grid.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(chatsFeedProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: MasonryFeedGrid(
            itemCount: feed.length,
            itemBuilder: (ctx, i) => buildFeedItemCard(ctx, feed[i]),
          ),
        ),
      ],
    );
  }
}
```

#### `pages/groups_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/filtered_feed_providers.dart';
import '../_card_factory.dart';
import '../masonry_grid.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(groupsFeedProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: MasonryFeedGrid(
            itemCount: feed.length,
            itemBuilder: (ctx, i) => buildFeedItemCard(ctx, feed[i]),
          ),
        ),
      ],
    );
  }
}
```

#### `pages/plans_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../_card_factory.dart';
import '../masonry_grid.dart';

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key});

  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(plansFeedProvider);

    final focusItems = feed.whereType<FocusHeroFeedItem>().toList();
    final focusItem = focusItems.isEmpty ? null : focusItems.first;
    final rest =
        feed.where((i) => i is! FocusHeroFeedItem).toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        if (focusItem != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: buildFeedItemCard(context, focusItem),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: MasonryFeedGrid(
            itemCount: rest.length,
            itemBuilder: (ctx, i) => buildFeedItemCard(ctx, rest[i]),
          ),
        ),
      ],
    );
  }
}
```

**Steps:**
- [ ] Step 1: Create all 5 files
- [ ] Step 2: Verify. Cross-track `undefined_identifier` OK.
- [ ] Step 3: Commit
  ```
  git add app/lib/views/home/decision_board/_card_factory.dart app/lib/views/home/decision_board/pages/
  git commit -m "feat(home): add _card_factory + 4 tab pages (home/chats/groups/plans)"
  ```

---

## Wave 2 — Integration (primary agent, not a subagent)

### Task I.1: Rewrite `decision_board_page.dart` as TAB SCAFFOLD

Replace with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'atmosphere.dart';
import 'bottom_bar.dart';
import 'floating_avatar.dart';
import 'pages/chats_page.dart';
import 'pages/groups_page.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'sheets/new_chat_sheet.dart';
import 'sheets/search_sheet.dart';

class DecisionBoardPage extends ConsumerStatefulWidget {
  const DecisionBoardPage({super.key});

  @override
  ConsumerState<DecisionBoardPage> createState() =>
      _DecisionBoardPageState();
}

class _DecisionBoardPageState extends ConsumerState<DecisionBoardPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    final index = _tabController.index;
    final current = ref.read(activeTabIndexProvider);
    if (index != current) {
      ref.read(activeTabIndexProvider.notifier).state = index;
    }
  }

  void _switchToTab(int index) {
    if (!mounted) return;
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientMesh()),
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: const [
                HomePage(),
                ChatsPage(),
                GroupsPage(),
                PlansPage(),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            child: const FloatingAvatar(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomBar(
              onTabSelected: _switchToTab,
              onSearchSubmit: () => openSearchSheet(context),
              onComposeTap: () => openNewChatSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Task I.2: Delete obsolete files

```bash
cd /Users/ramchitturi/hello
rm app/lib/views/home/decision_board/search_compose_bar.dart
rm app/lib/views/home/decision_board/feed_header.dart
```

### Task I.3: Run analyze

```
cd /Users/ramchitturi/hello/app && dart analyze lib/ 2>&1 | grep -E "error|warning"
```

Expected: no errors, no warnings. If either appears, fix inline before continuing.

### Task I.4: Commit

```
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/decision_board_page.dart
git add -A app/lib/views/home/decision_board/search_compose_bar.dart app/lib/views/home/decision_board/feed_header.dart
git commit -m "feat(home): wire tab scaffold — TabController + 4 pages + BottomBar + FloatingAvatar"
```

### Task I.5: Kill + rebuild Flutter

Stop the existing flutter background task, clear port 8765, relaunch `flutter run -d chrome --web-port=8765`, wait for DevTools line, verify no runtime errors.

### Task I.6: Report back

Report when:
- `dart analyze lib/` is clean
- `flutter run` is live, no runtime overflow / layout errors
- Chrome shows 4-tab scaffold with HOME default, bottom bar visible, floating avatar top-left
- Swipe switches tabs
- Tap chip opens popover
- Mic morphs to send on text entry
- `+` opens new_chat_sheet

---

## Rollback

If Wave 2 breaks catastrophically, `git reset --hard 5fa83de` restores the previous iMessage bar state (last stable commit before this plan).
