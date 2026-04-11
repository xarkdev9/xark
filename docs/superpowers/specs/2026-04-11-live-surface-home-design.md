# Live Surface — V10 Home Feed Design

**Date:** 2026-04-11
**Status:** Approved for implementation
**Supersedes:** 2026-04-10-decision-board-peek-stack-design.md (which itself replaced the demov2 swim-lane design)

---

## 1. Vision

The hello home screen is a **time-ordered, masonry-layout, live-streaming feed of everything actionable across every group and every person you coordinate with.** Unlike Instagram (passive) or TikTok (algorithmic), every card is a thing to do: reply to a DM, vote on a decision, pay a settlement, open a trip. Users scroll vertically through glass cards of varied sizes, tap to open a full-screen sheet, act inline, dismiss. One topic is pinned as the current "FOCUS" (your most active trip or event) and tints the atmospheric background.

This is not a messenger with a dashboard. This is a **group coordination surface** whose UX justifies a billion-dollar business model (consumer subscription + transaction fees + B2B white-label + GroupIntelligence API).

## 2. Why this design

Coordinated small groups (2–15 people) are the underserved niche in consumer software. Currently: WhatsApp thread → Google Doc → Venmo → Calendar → Photos Library → scattered, chaotic, forgotten. hello collapses that stack into one E2EE surface. Every card is structured data (not plaintext), every decision is auditable, every settlement is tracked, every memory is searchable.

The home feed must make this tangible in <3 seconds of first scroll. It must prove that "the app that remembers my group" is a real thing.

## 3. Scope — V1 is V10

This ship includes **everything needed to be visually and architecturally complete at the billion-dollar target.** No intentional deferrals for "later sprints" beyond the explicit out-of-scope list at the end.

**In scope:**
- Masonry 2-column grid with hero tiles via `flutter_staggered_grid_view`
- 10 card types (see §5)
- 4 full-screen action sheets (see §7)
- FocusProvider with per-focus atmosphere color tinting
- Unified `FeedItem` sealed class + `feedProvider` merging all sources
- New domain models: `Trip`, `Settlement`, `ItineraryEvent`
- New providers: `trips_provider`, `settlements_provider`, `itinerary_provider`, `focus_provider`, `feed_provider`
- Extended mock data with trips, settlements, itinerary, focus, memory cards, AI nudge cards
- Feed header strip: `LIVE SURFACE · What matters now` (left) · `FOCUS · {trip}` (right)
- Dark violet atmospheric mesh that shifts color based on active focus
- Full brand-restraint rule application (Rausch only in: unread dots, live indicators, CTA text, settlement pay button)

**Explicitly out of scope for V1:**
- Trip detail screen (TripCard navigates to a placeholder route)
- In-place card expansion (we use full-screen modal sheets; shared-element transitions are v2)
- Real engine wiring (we ship behind `kUseMockData = true`; the engine path stays functional for when auth is wired)
- Swipe gestures on feed tiles (gestures live inside the sheets, not on the masonry grid)
- Card types 11–24 from the billion-dollar vision (milestones, reflections, suggestions, digests, nearby, birthday, photo-of-day, pending-payment, settlement-complete, countdown, live-session, group-check-in). The `FeedItem` sealed class and card-type switcher in `decision_board_page.dart` are designed so each of these is a single-file addition later.
- Focus picker UI (v1 focus is hardcoded to `swiss_jun_2026` via mock data; user cannot change it at runtime yet)
- Haptic choreography, delight animations beyond the existing glass shell
- Accessibility polish (dynamic type, VoiceOver labels) — baseline only
- Offline state rendering — providers already handle this gracefully

## 4. Architecture

### 4.1 Layer map

```
┌─────────────────────────────────────────────────────────┐
│  DecisionBoardPage (ConsumerStatefulWidget)            │
│  - CustomScrollView with header sliver + SliverMasonryGrid│
│  - Iterates feedProvider, switches on FeedItem type,    │
│    builds the correct card widget, wires onTap to sheet │
└──────────────────────┬──────────────────────────────────┘
                       │ watches
          ┌────────────┴────────────┐
          │    feedProvider          │
          │  (merges 7 sources,     │
          │   sorts by sortKey)      │
          └────┬─────────────┬──────┘
               │             │
    ┌──────────┴──┐  ┌──────┴──────┐
    │ existing    │  │ new         │
    │ providers   │  │ providers   │
    │ (DMs,       │  │ (trips,     │
    │  groups,    │  │  settlements,│
    │  decisions) │  │  itinerary, │
    │             │  │  focus)     │
    └─────────────┘  └─────────────┘
          │                 │
          └────────┬────────┘
                   │
          ┌────────┴────────┐
          │   mock_data     │
          │  (kUseMockData) │
          └─────────────────┘
```

All data flows through the sealed `FeedItem` union. No widget reads raw `Conversation` or `DecisionItem` directly; every widget takes a typed `FeedItem` variant.

### 4.2 Sealed FeedItem union

One sealed class with 10 variants. Every variant has:
- `String get id` — globally unique, prefixed (`dm_`, `group_`, `decs_`, `dech_`, `trip_`, `settle_`, `itin_`, `mem_`, `ai_`, `focus_`)
- `DateTime get sortKey` — what `feedProvider` sorts by

The `FocusHeroFeedItem` variant has `sortKey = DateTime(9999)` so it always appears first after sort. All other variants sort by their most recent activity timestamp, descending.

### 4.3 Feed ordering

**Time descending, Instagram/WhatsApp style.** No urgency scoring, no ranking algorithm. The exception is `FocusHeroFeedItem`, which is pinned at index 0 regardless of timestamp. Everything else flows by `sortKey` desc.

```dart
items.sort((a, b) {
  if (a is FocusHeroFeedItem) return -1;
  if (b is FocusHeroFeedItem) return 1;
  return b.sortKey.compareTo(a.sortKey);
});
```

### 4.4 Masonry layout

`SliverMasonryGrid.count(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12)` from the `flutter_staggered_grid_view` package (~5k stars, maintained). Each card is a `StaggeredGridTile.fit()` by default; hero cards use `StaggeredGridTile.count(crossAxisCellCount: 2, ...)` to span both columns.

Card height is driven by each widget's own `Column` children — masonry handles variable heights natively. The `_CardShell` glass surface does not enforce a height.

### 4.5 Reuse audit

**Keep (unchanged):**
- `app/lib/main.dart` — engine boot, lifecycle, routing
- `app/lib/theme.dart` — extended with focus colors, not broken
- `app/lib/providers/conversations_provider.dart` — still source of truth for DMs and groups
- `app/lib/providers/decisions_provider.dart` — still source of truth for decision items
- `app/lib/providers/home_state_provider.dart` — repurposed to track feed scroll position
- `app/lib/views/home/home_layout.dart` — unchanged wrapper
- `.agent/`, existing docs, engine package

**Delete (orphaned by this spec):**
- `app/lib/views/home/decision_board/peek_stack.dart`
- `app/lib/views/home/decision_board/cards/chats_card.dart`
- `app/lib/views/home/decision_board/cards/groups_card.dart`
- `app/lib/views/home/decision_board/cards/decisions_card.dart`
- `app/lib/views/home/decision_board/cards/card_header.dart`
- `app/lib/views/home/decision_board/cards/empty_state.dart`
- `app/lib/views/home/decision_board/cards/conversation_row.dart`
- `app/lib/views/home/decision_board/cards/decision_row.dart`
- `app/lib/views/home/decision_board/cards/see_all_row.dart`

**Rewrite (same file, new content):**
- `app/lib/views/home/decision_board/decision_board_page.dart` — masonry feed host
- `app/lib/views/home/decision_board/atmosphere.dart` — violet gradient with focus-color shift
- `app/lib/providers/mock_data.dart` — extended with trips, settlements, itinerary, memories, AI nudges, focus, decision hero metadata

**New:**
- 4 domain models (`models/feed_item.dart`, `trip.dart`, `settlement.dart`, `itinerary_event.dart`)
- 5 new providers (`trips`, `settlements`, `itinerary`, `focus`, `feed`)
- 10 card widgets + 1 shared `_card_shell.dart`
- 4 sheet widgets
- 1 feed header widget
- 1 masonry wrapper widget

## 5. Card taxonomy (10 types at V10)

| # | Type | Span | Content | Action | Photo bg |
|---|---|---|---|---|---|
| 1 | **DmCard** | 1 col | flat avatar · name · 2m · 1-line preview · unread dot | tap → DmSheet | no |
| 2 | **GroupCard** | 1 col | avatar · group name · live eyebrow · activity blurb · unread dot | tap → GroupSheet | no |
| 3 | **DecisionCardSmall** | 1 col | title · eyebrow (TONIGHT / NEEDS YOU) · inline ♥ ✓ ✗ vote · progress bar | react inline **or** tap → DecisionSheet | no |
| 4 | **DecisionCardHero** | 2 cols | photo bg · scrim · title · subtitle · "N voted" · live tag · progress ring | tap → DecisionSheet | yes |
| 5 | **TripCard** | 2 cols | destination photo · trip name · dates · member stack · "N pending" · phase ring | tap → **navigates** to placeholder trip route | yes |
| 6 | **SettlementCard** | 1 col | "You owe X" or "X owes you" · avatar · amount · quick-pay button | pay inline · tap → SettlementSheet | no |
| 7 | **ItineraryCard** | 1 col | "Dinner at Alila · 7pm" · countdown · location · member stack | tap → (stub: DmSheet for groupId) | no |
| 8 | **MemoryCard** | 1 col (medium) | eyebrow ("A YEAR AGO TODAY") · body · optional photo · CTA | tap → (stub: placeholder snackbar) | optional |
| 9 | **AiNudgeCard** | 1 col | @hello voice eyebrow · message · CTA button | tap CTA → (stub: placeholder snackbar) | no |
| 10 | **FocusHeroCard** | 2 cols (tall) | destination photo bg · focus eyebrow · trip name · dates · phase · member stack | tap → TripCard navigation | yes |

Each card is **self-contained**: it takes its typed `FeedItem` variant in the constructor, wraps content in `_CardShell`, and calls back with `onTap`. Cards do not read providers directly — `decision_board_page.dart` is the only widget that watches `feedProvider`.

### 5.1 Card height ranges (masonry-friendly)

- Small 1-col cards: ~140–200 px tall
- Medium 1-col cards (memory): ~220–280 px
- Hero 2-col cards: ~280–360 px
- FocusHero (top pinned): ~320–400 px

Column spacing = 12 px, row spacing = 12 px, horizontal padding = 16 px from viewport edges.

## 6. FocusProvider + atmosphere tinting

One topic is always "the focus" — the trip or event you're most engaged with. In V1 this is hardcoded to `swiss_jun_2026` (which resolves to the Swiss Alps trip in mock data). Future: user can long-press any TripCard to set as focus.

The focus drives **two** visual surfaces:
1. The **FocusHeroFeedItem** always appears at index 0 of the feed (pinned hero card spanning 2 columns)
2. The **atmosphere mesh** shifts its primary glow color to match the focus's `accentColor` field:
   - Swiss → `0xFF4A90E2` (alpine blue)
   - Goa → `0xFF14B8A6` (ocean teal)
   - Bali → `0xFFFF9B6E` (sunset amber)
   - Tokyo → `0xFFD4536B` (deep rose)
   - No focus → default `0xFF7C3AED` (deep violet)

Atmosphere reads `focusTripProvider` via Riverpod and listens for changes. When the focus changes, the mesh color animates to the new primary glow over ~800ms.

`focus_provider.dart` exports:
```dart
final focusTripIdProvider = StateProvider<String?>((ref) => kMockFocusTripId);
final focusTripProvider = Provider<Trip?>((ref) { ... });
```

## 7. Sheet system

Every card (except TripCard) opens a **full-screen modal sheet** on tap via `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: ...)`. The sheet fills ~92% of viewport height, has a handle at top + close X in corner, and dismisses on swipe-down or X-tap.

### 7.1 Sheets in V1

| Sheet | Triggered by | Content |
|---|---|---|
| **DmSheet** | DmCard, ItineraryCard (for now) | Header (avatar + name + online dot) · scrollable mock message thread (3–5 messages) · reply text field with send icon |
| **GroupSheet** | GroupCard | Header (name + "12 messages · 3 typing") · two stat chips (Unread, Typing) · activity summary blurb · reply text field |
| **DecisionSheet** | DecisionCardSmall, DecisionCardHero | Header (title + eyebrow) · optional photo hero · vote progress bar · 3 big vote buttons (Love it / Works for me / Not for me) · comments stub · dismiss |
| **SettlementSheet** | SettlementCard | Header (counterparty + amount) · itemized breakdown stub · big pay button · "mark as settled" stub |

TripCard navigates to a placeholder route (`/trip/{id}`) that shows "Trip view — coming soon" as a full screen. This demonstrates the routing distinction.

MemoryCard, AiNudgeCard, and ItineraryCard open a placeholder `ScaffoldMessenger` snackbar in V1 ("Coming in v1.1") — the tap affordance exists, the destination doesn't. This keeps scope manageable while validating the feed→sheet architecture.

### 7.2 Sheet visual language

- Background: ambient mesh continues behind (sheet is semi-transparent over it)
- Sheet chrome: glass surface (same treatment as cards), no hard card border
- Top handle: 40×4 pill at ~12% white
- Close X: 24×24 at top-right, `inkSecondary`
- Typography: Inter 400 for body, Inter 300 for metadata, no-bold mandate
- Brand color: still restrained — Rausch only in send button, pay button, active vote button

## 8. Feed header

A `SliverToBoxAdapter` at the top of the `CustomScrollView`:

**Left column:**
- Eyebrow: `LIVE SURFACE` (10px caps, inkTertiary, letter-spacing 2)
- Display title: `What matters now` (22px, Inter 400, inkPrimary)

**Right column:**
- Eyebrow: `FOCUS` (10px caps, focus accent color, letter-spacing 2)
- Title: the focus trip's destination, e.g. `Swiss in June` (14px, Inter 400, inkPrimary)

Total header height: 96 px. Bottom has an 8% white hairline separator.

## 9. Visual language

- **Background:** `HelloColors.voidBg` (#050507) base, overlaid with animated `AmbientMesh` that has 4 drifting blur blobs whose primary glow color comes from the current focus's accent
- **Cards:** glass surface (`ClipRRect` 24px radius → `BackdropFilter` blur 20px → gradient fill 7%→2% white → 1px hairline rim)
- **Hero cards with photos:** photo loaded via `Image.network` with `colorBlendMode: BlendMode.darken` + `color: Colors.black.withValues(alpha: 0.35)` for text contrast, and a bottom scrim `LinearGradient` from transparent to `0xCC000000`
- **Typography:** Inter 400 (name, title, body), Inter 300 (preview, meta), 10px uppercase caps at 2-letter-spacing for eyebrows
- **Ink scale:** `inkPrimary` / `inkSecondary` / `inkTertiary`
- **Brand color (Rausch #FF385C):** unread dots (6px), live indicator tags, action button backgrounds in sheets, and nothing else. See the brand-restraint memory rule.
- **No hard borders on any content tile.** Zero-Box doctrine holds.
- **No-Bold mandate.** Font weight 400 maximum.

## 10. Data contracts (interface agreement between tracks)

### 10.1 Models

```dart
// models/trip.dart
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
// models/settlement.dart
class Settlement {
  final String id;
  final String counterpartyId;
  final String counterpartyName;
  final double amount;    // positive = they owe you, negative = you owe them
  final String currency;  // 'USD', 'EUR', ...
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
// models/itinerary_event.dart
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

### 10.2 FeedItem sealed union

```dart
// models/feed_item.dart
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'trip.dart';
import 'settlement.dart';
import 'itinerary_event.dart';

sealed class FeedItem {
  String get id;
  DateTime get sortKey;
}

final class DmFeedItem extends FeedItem {
  final Conversation conversation;
  DmFeedItem(this.conversation);
  @override String get id => 'dm_${conversation.id}';
  @override DateTime get sortKey => conversation.lastMessageTimestamp ?? conversation.updatedAt;
}

final class GroupFeedItem extends FeedItem {
  final Conversation conversation;
  final int typingCount;
  GroupFeedItem(this.conversation, {this.typingCount = 0});
  @override String get id => 'group_${conversation.id}';
  @override DateTime get sortKey => conversation.lastMessageTimestamp ?? conversation.updatedAt;
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
  @override String get id => 'decs_${item.id}';
  @override DateTime get sortKey => updatedAt;
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
  @override String get id => 'dech_${item.id}';
  @override DateTime get sortKey => updatedAt;
}

final class TripFeedItem extends FeedItem {
  final Trip trip;
  TripFeedItem(this.trip);
  @override String get id => 'trip_${trip.id}';
  @override DateTime get sortKey => trip.updatedAt;
}

final class SettlementFeedItem extends FeedItem {
  final Settlement settlement;
  SettlementFeedItem(this.settlement);
  @override String get id => 'settle_${settlement.id}';
  @override DateTime get sortKey => settlement.updatedAt;
}

final class ItineraryFeedItem extends FeedItem {
  final ItineraryEvent event;
  ItineraryFeedItem(this.event);
  @override String get id => 'itin_${event.id}';
  @override DateTime get sortKey => event.updatedAt;
}

final class MemoryFeedItem extends FeedItem {
  final String memoryId;
  final String eyebrow;    // "A YEAR AGO TODAY"
  final String title;      // "Alila Ubud"
  final String body;       // "The Bali crew decided on this. Worth a revisit?"
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
  @override String get id => 'mem_$memoryId';
  @override DateTime get sortKey => updatedAt;
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
  @override String get id => 'ai_$nudgeId';
  @override DateTime get sortKey => updatedAt;
}

final class FocusHeroFeedItem extends FeedItem {
  final Trip trip;
  FocusHeroFeedItem(this.trip);
  @override String get id => 'focus_${trip.id}';
  @override DateTime get sortKey => DateTime(9999);
}
```

### 10.3 `_CardShell` widget contract

```dart
// views/home/decision_board/cards/_card_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class CardShell extends StatelessWidget {
  final Widget child;
  final Color? accentColor;      // tints the 1px rim subtly; null = white
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const CardShell({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });
}
```

Every card wraps its internal Column in `CardShell(child: ..., onTap: onTap)`. The shell handles: rounded clip, backdrop blur, gradient fill, hairline rim, tap ripple.

### 10.4 Sheet launcher contract

Each sheet file exports a top-level function:

```dart
// views/home/decision_board/sheets/dm_sheet.dart
Future<void> openDmSheet(BuildContext context, DmFeedItem item) async { ... }

// views/home/decision_board/sheets/group_sheet.dart
Future<void> openGroupSheet(BuildContext context, GroupFeedItem item) async { ... }

// views/home/decision_board/sheets/decision_sheet.dart
Future<void> openDecisionSheet(BuildContext context, FeedItem item) async { ... }
// (accepts DecisionSmallFeedItem or DecisionHeroFeedItem)

// views/home/decision_board/sheets/settlement_sheet.dart
Future<void> openSettlementSheet(BuildContext context, SettlementFeedItem item) async { ... }
```

`decision_board_page.dart` imports these and wires the correct launcher per card type.

### 10.5 Provider contracts

```dart
// providers/trips_provider.dart
final tripsProvider = Provider<List<Trip>>((ref) { ... });

// providers/settlements_provider.dart
final settlementsProvider = Provider<List<Settlement>>((ref) { ... });

// providers/itinerary_provider.dart
final itineraryProvider = Provider<List<ItineraryEvent>>((ref) { ... });

// providers/focus_provider.dart
final focusTripIdProvider = StateProvider<String?>((ref) => kMockFocusTripId);
final focusTripProvider = Provider<Trip?>((ref) { ... });

// providers/feed_provider.dart
final feedProvider = Provider<List<FeedItem>>((ref) { ... });
```

All read from mock data when `kUseMockData = true`.

## 11. Dependencies

**New Flutter package:** `flutter_staggered_grid_view: ^0.7.0` — adds to `app/pubspec.yaml` under `dependencies`. Well-maintained, 5.4k stars, widely used (Quriverse, Bluesky Flutter apps). No transitive dependencies beyond Flutter itself.

No other package additions.

## 12. Rollback strategy

Every track commits its own output at the end of its Wave 1 execution. If anything breaks in Wave 2 integration, `git reset --hard <Wave 1 HEAD>` restores a broken-but-compilable intermediate state where the new providers + cards exist but `decision_board_page.dart` still imports the old peek_stack.

The toggle `kUseMockData` remains at `true`; flipping to `false` would disable all new providers in one keystroke (they'd fall through to their engine paths which return empty lists).

## 13. Success criteria

The V1 ship is successful when:

1. `dart analyze lib/` returns 0 errors, 0 warnings, and no new infos beyond the 10 pre-existing placeholder-page notices
2. `flutter run -d chrome` launches without runtime errors
3. The home screen renders a masonry feed with at least 14 visible cards across the 10 types
4. The FocusHeroCard (Swiss Alps) is pinned at top with an alpine blue atmosphere tint
5. Tapping a DmCard / GroupCard / DecisionCard / SettlementCard opens a full-screen sheet with the correct chrome and dismisses cleanly
6. Tapping a TripCard pushes a placeholder route (doesn't crash)
7. The brand color rule is obeyed (Rausch appears only in unread dots, live tags, and action buttons)
8. Scroll performance is smooth (no frame drops on a mid-range device)
9. All changes are committed across 10 Wave 1 commits + 1 Wave 2 integration commit

## 14. Known limitations (acceptable for V1)

- Masonry layout uses symmetric viewport fractions; hero spans are hardcoded (not responsive to card content)
- Sheet thread content is mock hardcoded — no real message plumbing
- Inline decision voting in `DecisionCardSmall` updates local UI only (no engine writes)
- Focus is hardcoded; no user-facing picker
- Photo URLs depend on Unsplash availability — if URLs 404, cards render with gradient fallback
- No skeleton loaders; cards appear all at once when `feedProvider` emits
- No pull-to-refresh (streams are live; refresh is redundant)
- TripCard navigation target is a `Scaffold` with a `Text('Trip view — coming soon')` placeholder

## 15. The billion-dollar trajectory

This home feed is the surface that enables the entire business model. Every card type maps to a revenue mechanism:

| Card | Revenue lever |
|---|---|
| DmCard, GroupCard | DAU/MAU habit loop → subscription conversion |
| DecisionCardSmall, DecisionCardHero, LiveEventCard | Decision lock as celebratory moment → screenshot virality → growth |
| TripCard, FocusHeroCard | Trip planning as the "job-to-be-done" → premium tier features |
| SettlementCard | Xpensly transaction fees (2% free, 0% pro) → direct revenue |
| ItineraryCard | Calendar integration → platform stickiness |
| MemoryCard | Compounding shared history → switching cost → retention |
| AiNudgeCard | @hello as group member → GroupIntelligence API differentiation |

When every card is actionable and the feed is alive, users return 10+ times per day. That habit loop funds the billion-dollar outcome.

---

**Next step:** write the implementation plan at `docs/superpowers/plans/2026-04-11-live-surface-home.md` and dispatch 10 parallel subagents.
