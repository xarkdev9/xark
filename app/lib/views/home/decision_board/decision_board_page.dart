// The V10 live-surface home screen.
//
// A masonry feed of 10 card types sourced from `feedProvider` and
// sorted by time desc with the focus trip pinned at index 0. Every
// card opens a full-screen modal sheet on tap, except TripCard
// (which navigates) and Memory/Itinerary/AiNudge (which show a
// placeholder snackbar in v1).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feed_item.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../theme.dart';
import 'atmosphere.dart';
import 'cards/ai_nudge_card.dart';
import 'cards/decision_card_hero.dart';
import 'cards/decision_card_small.dart';
import 'cards/dm_card.dart';
import 'cards/focus_hero_card.dart';
import 'cards/group_card.dart';
import 'cards/itinerary_card.dart';
import 'cards/memory_card.dart';
import 'cards/settlement_card.dart';
import 'cards/trip_card.dart';
import 'feed_header.dart';
import 'masonry_grid.dart';
import 'sheets/decision_sheet.dart';
import 'sheets/dm_sheet.dart';
import 'sheets/group_sheet.dart';
import 'sheets/settlement_sheet.dart';

class DecisionBoardPage extends ConsumerStatefulWidget {
  const DecisionBoardPage({super.key});

  @override
  ConsumerState<DecisionBoardPage> createState() =>
      _DecisionBoardPageState();
}

class _DecisionBoardPageState extends ConsumerState<DecisionBoardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _stubSnack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: HelloColors.recessed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTripRoute(BuildContext ctx, String tripId) {
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: HelloColors.voidBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: HelloColors.inkPrimary),
          ),
          body: Center(
            child: Text(
              'Trip · $tripId\n\nComing in v1.1',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext ctx, FeedItem item) {
    return switch (item) {
      DmFeedItem() => DmCard(
          item: item,
          onTap: () => openDmSheet(ctx, item),
        ),
      GroupFeedItem() => GroupCard(
          item: item,
          onTap: () => openGroupSheet(ctx, item),
        ),
      DecisionSmallFeedItem() => DecisionCardSmall(
          item: item,
          onTap: () => openDecisionSheet(ctx, item),
        ),
      DecisionHeroFeedItem() => DecisionCardHero(
          item: item,
          onTap: () => openDecisionSheet(ctx, item),
        ),
      TripFeedItem() => TripCard(
          item: item,
          onTap: () => _openTripRoute(ctx, item.trip.id),
        ),
      SettlementFeedItem() => SettlementCard(
          item: item,
          onTap: () => openSettlementSheet(ctx, item),
        ),
      ItineraryFeedItem() => ItineraryCard(
          item: item,
          onTap: () =>
              _stubSnack(ctx, 'Itinerary detail — coming in v1.1'),
        ),
      MemoryFeedItem() => MemoryCard(
          item: item,
          onTap: () => _stubSnack(ctx, 'Memory detail — coming in v1.1'),
        ),
      AiNudgeFeedItem() => AiNudgeCard(
          item: item,
          onTap: () => _stubSnack(ctx, '@hello nudge — coming in v1.1'),
        ),
      FocusHeroFeedItem() => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(feedProvider);
    final focus = ref.watch(focusTripProvider);

    // Split the feed: FocusHero renders in its own sliver; everything
    // else flows into the masonry grid.
    final focusItems = feed.whereType<FocusHeroFeedItem>().toList();
    final focusItem = focusItems.isEmpty ? null : focusItems.first;
    final rest = feed.where((i) => i is! FocusHeroFeedItem).toList();

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientMesh()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: FeedHeader(focus: focus)),
                if (focusItem != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: FocusHeroCard(
                        item: focusItem,
                        onTap: () =>
                            _openTripRoute(context, focusItem.trip.id),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: MasonryFeedGrid(
                    itemCount: rest.length,
                    itemBuilder: (ctx, i) => _buildCard(ctx, rest[i]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
