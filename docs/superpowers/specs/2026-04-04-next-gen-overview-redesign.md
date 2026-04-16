# Next-Gen Overview Redesign — UI/UX Pro Max Directive

## The Problem
The current overview looks like a SaaS dashboard (Jira/Asana). Four specific culprits identified by UI/UX Pro Max analysis.

## The 4 Fixes

### 1. People > Percentages
- **Kill**: 75% badge, progress bars, "0 done · 7 voting · 1 new" metrics
- **Replace with**: Facepile (overlapping avatar circles of who voted), conversational copy ("Waiting on Dad...", "Priya and 3 others love this")
- **Why**: Social proof > raw data. Emotion > analytics.

### 2. Media > Data (Full-Bleed Photo Cards)
- **Kill**: thumbnail-left/text-right ListTile layout
- **Replace with**: Full-width photo spanning the card, text layered OVER bottom of image with dark gradient overlay
- **Layout**: Stack widget — Image background → gradient overlay → white text (title, price, description)
- **Border radius**: 24px (bubbly, organic — not 12px corporate)
- **Why**: Vacations are visual. The photo IS the content.

### 3. Vibrant Avatars
- **Kill**: 20px gray circles with initial letters
- **Replace with**: 36-40px colorful avatar circles, unique color per person (not gray), overlap card edges
- **Avatar colors**: Each person gets a consistent warm color from a palette (coral, teal, violet, amber, rose)
- **Why**: Human identity is core to a social app.

### 4. Navigation — Floating Glass Pill
- **Kill**: Two stacked horizontal bars (categories + events)
- **Replace with**:
  - Trip selector → dropdown in the header bar (next to group name)
  - Categories → floating frosted glass pill at screen bottom (BackdropFilter blur)
- **Glass pill**: translucent white, blur 20px, rounded 24px, floats 16px above bottom safe area
- **Why**: Maximize vertical content space. No Excel tabs.

## Card Anatomy — Active Item (New Design)

```
┌────────────────────────────────────────┐
│                                        │  ← Full-width photo (160px height)
│         [HOTEL PHOTO HERE]             │     ClipRRect borderRadius 24
│                                        │
│  ┌─gradient overlay──────────────────┐ │
│  │  Fairmont Kea Lani      $520/nt   │ │  ← White text on dark gradient
│  │  5-star · Wailea Beach            │ │
│  │  ◯◯◯ Priya, Dad +1 love this     │ │  ← Facepile + social copy
│  └───────────────────────────────────┘ │
└────────────────────────────────────────┘
```

## Card Anatomy — Settled Item

```
┌────────────────────────────────────────┐
│         [PHOTO + GREEN TINT]           │  ← Green overlay on photo
│                                        │
│  ┌─gradient overlay──────────────────┐ │
│  │  ✓ Fairmont Kea Lani    Booked   │ │  ← Checkmark + "Booked"
│  │  Priya booked · Conf #KL4829     │ │
│  └───────────────────────────────────┘ │
└────────────────────────────────────────┘
```

## Header — Compact with Trip Dropdown

```
  < ←    ◯ Family    [+]  [Chat]
         Hawaii (Maui) ▼              ← Dropdown for trip selection
```

## Bottom Navigation — Floating Glass Pill

```
  ┌──────────────────────────────────┐
  │  Overview · Hotels · Flights · ▸ │  ← Frosted glass, blur 20
  └──────────────────────────────────┘
       ↑ floating 16px above bottom
```

## Flutter Implementation Rules
- Ditch `Card()` and `ListTile()` — custom `Container` + `Stack`
- `BorderRadius.circular(24)` everywhere (not 12-16)
- `Stack` for image + gradient overlay + text
- `BackdropFilter` + `ImageFilter.blur(sigmaX: 20, sigmaY: 20)` for glass pill
- No default `BoxShadow` — use brand-tinted shadows or 1px borders
- `ClipRRect` for all image containers
- Facepile: `Row` of overlapping `Container` circles with negative margins

## Avatar Color Palette (per person)
| Person | Color |
|--------|-------|
| Priya | #FF6B6B (coral) |
| Dad | #4ECDC4 (teal) |
| Me | #FFB347 (amber) |
| Emma | #9B59B6 (violet) |
| Alex | #3498DB (blue) |
| Mom | #E74C8B (rose) |
