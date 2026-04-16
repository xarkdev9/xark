import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../_card_factory.dart';
import '../masonry_grid.dart';

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key});

  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(plansFeedProvider);

    final focusItems = feed.whereType<FocusHeroFeedItem>().toList();
    final focusItem = focusItems.isEmpty ? null : focusItems.first;
    final rest =
        feed.where((i) => i is! FocusHeroFeedItem).toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        if (focusItem != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: buildFeedItemCard(context, focusItem),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: MasonryFeedGrid(
            itemCount: rest.length,
            itemBuilder: (ctx, i) => buildFeedItemCard(ctx, rest[i]),
          ),
        ),
      ],
    );
  }
}
