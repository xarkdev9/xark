# Light Theme Migration — Design Spec

**Date:** 2026-04-11
**Status:** Approved for implementation
**Supersedes:** Dark theme across the entire home surface

---

## 1. Vision

Replace the dark theme (`voidBg #050507`, light-on-dark ink) with the original **light theme** from `ui_backup_2026-04-10/flutter/theme.dart`: `voidBg #FAFAFA`, dark-on-light ink, white glass surfaces. Keep everything that works — V10 tab scaffold, mode chip bar, living-field atmosphere mechanics, Airbnb Rausch accent, focus-trip colors, card widgets, sheets, masonry grid, all of it — and flip the color math so the whole surface feels bright and clean.

Three things happen together:

1. **Theme tokens flip.** All dark-mode token values invert to their light equivalents (from the archived theme). Every widget that uses theme tokens updates automatically. Widgets that use hardcoded `Colors.white` for glass / `Colors.black` for scrims / light hex text colors get manual flips.
2. **Atmosphere is replaced with a focus-tinted light wash.** The existing `AmbientMesh` keeps its `focusTripProvider` / `centeredFeedItemKindProvider` / `tabAnimationProvider` bindings, but the primary blob renders as a very faint (6–10% alpha) radial wash in the focus trip's accent color on top of an `#FAFAFA` base. Lerps smoothly during tab swipes. No grain in v1 (kill the dark grain layer).
3. **Chat bubbles become real.** The mock `_DmSheet._MessageBubble` is replaced by a full `ChatBubble` widget ported from `ui_backup_2026-04-10/flutter/widgets/chat_bubble.dart`: white glass bubbles with 20σ/8σ asymmetric backdrop blur, 4px smart-corner radii for consecutive same-sender messages, swipe-to-reply with spring physics snap-back, long-press for emoji reactions.

## 2. Scope

**In scope:**
- Full color token flip in `app/lib/theme.dart`
- Rewrite `atmosphere.dart` as a light focus-tinted wash (keeps the tab/focus/kind listeners and the tab animation lerp)
- Flip `_card_shell.dart` glass for light: white fill, subtle dark rim, subtle drop shadow
- Flip hardcoded `Colors.white.withAlpha(...)` / `Color(0xFFF0EFF4)` / `Color(0xCC000000)` references in chrome widgets, text cards, hero cards, sheets
- Flip hero card scrims from dark-gradient to light-gradient, flip hero card text from near-white to near-black
- Port `ChatBubble` from archive verbatim (white glass, smart corners, swipe-to-reply, long-press emoji reactions)
- Replace the mock `_MessageBubble` in `dm_sheet.dart` and `group_sheet.dart` with real `ChatBubble` widgets
- Wrap all 7 sheets (`dm_sheet`, `group_sheet`, `decision_sheet`, `settlement_sheet`, `search_sheet`, `new_chat_sheet`, `attachment_sheet`) with `Material(type: MaterialType.transparency, child: ...)` ancestors so `TextField` no longer throws "No Material widget found" errors
- Update `ConversationListRow` colors for light background
- Update all 4 tab pages' background if any hardcoded reference exists (most use `HelloColors.voidBg` which flips automatically)

**Out of scope:**
- Dark mode toggle / theme mode provider (killed entirely per user decision)
- Archived theme's `primary` (Deep Rose / Liquid Fire) — keeping our Rausch `accent` as the sole brand color
- Archived theme's `liquidFireStandard` / `liquidFireInvocation` gradients (not used in current codebase)
- Reviving `widgets/chat_input.dart` from archive — keeping our `MessageInputBar` as the chat input, only adopting the `ChatBubble`
- Changing the atmosphere's `centeredFeedItemKindProvider` watching (still lerps per kind, just in light variant)
- Changing `_card_factory.dart` or the card type switch logic

## 3. Color token changes

### Current → New

| Token | Dark value | Light value | Source |
|---|---|---|---|
| `voidBg` | `#050507` | `#FAFAFA` | archive exact |
| `surfaceDeep` | `#0A0A0E` | `#FFFFFF` | new (pure white for elevated surfaces) |
| `recessed` | `#17171C` | `#F0F0F0` | archive exact |
| `accent` | `#FF385C` | `#FF385C` | **unchanged** (Airbnb Rausch preserved) |
| `focusViolet` | `#7C3AED` | `#7C3AED` | unchanged (trip accent) |
| `focusAlpine` | `#4A90E2` | `#4A90E2` | unchanged (Swiss trip accent) |
| `focusOcean` | `#14B8A6` | `#14B8A6` | unchanged (Goa trip accent) |
| `focusSunset` | `#FF9B6E` | `#FF9B6E` | unchanged (Bali trip accent) |
| `liveGreen` | `#10B981` | `#047857` | darkened for contrast on light bg |
| `primary` | `#D4536B` | `#D4536B` | unchanged (kept for backward compat) |
| `inkPrimary` | `#F0EFF4` | `#1A1A1A` | archive exact |
| `inkSecondary` | `0x8CF0EFF4` | `#6B6B78` | archive exact |
| `inkTertiary` | `0x47F0EFF4` | `#8A8A94` | archive exact |
| `gold` | `#C8A84E` | `#8B6914` | archive exact |
| `error` | `#FF6B8A` | `#C43D08` | archive exact |
| `white` | — (N/A) | `#FFFFFF` | **new token** for chat bubbles and elevated chrome |

## 4. Atmosphere redesign — focus-tinted light wash

**Concept:** keep every provider binding (`focusTripProvider`, `centeredFeedItemKindProvider`, `tabAnimationProvider`), keep the animated blob motion, but replace the dark-base + colored-blob composition with a light-base + very-faint-wash composition.

**Layer stack (top → bottom):**

1. **Base wash** — pure `#FAFAFA` flat fill
2. **Primary wash** — radial gradient centered top-left, ~560×460, color = focus trip accent / tab signature, alpha = `0.08` (very subtle)
3. **Secondary wash** — radial gradient center-right, ~500×460, color = tab animation lerp (or centered kind), alpha = `0.05`
4. **Tertiary wash** — radial gradient bottom-left, same color, alpha = `0.03`
5. **Optional:** very faint white-gradient highlight top-right at `0.12` for "light coming in"
6. **No grain layer.** Grain was useful against dark bases; on light, it reads as dirt.

The blob positions still animate via `AnimationController(duration: Duration(seconds: 26))..repeat()` using the same `sin/cos` position offsets. What changes is the colors get lerped via `_primaryForKind` / `_primaryForTabAnimation` (same functions, same result) — we just draw them at much lower alpha on a white base.

Net effect: the background is predominantly off-white, with a very subtle colored wash that shifts as the user scrolls and swipes tabs. The "living field" concept survives in whisper form.

## 5. CardShell glass for light theme

**Current (dark):** `Colors.white.alpha(0.07→0.02)` gradient + `Colors.white.alpha(0.10)` rim + `BackdropFilter(blur 20σ)`.

**New (light):**
- Base fill: solid `Colors.white` (or `HelloColors.white` after the new token lands)
- Rim: `Colors.black.alpha(0.06)` — very subtle dark edge
- Drop shadow: `BoxShadow(color: Colors.black.alpha(0.04), blurRadius: 12, offset: Offset(0, 2))` — soft elevation
- Kind overlay (if present): unchanged — still renders at low alpha over the white fill (the colors are subtle in both themes)
- Focus ring + ambient pulse: flip ring color from `Colors.white.alpha(X)` to `Colors.black.alpha(X)` so the ring is visible against a white card
- Spring tap scale: unchanged

The backdrop blur is mostly cosmetic in light mode (there's nothing dark behind to blur) but we keep it so photo-hero cards still have the frosted edge feeling.

## 6. Hero card scrim + text flip

Hero cards (DecisionCardHero, TripCard, FocusHeroCard, optionally MemoryCard with photo) have photo backgrounds with gradient scrims and overlaid text.

**Current:**
- Darken overlay: `Colors.black.alpha(0.28-0.55)`
- Scrim gradient: `transparent → Color(0xCC000000)` (black at 80%)
- Text color: `Color(0xFFF0EFF4)` (near-white)

**New:**
- Darken overlay: removed (or `Colors.white.alpha(0.12)` for subtle cleanup)
- Scrim gradient: `transparent → Color(0xE6FFFFFF)` (white at 90%)
- Text color: `Color(0xFF1A1A1A)` (near-black)

The flip means dark text becomes readable on the bottom half of hero photos where the scrim turns the photo progressively white. The top half keeps the photo crisp.

**Live event tag color:** flips from bright `liveGreen #10B981` to darker `#047857` for contrast on a light photo.

## 7. Chat bubble port

Source: `ui_backup_2026-04-10/flutter/widgets/chat_bubble.dart` — port **verbatim** (all 360 lines) to `app/lib/views/home/decision_board/chat_bubble.dart`. The archived widget is already a finished design with:

- Glass bubble: `Colors.white.alpha(0.85)` inbound, `Colors.white.alpha(0.60)` outbound
- 1px border at `Colors.white.alpha(0.30)` (visible against the off-white background as a very subtle edge)
- `BackdropFilter` with `ImageFilter.blur(20σ)` outbound, `8σ` inbound (asymmetric by intent — the outbound bubble has stronger frost)
- **Smart corner radii:** `BorderRadius.only` with 20px outer corners and 4px inner corners on the "tail" side, plus 4px top-right on consecutive grouped messages (iMessage cluster behavior)
- **Swipe-to-reply:** `GestureDetector.onHorizontalDragUpdate` with drag resistance `0.35`, drag threshold `60px`, snap-back via `SpringSimulation` at stiffness `600`, damping `28`. Reply icon fades in from behind the bubble based on drag offset. `HapticFeedback.heavyImpact()` when threshold crossed.
- **Long-press for reactions:** `onLongPress` → `HapticFeedback.mediumImpact()` → `_pressScale: 0.98` → reveals a 5-emoji picker row (❤️ 😂 👍 😮 🔥) on a white pill with soft shadow. Selected emoji floats below the bubble as a small reaction chip.
- Sender name for incoming group messages (first in group only)
- Text at `HelloColors.inkPrimary.alpha(0.9)` — in new tokens this means `#1A1A1A` at 90% alpha, which is the dark-on-white look

The archived `_senderNames` hardcoded lookup table is kept as-is for v1 (stubs for real profile fetching).

**Integration:**
- `dm_sheet.dart` — replace the mock `_MessageBubble` class + the 3-message `ListView.separated` with real `ChatBubble` widgets sourced from a mock `List<_MockMsg>` (retaining the existing message text for continuity)
- `group_sheet.dart` — same pattern; if the group has a sender id, pass it so ChatBubble shows the sender name above the bubble
- `decision_sheet.dart` / `settlement_sheet.dart` / `search_sheet.dart` / `new_chat_sheet.dart` / `attachment_sheet.dart` — unchanged (no chat bubbles in these)

## 8. Sheet Material ancestor fix

All 7 sheets use `showGeneralDialog` + `Stack` + `Container` without a `Material` ancestor. When they contain a `TextField` (`MessageInputBar` for DM/Group, search field in search sheet, voice title "What do you want to start?" heading), Flutter throws: "No Material widget found. TextField widgets require a Material widget ancestor…"

**Fix:** inside each sheet's `ClipRRect(borderRadius: ...) → BackdropFilter → Container` chain, wrap the content in `Material(type: MaterialType.transparency, child: ...)`. This provides the required ancestor without adding any visual chrome (no background color, no elevation).

Applied to all 7 sheet files. Trivially small per-file change.

## 9. Chrome widget flips

**Widgets with hardcoded `Colors.white.alpha(X)` that need flipping:**

- `tab_popover.dart` — glass gradient uses `Colors.white.alpha(0.12→0.04)` → flip to `Colors.black.alpha(0.06→0.02)` (or use a pale background with dark rim)
- `bottom_bar.dart` — glass gradient 0.08→0.03 → flip equivalent
- `message_input_bar.dart` — text field container uses `Colors.white.alpha(0.06)` border → `Colors.black.alpha(0.06)` border
- `conversation_list_row.dart` — separator line uses `Colors.white.alpha(0.06)` → `Colors.black.alpha(0.06)`

**Widgets using theme tokens (auto-flip, no changes needed):**

- `tab_chip.dart` — uses `HelloColors.recessed` + tab signature color
- `tab_header.dart` — uses `HelloColors.inkPrimary`
- `floating_avatar.dart` — uses `HelloColors.recessed` + `HelloColors.inkPrimary`
- `masonry_grid.dart` — no colors

## 10. Card flips

**Text-only cards with hardcoded white references:**

- `dm_card.dart` — `HelloColors.recessed` for avatar → auto-flip
- `group_card.dart` — same
- `decision_card_small.dart` — `HelloColors.accent` for vote buttons + eyebrow → auto-flip (Rausch unchanged)
- `ai_nudge_card.dart` — `HelloColors.focusAlpine` for accent → unchanged
- `settlement_card.dart` — `HelloColors.accent` for PAY button → unchanged
- `itinerary_card.dart` — `HelloColors.liveGreen` countdown → auto-flip to darker liveGreen
- `memory_card.dart` — uses theme tokens → auto-flip

**Hero cards with hardcoded light-text colors:**

- `decision_card_hero.dart` — `Color(0xFFF0EFF4)` for title/subtitle/meta → flip to `Color(0xFF1A1A1A)`
- `trip_card.dart` — same
- `focus_hero_card.dart` — same

All three also need the scrim gradient flipped and the darken overlay removed.

## 11. Success criteria

The migration is successful when:

1. `dart analyze lib/` returns 0 errors + 0 warnings
2. `flutter run -d chrome --web-port=8765` launches cleanly
3. Home feed renders on an off-white background with faint focus-tinted wash
4. All text is readable (dark ink on white)
5. Tap a DM card → sheet opens WITHOUT the red "No Material widget found" error
6. DM sheet shows real `ChatBubble` widgets (white glass, smart corners, dark text)
7. Long-press a chat bubble → emoji picker floats up
8. Swipe-left on a chat bubble → reply indicator fades in, spring snap-back on release
9. TabBar swipe across 4 tabs shows atmosphere wash lerping between the 4 signature colors (faintly — not a shouting color change)
10. Tab chip + bottom bar + floating avatar + top header all read as light-mode chrome
11. Rausch accent appears only in: unread count pills, CTA buttons, compose `+` icon tint, decision vote buttons. Nowhere else.
12. No dark color block anywhere on screen except:
    - Text
    - Dark-photographed regions of hero card backgrounds
    - User-interaction feedback (button press states)

## 12. Known limitations (acceptable for v1)

- Chat bubble `ChatBubble` widget uses hardcoded `_senderNames` lookup — not wired to the engine's profile fetcher
- Long-press emoji reaction is local state only (not persisted)
- Swipe-to-reply's `onReply` callback in `dm_sheet.dart` is a stub (v2: focuses the input with a reply context)
- Material wrapper on sheets is applied at the sheet root, not on individual TextFields — fine for v1
- Photo-backed hero cards on very light photos (e.g., Bali beach) may have low text contrast even with the white scrim
- Grain layer is deleted, not rebuilt — light grain reads as dirt, skipped
- All secondary/tertiary atmosphere washes draw at equal alpha regardless of tab state — could be further tuned but good enough for v1

---

**Next:** write the parallel implementation plan at `docs/superpowers/plans/2026-04-11-light-theme-migration.md` and dispatch 7 Wave 1 subagents.
