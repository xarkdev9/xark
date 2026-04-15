# Cosmos Home — Floating Avatars + Text Actions

**Date:** 2026-04-14
**Status:** Design ratified. Technical review (2026-04-14 evening) applied as six architectural patches. v2 — this supersedes the v1 saved earlier today.
**Predecessor spec:** `2026-04-14-chromatic-atmosphere-design.md`

---

## Problem statement

Home (post-Night-Shift #3) is a 2-column masonry grid of `DecisionCardSmall` cards under a row of status-count pills (`StatusOverview`), with a 60pt bottom search pill (`BottomBar`) that duplicates the purpose of `liquid_intent_handle.dart`. Opening Home at 7am means parsing 8-9 micro-decisions + 4 count pills + a search-bar read before anything registers. That reads as work, not life.

The "one avatar at a time" design the user built on 2026-04-13 (`cosmos_home_page.dart.disabled`, `live_avatar.dart.disabled`) got shelved during Night Shift #3 without review — the agents writing Chromatic Atmosphere never opened the `.disabled` file.

**Goal:** rebuild Home as a *floating-people* surface — clarity in 5-10 seconds, zero obligation framing, no containers, no counts. Resurrect the cosmos intent and refine it on top of the Chromatic Atmosphere infrastructure. Every action rewards.

---

## Ratified design principles (non-negotiable)

1. **Zero-Box.** No pills, no containers, no boxes, no rounded-rect chrome, no borders around any content element. Applies to avatars, action words, labels, empty states, trip surfaces.
2. **Floating feel.** Avatars are transparent PNG cut-outs (built with `apply_rembg.py`), rendered via `HologramAvatar` (ShaderMask guillotine dissolve at bottom 15%). Nothing ever wraps around them — no rings, halos, discs, plates, shadows.
3. **Text IS the action.** There are no buttons in the design. Words are typed, spaced, and the ambient atmosphere behind them responds to proximity and tap. No ✓/✗/♥/→ glyphs as action affordances.
4. **No counts on Home.** Counts (3 need you, 9 voting, etc.) frame relationships as obligations. Counts live on their owner tabs only.
5. **One avatar at a time.** Exactly one foreground avatar. Queue of 6 face-only avatars at 48px. At any moment the user's focus is on a single person.
6. **3-second rule.** Without memory work the user should read: **who** (face), **where** (context label), **what** (subject preview), **how to respond** (revealed in exactly one tap). **No exceptions** — DMs expose the subject preview. A bare "Message" label would force a tap just to triage priority, which is exactly the blind-inbox anti-pattern the 3-second rule forbids.
7. **Every action rewards.** Yes/No/Maybe/Love/Pass — every tap triggers the floating-respect reward loop. No punitive framing for "No."
8. **All expansion is in-place.** Tapping an avatar does NOT push a new route. Home's Stack cross-fades its own content. Reward animations run on the native Home canvas, with the queue and atmosphere still mounted.

---

## Home composition

```
┌─────────────────────────────────────────────┐
│  ChromaticAtmosphere — full-bleed,          │
│  palette drenched by the foreground         │
│  avatar's signature                         │
│                                             │
│                                             │
│              [HologramAvatar 140px]         │  ← foreground, upper-third
│                                             │
│      Swiss Alps · "hotel — zostel or taj?"  │  ← context label (groups)
│                                             │     or Message · "first 36 chars" (DMs)
│                                             │
│   [48] [48] [48] [48] [48] [48]             │  ← queue, 6 faces, horizontal
│                                             │
│                                             │
│              "all caught up"                │  ← empty state (future: recs)
│                                             │
│   ─── ── ── ──                              │  ← liquid_intent_handle idle
│                                             │
│        inbox · home · plans                 │  ← ghost indicators
└─────────────────────────────────────────────┘
```

### 1. Full-bleed ChromaticAtmosphere
Already implemented at `app/lib/views/home/decision_board/chromatic_atmosphere.dart`. Drenched by the foreground avatar's signature palette via `focusSourcesProvider`. When the foreground avatar changes (freshness re-sort), atmosphere cross-fades over 800ms. **No changes to this widget.** Home mounts it full-bleed and pushes the foreground avatar's palette into `focusSourcesProvider` at priority 20.

### 2. Foreground avatar (140 × 140)
- Widget: `HologramAvatar(avatarPath: getAvatarImagePath(senderName), size: 140)`
- Position: centered horizontally; top anchor ≈ 25% down from the top of Home's content area
- Source: `freshestPendingSender` — the person behind the most recent pending item
- `HologramAvatar`'s existing ShaderMask gradient `[0.0, 0.5, 0.85, 1.0]` (white→white→white→transparent) remains untouched at rest
- Hit target: full 140 × 140. On tap → **in-place expansion** to action surface (see Interaction model)

### 3. Context label (below foreground)
- Font: Inter w400, 14pt, `HelloColors.inkSecondary`
- Position: 12pt below the foreground avatar's bottom edge, centered horizontally
- Format:

| Source kind | Label |
|---|---|
| Item posted in a group / trip | `{group_name} · "{subject}"` |
| 1:1 DM | `Message · "{subject}"` |

- For groups: `{subject}` = the decision title / poll question / first 36 chars of the message text; trim with `…` if longer. Wrapped in straight double quotes.
- For DMs: same `{subject}` extraction as groups — first 36 chars of the message text, trimmed. The word `Message` replaces the group name as the context token so the user knows it's a 1:1.
- No container, no fill, no border. Just type. Max width 80% of Home width; overflow ellipsizes.

### 4. Queue row (6 × 48px avatars)
- Widget: up to 6 × `HologramAvatar(size: 48)` in a horizontal `Row`, 12pt gap between, centered
- Position: 32pt below the context label
- Source: next 6 pending senders by recency, excluding whoever is in the foreground. Purely recency-sorted, no tiebreakers.
- Fewer than 6 pending? Render only the actual count. No padding with placeholders.
- Face-only: no label, no bubble, no subject preview, no container, no ring, no border.
- Hit target: each 48 × 48 avatar. On tap → **in-place expansion** to action surface for that sender. No intermediate "promote to foreground" step.

### 5. Empty state
When the user has no pending items:
- `all caught up` at 15pt Inter w400, `HelloColors.inkTertiary`, centered horizontally, vertical position ~60% down from top
- No container, no icon, no illustration
- Atmosphere still breathes, drenched in the user's own signature palette (tab fallback)
- **Future (out of scope):** location-based recommendations fill this slot. Implementation deferred.

### 6. LiquidIntentLayer (scaffold-level)
Promoted from `pages/group_page.dart:343` to `decision_board_page.dart` wrapping the entire `TabBarView`. Only persistent bottom chrome across all four tabs.
- Idle: thin plasma line 160 × 4pt, bottom-centered, ~32pt above safe-area bottom
- Proximity (hover, web/desktop): 220 × 6pt, higher opacity
- Active (tap / drag up): 360 × 64pt bloomed glass shell with `TextField` + mic circle + `+` circle
- Ghost indicators `inbox · home · plans` at 11pt letterspaced, above idle line; active one at opacity 0.8 + scale 1.0, others 0.3 + 0.8
- `HOME ^` tab dropdown is **gone**; tab switching via TabBarView swipe + ghost-indicator tap

### 7. Home does NOT render
- `StatusOverview` pills — deleted
- `BottomBar` search pill — deleted
- `HOME ^` tab dropdown — deleted
- Any `DecisionCardSmall` — file deleted
- Nexus Orb (`cosmos_home_page.dart.disabled:213-239`) — deleted concept
- Plan World pill (`cosmos_home_page.dart.disabled:131-183`) — focus trip lives on PLANS tab
- Any count, badge, or number
- Rive-powered avatars (`live_avatar.dart.disabled`) — Rive assets never existed

---

## Interaction model — in-place state expansion

**Critical architectural patch (v2):** Tapping an avatar does NOT push a route. `OpenContainer` is **not used**. Home holds its own `_focusedSender?` state and transitions internally.

### State machine

Home has two primary display states plus a transient reward state:

| State | `_focusedSender` | `_isAnimatingReward` | Renders |
|---|---|---|---|
| **Ambient** | `null` | `false` | Atmosphere + foreground avatar + context label + queue row (or empty state) |
| **Expanded** | `Sender` | `false` | Atmosphere + focused avatar (still in 140px slot, possibly translated slightly) + full message text + action text-words row. Queue + context label cross-faded out. |
| **Rewarding** | `Sender` | `true` | Atmosphere + focused avatar mid-reward-sequence + frozen UI reading from `_snapshot` (not from provider). |

### Transitions

**Tap any avatar (foreground or queue → Expanded):**
1. `AnimatedOpacity` fades out the queue row + context label over 180ms
2. `AnimatedOpacity` fades in the message text + action text-words row over 180ms (overlapping)
3. If a queue avatar was tapped, it animates from its 48px slot up to the 140px foreground slot over 400ms (scale + translate) as the previous foreground fades. Otherwise the foreground avatar simply stays in place.
4. Atmosphere palette shifts to the focused sender's signature via `focusSourcesProvider` update
5. `_focusedSender` is set; `build()` renders the Expanded state

**Dismiss (tap outside the action region, or system back, → Ambient):**
- Reverse of above: message text + actions fade out (180ms), queue + context label fade back in (180ms). `_focusedSender` cleared.

**Action tap (Expanded → Rewarding → Ambient with next sender):**
1. Set `_isAnimatingReward = true` and snapshot the current `(foreground, queue)` tuple
2. Fire the engine mutation in parallel (`session.vote(...)`, `session.sendText(...)`, etc.)
3. Run the 1700ms reward sequence reading from `_snapshot` only
4. At animation completion, unset `_isAnimatingReward`, clear `_snapshot`, clear `_focusedSender`. `build()` re-reads from provider (which has since converged).
5. Next-freshest sender is now in the foreground slot naturally.

### In-place state expansion — rendering detail

`home_page.dart` holds a Stack with crossfading layers:

```dart
Stack(
  children: [
    // Layer 1: atmosphere (always)
    Positioned.fill(child: ChromaticAtmosphere()),

    // Layer 2: foreground avatar (always)
    Align(alignment: Alignment(0, -0.5), child: HologramAvatar(size: 140, ...)),

    // Layer 3: context label + queue (ambient only)
    AnimatedOpacity(
      opacity: _focusedSender == null ? 1.0 : 0.0,
      duration: Duration(milliseconds: 180),
      child: Column(children: [_contextLabel, _queueRow]),
    ),

    // Layer 4: message text + action row (expanded only)
    AnimatedOpacity(
      opacity: _focusedSender != null ? 1.0 : 0.0,
      duration: Duration(milliseconds: 180),
      child: Column(children: [_messageText, _actionWordsRow]),
    ),
  ],
)
```

Dismiss tap-away implementation: a transparent `GestureDetector(onTap: _dismissExpansion)` layered beneath the action row when `_focusedSender != null`.

### Action shape adapts to message kind

| Message kind | Action text-words (left → right) | Layout |
|---|---|---|
| Yes/No / time confirm / ack | `Yes`   `No`   `Maybe` | Horizontal row, 3 × `Expanded` |
| Decision / poll | `Love`   `Works`   `Pass` | Horizontal row, 3 × `Expanded` |
| Settlement | `Pay now`   `Later` | Horizontal row, 2 × `Expanded` |
| Open DM | full-width reply `TextField` | Single row, full width |

---

## Text-as-action design language

Applied uniformly wherever a word acts as an action.

- Font: Inter w400, **26pt**, `HelloColors.inkPrimary`
- Layout rule: **hit zones are grid-derived, not text-derived.** Each action word lives in its own `Expanded` inside a `Row`. The `Expanded` wraps `GestureDetector(behavior: HitTestBehavior.opaque)` → `Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(word)))`. This guarantees exactly `1/N` of the row is the tap target for each action, edge-to-edge, zero dead zones between.
- `FittedBox(scaleDown)` remains as a foldable / sub-320pt safety net but should rarely trigger. Every action-word set (`Yes`/`No`/`Maybe`, `Love`/`Works`/`Pass`, `Pay now`/`Later`) fits 26pt in a ⅓ slot on any phone viewport ≥ 320pt. Visual impact of 26pt stays perfectly uniform across devices.
- Rest state: just the word. No edge, no fill, no rounded rect.
- On approach (finger proximity / `pressDown` for touch; hover on web/desktop):
  - The atmosphere *behind* the word brightens. Implementation: a `RadialGradient` painted behind the text at the center of the `Expanded` bounds, alpha tapering to 0 at ~60pt radius. **No visible edge.** Reads as warm light behind frosted glass.
- On tap release:
  - The letters themselves fill with an animated plasma gradient via `ShaderMask + BlendMode.srcATop` (not `srcIn` — see Reward Layer 2 fix), 500ms
  - Ambient glow expands briefly then recedes over 400ms
  - `HelloHaptic.confirm` for affirmative (Yes / Love it / Pay now); `HelloHaptic.tap` for soft negatives (No / Not for me / Later / Maybe)
  - Word returns to ink at 500ms

---

## Reward animation — floating-respect, no shapes, GPU-safe

Every action tap triggers the following sequence, in parallel across layers. All layers run against the snapshot (see Animation Lock). Total ~1700ms to next-avatar-stable.

### Layer 1 — Avatar levitation
The person physically lifts toward you.
```
t = 0ms    → start
t = 300ms  → peak (avatar Y - 7pt), easeOutCubic
t = 700ms  → rest (avatar Y restored), easeInOut
```
Implementation: `TweenAnimationBuilder<double>` driving a `Transform.translate` on the `HologramAvatar`'s parent.

### Layer 2 — Plasma holographic infusion (not silhouette replacement)
**Patched from v1.** The photo's pixels gain plasma color temporarily, face remains intact.

v1 used `BlendMode.srcIn` in a nested `ShaderMask` — that discards destination pixels entirely (face becomes a flat plasma blob) AND forces a second `saveLayer` on top of the existing `HologramAvatar` mask (double off-screen render → jank over 120fps atmosphere).

v2 uses a single-layer color infusion:

```dart
AnimatedBuilder(
  animation: _plasmaPhase,
  builder: (ctx, child) {
    final color = buildPlasmaColorAt(_plasmaPhase.value)
        .withOpacity(0.55);  // alpha controls the infusion strength
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
      child: child,  // the existing HologramAvatar
    );
  },
  child: HologramAvatar(avatarPath: ..., size: 140),
)
```

- `BlendMode.srcATop` draws the plasma color on top of existing pixels only where the PNG has alpha. Face features remain; skin picks up plasma tint.
- `ColorFiltered` is cheaper than a second `ShaderMask` — no duplicate `saveLayer`.
- The "sweep" feel travels through *time* — the plasma color animates through the palette over 500ms instead of traveling top→bottom geometrically.
- No nested ShaderMask. No face obliteration.

### Layer 3 — Atmosphere responds
The whole screen's mood acknowledges.

| Action | Atmosphere transient (800ms, then relax) |
|---|---|
| Yes / Love it / Pay now | Saturation +15% |
| No / Not for me / Later | Saturation -15% + brightness -10% |
| Maybe | Dither opacity 0.015 → 0.025 + soft hue shimmer |

Implementation: new transient signal on `ambientPaletteProvider` (`ambientPalettePulseController`) that modulates the emitted palette for the pulse duration, then reverts. Full-bleed — no disc, no shape.

### Layer 4 — Ascent + handoff
Starting at t ≈ 1000ms:
- `HologramAvatar`'s gradient stops animate from `[0.0, 0.5, 0.85, 1.0]` → `[0.0, 0.15, 0.5, 1.0]` over 600ms — fade migrates feet→head, person dissolves from top down
- `Transform.translate` moves the avatar ~60pt upward simultaneously — they ascend through the top of the visible Home area
- `queue[0]` (from `_snapshot`) rises into the foreground slot: scales 48 → 140 over 700ms easeOutBack; translates to foreground position; new context label cross-fades in at t+400ms
- Queue row shifts left by one slot; if a 7th pending person exists, they fade in at `queue[5]`

### Layer 5 — Haptic
Fires on tap-down, before animation begins:
- `HelloHaptic.confirm` for affirmative
- `HelloHaptic.tap` for soft negative / Maybe

---

## State management — animation lock

**Patched from v1.** v1 would have let the provider's optimistic mutation instantly re-evaluate `freshestPendingSender`, flashing the next person into the foreground the moment "Yes" is tapped — breaking the 1700ms reward illusion.

v2 uses a local snapshot + reactive-read lock:

```dart
class _HomePageState extends ConsumerState<HomePage> {
  Sender? _focusedSender;
  bool _isAnimatingReward = false;
  ({Sender foreground, List<Sender> queue})? _snapshot;

  Future<void> _onActionTap(MessageKind kind, String action) async {
    // 1. Freeze the UI on the current state
    setState(() {
      _snapshot = (
        foreground: ref.read(freshestPendingSenderProvider)!,
        queue: ref.read(pendingSendersQueueProvider),
      );
      _isAnimatingReward = true;
    });

    // 2. Fire the mutation in parallel (provider re-emits, but UI ignores)
    unawaited(_applyAction(kind, action));

    // 3. Run the 1700ms reward sequence using _snapshot only
    await _runRewardSequence();

    // 4. Unlock — build() re-reads from provider (already converged)
    if (mounted) {
      setState(() {
        _isAnimatingReward = false;
        _focusedSender = null;
        _snapshot = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (foreground, queue) = _isAnimatingReward
      ? (_snapshot!.foreground, _snapshot!.queue)
      : (
          ref.watch(freshestPendingSenderProvider),
          ref.watch(pendingSendersQueueProvider),
        );
    // ... render using foreground + queue
  }
}
```

Provider mutation runs concurrently; UI stays locked on the snapshot for exactly 1700ms; then re-syncs. No mid-flight flash.

---

## File changes

### Delete
- `app/lib/views/home/decision_board/cards/decision_card_small.dart`
- `app/lib/views/home/decision_board/cards/focus_card_widget.dart` (subsumed inline into `home_page.dart`; no separate widget needed in the in-place architecture)
- `app/lib/views/home/decision_board/status_overview.dart`
- `app/lib/views/home/decision_board/bottom_bar.dart`
- `app/lib/views/home/decision_board/tab_chip.dart` (confirm BottomBar-only use first; grep)
- `app/lib/views/home/decision_board/tab_popover.dart`
- `app/lib/views/home/decision_board/cards/live_avatar.dart.disabled`
- `app/lib/views/home/decision_board/cards/live_avatar_showcase.dart.disabled`
- `app/lib/views/home/decision_board/pages/cosmos_home_page.dart.disabled`

### Rewrite
- `app/lib/views/home/decision_board/pages/home_page.dart` — full rewrite as cosmos with in-place state expansion + animation lock
- `app/lib/views/home/decision_board/decision_board_page.dart` — promote `LiquidIntentLayer` wrapping the entire `TabBarView`; remove `BottomBar` mount + import
- `app/lib/views/home/decision_board/pages/group_page.dart` — remove local `LiquidIntentLayer` mount (moved to scaffold)

### Modify (minor)
- `app/lib/views/home/decision_board/_card_factory.dart` — remove `DecisionSmallFeedItem` case; remove any residual `FocusCardWidget` references
- `app/lib/providers/filtered_feed_providers.dart` (or nearby) — add `freshestPendingSenderProvider` + `pendingSendersQueueProvider(maxCount: 6)` computed from the unified pending-items feed
- `app/lib/providers/ambient_palette_provider.dart` — add transient pulse signal for Reward Layer 3 (saturation bump / dim / shimmer)

### Preserve untouched
- `app/lib/views/home/decision_board/avatar_utils.dart` (`HologramAvatar`, `getAvatarImagePath`)
- `app/lib/views/home/decision_board/chromatic_atmosphere.dart`
- `app/lib/views/home/decision_board/liquid_intent_handle.dart`
- Plasma system (`plasma/*`)
- NS3 palette infrastructure (`focus_sources_provider.dart`, `palette_extractor.dart`, `oklch.dart`, `signature_color.dart`, `ambient_palette.dart`)
- `app/assets/images/*.png`
- `app/apply_rembg.py`

---

## Execution plan — 6 phases

Each phase ends with `cd app && dart analyze lib/` → zero new errors, plus the phase-specific gate below.

### Phase 1 — Scaffold chrome flip
**Goal:** `LiquidIntentLayer` is the only persistent bottom chrome on all four tabs.
- Move `LiquidIntentLayer` mount from `pages/group_page.dart:343` to `decision_board_page.dart` wrapping the entire `TabBarView`
- Remove `BottomBar` import + mount at `decision_board_page.dart:103`
- Delete `bottom_bar.dart`, `tab_chip.dart` (verify no other consumers), `tab_popover.dart`
- **Gate:** all four tabs render, swipe between tabs works, `LiquidIntentLayer` renders idle-line on every tab, tap blooms input correctly

### Phase 2 — Strip Home
**Goal:** Home reduces to atmosphere + empty content.
- Delete `status_overview.dart`, `decision_card_small.dart`, `focus_card_widget.dart`, all three `.disabled` files
- Remove `DecisionCardSmall` + `FocusCardWidget` cases from `_card_factory.dart`
- Replace `home_page.dart` body with a minimal `AtmosphereDensityScope(density: focus, child: SizedBox.expand())` temporarily
- **Gate:** Home renders as pure atmospheric surface; no counts, no masonry, no cards

### Phase 3 — Cosmos Home
**Goal:** The floating avatar surface renders.
- Add `freshestPendingSenderProvider` + `pendingSendersQueueProvider(maxCount: 6)` reading from the unified pending-items feed
- Implement `home_page.dart` Ambient state:
  - `Stack` with full-bleed `ChromaticAtmosphere`
  - Foreground `HologramAvatar` 140px at upper-third
  - Context label below (group+subject OR literal "Message" for DMs)
  - Queue row of 6 × 48px `HologramAvatar`
  - "all caught up" empty state when queue + foreground are both empty
- Push the foreground sender's signature palette into `focusSourcesProvider` at priority 20
- **Gate:** Home shows foreground avatar + label + queue; atmosphere drenches from foreground palette; tapping does nothing yet (expansion deferred)

### Phase 4 — In-place action expansion (no OpenContainer)
**Goal:** Tapping any avatar expands the action surface on Home's own canvas.
- Add `_focusedSender` state to `_HomePageState`
- Implement cross-fade transitions (Ambient ↔ Expanded):
  - Queue row + context label fade out (180ms)
  - Message text + action words row fade in (180ms)
  - If a queue avatar was tapped, scale/translate it 48→140 into the foreground slot (400ms)
- Implement the four action shape layouts (Yes/No/Maybe, decision, settlement, DM-reply)
- Apply text-as-action language: `Expanded` grid hit zones, `FittedBox(scaleDown)`, approach-glow via shapeless `RadialGradient`, `ColorFiltered(srcATop)` plasma sweep on letters on tap
- Wire dismiss on tap-outside
- Wire action taps to fire engine mutations (but no reward animation yet)
- **Gate:** tap any avatar → action surface expands in-place; each message kind renders correct action words; `Works for me` does NOT overflow on 390pt-wide viewports; tapping outside dismisses back to Ambient

### Phase 5 — Reward animation + lock
**Goal:** Every action tap runs the full floating-respect loop without provider snap.
- Implement `_isAnimatingReward` + `_snapshot` locking pattern in `_HomePageState.build()`
- Implement Layer 1 (levitation) as a state-driven `TweenAnimationBuilder`
- Implement Layer 2 (holographic infusion) using `ColorFiltered(ColorFilter.mode(plasmaColor, BlendMode.srcATop))` — verify via widget test that face features are preserved (no srcIn)
- Implement Layer 3 (atmosphere pulse) — add `ambientPalettePulseController` transient signal consumed by `ChromaticAtmosphere`
- Implement Layer 4 (ascent + handoff) — gradient stop animation + translate + queue shift from snapshot
- Wire Layer 5 (haptic) on tap-down
- **Gate:** tapping Yes/No/Maybe/Love-it/Pay-now triggers all five reward layers; foreground does NOT flash to next person mid-sequence; next queue avatar rises smoothly after animation; provider has converged by the time the lock releases

### Phase 6 — Audit & polish
**Goal:** Doctrine enforced, no regressions.
- Grep-assert: no `BorderRadius` or `border:` in `home_page.dart`
- Grep-assert: no `Icons.` usage as a primary action in `home_page.dart`
- Grep-assert: no `BlendMode.srcIn` anywhere in Home rendering (Layer 2 verification)
- Grep-assert: no nested `ShaderMask` over `HologramAvatar` (GPU verification)
- Visual audit: open every combination of (0, 1, 3, 6) queue senders + (group, DM) foreground + each message kind; verify no ring / halo / disc / plate / shadow appears around any avatar in any state
- Performance audit: verify frame rate stays ≥ 60fps during the reward sequence (Flutter DevTools Timeline); no `saveLayer` count regressions
- Overflow audit: build on simulated 320pt-wide viewport; verify no `RenderFlex overflowed` errors in decision action row
- 3-second rule test: close app, re-open to Home, count Mississippi seconds to name *who · where · what*. Target ≤ 3. Repeat 5 times with different feed states.
- `dart analyze lib/` zero new errors; `flutter build web --no-tree-shake-icons` passes
- Update root `CLAUDE.md` + `app/CLAUDE.md` to reflect new Home architecture and retire references to `StatusOverview`, `BottomBar`, `DecisionCardSmall`-on-Home, `FocusCardWidget`

---

## Out of scope

1. **Location-based recommendations** in the empty state — slot reserved; implementation deferred
2. **Engine wiring for real action side-effects** — this spec assumes `session.sendText(...)`, vote/settle RPCs exist; concrete E2EE transport per action is "Great Wiring" work, separate track
3. **Group avatar hologram variants** — the 3 group PNGs render identically to individual avatars when a group is the pending-item source
4. **Rive character avatars** — permanently dropped; `assets/rive/` does not exist in the repo; `.disabled` files deleted in Phase 2

---

## Open questions

**None.** All brainstorming questions + all six technical review patches resolved.

---

## Verification criteria (acceptance)

- Home opens → user names *who needs me · where · what they asked* in under 3 seconds — **no exceptions**; DMs expose the subject preview
- Tapping a queue avatar → response sent in exactly 2 taps (avatar + action word)
- Zero containers, pills, boxes, borders, or glyph-buttons on any Home surface
- Every action tap runs the reward loop and promotes the next avatar — **without mid-flight snap**
- `LiquidIntentLayer` is the only persistent bottom chrome across all four tabs
- `BlendMode.srcIn` never appears over a `HologramAvatar` (Layer 2 GPU safety)
- Single-word decision copy (`Love` / `Works` / `Pass`) renders at a uniform 26pt without triggering `FittedBox` scale-down on any viewport ≥ 320pt
- `dart analyze lib/` zero new errors at every phase gate
- 60fps maintained during the reward sequence

---

## Revision history

- **v1** (2026-04-14 evening) — Initial spec from brainstorming. Used `OpenContainer` for morph, `BlendMode.srcIn` for plasma sweep, padding-based hit targets, assumed provider-driven UI during reward. **Six architectural flaws caught in review:** OpenContainer paradox, srcIn face-obliteration + nested ShaderMask, 26pt overflow on decision row, DM subject gap, hit-target dead zones, optimistic UI snap.
- **v2** (2026-04-14 evening) — All six technical patches integrated. OpenContainer replaced with in-place state expansion. Layer 2 uses `ColorFiltered(srcATop)`. Hit targets use `Expanded` grid. `FittedBox(scaleDown)` safety net for long decision copy. Animation lock with local snapshot during reward. DM label was `Message` alone with an explicit Principle 6 DM exception.
- **v3** (this document — 2026-04-14 late evening) — Two product-level flips after a second architectural review:
  1. **DM label exposes the subject preview.** `Message` alone is now `Message · "{first 36 chars}"`. Principle 6 DM exception is deleted. Rationale: a bare label forces the user to tap just to triage priority, which is the blind-inbox pattern the 3-second rule forbids.
  2. **Decision action copy is single-word.** `Love it` / `Works for me` / `Not for me` becomes `Love` / `Works` / `Pass`. Rationale: typographic consistency — all three words render at 26pt without FittedBox scale-down on any viewport ≥ 320pt, so the 26pt visual impact stays uniform across devices and across action kinds (Yes/No/Maybe, Love/Works/Pass, Pay now/Later all share the same visual weight).
