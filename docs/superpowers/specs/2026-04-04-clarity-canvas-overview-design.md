# Clarity Canvas — Overview Page Design

## Goal
Replace the current hero-banner Overview with a clarity-first, detail-rich status board. Every item is a self-contained detail card showing all relevant information (price, times, ownership, booking status) without tapping. Settled items are green-tinted, active items have orange progress bars. [+ add] is contextual per section and omnipresent via top bar.

## Design Principles
1. **Clarity dominates** — no hero banner, no mood board. Content IS the visual.
2. **Self-contained cards** — each card shows ALL details (flight number, cost, who paid, PNR).
3. **Avatar-on-item** — 24px avatar + name on every card showing ownership.
4. **Two visual states only** — Green (settled) vs Orange (active). Nothing else.
5. **[+ add] everywhere, never in the way** — contextual in section headers, global in top bar.
6. **No-Bold mandate** — w400 max. Hierarchy via size, spacing, color, opacity.

---

## Layout Structure

### Compact Header (replaces hero banner)
- Event name: `HelloTypography.hero` at 22px, left-aligned
- Progress ring: 36px diameter, 2px stroke, accent color, percentage text inside
- Stats line: `"4 done · 8 pending · 2 new"` in `HelloTypography.hint`
- No photo. No banner. Compact — ~60px total height.

### Section Headers
```
HOTELS                        + add
```
- Category name: uppercase, `HelloTypography.label`, letter-spacing 1.0, `inkSecondary`
- `+ add`: right-aligned, `HelloTypography.hint`, `inkTertiary`, tappable
- Tap `+ add` opens AddItemSheet pre-filled with that category
- 16px top margin, 8px bottom margin. Whitespace creates separation.

### Active Item Card
```
┌────────────────────────────────────┐
│  Title                       65%   │
│  $price · detail · detail          │
│  ◯ Priya proposed                  │
│  ▎████████████░░░░░░▕       65%   │
└────────────────────────────────────┘
```
- **Left border:** 3px solid `HelloColors.accent` (#FF6B35)
- **Background:** `HelloColors.chrome` (#FAFAFA)
- **Border radius:** 12px
- **Padding:** 14px all sides
- **Margin:** 0 horizontal (full section width), 8px bottom
- **Title:** `HelloTypography.body` at 16px, `inkPrimary`
- **Score:** right-aligned, `HelloTypography.hero` at 22px, accent color when >=70%, `inkSecondary` otherwise
- **Description:** `HelloTypography.hint` at 13px, single line, ellipsis
- **Avatar row:** 24px circle (recessed bg, initial letter) + "Name proposed/paid" in `hint` at 13px
- **Progress bar:** 6px height, rounded 3px, accent fill, `recessed` track. Full width minus padding.
- **Progress %:** right-aligned next to bar, `hint` at 12px

### Settled Item Card
```
┌────────────────────────────────────┐
│  ✓ Title                  Booked   │
│  $price · detail · detail          │
│  Conf #KL4829 · PNR: X4K2M        │
│  ◯ Priya paid · $3,640            │
└────────────────────────────────────┘
```
- **Left border:** 3px solid `HelloColors.successGreen` (#047857)
- **Background:** `successGreen` at 4% opacity
- **"Booked" label:** right-aligned, `successGreen`, `label` style
- **Checkmark:** 16px `Icons.check_circle`, `successGreen`, inline with title
- **Booking details line:** description line shows confirmation/PNR if available
- **Paid line:** avatar + "Name paid · $amount" — shows who paid and how much
- All other styling matches Active card

### [+ Add] Behavior
- **Section-level:** `+ add` text in section header, right-aligned. Tapping opens AddItemSheet with category pre-selected.
- **Global:** existing [+] button in top bar opens AddItemSheet with no category pre-selected (user picks).
- **No floating FAB.** No visual disruption to the card stream.

### Sections Ordering
1. Sections ordered by: most active items first (by total weighted score)
2. Within each section: settled items first (trophies), then active (by score desc), then new
3. Empty sections are not shown

---

## File Changes

| Action | File |
|--------|------|
| Rewrite | `app/lib/demov2/plans_view.dart` — replace `_OverviewDashboard` with Clarity Canvas |
| Keep | All other PlansView components (Tier 1, Tier 2, DecisionCardStream, Split) unchanged |

## Constraints
- No hero banner. No photos in overview (photos live on the Decision Cards in category tabs).
- No-Bold mandate: w400 max everywhere.
- Avatar: 24px circle, `HelloColors.recessed` background, initial letter in `body` at 12px.
- Progress bar: only on active items. Settled items show "Booked" label instead.
- Cards must handle missing data gracefully (no PNR? don't show the line. No photo? no problem — overview doesn't use photos).
