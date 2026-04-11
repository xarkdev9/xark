# Home Screen Redesign — Peek Stack (3-Card Vertical Swipe)

**Date:** 2026-04-10
**Status:** Design approved. Pending spec review → implementation plan.
**Supersedes:** The current `app/lib/views/home/decision_board/decision_board_page.dart` masonry/rail layout (uses mock data, no engine wiring).

---

## 1. Problem

The hello home screen needs to answer three jobs the moment the app opens:
- **Where are my 1:1 conversations?** (DMs)
- **Where is my group chat activity?** (Group chats)
- **What needs my vote?** (Decisions / consensus engine)

Current state audited on 2026-04-10:
- `group_chat_page.dart` and `direct_message_page.dart` are stubs with hardcoded strings, zero engine wiring.
- `decision_board_page.dart` renders masonry + rails from `mockDecisionItems()`, zero engine wiring.
- No chat provider, no decision provider, no message stream consumer anywhere in `app/lib/`.
- Prior design iterations (swim-lane rails, masonry grid, chat-strip + tabs, editorial cascade) were all rejected by the user for feeling "SaaS / 2015 / meditation app / not WhatsApp-clarity".

The user's brief (2026-04-10):

> "Chat cards on home screen. 1 card for 1:1 personal chats, another card for group chats, another card for items which I have to vote. Instead of tabs and swipe on screen, I want to use cards. Vertical swipe of these 3 cards on home screen. If user clicks on any card, then they go to the actual screens."

Confirmed content density model: **live previews** inside each card (iMessage/WhatsApp style), not summary counts.

## 2. Decision

**Approach:** Peek Stack — vertical PageView with a 78% current card, 18% peek of the next card, 4% peek of the previous card. Hard stop at both ends (no infinite loop).

**Why:**
- Discoverability without chrome — the peek teaches "there's more below" without dots, tabs, or tutorial
- Utility-app rhythm, not feed-app rhythm — hard stop provides completion, infinite loop invites doom-scroll
- No gesture conflict — peek areas are paginate handles, card body owns scroll
- Aligns with DESIGN.md doctrines: Zero-Box (no containers), no-bold (hierarchy via size + opacity + color), glass only for functional containers

**Rejected alternatives:**
- **Full-screen pages (Approach 1):** low discoverability on first open; dots indicator doesn't fully compensate
- **Pinned expand/collapse (Approach 3):** each card in collapsed state shows too little content; unusual interaction model

## 3. The Three Cards

| # | Card | Data source | Sort order | Row anatomy |
|---|---|---|---|---|
| 1 | **Chats** (1:1 DMs) | `conversationsProvider.where(isGroup == false)` | Unread first, then most recent | Avatar (44px circle) · Name · Last message preview · Timestamp · Unread badge |
| 2 | **Groups** | `conversationsProvider.where(isGroup == true)` | Unread first, then most recent | Avatar stack (3×28px overlapping) · Group name · "[sender]: preview" · Timestamp · Unread badge |
| 3 | **Decisions** | `decisionsProvider` (cross-group, active only) | Hot first (consensus ≥80%), then weighted score desc | Thumbnail (40px square, 0 radius) · Score (22px Geist Mono, left-anchored beside title) · Title · Category · Consensus bar **replaces the row's bottom separator** (2px, width proportional to score %, color hot/warm/cool) |

### Card header (shared across all 3)
- Height: 56px
- Content: `CARD NAME · N unread` in 10px Micro caps (Satoshi 400, tracking 0.1em), Ink Secondary color
- Tappable → navigates to the full list screen for that card
- Pull-to-refresh lives on the card body, not the header

### Row content rules
- **Chats card:** show last message preview text. `"are we doing the cruise?"` (no sender prefix — it's a DM, sender is implied)
- **Groups card:** show sender + preview. `"Sarah: are we doing the cruise?"`
- **Decisions card:** score is the **horizontal anchor** on the left of the title, not stacked vertically. Layout: `[thumb] [score] [title / category stacked] [optional: hot/fresh/locked badge]`. Consensus bar is the row's bottom separator (see §8 for exact dimensions). This avoids the visual crowding risk of stacking score + title + category + separator vertically in a 56px row.
- All rows: tappable. Tapping a row navigates directly to that specific chat or decision (not the full list).

### Content cap per card
- Show **up to 10 rows** in the card by default (fewer if the user has fewer items; never more)
- If more than 10 items exist, the 10th visible row is replaced by a "See all N" row that navigates to the full list screen
- **"See all" row aesthetic:** same height as normal rows (64px), no background, no border, no pill. Right-aligned text `See all 23 →` in 13px Satoshi weight 300, Ink Secondary color, trailing arrow glyph. Looks like a dimmed list row, not a button. Zero-Box doctrine preserved.
- **Cards do not internally scroll** in v1. This is a deliberate constraint to avoid gesture conflict with the PageView paginate gesture and keep v1 simple. Scroll capability is deferred to v2 after the gesture resolution is validated.

## 4. Peek Stack Geometry

Viewport = usable screen height (below status bar, above bottom safe area)

```
┌────────────────────────────────────┐
│ [previous card header peek]  4%    │ ← prev card header only, dimmed 50%, scale 0.94
├────────────────────────────────────┤
│                                    │
│  CARD HEADER  · N unread            │
│                                    │
│  [row 1]                            │
│  [row 2]                            │
│  [row 3]                            │
│  [row 4]                            │   78% = current card
│  [row 5]                            │
│  [row 6]                            │
│  [row 7]                            │
│  [row 8]                            │
│  See all N →                        │
│                                    │
├────────────────────────────────────┤
│ [next card header peek]      18%    │ ← next card header + 1 row, dimmed 70%, scale 0.94
│ [next card row 1 teaser]            │
└────────────────────────────────────┘
```

**Exact percentages:**
- Current card: **78%** of viewport height
- Next card peek (below): **18%** — enough for header (56px) + 1 row teaser (~44px) on a typical 714px usable height
- Previous card peek (above): **4%** — enough for header text only, acts as a "breadcrumb" showing what you just came from
- On card 1 (Chats): no previous peek (hard stop)
- On card 3 (Decisions): no next peek (hard stop)

**Dimensions example** (390×844 iPhone, 714px usable after status bar + safe area):
- Current card height: 557px
- Next peek height: 129px
- Previous peek height: 29px
- Total: 715px ✓

## 5. Interaction Rules

### Vertical pagination
- **Trigger:** swipe up/down anywhere on the card (including the row list area, since internal scroll is disabled in v1)
- **Snap:** card snaps to next/previous position using spring physics
- **Spring config:** `stiffness: 400, damping: 30, mass: 1.0` — stiff, snappy, no bounce past target
- **Velocity threshold:** swipe velocity > 500 px/s OR drag distance > 30% of card height = commit to next card; otherwise snap back
- **Hard stop:** at card 1, downward swipe rubber-bands (15% overshoot, elastic return). At card 3, upward swipe rubber-bands same way.
- **Haptic:** `HapticFeedback.lightImpact()` on snap-into-place (iOS taptic "tick")

### Row tap
- **Trigger:** single tap on any row
- **Action:** navigate to that specific chat/group/decision detail screen via `Navigator.push`
- **Transition:** slide-from-right (iOS default) for chat screens; portal-dissolve for decisions (matches DESIGN.md signature)

### Card header tap
- **Trigger:** single tap on the card header (NOT on a row)
- **Action:** navigate to the full list screen for that card type
- **Transition:** slide-from-right

### No pull-to-refresh in v1 (gesture conflict avoidance)
Data is live-streamed via Riverpod `StreamProvider` from `engine.conversations` and the decisions provider. The UI auto-updates on every message/decision change. **Manual refresh is semantically unnecessary** and adding it would create a gesture ambiguity with the vertical paginate swipe (as flagged in the review). Since there's no functional benefit and a real risk, pull-to-refresh is removed from v1. In v2, when internal scrolling is added, pull-to-refresh can be re-evaluated with proper gesture isolation (e.g., `NestedScrollView` + sentinel-at-top detection).

### State persistence during navigation
The active card index and controller state must survive widget lifecycle events: navigation pushes (tapping a row → chat detail), engine provider rebuilds, and hot reloads.

**Implementation:**
- `homeActiveCardIndexProvider = StateProvider<int>((_) => 0)` — lives outside the widget tree, survives everything
- `_DecisionBoardPageState.initState()` reads the provider and initializes `PageController(initialPage: ref.read(homeActiveCardIndexProvider))`
- `onPageChanged` callback writes back: `ref.read(homeActiveCardIndexProvider.notifier).state = newIndex`
- Secondary safeguard: `AutomaticKeepAliveClientMixin` on `DecisionBoardPage` so it isn't disposed when a detail screen pushes on top (standard Flutter pattern for tab/page preservation)

**Result:** navigating from the Chats card into a specific chat and back returns you to the Chats card, not card 1. Same for engine provider rebuilds (auth re-init, token refresh).

### Focus dimming (while swiping between cards)
As the user drags, opacity and scale interpolate smoothly:
| State | Opacity | Scale |
|---|---|---|
| Current card (78% position) | 1.0 | 1.0 |
| Peeking card (18% or 4% position) | 0.70 | 0.94 |
| Transition (mid-swipe) | linear interpolation between the two | linear interpolation |

Peeking card rows additionally dim to **50% opacity** so the header is the most legible element.

### Scroll state persistence
- Each card remembers its internal scroll position across swipes (v2, when internal scroll is enabled)
- For v1 (no internal scroll): no state to remember
- The home screen remembers which card was active when navigating away. Returning from a chat detail screen lands back on the same card (e.g., Chats), not card 1.

## 6. Empty States

**Every card renders even when it has zero content.** This preserves the 3-card rhythm and peek stack geometry.

| Card | Empty state |
|---|---|
| **Chats (0 DMs)** | Header: `CHATS · 0` · Body: 48px illustration (line-art chat bubble) + "No conversations yet" (Body 17px Ink Secondary) + "Start a chat" primary text action (Accent color) |
| **Groups (0 groups)** | Header: `GROUPS · 0` · Body: 48px illustration (line-art people) + "No group chats yet" + "Create a group" primary text action |
| **Decisions (0 active)** | Header: `DECISIONS · 0` · Body: 48px illustration (line-art lightbulb) + "Nothing to vote on" + "Start a decision" primary text action |

Illustrations are inline SVG paths in Ink Tertiary color, ~1.4px stroke, no fills — line art only, matching DESIGN.md icon language.

CTAs are text actions (no pills, no buttons, per Zero-Box doctrine), Accent color, 17px Satoshi 400, with a trailing arrow `→` glyph.

## 7. Data Layer

### New providers (none of these exist today)

#### `lib/providers/conversations_provider.dart`
```dart
// Pseudo-signature — real code in implementation phase
@riverpod
Stream<List<Conversation>> conversations(ConversationsRef ref) {
  final engine = ref.watch(engineProvider);
  return engine.conversations; // Stream<List<Conversation>>
}

@riverpod
List<Conversation> directMessages(DirectMessagesRef ref) {
  final all = ref.watch(conversationsProvider).valueOrNull ?? [];
  return all.where((c) => !c.isGroup).toList()
    ..sort(_unreadFirstThenRecent);
}

@riverpod
List<Conversation> groupChats(GroupChatsRef ref) {
  final all = ref.watch(conversationsProvider).valueOrNull ?? [];
  return all.where((c) => c.isGroup).toList()
    ..sort(_unreadFirstThenRecent);
}
```

#### `lib/providers/decisions_provider.dart`
```dart
// Pseudo-signature
@riverpod
Stream<List<DecryptedItemPayload>> activeDecisions(ActiveDecisionsRef ref) {
  final engine = ref.watch(engineProvider) as ChatEngineDecisions;
  // Engine API: need to add a cross-group active-decisions stream if not present
  return engine.getActiveDecisionsAcrossGroups();
}
```

**Engine API gap:** `ChatEngineDecisions` currently exposes per-group methods (`getDecisionItems(groupId)`). No cross-group active-decisions stream exists today.

**Fallback commitment:** if the implementation plan confirms no cross-group stream exists in the engine, the `activeDecisionsProvider` will **merge client-side**: watch `engine.conversations`, fetch `getDecisionItems(groupId)` for each active group, filter to `state != 'archived' && !isLocked`, and combine into a single sorted list. This is O(groups) work per refresh, acceptable for typical group counts (< 20). A proper engine-side stream can replace the merge later as a perf optimization without changing the widget API.

#### Lifecycle
- Providers are `AutoDispose` — subscribe when the home screen mounts, unsubscribe on dispose
- `ref.invalidate` on pull-to-refresh
- Error states: if engine not initialized, show loading skeleton instead of throwing

### Data model shims
- `Conversation` comes from the engine package (`e2ee_chat_sdk`). No shim needed.
- `DecryptedItemPayload` comes from the engine package. **Remove `DecisionItem` mock class from `decision_board/models.dart`** — it was a stopgap. Use the real payload type.

## 8. Visual Specification (per DESIGN.md)

### Typography (Satoshi only, weights 300 and 400)
| Element | Size | Weight | Tracking | Scale |
|---|---|---|---|---|
| Card header title | 10px | 400 | 0.1em (1px) | Micro uppercase |
| Card header unread count | 10px | 400 | 0.1em | Micro, Accent color when > 0 |
| Row name (chat/group) | 15px | 400 | 0 | Small |
| Row preview text | 13px | 300 | 0 | Caption |
| Row timestamp | 10px | 400 | 0.04em | Micro |
| Decision score | 22px | 400 | -0.44 | Heading, Geist Mono |
| Decision title | 15px | 400 | 0 | Small |
| Empty state tagline | 17px | 400 | 0 | Body, Ink Secondary |
| Empty state CTA | 17px | 400 | -0.17 | Body, Accent color |

### Colors (DESIGN.md tokens)
- Background: `#050507` (Void)
- Row name (unread): `#F0EFF4` (Ink Primary)
- Row name (read): `rgba(240,239,244,0.55)` (Ink Secondary)
- Row preview (unread): `rgba(240,239,244,0.68)` (bumped Secondary)
- Row preview (read): `rgba(240,239,244,0.42)` (dim tertiary)
- Unread badge: `#FF6B35` (Accent) background, `#050507` text
- Hot decision score: `#E8C86A` (Gold Light)
- Warm decision score: `#FF9B6E` (Accent Light)
- Cool decision score: `#FBBF24` (Warning)
- Hairlines: `rgba(240,239,244,0.06)`

### Row layout
- Height: **64px for all three cards** (chats, groups, decisions). Decision rows were initially spec'd at 56px but bumped to 64 after density review flagged crowding risk of stacking score + title + category + separator in the smaller height. 64px matches chat/group row height for visual consistency across all three cards.
- Horizontal padding: 24px (matches existing decision_board layout)
- **Standard separator** (chats, groups, and the last decision row): 1px at 6% Ink opacity, indented past avatar/thumb
- **Decision rows special case:** the bottom separator is **replaced** by a 2px consensus bar. The bar width equals `consensusScore * rowContentWidth` (i.e., 100% = full width, 50% = half width). Color follows hot/warm/cool mapping (gold / accent / warning). The bar starts at the left padding edge (aligned with the thumbnail's left edge). This means the separator *is* the consensus bar for decision rows — zero extra vertical pixels added.

### Decision row horizontal layout (fits in 64px)
```
┌────────────────────────────────────────────────────────┐
│  [thumb]   92   Mt Batur sunrise trek                  │
│  40×40     Geist  activity · 3 of 4 voted              │
│           Mono22                                       │
├════════════════════════════════════════════════════════┤  ← 2px consensus bar (width ∝ score, color by state)
```
- Thumb: 40×40px square, 0 radius, left-aligned
- 12px gap
- Score: 22px Geist Mono, right-aligned in a 40px wide column (tabular numbers)
- 14px gap
- Title + category: stacked vertically in remaining flex space. Title 15px Satoshi 400 on top, category 10px Micro Satoshi 400 Ink Tertiary below
- Row vertical padding: 10px top + 10px bottom + 2px bar = 64px total
- Content vertical: 44px available — thumbnail fits, title+category stacks in ~35px, centered against the thumbnail/score

### Unread badge (avatar overlay)
- Circle: 18px diameter, 2px Void inset ring to separate from avatar
- Fill: Accent `#FF6B35` solid
- **Outer glow:** 6px Gaussian blur at 20% Accent opacity to soften the hard edge against the Void background and prevent the "neon vibration" at small sizes
- Numeral text: Void `#050507` (inverted for max contrast — 17:1 vs 4.7:1 for white-on-accent). This also removes the ambiguity of "white numeral on accent background" which is the WCAG-borderline case.
- Font: Geist Mono 10px weight 400
- Max displayed count: 99+ (if N > 99, render `99+`)

### Unread indicator (WhatsApp/iMessage clarity)
- **Avatar ring** — 1.5px Accent border around unread chat avatars
- **Count badge** — 18px orange pill with mono count, top-right corner of avatar, 2px Void inset ring to separate from avatar
- **Name brightness** — unread = Ink Primary, read = Ink Secondary
- Three simultaneous cues (ring + badge + brightness), same pattern across all cards

### No containers, no pills, no boxes
- Cards themselves have no visible border, no background, no drop shadow
- Card content floats directly on the Void background
- The "peek stack" visual depth comes from opacity + scale transforms only
- Hairlines between rows at 6% Ink opacity are the only separators
- No rounded rectangles on card bodies (Zero-Box doctrine, feed items = 0 radius)
- Avatars are circles (9999px) per DESIGN.md exception
- Decision thumbnails are 0 radius squares per Zero-Box

## 9. Navigation on Tap

| Tap target | Action |
|---|---|
| Chats card row | `Navigator.push(DirectMessagePage(conversationId))` |
| Groups card row | `Navigator.push(GroupChatPage(conversationId))` |
| Decisions card row | `Navigator.push(PlanDetailPage(itemId))` |
| Chats card header | `Navigator.push(FullChatsListPage())` |
| Groups card header | `Navigator.push(FullGroupsListPage())` |
| Decisions card header | `Navigator.push(FullDecisionsListPage())` |
| Empty state CTA | Open the "start" flow for that card type (compose new DM, create group, start decision) |

**Return navigation:** when the user pops back from a detail screen, the home screen is preserved in its previous state (active card, scroll position when v2 enables internal scroll).

## 10. Widget architecture

```
DecisionBoardPage (existing, rewritten)
├── AmbientMesh (existing, keep)
├── SafeArea
│   └── PeekStackPageView (new, vertical PageView with custom peek geometry)
│       ├── ChatsCard (new)
│       │   ├── CardHeader
│       │   ├── ChatRow × N   (using ConversationRow widget)
│       │   └── SeeAllRow
│       ├── GroupsCard (new)
│       │   ├── CardHeader
│       │   ├── ChatRow × N   (same ConversationRow widget, isGroup=true variant)
│       │   └── SeeAllRow
│       └── DecisionsCard (new)
│           ├── CardHeader
│           ├── DecisionRow × N
│           └── SeeAllRow
└── (no tab bar, no chat strip, no masthead)
```

### Files to create
- `lib/views/home/decision_board/peek_stack.dart` — the `PeekStackPageView` widget (reusable, takes a list of card children)
- `lib/views/home/decision_board/cards/chats_card.dart`
- `lib/views/home/decision_board/cards/groups_card.dart`
- `lib/views/home/decision_board/cards/decisions_card.dart`
- `lib/views/home/decision_board/cards/card_header.dart` — shared header widget
- `lib/views/home/decision_board/cards/conversation_row.dart` — shared row widget for DMs and groups
- `lib/views/home/decision_board/cards/decision_row.dart` — decision list row
- `lib/views/home/decision_board/cards/empty_state.dart` — shared empty state widget
- `lib/providers/conversations_provider.dart` — Riverpod provider for chat stream
- `lib/providers/decisions_provider.dart` — Riverpod provider for decision stream

### Files to modify
- `lib/views/home/decision_board/decision_board_page.dart` — rewrite to use `PeekStackPageView` with the three cards
- `lib/views/home/decision_board/models.dart` — delete entirely; mock classes replaced by engine types (`Conversation`, `DecryptedItemPayload`)
- `lib/views/home/decision_board/atmosphere.dart` — keep `AmbientMesh` only, delete `AuroraStrip` (the peek stack layout has no top strip to attach it to; the peek itself provides the atmospheric motion)

### Files to delete (no longer needed after this rewrite)
- `lib/views/home/decision_board/swim_lane_rail.dart` — swim lane pattern abandoned
- `lib/views/home/decision_board/decision_card.dart` — Netflix-style card pattern abandoned; replaced by `decision_row.dart` list row
- `lib/views/home/decision_board/world_tile.dart` — worlds tile pattern not used in peek stack

## 11. Out of Scope (YAGNI)

- **Internal card scrolling** — cards show first 10 + "See all" row; no internal scroll in v1
- **Horizontal swipe on rows** — no archive/mute/delete swipe actions in v1
- **Typing indicators** — no "Sarah is typing..." in the card preview
- **Read receipts** — not shown in preview rows
- **Message reactions** — not shown in preview rows
- **Decision consensus timer** — not shown in v1 decision rows (just static consensus %)
- **Animated message arrival** — new messages cause a provider rebuild, no slide-in animation
- **Search bar** — no search in v1
- **Filters / tags** — no filter UI in v1
- **The "chat card" size proposal from earlier** — those large standalone chat cards with 5-6 messages each are superseded by this per-row list model
- **Aurora bridge** — DESIGN.md's Aurora Bridge (gradient strip indicating plan activity inside a group chat) is a separate feature, not part of the home

## 12. Testing Strategy

### Unit tests (mock provider data)
- `peek_stack_test.dart` — PageView math, geometry calculations, hard stop behavior, rubber-band overshoot
- `conversation_row_test.dart` — unread vs read styling, timestamp format, tap callback, group vs DM variants
- `decision_row_test.dart` — consensus bar width matches score, hot/warm/cool color selection
- `card_header_test.dart` — unread count visibility, tap callback fires
- `empty_state_test.dart` — renders for zero-item case, CTA callback fires

### Widget tests
- `chats_card_test.dart` — renders N rows from mock provider, "See all" appears for N > 10, empty state when list is empty
- `groups_card_test.dart` — same
- `decisions_card_test.dart` — same
- `decision_board_page_test.dart` — 3 cards mount, initial position is card 1, swipe gesture fires card change, tap on row fires navigation, hard stop at edges

### Integration test (optional, mock engine)
- Full swipe journey through all 3 cards, tap a row, navigate back, verify state preservation

### Contrast + accessibility check
- Every text color meets WCAG AA 4.5:1 against `#050507` background (already validated by DESIGN.md tokens)
- Tap targets ≥ 44pt per row
- Supports `prefers-reduced-motion` — skip spring physics, use 150ms ease-out instead

## 13. Implementation Priority (matches user's stated order)

**Phase 1: Engine** — Get vertical snap-to-card pagination working with the 78/18 split on mock data. Single PageView, three colored placeholder cards. No content, no gestures beyond snap.

**Phase 2: Gesture Logic** — Lock in the peek stack geometry, focus dimming (opacity + scale transforms during swipe), hard stop rubber-band at edges, haptic on snap.

**Phase 3: Content** — Wire the provider layer (`conversations_provider`, `decisions_provider`), replace placeholder card bodies with real `ChatsCard` / `GroupsCard` / `DecisionsCard`, build row widgets, empty states.

**Phase 4: Integration** — Wire tap actions to real navigation routes (requires the existing `GroupChatPage` / `DirectMessagePage` to also be rewritten as real engine-consuming widgets, which is adjacent scope flagged below).

### Scope: Home-only (locked 2026-04-10)
This spec is **home screen only**. Reviewer rationale (adopted): "The Peek Stack is a foundational architectural change. If you attempt to build the detail screens simultaneously, you are effectively trying to build the engine and the car at the same time. Build the Home Screen first → get immediate visual feedback on the new interaction model → feel the physics before getting bogged down in E2EE message streams in detail views."

**In scope:**
- `PeekStackPageView` widget
- 3 card widgets (Chats, Groups, Decisions)
- `conversationsProvider`, `decisionsProvider` (live-streamed)
- `homeActiveCardIndexProvider` (state persistence)
- Empty state widgets for all 3 cards
- Navigation routes (tap row / tap header / tap CTA) — route *targets* exist as stubs; this spec wires the routes but does not rewrite the detail screens

**Explicitly out of scope (follow-up specs):**
- Rewriting `group_chat_page.dart` and `direct_message_page.dart` as real engine consumers
- Building `FullChatsListPage`, `FullGroupsListPage`, `FullDecisionsListPage`
- The detail screens will land on existing stubs after tap-through. Functional-but-unsatisfying until the follow-up spec.

## 14. Open Questions

**None.** All decisions explicit.

If any question arises during implementation, it is a bug in this spec — return here and resolve it explicitly before coding.

---

## 15. Pre-Implementation Checklist (reviewer-mandated)

Addressed inline in this spec:

| # | Item | Status | Where |
|---|---|---|---|
| 1 | Verify PageView snap physics against stiffness/damping | Spec'd | §5 — `stiffness: 400, damping: 30, mass: 1.0`, velocity threshold 500 px/s, drag commit at 30% of card height |
| 2 | Confirm DecisionRow layout fits without text overlap | Spec'd | §8 — row bumped from 56px to 64px; horizontal layout with score as left-anchor; consensus bar replaces bottom separator (zero extra vertical px) |
| 3 | Implement client-side merge for decisions as primary fallback | Spec'd | §7 — `activeDecisionsProvider` iterates `engine.conversations`, calls `getDecisionItems(groupId)` per group, merges + filters client-side. O(groups) work per refresh. |
| 4 | Prioritize gesture resolution for Pull-to-Refresh vs Pagination | **Resolved by removal** | §5 — pull-to-refresh removed from v1. Data is live-streamed via Riverpod `StreamProvider`; manual refresh is semantically unnecessary and eliminates the gesture ambiguity entirely. |

Additional implementation-phase validations:
- Test on 390×844 (iPhone 15) AND 360×780 (small Android) AND 428×926 (iPhone 15 Pro Max) to verify peek percentages produce sensible pixel heights at each aspect ratio
- Test with `prefers-reduced-motion` enabled — swap spring physics for 150ms ease-out curve
- Contrast check: run automated WCAG AA validator on every text/background color pair from §8
- Verify `AutomaticKeepAliveClientMixin` works across the app's actual navigation stack (not just a test harness)

---

**Approved 2026-04-10** with reviewer refinements incorporated:
1. ✅ Design as specified (peek stack, 78/18/4, hard stop, empty states, focus dimming)
2. ✅ Content cap: up to 10 rows + "See all" styled as a dimmed row (not a button)
3. ✅ Scope: (a) home-only — locked
4. ✅ File deletions (`swim_lane_rail.dart`, `decision_card.dart`, `world_tile.dart`, `models.dart`)
5. ✅ Decision row density fix: 64px height, horizontal score-anchored layout, consensus-bar-as-separator
6. ✅ Gesture conflict resolution: pull-to-refresh removed from v1
7. ✅ State persistence: `homeActiveCardIndexProvider` + `AutomaticKeepAliveClientMixin`
8. ✅ Unread badge contrast: Void numeral on Accent fill + 6px outer glow

**Status: ready for implementation plan.**
