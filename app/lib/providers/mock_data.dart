// Mock data for the decision board home screen.
//
// This file exists so the home screen can be reviewed visually while
// the engine is still unauthenticated. Flip [kUseMockData] to `false`
// to restore the real engine-backed providers.
//
// Scope guarantee: this file is imported by
// `conversations_provider.dart` and `decisions_provider.dart` and
// nothing else. No widget file imports from here. Rolling back means
// setting [kUseMockData] to `false` — or reverting this file and the
// two providers.

import 'package:e2ee_chat_sdk/e2ee_chat.dart';

/// Single on/off switch for mock data. `true` short-circuits the
/// engine-backed providers and returns the lists defined below.
const bool kUseMockData = true;

DateTime _ago(Duration d) => DateTime.now().subtract(d);

/// Seven direct messages and four group chats. The row widget derives
/// the display name from `conversation.id` for DMs (truncated to 8
/// chars) and from `participantIds.length` for groups — so DM ids are
/// kept short and readable ("sarah", "alex", …) and groups vary in
/// participant count so the "Group · N members" line reads distinct.
final List<Conversation> mockConversations = <Conversation>[
  // ─── Direct messages (5) ───
  Conversation(
    id: 'sarah',
    type: ConversationType.oneToOne,
    participantIds: const ['me', 'sarah'],
    createdAt: _ago(const Duration(days: 120)),
    updatedAt: _ago(const Duration(minutes: 4)),
    lastMessageText: 'hey are we still on for saturday?',
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
    lastMessageText: 'thanks for the rec 🙌',
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

  // ─── Group chats (4) ───
  Conversation(
    id: 'bali_trip',
    type: ConversationType.group,
    participantIds: const ['me', 'sarah', 'alex', 'maya', 'priya'],
    createdAt: _ago(const Duration(days: 21)),
    updatedAt: _ago(const Duration(minutes: 18)),
    lastMessageText: 'just booked the villa!! 🏝️',
    lastMessageTimestamp: _ago(const Duration(minutes: 18)),
    unreadCount: 8,
  ),
  Conversation(
    id: 'family',
    type: ConversationType.group,
    participantIds: const ['me', 'mom', 'dad', 'sis'],
    createdAt: _ago(const Duration(days: 900)),
    updatedAt: _ago(const Duration(hours: 2)),
    lastMessageText: 'dinner sunday? 🍝',
    lastMessageTimestamp: _ago(const Duration(hours: 2)),
    unreadCount: 2,
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
  Conversation(
    id: 'weekend_crew',
    type: ConversationType.group,
    participantIds: const ['me', 'mike', 'chris', 'sara', 'dan', 'nat'],
    createdAt: _ago(const Duration(days: 300)),
    updatedAt: _ago(const Duration(days: 3)),
    lastMessageText: "who's in for climbing saturday?",
    lastMessageTimestamp: _ago(const Duration(days: 3)),
  ),
];

/// Six active (unlocked, non-archived) decision items across three
/// groups. Scores are spaced to exercise every score-color band:
/// `>= 0.80` → gold, `>= 0.50` → rausch-light, `< 0.50` → warning.
///
/// Ids are ≥ 8 chars because `DecisionRow._title()` calls
/// `id.substring(0, 8)`. Reaction maps are populated so the subtitle
/// `"{state} · N reactions"` renders plausibly.
final List<DecisionItem> mockDecisions = <DecisionItem>[
  DecisionItem(
    id: 'flight_mar22_united_827',
    groupId: 'bali_trip',
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
  DecisionItem(
    id: 'sunday_dinner_italian_place',
    groupId: 'family',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.67,
    reactions: const {
      'mom': 'works_for_me',
      'dad': 'works_for_me',
      'me': 'love_it',
    },
  ),
  DecisionItem(
    id: 'book_chapter7_discussion',
    groupId: 'book_club',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'proposed',
    agreementScore: 0.55,
    reactions: const {
      'zoe': 'works_for_me',
      'lin': 'works_for_me',
      'me': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'saturday_climbing_outdoor',
    groupId: 'weekend_crew',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'nominated',
    agreementScore: 0.42,
    reactions: const {
      'mike': 'works_for_me',
      'me': 'works_for_me',
    },
  ),
  DecisionItem(
    id: 'monday_brunch_spot_downtown',
    groupId: 'bali_trip',
    ciphertextPayload: 'mock',
    nonce: 'mock',
    state: 'nominated',
    agreementScore: 0.35,
    reactions: const {
      'me': 'not_for_me',
    },
  ),
];
