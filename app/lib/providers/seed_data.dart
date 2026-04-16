import 'package:e2ee_chat_sdk/e2ee_chat.dart';

import '../models/feed_item.dart';

// ── Mock Decisions ──────────────────────────────────────────────

final List<DecisionItem> mockDecisions = [
  DecisionItem(
    id: 'swiss_hotel_zostel_vs_taj',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'Goa hotel - Zostel or Taj?',
    nonce: 'hotels',
    state: 'proposed',
    weightedScore: 3,
    agreementScore: 0.5,
    reactions: const {'priya': 'love_it', 'james': 'works_for_me', 'maya': 'not_for_me'},
    proposedBy: 'priya',
  ),
  DecisionItem(
    id: 'sunday_dinner_italian_place',
    groupId: 'family',
    ciphertextPayload: 'Italian or Thai?',
    nonce: 'food',
    state: 'proposed',
    weightedScore: 6,
    agreementScore: 0.33,
    reactions: const {'james': 'love_it', 'sarah': 'works_for_me'},
    proposedBy: 'james',
  ),
  DecisionItem(
    id: 'book_chapter7_discussion',
    groupId: 'college_crew',
    ciphertextPayload: 'Which book for chapter 7?',
    nonce: 'books',
    state: 'proposed',
    weightedScore: 2,
    agreementScore: 0.17,
    reactions: const {'maya': 'works_for_me'},
    proposedBy: 'maya',
  ),
  DecisionItem(
    id: 'goa_flight_spicejet_vs_indigo',
    groupId: 'trip_2027',
    ciphertextPayload: 'SpiceJet or IndiGo for Goa?',
    nonce: 'flights',
    state: 'proposed',
    weightedScore: 4,
    agreementScore: 0.67,
    reactions: const {'ali': 'love_it', 'priya': 'works_for_me', 'james': 'works_for_me', 'me': 'love_it'},
    proposedBy: 'ali',
  ),
  DecisionItem(
    id: 'bali_cruise_option',
    groupId: 'trip_2027',
    ciphertextPayload: 'Add sunset cruise?',
    nonce: 'activities',
    state: 'locked',
    weightedScore: 12,
    agreementScore: 0.83,
    reactions: const {'ali': 'love_it', 'priya': 'love_it', 'james': 'works_for_me', 'maya': 'love_it', 'me': 'love_it'},
    proposedBy: 'ali',
    isLocked: true,
  ),
  DecisionItem(
    id: 'goa_hotel_zostel_vs_taj',
    groupId: 'trip_2027',
    ciphertextPayload: 'Zostel or Taj for Goa?',
    nonce: 'hotels',
    state: 'proposed',
    weightedScore: 1,
    agreementScore: 0.33,
    reactions: const {'ali': 'works_for_me', 'priya': 'not_for_me'},
    proposedBy: 'priya',
  ),
];

// ── Hero card metadata (keyed by DecisionItem.id) ──────────────

class MockHeroMeta {
  final String title;
  final String subtitle;
  final String photoUrl;
  final String? liveTag;
  final int votedCount;
  final int totalCount;
  const MockHeroMeta({
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    this.liveTag,
    required this.votedCount,
    required this.totalCount,
  });
}

final Map<String, MockHeroMeta> mockDecisionHero = {
  'goa_flight_spicejet_vs_indigo': const MockHeroMeta(
    title: 'SpiceJet or IndiGo?',
    subtitle: 'Goa flights · Dec 2027',
    photoUrl: 'assets/decide/bali_flight_sq.jpg',
    votedCount: 4,
    totalCount: 6,
  ),
  'bali_cruise_option': const MockHeroMeta(
    title: 'Sunset cruise',
    subtitle: 'Bali trip · optional add-on',
    photoUrl: 'assets/decide/bali_cruise.jpg',
    liveTag: 'LIVE EVENT',
    votedCount: 5,
    totalCount: 6,
  ),
};

// ── Small card metadata ────────────────────────────────────────

class MockSmallMeta {
  final String title;
  final String? eyebrow;
  const MockSmallMeta({required this.title, this.eyebrow});
}

final Map<String, MockSmallMeta> mockDecisionSmall = {
  'swiss_hotel_zostel_vs_taj': const MockSmallMeta(
    title: 'Goa hotel - Zostel or Taj?',
    eyebrow: 'TONIGHT · NEEDS YOU',
  ),
  'sunday_dinner_italian_place': const MockSmallMeta(
    title: 'Italian or Thai?',
    eyebrow: 'TONIGHT · NEEDS YOU',
  ),
  'book_chapter7_discussion': const MockSmallMeta(
    title: 'Which book for chapter 7?',
    eyebrow: 'COLLEGE CREW',
  ),
  'goa_hotel_zostel_vs_taj': const MockSmallMeta(
    title: 'Zostel or Taj for Goa?',
    eyebrow: 'GOA TRIP',
  ),
};

// ── Memory + AI nudge seed items ────────────────────────────────

final List<MemoryFeedItem> mockMemoryFeedItems = [
  MemoryFeedItem(
    memoryId: 'mem_swiss_sunset',
    eyebrow: '3 MONTHS AGO',
    title: 'That sunset in Interlaken',
    body: 'Remember when we almost missed the last train back?',
    photoUrl: 'assets/memories/swiss_sunset.jpg',
    occurredAt: DateTime(2026, 1, 15),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

final List<AiNudgeFeedItem> mockAiNudgeFeedItems = [
  AiNudgeFeedItem(
    nudgeId: 'nudge_bali_visa',
    message: 'Bali visa-on-arrival is free for 30 days. Your trip is 28 days — cutting it close.',
    ctaLabel: 'Check details',
    updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
  ),
];

/// Focus trip ID used by focusTripIdProvider.
const String kMockFocusTripId = 'swiss_jun_2026';
