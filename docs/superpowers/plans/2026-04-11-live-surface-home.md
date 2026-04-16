# Live Surface Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `app/lib/views/home/` as a time-ordered masonry feed of 10 actionable card types with per-card sheets, a pinned focus hero, and a focus-tinted violet atmosphere — the V10 home screen from `docs/superpowers/specs/2026-04-11-live-surface-home-design.md`.

**Architecture:** `CustomScrollView` with a header sliver + focus-hero sliver + `SliverMasonryGrid.count(crossAxisCount: 2)` that renders cards from a sealed `FeedItem` union. All data flows through `feedProvider`, which merges DMs, groups, decisions, trips, settlements, itinerary, memories, and AI nudges, sorted by time desc with focus pinned at index 0. Every card wraps its content in a shared `CardShell` glass surface and dispatches taps to a per-type full-screen modal sheet.

**Tech stack:** Flutter, Riverpod 3.x (with `legacy.dart` for `StateProvider`), `flutter_staggered_grid_view ^0.7.0` (new dependency), `e2ee_chat_sdk` (existing engine package).

---

## File structure

| Path | Track | Purpose |
|---|---|---|
| `app/lib/models/feed_item.dart` | 1 | Sealed `FeedItem` union — 10 variants |
| `app/lib/models/trip.dart` | 1 | `Trip` POD class |
| `app/lib/models/settlement.dart` | 1 | `Settlement` POD class |
| `app/lib/models/itinerary_event.dart` | 1 | `ItineraryEvent` POD class |
| `app/lib/providers/trips_provider.dart` | 2 | `tripsProvider` |
| `app/lib/providers/settlements_provider.dart` | 2 | `settlementsProvider` |
| `app/lib/providers/itinerary_provider.dart` | 2 | `itineraryProvider` |
| `app/lib/providers/focus_provider.dart` | 2 | `focusTripIdProvider` + `focusTripProvider` |
| `app/lib/providers/feed_provider.dart` | 2 | `feedProvider` — merges everything |
| `app/lib/providers/mock_data.dart` | 3 | Extended with trips, settlements, itinerary, memories, AI nudges, hero meta |
| `app/lib/views/home/decision_board/atmosphere.dart` | 4 | Violet mesh w/ focus-color shift |
| `app/lib/theme.dart` | 5 | Extended tokens (focus color palette) |
| `app/lib/views/home/decision_board/cards/_card_shell.dart` | 5 | Shared `CardShell` glass wrapper |
| `app/lib/views/home/decision_board/cards/dm_card.dart` | 6 | DM card widget |
| `app/lib/views/home/decision_board/cards/group_card.dart` | 6 | Group card widget |
| `app/lib/views/home/decision_board/cards/decision_card_small.dart` | 6 | Decision small (inline vote) |
| `app/lib/views/home/decision_board/cards/decision_card_hero.dart` | 7 | Decision hero (photo bg) |
| `app/lib/views/home/decision_board/cards/trip_card.dart` | 7 | Trip card (photo bg, navigates) |
| `app/lib/views/home/decision_board/cards/focus_hero_card.dart` | 7 | Focus pinned hero |
| `app/lib/views/home/decision_board/cards/settlement_card.dart` | 8 | Settlement card (inline pay) |
| `app/lib/views/home/decision_board/cards/itinerary_card.dart` | 8 | Itinerary event card |
| `app/lib/views/home/decision_board/cards/memory_card.dart` | 8 | Memory card (nostalgic) |
| `app/lib/views/home/decision_board/cards/ai_nudge_card.dart` | 8 | @hello AI nudge card |
| `app/lib/views/home/decision_board/sheets/dm_sheet.dart` | 9 | DM full-screen sheet |
| `app/lib/views/home/decision_board/sheets/group_sheet.dart` | 9 | Group full-screen sheet |
| `app/lib/views/home/decision_board/sheets/decision_sheet.dart` | 9 | Decision full-screen sheet |
| `app/lib/views/home/decision_board/sheets/settlement_sheet.dart` | 9 | Settlement full-screen sheet |
| `app/lib/views/home/decision_board/feed_header.dart` | 10 | LIVE SURFACE + FOCUS header strip |
| `app/lib/views/home/decision_board/masonry_grid.dart` | 10 | Sliver masonry grid wrapper |
| *(deletions)* | 10 | `peek_stack.dart`, `chats_card.dart`, `groups_card.dart`, `decisions_card.dart`, `card_header.dart`, `empty_state.dart`, `conversation_row.dart`, `decision_row.dart`, `see_all_row.dart` |
| `app/lib/views/home/decision_board/decision_board_page.dart` | **Wave 2** | Rewrite — masonry feed host |
| `app/pubspec.yaml` | **Wave 2** | Add `flutter_staggered_grid_view: ^0.7.0` |

---

## Shared interface contracts

Every Wave 1 track references these contracts. They are the agreement between parallel agents.

### Contract A — `feed_item.dart` (sealed union)

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';

import 'itinerary_event.dart';
import 'settlement.dart';
import 'trip.dart';

sealed class FeedItem {
  String get id;
  DateTime get sortKey;
}

final class DmFeedItem extends FeedItem {
  final Conversation conversation;
  DmFeedItem(this.conversation);
  @override
  String get id => 'dm_${conversation.id}';
  @override
  DateTime get sortKey =>
      conversation.lastMessageTimestamp ?? conversation.updatedAt;
}

final class GroupFeedItem extends FeedItem {
  final Conversation conversation;
  final int typingCount;
  GroupFeedItem(this.conversation, {this.typingCount = 0});
  @override
  String get id => 'group_${conversation.id}';
  @override
  DateTime get sortKey =>
      conversation.lastMessageTimestamp ?? conversation.updatedAt;
}

final class DecisionSmallFeedItem extends FeedItem {
  final DecisionItem item;
  final String title;
  final String? eyebrow;
  final DateTime updatedAt;
  DecisionSmallFeedItem(
    this.item, {
    required this.title,
    this.eyebrow,
    required this.updatedAt,
  });
  @override
  String get id => 'decs_${item.id}';
  @override
  DateTime get sortKey => updatedAt;
}

final class DecisionHeroFeedItem extends FeedItem {
  final DecisionItem item;
  final String title;
  final String subtitle;
  final String photoUrl;
  final String? liveTag;
  final int votedCount;
  final int totalCount;
  final DateTime updatedAt;
  DecisionHeroFeedItem(
    this.item, {
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    this.liveTag,
    required this.votedCount,
    required this.totalCount,
    required this.updatedAt,
  });
  @override
  String get id => 'dech_${item.id}';
  @override
  DateTime get sortKey => updatedAt;
}

final class TripFeedItem extends FeedItem {
  final Trip trip;
  TripFeedItem(this.trip);
  @override
  String get id => 'trip_${trip.id}';
  @override
  DateTime get sortKey => trip.updatedAt;
}

final class SettlementFeedItem extends FeedItem {
  final Settlement settlement;
  SettlementFeedItem(this.settlement);
  @override
  String get id => 'settle_${settlement.id}';
  @override
  DateTime get sortKey => settlement.updatedAt;
}

final class ItineraryFeedItem extends FeedItem {
  final ItineraryEvent event;
  ItineraryFeedItem(this.event);
  @override
  String get id => 'itin_${event.id}';
  @override
  DateTime get sortKey => event.updatedAt;
}

final class MemoryFeedItem extends FeedItem {
  final String memoryId;
  final String eyebrow;
  final String title;
  final String body;
  final String? photoUrl;
  final DateTime occurredAt;
  final DateTime updatedAt;
  MemoryFeedItem({
    required this.memoryId,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.photoUrl,
    required this.occurredAt,
    required this.updatedAt,
  });
  @override
  String get id => 'mem_$memoryId';
  @override
  DateTime get sortKey => updatedAt;
}

final class AiNudgeFeedItem extends FeedItem {
  final String nudgeId;
  final String message;
  final String? ctaLabel;
  final DateTime updatedAt;
  AiNudgeFeedItem({
    required this.nudgeId,
    required this.message,
    this.ctaLabel,
    required this.updatedAt,
  });
  @override
  String get id => 'ai_$nudgeId';
  @override
  DateTime get sortKey => updatedAt;
}

final class FocusHeroFeedItem extends FeedItem {
  final Trip trip;
  FocusHeroFeedItem(this.trip);
  @override
  String get id => 'focus_${trip.id}';
  @override
  DateTime get sortKey => DateTime(9999);
}
```

### Contract B — model classes

```dart
// trip.dart
import 'package:flutter/material.dart';

class Trip {
  final String id;
  final String destination;
  final String photoUrl;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> memberIds;
  final int pendingDecisionCount;
  final String phase; // 'planning' | 'active' | 'done'
  final Color accentColor;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    required this.destination,
    required this.photoUrl,
    required this.startDate,
    required this.endDate,
    required this.memberIds,
    required this.pendingDecisionCount,
    required this.phase,
    required this.accentColor,
    required this.updatedAt,
  });
}
```

```dart
// settlement.dart
class Settlement {
  final String id;
  final String counterpartyId;
  final String counterpartyName;
  final double amount; // positive = they owe you, negative = you owe them
  final String currency;
  final String reason;
  final DateTime updatedAt;

  const Settlement({
    required this.id,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.updatedAt,
  });

  bool get isOwedToYou => amount > 0;
}
```

```dart
// itinerary_event.dart
class ItineraryEvent {
  final String id;
  final String title;
  final String location;
  final DateTime startsAt;
  final List<String> memberIds;
  final String? groupId;
  final DateTime updatedAt;

  const ItineraryEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.startsAt,
    required this.memberIds,
    this.groupId,
    required this.updatedAt,
  });
}
```

### Contract C — `CardShell` widget (Track 5)

```dart
// app/lib/views/home/decision_board/cards/_card_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass surface wrapper used by every card in the masonry feed.
/// Backdrop blur + low-alpha gradient fill + 1px hairline rim + 24px radius.
/// No fixed height — the child's column decides.
class CardShell extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const CardShell({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final rimColor =
        (accentColor ?? Colors.white).withValues(alpha: 0.10);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
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
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### Contract D — sheet launcher signatures (Track 9)

Each sheet file exports a top-level `Future<void> open...(...)` function. `decision_board_page.dart` calls these directly.

```dart
Future<void> openDmSheet(BuildContext context, DmFeedItem item);
Future<void> openGroupSheet(BuildContext context, GroupFeedItem item);
Future<void> openDecisionSheet(BuildContext context, FeedItem item); // accepts small or hero
Future<void> openSettlementSheet(BuildContext context, SettlementFeedItem item);
```

### Contract E — provider signatures (Track 2)

```dart
final tripsProvider = Provider<List<Trip>>((ref) { ... });
final settlementsProvider = Provider<List<Settlement>>((ref) { ... });
final itineraryProvider = Provider<List<ItineraryEvent>>((ref) { ... });
final focusTripIdProvider = StateProvider<String?>((ref) => kMockFocusTripId);
final focusTripProvider = Provider<Trip?>((ref) { ... });
final feedProvider = Provider<List<FeedItem>>((ref) { ... });
```

### Contract F — mock data additions (Track 3)

`mock_data.dart` keeps `kUseMockData`, `mockConversations`, `mockDecisions` as-is, and adds:

```dart
const String kMockFocusTripId = 'swiss_jun_2026';
final List<Trip> mockTrips;
final List<Settlement> mockSettlements;
final List<ItineraryEvent> mockItinerary;
final List<MemoryFeedItem> mockMemoryFeedItems;
final List<AiNudgeFeedItem> mockAiNudgeFeedItems;
final Map<String, ({String photoUrl, String title, String subtitle, String? liveTag, int votedCount, int totalCount})> mockDecisionHero;
final Map<String, ({String title, String? eyebrow})> mockDecisionSmall;
```

---

## Wave 1 — Parallel tracks (10 subagents)

Each track writes its own files. No track reads files from another track — they reference the contracts above. Each track runs `dart analyze` on its own files and commits at the end.

All tracks run `cd /Users/ramchitturi/hello/app` before `dart analyze` or `flutter` commands.

---

### Track 1: Domain models

**Files:**
- Create: `app/lib/models/feed_item.dart`
- Create: `app/lib/models/trip.dart`
- Create: `app/lib/models/settlement.dart`
- Create: `app/lib/models/itinerary_event.dart`

- [ ] **Step 1: Create `trip.dart`** — copy the full Contract B Trip class verbatim.
- [ ] **Step 2: Create `settlement.dart`** — copy the full Contract B Settlement class verbatim.
- [ ] **Step 3: Create `itinerary_event.dart`** — copy the full Contract B ItineraryEvent class verbatim.
- [ ] **Step 4: Create `feed_item.dart`** — copy the full Contract A sealed union verbatim.
- [ ] **Step 5: Verify dart analyze passes**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/models/
  ```
  Expected: `No issues found!`
- [ ] **Step 6: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/models/
  git commit -m "feat(home): add FeedItem sealed union + Trip/Settlement/ItineraryEvent models"
  ```

---

### Track 2: New providers

**Files:**
- Create: `app/lib/providers/trips_provider.dart`
- Create: `app/lib/providers/settlements_provider.dart`
- Create: `app/lib/providers/itinerary_provider.dart`
- Create: `app/lib/providers/focus_provider.dart`
- Create: `app/lib/providers/feed_provider.dart`

- [ ] **Step 1: Create `trips_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip.dart';
import 'mock_data.dart';

/// Source of truth for trips. Mock-backed when [kUseMockData] is true.
final tripsProvider = Provider<List<Trip>>((ref) {
  if (kUseMockData) return mockTrips;
  return const <Trip>[];
});
```

- [ ] **Step 2: Create `settlements_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settlement.dart';
import 'mock_data.dart';

final settlementsProvider = Provider<List<Settlement>>((ref) {
  if (kUseMockData) return mockSettlements;
  return const <Settlement>[];
});
```

- [ ] **Step 3: Create `itinerary_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/itinerary_event.dart';
import 'mock_data.dart';

final itineraryProvider = Provider<List<ItineraryEvent>>((ref) {
  if (kUseMockData) return mockItinerary;
  return const <ItineraryEvent>[];
});
```

- [ ] **Step 4: Create `focus_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/trip.dart';
import 'mock_data.dart';
import 'trips_provider.dart';

/// The id of the currently-pinned focus trip. Nullable so "no focus"
/// is a valid state. Defaults to [kMockFocusTripId] on first boot.
final focusTripIdProvider =
    StateProvider<String?>((ref) => kMockFocusTripId);

/// Resolves the focus trip id to the actual [Trip] object, or null
/// if no focus is set / the id doesn't match.
final focusTripProvider = Provider<Trip?>((ref) {
  final id = ref.watch(focusTripIdProvider);
  if (id == null) return null;
  final trips = ref.watch(tripsProvider);
  for (final t in trips) {
    if (t.id == id) return t;
  }
  return null;
});
```

- [ ] **Step 5: Create `feed_provider.dart`**

```dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'conversations_provider.dart';
import 'decisions_provider.dart';
import 'focus_provider.dart';
import 'itinerary_provider.dart';
import 'mock_data.dart';
import 'settlements_provider.dart';
import 'trips_provider.dart';

/// Unified time-ordered feed. Merges DMs, groups, decisions (as
/// small or hero per [mockDecisionHero]), trips, settlements,
/// itinerary, memories, and AI nudges. The focus trip (if any)
/// is pinned at index 0 as a [FocusHeroFeedItem].
final feedProvider = Provider<List<FeedItem>>((ref) {
  final dms = ref.watch(directMessagesProvider);
  final groups = ref.watch(groupChatsProvider);
  final decisionsAsync = ref.watch(activeDecisionsProvider);
  final trips = ref.watch(tripsProvider);
  final settlements = ref.watch(settlementsProvider);
  final itinerary = ref.watch(itineraryProvider);
  final focus = ref.watch(focusTripProvider);

  final decisions = decisionsAsync.value ?? const <DecisionItem>[];

  final items = <FeedItem>[
    if (focus != null) FocusHeroFeedItem(focus),
    for (final c in dms) DmFeedItem(c),
    for (final c in groups) GroupFeedItem(c),
    ...decisions.map<FeedItem>((d) {
      final hero = mockDecisionHero[d.id];
      if (hero != null) {
        return DecisionHeroFeedItem(
          d,
          title: hero.title,
          subtitle: hero.subtitle,
          photoUrl: hero.photoUrl,
          liveTag: hero.liveTag,
          votedCount: hero.votedCount,
          totalCount: hero.totalCount,
          updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        );
      }
      final small = mockDecisionSmall[d.id];
      return DecisionSmallFeedItem(
        d,
        title: small?.title ?? 'Decision ${d.id.substring(0, 8)}',
        eyebrow: small?.eyebrow,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
    }),
    for (final t in trips)
      if (focus == null || t.id != focus.id) TripFeedItem(t),
    for (final s in settlements) SettlementFeedItem(s),
    for (final e in itinerary) ItineraryFeedItem(e),
    ...mockMemoryFeedItems,
    ...mockAiNudgeFeedItems,
  ];

  items.sort((a, b) {
    if (a is FocusHeroFeedItem) return -1;
    if (b is FocusHeroFeedItem) return 1;
    return b.sortKey.compareTo(a.sortKey);
  });

  return items;
});
```

- [ ] **Step 6: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/providers/trips_provider.dart lib/providers/settlements_provider.dart lib/providers/itinerary_provider.dart lib/providers/focus_provider.dart lib/providers/feed_provider.dart
  ```
  Expected: `No issues found!`
- [ ] **Step 7: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/providers/trips_provider.dart app/lib/providers/settlements_provider.dart app/lib/providers/itinerary_provider.dart app/lib/providers/focus_provider.dart app/lib/providers/feed_provider.dart
  git commit -m "feat(home): add trips/settlements/itinerary/focus/feed providers"
  ```

---

### Track 3: Mock data expansion

**Files:**
- Modify: `app/lib/providers/mock_data.dart`

- [ ] **Step 1: Rewrite `mock_data.dart` entirely with the following content:**

```dart
// Mock data for the decision board home screen.
//
// Flip [kUseMockData] to `false` to restore the real engine-backed
// providers. Expanded with trips, settlements, itinerary events,
// memories, AI nudges, and per-decision hero/small metadata for the
// live-surface V10 feed.

import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/itinerary_event.dart';
import '../models/settlement.dart';
import '../models/trip.dart';

const bool kUseMockData = true;
const String kMockFocusTripId = 'swiss_jun_2026';

DateTime _ago(Duration d) => DateTime.now().subtract(d);
DateTime _ahead(Duration d) => DateTime.now().add(d);

// ─── Conversations ─────────────────────────────────────────────────

final List<Conversation> mockConversations = <Conversation>[
  // DMs (5)
  Conversation(
    id: 'sarah',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'sarah'],
    createdAt: _ago(const Duration(days: 120)),
    updatedAt: _ago(const Duration(minutes: 4)),
    lastMessageText: 'Reached? Swiss looks insane.',
    lastMessageTimestamp: _ago(const Duration(minutes: 4)),
    unreadCount: 3,
  ),
  Conversation(
    id: 'alex',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'alex'],
    createdAt: _ago(const Duration(days: 60)),
    updatedAt: _ago(const Duration(minutes: 42)),
    lastMessageText: 'just dropped you the link — lmk what you think',
    lastMessageTimestamp: _ago(const Duration(minutes: 42)),
    unreadCount: 1,
  ),
  Conversation(
    id: 'maya',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'maya'],
    createdAt: _ago(const Duration(days: 14)),
    updatedAt: _ago(const Duration(hours: 3)),
    lastMessageText: 'lol yes!! that sounds amazing',
    lastMessageTimestamp: _ago(const Duration(hours: 3)),
  ),
  Conversation(
    id: 'priya',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'priya'],
    createdAt: _ago(const Duration(days: 200)),
    updatedAt: _ago(const Duration(days: 1)),
    lastMessageText: 'thanks for the rec',
    lastMessageTimestamp: _ago(const Duration(days: 1)),
  ),
  Conversation(
    id: 'jordan',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'jordan'],
    createdAt: _ago(const Duration(days: 500)),
    updatedAt: _ago(const Duration(days: 3)),
    lastMessageText: 'call me when you can',
    lastMessageTimestamp: _ago(const Duration(days: 3)),
  ),

  // Groups (4)
  Conversation(
    id: 'bali_trip',
    type: ConversationType.group,
    participantIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    createdAt: _ago(const Duration(days: 21)),
    updatedAt: _ago(const Duration(minutes: 18)),
    lastMessageText: 'just booked the villa!!',
    lastMessageTimestamp: _ago(const Duration(minutes: 18)),
    unreadCount: 8,
  ),
  Conversation(
    id: 'family',
    type: ConversationType.group,
    participantIds: const ['me', 'mom', 'dad', 'sis'],
    createdAt: _ago(const Duration(days: 900)),
    updatedAt: _ago(const Duration(hours: 2)),
    lastMessageText: 'dinner sunday?',
    lastMessageTimestamp: _ago(const Duration(hours: 2)),
    unreadCount: 2,
  ),
  Conversation(
    id: 'goa_group',
    type: ConversationType.group,
    participantIds: const ['me', 'mike', 'chris', 'sara', 'dan', 'nat'],
    createdAt: _ago(const Duration(days: 45)),
    updatedAt: _ago(const Duration(minutes: 25)),
    lastMessageText: 'Location dropped. Hotel links everywhere.',
    lastMessageTimestamp: _ago(const Duration(minutes: 25)),
    unreadCount: 12,
  ),
  Conversation(
    id: 'book_club',
    type: ConversationType.group,
    participantIds: const ['me', 'zoe', 'lin', 'kai', 'omar'],
    createdAt: _ago(const Duration(days: 180)),
    updatedAt: _ago(const Duration(days: 1)),
    lastMessageText: 'chapter 7 discussion tonight @ 8',
    lastMessageTimestamp: _ago(const Duration(days: 1)),
  ),
];

// ─── Decisions ─────────────────────────────────────────────────────

final List<DecisionItem> mockDecisions = <DecisionItem>[
  DecisionItem(
    id: 'flight_mar22_united_827',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'ranked',
    agreementScore: 0.82,
    reactions: const {
      'sarah': 'love_it',
      'alex': 'love_it',
      'maya': 'works_for_me',
      'priya': 'works_for_me',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'villa_ubud_seaview_3br',
    groupId: 'bali_trip',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'ranked',
    agreementScore: 0.76,
    reactions: const {
      'sarah': 'love_it',
      'alex': 'works_for_me',
      'maya': 'love_it',
      'me': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'sunday_dinner_italian_place',
    groupId: 'family',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.67,
    reactions: const {
      'mom': 'works_for_me',
      'dad': 'works_for_me',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'book_chapter7_discussion',
    groupId: 'book_club',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.55,
    reactions: const {
      'zoe': 'works_for_me',
      'lin': 'works_for_me',
      'me': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'goa_hotel_zostel_vs_taj',
    groupId: 'goa_group',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.48,
    reactions: const {
      'mike': 'works_for_me',
      'chris': 'not_for_me',
      'me': 'works_for_me',
    },
  ),
];

final Map<
    String,
    ({
      String photoUrl,
      String title,
      String subtitle,
      String? liveTag,
      int votedCount,
      int totalCount
    })> mockDecisionHero = {
  'flight_mar22_united_827': (
    photoUrl:
        'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=800',
    title: 'Zurich flight · United 827',
    subtitle: 'Direct ORD → ZRH · Jun 12',
    liveTag: 'LIVE EVENT',
    votedCount: 5,
    totalCount: 5,
  ),
  'villa_ubud_seaview_3br': (
    photoUrl:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
    title: 'Villa Ubud · 3BR seaview',
    subtitle: '\$340/night · 8 nights',
    liveTag: null,
    votedCount: 4,
    totalCount: 5,
  ),
  'goa_hotel_zostel_vs_taj': (
    photoUrl:
        'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=800',
    title: 'Goa hotel · Zostel or Taj?',
    subtitle: '3 still deciding · live',
    liveTag: 'LIVE EVENT',
    votedCount: 3,
    totalCount: 6,
  ),
};

final Map<String, ({String title, String? eyebrow})> mockDecisionSmall = {
  'sunday_dinner_italian_place': (
    title: 'Italian or Thai?',
    eyebrow: 'TONIGHT · NEEDS YOU',
  ),
  'book_chapter7_discussion': (
    title: 'Which book next?',
    eyebrow: 'BOOK CLUB',
  ),
};

// ─── Trips ─────────────────────────────────────────────────────────

final List<Trip> mockTrips = <Trip>[
  Trip(
    id: 'swiss_jun_2026',
    destination: 'Swiss Alps',
    photoUrl:
        'https://images.unsplash.com/photo-1527004013197-933c4bb611b3?w=1200',
    startDate: DateTime(2026, 6, 12),
    endDate: DateTime(2026, 6, 20),
    memberIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    pendingDecisionCount: 3,
    phase: 'planning',
    accentColor: const Color(0xFF4A90E2), // alpine blue
    updatedAt: _ago(const Duration(hours: 2)),
  ),
  Trip(
    id: 'goa_sep_2026',
    destination: 'Goa',
    photoUrl:
        'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=1200',
    startDate: DateTime(2026, 9, 3),
    endDate: DateTime(2026, 9, 10),
    memberIds: const ['me', 'mike', 'chris', 'sara', 'dan', 'nat'],
    pendingDecisionCount: 5,
    phase: 'planning',
    accentColor: const Color(0xFF14B8A6), // ocean teal
    updatedAt: _ago(const Duration(days: 1)),
  ),
  Trip(
    id: 'bali_past_2026',
    destination: 'Bali',
    photoUrl:
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200',
    startDate: DateTime(2026, 3, 15),
    endDate: DateTime(2026, 3, 22),
    memberIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    pendingDecisionCount: 0,
    phase: 'done',
    accentColor: const Color(0xFFFF9B6E),
    updatedAt: _ago(const Duration(days: 19)),
  ),
];

// ─── Settlements ───────────────────────────────────────────────────

final List<Settlement> mockSettlements = <Settlement>[
  Settlement(
    id: 'settle_1',
    counterpartyId: 'sarah',
    counterpartyName: 'Sarah',
    amount: -42.50,
    currency: 'USD',
    reason: 'Alila villa deposit',
    updatedAt: _ago(const Duration(hours: 6)),
  ),
  Settlement(
    id: 'settle_2',
    counterpartyId: 'maya',
    counterpartyName: 'Maya',
    amount: 18.00,
    currency: 'USD',
    reason: 'Venice dinner split',
    updatedAt: _ago(const Duration(days: 2)),
  ),
];

// ─── Itinerary ─────────────────────────────────────────────────────

final List<ItineraryEvent> mockItinerary = <ItineraryEvent>[
  ItineraryEvent(
    id: 'itin_1',
    title: 'Dinner at Alila',
    location: 'Ubud, Bali',
    startsAt: _ahead(const Duration(hours: 7)),
    memberIds: const ['me', 'sarah', 'alex'],
    groupId: 'bali_trip',
    updatedAt: _ago(const Duration(minutes: 30)),
  ),
  ItineraryEvent(
    id: 'itin_2',
    title: 'Flight ZRH → ORD',
    location: 'Zurich Airport',
    startsAt: DateTime(2026, 6, 20, 14, 30),
    memberIds: const ['me', 'sarah'],
    groupId: 'swiss_jun_2026',
    updatedAt: _ago(const Duration(days: 3)),
  ),
];

// ─── Memories ──────────────────────────────────────────────────────

final List<MemoryFeedItem> mockMemoryFeedItems = <MemoryFeedItem>[
  MemoryFeedItem(
    memoryId: 'bali_alila',
    eyebrow: 'A YEAR AGO TODAY',
    title: 'Alila Ubud',
    body: 'The Bali crew chose this villa. Worth a revisit for Goa?',
    photoUrl:
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
    occurredAt: _ago(const Duration(days: 365)),
    updatedAt: _ago(const Duration(hours: 18)),
  ),
];

// ─── AI nudges ─────────────────────────────────────────────────────

final List<AiNudgeFeedItem> mockAiNudgeFeedItems = <AiNudgeFeedItem>[
  AiNudgeFeedItem(
    nudgeId: 'swiss_hotel_nudge',
    message:
        'Swiss trip in 62 days and the hotel vote is still open. Want me to summarize the top three options?',
    ctaLabel: 'Summarize',
    updatedAt: _ago(const Duration(hours: 1)),
  ),
];
```

- [ ] **Step 2: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/providers/mock_data.dart
  ```
  Expected: `No issues found!` — the imports from `../models/` and `package:flutter/material.dart` are needed.
- [ ] **Step 3: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/providers/mock_data.dart
  git commit -m "feat(home): expand mock data with trips, settlements, itinerary, memories, AI nudges"
  ```

---

### Track 4: Atmosphere with focus-color shift

**Files:**
- Modify: `app/lib/views/home/decision_board/atmosphere.dart`

- [ ] **Step 1: Rewrite `atmosphere.dart` entirely with the following content:**

```dart
// Home atmosphere — ambient mesh that shifts with the current focus.
//
// The primary blob color is driven by [focusTripProvider]. Swiss →
// alpine blue, Goa → ocean teal, Bali → sunset amber, Tokyo → deep
// rose, no focus → default deep violet.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';

const Color _defaultPrimary = Color(0xFF7C3AED); // deep violet
const Color _teal = Color(0xFF14B8A6);
const Color _rose = Color(0xFFD4536B);
const Color _gold = Color(0xFFC8A84E);

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
    final primary = focus?.accentColor ?? _defaultPrimary;

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
              // Base wash — subtle violet undercoat
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.5,
                    colors: [
                      Color(0xFF1A0F2E),
                      Color(0xFF0A0814),
                      Color(0xFF050507),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // Focus-tinted blob — top left
              Positioned(
                left: -60 + dx1,
                top: -80 + dy1,
                width: 560,
                height: 460,
                child: _BlurBlob(color: primary, opacity: 0.22),
              ),
              // Teal accent — right mid
              Positioned(
                right: -80 + dx2,
                top: 200 + dy2,
                width: 500,
                height: 460,
                child: const _BlurBlob(color: _teal, opacity: 0.10),
              ),
              // Rose accent — bottom left
              Positioned(
                left: -100 - dx1,
                bottom: -60 - dy1,
                width: 520,
                height: 420,
                child: const _BlurBlob(color: _rose, opacity: 0.08),
              ),
              // Gold accent — center bottom
              Positioned(
                left: 40,
                right: 40,
                bottom: -140 + dy2.abs(),
                height: 380,
                child: const _BlurBlob(color: _gold, opacity: 0.06),
              ),
              // Grain overlay
              const _GrainLayer(),
            ],
          ),
        );
      },
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Color color;
  final double opacity;
  const _BlurBlob({required this.color, required this.opacity});

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

class _GrainLayer extends StatelessWidget {
  const _GrainLayer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GrainPainter(),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();
    final count = (size.width * size.height / 420).round();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = 0.015 + rng.nextDouble() * 0.02;
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 2: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/atmosphere.dart
  ```
  Expected: `No issues found!`
- [ ] **Step 3: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/views/home/decision_board/atmosphere.dart
  git commit -m "feat(home): atmosphere shifts primary glow to focus trip accent"
  ```

---

### Track 5: Theme tokens + CardShell

**Files:**
- Modify: `app/lib/theme.dart`
- Create: `app/lib/views/home/decision_board/cards/_card_shell.dart`

- [ ] **Step 1: Extend `theme.dart` — locate the `HelloColors` class and ADD these fields right after `recessed`:**

Find the block:
```dart
  static const Color voidBg = Color(0xFF050507);
  static const Color surfaceDeep = Color(0xFF0A0A0E);
  static const Color recessed = Color(0xFF17171C); // flat avatar / chip bg
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)
```

Replace with:
```dart
  static const Color voidBg = Color(0xFF050507);
  static const Color surfaceDeep = Color(0xFF0A0A0E);
  static const Color recessed = Color(0xFF17171C); // flat avatar / chip bg
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)
  static const Color focusViolet = Color(0xFF7C3AED); // default focus tint
  static const Color focusAlpine = Color(0xFF4A90E2); // Swiss
  static const Color focusOcean = Color(0xFF14B8A6); // Goa
  static const Color focusSunset = Color(0xFFFF9B6E); // Bali
  static const Color liveGreen = Color(0xFF10B981); // LIVE EVENT tag
```

- [ ] **Step 2: Create `app/lib/views/home/decision_board/cards/_card_shell.dart` with the Contract C code verbatim.**

- [ ] **Step 3: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/theme.dart lib/views/home/decision_board/cards/_card_shell.dart
  ```
  Expected: `No issues found!`
- [ ] **Step 4: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/theme.dart app/lib/views/home/decision_board/cards/_card_shell.dart
  git commit -m "feat(home): add focus color tokens + shared CardShell glass surface"
  ```

---

### Track 6: Cards batch A (DM, Group, DecisionSmall)

**Files:**
- Create: `app/lib/views/home/decision_board/cards/dm_card.dart`
- Create: `app/lib/views/home/decision_board/cards/group_card.dart`
- Create: `app/lib/views/home/decision_board/cards/decision_card_small.dart`

- [ ] **Step 1: Create `dm_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col DM card. Flat recessed avatar + name + eyebrow + 2-line
/// preview + unread dot. Tap opens [openDmSheet].
class DmCard extends StatelessWidget {
  final DmFeedItem item;
  final VoidCallback onTap;

  const DmCard({super.key, required this.item, required this.onTap});

  String _displayName() {
    final id = item.conversation.id;
    if (id.isEmpty) return 'Unknown';
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  String _timestamp() {
    final ts = item.conversation.lastMessageTimestamp;
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = item.conversation.unreadCount > 0;
    final preview = item.conversation.lastMessageText ?? '';
    final initial = _displayName()[0].toUpperCase();

    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Avatar(initial: initial),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName(),
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
                    Row(
                      children: [
                        const Text(
                          'DIRECT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timestamp(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.4,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: HelloColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview.isEmpty ? 'No messages yet' : preview,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w300,
              height: 1.35,
              color: HelloColors.inkSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  const _Avatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: HelloColors.recessed,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HelloColors.inkSecondary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `group_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col group card. Flat recessed avatar + group name + live eyebrow
/// + activity blurb + unread dot. Tap opens [openGroupSheet].
class GroupCard extends StatelessWidget {
  final GroupFeedItem item;
  final VoidCallback onTap;

  const GroupCard({super.key, required this.item, required this.onTap});

  String _displayName() {
    return item.conversation.id
        .split('_')
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _eyebrow() {
    if (item.typingCount > 0) return '${item.typingCount} TYPING';
    if (item.conversation.unreadCount > 0) return 'ACTIVE';
    return 'GROUP';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = item.conversation.unreadCount > 0;
    final preview = item.conversation.lastMessageText ?? '';
    final memberCount = item.conversation.participantIds.length;
    final initial = _displayName().isNotEmpty
        ? _displayName()[0].toUpperCase()
        : 'G';

    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: HelloColors.recessed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName(),
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
                      _eyebrow(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                        color: isUnread
                            ? HelloColors.accent
                            : HelloColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: HelloColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview.isEmpty ? 'No activity yet' : preview,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w300,
              height: 1.35,
              color: HelloColors.inkSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            '$memberCount members',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create `decision_card_small.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col decision card with inline vote buttons. React without
/// opening, or tap to open the full decision sheet.
class DecisionCardSmall extends StatefulWidget {
  final DecisionSmallFeedItem item;
  final VoidCallback onTap;

  const DecisionCardSmall({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<DecisionCardSmall> createState() => _DecisionCardSmallState();
}

class _DecisionCardSmallState extends State<DecisionCardSmall> {
  String? _myVote;

  @override
  Widget build(BuildContext context) {
    final score = (widget.item.item.agreementScore * 100).round();

    return CardShell(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item.eyebrow != null)
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
          const SizedBox(height: 8),
          Text(
            widget.item.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: HelloColors.inkPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // Inline vote row
          Row(
            children: [
              _VoteButton(
                label: '♥',
                active: _myVote == 'love_it',
                onTap: () => setState(() => _myVote = 'love_it'),
              ),
              const SizedBox(width: 8),
              _VoteButton(
                label: '✓',
                active: _myVote == 'works_for_me',
                onTap: () => setState(() => _myVote = 'works_for_me'),
              ),
              const SizedBox(width: 8),
              _VoteButton(
                label: '✗',
                active: _myVote == 'not_for_me',
                onTap: () => setState(() => _myVote = 'not_for_me'),
              ),
              const Spacer(),
              Text(
                '$score%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
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
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _VoteButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: active
              ? HelloColors.accent.withValues(alpha: 0.18)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(6),
          border: active
              ? Border.all(color: HelloColors.accent, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: active
                ? HelloColors.accent
                : HelloColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/dm_card.dart lib/views/home/decision_board/cards/group_card.dart lib/views/home/decision_board/cards/decision_card_small.dart
  ```
  Expected: `No issues found!`
- [ ] **Step 5: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/views/home/decision_board/cards/dm_card.dart app/lib/views/home/decision_board/cards/group_card.dart app/lib/views/home/decision_board/cards/decision_card_small.dart
  git commit -m "feat(home): add DmCard, GroupCard, DecisionCardSmall"
  ```

---

### Track 7: Cards batch B (DecisionHero, Trip, FocusHero)

**Files:**
- Create: `app/lib/views/home/decision_board/cards/decision_card_hero.dart`
- Create: `app/lib/views/home/decision_board/cards/trip_card.dart`
- Create: `app/lib/views/home/decision_board/cards/focus_hero_card.dart`

All three use photo backgrounds loaded via `Image.network` wrapped in a stack with a bottom gradient scrim.

- [ ] **Step 1: Create `decision_card_hero.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// Tall 1-col hero decision card with photo background, scrim,
/// live tag, and vote progress.
class DecisionCardHero extends StatelessWidget {
  final DecisionHeroFeedItem item;
  final VoidCallback onTap;

  const DecisionCardHero({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CardShell(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo background
            Image.network(
              item.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: HelloColors.surfaceDeep,
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(color: HelloColors.surfaceDeep);
              },
            ),
            // Darken overlay
            const ColoredBox(color: Color(0x55000000)),
            // Bottom gradient scrim
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
            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.liveTag != null)
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: HelloColors.liveGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.liveTag!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.liveGreen,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 1.15,
                      color: Color(0xFFF0EFF4),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFFF0EFF4).withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${item.votedCount} of ${item.totalCount} voted',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                      color: Color(0xFFF0EFF4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: item.totalCount == 0
                          ? 0
                          : item.votedCount / item.totalCount,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        HelloColors.accent,
                      ),
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

- [ ] **Step 2: Create `trip_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// Tall 1-col trip card with destination photo, dates, member stack,
/// pending-decision count. Tap navigates to the trip view (placeholder
/// route in v1).
class TripCard extends StatelessWidget {
  final TripFeedItem item;
  final VoidCallback onTap;

  const TripCard({super.key, required this.item, required this.onTap});

  String _dateRange() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final s = item.trip.startDate;
    final e = item.trip.endDate;
    return '${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}';
  }

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    return CardShell(
      onTap: onTap,
      accentColor: trip.accentColor,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              trip.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: trip.accentColor.withValues(alpha: 0.3),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: trip.accentColor.withValues(alpha: 0.3),
                );
              },
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.30)),
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
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: trip.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    trip.phase.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                      color: trip.accentColor,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.destination,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                      color: Color(0xFFF0EFF4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateRange(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFFF0EFF4).withValues(alpha: 0.80),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${trip.memberIds.length} members',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                          color: Color(0xFFF0EFF4),
                        ),
                      ),
                      const Spacer(),
                      if (trip.pendingDecisionCount > 0)
                        Text(
                          '${trip.pendingDecisionCount} pending',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                            color: HelloColors.accent,
                          ),
                        ),
                    ],
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

- [ ] **Step 3: Create `focus_hero_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// Full-width hero card for the pinned focus trip. Always appears
/// at the top of the feed (outside the masonry grid).
class FocusHeroCard extends StatelessWidget {
  final FocusHeroFeedItem item;
  final VoidCallback onTap;

  const FocusHeroCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _dateRange() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final s = item.trip.startDate;
    final e = item.trip.endDate;
    return '${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}';
  }

  int _daysUntil() {
    final diff = item.trip.startDate.difference(DateTime.now()).inDays;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    final days = _daysUntil();

    return CardShell(
      onTap: onTap,
      accentColor: trip.accentColor,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 340,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              trip.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: trip.accentColor.withValues(alpha: 0.3),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: trip.accentColor.withValues(alpha: 0.3),
                );
              },
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xDD000000)],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 20,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: trip.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'YOUR FOCUS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      color: trip.accentColor,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.destination,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      height: 1.05,
                      letterSpacing: -0.5,
                      color: Color(0xFFF0EFF4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateRange(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFFF0EFF4).withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (days > 0) ...[
                        Text(
                          '$days DAYS',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: Color(0xFFF0EFF4),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        '${trip.memberIds.length} MEMBERS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: const Color(0xFFF0EFF4).withValues(alpha: 0.85),
                        ),
                      ),
                      if (trip.pendingDecisionCount > 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          '${trip.pendingDecisionCount} PENDING',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.accent,
                          ),
                        ),
                      ],
                    ],
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

- [ ] **Step 4: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/decision_card_hero.dart lib/views/home/decision_board/cards/trip_card.dart lib/views/home/decision_board/cards/focus_hero_card.dart
  ```
  Expected: `No issues found!`
- [ ] **Step 5: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/views/home/decision_board/cards/decision_card_hero.dart app/lib/views/home/decision_board/cards/trip_card.dart app/lib/views/home/decision_board/cards/focus_hero_card.dart
  git commit -m "feat(home): add DecisionCardHero, TripCard, FocusHeroCard (photo-backed heroes)"
  ```

---

### Track 8: Cards batch C (Settlement, Itinerary, Memory, AiNudge)

**Files:**
- Create: `app/lib/views/home/decision_board/cards/settlement_card.dart`
- Create: `app/lib/views/home/decision_board/cards/itinerary_card.dart`
- Create: `app/lib/views/home/decision_board/cards/memory_card.dart`
- Create: `app/lib/views/home/decision_board/cards/ai_nudge_card.dart`

- [ ] **Step 1: Create `settlement_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col settlement card. Shows "You owe X" or "X owes you" plus
/// an inline pay button (mock — prints to debug).
class SettlementCard extends StatelessWidget {
  final SettlementFeedItem item;
  final VoidCallback onTap;

  const SettlementCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = item.settlement;
    final abs = s.amount.abs().toStringAsFixed(2);
    final prefix = s.currency == 'USD' ? '\$' : s.currency;
    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.isOwedToYou ? 'OWED TO YOU' : 'YOU OWE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: s.isOwedToYou
                  ? HelloColors.liveGreen
                  : HelloColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                prefix,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                abs,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.isOwedToYou
                ? 'from ${s.counterpartyName}'
                : 'to ${s.counterpartyName}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.reason,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: HelloColors.inkTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (!s.isOwedToYou)
            _PayButton(onTap: () => debugPrint('[mock] pay ${s.id}'))
          else
            _RequestButton(onTap: () => debugPrint('[mock] remind ${s.id}')),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          color: HelloColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
          'PAY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: Color(0xFFF0EFF4),
          ),
        ),
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RequestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          color: HelloColors.recessed,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
          'REMIND',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: HelloColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `itinerary_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col itinerary event card. Shows title + countdown + location.
class ItineraryCard extends StatelessWidget {
  final ItineraryFeedItem item;
  final VoidCallback onTap;

  const ItineraryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _countdown() {
    final diff = item.event.startsAt.difference(DateTime.now());
    if (diff.isNegative) return 'NOW';
    if (diff.inHours < 1) return 'IN ${diff.inMinutes}M';
    if (diff.inHours < 24) return 'IN ${diff.inHours}H';
    return 'IN ${diff.inDays}D';
  }

  @override
  Widget build(BuildContext context) {
    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _countdown(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: HelloColors.liveGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.event.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: HelloColors.inkPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            item.event.location,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: HelloColors.inkSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '${item.event.memberIds.length} attending',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create `memory_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col (medium height) nostalgic memory card with optional photo.
class MemoryCard extends StatelessWidget {
  final MemoryFeedItem item;
  final VoidCallback onTap;

  const MemoryCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CardShell(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.photoUrl != null)
            AspectRatio(
              aspectRatio: 1.6,
              child: Image.network(
                item.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: HelloColors.surfaceDeep,
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const ColoredBox(
                    color: HelloColors.surfaceDeep,
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.eyebrow,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5,
                    color: HelloColors.focusSunset,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: HelloColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                    color: HelloColors.inkSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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

- [ ] **Step 4: Create `ai_nudge_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col AI nudge card. @hello voice eyebrow, message body, CTA.
class AiNudgeCard extends StatelessWidget {
  final AiNudgeFeedItem item;
  final VoidCallback onTap;

  const AiNudgeCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CardShell(
      onTap: onTap,
      accentColor: HelloColors.focusAlpine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: HelloColors.focusAlpine,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '@HELLO',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: HelloColors.focusAlpine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w300,
              height: 1.45,
              color: HelloColors.inkPrimary,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.ctaLabel != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  item.ctaLabel!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.focusAlpine,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: HelloColors.focusAlpine,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/cards/settlement_card.dart lib/views/home/decision_board/cards/itinerary_card.dart lib/views/home/decision_board/cards/memory_card.dart lib/views/home/decision_board/cards/ai_nudge_card.dart
  ```
  Expected: `No issues found!`
- [ ] **Step 6: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/views/home/decision_board/cards/settlement_card.dart app/lib/views/home/decision_board/cards/itinerary_card.dart app/lib/views/home/decision_board/cards/memory_card.dart app/lib/views/home/decision_board/cards/ai_nudge_card.dart
  git commit -m "feat(home): add SettlementCard, ItineraryCard, MemoryCard, AiNudgeCard"
  ```

---

### Track 9: Action sheets (DM, Group, Decision, Settlement)

**Files:**
- Create: `app/lib/views/home/decision_board/sheets/dm_sheet.dart`
- Create: `app/lib/views/home/decision_board/sheets/group_sheet.dart`
- Create: `app/lib/views/home/decision_board/sheets/decision_sheet.dart`
- Create: `app/lib/views/home/decision_board/sheets/settlement_sheet.dart`

All sheets follow this pattern: a top-level `Future<void> open...Sheet(BuildContext, FeedItem)` function that calls `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: ...)`. The builder returns a `_SheetShell` stateless widget with a handle, close X, scrollable content, and optional footer (e.g. reply input).

- [ ] **Step 1: Create `dm_sheet.dart`**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';

Future<void> openDmSheet(BuildContext context, DmFeedItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DmSheet(item: item),
  );
}

class _DmSheet extends StatelessWidget {
  final DmFeedItem item;
  const _DmSheet({required this.item});

  String _displayName() {
    final id = item.conversation.id;
    if (id.isEmpty) return 'Unknown';
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    // Mock thread — 3 messages
    final messages = <_MockMessage>[
      _MockMessage(
        text: item.conversation.lastMessageText ?? 'hey',
        fromMe: false,
      ),
      const _MockMessage(
        text: 'Looks unreal. Which hotel are you leaning toward?',
        fromMe: true,
      ),
      const _MockMessage(
        text: 'Probably Alila. Price is painful though.',
        fromMe: false,
      ),
    ];

    return _SheetShell(
      eyebrow: 'DIRECT MESSAGE',
      title: name,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _MessageBubble(msg: messages[i]),
      ),
      footer: _ReplyInput(hint: 'Reply to $name'),
    );
  }
}

class _MockMessage {
  final String text;
  final bool fromMe;
  const _MockMessage({required this.text, required this.fromMe});
}

class _MessageBubble extends StatelessWidget {
  final _MockMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.fromMe
              ? HelloColors.accent.withValues(alpha: 0.22)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.35,
            color: HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}

class _ReplyInput extends StatelessWidget {
  final String hint;
  const _ReplyInput({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: HelloColors.inkTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: HelloColors.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: Color(0xFFF0EFF4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget body;
  final Widget? footer;
  const _SheetShell({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              color: HelloColors.inkTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                              color: HelloColors.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `group_sheet.dart`**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';

Future<void> openGroupSheet(BuildContext context, GroupFeedItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupSheet(item: item),
  );
}

class _GroupSheet extends StatelessWidget {
  final GroupFeedItem item;
  const _GroupSheet({required this.item});

  String _displayName() {
    return item.conversation.id
        .split('_')
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final memberCount = item.conversation.participantIds.length;
    final unread = item.conversation.unreadCount;

    return _GroupSheetShell(
      eyebrow: 'GROUP CHAT',
      title: name,
      subtitle: '$memberCount members · $unread unread',
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(label: 'UNREAD', value: '$unread'),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'MEMBERS',
                  value: '$memberCount',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              item.conversation.lastMessageText ?? 'No activity yet',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w300,
                height: 1.5,
                color: HelloColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
      footer: _ReplyInput(hint: 'Message $name'),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: HelloColors.recessed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: HelloColors.inkTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyInput extends StatelessWidget {
  final String hint;
  const _ReplyInput({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: HelloColors.inkTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: HelloColors.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: Color(0xFFF0EFF4),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSheetShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? footer;
  const _GroupSheetShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              color: HelloColors.inkTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                              color: HelloColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: HelloColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create `decision_sheet.dart`**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';

Future<void> openDecisionSheet(BuildContext context, FeedItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DecisionSheet(item: item),
  );
}

class _DecisionSheet extends StatefulWidget {
  final FeedItem item;
  const _DecisionSheet({required this.item});

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  String? _vote;

  ({String title, String? subtitle, String? photoUrl, double score})
      _extract() {
    final it = widget.item;
    if (it is DecisionHeroFeedItem) {
      return (
        title: it.title,
        subtitle: it.subtitle,
        photoUrl: it.photoUrl,
        score: it.item.agreementScore,
      );
    }
    if (it is DecisionSmallFeedItem) {
      return (
        title: it.title,
        subtitle: it.eyebrow,
        photoUrl: null,
        score: it.item.agreementScore,
      );
    }
    return (title: 'Decision', subtitle: null, photoUrl: null, score: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final data = _extract();
    final scorePct = (data.score * 100).round();
    final height = MediaQuery.of(context).size.height * 0.92;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'DECISION',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: HelloColors.inkTertiary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (data.photoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            data.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: HelloColors.surfaceDeep,
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const ColoredBox(
                                color: HelloColors.surfaceDeep,
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3,
                        height: 1.1,
                        color: HelloColors.inkPrimary,
                      ),
                    ),
                    if (data.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        data.subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Score
                    Row(
                      children: [
                        Text(
                          '$scorePct%',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 36,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.5,
                            color: HelloColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'consensus',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 28),
                    _BigVoteButton(
                      label: 'Love it',
                      active: _vote == 'love_it',
                      onTap: () => setState(() => _vote = 'love_it'),
                    ),
                    const SizedBox(height: 10),
                    _BigVoteButton(
                      label: 'Works for me',
                      active: _vote == 'works_for_me',
                      onTap: () => setState(() => _vote = 'works_for_me'),
                    ),
                    const SizedBox(height: 10),
                    _BigVoteButton(
                      label: 'Not for me',
                      active: _vote == 'not_for_me',
                      onTap: () => setState(() => _vote = 'not_for_me'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigVoteButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BigVoteButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? HelloColors.accent.withValues(alpha: 0.22)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: HelloColors.accent, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: active ? HelloColors.accent : HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `settlement_sheet.dart`**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';

Future<void> openSettlementSheet(
  BuildContext context,
  SettlementFeedItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettlementSheet(item: item),
  );
}

class _SettlementSheet extends StatelessWidget {
  final SettlementFeedItem item;
  const _SettlementSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = item.settlement;
    final height = MediaQuery.of(context).size.height * 0.82;
    final abs = s.amount.abs().toStringAsFixed(2);
    final prefix = s.currency == 'USD' ? '\$' : s.currency;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.isOwedToYou ? 'OWED TO YOU' : 'YOU OWE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: s.isOwedToYou
                              ? HelloColors.liveGreen
                              : HelloColors.accent,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            prefix,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: HelloColors.inkPrimary
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          abs,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 72,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -2,
                            height: 1,
                            color: HelloColors.inkPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.isOwedToYou
                          ? 'from ${s.counterpartyName}'
                          : 'to ${s.counterpartyName}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.reason,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: HelloColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: s.isOwedToYou
                          ? HelloColors.recessed
                          : HelloColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.isOwedToYou ? 'REMIND' : 'PAY NOW',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2.5,
                        color: s.isOwedToYou
                            ? HelloColors.inkPrimary
                            : const Color(0xFFF0EFF4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/sheets/
  ```
  Expected: `No issues found!`
- [ ] **Step 6: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/views/home/decision_board/sheets/
  git commit -m "feat(home): add DM, group, decision, settlement full-screen sheets"
  ```

---

### Track 10: Feed header + masonry wrapper + orphan cleanup

**Files:**
- Create: `app/lib/views/home/decision_board/feed_header.dart`
- Create: `app/lib/views/home/decision_board/masonry_grid.dart`
- Delete: 9 orphaned files listed below

- [ ] **Step 1: Create `feed_header.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../models/trip.dart';
import '../../../theme.dart';

/// Header strip at the top of the home feed.
/// Left: "LIVE SURFACE" eyebrow + "What matters now" display title.
/// Right: "FOCUS" eyebrow in the focus accent color + focus title.
class FeedHeader extends StatelessWidget {
  final Trip? focus;
  const FeedHeader({super.key, this.focus});

  @override
  Widget build(BuildContext context) {
    final focusColor = focus?.accentColor ?? HelloColors.focusViolet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LIVE SURFACE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                    color: HelloColors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'What matters now',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                    height: 1.1,
                    color: HelloColors.inkPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (focus != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: focusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FOCUS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        color: focusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  focus!.destination,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkPrimary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `masonry_grid.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Thin wrapper around [SliverMasonryGrid.count] with fixed 2-col
/// layout + symmetric spacing. Each item is a tile; heights are
/// driven by the item widgets themselves.
class MasonryFeedGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const MasonryFeedGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
```

- [ ] **Step 3: Delete orphaned files**

```
cd /Users/ramchitturi/hello
rm app/lib/views/home/decision_board/peek_stack.dart
rm app/lib/views/home/decision_board/cards/chats_card.dart
rm app/lib/views/home/decision_board/cards/groups_card.dart
rm app/lib/views/home/decision_board/cards/decisions_card.dart
rm app/lib/views/home/decision_board/cards/card_header.dart
rm app/lib/views/home/decision_board/cards/empty_state.dart
rm app/lib/views/home/decision_board/cards/conversation_row.dart
rm app/lib/views/home/decision_board/cards/decision_row.dart
rm app/lib/views/home/decision_board/cards/see_all_row.dart
```

- [ ] **Step 4: Verify (new files only — decision_board_page is still broken, that's Wave 2)**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/views/home/decision_board/feed_header.dart
  ```
  Expected: `No issues found!`
  
  Note: `masonry_grid.dart` will fail to analyze until `flutter_staggered_grid_view` is added to pubspec in Wave 2 — this is expected. Skip analyzing it on this track.

- [ ] **Step 5: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add -A app/lib/views/home/decision_board/
  git commit -m "feat(home): add feed header + masonry grid wrapper; delete peek-stack orphans"
  ```

---

## Wave 2 — Integration (primary agent, not a subagent)

**Prerequisites:** All of Wave 1 must be complete and committed.

### Task I.1: Add the dependency

- [ ] **Step 1: Edit `app/pubspec.yaml`** — under `dependencies:` add:
  ```yaml
    flutter_staggered_grid_view: ^0.7.0
  ```
- [ ] **Step 2: Run `flutter pub get`**
  ```
  cd /Users/ramchitturi/hello/app && flutter pub get
  ```
  Expected: dependency resolved, no errors.

### Task I.2: Rewrite `decision_board_page.dart`

- [ ] **Step 1: Replace the file entirely with the following:**

```dart
// The V10 live-surface home screen.
//
// A masonry feed of 10 card types sourced from `feedProvider` and
// sorted by time desc with the focus trip pinned at index 0. Every
// card opens a full-screen modal sheet on tap, except TripCard
// (which navigates) and Memory/Itinerary/AiNudge (which show a
// placeholder snackbar in v1).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feed_item.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../theme.dart';
import 'atmosphere.dart';
import 'cards/_card_shell.dart';
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
import 'feed_header.dart';
import 'masonry_grid.dart';
import 'sheets/decision_sheet.dart';
import 'sheets/dm_sheet.dart';
import 'sheets/group_sheet.dart';
import 'sheets/settlement_sheet.dart';

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

  void _stubSnack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: HelloColors.recessed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTripRoute(BuildContext ctx, String tripId) {
    Navigator.of(ctx).push(
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

  Widget _buildCard(BuildContext ctx, FeedItem item) {
    return switch (item) {
      DmFeedItem() => DmCard(
          item: item,
          onTap: () => openDmSheet(ctx, item),
        ),
      GroupFeedItem() => GroupCard(
          item: item,
          onTap: () => openGroupSheet(ctx, item),
        ),
      DecisionSmallFeedItem() => DecisionCardSmall(
          item: item,
          onTap: () => openDecisionSheet(ctx, item),
        ),
      DecisionHeroFeedItem() => DecisionCardHero(
          item: item,
          onTap: () => openDecisionSheet(ctx, item),
        ),
      TripFeedItem() => TripCard(
          item: item,
          onTap: () => _openTripRoute(ctx, item.trip.id),
        ),
      SettlementFeedItem() => SettlementCard(
          item: item,
          onTap: () => openSettlementSheet(ctx, item),
        ),
      ItineraryFeedItem() => ItineraryCard(
          item: item,
          onTap: () =>
              _stubSnack(ctx, 'Itinerary detail — coming in v1.1'),
        ),
      MemoryFeedItem() => MemoryCard(
          item: item,
          onTap: () => _stubSnack(ctx, 'Memory detail — coming in v1.1'),
        ),
      AiNudgeFeedItem() => AiNudgeCard(
          item: item,
          onTap: () => _stubSnack(ctx, '@hello nudge — coming in v1.1'),
        ),
      FocusHeroFeedItem() => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(feedProvider);
    final focus = ref.watch(focusTripProvider);

    // Split the feed: FocusHero renders in its own sliver; everything
    // else flows into the masonry grid.
    final focusItem =
        feed.whereType<FocusHeroFeedItem>().isEmpty
            ? null
            : feed.whereType<FocusHeroFeedItem>().first;
    final rest = feed.where((i) => i is! FocusHeroFeedItem).toList();

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientMesh()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: FeedHeader(focus: focus)),
                if (focusItem != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: FocusHeroCard(
                        item: focusItem,
                        onTap: () =>
                            _openTripRoute(context, focusItem.trip.id),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: MasonryFeedGrid(
                    itemCount: rest.length,
                    itemBuilder: (ctx, i) => _buildCard(ctx, rest[i]),
                  ),
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

- [ ] **Step 2: Run full analyze**
  ```
  cd /Users/ramchitturi/hello/app && dart analyze lib/
  ```
  Expected: 0 errors. At most the 10 pre-existing `info` notices on placeholder pages. **Fix any real errors inline before proceeding.**

- [ ] **Step 3: Commit**
  ```
  cd /Users/ramchitturi/hello
  git add app/lib/views/home/decision_board/decision_board_page.dart app/pubspec.yaml app/pubspec.lock
  git commit -m "feat(home): wire V10 live-surface masonry feed + staggered grid dep"
  ```

### Task I.3: Kill + restart Flutter

- [ ] **Step 1: Stop the current `flutter run` background task.**
- [ ] **Step 2: Relaunch `flutter run -d chrome --web-port=8765` as a background task.**
- [ ] **Step 3: Monitor for build completion (look for "DevTools" line in output).**
- [ ] **Step 4: If the build fails, read the error, fix the referenced file, hot-restart, repeat.**

### Task I.4: Report back

Report when:
- `dart analyze lib/` is clean
- `flutter run` is live on port 8765 with no runtime errors
- The home screen renders the masonry feed with ≥14 cards across 10 types
- The FocusHeroCard (Swiss Alps) is pinned at top
- Atmosphere shows the alpine blue tint from the focus
- At least one sheet has been verified to open and dismiss cleanly in Chrome DevTools

---

## Execution strategy summary

```
Wave 1 (parallel, 10 agents):
  ┌────────┬────────┬────────┬────────┬────────┐
  │ T1     │ T2     │ T3     │ T4     │ T5     │
  │ models │ providers │ mock  │ atmos │ theme+ │
  │        │        │ data   │       │ shell  │
  ├────────┼────────┼────────┼────────┼────────┤
  │ T6     │ T7     │ T8     │ T9     │ T10    │
  │ cards  │ cards  │ cards  │ sheets │ header+│
  │ batch A│ batch B│ batch C│ (4)    │ masonry│
  │ (3)    │ (3)    │ (4)    │        │ +cleanup│
  └────────┴────────┴────────┴────────┴────────┘

Wave 2 (primary agent — me):
  ┌──────────────────────────────────────┐
  │  Add dep → pub get → rewrite page →  │
  │  dart analyze → kill flutter →       │
  │  relaunch → verify                   │
  └──────────────────────────────────────┘
```

Parallel safety: each Wave 1 track writes to its own files (no overlap). The only shared modification is Track 5 extending `theme.dart` — no other track touches theme. Interface contracts are pre-agreed in §Shared interface contracts so no track depends on reading another track's source.

## Rollback

If Wave 2 integration fails catastrophically, `git reset --hard 9dd71c1` restores the pre-spec state (masonry peek + mock data). Partial rollback points: each Wave 1 track commits individually, so `git reset --hard <any wave 1 commit>` is a valid intermediate.
