import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../main.dart';
import '../theme.dart';
import '../src/mock_data_seed.dart';
import '../widgets/action_card_widget.dart';

// ═══════════════════════════════════════════════════════════════════
// 3-TIER PLANS VIEW — Correct Architecture
//
// TIER 1 (bottom): EVENTS within this group
//   - Single-event groups (Bali): shows group name as sole event
//   - Multi-event groups (Family): shows sub-events
//
// TIER 2 (thumb arc): CATEGORIES within selected event — DYNAMIC
//   - Always starts with Overview
//   - Then Recommendations (AI top picks)
//   - Then dynamic categories extracted from items (Hotels, Flights...)
//   - Ends with Split (Xpensly)
//
// TIER 3 (hero): Content
//   - Overview = dashboard (what's done, what's pending)
//   - Recommendations = top-voted items as Decision Cards
//   - Any category = Decision Cards with full voting
//   - Split = Xpensly expense page
//
// Rule: Overview is the ONLY dashboard. Everything else is Decision Cards.
// ═══════════════════════════════════════════════════════════════════

/// Icons for Tier 2 pills
const _categoryIcons = <String, IconData>{
  'overview': Icons.dashboard_outlined,
  'recommendations': Icons.auto_awesome,
  'hotels': Icons.hotel_outlined,
  'flights': Icons.flight_outlined,
  'experiences': Icons.explore_outlined,
  'dining': Icons.restaurant_outlined,
  'restaurants': Icons.restaurant_outlined,
  'destinations': Icons.place_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'decorations': Icons.celebration_outlined,
  'ideas': Icons.lightbulb_outline,
  'menu': Icons.menu_book_outlined,
  'venues': Icons.location_city_outlined,
  'contractors': Icons.construction_outlined,
  'plans': Icons.event_outlined,
  'shopping list': Icons.shopping_cart_outlined,
  'locations': Icons.photo_camera_outlined,
  'tasks': Icons.check_circle_outline,
  'cabs': Icons.local_taxi_outlined,
  'split': Icons.receipt_long_outlined,
};

IconData _iconFor(String cat) =>
    _categoryIcons[cat.toLowerCase()] ?? Icons.label_outline;

// ═══════════════════════════════════════════════════════
// MAIN WIDGET
// ═══════════════════════════════════════════════════════

class PlansView extends ConsumerStatefulWidget {
  final String groupId;
  const PlansView({super.key, required this.groupId});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  int _selectedEventIdx = 0;
  int _selectedCatIdx = 0;

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final engineDecisions = engine as ChatEngineDecisions;
    final groupName = MockDataSeed.displayNames[widget.groupId] ?? widget.groupId;

    return FutureBuilder<List<DecisionItem>>(
      future: engineDecisions.getDecisionItems(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: HelloColors.accent));
        }

        final allItems = snapshot.data!;
        if (allItems.isEmpty) {
          return const Center(
            child: Text('No plans yet. Tap + to start.', style: HelloTypography.hint),
          );
        }

        // ── Parse items: extract event and category from "Event|Category" format ──
        // If category contains "|", it's multi-event: "Hawaii (Maui)|Hotels"
        // If not, the category IS the Tier 2 category (single-event group like Bali)

        final bool hasDelimiter = allItems.any((i) => (i.category ?? '').contains('|'));

        late final List<String> eventNames;
        late final Map<String, List<DecisionItem>> eventItemsMap;

        if (hasDelimiter) {
          // Multi-event: parse "Event|Category"
          eventItemsMap = <String, List<DecisionItem>>{};
          for (final item in allItems) {
            final parts = (item.category ?? 'General|Items').split('|');
            final event = parts[0].trim();
            eventItemsMap.putIfAbsent(event, () => []).add(item);
          }
          eventNames = eventItemsMap.keys.toList()
            ..sort((a, b) {
              final sa = eventItemsMap[a]!.fold<double>(0, (s, i) => s + i.weightedScore);
              final sb = eventItemsMap[b]!.fold<double>(0, (s, i) => s + i.weightedScore);
              return sb.compareTo(sa);
            });
        } else {
          // Single-event: group name IS the event, item categories are Tier 2
          eventNames = [groupName];
          eventItemsMap = {groupName: allItems};
        }

        if (_selectedEventIdx >= eventNames.length) _selectedEventIdx = 0;
        final selectedEvent = eventNames[_selectedEventIdx];
        final eventItems = eventItemsMap[selectedEvent]!;

        // ── Build Tier 2: Categories (dynamic per selected event) ──
        final List<String> tier2Categories = ['Overview', 'Recommendations'];

        if (hasDelimiter) {
          // Extract sub-categories from "Event|Category" for this event
          final subCats = <String>{};
          for (final item in eventItems) {
            final parts = (item.category ?? '').split('|');
            if (parts.length > 1) subCats.add(parts[1].trim());
          }
          tier2Categories.addAll(subCats);
        } else {
          // Single-event: item.category IS the Tier 2 label (Hotels, Flights, etc.)
          final cats = <String>{};
          for (final item in eventItems) {
            cats.add(item.category ?? 'Ideas');
          }
          final sortedCats = cats.toList()
            ..sort((a, b) {
              final ca = eventItems.where((i) => i.category == a).length;
              final cb = eventItems.where((i) => i.category == b).length;
              return cb.compareTo(ca);
            });
          tier2Categories.addAll(sortedCats);
        }
        tier2Categories.add('Split');

        if (_selectedCatIdx >= tier2Categories.length) _selectedCatIdx = 0;
        final selectedCat = tier2Categories[_selectedCatIdx];

        // ── Get items for the selected Tier 2 category ──
        List<DecisionItem> catItems;
        if (_selectedCatIdx >= 2 && _selectedCatIdx < tier2Categories.length - 1) {
          if (hasDelimiter) {
            // Match by sub-category part after "|"
            catItems = eventItems.where((i) {
              final parts = (i.category ?? '').split('|');
              return parts.length > 1 && parts[1].trim() == selectedCat;
            }).toList();
          } else {
            catItems = eventItems.where((i) => i.category == selectedCat).toList();
          }
        } else {
          catItems = eventItems;
        }

        return Column(
          children: [
            // ═══ TIER 3: Hero Area ═══
            Expanded(
              child: _buildHero(selectedCat, selectedEvent, catItems, eventItems, engineDecisions),
            ),

            // ═══ TIER 2: Categories (thumb arc — bottom) ═══
            _CategoryRail(
              categories: tier2Categories,
              selectedIdx: _selectedCatIdx,
              onSelect: (idx) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCatIdx = idx);
              },
            ),

            // ═══ TIER 1: Events (above categories) ═══
            _EventRail(
              events: eventNames,
              eventItems: eventItemsMap,
              selectedIdx: _selectedEventIdx,
              onSelect: (idx) {
                HapticFeedback.selectionClick();
                setState(() { _selectedEventIdx = idx; _selectedCatIdx = 0; });
              },
            ),

            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  Widget _buildHero(
    String category,
    String eventName,
    List<DecisionItem> catItems,
    List<DecisionItem> allEventItems,
    ChatEngineDecisions engine,
  ) {
    // Overview = dashboard
    if (category == 'Overview') {
      return _OverviewDashboard(eventName: eventName, items: allEventItems);
    }

    // Split = Xpensly
    if (category == 'Split') {
      return _SplitPlaceholder(eventName: eventName);
    }

    // Recommendations = top-voted items as decision cards
    if (category == 'Recommendations') {
      final sorted = List<DecisionItem>.from(allEventItems)
        ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
      final topItems = sorted.where((i) => !i.isLocked).take(5).toList();
      return _DecisionCardStream(
        items: topItems,
        engine: engine,
        emptyMessage: 'Vote on items to see recommendations',
      );
    }

    // Any other category = Decision Cards with voting
    return _DecisionCardStream(
      items: catItems.where((i) => !i.isLocked).toList(),
      engine: engine,
      emptyMessage: 'All items settled',
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 1: Event Rail
// ═══════════════════════════════════════════════════════

class _EventRail extends StatelessWidget {
  final List<String> events;
  final Map<String, List<DecisionItem>> eventItems;
  final int selectedIdx;
  final ValueChanged<int> onSelect;

  const _EventRail({
    required this.events,
    required this.eventItems,
    required this.selectedIdx,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: HelloColors.inkPrimary.withValues(alpha: 0.05), width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: events.length,
        itemBuilder: (context, idx) {
          final name = events[idx];
          final items = eventItems[name]!;
          final isSelected = idx == selectedIdx;
          final doneCount = items.where((i) => i.isLocked).length;
          final allDone = doneCount == items.length;

          return Padding(
            padding: EdgeInsets.only(right: idx < events.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelloColors.inkPrimary.withValues(alpha: 0.07)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: HelloColors.inkPrimary.withValues(alpha: 0.12), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (allDone)
                      Icon(Icons.check_circle, size: 12, color: HelloColors.successGreen)
                    else
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: isSelected ? HelloColors.accent : HelloColors.inkTertiary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      name.length > 18 ? '${name.substring(0, 16)}...' : name,
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
                        color: isSelected ? HelloColors.inkPrimary : HelloColors.inkSecondary,
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
// TIER 2: Category Rail (thumb arc)
// ═══════════════════════════════════════════════════════

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final int selectedIdx;
  final ValueChanged<int> onSelect;

  const _CategoryRail({
    required this.categories,
    required this.selectedIdx,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length,
        itemBuilder: (context, idx) {
          final cat = categories[idx];
          final isSelected = idx == selectedIdx;

          return Padding(
            padding: EdgeInsets.only(right: idx < categories.length - 1 ? 4 : 0),
            child: GestureDetector(
              onTap: () => onSelect(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelloColors.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconFor(cat), size: 15,
                      color: isSelected ? HelloColors.accent : HelloColors.inkTertiary),
                    const SizedBox(width: 5),
                    Text(cat,
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
                        color: isSelected ? HelloColors.accent : HelloColors.inkSecondary,
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
// TIER 3: Next-Gen Overview (Soft UI + Spatial Depth)
//
// Design system: Soft UI Evolution + Spatial glass hints
// Visual: photo thumbnails integrated, soft shadows for depth,
// progress as ambient glow, avatar stacks, spring scale feedback
// ═══════════════════════════════════════════════════════

class _OverviewDashboard extends StatelessWidget {
  final String eventName;
  final List<DecisionItem> items;

  const _OverviewDashboard({required this.eventName, required this.items});

  String _subCategory(DecisionItem item) {
    final parts = (item.category ?? '').split('|');
    return parts.length > 1 ? parts[1].trim() : (item.category ?? 'General');
  }

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final settled = items.where((i) => i.isLocked).toList();
    final voting = items.where((i) => !i.isLocked && i.agreementScore > 0).toList()
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    final fresh = items.where((i) => !i.isLocked && i.agreementScore == 0).toList();
    final doneCount = settled.length;
    final progress = total > 0 ? doneCount / total : 0.0;

    // Group by sub-category
    final sectionMap = <String, List<DecisionItem>>{};
    for (final item in items) {
      sectionMap.putIfAbsent(_subCategory(item), () => []).add(item);
    }
    final sectionKeys = sectionMap.keys.toList()
      ..sort((a, b) {
        final wa = sectionMap[a]!.fold<double>(0, (s, i) => s + i.weightedScore);
        final wb = sectionMap[b]!.fold<double>(0, (s, i) => s + i.weightedScore);
        return wb.compareTo(wa);
      });

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ HEADER — event name + progress arc ═══
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eventName, style: HelloTypography.spaceTitle.copyWith(fontSize: 20)),
                      const SizedBox(height: 6),
                      // Mini stat row
                      Row(
                        children: [
                          _MiniStat('$doneCount', 'done', HelloColors.successGreen),
                          const SizedBox(width: 16),
                          _MiniStat('${voting.length}', 'voting', HelloColors.accent),
                          const SizedBox(width: 16),
                          _MiniStat('${fresh.length}', 'new', HelloColors.inkTertiary),
                        ],
                      ),
                    ],
                  ),
                ),
                // Progress ring with glow
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (progress >= 1.0 ? HelloColors.successGreen : HelloColors.accent)
                            .withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52, height: 52,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          backgroundColor: HelloColors.recessed,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? HelloColors.successGreen : HelloColors.accent,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
                          color: progress >= 1.0 ? HelloColors.successGreen : HelloColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ═══ SECTIONS ═══
          for (final sectionName in sectionKeys) ...[
            // Section header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    sectionName.toUpperCase(),
                    style: HelloTypography.label.copyWith(
                      color: HelloColors.inkTertiary,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      '+ add',
                      style: HelloTypography.hint.copyWith(
                        color: HelloColors.accent.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Items
            ..._sortedSection(sectionMap[sectionName]!).map((item) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: item.isLocked
                    ? _SettledCard(item: item)
                    : _ActiveCard(item: item),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  List<DecisionItem> _sortedSection(List<DecisionItem> items) {
    final s = items.where((i) => i.isLocked).toList();
    final a = items.where((i) => !i.isLocked).toList()
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    return [...s, ...a];
  }
}

/// Mini stat: number + label
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(
          fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400, color: color,
        )),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w300, color: color.withValues(alpha: 0.6),
        )),
      ],
    );
  }
}

// ── Active Card (Soft UI + thumbnail) ─────────────────

class _ActiveCard extends StatelessWidget {
  final DecisionItem item;
  const _ActiveCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = (item.agreementScore * 100).toInt();
    final isHot = item.agreementScore >= 0.7;
    final proposer = item.proposedBy ?? 'someone';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
          // Accent ambient glow for hot items
          if (isHot) BoxShadow(
            color: HelloColors.accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Thumbnail (left side, 80px)
            if (hasPhoto)
              SizedBox(
                width: 80,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: item.photoUrl!.startsWith('assets/')
                      ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                      : Image.network(item.photoUrl!, fit: BoxFit.cover),
                ),
              ),
            // Content (right side)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hasPhoto ? 12 : 14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + score
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: HelloTypography.body.copyWith(fontSize: 15, height: 1.25),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pct > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isHot
                                  ? HelloColors.accent.withValues(alpha: 0.1)
                                  : HelloColors.recessed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$pct%',
                              style: TextStyle(
                                fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
                                color: isHot ? HelloColors.accent : HelloColors.inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Description
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description!.split('\n').first,
                        style: HelloTypography.hint.copyWith(fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Avatar + progress
                    Row(
                      children: [
                        _MiniAvatar(name: proposer),
                        const SizedBox(width: 5),
                        Text(proposer, style: HelloTypography.hint.copyWith(fontSize: 11)),
                        const Spacer(),
                        // Compact progress
                        if (item.agreementScore > 0)
                          SizedBox(
                            width: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: item.agreementScore,
                                minHeight: 4,
                                backgroundColor: HelloColors.recessed,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isHot ? HelloColors.accent : HelloColors.inkTertiary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settled Card (green depth) ────────────────────────

class _SettledCard extends StatelessWidget {
  final DecisionItem item;
  const _SettledCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final proposer = item.proposedBy ?? 'someone';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: HelloColors.successGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HelloColors.successGreen.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: HelloColors.successGreen.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            if (hasPhoto)
              SizedBox(
                width: 72,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.photoUrl!.startsWith('assets/')
                          ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                          : Image.network(item.photoUrl!, fit: BoxFit.cover),
                      // Green tint overlay
                      Container(color: HelloColors.successGreen.withValues(alpha: 0.1)),
                      // Checkmark
                      Center(
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: HelloColors.successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: HelloColors.successGreen.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hasPhoto ? 12 : 14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                            style: HelloTypography.body.copyWith(fontSize: 15),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: HelloColors.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Settled', style: TextStyle(
                            fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w400,
                            color: HelloColors.successGreen,
                          )),
                        ),
                      ],
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 3),
                      Text(item.description!.split('\n').first,
                        style: HelloTypography.hint.copyWith(fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MiniAvatar(name: proposer),
                        const SizedBox(width: 5),
                        Text('$proposer settled', style: HelloTypography.hint.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini Avatar ───────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String name;
  const _MiniAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        color: HelloColors.inkPrimary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w400,
        color: HelloColors.inkSecondary,
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 3: Decision Card Stream (used by ALL categories except Overview)
// ═══════════════════════════════════════════════════════

class _DecisionCardStream extends StatelessWidget {
  final List<DecisionItem> items;
  final ChatEngineDecisions engine;
  final String emptyMessage;

  const _DecisionCardStream({
    required this.items,
    required this.engine,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<DecisionItem>.from(items)
      ..sort((a, b) {
        final ws = b.weightedScore.compareTo(a.weightedScore);
        if (ws != 0) return ws;
        return b.agreementScore.compareTo(a.agreementScore);
      });

    if (sorted.isEmpty) {
      return Center(child: Text(emptyMessage, style: HelloTypography.hint));
    }

    return PageView.builder(
      clipBehavior: Clip.none,
      controller: PageController(viewportFraction: 0.88),
      physics: const BouncingScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
          child: ActionCardWidget(
            item: item,
            onReact: () => engine.reactToItem(item.id, 'works_for_me'),
            onPinCommit: () => engine.lockItem(
              item.id, CommitmentProof(type: 'mock', value: 'booked', submittedBy: 'me'),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// TIER 3: Split (Xpensly placeholder)
// ═══════════════════════════════════════════════════════

class _SplitPlaceholder extends StatelessWidget {
  final String eventName;
  const _SplitPlaceholder({required this.eventName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48,
              color: HelloColors.inkTertiary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Expenses for $eventName',
              style: HelloTypography.body.copyWith(color: HelloColors.inkSecondary)),
          const SizedBox(height: 8),
          Text('No expenses yet', style: HelloTypography.hint),
        ],
      ),
    );
  }
}
