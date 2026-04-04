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
// TIER 3: Overview Dashboard
// ═══════════════════════════════════════════════════════

class _OverviewDashboard extends StatelessWidget {
  final String eventName;
  final List<DecisionItem> items;

  const _OverviewDashboard({required this.eventName, required this.items});

  @override
  Widget build(BuildContext context) {
    final settled = items.where((i) => i.isLocked).toList();
    final voting = items.where((i) => !i.isLocked && i.agreementScore > 0).toList()
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    final fresh = items.where((i) => !i.isLocked && i.agreementScore == 0).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(eventName, style: HelloTypography.hero.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            '${items.length} items  \u00b7  ${settled.length} done  \u00b7  ${voting.length} pending  \u00b7  ${fresh.length} new',
            style: HelloTypography.hint,
          ),
          const SizedBox(height: 20),

          // Settled
          if (settled.isNotEmpty) ...[
            _SectionLabel('Done', HelloColors.successGreen),
            ...settled.map((i) => _ItemRow(item: i, trailing: 'settled', trailingColor: HelloColors.successGreen)),
            const SizedBox(height: 16),
          ],

          // Voting (pending)
          if (voting.isNotEmpty) ...[
            _SectionLabel('Pending', HelloColors.accent),
            ...voting.map((i) => _ItemRow(
              item: i,
              trailing: '${(i.agreementScore * 100).toInt()}%',
              trailingColor: i.agreementScore >= 0.7 ? HelloColors.accent : HelloColors.inkSecondary,
            )),
            const SizedBox(height: 16),
          ],

          // Fresh (new)
          if (fresh.isNotEmpty) ...[
            _SectionLabel('New', HelloColors.inkTertiary),
            ...fresh.map((i) => _ItemRow(item: i, trailing: 'new', trailingColor: HelloColors.inkTertiary)),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: HelloTypography.label.copyWith(color: color, letterSpacing: 1.0)),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final DecisionItem item;
  final String trailing;
  final Color trailingColor;

  const _ItemRow({required this.item, required this.trailing, required this.trailingColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44, height: 44,
              child: item.photoUrl != null && item.photoUrl!.isNotEmpty
                  ? (item.photoUrl!.startsWith('assets/')
                      ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                      : Image.network(item.photoUrl!, fit: BoxFit.cover))
                  : Container(
                      color: HelloColors.recessed,
                      child: Icon(Icons.image_outlined, size: 20, color: HelloColors.inkTertiary),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: HelloTypography.body.copyWith(fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.description != null)
                  Text(item.description!.split('\n').first,
                      style: HelloTypography.hint.copyWith(fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: HelloTypography.label.copyWith(color: trailingColor, fontSize: 13)),
        ],
      ),
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
