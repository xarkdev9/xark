# Mode Chip Home — Design Spec

**Date:** 2026-04-11
**Status:** Approved for implementation
**Supersedes:** 2026-04-11-live-surface-home-design.md (layout only — V10 living-field card mechanics are preserved)

---

## 1. Vision

The home screen is a **4-tab surface** (HOME / CHATS / GROUPS / PLANS) with a single unified bottom bar that does **everything**: shows the current tab, hosts search + mic + compose, and serves as the primary navigator. There is no top bar chrome — just a minimal floating user avatar.

Tabs are accessible two ways:
1. **Tap the mode chip** on the bottom bar → a popover rises with 4 tab choices
2. **Swipe horizontally on the feed** → `TabBarView` animates between tabs, atmosphere color lerps through the transition

The bottom bar layout follows iMessage conventions but reordered for right-thumb ergonomics:
**`[HOME ▾]  Search or a name…  🎤  [+]`**

- `[HOME ▾]` — tab chip (far left, passive label + dropdown affordance)
- Search field — middle, large tap target, adaptive placeholder per tab
- `🎤` — mic when idle, morphs to `↑` send arrow when text is entered (iMessage pattern)
- `[+]` — compose button, far right (thumb optimal), **context-aware per tab**

Chrome footprint: **~96px total** (36px floating avatar + 60px bottom bar). Feed gets ~88% of viewport.

## 2. Scope — V1 is V10

V1 ships the complete tabbed home with all 4 tabs functional + both navigation paths (tap + swipe) + the mode-chip bottom bar + all V10 living-field mechanics preserved inside each tab.

**In scope:**
- 4 tabs (HOME, CHATS, GROUPS, PLANS) each rendered as its own `ConsumerStatefulWidget` page with `AutomaticKeepAliveClientMixin` (scroll position preserved across switches)
- `TabController` + `TabBarView` for horizontal swipe navigation
- Atmosphere color lerp during horizontal tab swipe
- Mode chip dropdown popover (glass, 4 rows, tap to switch)
- Adaptive search field placeholder per active tab
- Mic → send arrow morph when text is entered
- Context-aware `+` button (per-tab compose action)
- Floating avatar in top-left corner (no top bar)
- 3 new filtered feed providers (`chatsFeedProvider`, `groupsFeedProvider`, `plansFeedProvider`)
- `activeTabIndexProvider` for cross-component tab state sharing

**Out of scope:**
- Avatar actions beyond a placeholder tap (profile / settings is v2)
- Voice search functionality (mic button is a v1 stub, only the morph is real)
- Custom card types for CHATS/GROUPS/PLANS pages — they reuse the existing 10 V10 card types filtered by kind
- Filtered feed providers hitting the real engine — all go through mock data for v1 via `kUseMockData`
- Horizontal swipe conflict resolution beyond Flutter's default `TabBarView` gesture arena
- "SWIPE MODES" teaching overlay — we rely on discoverability of standard `TabBarView` swipe

## 3. Architecture

### 3.1 Layer map

```
┌────────────────────────────────────────────────┐
│  DecisionBoardPage (TAB SCAFFOLD)              │
│  - ConsumerStatefulWidget + SingleTickerProviderStateMixin│
│  - owns TabController(length: 4)               │
│  - listens to controller, writes index to      │
│    activeTabIndexProvider                      │
│  - Stack:                                       │
│    1. AmbientMesh (full-fill, watches centered kind + tab) │
│    2. SafeArea > TabBarView(4 children)       │
│       - HomePage                                │
│       - ChatsPage                               │
│       - GroupsPage                              │
│       - PlansPage                               │
│    3. Positioned top-left: FloatingAvatar      │
│    4. Align bottomCenter: BottomBar            │
└────────────────────────────────────────────────┘
                     │
                     ▼
     ┌───────────────────────────────┐
     │     activeTabIndexProvider     │  ← StateProvider<int>, updated by
     │     StateProvider<int>          │    TabController listener
     └───────────┬───────────────────┘
                 │
     ┌───────────▼───────────────────┐
     │  Derived Providers             │
     │   - activeTabProvider (enum)   │
     │   - activeTabHintProvider      │
     │   - activeTabAccentProvider    │
     └───────────────────────────────┘
```

### 3.2 Tab enum

```dart
enum HomeTab { home, chats, groups, plans }
```

### 3.3 Filtered feed providers

```dart
final homeFeedProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider); // existing unified feed unchanged
});

final chatsFeedProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider).whereType<DmFeedItem>().toList();
});

final groupsFeedProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider).whereType<GroupFeedItem>().toList();
});

final plansFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  return <FeedItem>[
    ...feed.whereType<FocusHeroFeedItem>(),
    ...feed.whereType<TripFeedItem>(),
    ...feed.whereType<ItineraryFeedItem>(),
  ];
});
```

### 3.4 Reuse audit

**Keep unchanged (V10 survivors):**
- All 10 card widgets (dm_card, group_card, decision_card_small, decision_card_hero, trip_card, focus_hero_card, settlement_card, itinerary_card, memory_card, ai_nudge_card)
- `_card_shell.dart` — glass surface + focus lift + pulsing ring + kind overlay + ambient pulse + spring tap
- `masonry_grid.dart` — SliverMasonryGrid wrapper
- `atmosphere.dart` — lerps glow to centered kind (plus swipe-tab-aware color as an extension)
- `viewport_focus_provider.dart` — cardKeyRegistry, centeredFeedItemIdProvider, centeredFeedItemKindProvider
- All 6 sheets (dm_sheet, group_sheet, decision_sheet, settlement_sheet, search_sheet, new_chat_sheet, attachment_sheet)
- `message_input_bar.dart` — still used INSIDE DM/Group sheets for reply input
- All providers (feed_provider, focus_provider, conversations_provider, decisions_provider, trips_provider, settlements_provider, itinerary_provider, mock_data)
- `main.dart`, `theme.dart`, `home_layout.dart`

**New:**
- `providers/tabs_provider.dart` — `activeTabIndexProvider`, `activeTabProvider`, derived helpers
- `providers/filtered_feed_providers.dart` — `homeFeedProvider`, `chatsFeedProvider`, `groupsFeedProvider`, `plansFeedProvider`
- `views/home/decision_board/floating_avatar.dart` — 36px floating user avatar
- `views/home/decision_board/tab_chip.dart` — the `[HOME ▾]` chip with caret and tap-to-open popover
- `views/home/decision_board/tab_popover.dart` — Overlay-based 4-tab popover that appears above the chip
- `views/home/decision_board/bottom_bar.dart` — the full glass pill layout
- `views/home/decision_board/_card_factory.dart` — shared `buildFeedItemCard(context, item)` switch helper (used by all 4 pages)
- `views/home/decision_board/pages/home_page.dart`
- `views/home/decision_board/pages/chats_page.dart`
- `views/home/decision_board/pages/groups_page.dart`
- `views/home/decision_board/pages/plans_page.dart`

**Rewritten:**
- `views/home/decision_board/decision_board_page.dart` — becomes TAB SCAFFOLD with TabController + TabBarView + 4 pages + FloatingAvatar + BottomBar

**Deleted:**
- `views/home/decision_board/search_compose_bar.dart` — replaced by bottom_bar.dart
- `views/home/decision_board/feed_header.dart` — replaced by floating_avatar.dart

## 4. Layout specs

### 4.1 Top — floating avatar

- **Position:** absolute, top-left. 20px from left edge, 12px below the top safe-area inset
- **Size:** 36×36 circle
- **Background:** `HelloColors.recessed` with a 1px hairline border at 10% white
- **Content:** initial "R" in Inter 400, 15px, `inkPrimary`
- **Tap:** v1 no-op (placeholder for v2 profile)
- **No bar chrome around it** — just the circle overlaid on the feed

### 4.2 Bottom bar — glass pill

- **Position:** `Align(alignment: Alignment.bottomCenter)` inside the Scaffold body Stack
- **Padding from edges:** 16px left, 16px right, 14px above the bottom safe-area inset
- **Height:** 60px
- **Radius:** 28px
- **Chrome:**
  - `ClipRRect(borderRadius: 28)` → `BackdropFilter(sigma: 24)` → `Container` with gradient fill 8% → 3% white, 1px rim at 12% white
- **Internal padding:** 10px vertical, 14px horizontal
- **Layout (single row, left → right):**

| Element | Size | Gap after |
|---|---|---|
| TabChip `[HOME ▾]` | auto (~92–120px depending on label) | 12px |
| Search field | `Expanded` | 10px |
| Mic/Send button | 36×36 circle | 8px |
| Compose `+` button | 36×36 circle | 0 |

### 4.3 TabChip

- **Shape:** rounded 20px capsule, 36px tall
- **Background:** `HelloColors.recessed` at 60% opacity
- **Padding:** 12px left, 10px right, 8px vertical
- **Content:**
  - Label: tab name in UPPERCASE, Inter 400, 11px, letter-spacing 1.2, `inkPrimary`
  - Caret: `Icons.keyboard_arrow_up_rounded` at 14px, `inkSecondary`, 4px left gap
- **Active color tint:** the chip's label + caret gain a subtle tint from the active tab's atmosphere color (violet for CHATS, orange for GROUPS, alpine blue for PLANS, neutral for HOME)
- **Tap:** opens `TabPopover` via `Overlay.insert`

### 4.4 TabPopover

- **Trigger:** tap on TabChip
- **Position:** floats above the TabChip using `CompositedTransformFollower` (offset upward by `-[popover height + 8]`)
- **Size:** 180px wide, ~200px tall (4 rows × 48px + 8px vertical padding)
- **Chrome:**
  - `ClipRRect(borderRadius: 20)` → `BackdropFilter(sigma: 24)` → gradient fill at 12% white → 4% white, 1px rim at 14% white
- **Barrier:** full-screen tappable transparent layer — tap anywhere outside → dismiss
- **Entry animation:** 180ms ease-out, fade + scale from 0.94
- **Content:** 4 rows, each a 48px GestureDetector
  - Left: 32×32 small icon tile tinted by that tab's atmosphere color
  - Middle: tab label ("Home" / "Chats" / "Groups" / "Plans") in Inter 400, 15px
  - Right: a small check `Icons.check_rounded` at 14px if this row is the active tab
- **Tap a row:** dismisses popover, calls `tabController.animateTo(index)`

### 4.5 Search field

- **Widget:** `TextField` (transparent background, no inner decoration)
- **Text style:** Inter 400, 15px, `inkPrimary`
- **Placeholder style:** Inter 300, 15px, `inkTertiary`
- **Adaptive placeholder:**

| Active tab | Placeholder |
|---|---|
| HOME | "Search or a name…" |
| CHATS | "Search chats or a name…" |
| GROUPS | "Search groups…" |
| PLANS | "Search plans…" |

- **Cursor:** 1px, `inkPrimary`
- **On submit (return key):** triggers the `onSend` callback — opens `search_sheet.dart`

### 4.6 Mic/Send button

- **Size:** 36×36 circle
- **Background:** `HelloColors.recessed` when mic, focus accent color when send
- **Icon:** `Icons.mic_none_rounded` (18px) when idle, `Icons.arrow_upward_rounded` (18px) when text entered
- **Transition:** 200ms `AnimatedSwitcher` with `ScaleTransition` + `FadeTransition`
- **Tap mic:** v1 stub (future: voice search)
- **Tap send:** opens search sheet with query scope to active tab

### 4.7 Compose `+` button

- **Size:** 36×36 circle
- **Background:** `HelloColors.recessed`
- **Icon:** `Icons.add` (22px) in focus-trip accent color
- **Tap behavior by active tab:**

| Tab | `+` action |
|---|---|
| HOME | Opens `new_chat_sheet.dart` with 3 options (Chat/Group/Event) |
| CHATS | v1: opens `new_chat_sheet.dart` (same sheet, 3 options — in v2 jumps direct to new DM) |
| GROUPS | v1: opens `new_chat_sheet.dart` |
| PLANS | v1: opens `new_chat_sheet.dart` |

v1 uses the same `new_chat_sheet` for all tabs (simplest path). v2 can add tab-specific compose flows.

## 5. Interaction model

### 5.1 Tab switching — two paths, both always available

| Path | User action | Effect |
|---|---|---|
| **Tap chip** | Tap `[HOME ▾]` on bottom bar | `TabPopover` rises above chip with 4 rows. Tap a row → popover dismisses, `TabController.animateTo(index)`. |
| **Swipe feed** | Horizontal drag on the feed | `TabBarView` handles the drag natively. Page slides, chip label updates live during drag, atmosphere mesh color lerps between the two tab colors, haptic tick on snap. |

Both paths write to `TabController.index`, which is mirrored to `activeTabIndexProvider` via a listener in `DecisionBoardPage.initState`.

### 5.2 Atmosphere lerp during swipe

The existing `AmbientMesh` already watches `centeredFeedItemKindProvider` and lerps the primary blob color. **New extension:** it ALSO watches the `activeTabProvider` and blends its color with the centered card kind's color, so during a horizontal swipe the background color cross-fades between the two tabs' signature colors.

Tab signature colors:

| Tab | Primary glow color |
|---|---|
| HOME | Default violet `#7C3AED` |
| CHATS | Violet `#8B5CF6` |
| GROUPS | Orange `#F97316` |
| PLANS | Alpine blue `#4A90E2` |

### 5.3 Keyboard + search behavior

- Tap search field → keyboard focuses, cursor appears
- As user types → mic morphs to send arrow, placeholder hides, user's text shows
- Clear text → send morphs back to mic
- Submit (return key OR tap send) → opens `search_sheet.dart` with `JUMP TO` list scoped to the active tab

For v1, the search sheet's filter is NOT pre-scoped — it shows all DMs + groups regardless of active tab. v2 will add scoping.

### 5.4 Compose `+` with focus accent

The `+` icon color always matches the **focus trip's accent color** (alpine blue for Swiss focus), not the active tab's color. This ties compose to "what you're planning" (the focus) rather than "what list you're on" (the tab). Subtle but meaningful.

## 6. File structure

### 6.1 New providers

```
app/lib/providers/
  tabs_provider.dart        (NEW)
  filtered_feed_providers.dart  (NEW)
```

### 6.2 New widgets

```
app/lib/views/home/decision_board/
  floating_avatar.dart        (NEW)
  tab_chip.dart               (NEW)
  tab_popover.dart            (NEW)
  bottom_bar.dart             (NEW)
  _card_factory.dart          (NEW)
  pages/
    home_page.dart            (NEW)
    chats_page.dart           (NEW)
    groups_page.dart          (NEW)
    plans_page.dart           (NEW)
```

### 6.3 Rewritten

```
app/lib/views/home/decision_board/
  decision_board_page.dart    (REWRITTEN - TAB SCAFFOLD)
```

### 6.4 Deleted

```
app/lib/views/home/decision_board/
  search_compose_bar.dart     (DELETED - replaced by bottom_bar.dart)
  feed_header.dart            (DELETED - replaced by floating_avatar.dart)
```

Any references to `SearchComposeBar` or `FeedHeader` anywhere must be updated to the new widgets.

## 7. Success criteria

The ship is successful when:

1. `dart analyze lib/` returns 0 errors + 0 warnings (cosmetic info lints acceptable)
2. `flutter run -d chrome --web-port=8765` launches cleanly
3. Home screen shows a 4-tab scaffold with HOME as the default tab
4. Swipe horizontally on the feed → tab switches with smooth slide + atmosphere lerp + haptic
5. Tap `[HOME ▾]` on bottom bar → popover rises with 4 tab rows
6. Tap a tab row in the popover → tab switches
7. Tap search field → keyboard focuses, adaptive placeholder matches active tab
8. Type "hello" in search field → mic button morphs to send arrow in alpine blue
9. Tap send → opens search sheet (existing v10 behavior)
10. Tap `+` button → opens new_chat_sheet with 3 options
11. Tabs preserve scroll position when switching away and back
12. HOME tab shows the full mixed feed + FocusHeroCard at top
13. CHATS tab shows only DM cards
14. GROUPS tab shows only group cards
15. PLANS tab shows focus hero + trip cards + itinerary cards
16. Top-left corner shows a 36px floating avatar circle with "R"
17. No top bar chrome visible anywhere
18. Bottom bar hovers above the home indicator with proper safe-area padding

## 8. Known limitations (acceptable for v1)

- Voice search (mic tap with empty field) is a placeholder stub
- `+` button opens the same new_chat_sheet for all tabs (not per-tab compose)
- Search sheet doesn't filter by active tab (shows all DMs + groups regardless)
- TabPopover doesn't have a backdrop blur of the feed underneath (just a tappable dismiss barrier)
- No "first-run" teaching overlay for the swipe gesture
- Atmosphere lerp during swipe is linear; could be eased for more polish
- CHATS/GROUPS/PLANS pages share a single `_card_factory.dart` — they're visually identical aside from the filtered content

---

**Next:** write the parallel implementation plan at `docs/superpowers/plans/2026-04-11-mode-chip-home.md` and dispatch subagents.
