# Decide-First Group Interior UX

## Goal
Port the React web app's Netflix-style DecisionBoard into Flutter as the default group view, with a summary header, [+] add flow, and gold burst consensus celebration.

## Source of Truth
The React implementation in `web/src/components/os/DecisionBoard.tsx` and `web/src/components/os/AddItemModal.tsx` defines the patterns. This spec ports them to Flutter with mobile-native interactions.

---

## 1. Group Interior Layout

**File:** `app/lib/demov2/space_layout.dart` (modify existing)

Current: `[Chat (index 0), Possibilities (index 1)]` with Chat as default.
New: `[Decide (index 0), Chat (index 1)]` with Decide as default.

- Top nav rail: `Decide` and `Chat` with typographic opacity fade (existing pattern).
- `PageView` with `ClampingScrollPhysics` — swipe right to access Chat.
- Back button returns to home, not to chat.

---

## 2. Summary Card (Group Pulse)

**File:** `app/lib/demov2/group_summary_card.dart` (new)

Compact dashboard pinned at the top of the Decide tab, above swim lanes. Shows at-a-glance group state.

**Contents:**
- Item counts by state: `"4 active · 2 locked · 3 new"`
- Hottest item callout: highest `agreementScore` item not yet locked, with percentage. E.g. `"St. Regis at 82%"`
- Member activity: `"3 members voted today"`

**Visual:**
- Full-width card with `HelloColors.recessed` background, 16px border radius.
- Horizontal row layout: counts left, hottest item right.
- `HelloTypography.label` for counts, `HelloTypography.body` for hottest item name.
- Accent color on the percentage number.
- No elevation, no border. Minimal.

---

## 3. Netflix Swim Lanes (Decision Board)

**File:** `app/lib/demov2/decision_board.dart` (new)

Replaces the current `_PossibilityHorizon` vertical list. Vertical `SingleChildScrollView` containing stacked horizontal rails.

### 3a. Data Flow

```
engine.getDecisionItems(groupId)
  → group by smart category routing (mirrors React DecisionBoard)
  → sort each group by heartSort (weightedScore desc, then agreementScore desc)
  → render as swim lane rows
```

### 3b. Smart Category Routing

Port from React `DecisionBoard.tsx` lines 726-759:

| `metadata.type` | `category` field | Rail label |
|---|---|---|
| `"task"` (unclaimed) | any | "up for grabs" |
| `"task"` (claimed) | any | "claimed" |
| `"poll"` | any | "polls" |
| — | `"hotel"` | "hotels" |
| — | `"restaurant"` | "restaurants" |
| — | `"activity"` | "things to do" |
| — | `"flight"` | "flights" |
| — | `"experience"` | "experiences" |
| — | other / empty | "ideas" |

Items with `isLocked: true` are grouped into a special "locked" rail that renders at the top.

### 3c. Rail Rendering Order

1. **Locked** — gold-bordered trophies (only if locked items exist). Collapsed to a single line if all items in a category are locked (matches React `allLocked` pattern).
2. **Category rails** — one per category, sorted by total weighted score descending.
3. **Up for grabs / Polls** — special rails at bottom.

### 3d. Single Rail Widget

**File:** `app/lib/demov2/swim_lane_rail.dart` (new)

Each rail:
- **Header:** category name (Inter, 22px, w400, `inkPrimary`) + vital label right-aligned (12px, w300, colored by consensus state).
- **Horizontal cards:** `SizedBox` height = 55% screen height. `ListView.builder` with `scrollDirection: Axis.horizontal`, item width = 78% screen width, 12px gap. `Clip.none` for shadow overflow. `BouncingScrollPhysics`.
- Cards are the existing `ActionCardWidget` — full-bleed photo, dark wash, score number, Pass/Okay/Love buttons.

### 3e. Vital Label (per rail)

Port from React `categoryVital()`:
- Top item >= 80%: `"92% on #1 · 3 of 4"` in gold.
- Some rated: `"3 of 4 rated"` in accent.
- None rated: `"needs votes"` in amber.

---

## 4. [+] Add Item Flow

**File:** `app/lib/demov2/add_item_sheet.dart` (new)

Port of `web/src/components/os/AddItemModal.tsx`.

### 4a. FAB Trigger

Floating action button, bottom-right of Decide tab. 48x48, `HelloColors.accent` background, white `+` icon, 16px border radius, subtle shadow.

### 4b. Bottom Sheet

Tap FAB opens a modal bottom sheet (spring animation, 400ms). Contents:

1. **Image zone** — tap to open image picker (camera or gallery). Shows dashed border placeholder initially, fills with selected image preview.
2. **Title input** — `"what is this?"` placeholder. Auto-filled from filename if image selected.
3. **Category input** — `"category (e.g. hotels, decorations)"` placeholder. Optional, defaults to `"shared"`.
4. **Submit button** — `"add to decide"`, accent color, disabled until image + title provided.

### 4c. Demo Mode

For the demo (mock engine): skip E2EE encryption and Firebase upload. Instead:
- Use a random Unsplash URL as the photo.
- Insert directly into the mock engine's decision items list.
- Animate the new card into the appropriate swim lane with the dealer effect.

### 4d. Live Mode (Future)

Full pipeline matching React: encrypt file → upload to Firebase → insert to Supabase → realtime dealer picks it up.

---

## 5. Gold Burst Consensus Celebration

**File:** `app/lib/demov2/gold_burst.dart` (new)

The app's signature moment. Triggers when `agreementScore` crosses 0.80 threshold.

### 5a. Trigger

Existing `_checkConsensus()` in `ActionCardWidget` detects threshold. Add celebration overlay on state change.

### 5b. Animation Sequence (1.2s total)

1. **0ms:** Heavy haptic (`HapticFeedback.heavyImpact()`).
2. **0-400ms:** Card border morphs from transparent to gold gradient. `AnimatedContainer` with `BoxDecoration` border color transition.
3. **100-800ms:** Particle burst — 40 gold circles (`CustomPainter`) explode radially from card center. Each particle: random angle, random velocity (200-500px), fade from 1.0→0.0, scale 1.0→0.3. Use `AnimationController` + `Tween`.
4. **200-600ms:** Score number scales 1.0→1.4→1.0 with `SpringSimulation` (mass: 1, stiffness: 300, damping: 15).
5. **600-1200ms:** Gold glow shadow intensifies then settles. `BoxShadow` with animated `blurRadius` 0→30→20 and `color` opacity 0→0.4→0.2.

### 5c. Visual Constants

- Particle color: `HelloColors.gold` (#8B6914) at varying opacities.
- Border gradient: `[#8B6914, #FFCF40, #8B6914]`.
- Glow color: `HelloColors.gold.withOpacity(0.3)`.

---

## 6. Mock Data Expansion

**File:** `app/lib/demov1/mock_data_seed.dart` (modify existing)

Expand `buildDecisionItemsFor` to generate richer data for the swim lane demo.

### Bali Trip (15 items across 5 categories)

**Hotels (3):** St. Regis (locked, 1.0), W Bali (voting, 0.45), Mulia (voting, 0.30).
**Experiences (3):** Mt. Batur Trek (locked, 1.0), Ubud Rice Terraces (voting, 0.60), Sunset Cruise (voting, 0.25).
**Flights (2):** SQ938 (voting, 0.70), GA715 (voting, 0.35).
**Dining (3):** Locavore (voting, 0.55), Sardine (voting, 0.40), Warung Babi (new, 0.0).
**Loose (4):** Beach club day pass (new, 0.0), Surfboard rental (new, 0.0), Spa treatment (new, 0.0), Airport transfer (new, 0.0).

### Sarah's Birthday (8 items across 3 categories)

**Restaurants (3):** Carbone (voting, 0.90), Balthazar (voting, 0.20), Le Bernardin (new, 0.0).
**Gifts (3):** Aesop kit (voting, 0.60), Concert tickets (voting, 0.45), Photo book (new, 0.0).
**Decorations (2):** Balloon arch (new, 0.0), Custom cake (new, 0.0).

### Tokyo (12 items) — existing demo data in React, port the 17-item set from `DEMO_ITEMS["space_tokyo-neon-nights"]`.

---

## 7. Theme

Light mode is the default. No changes. Dark mode is a future premium feature, not part of this build.

---

## Constraints

- **No-Bold Mandate:** All text weights 400 max. Rail headers, card titles, labels — all w400 or w300.
- **Iron Rule:** All data flows through the engine. The Flutter UI never queries Supabase directly.
- **E2EE:** [+] add flow in live mode must encrypt images before upload. Demo mode skips this.
- **Spring Physics:** All button interactions use `SpringSimulation`, not `CurvedAnimation`.
- **No elevation/Material shadows:** Use `BoxShadow` with custom blur/spread. No `Material` or `Card` elevation.

---

## File Map

| Action | File |
|--------|------|
| Modify | `app/lib/demov2/space_layout.dart` — flip tab order, wire DecisionBoard |
| Create | `app/lib/demov2/decision_board.dart` — Netflix swim lane orchestrator |
| Create | `app/lib/demov2/swim_lane_rail.dart` — single horizontal rail widget |
| Create | `app/lib/demov2/group_summary_card.dart` — compact group pulse header |
| Create | `app/lib/demov2/add_item_sheet.dart` — [+] bottom sheet |
| Create | `app/lib/demov2/gold_burst.dart` — particle celebration overlay |
| Modify | `app/lib/demov1/mock_data_seed.dart` — expand to 15+ items per group |
| Modify | `app/lib/demov1/mock_chat_engine.dart` — add `addDecisionItem()` for [+] flow |
| Modify | `app/lib/widgets/action_card_widget.dart` — integrate gold burst trigger |
