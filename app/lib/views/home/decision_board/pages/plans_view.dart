import 'dart:ui';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../providers/playground_provider.dart';
import '../../../../../providers/seed_data.dart';
import '../../../../../theme.dart';
import '../../../../../utils/haptics.dart';
import '../avatar_utils.dart';
import '../cards/decision_card.dart';
import '../sheets/add_item_sheet.dart';
import '../plasma/plasma.dart';

/// Extract the display title from a DecisionItem.
/// Playground items store the title in ciphertextPayload.
String _itemTitle(DecisionItem item) {
  final payload = item.ciphertextPayload;
  return (payload == 'mock' || payload.isEmpty) ? item.id : payload;
}

/// Extract the event|category string from a DecisionItem.
/// Playground items store this in nonce.
String _itemCategory(DecisionItem item) {
  final n = item.nonce;
  return (n == 'mock' || n.isEmpty) ? 'Ideas|General' : n;
}

/// Resolve a photo URL for a DecisionItem from the seed data map.
String? _itemPhotoUrl(DecisionItem item) {
  return mockDecisionPhoto[item.id];
}

/// Convert a DecisionItem to a MockPlanItem for DecisionCard compatibility.
MockPlanItem _toMockPlanItem(DecisionItem item) {
  return MockPlanItem(
    id: item.id,
    title: _itemTitle(item),
    category: _itemCategory(item),
    photoUrl: _itemPhotoUrl(item),
    agreementScore: item.agreementScore,
    isLocked: item.isLocked,
    proposedBy: item.proposedBy ?? 'Unknown',
    weightedScore: item.weightedScore,
  );
}

class PlansView extends ConsumerStatefulWidget {
  final String groupId;
  const PlansView({super.key, required this.groupId});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  int _selectedEventIdx = 0;
  int _selectedCatIdx = 0;
  
  // For the horizontal PageView when deep inside a category
  late PageController _pageController;
  int _currentCardIdx = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Extracts the Photo to use for the immersive room lighting
  String? _getActivePhotoUrl(String category, List<DecisionItem> catItems, List<DecisionItem> allEventItems) {
    if (category == 'Overview' && allEventItems.isNotEmpty) {
      // Find the first item with a photo to set the mood of the overview
      final valid = allEventItems.where((i) {
        final url = _itemPhotoUrl(i);
        return url != null && url.isNotEmpty;
      });
      if (valid.isNotEmpty) return _itemPhotoUrl(valid.first);
      return null;
    }

    if (catItems.isNotEmpty && _currentCardIdx < catItems.length) {
      return _itemPhotoUrl(catItems[_currentCardIdx]);
    }
    return null;
  }

  Widget _buildAtmosphericBackground(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF18181A), 
              Color(0xFF000000),
            ],
            stops: [0.1, 1.0],
          ),
        ),
      );
    }

    const ColorFilter activeLightEmitter = ColorFilter.matrix([
      1.6, 0.0, 0.0, 0.0, 15.0, // R scale + pop
      0.0, 1.6, 0.0, 0.0, 15.0, // G scale + pop
      0.0, 0.0, 1.6, 0.0, 15.0, // B scale + pop
      0.0, 0.0, 0.0, 1.0, 0.0,  // Alpha
    ]);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: activeLightEmitter,
          child: photoUrl.startsWith('http')
              ? Image.network(photoUrl, fit: BoxFit.cover)
              : Image.asset(photoUrl, fit: BoxFit.cover),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter playground items to those with proper event|category nonce
    // (items with nonce == 'mock' are HOME-feed-only items)
    final allItems = ref.watch(playgroundDecisionsProvider)
        .where((i) => i.nonce != 'mock' && i.nonce.isNotEmpty && i.nonce.contains('|'))
        .toList();

    // ── Parse Tier 1: Events ──
    final Map<String, List<DecisionItem>> eventItemsMap = {};
    for (final item in allItems) {
      final parts = _itemCategory(item).split('|');
      final event = parts[0].trim();
      eventItemsMap.putIfAbsent(event, () => []).add(item);
    }
    
    final eventNames = eventItemsMap.keys.toList()
      ..sort((a, b) {
        final sa = eventItemsMap[a]!.fold<double>(0, (s, i) => s + i.weightedScore);
        final sb = eventItemsMap[b]!.fold<double>(0, (s, i) => s + i.weightedScore);
        return sb.compareTo(sa);
      });

    if (_selectedEventIdx >= eventNames.length) _selectedEventIdx = 0;
    final selectedEvent = eventNames.isNotEmpty ? eventNames[_selectedEventIdx] : 'No Plans';
    final eventItems = eventItemsMap[selectedEvent] ?? [];

    // ── Parse Tier 2: Categories (dynamic per event) ──
    final List<String> tier2Categories = ['Overview', 'Recommendations'];
    final subCats = <String>{};
    for (final item in eventItems) {
      final parts = _itemCategory(item).split('|');
      if (parts.length > 1 && parts[1].trim() != 'General') {
        subCats.add(parts[1].trim());
      }
    }
    tier2Categories.addAll(subCats.toList());

    if (_selectedCatIdx >= tier2Categories.length) _selectedCatIdx = 0;
    final selectedCat = tier2Categories[_selectedCatIdx];

    // ── Filter Tier 3: Items for the active Category ──
    List<DecisionItem> catItems;
    if (_selectedCatIdx >= 2) {
      catItems = eventItems.where((i) {
        final parts = _itemCategory(i).split('|');
        return parts.length > 1 && parts[1].trim() == selectedCat;
      }).toList();
    } else if (selectedCat == 'Recommendations') {
       final sorted = List<DecisionItem>.from(eventItems)..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
       catItems = sorted.where((i) => !i.isLocked).take(5).toList();
    } else {
      catItems = eventItems;
    }

    final topSafe = MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    
    const double ambientLineHeight = 36.0; // Fixed global anchor footprint 
    const double negativeSpaceGap = 16.0;

    const double dockHeight = 90.0;
    final dockBottomPosition = bottomSafe + ambientLineHeight + negativeSpaceGap;

    final activePhotoUrl = _getActivePhotoUrl(selectedCat, catItems, eventItems);

    return Stack(
      children: [
        // ═══ LAYER 0: GLOBAL ATMOSPHERIC LIGHTING ═══
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInQuart,
                child: _buildAtmosphericBackground(activePhotoUrl),
              ),
              ClipRect(
                child: const ColoredBox(color: Colors.black45),
                ),
            ],
          ),
        ),

        // ═══ LAYER 1: TIER 3 CANVAS (Overview or Cards) ═══
        Positioned.fill(
          child: Container(
            padding: EdgeInsets.only(top: topSafe + 80, bottom: dockHeight + dockBottomPosition + 8),
            child: _buildHeroCanvas(selectedCat, selectedEvent, catItems, eventItems),
          ),
        ),

        // ═══ LAYER 2: THE 3-TIER NAVIGATION FLIGHT DECK ═══
        Positioned(
          left: 0,
          right: 0,
          bottom: dockBottomPosition,
          height: dockHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tier 2: Category Rail (Layered exactly above events)
              SizedBox(
                height: 44,
                child: _buildCategoryRail(tier2Categories),
              ),
              const SizedBox(height: 6),
              // Tier 1: Event Rail
              SizedBox(
                height: 40,
                child: _buildEventRail(eventNames),
              ),
            ],
          ),
        ),

        // Floating [+] Add Item button
        Positioned(
          bottom: dockBottomPosition + dockHeight + 12,
          right: 20,
          child: GestureDetector(
            onTap: () {
              HelloHaptic.tap();
              openAddItemSheet(context);
            },
            child: PlasmaFill(
              shape: BoxShape.circle,
              width: 48,
              height: 48,
              child: Icon(Icons.add_rounded, size: 24, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // NAVIGATION RAILS (ZERO-BOX ALIGNMENT)
  // ==========================================

  Widget _buildCategoryRail(List<String> categories) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = index == _selectedCatIdx;

          return Builder(
            builder: (itemContext) {
              return GestureDetector(
                onTap: () {
                  HelloHaptic.select();
                  setState(() {
                    _selectedCatIdx = index;
                    _currentCardIdx = 0; // Reset card wipe on category shift
                  });
                  Scrollable.ensureVisible(
                    itemContext,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutQuart,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.only(right: 28),
                  alignment: Alignment.center,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isSelected ? 13 : 12,
                      fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                      color: isSelected ? Colors.white : Colors.white38,
                      letterSpacing: 1.5,
                      shadows: isSelected 
                          ? [const Shadow(color: Colors.white54, blurRadius: 18)] 
                          : null,
                    ),
                    child: Text(cat.toUpperCase()),
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildEventRail(List<String> events) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isSelected = index == _selectedEventIdx;

          return Builder(
            builder: (itemContext) {
              return GestureDetector(
                onTap: () {
                  HelloHaptic.confirm();
                  setState(() {
                    _selectedEventIdx = index;
                    _selectedCatIdx = 0; // Reset to overview when event changes
                    _currentCardIdx = 0;
                  });
                  Scrollable.ensureVisible(
                    itemContext,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutQuart,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.only(right: 32),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutQuart,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: isSelected ? 24 : 18,
                          fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                          letterSpacing: 0.0,
                          color: isSelected ? Colors.white : Colors.white38,
                          shadows: isSelected 
                            ? [const Shadow(color: Colors.white54, blurRadius: 18)] 
                            : null,
                        ),
                        child: Text(event),
                      ),
                      const SizedBox(height: 7),
                    ],
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }

  // ==========================================
  // TIER 3: HERO CANVAS DELEGATOR
  // ==========================================

  Widget _buildHeroCanvas(String category, String eventName, List<DecisionItem> catItems, List<DecisionItem> allEventItems) {
    if (category == 'Overview') {
      return _OverviewDashboard(eventName: eventName, items: allEventItems);
    }

    if (catItems.isEmpty) {
      return Center(child: Text('No active items', style: HelloText.label));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: catItems.length,
      itemBuilder: (context, index) {
        final item = catItems[index];

        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            // Define strict card width for horizontal scrolling
            width: MediaQuery.sizeOf(context).width * 0.82,
            child: DecisionCard(item: _toMockPlanItem(item)),
          ),
        );
      },
    );
  }
}

// ==========================================
// OUTBOUND OVERVIEW DASHBOARD (FLOATING LIST)
// ==========================================

class _OverviewDashboard extends StatelessWidget {
  final String eventName;
  final List<DecisionItem> items;

  const _OverviewDashboard({required this.eventName, required this.items});

  @override
  Widget build(BuildContext context) {
    final sorted = List<DecisionItem>.from(items)
      ..sort((a, b) {
        if (a.isLocked && !b.isLocked) return 1;
        if (!a.isLocked && b.isLocked) return -1;
        return b.agreementScore.compareTo(a.agreementScore);
      });

    final settled = items.where((i) => i.isLocked).length;
    final total = items.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal scrolling list of cards now taking full height
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final item = sorted[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.82,
                    child: item.isLocked ? _FloatingSettledCard(item: item) : _FloatingActiveCard(item: item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingActiveCard extends StatelessWidget {
  final DecisionItem item;
  const _FloatingActiveCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final proposer = item.proposedBy ?? 'Unknown';
    final photoUrl = _itemPhotoUrl(item);
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final title = _itemTitle(item);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
               photoUrl!.startsWith('http')
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Image.asset(photoUrl, fit: BoxFit.cover)
            else
               Container(color: HelloColors.surfaceDeep),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                    colors: [Colors.transparent, Colors.black.withAlpha(200)],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 16, right: 16, bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w400, color: Colors.white, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      HologramAvatar(avatarPath: getAvatarImagePath(proposer), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$proposer proposed this',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w300, color: Colors.white.withAlpha(200)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
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

class _FloatingSettledCard extends StatelessWidget {
  final DecisionItem item;
  const _FloatingSettledCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final proposer = item.proposedBy ?? 'Unknown';
    final photoUrl = _itemPhotoUrl(item);
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final title = _itemTitle(item);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
               photoUrl!.startsWith('http')
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Image.asset(photoUrl, fit: BoxFit.cover)
            else
               Container(color: HelloColors.liveGreen.withAlpha(20)),

            if (hasPhoto)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [HelloColors.liveGreen.withAlpha(50), HelloColors.liveGreen.withAlpha(150)],
                  ),
                ),
              ),

            Positioned(
              top: 12, right: 14,
              child: const Icon(Icons.check_circle_outline, size: 24, color: Colors.white),
            ),

            Positioned(
              left: 16, right: 40, bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w400, color: Colors.white, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      HologramAvatar(avatarPath: getAvatarImagePath(proposer), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$proposer booked this',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w300, color: Colors.white.withAlpha(200)),
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
