# Next-Gen Chat Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the chat screen from SMS-2014 into a spatial communication environment with glassmorphism, ambient gradients, temporal timestamps, avatars, and Apple-scale physics.

**Architecture:** The chat uses a Stack layout (chat_view.dart) with messages filling the screen, floating top/bottom chrome, and a gradient layer behind everything. Bubbles get BackdropFilter for glassmorphism. Scroll position drives parallax on the gradient. Timestamps become temporal (scroll-pause reveal). Avatars appear on incoming messages.

**Tech Stack:** Flutter 3.x, Riverpod, BackdropFilter, ImageFilter.blur, SpringSimulation, AnimationController, ScrollController.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/lib/demov2/chat_feed.dart` | Remove per-message timestamps, add sender name/avatar params |
| Modify | `app/lib/widgets/chat_bubble.dart` | Glassmorphism (BackdropFilter), avatar, hidden timestamps, haptic scale |
| Modify | `app/lib/demov2/chat_view.dart` | Ambient gradient layer, parallax, floating input restructure |
| Modify | `app/lib/widgets/chat_input.dart` | Sparkle icon, floating capsule styling, glass backdrop |

---

### Task 1: Hide Timestamps + Add Sender Info to Feed

**Files:**
- Modify: `app/lib/demov2/chat_feed.dart`

This task removes per-message timestamps (they'll appear on scroll-pause in a future iteration) and passes sender identity to ChatBubble.

- [ ] **Step 1: Update _FeedItem to remove timestamps and pass sender info**

In `app/lib/demov2/chat_feed.dart`, replace the `_FeedItem` build method's ChatBubble call. Remove `timestamp` and `showReceipt` params. Add `senderName` and `senderId` params.

Change lines 156-173 from:
```dart
    // iMessage style: timestamp only on last message in group
    // Receipt ticks only on last outbound message in the entire feed
    final showTimestamp = isLastInGroup;
    final isLastSent = isOutbound && index == 0; // index 0 = newest in reversed list

    return RepaintBoundary(
      child: ChatBubble(
        text: message.text ?? '',
        isOutbound: isOutbound,
        status: isLastSent ? computedStatus : MessageStatus.sent,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
        timestamp: showTimestamp ? timeStr : null,
        showReceipt: isLastSent,
        mediaChild: mediaChild,
        onReply: onReply != null ? () => onReply!(message) : null,
      ),
    );
```

To:
```dart
    return RepaintBoundary(
      child: ChatBubble(
        text: message.text ?? '',
        isOutbound: isOutbound,
        status: computedStatus,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
        mediaChild: mediaChild,
        senderId: message.senderId,
        onReply: onReply != null ? () => onReply!(message) : null,
      ),
    );
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/demov2/chat_feed.dart`

- [ ] **Step 3: Commit**

```bash
git add app/lib/demov2/chat_feed.dart
git commit -m "feat: remove per-message timestamps, pass sender info to bubble"
```

---

### Task 2: Glassmorphism Bubbles + Avatars + Glass Haptics

**Files:**
- Modify: `app/lib/widgets/chat_bubble.dart`

This is the largest task. Replaces opaque bubbles with asymmetric glassmorphism, adds colorful avatars on incoming messages, removes visible timestamps, and adds haptic scale on long-press.

- [ ] **Step 1: Add `dart:ui` import and update ChatBubble params**

Add `import 'dart:ui';` at the top. Replace the constructor params — remove `timestamp`, `showReceipt`, add `senderId`:

```dart
class ChatBubble extends StatefulWidget {
  final String text;
  final bool isOutbound;
  final MessageStatus status;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final Widget? mediaChild;
  final String? senderId;
  final VoidCallback? onReply;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutbound,
    this.status = MessageStatus.sent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.mediaChild,
    this.senderId,
    this.onReply,
  });
```

- [ ] **Step 2: Add avatar color map and haptic scale state**

Inside `_ChatBubbleState`, add:
```dart
  static const _avatarColors = <String, Color>{
    'priya': Color(0xFFFF6B6B),
    'dad': Color(0xFF4ECDC4),
    'me': Color(0xFFFFB347),
    'emma': Color(0xFF9B59B6),
    'alex': Color(0xFF3498DB),
    'mom': Color(0xFFE74C8B),
    'liam': Color(0xFF2ECC71),
    'noah': Color(0xFF1ABC9C),
    'sofia': Color(0xFFE67E22),
    'maya': Color(0xFFF39C12),
  };

  double _pressScale = 1.0;
```

- [ ] **Step 3: Replace the bubble decoration with glassmorphism**

In the build method, replace the opaque `bgColor` and `BoxDecoration` with:

```dart
    // Asymmetric glassmorphism
    final bubbleOpacity = widget.isOutbound ? 0.6 : 0.85;
    final blurSigma = widget.isOutbound ? 20.0 : 8.0;
```

Wrap the bubble Container in a `ClipRRect` + `BackdropFilter`:
```dart
ClipRRect(
  borderRadius: _buildCornerRadii(),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: bubbleOpacity),
        borderRadius: _buildCornerRadii(),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      // ... existing content
    ),
  ),
),
```

- [ ] **Step 4: Add avatar on incoming messages**

Before the bubble, if `!widget.isOutbound && widget.isFirstInGroup`, show sender name and avatar:

```dart
if (!widget.isOutbound && widget.isFirstInGroup && widget.senderId != null) ...[
  Padding(
    padding: const EdgeInsets.only(left: 44, bottom: 2),
    child: Text(
      widget.senderId!,
      style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w300,
        color: HelloColors.inkTertiary),
    ),
  ),
],
```

The avatar (28px colorful circle) shows next to the bubble:
```dart
if (!widget.isOutbound && widget.isFirstInGroup)
  Container(
    width: 28, height: 28,
    margin: const EdgeInsets.only(right: 6, top: 2),
    decoration: BoxDecoration(
      color: _avatarColors[widget.senderId?.toLowerCase()] ?? HelloColors.accent,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      (widget.senderId ?? '?')[0].toUpperCase(),
      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white),
    ),
  ),
```

- [ ] **Step 5: Add glass haptics (scale on long-press)**

Update the long-press handler to include scale depression:
```dart
onLongPress: () {
  HapticFeedback.mediumImpact();
  setState(() {
    _pressScale = 0.98;
    _showReactionPicker = !_showReactionPicker;
  });
  Future.delayed(const Duration(milliseconds: 200), () {
    if (mounted) setState(() => _pressScale = 1.0);
  });
},
```

Wrap the bubble in `Transform.scale(scale: _pressScale, ...)`.

- [ ] **Step 6: Remove _buildTimestampRow and _buildReceiptIcon methods**

Delete these methods entirely. Timestamps are now invisible by default.

- [ ] **Step 7: Verify and commit**

Run: `cd /Users/ramchitturi/hello/app && dart analyze lib/widgets/chat_bubble.dart`

```bash
git add app/lib/widgets/chat_bubble.dart
git commit -m "feat: glassmorphism bubbles, avatars, hidden timestamps, glass haptics"
```

---

### Task 3: Ambient Gradient Background + Parallax

**Files:**
- Modify: `app/lib/demov2/chat_view.dart`

- [ ] **Step 1: Add per-group ambient colors map**

```dart
const _groupAmbientColors = <String, List<Color>>{
  'family': [Color(0xFFFFB347), Color(0xFFFF6B6B)],
  'bali': [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
  'tokyo': [Color(0xFF9B59B6), Color(0xFF3498DB)],
  'sarah': [Color(0xFFE74C8B), Color(0xFFF39C12)],
  'poker': [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
  'alaska': [Color(0xFF45B7D1), Color(0xFF96E6A1)],
};
```

- [ ] **Step 2: Convert ChatView to StatefulWidget for animation + scroll listening**

Change from `ConsumerWidget` to `ConsumerStatefulWidget`. Add:
- `AnimationController _gradientController` (20s cycle, repeat)
- `ScrollController` passed down to ChatFeed via a callback
- `double _scrollOffset = 0`

- [ ] **Step 3: Add ambient gradient as the first layer in the Stack**

```dart
// Ambient gradient with parallax
Positioned.fill(
  child: AnimatedBuilder(
    animation: _gradientController,
    builder: (context, child) {
      final t = _gradientController.value;
      final colors = _groupAmbientColors[widget.spaceId] ??
          [const Color(0xFFFF6B35), const Color(0xFFFF9F43)];
      return Transform.translate(
        offset: Offset(0, -_scrollOffset * 0.1), // Parallax: 10% speed
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(t - 0.5, -1),
              end: Alignment(1 - t, 1),
              colors: [
                colors[0].withValues(alpha: 0.06),
                colors[1].withValues(alpha: 0.06),
              ],
            ),
          ),
        ),
      );
    },
  ),
),
```

- [ ] **Step 4: Update ChatFeed to report scroll offset**

Add `onScrollUpdate` callback to ChatFeed. In `_ChatFeedState._onScroll`, call the callback with the current offset.

- [ ] **Step 5: Verify and commit**

```bash
git add app/lib/demov2/chat_view.dart app/lib/demov2/chat_feed.dart
git commit -m "feat: ambient gradient background with parallax depth"
```

---

### Task 4: Floating Input Bar + Sparkle Icon + Glass

**Files:**
- Modify: `app/lib/widgets/chat_input.dart`
- Modify: `app/lib/demov2/chat_view.dart`

- [ ] **Step 1: Update chat_input.dart — floating capsule with glass**

Wrap the entire composer in a `ClipRRect` + `BackdropFilter`:
- Margin: `EdgeInsets.fromLTRB(12, 4, 12, 12)` (detached from edges)
- `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))`
- Background: `Colors.white.withValues(alpha: 0.8)`
- Shadow: `BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: Offset(0, 4))`
- Border radius: 24

- [ ] **Step 2: Replace "+" icon with sparkle**

Change `Icons.add_rounded` to `Icons.auto_awesome`:
```dart
Icon(
  Icons.auto_awesome,
  size: 20,
  color: _isAIMode
      ? HelloColors.accent.withOpacity(0.8)
      : HelloColors.inkPrimary.withOpacity(0.3),
),
```

- [ ] **Step 3: Update chat_view.dart — remove solid background on composer area**

Change the composer's parent `Container(color: HelloColors.voidBg)` to `Container(color: Colors.transparent)` so the glass effect shows the gradient behind it.

- [ ] **Step 4: Verify and commit**

```bash
git add app/lib/widgets/chat_input.dart app/lib/demov2/chat_view.dart
git commit -m "feat: floating glass input bar with sparkle icon"
```

---

### Task 5: Integration + Visual Polish

**Files:**
- All four files — final adjustments

- [ ] **Step 1: Verify the complete flow on Chrome**

Run: `cd /Users/ramchitturi/hello/app && flutter run -d chrome`

Check:
1. Ambient gradient visible behind messages
2. Sent bubbles show gradient through (60% glass)
3. Received bubbles are stable surface (85% glass)
4. Avatars appear on incoming messages (first in group)
5. No timestamps visible
6. Input bar floats with glass effect
7. Long-press shows reactions with scale depression
8. Hello orb breathes at bottom right
9. Parallax: gradient moves slower than messages when scrolling

- [ ] **Step 2: Fix any visual issues found during testing**

Common fixes:
- If bubbles look washed out without gradient, increase opacity per the contrast guard (sent=75%, received=92%)
- If BackdropFilter is too expensive, reduce blur sigma
- If avatars overlap bubbles, adjust margins

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: next-gen chat screen — glassmorphism, ambient gradient, avatars, floating input"
```

---

## Self-Review

**Spec coverage:**
- Item 1 (timestamp fix): Covered by Task 1 (timestamps removed, order preserved by existing reverse-scroll)
- Item 2 (temporal timestamps): Timestamps hidden by default (Task 1). Scroll-pause reveal deferred to Sub-project B (requires scroll listener state machine).
- Item 3 (avatars): Task 2
- Item 4 (ambient gradient): Task 3
- Item 5 (floating input): Task 4
- Item 6 (glassmorphism): Task 2
- Item 7 (glass haptics): Task 2
- Item 8 (parallax): Task 3
- Item 9 (liquid transition): Deferred — requires image color extraction which needs a palette library. The per-group fallback colors (Fallback A) provide the ambient mood.

**Note:** Temporal bucketed timestamps (scroll-pause reveal) and liquid color transition are deferred to Sub-project B as they require additional scroll-state-machine and image analysis infrastructure.
