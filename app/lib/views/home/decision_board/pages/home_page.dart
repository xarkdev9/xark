import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../providers/viewport_focus_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../_card_factory.dart';
import '../chromatic_atmosphere.dart';
import '../empty_state.dart';
import '../masonry_grid.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _focusDebounce;
  // Captured at initState; used in dispose() because Riverpod 3 disposes
  // the ref before State.dispose() runs.
  FocusSourceStack? _focusStack;

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireFocusListener();
    });
  }

  @override
  void dispose() {
    _focusDebounce?.cancel();
    _focusStack?.pop('home_feed');
    super.dispose();
  }

  void _wireFocusListener() {
    ref.listenManual<String?>(centeredFeedItemIdProvider, (_, next) {
      _focusDebounce?.cancel();
      _focusDebounce = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted || next == null) return;
        final feed = ref.read(homeFeedProvider);
        final item = _feedItemById(feed, next);
        if (item == null) return;
        final palette = await PaletteExtractor.resolve(_contentRefOf(item));
        if (!mounted) return;
        ref.read(focusSourcesProvider.notifier).push(
              FocusSource(id: 'home_feed', palette: palette, priority: 10),
            );
      });
    });
  }

  FeedItem? _feedItemById(List<FeedItem> items, String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  ContentRef _contentRefOf(FeedItem item) {
    return switch (item) {
      DmFeedItem(:final conversation) => ContentRef(
          signatureId: conversation.id,
          kind: 'dm',
        ),
      GroupFeedItem(:final conversation) => ContentRef(
          signatureId: conversation.id,
          kind: 'group',
        ),
      DecisionHeroFeedItem(:final photoUrl) => ContentRef(
          photoPath: photoUrl.startsWith('assets/') ? photoUrl : null,
          photoUrl: photoUrl.startsWith('http') ? photoUrl : null,
          kind: 'decision',
        ),
      DecisionSmallFeedItem() => const ContentRef(kind: 'decision'),
      FocusHeroFeedItem(:final trip) => ContentRef(
          photoPath: trip.photoUrl.startsWith('assets/') ? trip.photoUrl : null,
          photoUrl: trip.photoUrl.startsWith('http') ? trip.photoUrl : null,
          kind: 'trip',
        ),
      TripFeedItem(:final trip) => ContentRef(
          photoPath: trip.photoUrl.startsWith('assets/') ? trip.photoUrl : null,
          photoUrl: trip.photoUrl.startsWith('http') ? trip.photoUrl : null,
          kind: 'trip',
        ),
      SettlementFeedItem() => const ContentRef(kind: 'settlement'),
      ItineraryFeedItem() => const ContentRef(kind: 'itinerary'),
      MemoryFeedItem() => const ContentRef(kind: 'memory'),
      AiNudgeFeedItem() => const ContentRef(kind: 'ai'),
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(homeFeedProvider);

    final focusItems = feed.whereType<FocusHeroFeedItem>().toList();
    final focusItem = focusItems.isEmpty ? null : focusItems.first;
    final rest =
        feed.where((i) => i is! FocusHeroFeedItem).toList(growable: false);

    if (focusItem == null && rest.isEmpty) {
      return const AtmosphereDensityScope(
        density: AtmosphereDensity.dense,
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 56)),
            SliverFillRemaining(
              child: HelloEmptyState(
                icon: Icons.home_rounded,
                headline: 'All caught up',
                body: 'Nothing needs your attention right now',
              ),
            ),
          ],
        ),
      );
    }

    return AtmosphereDensityScope(
      density: AtmosphereDensity.dense,
      child: CustomScrollView(
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
      ),
    );
  }
}
