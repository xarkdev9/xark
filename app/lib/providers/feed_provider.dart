import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'conversations_provider.dart';
import 'decisions_provider.dart';
import 'focus_provider.dart';
import 'itinerary_provider.dart';
import 'mock_data.dart';
import 'settlements_provider.dart';
import 'trips_provider.dart';

/// Unified time-ordered feed. Merges DMs, groups, decisions (as
/// small or hero per [mockDecisionHero]), trips, settlements,
/// itinerary, memories, and AI nudges. The focus trip (if any)
/// is pinned at index 0 as a [FocusHeroFeedItem].
final feedProvider = Provider<List<FeedItem>>((ref) {
  final dms = ref.watch(directMessagesProvider);
  final groups = ref.watch(groupChatsProvider);
  final decisionsAsync = ref.watch(activeDecisionsProvider);
  final trips = ref.watch(tripsProvider);
  final settlements = ref.watch(settlementsProvider);
  final itinerary = ref.watch(itineraryProvider);
  final focus = ref.watch(focusTripProvider);

  final decisions = decisionsAsync.value ?? const <DecisionItem>[];

  final items = <FeedItem>[
    if (focus != null) FocusHeroFeedItem(focus),
    for (final c in dms) DmFeedItem(c),
    for (final c in groups) GroupFeedItem(c),
    ...decisions.map<FeedItem>((d) {
      final hero = mockDecisionHero[d.id];
      if (hero != null) {
        return DecisionHeroFeedItem(
          d,
          title: hero.title,
          subtitle: hero.subtitle,
          photoUrl: hero.photoUrl,
          liveTag: hero.liveTag,
          votedCount: hero.votedCount,
          totalCount: hero.totalCount,
          updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        );
      }
      final small = mockDecisionSmall[d.id];
      return DecisionSmallFeedItem(
        d,
        title: small?.title ?? 'Decision ${d.id.substring(0, 8)}',
        eyebrow: small?.eyebrow,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
    }),
    for (final t in trips)
      if (focus == null || t.id != focus.id) TripFeedItem(t),
    for (final s in settlements) SettlementFeedItem(s),
    for (final e in itinerary) ItineraryFeedItem(e),
    ...mockMemoryFeedItems,
    ...mockAiNudgeFeedItems,
  ];

  items.sort((a, b) {
    if (a is FocusHeroFeedItem) return -1;
    if (b is FocusHeroFeedItem) return 1;
    return b.sortKey.compareTo(a.sortKey);
  });

  return items;
});
