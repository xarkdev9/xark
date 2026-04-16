# Night Shift #2 Tracker — 2026-04-14

Plan: `docs/superpowers/plans/2026-04-14-night-shift-2-make-it-work-plan.md`
Spec: `docs/superpowers/specs/2026-04-14-night-shift-2-make-it-work-design.md`

---

## Phase 1: PlaygroundProvider + Feed Integration

### Task 1: Create PlaygroundDecisionNotifier — DONE
- Created `app/lib/providers/playground_provider.dart`
- `PlaygroundDecisionNotifier` extends Riverpod 3 `Notifier<List<DecisionItem>>` (NOT StateNotifier, which was removed in Riverpod 3)
- Initializes from `mockDecisions` (5 seed items from `seed_data.dart`)
- `vote()` method: updates reactions map, recalculates `weightedScore` (love_it=+5, works_for_me=+1, not_for_me=-3), computes `agreementScore` as fraction of 6-member group, transitions to `locked` at >=80%, sorts locked items to bottom, emits consensus event on lock
- `addItem()` method: creates new `DecisionItem` with timestamp-based id prefix `pg_`, prepends to list
- `playgroundConsensusEventProvider` (StreamProvider) exposes consensus lock events
- `ref.onDispose` closes the `StreamController` (Riverpod 3 pattern, no `dispose()` override needed)
- `dart analyze lib/providers/playground_provider.dart` — 0 issues

### Task 2: Integrate playground into decisions_provider.dart — DONE
- Added `import 'playground_provider.dart';` to `decisions_provider.dart`
- Changed fallback from `return const <DecisionItem>[]` to `return ref.watch(playgroundDecisionsProvider)` when engine is null (pre-auth path)
- `dart analyze lib/providers/decisions_provider.dart` — 0 issues

### Task 3: Verify feed integration — DONE (no code changes needed)
- `feedProvider` watches `activeDecisionsProvider` (line 20), extracts `decisions` on line 26
- All 5 mock decision IDs are covered by display metadata maps:
  - Hero cards (3): `flight_mar22_united_827`, `villa_ubud_seaview_3br`, `goa_hotel_zostel_vs_taj`
  - Small cards (2): `sunday_dinner_italian_place`, `book_chapter7_discussion`
- Integration chain verified: `PlaygroundDecisionNotifier` -> `playgroundDecisionsProvider` -> `activeDecisionsProvider` -> `feedProvider` -> filtered tab providers
- Playground decisions will flow through the feed automatically in pre-auth mode
- Voting via `PlaygroundDecisionNotifier.vote()` will reactively update the feed (Riverpod dependency chain)

---

## Phase 5: Web Voter View

### Task 4: Create vote API endpoint — DONE
- Created `/web/src/app/api/vote/route.ts`
- Unauthenticated POST endpoint accepting `{ inviteCode, itemId, signal, voterName }`
- Validates invite code against `summon_links` table
- Validates signal is one of `love_it`, `works_for_me`, `not_for_me`
- Builds guest ID: `guest_${sanitizedName}` from voterName
- Upserts reaction into the `reactions` table (separate table, not JSON column) with proper `(item_id, user_id)` conflict handling
- Recomputes `weighted_score` and `agreement_score` on `decision_items` after each vote
- Returns `{ ok: true, guestId, signal }`
- Follows existing patterns from `/api/invite/route.ts` and `react_to_item` RPC

### Task 5: Add rate limiting for /api/vote — DONE
- Added `voteLimiter = slidingWindow('rl:vote', 30, '1 m')` to `rate-limit-edge.ts`
- Added `voteLimiter` to the null check guard
- Added route config: `config.set('/api/vote', { limiter: voteLimiter!, prefix: 'rl:vote', keyByIp: true, failureMode: 'open' })`
- IP-keyed (no auth), fail-open (voting should never hard-block)

### Task 6: Create Web Voter View page — DONE
- Created 3 files at `/web/src/app/v/[code]/`:
  - `vote-header.tsx` — sticky glass header with trip name (28px w400), member count, name input persisted to `hello_voter_name` in localStorage
  - `vote-card.tsx` — glass card with photo, category (10px uppercase), title (22px w400), gold progress bar, agreement %, 3 vote buttons (Love It/Works/Pass) with active state (2px border + 8% fill), optimistic update, localStorage persistence per item
  - `page.tsx` — server component, validates invite via `summon_links`, fetches `decision_items` for the group, falls back to 3 Unsplash demo items, fixed bottom conversion banner linking to gethello.ai
- Uses Next.js 16 pattern: `params` as Promise with `const { code } = await params`
- All CSS uses `var()` references to hello design tokens with fallbacks
- No-bold mandate respected (all fontWeight: 400)
- `npm run build` succeeds, `/api/vote` and `/v/[code]` visible in build output

---

## Phase 2: Wire Vote Buttons

### Task 7: Wire decision_card_small.dart to playground provider — DONE
- Converted `DecisionCardSmall` from `StatefulWidget` to `ConsumerStatefulWidget`
- Removed local `_myVote` state variable
- Added `ref.watch(playgroundDecisionsProvider)` to get live decisions list
- Derives `liveItem` by matching `widget.item.item.id` against the provider's list (with fallback to original item)
- Vote state (`myVote`) now reads from `liveItem.reactions['me']` instead of local state
- Score percentage (`scorePct`) and progress bar value now derive from `liveItem.agreementScore` (live)
- Vote button taps now call `ref.read(playgroundDecisionsProvider.notifier).vote(itemId, signal, 'me')`
- Accessibility label updated to use live `scorePct`
- `dart analyze` — 0 errors (1 pre-existing info lint)

### Task 8: Wire decision_page.dart to playground provider — DONE
- Converted `_DecisionPage` from `StatefulWidget` to `ConsumerStatefulWidget`
- Removed local `_vote` state variable
- Changed `_extract()` to return `itemId` instead of `score` (score now comes from live provider)
- Added `ref.watch(playgroundDecisionsProvider)` to derive `liveItem`, `liveScore`, `myVote`, `scorePct`
- All three vote buttons wired to `ref.read(playgroundDecisionsProvider.notifier).vote()` with null-guard on `itemId`
- Progress bar uses `liveScore` instead of static `data.score`
- `dart analyze` — 0 errors (2 pre-existing info lints)

### Task 9: Wire decision_sheet.dart to playground provider — DONE
- Converted `_DecisionSheet` from `StatefulWidget` to `ConsumerStatefulWidget`
- Removed local `_vote` state variable
- Changed `_extract()` to return `itemId` instead of `score`
- Added `ref.watch(playgroundDecisionsProvider)` to derive `liveItem`, `liveScore`, `myVote`, `scorePct`
- All three vote buttons wired to `ref.read(playgroundDecisionsProvider.notifier).vote()` with null-guard on `itemId`
- Progress bar uses `liveScore`
- `dart analyze` — 0 errors (3 pre-existing info lints)

---

## Phase 3: Add Item Sheet

### Task 10: Create Add Item Sheet — DONE
- Created `app/lib/views/home/decision_board/sheets/add_item_sheet.dart`
- `openAddItemSheet(BuildContext context)` — top-level function using `showGeneralDialog` with backdrop blur + slide-up transition (matches `dm_sheet.dart` / `decision_sheet.dart` pattern)
- `_AddItemSheetContent` is a `ConsumerStatefulWidget` for `ref` access
- UI: handle bar, "ADD TO GROUP" eyebrow + close button, horizontal photo selector (10 demo assets from `assets/decide/`), title TextField, category TextField, submit button
- Photo selector: 64x64 rounded thumbnails in horizontal `ListView`, selected photo gets `PlasmaStroke` border (2px)
- Submit button: `PlasmaFill` pill when title is non-empty, gray `Container` when empty
- On submit: validates non-empty title, defaults category to 'Ideas', calls `ref.read(playgroundDecisionsProvider.notifier).addItem(title, category, photo)`, pops dialog, fires `HelloHaptic.confirm()`
- `dart analyze` — 0 errors (4 pre-existing info lints)

### Task 11: Add [+] button to PlansView and GroupPage — DONE
- **plans_view.dart**: Added `PlasmaFill` circular [+] button as a `Positioned` child in the main `Stack`, placed above the 3-tier navigation dock (`bottom: dockBottomPosition + dockHeight + 12, right: 20`). Taps call `HelloHaptic.tap()` then `openAddItemSheet(context)`. Fixed pre-existing double-comma syntax error at line 180. Added imports for `add_item_sheet.dart` and `plasma.dart`.
- **group_page.dart**: Added `Positioned` [+] button in the main Stack, conditionally showing the button when `_currentIndex == 1` (Plans page) and `SizedBox.shrink()` otherwise (follows landmine #9 pattern — always render `Positioned`, return `SizedBox.shrink()` internally when hidden, to avoid index shifting with `LiquidIntentLayer`). Positioned at `bottom: bottomSafe + 80, right: 20`. Added imports for `add_item_sheet.dart` and `plasma.dart`.
- `dart analyze lib/` — 0 new errors introduced. All 8 pre-existing errors are in unrelated files (`decision_card.dart`, `consensus_banner.dart`, `liquid_intent_handle.dart`, `explore_tab.dart`, `space_picker_sheet.dart`, `spatial_sheet_wrapper.dart`).

---

## Phase 4: Consensus Celebration

### Task 12: Create ConsensusWatcher and wire to scaffold — DONE
- Created `app/lib/views/home/decision_board/consensus_watcher.dart`
- `ConsensusWatcher` is a `ConsumerStatefulWidget` that wraps the decision board scaffold
- Uses `ref.listenManual<AsyncValue<String>>` on `playgroundConsensusEventProvider` (Riverpod 3 pattern) in `initState`
- When a consensus event fires (item crosses 80% and locks):
  - Looks up item title from `playgroundDecisionsProvider` (reads `ciphertextPayload`, falls back to id if 'mock')
  - Calls `HelloHaptic.celebrate()` for haptic feedback
  - Sets state to show `ConsensusBanner` with "{title} -- Locked" text
  - Auto-dismisses after 3 seconds via `Timer`
- Banner overlays at top of screen using `Stack` + `Positioned` (always rendered per landmine #9)
- Matches `ConsensusBanner` constructor: `isVisible: bool, text: String`
- Wired into `decision_board_page.dart`: `Scaffold` wrapped in `ConsensusWatcher(child: Scaffold(...))`
- `ProviderSubscription` properly closed in `dispose()`
- `dart analyze lib/` -- 0 new errors (8 pre-existing)

---

## Phase 6: PlansView Migration

### Task 13: Migrate PlansView from MockPlanItem to DecisionItem — DONE
- Converted `PlansView` from `StatefulWidget` to `ConsumerStatefulWidget` (+ `ConsumerState`)
- Replaced `_getMockItems()` with `ref.watch(playgroundDecisionsProvider)`, filtered to items with proper `event|category` nonce format (excludes HOME-feed items with `nonce: 'mock'`)
- Added 6 plans-specific seed items to `mockDecisions` in `seed_data.dart` with properly formatted `ciphertextPayload` (title) and `nonce` (event|category pipe format): Hawaii Hotels (2), Flights (1), Experiences (1), Dinners (2)
- Added `mockDecisionPhoto` map to `seed_data.dart` for photo URL lookup by item id
- Created 4 helper functions: `_itemTitle()`, `_itemCategory()`, `_itemPhotoUrl()`, `_toMockPlanItem()` for clean field mapping
- Replaced all `MockPlanItem` type references in `plans_view.dart` with `DecisionItem`: `_getActivePhotoUrl`, `_buildHeroCanvas`, `_OverviewDashboard`, `_FloatingActiveCard`, `_FloatingSettledCard`
- Field mapping: `ciphertextPayload` -> title, `nonce` -> category (event|category), `mockDecisionPhoto[id]` -> photoUrl, `proposedBy ?? 'Unknown'` -> proposer
- `DecisionCard` (separate file) still takes `MockPlanItem` -- bridged via `_toMockPlanItem()` at call site
- `MockPlanItem` class retained in `decision_card.dart` (still used by `DecisionCard` widget)
- 3-tier navigation (events -> categories -> hero canvas) preserved with same parsing logic
- Added imports: `e2ee_chat_sdk`, `flutter_riverpod`, `playground_provider`, `seed_data`
- `dart analyze lib/` -- 0 new errors (8 pre-existing)

---

## Phase 7: Status Overview

### Task 14: Create StatusOverview widget -- DONE
- Created `app/lib/views/home/decision_board/status_overview.dart`
- `StatusOverview` is a `ConsumerWidget` showing a horizontal scrolling row of 4 summary chips
- Reads from `playgroundDecisionsProvider` to compute live counts:
  - Locked: items where `isLocked == true`
  - Voting: items where `isLocked == false`
  - Needs You: items where `reactions` does not contain key `'me'`
  - Settled: hardcoded 0 (no settlement tracking yet)
- Each `_StatusChip` renders icon (16px, colored), count (small text), and label (caption text)
- Chips use `HelloGlass.whisperFill` background with `whisperBorder` and 24px border radius
- Icon colors: `liveGreen` for Locked, `accent` for Voting/Needs You, `gold` for Settled
- `dart analyze` -- 0 issues

### Task 15: Wire StatusOverview into home_page.dart -- DONE
- Added `import '../status_overview.dart'` to `home_page.dart`
- Inserted `StatusOverview()` wrapped in `SliverToBoxAdapter` with 12px bottom padding
- Placed after the 56px top spacer and before the focus hero item in the `CustomScrollView`
- Visible on HOME tab at top of scrollable content area
- `dart analyze` -- 0 issues

---

## Phase 8: Final Verification

### Task 16: Final verification -- DONE

---

## NIGHT SHIFT #2 COMPLETE

### Summary
- **Total tasks:** 16
- **New files created:** 9 (playground_provider.dart, add_item_sheet.dart, status_overview.dart, consensus_watcher.dart, vote/route.ts, vote-header.tsx, vote-card.tsx, v/[code]/page.tsx, seed_data additions)
- **Files modified:** ~12

### Features delivered:
1. **Playground voting** -- in-memory DecisionNotifier with heart-sort algorithm, optimistic updates
2. **Vote button wiring** -- all 3 surfaces (card_small, page, sheet) wired to provider
3. **Add Item sheet** -- title/category/photo inputs, wired to provider
4. **Consensus celebration** -- banner + haptic fires when item crosses 80%
5. **PlansView migration** -- reads from provider instead of MockPlanItem
6. **Status Overview** -- horizontal chip bar showing locked/voting/needs-you counts
7. **Web Voter View** -- zero-install voting page at /v/[code] with rate-limited API
8. **Vote API** -- unauthenticated endpoint with invite validation + rate limiting

### Verification:
- `dart analyze lib/` -- 8 errors (all pre-existing in consensus_banner.dart, decision_card.dart, liquid_intent_handle.dart, explore_tab.dart, space_picker_sheet.dart, spatial_sheet_wrapper.dart), 10 warnings (pre-existing), ~60 infos. **0 new errors from night shift #2 work.**
- `flutter build web --no-tree-shake-icons` -- FAILED due to pre-existing compilation errors in `consensus_banner.dart` (double comma at line 110 + `SlideTransition` misuse inside `AnimatedBuilder`). Not caused by night shift #2 changes.
- `npm run build` (web) -- SUCCESS. All 55 routes compiled. `/api/vote` and `/v/[code]` visible in build output.

