// Viewport focus tracking — which card is closest to the viewport
// midline right now. Powers the "living field" focus lift, pulsing
// ring, and atmosphere color shift.
//
// Cards register their GlobalKey in [cardKeyRegistry] via CardShell.
// decision_board_page.dart's scroll listener iterates the registry
// on every scroll frame and writes the winner to
// [centeredFeedItemIdProvider].

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/feed_item.dart';
import 'feed_provider.dart';

/// Global mutable registry of GlobalKeys per FeedItem id. Cards
/// register/unregister via CardShell's initState/dispose. The
/// page's scroll listener reads this map to compute which card's
/// center is closest to the viewport midline.
final Map<String, GlobalKey> cardKeyRegistry = <String, GlobalKey>{};

/// The id of the FeedItem whose visual center is closest to the
/// viewport midline. Updated by a scroll listener in
/// decision_board_page.dart. null when no cards are visible yet.
final centeredFeedItemIdProvider = StateProvider<String?>((ref) => null);

/// Derived: the actual FeedItem for the centered id.
final centeredFeedItemProvider = Provider<FeedItem?>((ref) {
  final id = ref.watch(centeredFeedItemIdProvider);
  if (id == null) return null;
  final feed = ref.watch(feedProvider);
  for (final item in feed) {
    if (item.id == id) return item;
  }
  return null;
});

/// Derived: the kind string of the centered item. Drives the
/// atmosphere mesh's primary glow color lerp. Returns null when
/// no card is centered (edges of scroll, initial state).
final centeredFeedItemKindProvider = Provider<String?>((ref) {
  final item = ref.watch(centeredFeedItemProvider);
  if (item == null) return null;
  return switch (item) {
    DmFeedItem() => 'dm',
    GroupFeedItem() => 'group',
    DecisionSmallFeedItem() => 'decision',
    DecisionHeroFeedItem() => 'decision',
    TripFeedItem() => 'trip',
    SettlementFeedItem() => 'settlement',
    ItineraryFeedItem() => 'itinerary',
    MemoryFeedItem() => 'memory',
    AiNudgeFeedItem() => 'ai',
    FocusHeroFeedItem() => 'trip',
  };
});
