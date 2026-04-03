import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';
import 'explore_search_bar.dart';
import 'category_chips.dart';
import 'discovery_item_card.dart';

/// Full-screen discovery browse tab.
///
/// Search bar at top, category chips, 2-column grid of items,
/// pull-to-refresh, and shimmer placeholders when loading.
class ExploreTab extends StatefulWidget {
  final List<DiscoveryItem> items;
  final void Function(String query, DiscoveryCategory? category)? onSearch;
  final void Function(DiscoveryItem item)? onItemTap;
  final void Function(DiscoveryItem item)? onSave;
  final void Function(DiscoveryItem item)? onDismiss;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const ExploreTab({
    super.key,
    required this.items,
    this.onSearch,
    this.onItemTap,
    this.onSave,
    this.onDismiss,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  DiscoveryCategory? _selectedCategory;
  String _query = '';

  void _onSearch(String query) {
    _query = query;
    widget.onSearch?.call(_query, _selectedCategory);
  }

  void _onCategorySelected(DiscoveryCategory? category) {
    setState(() => _selectedCategory = category);
    widget.onSearch?.call(_query, _selectedCategory);
  }

  Future<void> _onRefresh() async {
    widget.onRefresh?.call();
    // Allow RefreshIndicator to complete its animation
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: ExploreSearchBar(onSearch: _onSearch),
          ),

          // Category chips
          CategoryChips(
            selected: _selectedCategory,
            onSelected: _onCategorySelected,
          ),

          const SizedBox(height: 8.0),

          // Grid content
          Expanded(
            child: widget.isLoading
                ? _buildShimmerGrid()
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: HelloColors.accent,
                    child: widget.items.isEmpty
                        ? _buildEmpty()
                        : _buildGrid(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.72,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return DiscoveryItemCard(
          item: item,
          onTap: () => widget.onItemTap?.call(item),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const _ShimmerCard();
      },
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80.0),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.explore_outlined,
                size: 48.0,
                color: HelloColors.inkTertiary,
              ),
              const SizedBox(height: 12.0),
              Text(
                'Nothing here yet',
                style: HelloTypography.body.copyWith(
                  color: HelloColors.inkSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Pull to refresh or try a different search',
                style: HelloTypography.hint.copyWith(
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated placeholder card with pulsing opacity.
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.4),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: HelloColors.recessed,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            const Expanded(
              flex: 3,
              child: SizedBox.expand(),
            ),
            // Text placeholder
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12.0,
                      width: double.infinity,
                      color: HelloColors.neutralGray.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 6.0),
                    Container(
                      height: 10.0,
                      width: 80.0,
                      color: HelloColors.neutralGray.withValues(alpha: 0.15),
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
