import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import '../views/home/decision_board/pages/home/cosmos_sender_model.dart';
import 'feed_provider.dart';

/// HOME tab feed — the full unified feed, unchanged.
final homeFeedProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider);
});

/// Chats tab feed — iMessage-style unified list of DMs + Groups,
/// sorted by recency. As of 2026-04-15 the separate Groups tab is
/// gone; group conversations interleave with 1:1 DMs here.
final chatsFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  final merged = <FeedItem>[
    ...feed.whereType<DmFeedItem>(),
    ...feed.whereType<GroupFeedItem>(),
  ];
  merged.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return merged;
});

/// PLANS tab feed — focus hero + trips + itinerary events.
final plansFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  final items = <FeedItem>[];
  items.addAll(feed.whereType<FocusHeroFeedItem>());
  items.addAll(feed.whereType<TripFeedItem>());
  items.addAll(feed.whereType<ItineraryFeedItem>());
  return items;
});

// ── Cosmos Home providers (2026-04-14) ────────────────────────────

/// Freshest pending sender — the person behind the most recent
/// pending item in the unified feed. Returns null when no pending
/// items exist (Home shows the "all caught up" empty state).
final freshestPendingSenderProvider = Provider<PendingSender?>((ref) {
  final feed = ref.watch(feedProvider);
  final senders = <PendingSender>[];
  for (final item in feed) {
    final s = pendingSenderFromFeedItem(item);
    if (s != null) senders.add(s);
  }
  if (senders.isEmpty) return null;
  senders.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return senders.first;
});

/// Up to 6 pending senders by recency, excluding whoever is in the
/// foreground. Freshness-only sort (no relationship tiebreakers).
final pendingSendersQueueProvider = Provider<List<PendingSender>>((ref) {
  final feed = ref.watch(feedProvider);
  final foreground = ref.watch(freshestPendingSenderProvider);
  final senders = <PendingSender>[];
  for (final item in feed) {
    final s = pendingSenderFromFeedItem(item);
    if (s != null && s != foreground) senders.add(s);
  }
  senders.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return senders.take(6).toList();
});
