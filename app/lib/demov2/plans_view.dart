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
// TIER 3: Overview — Floating Visual Hierarchy
//
// ZERO: boxes, lines, grids, bars, progress bars
// ONLY: floating photo cards, gradient overlays, facepile
//       avatars, social copy, organic spacing
// ═══════════════════════════════════════════════════════

/// Per-person avatar colors (warm, vibrant, unique)
const _avatarColors = <String, Color>{
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

Color _colorForPerson(String name) =>
    _avatarColors[name.toLowerCase()] ?? HelloColors.accent;

class _OverviewDashboard extends StatelessWidget {
  final String eventName;
  final List<DecisionItem> items;

  const _OverviewDashboard({required this.eventName, required this.items});

  @override
  Widget build(BuildContext context) {
    // Sort: hottest first, settled at end
    final sorted = List<DecisionItem>.from(items)
      ..sort((a, b) {
        if (a.isLocked && !b.isLocked) return 1;
        if (!a.isLocked && b.isLocked) return -1;
        return b.agreementScore.compareTo(a.agreementScore);
      });

    final settled = items.where((i) => i.isLocked).length;
    final total = items.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Floating header text (no box) ──
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              eventName,
              style: HelloTypography.hero.copyWith(fontSize: 26, height: 1.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              settled > 0
                  ? '$settled of $total settled \u2022 ${total - settled} to go'
                  : '$total things to decide',
              style: HelloTypography.hint.copyWith(fontSize: 14),
            ),
          ),

          // ── Cards stream: each item is a full-bleed photo card ──
          ...sorted.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: item.isLocked
                ? _FloatingSettledCard(item: item)
                : _FloatingActiveCard(item: item),
          )),
        ],
      ),
    );
  }
}

// ── Floating Active Card — photo-first, text overlay ──

class _FloatingActiveCard extends StatelessWidget {
  final DecisionItem item;
  const _FloatingActiveCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final proposer = item.proposedBy ?? 'someone';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;
    final isHot = item.agreementScore >= 0.7;
    final socialText = _buildSocialText(item);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: hasPhoto ? 180 : 100,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo background (or subtle gradient for no-photo items)
            if (hasPhoto)
              item.photoUrl!.startsWith('assets/')
                  ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                  : Image.network(item.photoUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HelloColors.recessed,
                      HelloColors.inkTertiary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

            // Dark gradient overlay (bottom half only)
            if (hasPhoto)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),

            // Content floating on the image
            Positioned(
              left: 18, right: 18, bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title + description
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: hasPhoto ? Colors.white : HelloColors.inkPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description!.split('\n').first,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: hasPhoto
                            ? Colors.white.withValues(alpha: 0.7)
                            : HelloColors.inkTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Facepile + social copy
                  Row(
                    children: [
                      // Facepile (overlapping avatars)
                      _Facepile(names: [proposer, 'me']),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          socialText,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: hasPhoto
                                ? Colors.white.withValues(alpha: 0.8)
                                : HelloColors.inkSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Hot indicator — floating top-right flame
            if (isHot)
              Positioned(
                top: 12, right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, size: 14, color: HelloColors.accent),
                      const SizedBox(width: 3),
                      Text('trending', style: TextStyle(
                        fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w300,
                        color: Colors.white.withValues(alpha: 0.9),
                      )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildSocialText(DecisionItem item) {
    final proposer = item.proposedBy ?? 'someone';
    if (item.agreementScore >= 0.7) {
      return '$proposer and others love this';
    } else if (item.agreementScore >= 0.4) {
      return 'Waiting on votes...';
    } else if (item.agreementScore > 0) {
      return '$proposer proposed this';
    }
    return 'Just added by $proposer';
  }
}

// ── Floating Settled Card — photo with green veil ─────

class _FloatingSettledCard extends StatelessWidget {
  final DecisionItem item;
  const _FloatingSettledCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final proposer = item.proposedBy ?? 'someone';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: hasPhoto ? 140 : 80,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            if (hasPhoto)
              item.photoUrl!.startsWith('assets/')
                  ? Image.asset(item.photoUrl!, fit: BoxFit.cover)
                  : Image.network(item.photoUrl!, fit: BoxFit.cover)
            else
              Container(color: HelloColors.successGreen.withValues(alpha: 0.04)),

            // Green veil
            if (hasPhoto)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HelloColors.successGreen.withValues(alpha: 0.15),
                      HelloColors.successGreen.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),

            // Floating checkmark
            Positioned(
              top: 12, right: 14,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: HelloColors.successGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HelloColors.successGreen.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),

            // Content
            Positioned(
              left: 18, right: 60, bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w400,
                      color: hasPhoto ? Colors.white : HelloColors.inkPrimary,
                      height: 1.2,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Facepile(names: [proposer]),
                      const SizedBox(width: 6),
                      Text(
                        '$proposer booked this',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w300,
                          color: hasPhoto
                              ? Colors.white.withValues(alpha: 0.8)
                              : HelloColors.inkSecondary,
                        ),
                      ),
                    ],
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

// ── Facepile — overlapping colorful avatars ────────────

class _Facepile extends StatelessWidget {
  final List<String> names;
  const _Facepile({required this.names});

  @override
  Widget build(BuildContext context) {
    final visible = names.take(3).toList();
    return SizedBox(
      width: 20.0 + (visible.length - 1) * 14.0,
      height: 24,
      child: Stack(
        children: visible.asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value;
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          final color = _colorForPerson(name);

          return Positioned(
            left: idx * 14.0,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }).toList(),
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
