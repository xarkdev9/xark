# Next-Gen Chat Screen — Sub-project A

## Goal
Transform the chat from "SMS 2014" into a spatial communication environment. Six visual changes + three Apple-scale physics polish points.

---

## 1. Timestamp Fix (Critical Bug)
- Newest messages at bottom, directly above input bar
- Verify `ChatFeed` reverse-scroll renders newest-first correctly

## 2. Temporal Timestamps (Scroll-Pause Reveal)
- **Default:** Zero timestamps visible
- **Scroll pause (1s):** Floating time headers fade in with 10px Y-slide (magnetic snap, 250ms)
- **Temporal bucketing:**
  - Within 5 min → grouped under one header ("10:15 AM")
  - Over 1 hour apart → date header ("Yesterday", "Tuesday")
- **Scroll resume:** Headers fade out (200ms)
- **Precision escape:** Long-press bubble → exact time inline (secondary)

## 3. Avatars on Incoming Messages
- 28px colorful circles using `_avatarColors` map (Priya=coral, Dad=teal, etc.)
- Show on first message in sender group only
- Sender name 11px above first bubble in group
- Sent messages: no avatar, no name

## 4. Ambient Gradient Background (C → A → B)
- **Primary (C):** Extract dominant color from most recent image → 2-color mesh gradient at 8% opacity
- **Fallback (A):** Per-group identity colors:
  - Family = warm amber/rose (#FFB347 + #FF6B6B at 6%)
  - Bali = ocean teal (#4ECDC4 + #45B7D1 at 6%)
  - Tokyo = neon purple (#9B59B6 + #3498DB at 6%)
  - Sarah = soft pink (#E74C8B + #F39C12 at 6%)
- **Fallback (B):** Brand gradient (liquidFireStandard at 5% opacity)
- Gradient animates slowly (20s cycle, barely perceptible)
- **Parallax:** Gradient moves at 10% of scroll speed (spatial depth)
- **Liquid transition:** Color changes cross-fade over 800ms (ink-in-water feel)

## 5. Floating Input Bar
- Detached from bottom: 8px above safe area, 12px horizontal margins
- 24px rounded capsule (existing shape)
- Soft shadow: blur 20, alpha 0.08
- "+" → sparkle icon (`Icons.auto_awesome`) with breathing gradient
- Hello orb stays (already Liquid Fire breathing)
- **Glass effect:** Input bar gets BackdropFilter blur sigma 12, 80% opaque

## 6. Glassmorphism Bubbles (Asymmetric)
- **Sent (my messages):**
  - 60% opaque white
  - BackdropFilter blur sigma 20
  - Gradient shows through (immersive, "echo" feel)
- **Received (their messages):**
  - 85% opaque white
  - BackdropFilter blur sigma 8
  - High-contrast, stable reading surface ("signal" feel)
- **Dynamic contrast guard:**
  - No ambient gradient active → sent=75%, received=92%
- **Shadow anchor:** 1px inner stroke `Colors.white.withOpacity(0.3)` on all bubbles
- **No BoxShadow** — depth from glass only

---

## Apple-Scale Physics (3 Polish Points)

### 7. Glass Haptics
- Long-press bubble: light haptic tick + bubble scales to 98% (tactile depression)
- Release: spring back to 100% (200ms, damping 15)

### 8. Parallax Depth
- Ambient gradient layer scrolls at 10% of chat scroll speed
- Creates "floating window" effect — messages hover over vast glowing space
- Implementation: listen to ScrollController offset, apply `Transform.translate` to gradient at 0.1x

### 9. Liquid Transition
- When new image shared → dominant color extracted → gradient cross-fades over 800ms
- Use `ColorTween` + `AnimationController` for smooth interpolation
- Feels like ink dropping into water, not a snap

---

## Files

| Action | File | Changes |
|--------|------|---------|
| Modify | `chat_view.dart` | Ambient gradient layer with parallax, floating input restructure |
| Modify | `chat_feed.dart` | Scroll-pause timestamp detection, temporal bucketing |
| Modify | `chat_bubble.dart` | Glassmorphism (BackdropFilter), avatars, hidden timestamps, glass haptics |
| Modify | `chat_input.dart` | Sparkle icon, floating capsule, glass backdrop |

## Constraints
- **No-Bold mandate** — all text w400 max
- **No BoxShadow on bubbles** — glass creates depth
- **Readability is sacred** — contrast guard prevents washed text
- **Performance:** BackdropFilter is expensive — use `RepaintBoundary` on each bubble
- **Chat content untouched** — zero changes to message text, alignment, or order logic
