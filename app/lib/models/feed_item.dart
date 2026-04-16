import 'package:e2ee_chat_sdk/e2ee_chat.dart';

import 'itinerary_event.dart';
import 'settlement.dart';
import 'trip.dart';

sealed class FeedItem {
  String get id;
  DateTime get sortKey;
}

final class DmFeedItem extends FeedItem {
  final Conversation conversation;
  DmFeedItem(this.conversation);
  @override
  String get id => 'dm_${conversation.id}';
  @override
  DateTime get sortKey =>
      conversation.lastMessageTimestamp ?? conversation.updatedAt;
}

final class GroupFeedItem extends FeedItem {
  final Conversation conversation;
  final int typingCount;
  GroupFeedItem(this.conversation, {this.typingCount = 0});
  @override
  String get id => 'group_${conversation.id}';
  @override
  DateTime get sortKey =>
      conversation.lastMessageTimestamp ?? conversation.updatedAt;
}

final class DecisionSmallFeedItem extends FeedItem {
  final DecisionItem item;
  final String title;
  final String? eyebrow;
  final DateTime updatedAt;
  DecisionSmallFeedItem(
    this.item, {
    required this.title,
    this.eyebrow,
    required this.updatedAt,
  });
  @override
  String get id => 'decs_${item.id}';
  @override
  DateTime get sortKey => updatedAt;
}

final class DecisionHeroFeedItem extends FeedItem {
  final DecisionItem item;
  final String title;
  final String subtitle;
  final String photoUrl;
  final String? liveTag;
  final int votedCount;
  final int totalCount;
  final DateTime updatedAt;
  DecisionHeroFeedItem(
    this.item, {
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    this.liveTag,
    required this.votedCount,
    required this.totalCount,
    required this.updatedAt,
  });
  @override
  String get id => 'dech_${item.id}';
  @override
  DateTime get sortKey => updatedAt;
}

final class TripFeedItem extends FeedItem {
  final Trip trip;
  TripFeedItem(this.trip);
  @override
  String get id => 'trip_${trip.id}';
  @override
  DateTime get sortKey => trip.updatedAt;
}

final class SettlementFeedItem extends FeedItem {
  final Settlement settlement;
  SettlementFeedItem(this.settlement);
  @override
  String get id => 'settle_${settlement.id}';
  @override
  DateTime get sortKey => settlement.updatedAt;
}

final class ItineraryFeedItem extends FeedItem {
  final ItineraryEvent event;
  ItineraryFeedItem(this.event);
  @override
  String get id => 'itin_${event.id}';
  @override
  DateTime get sortKey => event.updatedAt;
}

final class MemoryFeedItem extends FeedItem {
  final String memoryId;
  final String eyebrow;
  final String title;
  final String body;
  final String? photoUrl;
  final DateTime occurredAt;
  final DateTime updatedAt;
  MemoryFeedItem({
    required this.memoryId,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.photoUrl,
    required this.occurredAt,
    required this.updatedAt,
  });
  @override
  String get id => 'mem_$memoryId';
  @override
  DateTime get sortKey => updatedAt;
}

final class AiNudgeFeedItem extends FeedItem {
  final String nudgeId;
  final String message;
  final String? ctaLabel;
  final DateTime updatedAt;
  AiNudgeFeedItem({
    required this.nudgeId,
    required this.message,
    this.ctaLabel,
    required this.updatedAt,
  });
  @override
  String get id => 'ai_$nudgeId';
  @override
  DateTime get sortKey => updatedAt;
}

final class FocusHeroFeedItem extends FeedItem {
  final Trip trip;
  FocusHeroFeedItem(this.trip);
  @override
  String get id => 'focus_${trip.id}';
  @override
  DateTime get sortKey => DateTime(9999);
}
