import 'package:flutter/material.dart';

import '../../../models/feed_item.dart';
import '../../../theme.dart';
import '../../../utils/haptics.dart';
import 'cards/ai_nudge_card.dart';
import 'cards/decision_card_hero.dart';
import 'cards/dm_card.dart';
import 'cards/focus_hero_card.dart';
import 'cards/group_card.dart';
import 'cards/itinerary_card.dart';
import 'cards/memory_card.dart';
import 'cards/settlement_card.dart';
import 'cards/trip_card.dart';
import 'pages/decision_page.dart';
import 'pages/settlement_page.dart';
import 'pages/trip_page.dart';
import 'sheets/dm_sheet.dart';
import 'sheets/group_sheet.dart';

/// Shared factory — maps a [FeedItem] variant to its widget and
/// wires its onTap to the correct sheet or route. Used by all 4
/// tab pages so each page has identical card rendering behavior.
Widget buildFeedItemCard(BuildContext context, FeedItem item) {
  void stubSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: HelloText.body.copyWith(color: HelloColors.inkPrimary),
        ),
        backgroundColor: HelloColors.recessed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  return switch (item) {
    DmFeedItem() => DmCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openDmSheet(context, item);
        },
      ),
    GroupFeedItem() => GroupCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openGroupSheet(context, item);
        },
      ),
    DecisionSmallFeedItem() => const SizedBox.shrink(),
    DecisionHeroFeedItem() => DecisionCardHero(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openDecisionPage(context, item);
        },
      ),
    TripFeedItem() => TripCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openTripPage(context, item);
        },
      ),
    SettlementFeedItem() => SettlementCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openSettlementPage(context, item);
        },
      ),
    ItineraryFeedItem() => ItineraryCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          stubSnack('Itinerary — coming in v1.1');
        },
      ),
    MemoryFeedItem() => MemoryCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          stubSnack('Memory — coming in v1.1');
        },
      ),
    AiNudgeFeedItem() => AiNudgeCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          stubSnack('@hello nudge — coming in v1.1');
        },
      ),
    FocusHeroFeedItem() => FocusHeroCard(
        item: item,
        onTap: () {
          HelloHaptic.tap();
          openTripPage(context, item);
        },
      ),
  };
}
