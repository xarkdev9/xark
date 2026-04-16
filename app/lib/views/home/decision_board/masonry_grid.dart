import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Thin wrapper around [SliverMasonryGrid.count] with fixed 2-col
/// layout + symmetric spacing. Each item is a tile; heights are
/// driven by the item widgets themselves.
class MasonryFeedGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const MasonryFeedGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
