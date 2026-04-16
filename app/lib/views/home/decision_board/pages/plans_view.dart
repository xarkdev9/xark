import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../../../main.dart' show engineProvider;
import '../../../../theme.dart';
// action_card_widget removed during restructure

// ═══════════════════════════════════════════════════════
// 3-TIER PLANS VIEW
//
// Tier 1 (bottom): Events — horizontal scroll of event pills
// Tier 2 (middle): Categories — Overview, Recommendations, Flights, Hotels...
// Tier 3 (top):    Hero area — full detail cards or overview dashboard
//
// All tiers in thumb-arc range. No vertical scrolling through swim lanes.
// ═══════════════════════════════════════════════════════

/// Category icon map for Tier 2 pills.
const _categoryIcons = <String, IconData>{
  'overview': Icons.dashboard_outlined,
  'recommendations': Icons.auto_awesome,
  'hotels': Icons.hotel_outlined,
  'flights': Icons.flight_outlined,
  'experiences': Icons.explore_outlined,
  'dining': Icons.restaurant_outlined,
  'restaurants': Icons.restaurant_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'decorations': Icons.celebration_outlined,
  'ideas': Icons.lightbulb_outline,
  'things to do': Icons.local_activity_outlined,
  'cabs': Icons.local_taxi_outlined,
  'split': Icons.receipt_long_outlined,
};

IconData _iconFor(String category) =>
    _categoryIcons[category.toLowerCase()] ?? Icons.label_outline;

class PlansView extends ConsumerStatefulWidget {
  final String groupId;

  const PlansView({super.key, required this.groupId});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  int _selectedEventIndex = 0;
  int _selectedCategoryIndex = 0; // 0 = Overview, 1 = Recommendations, 2+ = dynamic

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final engineDecisions = engine as ChatEngineDecisions;

    return FutureBuilder<List<DecisionItem>>(
      future: engineDecisions.getDecisionItems(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: HelloColors.accent));
        }

        final allItems = snapshot.data!;
        if (allItems.isEmpty) {
          return const Center(
            child: Text('No plans yet. Tap + to start.', style: HelloText.hint),
          );
        }

        // ── Extract events (unique categories from items) ──
        final eventMap = <String, List<DecisionItem>>{};
        for (final item in allItems) {
          final event = item.category ?? 'General';
          eventMap.putIfAbsent(event, () => []).add(item);
        }

        // Sort events: most active first (by total weighted score)
        final eventNames = eventMap.keys.toList()
          ..sort((a, b) {
            final scoreA = eventMap[a]!.fold<double>(0, (s, i) => s + i.weightedScore);
            final scoreB = eventMap[b]!.fold<double>(0, (s, i) => s + i.weightedScore);
            return scoreB.compareTo(scoreA);
          });

        // Clamp selected index
        if (_selectedEventIndex >= eventNames.length) {
          _selectedEventIndex = 0;
        }

        final selectedEvent = eventNames[_selectedEventIndex];
        final eventItems = eventMap[selectedEvent]!;

        // ── Build categories for selected event ──
        // Always: Overview, Recommendations, then item-type categories
        final dynamicCategories = <String>[];
        // For now, items within an event are the options (all same "type")
        // Add "Split" as a virtual category
        dynamicCategories.add('Split');

        final allCategories = ['Overview', 'Recommendations', ...dynamicCategories];

        if (_selectedCategoryIndex >= allCategories.length) {
          _selectedCategoryIndex = 0;
        }

        final selectedCategory = allCategories[_selectedCategoryIndex];

        return Column(
          children: [
            // ═══ TIER 3: Hero Area (top — takes remaining space) ═══
            Expanded(
              child: _buildHeroArea(selectedCategory, selectedEvent, eventItems, engineDecisions),
            ),

            // ═══ TIER 2: Categories (middle) ═══
            _Tier2Categories(
              categories: allCategories,
              selectedIndex: _selectedCategoryIndex,
              onSelect: (idx) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategoryIndex = idx);
              },
            ),

            const SizedBox(height: 6),

            // ═══ TIER 1: Events (bottom — thumb arc) ═══
            _Tier1Events(
              eventNames: eventNames,
              eventMap: eventMap,
              selectedIndex: _selectedEventIndex,
              onSelect: (idx) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedEventIndex = idx;
                  _selectedCategoryIndex = 0; // Reset to Overview
                });
              },
            ),

            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildHeroArea(
    String category,
    String eventName,
    List<DecisionItem> items,
    ChatEngineDecisions engine,
  ) {
    if (category == 'Overview') {
      return _OverviewPage(eventName: eventName, items: items);
    }
    if (category == 'Recommendations') {
      return _RecommendationsPage(eventName: eventName, items: items);
    }
    if (category == 'Split') {
      return _SplitPage(eventName: eventName);
    }

    // Dynamic category — show items as hero cards
    return _HeroCardStream(
      items: items,
      onReact: (item, reaction) => engine.reactToItem(item.id, reaction),
      onLock: (item) => engine.lockItem(
        item.id, CommitmentProof(type: 'mock', value: 'booked', submittedBy: 'me'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 1: Events (bottom rail)
// ═══════════════════════════════════════════════════════

class _Tier1Events extends StatelessWidget {
  final List<String> eventNames;
  final Map<String, List<DecisionItem>> eventMap;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Tier1Events({
    required this.eventNames,
    required this.eventMap,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: HelloColors.inkPrimary.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: eventNames.length,
        itemBuilder: (context, index) {
          final name = eventNames[index];
          final items = eventMap[name]!;
          final isSelected = index == selectedIndex;
          final activeCount = items.where((i) => !i.isLocked).length;
          final lockedCount = items.where((i) => i.isLocked).length;
          final hottest = items.where((i) => !i.isLocked && i.agreementScore > 0).toList()
            ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
          final topScore = hottest.isNotEmpty ? hottest.first.agreementScore : 0.0;

          return Padding(
            padding: EdgeInsets.only(right: index < eventNames.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelloColors.inkPrimary.withValues(alpha: 0.08)
                      : HelloColors.recessed,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: HelloColors.inkPrimary.withValues(alpha: 0.15), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status dot
                    if (lockedCount == items.length)
                      Icon(Icons.check_circle, size: 10, color: HelloColors.successGreen)
                    else if (topScore >= 0.7)
                      Container(width: 8, height: 8, decoration: BoxDecoration(
                        color: HelloColors.accent, shape: BoxShape.circle,
                      ))
                    else
                      Container(width: 8, height: 8, decoration: BoxDecoration(
                        color: HelloColors.inkTertiary.withValues(alpha: 0.3), shape: BoxShape.circle,
                      )),
                    const SizedBox(width: 8),
                    // Event name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name.length > 16 ? '${name.substring(0, 14)}...' : name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isSelected ? HelloColors.inkPrimary : HelloColors.inkSecondary,
                          ),
                        ),
                        Text(
                          '$activeCount active${lockedCount > 0 ? ' · $lockedCount done' : ''}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w300,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 2: Categories (middle rail)
// ═══════════════════════════════════════════════════════

class _Tier2Categories extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Tier2Categories({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.only(right: index < categories.length - 1 ? 6 : 0),
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelloColors.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(cat),
                      size: 16,
                      color: isSelected ? HelloColors.accent : HelloColors.inkTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isSelected ? HelloColors.accent : HelloColors.inkSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 3: Hero Area — Overview Page
// ═══════════════════════════════════════════════════════

class _OverviewPage extends StatelessWidget {
  final String eventName;
  final List<DecisionItem> items;

  const _OverviewPage({required this.eventName, required this.items});

  @override
  Widget build(BuildContext context) {
    final locked = items.where((i) => i.isLocked).toList();
    final active = items.where((i) => !i.isLocked && i.agreementScore > 0).toList()
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    final fresh = items.where((i) => !i.isLocked && i.agreementScore == 0).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event header
          Text(
            eventName,
            style: HelloText.hero.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            '${items.length} items · ${locked.length} settled · ${active.length} voting · ${fresh.length} new',
            style: HelloText.hint.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Settled items (green checkmarks)
          if (locked.isNotEmpty) ...[
            Text('Settled', style: HelloText.label.copyWith(color: HelloColors.successGreen)),
            const SizedBox(height: 8),
            ...locked.map((item) => _OverviewRow(
              item: item,
              color: HelloColors.successGreen,
              trailing: 'done',
            )),
            const SizedBox(height: 20),
          ],

          // Hot items (needs attention)
          if (active.isNotEmpty) ...[
            Text('Needs votes', style: HelloText.label.copyWith(color: HelloColors.accent)),
            const SizedBox(height: 8),
            ...active.map((item) => _OverviewRow(
              item: item,
              color: HelloColors.accent,
              trailing: '${(item.agreementScore * 100).toInt()}%',
            )),
            const SizedBox(height: 20),
          ],

          // Fresh items (no votes yet)
          if (fresh.isNotEmpty) ...[
            Text('Just added', style: HelloText.label.copyWith(color: HelloColors.inkTertiary)),
            const SizedBox(height: 8),
            ...fresh.map((item) => _OverviewRow(
              item: item,
              color: HelloColors.inkTertiary,
              trailing: 'new',
            )),
          ],
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final DecisionItem item;
  final Color color;
  final String trailing;

  const _OverviewRow({required this.item, required this.color, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Thumbnail
          if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: item.photoUrl!.startsWith('assets/')
                    ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                    : Image.network(item.photoUrl!, fit: BoxFit.cover),
              ),
            )
          else
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.image_outlined, size: 20, color: HelloColors.inkTertiary),
            ),
          const SizedBox(width: 12),
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: HelloText.body.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null)
                  Text(
                    item.description!.split('\n').first,
                    style: HelloText.hint.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Score / status
          Text(
            trailing,
            style: HelloText.label.copyWith(color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 3: Hero Area — Recommendations Page
// ═══════════════════════════════════════════════════════

class _RecommendationsPage extends StatelessWidget {
  final String eventName;
  final List<DecisionItem> items;

  const _RecommendationsPage({required this.eventName, required this.items});

  @override
  Widget build(BuildContext context) {
    // Sort by agreement score — highest first (group's preference)
    final sorted = List<DecisionItem>.from(items)
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    final top3 = sorted.take(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: HelloColors.accent),
              const SizedBox(width: 8),
              Text(
                'Based on your group\'s votes',
                style: HelloText.body.copyWith(fontSize: 15, color: HelloColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (top3.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text('Vote on items to see recommendations', style: HelloText.hint),
              ),
            )
          else
            ...top3.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return _RecommendationCard(item: item, rank: idx + 1);
            }),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final DecisionItem item;
  final int rank;

  const _RecommendationCard({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final pct = (item.agreementScore * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rank == 1
            ? HelloColors.accent.withValues(alpha: 0.06)
            : HelloColors.recessed,
        borderRadius: BorderRadius.circular(16),
        border: rank == 1
            ? Border.all(color: HelloColors.accent.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Rank number
          Text(
            '#$rank',
            style: HelloText.hero.copyWith(
              fontSize: 28,
              color: rank == 1 ? HelloColors.accent : HelloColors.inkTertiary,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 16),
          // Photo
          if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56, height: 56,
                child: item.photoUrl!.startsWith('assets/')
                    ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                    : Image.network(item.photoUrl!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: HelloText.body.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null)
                  Text(
                    item.description!.split('\n').first,
                    style: HelloText.hint.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Score
          Text(
            '$pct%',
            style: HelloText.hero.copyWith(
              fontSize: 22,
              color: pct >= 80 ? HelloColors.accent : HelloColors.inkSecondary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 3: Hero Area — Split (Xpensly) Page
// ═══════════════════════════════════════════════════════

class _SplitPage extends StatelessWidget {
  final String eventName;

  const _SplitPage({required this.eventName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: HelloColors.inkTertiary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Expenses for $eventName', style: HelloText.body.copyWith(color: HelloColors.inkSecondary)),
          const SizedBox(height: 8),
          Text('No expenses yet', style: HelloText.hint),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 3: Hero Area — Card Stream (for specific categories)
// ═══════════════════════════════════════════════════════

class _HeroCardStream extends StatelessWidget {
  final List<DecisionItem> items;
  final void Function(DecisionItem, String) onReact;
  final void Function(DecisionItem) onLock;

  const _HeroCardStream({
    required this.items,
    required this.onReact,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<DecisionItem>.from(items)
      ..sort((a, b) {
        final ws = b.weightedScore.compareTo(a.weightedScore);
        if (ws != 0) return ws;
        return b.agreementScore.compareTo(a.agreementScore);
      });

    final screenWidth = MediaQuery.of(context).size.width;

    return PageView.builder(
      clipBehavior: Clip.none,
      controller: PageController(viewportFraction: 0.88),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: ActionCardWidget(
            item: item,
            onReact: () => onReact(item, 'works_for_me'),
            onPinCommit: () => onLock(item),
          ),
        );
      },
    );
  }
}
