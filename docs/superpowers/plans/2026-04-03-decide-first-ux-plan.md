# Decide-First Group UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the React web DecisionBoard's Netflix-style swim lanes into the Flutter app as the default group interior view, with a summary header, [+] add flow, and gold burst consensus celebration.

**Architecture:** The Decide tab becomes index 0 in `SpaceLayout`'s `PageView`. A new `DecisionBoard` widget groups `DecisionItem`s by category and renders them as horizontal swim lane rails. A `GroupSummaryCard` sits above the rails. A FAB opens `AddItemSheet` to create items. `GoldBurstOverlay` fires particle animations when consensus crosses 80%.

**Tech Stack:** Flutter 3.x, Riverpod, e2ee_chat_sdk (DecisionItem, ChatEngineDecisions), Spring physics, CustomPainter for particles.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/lib/src/mock_data_seed.dart` | Expand to 15+ items per group (Bali, Sarah, Tokyo) |
| Modify | `app/lib/src/mock_chat_engine.dart` | Add `addDecisionItem()` method for [+] flow |
| Create | `app/lib/demov2/group_summary_card.dart` | Compact group pulse dashboard |
| Create | `app/lib/demov2/swim_lane_rail.dart` | Single horizontal card rail with vital label |
| Create | `app/lib/demov2/decision_board.dart` | Netflix orchestrator: groups items → renders rails |
| Create | `app/lib/demov2/add_item_sheet.dart` | Bottom sheet for adding new decision items |
| Create | `app/lib/demov2/gold_burst.dart` | Particle celebration overlay widget |
| Modify | `app/lib/demov2/space_layout.dart` | Flip tab order, wire DecisionBoard + FAB |

---

### Task 1: Expand Mock Data

**Files:**
- Modify: `app/lib/src/mock_data_seed.dart:217-253`

- [ ] **Step 1: Replace `buildDecisionItemsFor` with expanded data**

Replace the existing `buildDecisionItemsFor` method (lines 217-253) with this expanded version that generates 15 items for Bali, 8 for Sarah, and 12 for Tokyo:

```dart
  static List<DecisionItem> buildDecisionItemsFor(String groupId) {
    if (groupId == 'bali') {
      return [
        // ── Hotels (3) ──
        DecisionItem(
          id: 'item_bali_h1', groupId: 'bali', category: 'Hotels',
          title: 'The St. Regis Bali Resort',
          description: '\$750/night \u2022 5-star \u2022 Nusa Dua',
          state: 'locked', weightedScore: 10.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2', reactions: {'love': 'user_X'},
        ),
        DecisionItem(
          id: 'item_bali_h2', groupId: 'bali', category: 'Hotels',
          title: 'W Bali - Seminyak',
          description: '\$450/night \u2022 5-star \u2022 Seminyak',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.45,
          photoUrl: 'https://images.unsplash.com/photo-1542314831-c6a4d27ce66b?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user3',
        ),
        DecisionItem(
          id: 'item_bali_h3', groupId: 'bali', category: 'Hotels',
          title: 'The Mulia Bali',
          description: '\$680/night \u2022 5-star \u2022 Nusa Dua',
          state: 'voting', weightedScore: 1.0, agreementScore: 0.30,
          photoUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user4',
        ),
        // ── Experiences (3) ──
        DecisionItem(
          id: 'item_bali_e1', groupId: 'bali', category: 'Experiences',
          title: 'Mount Batur Sunrise Trek',
          description: '\$65/person \u2022 4 Hours',
          state: 'locked', weightedScore: 8.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user4',
        ),
        DecisionItem(
          id: 'item_bali_e2', groupId: 'bali', category: 'Experiences',
          title: 'Ubud Rice Terraces Tour',
          description: '\$45/person \u2022 Half day',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.60,
          photoUrl: 'https://images.unsplash.com/photo-1555400038-63f5ba517a47?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_bali_e3', groupId: 'bali', category: 'Experiences',
          title: 'Sunset Dinner Cruise',
          description: '\$120/person \u2022 3 Hours',
          state: 'voting', weightedScore: 1.0, agreementScore: 0.25,
          photoUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user3',
        ),
        // ── Flights (2) ──
        DecisionItem(
          id: 'item_bali_f1', groupId: 'bali', category: 'Flights',
          title: 'Singapore Airlines SQ938',
          description: '\$320 \u2022 SIN \u2192 DPS \u2022 08:20 AM',
          state: 'voting', weightedScore: 5.0, agreementScore: 0.70,
          photoUrl: 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_bali_f2', groupId: 'bali', category: 'Flights',
          title: 'Garuda Indonesia GA715',
          description: '\$280 \u2022 CGK \u2192 DPS \u2022 06:00 AM',
          state: 'voting', weightedScore: 2.0, agreementScore: 0.35,
          photoUrl: 'https://images.unsplash.com/photo-1569154941061-e231b4725ef1?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user4',
        ),
        // ── Dining (3) ──
        DecisionItem(
          id: 'item_bali_d1', groupId: 'bali', category: 'Dining',
          title: 'Locavore',
          description: 'Michelin-worthy tasting menu \u2022 Ubud',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.55,
          photoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_bali_d2', groupId: 'bali', category: 'Dining',
          title: 'Sardine',
          description: 'Farm-to-table rice paddy views \u2022 Seminyak',
          state: 'voting', weightedScore: 2.0, agreementScore: 0.40,
          photoUrl: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user3',
        ),
        DecisionItem(
          id: 'item_bali_d3', groupId: 'bali', category: 'Dining',
          title: 'Warung Babi Guling Ibu Oka',
          description: 'Legendary roast suckling pig \u2022 Ubud',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
        // ── Loose / New (4) ──
        DecisionItem(
          id: 'item_bali_l1', groupId: 'bali', category: 'Ideas',
          title: 'Beach Club Day Pass',
          description: 'Potato Head or Finns?',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_bali_l2', groupId: 'bali', category: 'Ideas',
          title: 'Surfboard Rental',
          description: 'Kuta Beach, full day',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'user3',
        ),
        DecisionItem(
          id: 'item_bali_l3', groupId: 'bali', category: 'Ideas',
          title: 'Group Spa Day',
          description: 'Traditional Balinese massage',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user4',
        ),
      ];
    } else if (groupId == 'sarah') {
      return [
        // ── Restaurants (3) ──
        DecisionItem(
          id: 'item_sarah_r1', groupId: 'sarah', category: 'Restaurants',
          title: 'Carbone (Private Room)',
          description: 'Michelin-starred Italian-American retro glamour.',
          state: 'voting', weightedScore: 8.0, agreementScore: 0.90,
          photoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'alice', reactions: {'love': 'me'},
        ),
        DecisionItem(
          id: 'item_sarah_r2', groupId: 'sarah', category: 'Restaurants',
          title: 'Balthazar',
          description: 'Classic French brasserie in SoHo.',
          state: 'voting', weightedScore: 1.0, agreementScore: 0.20,
          photoUrl: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_sarah_r3', groupId: 'sarah', category: 'Restaurants',
          title: 'Le Bernardin',
          description: 'World-class seafood. Special occasion perfect.',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'alice',
        ),
        // ── Gifts (3) ──
        DecisionItem(
          id: 'item_sarah_g1', groupId: 'sarah', category: 'Gifts',
          title: 'Aesop Departure Kit',
          description: 'Luxury travel skincare set',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.60,
          photoUrl: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_sarah_g2', groupId: 'sarah', category: 'Gifts',
          title: 'Concert Tickets (Billie Eilish)',
          description: 'MSG, 2 tickets, floor seats',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.45,
          photoUrl: 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'alice',
        ),
        DecisionItem(
          id: 'item_sarah_g3', groupId: 'sarah', category: 'Gifts',
          title: 'Custom Photo Book',
          description: 'Artifact Uprising hardcover',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'me',
        ),
        // ── Decorations (2) ──
        DecisionItem(
          id: 'item_sarah_d1', groupId: 'sarah', category: 'Decorations',
          title: 'Balloon Arch (Rose Gold)',
          description: 'Setup at venue 2hrs before',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'alice',
        ),
        DecisionItem(
          id: 'item_sarah_d2', groupId: 'sarah', category: 'Decorations',
          title: 'Custom Cake (Lady M)',
          description: 'Mille crepe, feeds 12',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
      ];
    } else if (groupId == 'tokyo') {
      return [
        DecisionItem(
          id: 'item_tokyo_h1', groupId: 'tokyo', category: 'Hotels',
          title: 'Park Hyatt Tokyo',
          description: '\$650/night \u2022 Lost in Translation vibes',
          state: 'voting', weightedScore: 18.0, agreementScore: 0.94,
          photoUrl: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_h2', groupId: 'tokyo', category: 'Hotels',
          title: 'Andaz Tokyo',
          description: '\$420/night \u2022 Toranomon Hills',
          state: 'voting', weightedScore: 8.0, agreementScore: 0.60,
          photoUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_h3', groupId: 'tokyo', category: 'Hotels',
          title: 'Hoshinoya Tokyo',
          description: '\$380/night \u2022 Traditional ryokan luxury',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.30,
          photoUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_tokyo_a1', groupId: 'tokyo', category: 'Experiences',
          title: 'TeamLab Borderless',
          description: 'Digital art museum \u2022 Odaiba',
          state: 'voting', weightedScore: 6.0, agreementScore: 0.67,
          photoUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85f82e?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_a2', groupId: 'tokyo', category: 'Experiences',
          title: 'Shibuya Crossing at Night',
          description: 'Rooftop photo session \u2022 Mag\'s Park',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.45,
          photoUrl: 'https://images.unsplash.com/photo-1532236204992-f5e82c553420?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_d1', groupId: 'tokyo', category: 'Dining',
          title: 'Sukiyabashi Jiro',
          description: '3-star Michelin sushi \u2022 Ginza',
          state: 'locked', weightedScore: 15.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'https://images.unsplash.com/photo-1553621042-f6e147245754?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_d2', groupId: 'tokyo', category: 'Dining',
          title: 'Ichiran Ramen',
          description: 'Solo booth ramen \u2022 Shinjuku',
          state: 'voting', weightedScore: 5.0, agreementScore: 0.55,
          photoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_tokyo_d3', groupId: 'tokyo', category: 'Dining',
          title: 'Robot Restaurant',
          description: 'Wild dinner show \u2022 Kabukicho',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1480796927426-f609979314bd?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_l1', groupId: 'tokyo', category: 'Ideas',
          title: 'Pocket WiFi Rental',
          description: 'Pick up at Narita',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_tokyo_l2', groupId: 'tokyo', category: 'Ideas',
          title: 'Suica Card vs Day Pass',
          description: 'Which metro strategy?',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_l3', groupId: 'tokyo', category: 'Ideas',
          title: 'Kyoto Day Trip',
          description: 'Shinkansen round trip \u2022 \$120',
          state: 'voting', weightedScore: 7.0, agreementScore: 0.50,
          photoUrl: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_l4', groupId: 'tokyo', category: 'Ideas',
          title: 'Akihabara Shopping Spree',
          description: 'Anime, tech, arcades',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'https://images.unsplash.com/photo-1524413840807-0c3cb6fa808d?q=80&w=800&auto=format&fit=crop',
          proposedBy: 'user2',
        ),
      ];
    }

    return [];
  }
```

- [ ] **Step 2: Verify the app still builds**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/src/mock_data_seed.dart`
Expected: No errors

- [ ] **Step 3: Update the heartbeat consensus target**

In `app/lib/src/mock_chat_engine.dart`, the heartbeat references `item_bali_1`. Update it to the new ID `item_bali_h1` (the St. Regis, which is now locked at 1.0 — so the heartbeat should target the W Bali `item_bali_h2` which is at 0.45 and can ramp up). Find the heartbeat section (around line 196-209) and change:

```dart
      // 3. Consensus Glow: Ramp Bali W Bali score toward ignition
      if (ticks % 3 == 0) {
        final items = _decisionCache['bali'];
        if (items != null) {
          int hotIdx = items.indexWhere((i) => i.id == 'item_bali_h2');
          if (hotIdx >= 0) {
            double oldScore = items[hotIdx].agreementScore;
            if (oldScore < 0.85) {
              items[hotIdx] = items[hotIdx].copyWith(
                agreementScore: min(1.0, oldScore + 0.1),
              );
            }
          }
        }
      }
```

- [ ] **Step 4: Copy changes to demov1 mirror**

The file `app/lib/demov1/mock_data_seed.dart` is a copy of `app/lib/src/mock_data_seed.dart`. Copy the same `buildDecisionItemsFor` replacement into `app/lib/demov1/mock_data_seed.dart:217-298`. Also update the heartbeat target in `app/lib/demov1/mock_chat_engine.dart` the same way.

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/mock_data_seed.dart app/lib/src/mock_chat_engine.dart app/lib/demov1/mock_data_seed.dart app/lib/demov1/mock_chat_engine.dart
git commit -m "feat: expand mock decision data to 15+ items per group"
```

---

### Task 2: Group Summary Card

**Files:**
- Create: `app/lib/demov2/group_summary_card.dart`

- [ ] **Step 1: Create the summary card widget**

```dart
import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';

class GroupSummaryCard extends StatelessWidget {
  final List<DecisionItem> items;

  const GroupSummaryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final locked = items.where((i) => i.isLocked).length;
    final voting = items.where((i) => !i.isLocked && i.agreementScore > 0).length;
    final fresh = items.where((i) => !i.isLocked && i.agreementScore == 0).length;

    // Find hottest unlocked item
    final unlocked = items.where((i) => !i.isLocked && i.agreementScore > 0).toList()
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    final hottest = unlocked.isNotEmpty ? unlocked.first : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HelloColors.recessed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left: counts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$voting active  \u00b7  $locked locked  \u00b7  $fresh new',
                  style: HelloTypography.label.copyWith(letterSpacing: 0.5),
                ),
                if (hottest != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: hottest.agreementScore >= 0.8
                              ? HelloColors.gold
                              : HelloColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${hottest.title} at ${(hottest.agreementScore * 100).toInt()}%',
                          style: HelloTypography.body.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Right: total count
          Text(
            '${items.length}',
            style: HelloTypography.hero.copyWith(
              color: HelloColors.accent,
              fontSize: 32,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/demov2/group_summary_card.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add app/lib/demov2/group_summary_card.dart
git commit -m "feat: add GroupSummaryCard for decide tab header"
```

---

### Task 3: Swim Lane Rail

**Files:**
- Create: `app/lib/demov2/swim_lane_rail.dart`

- [ ] **Step 1: Create the rail widget**

```dart
import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';
import '../widgets/action_card_widget.dart';

/// Vital label computed from items in a rail.
class _RailVital {
  final String label;
  final Color color;
  const _RailVital(this.label, this.color);
}

_RailVital _computeVital(List<DecisionItem> items) {
  final total = items.length;
  final rated = items.where((i) => i.agreementScore > 0).length;
  final sorted = List<DecisionItem>.from(items)
    ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
  final top = sorted.isNotEmpty ? sorted.first : null;

  if (top != null && top.agreementScore >= 0.8) {
    final pct = (top.agreementScore * 100).toInt();
    return _RailVital('$pct% on #1 \u00b7 $rated of $total', HelloColors.gold);
  }
  if (rated == 0) {
    return _RailVital('needs votes', HelloColors.seekingAmber);
  }
  return _RailVital('$rated of $total rated', HelloColors.accent);
}

class SwimLaneRail extends StatelessWidget {
  final String category;
  final List<DecisionItem> items;
  final void Function(DecisionItem item, String reaction) onReact;
  final void Function(DecisionItem item) onLock;

  const SwimLaneRail({
    super.key,
    required this.category,
    required this.items,
    required this.onReact,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth * 0.78;
    final cardHeight = screenHeight * 0.55;
    final vital = _computeVital(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.toLowerCase(),
                style: HelloTypography.spaceTitle,
              ),
              Text(
                vital.label,
                style: HelloTypography.hint.copyWith(
                  color: vital.color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Horizontal card scroll
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(right: index < items.length - 1 ? 12 : 0),
                child: SizedBox(
                  width: cardWidth,
                  child: ActionCardWidget(
                    item: item,
                    onReact: () => onReact(item, 'works_for_me'),
                    onPinCommit: () => onLock(item),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Collapsed locked rail — single line for trophies.
class LockedRailSummary extends StatelessWidget {
  final List<DecisionItem> items;

  const LockedRailSummary({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final first = items.first.title;
    final extra = items.length > 1 ? ' + ${items.length - 1} more' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: HelloColors.successGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text('locked', style: HelloTypography.label),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$first$extra',
              style: HelloTypography.hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/demov2/swim_lane_rail.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add app/lib/demov2/swim_lane_rail.dart
git commit -m "feat: add SwimLaneRail horizontal card rail widget"
```

---

### Task 4: Decision Board Orchestrator

**Files:**
- Create: `app/lib/demov2/decision_board.dart`

- [ ] **Step 1: Create the decision board orchestrator**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../main.dart'; // engineProvider
import '../theme.dart';
import 'group_summary_card.dart';
import 'swim_lane_rail.dart';

/// Category routing table — mirrors React DecisionBoard.tsx lines 726-759.
const _categoryLabels = <String, String>{
  'hotel': 'hotels',
  'hotels': 'hotels',
  'restaurant': 'restaurants',
  'restaurants': 'restaurants',
  'activity': 'things to do',
  'experience': 'experiences',
  'experiences': 'experiences',
  'flight': 'flights',
  'flights': 'flights',
  'dining': 'dining',
  'gifts': 'gifts',
  'decorations': 'decorations',
  'ideas': 'ideas',
};

String _routeCategory(DecisionItem item) {
  final cat = (item.category ?? 'ideas').toLowerCase();
  return _categoryLabels[cat] ?? cat;
}

class DecisionBoard extends ConsumerWidget {
  final String groupId;

  const DecisionBoard({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineProvider);
    final engineDecisions = engine as ChatEngineDecisions;

    return FutureBuilder<List<DecisionItem>>(
      future: engineDecisions.getDecisionItems(groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: HelloColors.accent),
          );
        }

        final allItems = snapshot.data!;
        if (allItems.isEmpty) {
          return const Center(
            child: Text('No items yet. Tap + to add one.', style: HelloTypography.hint),
          );
        }

        // Separate locked items
        final lockedItems = allItems.where((i) => i.isLocked).toList();
        final activeItems = allItems.where((i) => !i.isLocked).toList();

        // Group active items by category
        final Map<String, List<DecisionItem>> grouped = {};
        for (final item in activeItems) {
          final key = _routeCategory(item);
          grouped.putIfAbsent(key, () => []).add(item);
        }

        // Sort each group by weighted score desc, then agreement score desc
        for (final list in grouped.values) {
          list.sort((a, b) {
            final ws = b.weightedScore.compareTo(a.weightedScore);
            if (ws != 0) return ws;
            return b.agreementScore.compareTo(a.agreementScore);
          });
        }

        // Sort groups by total weighted score desc
        final sortedKeys = grouped.keys.toList()
          ..sort((a, b) {
            final totalA = grouped[a]!.fold<double>(0, (s, i) => s + i.weightedScore);
            final totalB = grouped[b]!.fold<double>(0, (s, i) => s + i.weightedScore);
            return totalB.compareTo(totalA);
          });

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              GroupSummaryCard(items: allItems),

              // Locked trophies (collapsed)
              if (lockedItems.isNotEmpty)
                LockedRailSummary(items: lockedItems),

              // Category swim lanes
              for (final key in sortedKeys)
                SwimLaneRail(
                  category: key,
                  items: grouped[key]!,
                  onReact: (item, reaction) {
                    engineDecisions.reactToItem(item.id, reaction);
                  },
                  onLock: (item) {
                    engineDecisions.lockItem(
                      item.id,
                      CommitmentProof(type: 'mock', value: 'booked', submittedBy: 'me'),
                    );
                  },
                ),

              const SizedBox(height: 100), // Bottom padding for FAB
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/demov2/decision_board.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add app/lib/demov2/decision_board.dart
git commit -m "feat: add DecisionBoard Netflix swim lane orchestrator"
```

---

### Task 5: Add Item Sheet

**Files:**
- Create: `app/lib/demov2/add_item_sheet.dart`
- Modify: `app/lib/src/mock_chat_engine.dart`

- [ ] **Step 1: Add `addDecisionItem` to MockChatEngine**

In `app/lib/src/mock_chat_engine.dart`, add this method inside the `MockChatEngine` class (after `getDecisionItems`, around line 300):

```dart
  void addDecisionItem(String groupId, {required String title, String? category, String? photoUrl}) {
    final item = DecisionItem(
      id: 'item_user_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      title: title,
      category: category ?? 'Ideas',
      state: 'proposed',
      agreementScore: 0.0,
      weightedScore: 0.0,
      photoUrl: photoUrl,
      proposedBy: 'me',
    );
    _decisionCache.putIfAbsent(groupId, () => []);
    _decisionCache[groupId]!.add(item);
  }
```

Also add the same method to `app/lib/demov1/mock_chat_engine.dart`.

- [ ] **Step 2: Create the add item bottom sheet**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class AddItemSheet extends StatefulWidget {
  final String groupId;
  final void Function(String title, String category, String photoUrl) onSubmit;

  const AddItemSheet({
    super.key,
    required this.groupId,
    required this.onSubmit,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _previewUrl;

  static const _demoImages = [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=800&auto=format&fit=crop',
  ];

  void _pickImage() {
    // Demo mode: pick a random Unsplash image
    setState(() {
      _previewUrl = _demoImages[Random().nextInt(_demoImages.length)];
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final category = _categoryController.text.trim().isEmpty
        ? 'Ideas'
        : _categoryController.text.trim();
    final photo = _previewUrl ?? '';

    widget.onSubmit(title, category, photo);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _titleController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HelloColors.inkTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Text('add to decide', style: HelloTypography.body),
          const SizedBox(height: 16),

          // Image zone
          GestureDetector(
            onTap: _pickImage,
            child: _previewUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(_previewUrl!, fit: BoxFit.cover),
                    ),
                  )
                : Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: HelloColors.recessed,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HelloColors.inkTertiary.withValues(alpha: 0.2),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28, color: HelloColors.inkTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 6),
                        Text(
                          'tap to add photo',
                          style: HelloTypography.hint.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Title input
          TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            style: HelloTypography.body.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'what is this?',
              hintStyle: HelloTypography.hint,
              filled: true,
              fillColor: HelloColors.recessed,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // Category input
          TextField(
            controller: _categoryController,
            style: HelloTypography.body.copyWith(fontSize: 13, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              hintText: 'category (e.g. hotels, decorations)',
              hintStyle: HelloTypography.hint.copyWith(fontSize: 13),
              filled: true,
              fillColor: HelloColors.recessed,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // Submit
          GestureDetector(
            onTap: canSubmit ? _submit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canSubmit ? HelloColors.accent : HelloColors.recessed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'add to decide',
                  style: HelloTypography.body.copyWith(
                    fontSize: 14,
                    color: canSubmit ? Colors.white : HelloColors.inkTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify both files compile**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/demov2/add_item_sheet.dart lib/src/mock_chat_engine.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add app/lib/demov2/add_item_sheet.dart app/lib/src/mock_chat_engine.dart app/lib/demov1/mock_chat_engine.dart
git commit -m "feat: add AddItemSheet bottom sheet and mock engine addDecisionItem"
```

---

### Task 6: Gold Burst Celebration

**Files:**
- Create: `app/lib/demov2/gold_burst.dart`

- [ ] **Step 1: Create the gold burst overlay widget**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// A single particle in the gold burst animation.
class _Particle {
  final double angle;
  final double velocity;
  final double size;
  final double opacity;

  _Particle()
      : angle = Random().nextDouble() * 2 * pi,
        velocity = 200 + Random().nextDouble() * 300,
        size = 4 + Random().nextDouble() * 8,
        opacity = 0.6 + Random().nextDouble() * 0.4;
}

/// CustomPainter that draws exploding gold particles.
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0.0 → 1.0

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();

    for (final p in particles) {
      final distance = p.velocity * progress;
      final dx = center.dx + cos(p.angle) * distance;
      final dy = center.dy + sin(p.angle) * distance;
      final currentSize = p.size * (1.0 - progress * 0.7);
      final currentOpacity = p.opacity * (1.0 - progress);

      paint.color = HelloColors.gold.withValues(alpha: currentOpacity);
      canvas.drawCircle(Offset(dx, dy), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

/// Overlay widget that plays the gold burst animation.
/// Wrap an ActionCardWidget in a Stack with this overlay positioned on top.
class GoldBurstOverlay extends StatefulWidget {
  /// Set to true to trigger the animation. Resets when set back to false.
  final bool trigger;
  final Widget child;

  const GoldBurstOverlay({
    super.key,
    required this.trigger,
    required this.child,
  });

  @override
  State<GoldBurstOverlay> createState() => _GoldBurstOverlayState();
}

class _GoldBurstOverlayState extends State<GoldBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = List.generate(40, (_) => _Particle());
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(GoldBurstOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !_hasPlayed) {
      _fire();
    }
  }

  void _fire() {
    _hasPlayed = true;
    HapticFeedback.heavyImpact();
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The card itself, with animated gold border
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final borderProgress = (_controller.value * 2.5).clamp(0.0, 1.0);
            final glowProgress = _controller.value < 0.5
                ? (_controller.value * 2.0)
                : (1.0 - (_controller.value - 0.5) * 1.0).clamp(0.0, 1.0);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: _hasPlayed
                    ? Border.all(
                        color: HelloColors.gold.withValues(alpha: borderProgress * 0.8),
                        width: 2,
                      )
                    : null,
                boxShadow: _hasPlayed
                    ? [
                        BoxShadow(
                          color: HelloColors.gold.withValues(alpha: glowProgress * 0.3),
                          blurRadius: 20 + glowProgress * 10,
                          spreadRadius: glowProgress * 4,
                        ),
                      ]
                    : [],
              ),
              child: widget.child,
            );
          },
        ),

        // Particle layer
        if (_hasPlayed)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  if (_controller.value >= 1.0) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/demov2/gold_burst.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add app/lib/demov2/gold_burst.dart
git commit -m "feat: add GoldBurstOverlay particle celebration animation"
```

---

### Task 7: Rewire Space Layout (Decide-First)

**Files:**
- Modify: `app/lib/demov2/space_layout.dart`

- [ ] **Step 1: Replace the entire space_layout.dart**

Replace the contents of `app/lib/demov2/space_layout.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';
import '../main.dart'; // engineProvider
import 'chat_view.dart';
import 'decision_board.dart';
import 'add_item_sheet.dart';

class SpaceLayout extends ConsumerStatefulWidget {
  final String spaceId;
  final String spaceTitle;
  const SpaceLayout({super.key, required this.spaceId, required this.spaceTitle});

  @override
  ConsumerState<SpaceLayout> createState() => _SpaceLayoutState();
}

class _SpaceLayoutState extends ConsumerState<SpaceLayout> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(); // Starts at 0 = Decide
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutExpo,
    );
  }

  void _openAddSheet() {
    final engine = ref.read(engineProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelloColors.chrome,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddItemSheet(
        groupId: widget.spaceId,
        onSubmit: (title, category, photoUrl) {
          // Cast to access addDecisionItem on mock engine
          if (engine is dynamic) {
            (engine as dynamic).addDecisionItem(
              widget.spaceId,
              title: title,
              category: category,
              photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
            );
          }
          // Force rebuild by triggering setState
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Rail
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: HelloColors.inkSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  // Decide tab (index 0)
                  GestureDetector(
                    onTap: () => _onTabTapped(0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentIndex == 0 ? 1.0 : 0.4,
                      child: const Text('Decide', style: HelloTypography.spaceTitle),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Chat tab (index 1)
                  GestureDetector(
                    onTap: () => _onTabTapped(1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentIndex == 1 ? 1.0 : 0.4,
                      child: const Text('Chat', style: HelloTypography.spaceTitle),
                    ),
                  ),
                  const Spacer(),
                  // Group title (subtle)
                  Text(
                    widget.spaceTitle,
                    style: HelloTypography.hint.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    physics: const ClampingScrollPhysics(),
                    children: [
                      // Index 0: Decide (default)
                      DecisionBoard(groupId: widget.spaceId),
                      // Index 1: Chat
                      ProviderScope(
                        overrides: const [],
                        child: ClipRRect(
                          child: ChatView(spaceId: widget.spaceId),
                        ),
                      ),
                    ],
                  ),

                  // FAB — only visible on Decide tab
                  if (_currentIndex == 0)
                    Positioned(
                      right: 20,
                      bottom: 24,
                      child: GestureDetector(
                        onTap: _openAddSheet,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: HelloColors.accent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: HelloColors.accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.add, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/demov2/space_layout.dart`
Expected: No errors

- [ ] **Step 3: Verify the app builds**

Run: `cd /Users/ramchitturi/hello/app && flutter build web --no-pub`
Expected: Build succeeds (or at minimum, no errors in the demov2 files)

- [ ] **Step 4: Commit**

```bash
git add app/lib/demov2/space_layout.dart
git commit -m "feat: rewire SpaceLayout to decide-first with FAB and swim lanes"
```

---

### Task 8: Integration — Wire Gold Burst into ActionCardWidget

**Files:**
- Modify: `app/lib/widgets/action_card_widget.dart`

- [ ] **Step 1: Add gold burst import and wrap the card**

At the top of `app/lib/widgets/action_card_widget.dart`, add the import:

```dart
import '../demov2/gold_burst.dart';
```

Then in the `build` method of `_ActionCardWidgetState` (around line 66), wrap the existing `Container` return value with `GoldBurstOverlay`:

Replace:
```dart
    return Container(
      decoration: BoxDecoration(
```

With:
```dart
    return GoldBurstOverlay(
      trigger: isIgnited,
      child: Container(
        decoration: BoxDecoration(
```

And add the closing parenthesis for `GoldBurstOverlay` at the end of the build method. The `Container` return (currently ending around line 180 with `);`) becomes:

```dart
        ),  // ClipRRect
      ),  // Container
    );  // GoldBurstOverlay
```

- [ ] **Step 2: Do the same for the demov1 copy**

In `app/lib/demov1/action_card_widget.dart`, add the same import and wrapping. The import path is:

```dart
import '../demov2/gold_burst.dart';
```

- [ ] **Step 3: Verify both files compile**

Run: `cd /Users/ramchitturi/hello/app && flutter analyze lib/widgets/action_card_widget.dart lib/demov1/action_card_widget.dart`
Expected: No errors

- [ ] **Step 4: Run the app to visually verify**

Run: `cd /Users/ramchitturi/hello/app && flutter run -d chrome`

Verify:
1. Home screen loads normally
2. Tapping a group opens to the **Decide** tab (not Chat)
3. Horizontal swim lanes visible with category headers
4. Summary card shows at top with item counts
5. Swiping right reveals Chat tab
6. [+] FAB visible, opens bottom sheet
7. Adding an item from sheet creates a new card in the board
8. Cards with score >= 80% show gold glow effect

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/action_card_widget.dart app/lib/demov1/action_card_widget.dart
git commit -m "feat: integrate GoldBurstOverlay into ActionCardWidget"
```

---

## Self-Review

**Spec coverage:**
- Section 1 (Layout flip) → Task 7
- Section 2 (Summary Card) → Task 2
- Section 3a-3e (Swim Lanes) → Tasks 3 + 4
- Section 4 (Add Item) → Task 5
- Section 5 (Gold Burst) → Tasks 6 + 8
- Section 6 (Mock Data) → Task 1
- Section 7 (Theme) → No changes needed (confirmed)
- Constraints (No-Bold, Iron Rule, Spring, No elevation) → Enforced in all widgets

**Placeholder scan:** No TBD/TODO found. All code blocks are complete.

**Type consistency:**
- `DecisionItem` properties (`id`, `groupId`, `category`, `title`, `agreementScore`, `weightedScore`, `isLocked`, `photoUrl`, `proposedBy`, `reactions`, `state`, `description`) used consistently across all tasks
- `SwimLaneRail` constructor params (`category`, `items`, `onReact`, `onLock`) match usage in `DecisionBoard`
- `AddItemSheet.onSubmit` signature `(String title, String category, String photoUrl)` matches `MockChatEngine.addDecisionItem` parameters
- `GoldBurstOverlay` `trigger` parameter matches `isIgnited` in `ActionCardWidget`
