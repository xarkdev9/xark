import 'package:flutter/material.dart';

import '../../../models/feed_item.dart';
import '../../../theme.dart';
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
import 'sheets/decision_sheet.dart';
import 'sheets/dm_sheet.dart';
import 'sheets/group_sheet.dart';
import 'sheets/settlement_sheet.dart';

/// Shared factory — maps a [FeedItem] variant to its widget and
/// wires its onTap to the correct sheet or route. Used by all 4
/// tab pages so each page has identical card rendering behavior.
Widget buildFeedItemCard(BuildContext context, FeedItem item) {
  void stubSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: HelloColors.recessed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void openTripRoute(String tripId) {
    Navigator.of(context).push(
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

  return switch (item) {
    DmFeedItem() => DmCard(
        item: item,
        onTap: () => openDmSheet(context, item),
      ),
    GroupFeedItem() => GroupCard(
        item: item,
        onTap: () => openGroupSheet(context, item),
      ),
    DecisionSmallFeedItem() => DecisionCardSmall(
        item: item,
        onTap: () => openDecisionSheet(context, item),
      ),
    DecisionHeroFeedItem() => DecisionCardHero(
        item: item,
        onTap: () => openDecisionSheet(context, item),
      ),
    TripFeedItem() => TripCard(
        item: item,
        onTap: () => openTripRoute(item.trip.id),
      ),
    SettlementFeedItem() => SettlementCard(
        item: item,
        onTap: () => openSettlementSheet(context, item),
      ),
    ItineraryFeedItem() => ItineraryCard(
        item: item,
        onTap: () => stubSnack('Itinerary — coming in v1.1'),
      ),
    MemoryFeedItem() => MemoryCard(
        item: item,
        onTap: () => stubSnack('Memory — coming in v1.1'),
      ),
    AiNudgeFeedItem() => AiNudgeCard(
        item: item,
        onTap: () => stubSnack('@hello nudge — coming in v1.1'),
      ),
    FocusHeroFeedItem() => FocusHeroCard(
        item: item,
        onTap: () => openTripRoute(item.trip.id),
      ),
  };
}
