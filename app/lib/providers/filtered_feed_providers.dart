import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'feed_provider.dart';

/// HOME tab feed — the full unified feed, unchanged.
final homeFeedProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider);
});

/// CHATS tab feed — only DmFeedItem, sorted by recency.
final chatsFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  return feed.whereType<DmFeedItem>().cast<FeedItem>().toList()
    ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
});

/// GROUPS tab feed — only GroupFeedItem, sorted by recency.
final groupsFeedProvider = Provider<List<FeedItem>>((ref) {
  final feed = ref.watch(feedProvider);
  return feed.whereType<GroupFeedItem>().cast<FeedItem>().toList()
    ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
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
