// Seed / playground data for the decision board home screen.
//
// These lists serve as seed data for development and playground mode.
// They are no longer gated behind a runtime flag — providers read from
// the real engine when initialized, and return empty lists otherwise.

import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/itinerary_event.dart';
import '../models/settlement.dart';
import '../models/trip.dart';

const String kMockFocusTripId = 'swiss_jun_2026';

DateTime _ago(Duration d) => DateTime.now().subtract(d);
DateTime _ahead(Duration d) => DateTime.now().add(d);

// ─── Conversations ─────────────────────────────────────────────────

final List<Conversation> mockConversations = <Conversation>[
  // DMs (5)
  Conversation(
    id: 'sarah',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'sarah'],
    createdAt: _ago(const Duration(days: 120)),
    updatedAt: _ago(const Duration(minutes: 4)),
    lastMessageText: 'Reached? Swiss looks insane.',
    lastMessageTimestamp: _ago(const Duration(minutes: 4)),
    unreadCount: 3,
  ),
  Conversation(
    id: 'alex',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'alex'],
    createdAt: _ago(const Duration(days: 60)),
    updatedAt: _ago(const Duration(minutes: 42)),
    lastMessageText: 'just dropped you the link — lmk what you think',
    lastMessageTimestamp: _ago(const Duration(minutes: 42)),
    unreadCount: 1,
  ),
  Conversation(
    id: 'maya',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'maya'],
    createdAt: _ago(const Duration(days: 14)),
    updatedAt: _ago(const Duration(hours: 3)),
    lastMessageText: 'lol yes!! that sounds amazing',
    lastMessageTimestamp: _ago(const Duration(hours: 3)),
  ),
  Conversation(
    id: 'priya',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'priya'],
    createdAt: _ago(const Duration(days: 200)),
    updatedAt: _ago(const Duration(days: 1)),
    lastMessageText: 'thanks for the rec',
    lastMessageTimestamp: _ago(const Duration(days: 1)),
  ),
  Conversation(
    id: 'jordan',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'jordan'],
    createdAt: _ago(const Duration(days: 500)),
    updatedAt: _ago(const Duration(days: 3)),
    lastMessageText: 'call me when you can',
    lastMessageTimestamp: _ago(const Duration(days: 3)),
  ),

  // Groups (4)
  Conversation(
    id: 'bali_trip',
    type: ConversationType.group,
    participantIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    createdAt: _ago(const Duration(days: 21)),
    updatedAt: _ago(const Duration(minutes: 18)),
    lastMessageText: 'just booked the villa!!',
    lastMessageTimestamp: _ago(const Duration(minutes: 18)),
    unreadCount: 8,
  ),
  Conversation(
    id: 'family',
    type: ConversationType.group,
    participantIds: const ['me', 'mom', 'dad', 'sis'],
    createdAt: _ago(const Duration(days: 900)),
    updatedAt: _ago(const Duration(hours: 2)),
    lastMessageText: 'dinner sunday?',
    lastMessageTimestamp: _ago(const Duration(hours: 2)),
    unreadCount: 2,
  ),
  Conversation(
    id: 'goa_group',
    type: ConversationType.group,
    participantIds: const ['me', 'mike', 'chris', 'sara', 'dan', 'nat'],
    createdAt: _ago(const Duration(days: 45)),
    updatedAt: _ago(const Duration(minutes: 25)),
    lastMessageText: 'Location dropped. Hotel links everywhere.',
    lastMessageTimestamp: _ago(const Duration(minutes: 25)),
    unreadCount: 12,
  ),
  Conversation(
    id: 'book_club',
    type: ConversationType.group,
    participantIds: const ['me', 'zoe', 'lin', 'kai', 'omar'],
    createdAt: _ago(const Duration(days: 180)),
    updatedAt: _ago(const Duration(days: 1)),
    lastMessageText: 'chapter 7 discussion tonight @ 8',
    lastMessageTimestamp: _ago(const Duration(days: 1)),
  ),
];

// ─── Decisions ─────────────────────────────────────────────────────

final List<DecisionItem> mockDecisions = <DecisionItem>[
  DecisionItem(
    id: 'flight_mar22_united_827',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'ranked',
    agreementScore: 0.82,
    reactions: const {
      'sarah': 'love_it',
      'alex': 'love_it',
      'maya': 'works_for_me',
      'priya': 'works_for_me',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'villa_ubud_seaview_3br',
    groupId: 'bali_trip',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'ranked',
    agreementScore: 0.76,
    reactions: const {
      'sarah': 'love_it',
      'alex': 'works_for_me',
      'maya': 'love_it',
      'me': 'works_for_me',
    },
  ),
  // 'me' NOT in reactions → appears in "Needs You" counter
  DecisionItem(
    id: 'sunday_dinner_italian_place',
    groupId: 'family',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.33,
    reactions: const {
      'mom': 'works_for_me',
      'dad': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'book_chapter7_discussion',
    groupId: 'book_club',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.33,
    reactions: const {
      'zoe': 'works_for_me',
      'lin': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'goa_hotel_zostel_vs_taj',
    groupId: 'goa_group',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.33,
    reactions: const {
      'mike': 'works_for_me',
      'chris': 'not_for_me',
    },
  ),

  // ── Plans-view items (title in ciphertextPayload, event|category in nonce) ──
  DecisionItem(
    id: 'plan_hawaii_hotel_four_seasons',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'Four Seasons Resort Maui',
    nonce: 'Hawaii (Maui)|Hotels',
    state: 'ranked',
    weightedScore: 85,
    agreementScore: 0.85,
    proposedBy: 'Mom',
    reactions: const {
      'sarah': 'love_it',
      'alex': 'love_it',
      'maya': 'works_for_me',
      'priya': 'works_for_me',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'plan_hawaii_hotel_andaz',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'Andaz Maui at Wailea',
    nonce: 'Hawaii (Maui)|Hotels',
    state: 'ranked',
    weightedScore: 65,
    agreementScore: 0.65,
    proposedBy: 'Me',
    reactions: const {
      'sarah': 'works_for_me',
      'alex': 'love_it',
      'maya': 'works_for_me',
      'me': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'plan_hawaii_flight_united',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'United SFO -> OGG',
    nonce: 'Hawaii (Maui)|Flights',
    state: 'proposed',
    weightedScore: 40,
    agreementScore: 0.4,
    proposedBy: 'Dad',
    reactions: const {
      'alex': 'works_for_me',
      'me': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'plan_hawaii_hana_tour',
    groupId: 'swiss_jun_2026',
    ciphertextPayload: 'Road to Hana Tour',
    nonce: 'Hawaii (Maui)|Experiences',
    state: 'locked',
    weightedScore: 90,
    agreementScore: 0.9,
    isLocked: true,
    proposedBy: 'Me',
    reactions: const {
      'sarah': 'love_it',
      'alex': 'love_it',
      'maya': 'love_it',
      'priya': 'works_for_me',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'plan_dinner_moms_60th',
    groupId: 'family',
    ciphertextPayload: "Mom's 60th Birthday Dinner",
    nonce: 'Dinners|General',
    state: 'locked',
    weightedScore: 120,
    agreementScore: 1.0,
    isLocked: true,
    proposedBy: 'Dad',
    reactions: const {
      'mom': 'love_it',
      'dad': 'love_it',
      'sis': 'love_it',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'plan_dinner_gary_danko',
    groupId: 'family',
    ciphertextPayload: 'Gary Danko',
    nonce: 'Dinners|Restaurants',
    state: 'ranked',
    weightedScore: 80,
    agreementScore: 0.8,
    proposedBy: 'Alex',
    reactions: const {
      'sarah': 'love_it',
      'alex': 'love_it',
      'maya': 'works_for_me',
      'me': 'love_it',
    },
  ),
];

final Map<
    String,
    ({
      String photoUrl,
      String title,
      String subtitle,
      String? liveTag,
      int votedCount,
      int totalCount
    })> mockDecisionHero = {
  'flight_mar22_united_827': (
    photoUrl:
        'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=800',
    title: 'Zurich flight · United 827',
    subtitle: 'Direct ORD → ZRH · Jun 12',
    liveTag: 'LIVE EVENT',
    votedCount: 5,
    totalCount: 5,
  ),
  'villa_ubud_seaview_3br': (
    photoUrl:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
    title: 'Villa Ubud · 3BR seaview',
    subtitle: '\$340/night · 8 nights',
    liveTag: null,
    votedCount: 4,
    totalCount: 5,
  ),
  'goa_hotel_zostel_vs_taj': (
    photoUrl:
        'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=800',
    title: 'Goa hotel · Zostel or Taj?',
    subtitle: '3 still deciding · live',
    liveTag: 'LIVE EVENT',
    votedCount: 3,
    totalCount: 6,
  ),
};

/// Photo URLs for plans-view decision items.
/// Keyed by DecisionItem.id.
final Map<String, String> mockDecisionPhoto = {
  'plan_hawaii_hotel_four_seasons': 'assets/decide/hawaii_hotel1.jpg',
  'plan_hawaii_hotel_andaz': 'assets/decide/hawaii_hotel1.jpg',
  'plan_hawaii_hana_tour': 'assets/decide/bali_beach.jpg',
};

final Map<String, ({String title, String? eyebrow})> mockDecisionSmall = {
  'sunday_dinner_italian_place': (
    title: 'Italian or Thai?',
    eyebrow: 'TONIGHT · NEEDS YOU',
  ),
  'book_chapter7_discussion': (
    title: 'Which book next?',
    eyebrow: 'BOOK CLUB',
  ),
};

// ─── Trips ─────────────────────────────────────────────────────────

final List<Trip> mockTrips = <Trip>[
  Trip(
    id: 'swiss_jun_2026',
    destination: 'Swiss Alps',
    photoUrl:
        'https://images.unsplash.com/photo-1527004013197-933c4bb611b3?w=1200',
    startDate: DateTime(2026, 6, 12),
    endDate: DateTime(2026, 6, 20),
    memberIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    pendingDecisionCount: 3,
    phase: 'planning',
    accentColor: const Color(0xFF4A90E2), // alpine blue
    updatedAt: _ago(const Duration(hours: 2)),
  ),
  Trip(
    id: 'goa_sep_2026',
    destination: 'Goa',
    photoUrl:
        'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=1200',
    startDate: DateTime(2026, 9, 3),
    endDate: DateTime(2026, 9, 10),
    memberIds: const ['me', 'mike', 'chris', 'sara', 'dan', 'nat'],
    pendingDecisionCount: 5,
    phase: 'planning',
    accentColor: const Color(0xFF14B8A6), // ocean teal
    updatedAt: _ago(const Duration(days: 1)),
  ),
  Trip(
    id: 'bali_past_2026',
    destination: 'Bali',
    photoUrl:
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200',
    startDate: DateTime(2026, 3, 15),
    endDate: DateTime(2026, 3, 22),
    memberIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    pendingDecisionCount: 0,
    phase: 'done',
    accentColor: const Color(0xFFFF9B6E),
    updatedAt: _ago(const Duration(days: 19)),
  ),
];

// ─── Settlements ───────────────────────────────────────────────────

final List<Settlement> mockSettlements = <Settlement>[
  Settlement(
    id: 'settle_1',
    counterpartyId: 'sarah',
    counterpartyName: 'Sarah',
    amount: -42.50,
    currency: 'USD',
    reason: 'Alila villa deposit',
    updatedAt: _ago(const Duration(hours: 6)),
  ),
  Settlement(
    id: 'settle_2',
    counterpartyId: 'maya',
    counterpartyName: 'Maya',
    amount: 18.00,
    currency: 'USD',
    reason: 'Venice dinner split',
    updatedAt: _ago(const Duration(days: 2)),
  ),
];

// ─── Itinerary ─────────────────────────────────────────────────────

final List<ItineraryEvent> mockItinerary = <ItineraryEvent>[
  ItineraryEvent(
    id: 'itin_1',
    title: 'Dinner at Alila',
    location: 'Ubud, Bali',
    startsAt: _ahead(const Duration(hours: 7)),
    memberIds: const ['me', 'sarah', 'alex'],
    groupId: 'bali_trip',
    updatedAt: _ago(const Duration(minutes: 30)),
  ),
  ItineraryEvent(
    id: 'itin_2',
    title: 'Flight ZRH → ORD',
    location: 'Zurich Airport',
    startsAt: DateTime(2026, 6, 20, 14, 30),
    memberIds: const ['me', 'sarah'],
    groupId: 'swiss_jun_2026',
    updatedAt: _ago(const Duration(days: 3)),
  ),
];

// ─── Memories ──────────────────────────────────────────────────────

final List<MemoryFeedItem> mockMemoryFeedItems = <MemoryFeedItem>[
  MemoryFeedItem(
    memoryId: 'bali_alila',
    eyebrow: 'A YEAR AGO TODAY',
    title: 'Alila Ubud',
    body: 'The Bali crew chose this villa. Worth a revisit for Goa?',
    photoUrl:
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
    occurredAt: _ago(const Duration(days: 365)),
    updatedAt: _ago(const Duration(hours: 18)),
  ),
];

// ─── AI nudges ─────────────────────────────────────────────────────

final List<AiNudgeFeedItem> mockAiNudgeFeedItems = <AiNudgeFeedItem>[
  AiNudgeFeedItem(
    nudgeId: 'swiss_hotel_nudge',
    message:
        'Swiss trip in 62 days and the hotel vote is still open. Want me to summarize the top three options?',
    ctaLabel: 'Summarize',
    updatedAt: _ago(const Duration(hours: 1)),
  ),
];
