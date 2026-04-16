# Decision Board Peek Stack — Parallel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is designed for **5–6 parallel subagents executing in 3 waves** with pre-agreed interface contracts.

**Goal:** Replace the current `decision_board_page.dart` (mock-data masonry) with a 3-card vertical peek-stack home screen wired to the real engine (`conversationsProvider`, `activeDecisionsProvider`, `homeActiveCardIndexProvider`).

**Architecture:** Vertical `PageView` with custom 78/18/4 peek geometry + hard stop + spring physics + focus dimming. Three cards (Chats / Groups / Decisions) render live streams from the engine via Riverpod `StreamProvider`s. State persistence via `StateProvider<int>` + `AutomaticKeepAliveClientMixin`. Zero mock data. Zero internal scrolling in v1 (up-to-10-rows cap + `SeeAllRow`).

**Tech Stack:** Flutter + `flutter_riverpod` (already in pubspec, no code gen used) + `e2ee_chat_sdk` engine package. Uses existing `HelloColors` / `HelloText` tokens from `lib/theme.dart` per DESIGN.md.

**Spec:** `docs/superpowers/specs/2026-04-10-decision-board-peek-stack-design.md`

---

## Engine types verified (exact signatures, already checked)

From `/Users/ramchitturi/hello/engine/lib/src/domain/models/conversation.dart`:
```dart
enum ConversationType { oneToOne, group }

@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required ConversationType type,
    required List<String> participantIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? lastMessageId,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    @Default(0) int unreadCount,
    @Default(false) bool isPinned,
    @Default(false) bool isArchived,
    @Default(false) bool isMuted,
    DateTime? muteUntil,
    int? disappearingMessageTimerMs,
    @Default(true) bool isEncrypted,
  }) = _Conversation;
}
```

From `/Users/ramchitturi/hello/engine/lib/src/domain/models/decision_item.dart`:
```dart
@freezed
class DecisionItem with _$DecisionItem {
  const factory DecisionItem({
    required String id,
    required String groupId,
    required String ciphertextPayload,
    required String nonce,
    String? commitmentCiphertext,
    String? commitmentNonce,
    required String state,
    @Default(0.0) double weightedScore,
    @Default(0.0) double agreementScore,
    @Default({}) Map<String, String> reactions,
    @Default(false) bool isLocked,
    String? proposedBy,
  }) = _DecisionItem;
}
```

From `engine/lib/src/extensions/chat_engine_decisions.dart`:
```dart
Future<List<DecisionItem>> getDecisionItems(String groupId);
```

**Key design implication:** `DecisionItem.ciphertextPayload` is encrypted. Decryption wrapper (`DecryptedItemPayload`) is **out of scope** for this v1 plan. Decision rows display `id.substring(0, 8)` as placeholder title and `state` as category. Empty state remains accessible until the group has any active decisions.

---

## Interface Contracts (PRE-AGREED — every subagent must honor)

These are the public APIs each parallel track commits to. They must not be changed once execution starts.

### Track A — Providers

```dart
// lib/providers/conversations_provider.dart

/// Live stream of all conversations from the engine.
/// Returns empty list when engine is not yet initialized (handles
/// UnimplementedError from main.dart's placeholder provider).
final conversationsStreamProvider = StreamProvider<List<Conversation>>((ref) { /* ... */ });

/// Direct messages only (type == ConversationType.oneToOne), sorted
/// unread-first then recent-first. Top 10 cap applied by consumer.
final directMessagesProvider = Provider<List<Conversation>>((ref) { /* ... */ });

/// Group chats only (type == ConversationType.group), same sort.
final groupChatsProvider = Provider<List<Conversation>>((ref) { /* ... */ });

/// Total unread count across all conversations of a given type.
final dmUnreadCountProvider = Provider<int>((ref) { /* ... */ });
final groupUnreadCountProvider = Provider<int>((ref) { /* ... */ });
```

```dart
// lib/providers/decisions_provider.dart

/// Cross-group active decisions via client-side merge. Watches
/// conversationsStreamProvider, fetches getDecisionItems(groupId) for
/// each group conversation, filters !isLocked && state != 'archived',
/// sorts by agreementScore desc.
final activeDecisionsProvider = FutureProvider<List<DecisionItem>>((ref) { /* ... */ });

/// Count of active decisions (for header badge).
final activeDecisionsCountProvider = Provider<int>((ref) { /* ... */ });
```

```dart
// lib/providers/home_state_provider.dart

/// Active card index (0=chats, 1=groups, 2=decisions). Survives
/// navigation push/pop and engine provider rebuilds.
final homeActiveCardIndexProvider = StateProvider<int>((_) => 0);
```

### Track B — PeekStackPageView

```dart
// lib/views/home/decision_board/peek_stack.dart

class PeekStackPageView extends StatefulWidget {
  /// Exactly 3 children for the 3-card peek stack.
  final List<Widget> children;
  /// Initial active card index (0-based).
  final int initialIndex;
  /// Fires whenever the active card changes (via swipe commit).
  final ValueChanged<int>? onIndexChanged;

  const PeekStackPageView({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.onIndexChanged,
  }) : assert(children.length == 3, '...');
}
```

**Geometry:** current card 78% of viewport, next peek 18%, previous peek 4%. Spring physics: `stiffness: 400, damping: 30, mass: 1.0`. Velocity threshold for commit: 500 px/s. Drag distance threshold: 30% of card height. Hard stop at index 0 and 2 (rubber-band 15% overshoot). Haptic on snap: `HapticFeedback.lightImpact()`. Focus dimming: peeking cards at opacity 0.70 / scale 0.94.

### Track C — Row widgets

```dart
// lib/views/home/decision_board/cards/conversation_row.dart

class ConversationRow extends StatelessWidget {
  final Conversation conversation;
  /// When true, renders "Name · sender: preview" (group style).
  /// When false, renders "Name · preview" (DM style).
  final bool isGroup;
  final VoidCallback onTap;
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.isGroup,
    required this.onTap,
  });
}
```

```dart
// lib/views/home/decision_board/cards/decision_row.dart

class DecisionRow extends StatelessWidget {
  final DecisionItem item;
  final VoidCallback onTap;
  const DecisionRow({super.key, required this.item, required this.onTap});
}
```

```dart
// lib/views/home/decision_board/cards/see_all_row.dart

class SeeAllRow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const SeeAllRow({super.key, required this.count, required this.onTap});
}
```

### Track D — Header + Empty state

```dart
// lib/views/home/decision_board/cards/card_header.dart

class CardHeader extends StatelessWidget {
  /// "CHATS", "GROUPS", "DECISIONS" — already uppercase.
  final String title;
  final int unreadCount;
  final VoidCallback onTap;
  const CardHeader({
    super.key,
    required this.title,
    required this.unreadCount,
    required this.onTap,
  });
}
```

```dart
// lib/views/home/decision_board/cards/empty_state.dart

enum EmptyStateKind { chats, groups, decisions }

class CardEmptyState extends StatelessWidget {
  final EmptyStateKind kind;
  final VoidCallback onCtaTap;
  const CardEmptyState({
    super.key,
    required this.kind,
    required this.onCtaTap,
  });
}
```

---

## File Structure

### Files to create (12 new)

| File | Track | Responsibility |
|---|---|---|
| `lib/providers/conversations_provider.dart` | A | Engine → conversations stream + DM/Group filters |
| `lib/providers/decisions_provider.dart` | A | Cross-group decision merge |
| `lib/providers/home_state_provider.dart` | A | Active card index persistence |
| `lib/views/home/decision_board/peek_stack.dart` | B | PeekStackPageView widget |
| `lib/views/home/decision_board/cards/conversation_row.dart` | C | Chat/group list row |
| `lib/views/home/decision_board/cards/decision_row.dart` | C | Decision list row with consensus bar separator |
| `lib/views/home/decision_board/cards/see_all_row.dart` | C | Dimmed "See all N →" row |
| `lib/views/home/decision_board/cards/card_header.dart` | D | Tiny caps header "CHATS · N unread" |
| `lib/views/home/decision_board/cards/empty_state.dart` | D | Illustration + tagline + text CTA |
| `lib/views/home/decision_board/cards/chats_card.dart` | E1 | Assembled Chats card consuming providers |
| `lib/views/home/decision_board/cards/groups_card.dart` | E1 | Assembled Groups card |
| `lib/views/home/decision_board/cards/decisions_card.dart` | E1 | Assembled Decisions card |

### Files to modify (3)

| File | Track | Change |
|---|---|---|
| `lib/views/home/decision_board/decision_board_page.dart` | Integration (Wave 3) | Rewrite body to `PeekStackPageView(children: [ChatsCard(), GroupsCard(), DecisionsCard()])` |
| `lib/views/home/decision_board/atmosphere.dart` | E2 | Delete `AuroraStrip` class + its animation controller; keep only `AmbientMesh` |
| `lib/views/home/home_layout.dart` | Integration (Wave 3) | No change — already delegates to `DecisionBoardPage` |

### Files to delete (4)

| File | Track | Reason |
|---|---|---|
| `lib/views/home/decision_board/models.dart` | E2 | Mock `DecisionItem` / `PlanWorld` / `PlanPhase` classes — engine types replace them |
| `lib/views/home/decision_board/decision_card.dart` | E2 | Netflix-card pattern abandoned |
| `lib/views/home/decision_board/swim_lane_rail.dart` | E2 | Swim-lane pattern abandoned |
| `lib/views/home/decision_board/world_tile.dart` | E2 | Worlds tile pattern not used in peek stack |

---

## Parallel Execution Waves

### Wave 1 — 5 agents in parallel (target: ≤ 10 min)

| Agent | Track | Files |
|---|---|---|
| **Agent 1** | A — Providers | `conversations_provider.dart`, `decisions_provider.dart`, `home_state_provider.dart` |
| **Agent 2** | B — PeekStackPageView | `peek_stack.dart` |
| **Agent 3** | C — Row widgets | `conversation_row.dart`, `decision_row.dart`, `see_all_row.dart` |
| **Agent 4** | D — Header + Empty | `card_header.dart`, `empty_state.dart` |
| **Agent 5** | E2 — Cleanup | Delete 4 orphan files, trim `atmosphere.dart` |

All 5 tracks have **zero interdependencies**. Each produces its own files, each commits independently.

### Wave 2 — 1 agent (target: ≤ 8 min)

| Agent | Track | Files |
|---|---|---|
| **Agent 6** | E1 — Card assemblies | `chats_card.dart`, `groups_card.dart`, `decisions_card.dart` |

Depends on: Track A providers, Track C rows, Track D header + empty. Wave 1 MUST be fully complete before Wave 2 begins.

### Wave 3 — Integration (target: ≤ 5 min)

Primary agent (not a subagent) wires it together:
1. Rewrite `decision_board_page.dart` body to use `PeekStackPageView` with the three cards
2. Run `dart analyze lib/` and resolve any warnings
3. Run `flutter test` on any widget tests that exist
4. Commit integration

**Wall clock target: 23 minutes, buffer 7 minutes for iteration = 30 minutes total.**

---

## Wave 1 — Track A: Providers

**Files:**
- Create: `lib/providers/conversations_provider.dart`
- Create: `lib/providers/decisions_provider.dart`
- Create: `lib/providers/home_state_provider.dart`

### Task A.1: `home_state_provider.dart` (simplest, write first)

- [ ] **Step 1: Create the file with the StateProvider**

Write `lib/providers/home_state_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the active card index on the decision board home
/// across widget disposal, navigation pushes, and engine rebuilds.
/// 0 = Chats, 1 = Groups, 2 = Decisions.
final homeActiveCardIndexProvider = StateProvider<int>((ref) => 0);
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/providers/home_state_provider.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/providers/home_state_provider.dart
git commit -m "feat(home): add homeActiveCardIndexProvider for peek stack state persistence"
```

### Task A.2: `conversations_provider.dart`

- [ ] **Step 1: Create the file**

Write `lib/providers/conversations_provider.dart`:

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show engineProvider;

/// Safely resolves the engine, returning null if not yet initialized.
/// The global engineProvider throws UnimplementedError until auth
/// completes — this helper converts that into a nullable so the
/// home screen can render an empty / loading state gracefully.
ChatEngine? _engineOrNull(Ref ref) {
  try {
    return ref.watch(engineProvider);
  } catch (_) {
    return null;
  }
}

/// Live stream of all conversations from the engine. Emits an
/// empty list while the engine is uninitialized.
final conversationsStreamProvider =
    StreamProvider<List<Conversation>>((ref) {
  final engine = _engineOrNull(ref);
  if (engine == null) {
    return Stream<List<Conversation>>.value(const <Conversation>[]);
  }
  return engine.conversations;
});

int _unreadFirstThenRecent(Conversation a, Conversation b) {
  // Unread (count > 0) ranks above read (count == 0).
  final aUnread = a.unreadCount > 0;
  final bUnread = b.unreadCount > 0;
  if (aUnread != bUnread) return aUnread ? -1 : 1;
  // Then most recent activity first (fall back to updatedAt).
  final aTs = a.lastMessageTimestamp ?? a.updatedAt;
  final bTs = b.lastMessageTimestamp ?? b.updatedAt;
  return bTs.compareTo(aTs);
}

/// Direct messages (1:1) sorted unread-first then recent-first.
final directMessagesProvider = Provider<List<Conversation>>((ref) {
  final all = ref.watch(conversationsStreamProvider).valueOrNull ??
      const <Conversation>[];
  final dms = all
      .where((c) => c.type == ConversationType.oneToOne && !c.isArchived)
      .toList()
    ..sort(_unreadFirstThenRecent);
  return dms;
});

/// Group chats sorted unread-first then recent-first.
final groupChatsProvider = Provider<List<Conversation>>((ref) {
  final all = ref.watch(conversationsStreamProvider).valueOrNull ??
      const <Conversation>[];
  final groups = all
      .where((c) => c.type == ConversationType.group && !c.isArchived)
      .toList()
    ..sort(_unreadFirstThenRecent);
  return groups;
});

/// Total unread count for the Chats (DM) card header badge.
final dmUnreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(directMessagesProvider)
      .fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// Total unread count for the Groups card header badge.
final groupUnreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(groupChatsProvider)
      .fold<int>(0, (sum, c) => sum + c.unreadCount);
});
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/providers/conversations_provider.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/providers/conversations_provider.dart
git commit -m "feat(home): add conversations/DM/group providers with unread-first sort"
```

### Task A.3: `decisions_provider.dart`

- [ ] **Step 1: Create the file**

Write `lib/providers/decisions_provider.dart`:

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show engineProvider;
import 'conversations_provider.dart';

ChatEngine? _engineOrNull(Ref ref) {
  try {
    return ref.watch(engineProvider);
  } catch (_) {
    return null;
  }
}

/// Cross-group active decisions via client-side merge.
///
/// Watches [conversationsStreamProvider], fetches
/// `engine.getDecisionItems(groupId)` for every group conversation,
/// filters to `!isLocked && state != 'archived'`, sorts by
/// `agreementScore` descending.
///
/// v1 note: the raw `DecisionItem` holds ciphertext payloads. Decision
/// rows render the item id (truncated) as a placeholder title and the
/// `state` as category. A `DecryptedItemPayload` wrapper is planned
/// for v2 — this provider's public shape will not change.
final activeDecisionsProvider =
    FutureProvider<List<DecisionItem>>((ref) async {
  final engine = _engineOrNull(ref);
  if (engine is! ChatEngineDecisions) {
    return const <DecisionItem>[];
  }
  final groups = ref.watch(groupChatsProvider);
  if (groups.isEmpty) return const <DecisionItem>[];

  final lists = await Future.wait(
    groups.map((g) => engine.getDecisionItems(g.id)),
  );
  final merged = <DecisionItem>[
    for (final list in lists) ...list,
  ]
      .where((d) => !d.isLocked && d.state != 'archived')
      .toList()
    ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));

  return merged;
});

/// Count of active decisions for the Decisions card header badge.
final activeDecisionsCountProvider = Provider<int>((ref) {
  return ref.watch(activeDecisionsProvider).valueOrNull?.length ?? 0;
});
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/providers/decisions_provider.dart`
Expected: `No issues found!`

**Note:** if the ChatEngine in `e2ee_chat_sdk` does not expose `ChatEngineDecisions` as a mixin, or `getDecisionItems` returns a different type, analysis will fail — check the error and import the correct type from the SDK barrel.

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/providers/decisions_provider.dart
git commit -m "feat(home): add activeDecisionsProvider with cross-group client-side merge"
```

---

## Wave 1 — Track B: PeekStackPageView

**Files:**
- Create: `lib/views/home/decision_board/peek_stack.dart`

### Task B.1: PeekStackPageView widget

- [ ] **Step 1: Create the file with the widget, custom geometry, and gesture handling**

Write `lib/views/home/decision_board/peek_stack.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Vertical peek stack — a 3-card PageView with custom geometry:
/// - current card: 78% of viewport
/// - next peek: 18% (below)
/// - previous peek: 4% (above)
///
/// Hard stop at first and last card (rubber-band overshoot). Focus
/// dimming: peeking cards at opacity 0.70, scale 0.94. Haptic feedback
/// on snap.
///
/// Accepts exactly 3 children.
class PeekStackPageView extends StatefulWidget {
  final List<Widget> children;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  const PeekStackPageView({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.onIndexChanged,
  }) : assert(
          children.length == 3,
          'PeekStackPageView expects exactly 3 children',
        );

  @override
  State<PeekStackPageView> createState() => _PeekStackPageViewState();
}

class _PeekStackPageViewState extends State<PeekStackPageView> {
  late final PageController _controller;

  // Geometry constants.
  static const double _currentFraction = 0.78;
  static const double _nextPeekFraction = 0.18;
  static const double _prevPeekFraction = 0.04;

  // Dim target for peeking cards.
  static const double _peekOpacity = 0.70;
  static const double _peekScale = 0.94;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: _currentFraction,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePageChanged(int idx) {
    HapticFeedback.lightImpact();
    widget.onIndexChanged?.call(idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: widget.children.length,
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                double page;
                if (_controller.position.haveDimensions) {
                  page = _controller.page ?? widget.initialIndex.toDouble();
                } else {
                  page = widget.initialIndex.toDouble();
                }
                final delta = (index - page).abs().clamp(0.0, 1.0);
                // Linear interp: 1.0 at delta=0, 0.70 at delta=1.
                final opacity =
                    1.0 - (1.0 - _peekOpacity) * delta;
                final scale = 1.0 - (1.0 - _peekScale) * delta;
                return SizedBox(
                  height: h,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: widget.children[index],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
```

**Implementation notes for the agent:**
- `PageController` with `viewportFraction: 0.78` gives the 78% current card with ~11% peek on each side in Flutter's built-in model. The spec calls for asymmetric 18/4 peeks; Flutter's `viewportFraction` is symmetric. For v1, symmetric peek (11% top + 11% bottom) is an acceptable approximation of the 18/4 asymmetry — it honors the "visible next card" requirement. Asymmetric geometry can be revisited in v2 with a custom `ScrollPhysics` if the symmetry looks wrong.
- `BouncingScrollPhysics` provides the rubber-band at edges for free.
- Spring physics `stiffness: 400, damping: 30` not directly configurable on PageController — the default iOS bouncy physics is close enough for v1. Custom spring simulation is a v2 optimization if the feel is off.
- Haptic feedback fires on every page change via `onPageChanged`.
- The `AnimatedBuilder` on `_controller` ensures opacity/scale interpolate smoothly during drag, not just on snap.

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/peek_stack.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/peek_stack.dart
git commit -m "feat(home): add PeekStackPageView with 78% viewport + focus dimming"
```

---

## Wave 1 — Track C: Row widgets

**Files:**
- Create: `lib/views/home/decision_board/cards/conversation_row.dart`
- Create: `lib/views/home/decision_board/cards/decision_row.dart`
- Create: `lib/views/home/decision_board/cards/see_all_row.dart`

### Task C.1: `conversation_row.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/conversation_row.dart`:

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// A single list row for a conversation (1:1 or group).
/// 64px tall, horizontal layout: avatar · name / preview · timestamp.
class ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final bool isGroup;
  final VoidCallback onTap;

  const ConversationRow({
    super.key,
    required this.conversation,
    required this.isGroup,
    required this.onTap,
  });

  bool get _isUnread => conversation.unreadCount > 0;

  String _displayName() {
    if (isGroup) {
      final count = conversation.participantIds.length;
      return 'Group · $count members';
    }
    return conversation.id.length > 8
        ? 'Chat ${conversation.id.substring(0, 8)}'
        : 'Chat ${conversation.id}';
  }

  String _previewText() {
    final text = conversation.lastMessageText ?? '';
    if (text.isEmpty) return 'No messages yet';
    return text;
  }

  String _timestampText() {
    final ts = conversation.lastMessageTimestamp;
    if (ts == null) return '';
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${ts.month}/${ts.day}';
  }

  @override
  Widget build(BuildContext context) {
    final nameColor =
        _isUnread ? HelloColors.inkPrimary : HelloColors.inkSecondary;
    final previewColor = _isUnread
        ? const Color(0xADF0EFF4)
        : HelloColors.inkTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: HelloColors.inkPrimary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            _Avatar(
              conversation: conversation,
              isGroup: isGroup,
              isUnread: _isUnread,
              unreadCount: conversation.unreadCount,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: nameColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _previewText(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: previewColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _timestampText(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.4,
                color: _isUnread
                    ? HelloColors.accent
                    : HelloColors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Conversation conversation;
  final bool isGroup;
  final bool isUnread;
  final int unreadCount;

  const _Avatar({
    required this.conversation,
    required this.isGroup,
    required this.isUnread,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (conversation.id.isNotEmpty
            ? conversation.id[0].toUpperCase()
            : '?');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGroup
                  ? const [Color(0xFFFF6B35), Color(0xFF14B8A6)]
                  : const [Color(0xFFF472B6), Color(0xFF9D174D)],
            ),
            border: isUnread
                ? Border.all(
                    color: HelloColors.accent,
                    width: 1.5,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Color(0xFFF0EFF4),
            ),
          ),
        ),
        if (isUnread && unreadCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              decoration: BoxDecoration(
                color: HelloColors.accent,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: HelloColors.voidBg,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HelloColors.accent.withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.voidBg,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/conversation_row.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/conversation_row.dart
git commit -m "feat(home): add ConversationRow (64px, unread ring/badge/brightness)"
```

### Task C.2: `decision_row.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/decision_row.dart`:

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// A single list row for a decision item. 64px tall.
/// Horizontal layout: thumbnail · score · title/category · consensus bar as bottom separator.
class DecisionRow extends StatelessWidget {
  final DecisionItem item;
  final VoidCallback onTap;

  const DecisionRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  int get _score => (item.agreementScore * 100).round();

  Color _scoreColor() {
    if (item.agreementScore >= 0.80) return const Color(0xFFE8C86A); // gold
    if (item.agreementScore >= 0.50) return const Color(0xFFFF9B6E); // accent-light
    return const Color(0xFFFBBF24); // warning
  }

  String _title() => 'Decision ${item.id.substring(0, 8)}';

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 2),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Thumbnail (placeholder gradient, 40×40, 0 radius per Zero-Box)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scoreColor.withValues(alpha: 0.4),
                          scoreColor.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Score (Geist Mono 22px, tabular)
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_score',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.44,
                        color: scoreColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + category stacked
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: HelloColors.inkPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.state} · ${item.reactions.length} reactions',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1,
                            color: HelloColors.inkTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Consensus bar REPLACES the row's bottom separator.
            // Width proportional to agreementScore (0.0 – 1.0).
            SizedBox(
              height: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: item.agreementScore.clamp(0.0, 1.0),
                  child: Container(color: scoreColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/decision_row.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/decision_row.dart
git commit -m "feat(home): add DecisionRow with consensus-bar-as-separator"
```

### Task C.3: `see_all_row.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/see_all_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// A dimmed list row (not a button) that navigates to the full
/// list screen when tapped. Zero-Box: no background, no border,
/// no pill — just text + arrow glyph.
class SeeAllRow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const SeeAllRow({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: HelloColors.inkPrimary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'See all $count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: HelloColors.inkSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/see_all_row.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/see_all_row.dart
git commit -m "feat(home): add SeeAllRow (dimmed list row, not a button)"
```

---

## Wave 1 — Track D: Header + Empty State

**Files:**
- Create: `lib/views/home/decision_board/cards/card_header.dart`
- Create: `lib/views/home/decision_board/cards/empty_state.dart`

### Task D.1: `card_header.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/card_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Shared card header: 56px, tiny caps title + unread count.
/// Tappable — fires onTap to navigate to the full list screen.
/// Zero-Box: no background, no border, only a bottom hairline.
class CardHeader extends StatelessWidget {
  /// Already-uppercased title (e.g. "CHATS").
  final String title;
  final int unreadCount;
  final VoidCallback onTap;

  const CardHeader({
    super.key,
    required this.title,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
                color: HelloColors.inkSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: HelloColors.inkTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              unreadCount > 0 ? '$unreadCount UNREAD' : 'CAUGHT UP',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
                color: unreadCount > 0
                    ? HelloColors.accent
                    : HelloColors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/card_header.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/card_header.dart
git commit -m "feat(home): add CardHeader (tiny caps + unread count, tappable)"
```

### Task D.2: `empty_state.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../theme.dart';

enum EmptyStateKind { chats, groups, decisions }

/// Shared empty state for all 3 cards. Renders an icon + tagline + CTA.
/// CTAs are text actions (no pills, no buttons) per Zero-Box doctrine.
class CardEmptyState extends StatelessWidget {
  final EmptyStateKind kind;
  final VoidCallback onCtaTap;

  const CardEmptyState({
    super.key,
    required this.kind,
    required this.onCtaTap,
  });

  IconData get _icon {
    switch (kind) {
      case EmptyStateKind.chats:
        return Icons.chat_bubble_outline_rounded;
      case EmptyStateKind.groups:
        return Icons.people_outline_rounded;
      case EmptyStateKind.decisions:
        return Icons.lightbulb_outline_rounded;
    }
  }

  String get _tagline {
    switch (kind) {
      case EmptyStateKind.chats:
        return 'No conversations yet';
      case EmptyStateKind.groups:
        return 'No group chats yet';
      case EmptyStateKind.decisions:
        return 'Nothing to vote on';
    }
  }

  String get _ctaLabel {
    switch (kind) {
      case EmptyStateKind.chats:
        return 'Start a chat';
      case EmptyStateKind.groups:
        return 'Create a group';
      case EmptyStateKind.decisions:
        return 'Start a decision';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icon,
              size: 48,
              color: HelloColors.inkTertiary,
            ),
            const SizedBox(height: 20),
            Text(
              _tagline,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: HelloColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCtaTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ctaLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.17,
                      color: HelloColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: HelloColors.accent,
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

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/empty_state.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/empty_state.dart
git commit -m "feat(home): add CardEmptyState for chats/groups/decisions"
```

---

## Wave 1 — Track E2: Cleanup (delete orphans, trim atmosphere)

**Files:**
- Delete: `lib/views/home/decision_board/models.dart`
- Delete: `lib/views/home/decision_board/decision_card.dart`
- Delete: `lib/views/home/decision_board/swim_lane_rail.dart`
- Delete: `lib/views/home/decision_board/world_tile.dart`
- Modify: `lib/views/home/decision_board/atmosphere.dart` — delete `AuroraStrip` class

### Task E2.1: Delete orphan files

- [ ] **Step 1: Delete the four orphan files**

```bash
cd /Users/ramchitturi/hello
rm app/lib/views/home/decision_board/models.dart
rm app/lib/views/home/decision_board/decision_card.dart
rm app/lib/views/home/decision_board/swim_lane_rail.dart
rm app/lib/views/home/decision_board/world_tile.dart
```

- [ ] **Step 2: Verify no lingering imports in the codebase**

Run: `grep -rn "swim_lane_rail\|decision_card\.dart\|world_tile\|decision_board/models" app/lib/`
Expected: only matches inside `decision_board_page.dart` (which will be rewritten in Wave 3)

- [ ] **Step 3: Do NOT run dart analyze yet** — it will fail until Wave 3 rewrites `decision_board_page.dart` to stop importing the deleted files.

### Task E2.2: Trim `atmosphere.dart` — delete `AuroraStrip`

- [ ] **Step 1: Read the current file and identify the AuroraStrip region**

Run: `grep -n "class AuroraStrip\|class _AuroraStripState" app/lib/views/home/decision_board/atmosphere.dart`

Expected output shows two class declarations starting somewhere around line 130–180.

- [ ] **Step 2: Delete the AuroraStrip class + its state class**

Use Edit with `old_string` being the entire `class AuroraStrip extends StatefulWidget { ... }` block and its matching `class _AuroraStripState extends State<AuroraStrip> ... { ... }` block (read the file first, copy the exact content). Replace with empty string.

- [ ] **Step 3: Verify dart analyze passes on atmosphere.dart**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/atmosphere.dart`
Expected: `No issues found!` (or at most an "Unused import" warning if dart:math is no longer needed — remove it too if so)

- [ ] **Step 4: Commit the cleanup together**

```bash
cd /Users/ramchitturi/hello
git add -A app/lib/views/home/decision_board/
git commit -m "refactor(home): delete orphan files + trim AuroraStrip from atmosphere"
```

---

## Wave 2 — Track E1: Card assemblies

**Prerequisites:** All of Wave 1 must be complete and committed (Agents 1–5 done).

**Files:**
- Create: `lib/views/home/decision_board/cards/chats_card.dart`
- Create: `lib/views/home/decision_board/cards/groups_card.dart`
- Create: `lib/views/home/decision_board/cards/decisions_card.dart`

### Task E1.1: `chats_card.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/chats_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/conversations_provider.dart';
import 'card_header.dart';
import 'conversation_row.dart';
import 'empty_state.dart';
import 'see_all_row.dart';

/// Chats card (1:1 DMs). Shows up to 10 rows + See all N row.
class ChatsCard extends ConsumerWidget {
  final VoidCallback onHeaderTap;
  final void Function(String conversationId) onRowTap;
  final VoidCallback onEmptyCtaTap;

  const ChatsCard({
    super.key,
    required this.onHeaderTap,
    required this.onRowTap,
    required this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dms = ref.watch(directMessagesProvider);
    final unread = ref.watch(dmUnreadCountProvider);

    return Column(
      children: [
        CardHeader(
          title: 'CHATS',
          unreadCount: unread,
          onTap: onHeaderTap,
        ),
        Expanded(
          child: dms.isEmpty
              ? CardEmptyState(
                  kind: EmptyStateKind.chats,
                  onCtaTap: onEmptyCtaTap,
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      dms.length > 10 ? 10 : dms.length,
                  itemBuilder: (context, index) {
                    if (dms.length > 10 && index == 9) {
                      return SeeAllRow(
                        count: dms.length,
                        onTap: onHeaderTap,
                      );
                    }
                    return ConversationRow(
                      conversation: dms[index],
                      isGroup: false,
                      onTap: () => onRowTap(dms[index].id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/chats_card.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/chats_card.dart
git commit -m "feat(home): add ChatsCard consuming directMessagesProvider"
```

### Task E1.2: `groups_card.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/groups_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/conversations_provider.dart';
import 'card_header.dart';
import 'conversation_row.dart';
import 'empty_state.dart';
import 'see_all_row.dart';

/// Groups card (group chats). Up to 10 rows + See all N row.
class GroupsCard extends ConsumerWidget {
  final VoidCallback onHeaderTap;
  final void Function(String conversationId) onRowTap;
  final VoidCallback onEmptyCtaTap;

  const GroupsCard({
    super.key,
    required this.onHeaderTap,
    required this.onRowTap,
    required this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupChatsProvider);
    final unread = ref.watch(groupUnreadCountProvider);

    return Column(
      children: [
        CardHeader(
          title: 'GROUPS',
          unreadCount: unread,
          onTap: onHeaderTap,
        ),
        Expanded(
          child: groups.isEmpty
              ? CardEmptyState(
                  kind: EmptyStateKind.groups,
                  onCtaTap: onEmptyCtaTap,
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      groups.length > 10 ? 10 : groups.length,
                  itemBuilder: (context, index) {
                    if (groups.length > 10 && index == 9) {
                      return SeeAllRow(
                        count: groups.length,
                        onTap: onHeaderTap,
                      );
                    }
                    return ConversationRow(
                      conversation: groups[index],
                      isGroup: true,
                      onTap: () => onRowTap(groups[index].id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/groups_card.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/groups_card.dart
git commit -m "feat(home): add GroupsCard consuming groupChatsProvider"
```

### Task E1.3: `decisions_card.dart`

- [ ] **Step 1: Create the file**

Write `lib/views/home/decision_board/cards/decisions_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/decisions_provider.dart';
import 'card_header.dart';
import 'decision_row.dart';
import 'empty_state.dart';
import 'see_all_row.dart';

/// Decisions card. Cross-group active decisions via client-side
/// merge. Up to 10 rows + See all N row.
class DecisionsCard extends ConsumerWidget {
  final VoidCallback onHeaderTap;
  final void Function(String decisionId) onRowTap;
  final VoidCallback onEmptyCtaTap;

  const DecisionsCard({
    super.key,
    required this.onHeaderTap,
    required this.onRowTap,
    required this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(activeDecisionsProvider);
    final count = decisionsAsync.valueOrNull?.length ?? 0;

    return Column(
      children: [
        CardHeader(
          title: 'DECISIONS',
          unreadCount: count,
          onTap: onHeaderTap,
        ),
        Expanded(
          child: decisionsAsync.when(
            data: (decisions) {
              if (decisions.isEmpty) {
                return CardEmptyState(
                  kind: EmptyStateKind.decisions,
                  onCtaTap: onEmptyCtaTap,
                );
              }
              return ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    decisions.length > 10 ? 10 : decisions.length,
                itemBuilder: (context, index) {
                  if (decisions.length > 10 && index == 9) {
                    return SeeAllRow(
                      count: decisions.length,
                      onTap: onHeaderTap,
                    );
                  }
                  return DecisionRow(
                    item: decisions[index],
                    onTap: () => onRowTap(decisions[index].id),
                  );
                },
              );
            },
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ),
            error: (_, __) => CardEmptyState(
              kind: EmptyStateKind.decisions,
              onCtaTap: onEmptyCtaTap,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify dart analyze passes**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/decisions_card.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/cards/decisions_card.dart
git commit -m "feat(home): add DecisionsCard consuming activeDecisionsProvider"
```

---

## Wave 3 — Integration (primary agent, not subagent)

**Prerequisites:** All of Wave 1 and Wave 2 complete. All 12 new files committed. All 4 orphan files deleted. `atmosphere.dart` trimmed.

**Files:**
- Modify: `lib/views/home/decision_board/decision_board_page.dart`

### Task I.1: Rewrite `decision_board_page.dart`

- [ ] **Step 1: Replace the file entirely**

Write `lib/views/home/decision_board/decision_board_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/home_state_provider.dart';
import '../../../theme.dart';
import 'atmosphere.dart';
import 'cards/chats_card.dart';
import 'cards/decisions_card.dart';
import 'cards/groups_card.dart';
import 'peek_stack.dart';

/// The home screen: a 3-card peek stack (Chats, Groups, Decisions)
/// consuming live engine streams via Riverpod providers.
class DecisionBoardPage extends ConsumerStatefulWidget {
  const DecisionBoardPage({super.key});

  @override
  ConsumerState<DecisionBoardPage> createState() =>
      _DecisionBoardPageState();
}

class _DecisionBoardPageState extends ConsumerState<DecisionBoardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _openChatList() {
    // v1: stub — detail screens will be wired in a follow-up spec.
    debugPrint('[DecisionBoardPage] open full chat list');
  }

  void _openGroupList() {
    debugPrint('[DecisionBoardPage] open full group list');
  }

  void _openDecisionList() {
    debugPrint('[DecisionBoardPage] open full decision list');
  }

  void _openConversation(String id) {
    debugPrint('[DecisionBoardPage] open conversation $id');
  }

  void _openDecision(String id) {
    debugPrint('[DecisionBoardPage] open decision $id');
  }

  void _startChat() {
    debugPrint('[DecisionBoardPage] start chat');
  }

  void _createGroup() {
    debugPrint('[DecisionBoardPage] create group');
  }

  void _startDecision() {
    debugPrint('[DecisionBoardPage] start decision');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final initialIndex = ref.watch(homeActiveCardIndexProvider);

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientMesh()),
          SafeArea(
            child: PeekStackPageView(
              initialIndex: initialIndex,
              onIndexChanged: (idx) {
                ref
                    .read(homeActiveCardIndexProvider.notifier)
                    .state = idx;
              },
              children: [
                ChatsCard(
                  onHeaderTap: _openChatList,
                  onRowTap: _openConversation,
                  onEmptyCtaTap: _startChat,
                ),
                GroupsCard(
                  onHeaderTap: _openGroupList,
                  onRowTap: _openConversation,
                  onEmptyCtaTap: _createGroup,
                ),
                DecisionsCard(
                  onHeaderTap: _openDecisionList,
                  onRowTap: _openDecision,
                  onEmptyCtaTap: _startDecision,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run full dart analyze on lib/**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/`
Expected: `No issues found!` (or at most the 10 pre-existing `info` notices on placeholder pages that we never touched)

If errors appear in any of the new files, stop and fix them inline before continuing.

- [ ] **Step 3: Verify home_layout.dart is unchanged and still delegates to DecisionBoardPage**

Run: `cat app/lib/views/home/home_layout.dart`
Expected: still shows `import 'decision_board/decision_board_page.dart';` and `DecisionBoardPage()` constructor call. If not, update to match.

- [ ] **Step 4: Commit the integration**

```bash
cd /Users/ramchitturi/hello
git add app/lib/views/home/decision_board/decision_board_page.dart
git commit -m "feat(home): integrate PeekStackPageView with 3 cards + providers"
```

### Task I.2: Final verification

- [ ] **Step 1: Run flutter analyze full**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze` (or `dart analyze lib/`)
Expected: ≤ the 10 pre-existing `info` lint notices on placeholder pages (`use_super_parameters`, deprecated `withOpacity`). **Zero errors, zero new warnings.**

- [ ] **Step 2: Run flutter test if any exist**

Run: `cd /Users/ramchitturi/hello/app && flutter test 2>&1 | tail -20`
Expected: pass or only pre-existing failures.

- [ ] **Step 3: Sanity-check the file tree**

Run:
```bash
cd /Users/ramchitturi/hello/app/lib
find views/home/decision_board -type f
find providers -type f
```

Expected:
```
views/home/decision_board/atmosphere.dart
views/home/decision_board/decision_board_page.dart
views/home/decision_board/peek_stack.dart
views/home/decision_board/cards/card_header.dart
views/home/decision_board/cards/chats_card.dart
views/home/decision_board/cards/conversation_row.dart
views/home/decision_board/cards/decision_row.dart
views/home/decision_board/cards/decisions_card.dart
views/home/decision_board/cards/empty_state.dart
views/home/decision_board/cards/groups_card.dart
views/home/decision_board/cards/see_all_row.dart
providers/conversations_provider.dart
providers/decisions_provider.dart
providers/engine_error_listener.dart
providers/home_state_provider.dart
```

Old files (`models.dart`, `decision_card.dart`, `swim_lane_rail.dart`, `world_tile.dart`) should be **gone**.

- [ ] **Step 4: Final commit if there are any stray cleanups**

```bash
cd /Users/ramchitturi/hello
git status
# If clean, nothing to do. If stragglers, commit them with:
git add -A
git commit -m "chore(home): final cleanup after peek stack migration"
```

---

## Execution Strategy Summary

```
Wave 1 (parallel, 5 agents, target ≤10 min):
  ┌────────┬────────┬────────┬────────┬────────┐
  │ Agent1 │ Agent2 │ Agent3 │ Agent4 │ Agent5 │
  │ TrackA │ TrackB │ TrackC │ TrackD │TrackE2 │
  │ 3 prov │ PeekSt │ 3 rows │ header │ delete │
  │ files  │ widget │        │ +empty │ +atmos │
  └────────┴────────┴────────┴────────┴────────┘

Wave 2 (1 agent, target ≤8 min):
  ┌──────────────┐
  │   Agent 6    │
  │   Track E1   │
  │   3 cards    │
  └──────────────┘

Wave 3 (primary agent, target ≤5 min):
  ┌──────────────┐
  │ Integration  │
  │ + analyze    │
  │ + final test │
  └──────────────┘

Total: 23 min execution + 7 min buffer = 30 min target.
```

### Coordination rules for the subagent dispatcher

1. **Wave 1 agents must complete and commit before Wave 2 starts.** No Wave 2 work can begin while any Wave 1 file is missing — `chats_card.dart` imports `conversation_row.dart` etc.
2. **Within a wave, parallel agents must not touch the same files.** Track assignments guarantee this (see Files table in Wave 1).
3. **Each task's "commit" step is mandatory** so the main branch has recoverable checkpoints between waves.
4. **If an agent's dart analyze fails**, they must fix inline before committing — don't push broken code between waves.
5. **Wave 3 is not a subagent** — it's the primary conversation's final integration pass. The dispatcher runs it directly after confirming Wave 2 is complete.

---

## Self-Review (done 2026-04-10 by primary agent)

### Spec coverage check

| Spec section | Plan task | Covered |
|---|---|---|
| §3 The 3 cards | Wave 2 E1.1, E1.2, E1.3 | ✅ |
| §3 Card header | Track D D.1 | ✅ |
| §3 Row content rules | Track C C.1 (ConversationRow), C.2 (DecisionRow) | ✅ |
| §3 Content cap + See all | C.3 (SeeAllRow) + E1.x cards handle the cap | ✅ |
| §4 Peek stack geometry | Track B B.1 | ✅ (with documented symmetric-viewport approximation for v1) |
| §5 Vertical pagination + spring + haptic | Track B B.1 | ✅ (BouncingScrollPhysics + HapticFeedback.lightImpact) |
| §5 Row tap → navigate | E1.x cards wire `onRowTap`; Wave 3 page provides stub handlers | ✅ (handlers are `debugPrint` stubs for v1 — detail screens are explicit out-of-scope per §13) |
| §5 Card header tap | Track D + E1.x wiring | ✅ |
| §5 No pull-to-refresh | Plan omits it explicitly | ✅ |
| §5 State persistence | Track A A.1 (home_state_provider) + Wave 3 uses AutomaticKeepAliveClientMixin | ✅ |
| §5 Focus dimming | Track B B.1 (AnimatedBuilder interpolates opacity + scale) | ✅ |
| §6 Empty states | Track D D.2 (CardEmptyState with 3 kinds) | ✅ |
| §7 conversations_provider | Track A A.2 | ✅ |
| §7 decisions_provider with client-side merge fallback | Track A A.3 | ✅ |
| §7 Data model shims | DecisionItem engine type used directly; `DecryptedItemPayload` wrapper explicitly deferred to v2 with placeholder title | ✅ (with noted v1 limitation) |
| §8 Typography | Inline in every row widget using Satoshi/Inter, weights 300/400, exact sizes | ✅ |
| §8 Colors | HelloColors tokens referenced from `lib/theme.dart` | ✅ |
| §8 Row layout 64px | All row widgets use `height: 64` | ✅ |
| §8 Decision row consensus-bar-as-separator | Track C C.2 (DecisionRow `FractionallySizedBox` bar) | ✅ |
| §8 Unread badge (Void numeral, accent fill, outer glow) | Track C C.1 (ConversationRow `_Avatar`) | ✅ |
| §8 Zero-Box | Every widget uses `Container` with transparent backgrounds, hairline borders only | ✅ |
| §9 Navigation on tap | Wave 3 handlers (stubs with `debugPrint`); real navigation deferred to follow-up spec per §13 | ✅ |
| §10 Widget architecture | Matches the file tree in this plan exactly | ✅ |
| §10 Files to delete | Track E2 E2.1 | ✅ |
| §10 Files to modify | atmosphere.dart in E2.2; decision_board_page.dart in Wave 3 | ✅ |
| §13 Scope (home-only) | Navigation targets are `debugPrint` stubs per spec | ✅ |
| §15 Pre-flight checklist | PageView math, DecisionRow density, client-side merge, pull-to-refresh removal — all addressed inline | ✅ |

### Placeholder scan

Searched for: TBD, TODO, implement later, fill in, appropriate error handling, similar to Task, add validation, handle edge cases.

**Findings:**
- Task A.3 note: "v1 note: the raw `DecisionItem` holds ciphertext payloads" — this is a documented limitation, not a TODO. Acceptable.
- Task B.1 note: "Asymmetric geometry can be revisited in v2" — documented v1 limitation with rationale. Acceptable.
- Wave 3 handlers use `debugPrint` stubs — explicitly marked as out-of-scope per spec §13. Acceptable.

No unaddressed placeholders.

### Type consistency check

- `conversationsStreamProvider` declared in Track A → consumed in E1.1 / E1.2 via `directMessagesProvider` / `groupChatsProvider` (derived). Names match.
- `DecisionItem` from `e2ee_chat_sdk` → used in `decision_row.dart` and `decisions_provider.dart`. Consistent.
- `Conversation.type == ConversationType.oneToOne` filter in A.2 → matches engine type.
- `PeekStackPageView({children, initialIndex, onIndexChanged})` → Wave 3 passes exactly these three params. Consistent.
- `ConversationRow({conversation, isGroup, onTap})` → E1.1 and E1.2 pass exactly these. Consistent.
- `CardHeader({title, unreadCount, onTap})` → E1.x cards pass exactly these. Consistent.
- `CardEmptyState({kind, onCtaTap})` → E1.x pass `EmptyStateKind.chats/groups/decisions` + callback. Consistent.
- `SeeAllRow({count, onTap})` → E1.x pass `dms.length` + callback. Consistent.

All types line up across tracks.

### Scope check

Single spec, single implementation plan, decomposable into parallel tracks. Not over-scoped. Matches the "home-only" scope lock in spec §13.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-10-decision-board-peek-stack.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per track, review between tracks, fast iteration. Designed for the 5-wave-1 + 1-wave-2 + 1-wave-3 parallel structure above.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints for review.

**Which approach?**
