# Night Shift #2: Make It Work + Make It Shareable — Spec

**Date:** 2026-04-14 (second shift)
**Scope:** 8-phase overhaul across Flutter + Web — playground voting, add item, consensus celebration, status overview, PlansView migration, feed integration, Web Voter View
**Input:** `todof.md` Phase 1 + Steve/Elon feedback on "lazy friend" friction
**Outcome:** A user can vote on decision items, add new items, see consensus celebrations, view live status — all working in playground mode without a backend. AND: a non-app-user can vote via a web link without downloading the app.

---

## Ground Truth (verified 2026-04-14)

**Exists and working:**
- `seed_data.dart`: 5 DecisionItems, 3 Trips, 2 Settlements, 9 Conversations, all with realistic data
- `consensus_banner.dart` (116 lines): fully animated slide-down banner, wired to AnimationController, ready for trigger
- `liquid_fire_consensus_burst.dart` (105 lines): fully animated radial glow + scale, calls HelloHaptic.celebrate(), ready for trigger
- `decision_card_small.dart`, `decision_page.dart`, `decision_sheet.dart`: all have vote UI, all use local setState only
- `ChatEngineDecisions` mixin: `reactToItem(itemId, signal)`, `addDecisionItem(groupId, ciphertext, nonce)`, `encryptPayload(groupId, plaintext)`, `getDecisionItems(groupId)`, `lockItem(itemId, proof)`, `decryptPayload(groupId, cipher, nonce)`
- `heart-sort.ts` (web): `addReaction()`, `removeReaction()`, `calculateWeightedScore()`, `calculateAgreementScore()`, `heartSort()` — SSOT with 232 passing tests
- `/api/invite`: generates 128-bit hex invite codes, stored in `summon_links` table
- `/api/invite/validate`: returns creator name for a code (public, no auth)
- `globals.css`: CSS tokens `--hello-amber` (LoveIt), `--hello-gray` (WorksForMe), `--hello-orange` (NotForMe), `--hello-gold` (locked)
- `proxy.ts`: edge rate limiting infrastructure ready for new routes

**Does not exist (this spec builds):**
- PlaygroundDecisionNotifier (in-memory voting provider)
- Add Item sheet in current app
- Consensus event wiring (banner/burst to voting state)
- Status Overview widget
- PlansView reading from provider (currently uses MockPlanItem)
- Feed integration for playground decisions
- Web Voter View page
- Web Vote API endpoint

---

## Architecture: Playground Mode

A `StateNotifier<List<DecisionItem>>` holds decision items in memory. Initialized from seed_data.dart. Provides:

- `vote(itemId, signal, userId)` — updates the item's reaction map, recalculates weightedScore and agreementScore using the same algorithm as heart-sort.ts
- `addItem(title, category, photoUrl)` — creates a new DecisionItem with generated ID, state 'proposed', empty reactions
- `items` — the current list
- `consensusEvents` — emits itemId when agreementScore crosses 0.8

**Engine vs Playground resolution:**

`decisions_provider.dart` already has `activeDecisionsProvider` which calls `engineOrNull(ref)`. When engine is null (pre-auth), it returns empty. The new logic:

```
activeDecisionsProvider:
  if engine != null AND engine is ChatEngineDecisions → use engine (live mode)
  else → read from playgroundDecisionsProvider (playground mode)
```

This means:
- Post-auth with backend: real engine data, playground ignored
- Pre-auth / demo: playground data, fully interactive voting
- No flag. No toggle. Automatic based on engine availability.

**Vote algorithm (Dart port of heart-sort.ts):**

```dart
void vote(String itemId, String signal, String userId) {
  final items = [...state];
  final idx = items.indexWhere((i) => i.id == itemId);
  if (idx == -1) return;

  final item = items[idx];
  final reactions = Map<String, String>.from(item.reactions);
  
  // One reaction per user. Last wins.
  reactions[userId] = signal;
  
  // Weighted score: LoveIt +5, WorksForMe +1, NotForMe -3
  double weightedScore = 0;
  for (final r in reactions.values) {
    weightedScore += switch (r) {
      'love_it' => 5,
      'works_for_me' => 1,
      'not_for_me' => -3,
      _ => 0,
    };
  }
  
  // Agreement score: unique reactors / total group members
  // All 3 reaction types count (per CLAUDE.md signal system rules)
  final totalMembers = 6; // seed data group size
  final agreementScore = reactions.length / totalMembers;
  
  // State transition at 80%
  final newState = agreementScore >= 0.8 ? 'locked' : item.state;
  final wasLocked = item.state == 'locked';
  
  items[idx] = item.copyWith(
    reactions: reactions,
    weightedScore: weightedScore,
    agreementScore: agreementScore,
    state: newState,
  );
  
  // Sort: locked items sink, then by weightedScore desc
  items.sort((a, b) {
    if (a.state == 'locked' && b.state != 'locked') return 1;
    if (b.state == 'locked' && a.state != 'locked') return -1;
    return b.weightedScore.compareTo(a.weightedScore);
  });
  
  state = items;
  
  // Fire consensus event if item just crossed 80%
  if (!wasLocked && newState == 'locked') {
    _consensusController.add(itemId);
  }
}
```

**The userId for playground:** Hardcoded `'me'`. Seed data reactions use `'sarah'`, `'alex'`, `'maya'`, etc. Vote math works correctly.

---

## Phase 1: PlaygroundProvider + Feed Integration

### Task 1.1 — Create PlaygroundDecisionNotifier

**New file: `app/lib/providers/playground_provider.dart`**

Contains:
- `PlaygroundDecisionNotifier extends StateNotifier<List<DecisionItem>>`
- Constructor initializes from `mockDecisions` in seed_data.dart
- `vote(String itemId, String signal, String userId)` — algorithm above
- `addItem(String title, String category, String photoUrl)` — creates new DecisionItem
- `Stream<String> get consensusEvents` — broadcasts itemId on 80% crossing
- `playgroundDecisionsProvider = StateNotifierProvider<PlaygroundDecisionNotifier, List<DecisionItem>>`
- `playgroundConsensusEventProvider = StreamProvider<String>` — wraps the consensus stream

### Task 1.2 — Integrate into decisions_provider.dart

**Modify: `app/lib/providers/decisions_provider.dart`**

Current `activeDecisionsProvider` calls `engineOrNull(ref)` and returns empty when null. Change fallback: when engine is null, read from `playgroundDecisionsProvider` instead of returning empty.

### Task 1.3 — Integrate into feed_provider.dart

**Modify: `app/lib/providers/feed_provider.dart`**

The feed currently reads decisions from `activeDecisionsProvider`. After Task 1.2, this automatically picks up playground decisions. Verify the mapping from `DecisionItem` to `DecisionHeroFeedItem`/`DecisionSmallFeedItem` works with playground items.

The current mapping uses `mockDecisionHero` and `mockDecisionSmall` maps from seed_data.dart — these map item IDs to display metadata (photo, live tag, eyebrow). The playground items use the same IDs from seed data, so the mapping works without changes.

### Phase 1 verification
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

---

## Phase 2: Wire Vote Buttons

### Task 2.1 — Wire decision_card_small.dart

**Modify: `app/lib/views/home/decision_board/cards/decision_card_small.dart`**

Current: `_myVote` is local setState. Vote buttons call `setState(() => _myVote = 'love_it')`.

Change:
1. Remove local `_myVote` state
2. The card receives a `DecisionSmallFeedItem` which has `item.item` (the DecisionItem). Read the current user's vote from `item.item.reactions['me']`.
3. On vote tap: `ref.read(playgroundDecisionsProvider.notifier).vote(itemId, signal, 'me')`
4. The provider emits updated state → `activeDecisionsProvider` updates → `feedProvider` updates → the card rebuilds with new data
5. Agreement score and progress bar read from the live DecisionItem, not a static value

### Task 2.2 — Wire decision_page.dart

**Modify: `app/lib/views/home/decision_board/pages/decision_page.dart`**

Same pattern as Task 2.1. Remove local `_vote` state. Read vote state from the DecisionItem's reactions. On vote: `ref.read(playgroundDecisionsProvider.notifier).vote(itemId, signal, 'me')`.

### Task 2.3 — Wire decision_sheet.dart

**Modify: `app/lib/views/home/decision_board/sheets/decision_sheet.dart`**

Same pattern. Remove local `_vote`. Wire to provider.

### Phase 2 verification
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```
Manual test: tap a vote button on a decision card → agreement score updates → progress bar moves → card re-sorts in the feed.

---

## Phase 3: Add Item Sheet

### Task 3.1 — Create AddItemSheet

**New file: `app/lib/views/home/decision_board/sheets/add_item_sheet.dart`**

Reference: Gen 3 `ui_backup_2026-04-10/flutter/demov2/add_item_sheet.dart` (193 lines).

Structure:
- `showGeneralDialog` wrapper function: `openAddItemSheet(BuildContext context)`
- Title `TextField` (required)
- Category `TextField` (required)
- Photo selector: 6 asset images from `assets/decide/` displayed in a horizontal strip. Tap to select. Selected image has a PlasmaStroke border.
- Submit button: `PlasmaFill` pill with "Add to Group". On tap:
  - Validates title + category are non-empty
  - `HelloHaptic.confirm()`
  - Calls `ref.read(playgroundDecisionsProvider.notifier).addItem(title, category, photoUrl)`
  - Closes the sheet
- When engine is live: submit calls `engine.encryptPayload(groupId, jsonPayload)` then `engine.addDecisionItem(groupId, ciphertext, nonce)` instead of the playground path

### Task 3.2 — Add [+] button to Plans view

**Modify: `app/lib/views/home/decision_board/pages/plans_view.dart`**

Add a floating [+] button (PlasmaFill circle, 48px, bottom-right positioned) that calls `openAddItemSheet(context)`. The button uses `HelloHaptic.tap()` on press.

Also add it to `group_page.dart` — when on the Plans page of the dual-pane swipe, the [+] is visible.

### Phase 3 verification
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```
Manual test: tap [+] → fill title "Park Hyatt Zurich" + category "Hotels" + select photo → submit → new item appears in the feed with 0% agreement.

---

## Phase 4: Consensus Celebration

### Task 4.1 — Create ConsensusWatcher

**New file: `app/lib/views/home/decision_board/consensus_watcher.dart`**

A `ConsumerWidget` that wraps the decision board scaffold. It listens to `playgroundConsensusEventProvider` and triggers the celebration:

```dart
ref.listen(playgroundConsensusEventProvider, (_, asyncItemId) {
  asyncItemId.whenData((itemId) {
    if (itemId == null) return;
    // Find the item title from the decisions list
    final items = ref.read(playgroundDecisionsProvider);
    final item = items.firstWhere((i) => i.id == itemId, orElse: () => null);
    if (item == null) return;
    
    // Show consensus banner (slide down from top, 3 second auto-dismiss)
    _showConsensusBanner(context, item.title);
    
    // Fire haptic
    HelloHaptic.celebrate();
  });
});
```

The banner uses the existing `ConsensusBanner` widget. It overlays at the top of the scaffold via an `OverlayEntry` or a `Stack` positioning.

### Task 4.2 — Wire into decision_board_page.dart

**Modify: `app/lib/views/home/decision_board/decision_board_page.dart`**

Wrap the scaffold content with `ConsensusWatcher`. The watcher is transparent — it adds no visual weight until a consensus event fires.

### Phase 4 verification
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```
Manual test: vote "Love It" on an item that's at 60% agreement (needs 2 more votes to reach 80% with 6 members). If the playground has an item with 4/6 votes already, voting tips it → banner slides down, haptic fires.

---

## Phase 5: Web Voter View

### Task 5.1 — Create vote API endpoint

**New file: `web/src/app/api/vote/route.ts`**

```typescript
// POST /api/vote
// Accepts unauthenticated votes from invite link holders.
// Body: { inviteCode: string, itemId: string, signal: string, voterName: string }

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { inviteCode, itemId, signal, voterName } = body;

  // Validate required fields
  if (!inviteCode || !itemId || !signal || !voterName) {
    return NextResponse.json({ error: "missing fields" }, { status: 400 });
  }

  // Validate signal
  if (!["love_it", "works_for_me", "not_for_me"].includes(signal)) {
    return NextResponse.json({ error: "invalid signal" }, { status: 400 });
  }

  // Validate invite code → get group_id
  const { data: invite, error: invErr } = await supabaseAdmin
    .from("summon_links")
    .select("creator_id")
    .eq("code", inviteCode)
    .maybeSingle();

  if (invErr || !invite) {
    return NextResponse.json({ error: "invalid invite" }, { status: 404 });
  }

  // Verify item belongs to a group this invite can access
  // (For v1: trust that the invite code holder should be able to vote on items
  //  shown on the page. The page only shows items for the invite's group.)

  // Upsert reaction: guest_{voterName} as the reactor ID
  const guestId = `guest_${voterName.toLowerCase().replace(/\s+/g, '_')}`;
  const { data, error } = await supabaseAdmin
    .from("reactions")
    .upsert({
      item_id: itemId,
      user_id: guestId,
      signal: signal,
      updated_at: new Date().toISOString(),
    }, { onConflict: "item_id,user_id" })
    .select()
    .single();

  if (error) {
    console.error("[vote] upsert failed:", error.message);
    return NextResponse.json({ error: "vote failed" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, reaction: data });
}
```

Note: The exact Supabase table schema for reactions may differ. The agent must read the actual schema (check `engine/` migrations or Supabase types) and adapt the insert. The concept is: upsert a reaction row keyed by (item_id, user_id).

### Task 5.2 — Add rate limiting for /api/vote

**Modify: `web/src/proxy.ts`**

Add to the `ROUTE_RATE_CONFIG` map:
```typescript
["/api/vote", { 
  type: "sliding_window",
  limit: 30,
  window: 60,  // 30 votes per minute
  failureMode: "fail_open",
  keyByIp: true  // No auth — key by IP
}]
```

### Task 5.3 — Create the vote page

**New file: `web/src/app/v/[code]/page.tsx`**

Server component. On load:
1. Extract `code` from params
2. Call `/api/invite/validate` internally (or query Supabase directly) to validate the code and get the group
3. Fetch decision items for the group from Supabase
4. Render the page with `VoteHeader` + list of `VoteCard` components

```tsx
// Server component — fetches data, passes to client components
export default async function VotePage({ params }: { params: { code: string } }) {
  const { code } = params;
  
  // Validate invite
  const invite = await validateInvite(code);
  if (!invite) return <NotFound />;
  
  // Fetch decision items for this group
  const items = await fetchGroupDecisions(invite.groupId);
  
  return (
    <main className="min-h-screen" style={{ background: 'var(--hello-void)' }}>
      <VoteHeader tripName={invite.groupName} memberCount={invite.memberCount} />
      <div className="px-4 py-6 space-y-4">
        {items.map(item => (
          <VoteCard key={item.id} item={item} inviteCode={code} />
        ))}
      </div>
      <ConversionBanner />
    </main>
  );
}
```

### Task 5.4 — Create VoteHeader component

**New file: `web/src/app/v/[code]/vote-header.tsx`**

Client component with:
- Trip/group name (HelloText title equivalent — Inter 28px w400)
- Member count badge
- Voter name input: "What's your name?" text field. Stored in localStorage so returning voters don't re-enter. This name is sent with every vote as `voterName`.
- Light glass background (backdrop-filter: blur(14px) — Whisper tier)

### Task 5.5 — Create VoteCard component

**New file: `web/src/app/v/[code]/vote-card.tsx`**

Client component. Each card shows:
- Photo (if available — Image with fallback)
- Title + category badge
- Current agreement score (percentage + progress bar)
- 3 vote buttons: Love It (amber), Works For Me (gray), Not For Me (orange)
- Active state: selected button has the CSS `liquid-brand-text` animation (plasma sweep already in globals.css as `@keyframes helloLiquidFire`)
- On tap: POST `/api/vote` with { inviteCode, itemId, signal, voterName }
- Optimistic update: button highlights immediately, score updates after response
- Glass card surface (backdrop-filter: blur(14px), white 70% fill — Whisper tier via CSS)

Design constraints:
- Mobile-first (opened from iMessage/WhatsApp on a phone)
- Inter font via Google Fonts CDN (`<link>` in layout or page head)
- No-bold mandate: w400 max
- Responsive: single column, full-width cards

### Task 5.6 — Create ConversionBanner component

A sticky bottom banner that appears after the user has voted on at least 1 item:

"You voted on N items. Want the full trip experience? [Get hello →]"

Links to App Store / Play Store (detect platform via user agent, fallback to app store page).

### Phase 5 verification
```bash
cd /Users/ramchitturi/hello/web && npm run build
```
Must compile. The page at `/v/[code]` must render with test data.

---

## Phase 6: PlansView Migration

### Task 6.1 — Replace MockPlanItem with DecisionItem

**Modify: `app/lib/views/home/decision_board/pages/plans_view.dart`**

Current: uses `_getMockItems()` returning hardcoded `MockPlanItem` objects.

Change:
1. Replace `MockPlanItem` usage with `DecisionItem` from the provider
2. `PlansView` becomes a `ConsumerStatefulWidget` (if not already)
3. Read items from `ref.watch(playgroundDecisionsProvider)` (or `activeDecisionsProvider`)
4. The 3-tier navigation (events → categories → items) reads category from `DecisionItem.category`
5. Vote buttons inside plans_view card overlays call `ref.read(playgroundDecisionsProvider.notifier).vote()`
6. Delete `MockPlanItem` class and `_getMockItems()` function

### Phase 6 verification
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

---

## Phase 7: Status Overview Widget

### Task 7.1 — Create StatusOverview

**New file: `app/lib/views/home/decision_board/status_overview.dart`**

A horizontal scroll of 4 summary chips, each showing a count and label:

1. **Locked** (green checkmark icon) — count of items where `state == 'locked'`
2. **Voting** (plasma-tinted) — count of items where `state != 'locked'`
3. **Needs You** (accent dot) — count of items where `reactions['me'] == null`
4. **Settled** (gold) — settlement summary from `settlementsProvider`

Each chip is tappable — scrolls or filters to show those items.

Reads from `playgroundDecisionsProvider` (or `activeDecisionsProvider`).

Layout: `SizedBox(height: 56)` containing a `ListView(scrollDirection: Axis.horizontal)` of `_StatusChip` widgets. Each chip: `Container` with `HelloGlass.whisperFill` background, `BorderRadius.circular(28)`, icon + count + label.

### Task 7.2 — Wire into home_page.dart

**Modify: `app/lib/views/home/decision_board/pages/home_page.dart`**

Add `StatusOverview` above the main feed content. It sits between the `TabHeader` area and the masonry grid / dock.

### Phase 7 verification
```bash
cd /Users/ramchitturi/hello/app && dart analyze lib/
```

---

## Phase 8: Final Verification

### Task 8.1 — Full verification battery

```bash
# Flutter
cd /Users/ramchitturi/hello/app && dart analyze lib/
cd /Users/ramchitturi/hello/app && flutter build web --no-tree-shake-icons --no-wasm-dry-run

# Web
cd /Users/ramchitturi/hello/web && npm run build
```

### Task 8.2 — Update nightshifttracker.md with Night Shift #2 summary

---

## Execution Architecture

```
WAVE A (concurrent — Flutter and Web are independent codebases):
  Phase 1: PlaygroundProvider + Feed Integration (Flutter)     → Tasks 1.1-1.3
  Phase 5: Web Voter View (Web/Next.js)                       → Tasks 5.1-5.6

WAVE B (sequential — depends on Phase 1 provider):
  Phase 2: Wire Vote Buttons (Flutter)                        → Tasks 2.1-2.3
  Phase 3: Add Item Sheet (Flutter)                           → Tasks 3.1-3.2

WAVE C (sequential — depends on Phase 2 voting):
  Phase 4: Consensus Celebration (Flutter)                    → Tasks 4.1-4.2
  Phase 6: PlansView Migration (Flutter)                      → Task 6.1

WAVE D (sequential — depends on everything):
  Phase 7: Status Overview (Flutter)                          → Tasks 7.1-7.2
  Phase 8: Final Verification                                 → Tasks 8.1-8.2
```

**4 waves. 8 phases. ~20 tasks. Wave A runs 2 concurrent agents (Flutter + Web).**

---

## New Files (9)

```
Flutter (5):
  app/lib/providers/playground_provider.dart
  app/lib/views/home/decision_board/sheets/add_item_sheet.dart
  app/lib/views/home/decision_board/status_overview.dart
  app/lib/views/home/decision_board/consensus_watcher.dart

Web (4):
  web/src/app/v/[code]/page.tsx
  web/src/app/v/[code]/vote-card.tsx
  web/src/app/v/[code]/vote-header.tsx
  web/src/app/api/vote/route.ts
```

## Modified Files (~10)

```
Flutter:
  app/lib/providers/decisions_provider.dart (playground fallback)
  app/lib/providers/feed_provider.dart (verify integration)
  app/lib/views/home/decision_board/cards/decision_card_small.dart (wire to provider)
  app/lib/views/home/decision_board/pages/decision_page.dart (wire to provider)
  app/lib/views/home/decision_board/sheets/decision_sheet.dart (wire to provider)
  app/lib/views/home/decision_board/pages/plans_view.dart (migrate + [+] button)
  app/lib/views/home/decision_board/pages/group_page.dart ([+] button)
  app/lib/views/home/decision_board/pages/home_page.dart (StatusOverview)
  app/lib/views/home/decision_board/decision_board_page.dart (ConsensusWatcher)

Web:
  web/src/proxy.ts (rate limit for /api/vote)
```

---

## Success Criteria

1. `dart analyze lib/` — zero new errors
2. `flutter build web` — compiles
3. `npm run build` (web) — compiles
4. Voting on a decision card updates the score and progress bar immediately
5. Adding an item via [+] sheet makes it appear in the feed
6. Tipping consensus (80%) triggers banner + burst + haptic
7. StatusOverview shows correct counts for locked/voting/needs-you
8. `/v/[code]` web page renders decision items with vote buttons
9. Voting on the web page posts to `/api/vote` successfully
10. `nightshifttracker.md` has entries for all tasks
