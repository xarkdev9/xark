// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/cache/discovery_cache.dart';
import 'package:e2ee_chat_sdk/src/discovery/feedback/error_capture.dart';
import 'package:e2ee_chat_sdk/src/discovery/feedback/feedback_collector.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';
import 'package:e2ee_chat_sdk/src/discovery/ranking/taste_ranker.dart';
import 'package:e2ee_chat_sdk/src/discovery/ranking/taste_signal.dart';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// Shared helper
// -----------------------------------------------------------------------------

/// Builds a [DiscoveryItem] with sensible defaults and overridable fields.
DiscoveryItem makeItem({
  required String id,
  required String title,
  DiscoveryCategory category = DiscoveryCategory.restaurants,
  String? subtitle,
  double? price,
  String currency = 'USD',
  String? location,
  List<String> tags = const [],
  String? dietary,
  List<String>? allergies,
  String source = 'test',
  DateTime? fetchedAt,
}) {
  return DiscoveryItem(
    id: id,
    title: title,
    subtitle: subtitle,
    category: category,
    price: price,
    currency: currency,
    location: location,
    metadata: {
      'tags': tags,
      if (dietary != null) 'dietary': [dietary],
      if (allergies != null) 'allergies': allergies,
    },
    source: source,
    fetchedAt: fetchedAt ?? DateTime.utc(2026, 4, 1),
  );
}

// =============================================================================
// Scenario 1 data builders
// =============================================================================

/// Creates 30 realistic items for the Rome vegetarian traveler scenario.
List<DiscoveryItem> _buildRomeItems() {
  return [
    // --- 8 restaurants ---
    // 3 Italian (vegetarian)
    makeItem(
      id: 'rest-it-1',
      title: 'Trattoria Bella Roma',
      subtitle: 'Classic Italian',
      price: 28.0,
      location: 'Trastevere, Rome',
      tags: ['italian', 'pasta', 'cozy'],
      dietary: 'vegetarian',
    ),
    makeItem(
      id: 'rest-it-2',
      title: 'Pasta Fresca al Dente',
      subtitle: 'Handmade Pasta',
      price: 32.0,
      location: 'Centro Storico, Rome',
      tags: ['italian', 'handmade', 'fresh'],
      dietary: 'vegetarian',
    ),
    makeItem(
      id: 'rest-it-3',
      title: 'Pizzeria Napoli Express',
      subtitle: 'Neapolitan Pizza',
      price: 18.0,
      location: 'Testaccio, Rome',
      tags: ['italian', 'pizza', 'casual'],
      dietary: 'vegetarian',
    ),
    // 2 seafood (vegetarian-safe for ranking, but not dietary=vegetarian)
    makeItem(
      id: 'rest-sea-1',
      title: 'Pesce Fresco',
      subtitle: 'Fresh Catch Daily',
      price: 45.0,
      location: 'Trastevere, Rome',
      tags: ['seafood', 'fresh', 'coastal'],
      dietary: 'pescatarian',
    ),
    makeItem(
      id: 'rest-sea-2',
      title: 'Oyster & Wine Bar',
      subtitle: 'Raw Bar Specialists',
      price: 55.0,
      location: 'Prati, Rome',
      tags: ['seafood', 'wine', 'upscale'],
      dietary: 'pescatarian',
    ),
    // 1 steakhouse (MEAT -> filtered out)
    makeItem(
      id: 'rest-steak',
      title: 'Angus Prime Steakhouse',
      subtitle: 'Premium Cuts',
      price: 65.0,
      location: 'Via Veneto, Rome',
      tags: ['meat', 'steak', 'premium'],
      dietary: 'carnivore',
    ),
    // 1 Indian (vegetarian)
    makeItem(
      id: 'rest-indian',
      title: 'Masala Kitchen',
      subtitle: 'Authentic North Indian',
      price: 22.0,
      location: 'Esquilino, Rome',
      tags: ['indian', 'curry', 'spicy'],
      dietary: 'vegetarian',
    ),
    // 1 Thai (vegetarian)
    makeItem(
      id: 'rest-thai',
      title: 'Bangkok Garden',
      subtitle: 'Thai Street Food',
      price: 20.0,
      location: 'Monti, Rome',
      tags: ['thai', 'street-food', 'noodles'],
      dietary: 'vegetarian',
    ),

    // --- 5 hotels ---
    makeItem(
      id: 'hotel-1',
      title: 'Hotel Colosseum View',
      category: DiscoveryCategory.hotels,
      price: 180.0,
      location: 'Centro Storico, Rome',
      tags: ['luxury', 'views', 'central'],
    ),
    makeItem(
      id: 'hotel-2',
      title: 'Trastevere B&B',
      category: DiscoveryCategory.hotels,
      price: 75.0,
      location: 'Trastevere, Rome',
      tags: ['boutique', 'cozy', 'local'],
    ),
    makeItem(
      id: 'hotel-3',
      title: 'Roma Budget Hostel',
      category: DiscoveryCategory.hotels,
      price: 30.0,
      location: 'Termini, Rome',
      tags: ['budget', 'social', 'central'],
    ),
    makeItem(
      id: 'hotel-4',
      title: 'Palazzo Luxury Suite',
      category: DiscoveryCategory.hotels,
      price: 350.0,
      location: 'Piazza Navona, Rome',
      tags: ['luxury', 'suite', 'historic'],
    ),
    makeItem(
      id: 'hotel-5',
      title: 'Eco Lodge Roma',
      category: DiscoveryCategory.hotels,
      price: 95.0,
      location: 'EUR, Rome',
      tags: ['eco', 'sustainable', 'quiet'],
    ),

    // --- 7 activities ---
    makeItem(
      id: 'act-1',
      title: 'Colosseum Guided Tour',
      category: DiscoveryCategory.activities,
      price: 35.0,
      location: 'Colosseum, Rome',
      tags: ['cultural', 'history', 'guided'],
    ),
    makeItem(
      id: 'act-2',
      title: 'Vatican Museum Skip-the-Line',
      category: DiscoveryCategory.activities,
      price: 45.0,
      location: 'Vatican City',
      tags: ['cultural', 'art', 'museum'],
    ),
    makeItem(
      id: 'act-3',
      title: 'Trastevere Food Tour',
      category: DiscoveryCategory.activities,
      price: 55.0,
      location: 'Trastevere, Rome',
      tags: ['food-tour', 'italian', 'walking'],
    ),
    makeItem(
      id: 'act-4',
      title: 'Bike Tour along the Tiber',
      category: DiscoveryCategory.activities,
      price: 25.0,
      location: 'Tiber River, Rome',
      tags: ['outdoor', 'biking', 'scenic'],
    ),
    makeItem(
      id: 'act-5',
      title: 'Italian Cooking Class',
      category: DiscoveryCategory.activities,
      price: 60.0,
      location: 'Testaccio, Rome',
      tags: ['italian', 'cooking', 'hands-on'],
    ),
    makeItem(
      id: 'act-6',
      title: 'Wine Tasting in Frascati',
      category: DiscoveryCategory.activities,
      price: 70.0,
      location: 'Frascati, Rome',
      tags: ['wine', 'tasting', 'countryside'],
    ),
    makeItem(
      id: 'act-7',
      title: 'Sunrise Jog at Villa Borghese',
      category: DiscoveryCategory.activities,
      price: 0.0,
      location: 'Villa Borghese, Rome',
      tags: ['outdoor', 'fitness', 'free'],
    ),

    // --- 5 destinations (neighborhoods) ---
    makeItem(
      id: 'dest-1',
      title: 'Trastevere',
      category: DiscoveryCategory.destinations,
      location: 'Rome',
      tags: ['nightlife', 'food', 'charming'],
    ),
    makeItem(
      id: 'dest-2',
      title: 'Monti',
      category: DiscoveryCategory.destinations,
      location: 'Rome',
      tags: ['vintage', 'cafes', 'artsy'],
    ),
    makeItem(
      id: 'dest-3',
      title: 'Testaccio',
      category: DiscoveryCategory.destinations,
      location: 'Rome',
      tags: ['food', 'local', 'authentic'],
    ),
    makeItem(
      id: 'dest-4',
      title: 'Vatican Area',
      category: DiscoveryCategory.destinations,
      location: 'Rome',
      tags: ['cultural', 'museums', 'spiritual'],
    ),
    makeItem(
      id: 'dest-5',
      title: 'EUR District',
      category: DiscoveryCategory.destinations,
      location: 'Rome',
      tags: ['modern', 'architecture', 'quiet'],
    ),

    // --- 5 day plans ---
    makeItem(
      id: 'plan-1',
      title: 'Classic Rome in a Day',
      category: DiscoveryCategory.dayPlans,
      price: 50.0,
      location: 'Rome',
      tags: ['cultural', 'walking', 'highlights'],
    ),
    makeItem(
      id: 'plan-2',
      title: 'Foodie Day: Trastevere + Testaccio',
      category: DiscoveryCategory.dayPlans,
      price: 40.0,
      location: 'Rome',
      tags: ['food', 'italian', 'local'],
    ),
    makeItem(
      id: 'plan-3',
      title: 'Vatican + Castel Sant Angelo',
      category: DiscoveryCategory.dayPlans,
      price: 55.0,
      location: 'Rome',
      tags: ['cultural', 'history', 'art'],
    ),
    makeItem(
      id: 'plan-4',
      title: 'Day Trip to Ostia Antica',
      category: DiscoveryCategory.dayPlans,
      price: 30.0,
      location: 'Ostia Antica',
      tags: ['outdoor', 'ruins', 'day-trip'],
    ),
    makeItem(
      id: 'plan-5',
      title: 'Luxury Spa + Shopping',
      category: DiscoveryCategory.dayPlans,
      price: 200.0,
      location: 'Via Condotti, Rome',
      tags: ['luxury', 'shopping', 'spa'],
    ),
  ];
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // Scenario 1: Complete discovery flow for a vegetarian traveler to Rome
  // ===========================================================================
  group('Scenario 1: Vegetarian traveler to Rome — full pipeline', () {
    late TasteRanker ranker;
    late DiscoveryCache cache;
    late ErrorCapture errorCapture;
    late FeedbackCollector feedbackCollector;
    late TasteProfile profile;
    late List<DiscoveryItem> items;

    setUp(() {
      ranker = TasteRanker();
      cache = DiscoveryCache();
      errorCapture = ErrorCapture();
      feedbackCollector = FeedbackCollector(errorCapture);

      // Vegetarian, loves Italian + seafood, budget $15-$60.
      profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
        },
        implicitWeights: {
          'restaurants': 0.9,
          'activities': 0.7,
          'destinations': 0.5,
          'dayPlans': 0.6,
          'hotels': 0.4,
        },
        tagWeights: {
          'italian': 5.0,
          'seafood': 4.0,
          'pasta': 3.0,
          'cultural': 2.0,
          'outdoor': 1.5,
          'food': 2.5,
          'food-tour': 3.0,
        },
        priceMin: 15.0,
        priceMax: 60.0,
      );

      items = _buildRomeItems();
    });

    // -------------------------------------------------------------------------
    // Step 1-2: Verify we have 30 items
    // -------------------------------------------------------------------------
    test('dataset contains exactly 30 items', () {
      expect(items, hasLength(30));
    });

    // -------------------------------------------------------------------------
    // Step 3-4: Cache all items and retrieve
    // -------------------------------------------------------------------------
    test('cache stores and retrieves all 30 items', () {
      cache.cacheItems(items);

      // The "all" key should contain all items.
      final cached = cache.getCached(null);
      expect(cached, isNotNull);
      expect(cached!, hasLength(30));

      // Category-specific retrieval.
      final restaurants =
          cache.getCached(DiscoveryCategory.restaurants, location: 'any');
      // Restaurants don't have location set to match "any" key.
      // But the all-key query should work.
      expect(cache.itemCount, greaterThanOrEqualTo(30));
    });

    // -------------------------------------------------------------------------
    // Step 5: Rank and verify ordering
    // -------------------------------------------------------------------------
    test('5a: steakhouse filtered out (meat violates vegetarian constraint)',
        () {
      final ranked = ranker.rank(items, profile);
      final ids = ranked.map((i) => i.id).toSet();

      expect(ids, isNot(contains('rest-steak')));
    });

    test('5a: seafood items filtered out (pescatarian != vegetarian)', () {
      final ranked = ranker.rank(items, profile);
      final ids = ranked.map((i) => i.id).toSet();

      // Seafood items have dietary: 'pescatarian', which violates vegetarian.
      expect(ids, isNot(contains('rest-sea-1')));
      expect(ids, isNot(contains('rest-sea-2')));
    });

    test('5b: Italian restaurants rank in top 5', () {
      final ranked = ranker.rank(items, profile);
      final topFive = ranked.take(5).map((i) => i.id).toSet();
      final italianIds = {'rest-it-1', 'rest-it-2', 'rest-it-3'};

      // At least 1 Italian restaurant should be in top 5.
      final italianInTop = topFive.intersection(italianIds);
      expect(
        italianInTop.length,
        greaterThanOrEqualTo(1),
        reason:
            'Expected Italian restaurants in top 5, got top 5: $topFive',
      );
    });

    test('5d: items within budget rank higher than luxury items', () {
      final ranked = ranker.rank(items, profile);

      // Compare the best in-budget restaurant vs the luxury day plan.
      final inBudgetRestaurants = ranked.where(
        (i) =>
            i.category == DiscoveryCategory.restaurants &&
            i.price != null &&
            i.price! >= 15 &&
            i.price! <= 60,
      );
      final luxuryItems = ranked.where(
        (i) => i.price != null && i.price! > 100,
      );

      if (inBudgetRestaurants.isNotEmpty && luxuryItems.isNotEmpty) {
        expect(
          inBudgetRestaurants.first.tasteScore,
          greaterThan(luxuryItems.first.tasteScore),
          reason: 'In-budget restaurants should score higher than luxury items',
        );
      }
    });

    test('5e: all returned items have tasteScore > 0', () {
      final ranked = ranker.rank(items, profile);

      for (final item in ranked) {
        expect(
          item.tasteScore,
          greaterThan(0.0),
          reason: '${item.id} should have tasteScore > 0',
        );
      }
    });

    test('5f: top items have tasteReason set', () {
      final ranked = ranker.rank(items, profile);
      // At least some top items should have reasons.
      final topWithReasons = ranked.take(5).where(
            (i) => i.tasteReason != null && i.tasteReason!.isNotEmpty,
          );

      expect(
        topWithReasons,
        isNotEmpty,
        reason: 'Expected at least one top item with a taste reason',
      );
    });

    // -------------------------------------------------------------------------
    // Step 6: User actions via TasteSignal
    // -------------------------------------------------------------------------
    test('6: user saves, dismisses, and adds to board', () {
      final ranked = ranker.rank(items, profile);
      final topItem = ranked.first;
      final bottomItem = ranked.last;
      final midItem = ranked[ranked.length ~/ 2];

      // 6a: Save top item.
      var updatedProfile = TasteSignal.applySignal(
        profile,
        topItem,
        TasteSignal.actionSaved,
      );
      expect(updatedProfile.savedItemIds, contains(topItem.id));

      // 6b: Dismiss bottom item.
      updatedProfile = TasteSignal.applySignal(
        updatedProfile,
        bottomItem,
        TasteSignal.actionDismissed,
      );
      expect(updatedProfile.dismissedItemIds, contains(bottomItem.id));

      // 6c: Add mid item to board.
      updatedProfile = TasteSignal.applySignal(
        updatedProfile,
        midItem,
        TasteSignal.actionAddedToBoard,
      );

      // Verify the category weight for the added item increased.
      final categoryName = midItem.category.name;
      final originalWeight = profile.implicitWeights[categoryName] ?? 0.5;
      final updatedWeight =
          updatedProfile.implicitWeights[categoryName] ?? 0.5;
      expect(
        updatedWeight,
        greaterThan(originalWeight),
        reason:
            'Category weight for $categoryName should increase after add_to_board',
      );
    });

    // -------------------------------------------------------------------------
    // Step 7: Re-rank with updated profile
    // -------------------------------------------------------------------------
    test('7a: dismissed item excluded on re-rank', () {
      final ranked = ranker.rank(items, profile);
      final dismissed = ranked.last;

      final updatedProfile = TasteSignal.applySignal(
        profile,
        dismissed,
        TasteSignal.actionDismissed,
      );

      final reRanked = ranker.rank(items, updatedProfile);
      final reRankedIds = reRanked.map((i) => i.id).toSet();

      expect(reRankedIds, isNot(contains(dismissed.id)));
    });

    test('7b: category of saved/added items has higher weight', () {
      final ranked = ranker.rank(items, profile);
      final savedItem = ranked.first;

      var updatedProfile = TasteSignal.applySignal(
        profile,
        savedItem,
        TasteSignal.actionSaved,
      );
      updatedProfile = TasteSignal.applySignal(
        updatedProfile,
        savedItem,
        TasteSignal.actionAddedToBoard,
      );

      final categoryName = savedItem.category.name;
      final originalWeight = profile.implicitWeights[categoryName] ?? 0.5;
      final boostedWeight =
          updatedProfile.implicitWeights[categoryName] ?? 0.5;

      expect(
        boostedWeight,
        greaterThan(originalWeight),
        reason:
            'Category $categoryName weight should be higher after save + add_to_board',
      );
    });

    // -------------------------------------------------------------------------
    // Step 8: Feedback flow
    // -------------------------------------------------------------------------
    test('8a-b: ErrorCapture captures search_timeout and getRecent returns it',
        () {
      final report = errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Search query timed out after 30s',
        context: {
          'query': 'best pasta near me',
          'elapsed_ms': 30000,
        },
      );

      expect(report.errorType, 'search_timeout');
      expect(report.errorMessage, contains('timed out'));

      final recent = errorCapture.getRecent();
      expect(recent, isNotNull);
      expect(recent!.id, report.id);
    });

    test('8c: buildHelloFeedbackPrompt references the error', () {
      final report = errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Timed out',
      );

      final prompt = feedbackCollector.buildHelloFeedbackPrompt(report);

      expect(prompt, contains('search_timeout'));
      expect(prompt, contains('can you tell me'));
    });

    test('8d-e: submitFeedback creates report with description and context',
        () {
      // First capture the error.
      errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Timed out',
      );

      // User submits feedback.
      final feedbackReport = feedbackCollector.submitFeedback(
        message: 'I was searching for restaurants and it froze',
        context: {'screen': 'explore', 'action': 'search'},
      );

      expect(feedbackReport.errorType, 'user_feedback');
      expect(
        feedbackReport.errorMessage,
        'I was searching for restaurants and it froze',
      );
      expect(feedbackReport.context['source'], 'user_feedback');
      expect(feedbackReport.context['screen'], 'explore');
    });

    test('8f: sanitizeContext strips sensitive keys', () {
      final rawContext = <String, dynamic>{
        'url': '/api/feed',
        'method': 'GET',
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        'api_key': 'sk-secret-12345',
        'password': 'hunter2',
        'plaintext': 'should be stripped',
        'taste': 'also stripped because sensitive',
        'screen': 'explore',
      };

      final sanitized = ErrorCapture.sanitizeContext(rawContext);

      // Safe keys preserved.
      expect(sanitized['url'], '/api/feed');
      expect(sanitized['method'], 'GET');
      expect(sanitized['screen'], 'explore');

      // Sensitive keys stripped.
      expect(sanitized.containsKey('token'), isFalse);
      expect(sanitized.containsKey('api_key'), isFalse);
      expect(sanitized.containsKey('password'), isFalse);
      expect(sanitized.containsKey('plaintext'), isFalse);
      expect(sanitized.containsKey('taste'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Step 9: Cache expiry
    // -------------------------------------------------------------------------
    test('9: cache with 1-second TTL expires and prunes correctly', () async {
      final shortCache = DiscoveryCache(
        defaultTtl: const Duration(seconds: 1),
      );

      final testItems = [
        makeItem(id: 'ttl-1', title: 'Expiring Item 1'),
        makeItem(id: 'ttl-2', title: 'Expiring Item 2'),
      ];

      shortCache.cacheItems(testItems);

      // Items should be available immediately.
      expect(shortCache.getCached(null), isNotNull);
      expect(shortCache.getCached(null)!, hasLength(2));

      // Wait for TTL to expire.
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      // Items should be expired now.
      expect(shortCache.getCached(null), isNull);

      // Prune should clean up internal state.
      shortCache.pruneExpired();
      expect(shortCache.entryCount, 0);
    });
  });

  // ===========================================================================
  // Scenario 2: Group trip discovery — taste intersection
  // ===========================================================================
  group('Scenario 2: Group trip — taste intersection', () {
    late TasteRanker ranker;

    setUp(() {
      ranker = TasteRanker();
    });

    test('intersected profile filters correctly for 3 group members', () {
      // Alice: vegetarian, loves Italian, budget $20-$50.
      // Bob: no restrictions, loves seafood, budget $10-$80.
      // Charlie: nut allergy, loves outdoor activities, budget $15-$40.

      // Manually intersected profile:
      // Hard constraints: vegetarian (Alice) + nut allergy (Charlie).
      // Implicit weights: averaged across three members.
      // Price range: $20-$40 (overlap of all three).
      final intersectedProfile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
          'allergies': ['nuts'],
        },
        implicitWeights: {
          // Average: Alice(0.9) + Bob(0.5) + Charlie(0.4) / 3
          'restaurants': 0.6,
          // Average: Alice(0.4) + Bob(0.3) + Charlie(0.9) / 3
          'activities': 0.53,
        },
        tagWeights: {
          'italian': 3.5, // Alice loves it, others neutral
          'seafood': 3.0, // Bob loves it, others neutral
          'outdoor': 2.5, // Charlie loves it, others neutral
          'cultural': 1.5,
        },
        priceMin: 20.0,
        priceMax: 40.0,
      );

      final groupItems = [
        // Restaurants.
        makeItem(
          id: 'g-veg-it',
          title: 'Veggie Italian Bistro',
          price: 25.0,
          tags: ['italian', 'vegetarian'],
          dietary: 'vegetarian',
        ),
        makeItem(
          id: 'g-steak',
          title: 'Steakhouse Grill',
          price: 35.0,
          tags: ['meat', 'steak'],
          dietary: 'carnivore',
        ),
        makeItem(
          id: 'g-nuts',
          title: 'Thai Peanut Kitchen',
          price: 22.0,
          tags: ['thai', 'peanuts'],
          dietary: 'vegetarian',
          allergies: ['nuts'],
        ),
        makeItem(
          id: 'g-seafood',
          title: 'Fresh Fish & Chips',
          price: 28.0,
          tags: ['seafood', 'casual'],
          dietary: 'pescatarian',
        ),
        makeItem(
          id: 'g-veg-indian',
          title: 'Curry Garden',
          price: 20.0,
          tags: ['indian', 'spicy', 'vegetarian'],
          dietary: 'vegetarian',
        ),
        makeItem(
          id: 'g-expensive-veg',
          title: 'Michelin Veggie',
          price: 120.0,
          tags: ['italian', 'fine-dining'],
          dietary: 'vegetarian',
        ),

        // Activities.
        makeItem(
          id: 'g-hike',
          title: 'Mountain Hike',
          category: DiscoveryCategory.activities,
          price: 25.0,
          tags: ['outdoor', 'hiking', 'nature'],
        ),
        makeItem(
          id: 'g-museum',
          title: 'Art Museum Tour',
          category: DiscoveryCategory.activities,
          price: 30.0,
          tags: ['cultural', 'art', 'indoor'],
        ),
        makeItem(
          id: 'g-kayak',
          title: 'Lake Kayaking',
          category: DiscoveryCategory.activities,
          price: 35.0,
          tags: ['outdoor', 'water', 'adventure'],
        ),
        makeItem(
          id: 'g-cooking',
          title: 'Pasta Making Class',
          category: DiscoveryCategory.activities,
          price: 38.0,
          tags: ['italian', 'cooking', 'hands-on'],
        ),
        makeItem(
          id: 'g-nut-trail',
          title: 'Nut Tasting Trail',
          category: DiscoveryCategory.activities,
          price: 20.0,
          tags: ['food', 'nuts'],
          allergies: ['nuts'],
        ),
        makeItem(
          id: 'g-bike',
          title: 'Countryside Bike Ride',
          category: DiscoveryCategory.activities,
          price: 22.0,
          tags: ['outdoor', 'biking', 'scenic'],
        ),

        // Extra restaurants.
        makeItem(
          id: 'g-sushi',
          title: 'Sushi Express',
          price: 30.0,
          tags: ['japanese', 'sushi'],
          dietary: 'pescatarian',
        ),
        makeItem(
          id: 'g-salad',
          title: 'Green Bowl Co',
          price: 18.0,
          tags: ['salad', 'healthy', 'vegetarian'],
          dietary: 'vegetarian',
        ),
        makeItem(
          id: 'g-pizza-veg',
          title: 'Pizza Vegana',
          price: 22.0,
          tags: ['italian', 'pizza', 'vegan'],
          dietary: 'vegetarian',
        ),
      ];

      final ranked = ranker.rank(groupItems, intersectedProfile);
      final rankedIds = ranked.map((i) => i.id).toSet();

      // No meat items.
      expect(rankedIds, isNot(contains('g-steak')),
          reason: 'Steakhouse should be filtered (vegetarian constraint)');

      // No nut items.
      expect(rankedIds, isNot(contains('g-nuts')),
          reason: 'Thai Peanut Kitchen filtered (nut allergy)');
      expect(rankedIds, isNot(contains('g-nut-trail')),
          reason: 'Nut Tasting Trail filtered (nut allergy)');

      // Seafood restaurants should be filtered (dietary pescatarian != veg).
      expect(rankedIds, isNot(contains('g-seafood')),
          reason:
              'Seafood restaurant filtered (pescatarian != vegetarian)');
      expect(rankedIds, isNot(contains('g-sushi')),
          reason: 'Sushi filtered (pescatarian != vegetarian)');

      // Vegetarian Italian bistro should be present and rank well.
      expect(rankedIds, contains('g-veg-it'));
      expect(rankedIds, contains('g-pizza-veg'));

      // Outdoor activities should be present.
      expect(rankedIds, contains('g-hike'));
      expect(rankedIds, contains('g-kayak'));
      expect(rankedIds, contains('g-bike'));

      // Items loved by all three should rank highest.
      // The Italian veggie bistro (Italian tags + in-budget + vegetarian)
      // should rank very well.
      final top5 = ranked.take(5).map((i) => i.id).toSet();
      final universallyLiked = {'g-veg-it', 'g-pizza-veg', 'g-hike', 'g-cooking'};
      final overlap = top5.intersection(universallyLiked);
      expect(
        overlap,
        isNotEmpty,
        reason: 'Items appealing to all members should appear in top 5. '
            'Top 5: $top5',
      );
    });
  });

  // ===========================================================================
  // Scenario 3: Edge cases
  // ===========================================================================
  group('Scenario 3: Edge cases', () {
    late TasteRanker ranker;

    setUp(() {
      ranker = TasteRanker();
    });

    test('empty item list returns empty', () {
      final profile = TasteProfile(
        implicitWeights: {'restaurants': 0.9},
        tagWeights: {'italian': 5.0},
      );

      final ranked = ranker.rank([], profile);

      expect(ranked, isEmpty);
    });

    test('empty taste profile gives all items a score around 0.5', () {
      final items = List.generate(
        5,
        (i) => makeItem(id: 'e-$i', title: 'Edge Item $i'),
      );

      final ranked = ranker.rank(items, TasteProfile.empty);

      expect(ranked, hasLength(5));
      for (final item in ranked) {
        // With no weights and no constraints, scores should hover around
        // the algorithm's neutral value. The exact value depends on defaults
        // (category default 0.5, price default 0.7, tag default 0.5,
        // diversity 1.0, recency 1.0 => ~0.59).
        expect(item.tasteScore, greaterThanOrEqualTo(0.0));
        expect(item.tasteScore, lessThanOrEqualTo(1.0));
        expect(
          item.tasteScore,
          closeTo(0.5, 0.2),
          reason: 'Neutral profile should give scores near 0.5, '
              'got ${item.tasteScore} for ${item.id}',
        );
      }
    });

    test('all items violate constraints returns empty', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
        },
      );

      final items = [
        makeItem(
          id: 'meat-1',
          title: 'Steak A',
          dietary: 'carnivore',
        ),
        makeItem(
          id: 'meat-2',
          title: 'Steak B',
          dietary: 'carnivore',
        ),
        makeItem(
          id: 'meat-3',
          title: 'Steak C',
          dietary: 'carnivore',
        ),
      ];

      final ranked = ranker.rank(items, profile);

      expect(ranked, isEmpty);
    });

    test('single item returns it with a score', () {
      final profile = TasteProfile(
        implicitWeights: {'restaurants': 0.8},
        tagWeights: {'italian': 3.0},
      );

      final items = [
        makeItem(
          id: 'solo',
          title: 'Only Option',
          tags: ['italian'],
        ),
      ];

      final ranked = ranker.rank(items, profile);

      expect(ranked, hasLength(1));
      expect(ranked.first.id, 'solo');
      expect(ranked.first.tasteScore, greaterThan(0.0));
    });

    test('100 items ranked in under 100ms', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
        },
        implicitWeights: {
          'restaurants': 0.8,
          'activities': 0.6,
          'hotels': 0.5,
        },
        tagWeights: {
          'italian': 5.0,
          'seafood': 3.0,
          'outdoor': 2.0,
          'cultural': 1.5,
          'budget': 1.0,
        },
        priceMin: 10.0,
        priceMax: 80.0,
      );

      final categories = DiscoveryCategory.values;
      final items = List.generate(100, (i) {
        final cat = categories[i % categories.length];
        return makeItem(
          id: 'perf-$i',
          title: 'Performance Item $i',
          category: cat,
          price: (i * 2.5) + 5.0,
          tags: [
            if (i % 3 == 0) 'italian',
            if (i % 4 == 0) 'seafood',
            if (i % 5 == 0) 'outdoor',
            'tag-$i',
          ],
          dietary: i % 2 == 0 ? 'vegetarian' : null,
        );
      });

      final stopwatch = Stopwatch()..start();
      final ranked = ranker.rank(items, profile);
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason:
            'Ranking 100 items took ${stopwatch.elapsedMilliseconds}ms (max 100ms)',
      );
      expect(ranked, isNotEmpty);
      // Verify sorting: scores should be descending.
      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i - 1].tasteScore,
          greaterThanOrEqualTo(ranked[i].tasteScore),
          reason: 'Items should be sorted by tasteScore descending',
        );
      }
    });

    test('all items dismissed returns empty', () {
      final items = [
        makeItem(id: 'd-1', title: 'A'),
        makeItem(id: 'd-2', title: 'B'),
        makeItem(id: 'd-3', title: 'C'),
      ];

      final profile = TasteProfile(
        dismissedItemIds: ['d-1', 'd-2', 'd-3'],
      );

      final ranked = ranker.rank(items, profile);

      expect(ranked, isEmpty);
    });

    test('duplicate item ids are handled by equality', () {
      final a = makeItem(id: 'dup', title: 'First');
      final b = makeItem(id: 'dup', title: 'Second');

      expect(a, equals(b));

      final ranked = ranker.rank([a, b], TasteProfile.empty);
      // Both exist in input, both should be ranked (engine does not deduplicate
      // — that is the responsibility of the cache or data layer).
      expect(ranked, hasLength(2));
    });

    test('items with no metadata tags still get a neutral tag score', () {
      final profile = TasteProfile(
        tagWeights: {'italian': 5.0},
      );

      final item = makeItem(
        id: 'no-tags',
        title: 'No Tags Item',
        // No tags in metadata (default is empty list via makeItem)
      );

      final ranked = ranker.rank(<DiscoveryItem>[item], profile);

      expect(ranked, hasLength(1));
      expect(ranked.first.tasteScore, greaterThan(0.0));
    });
  });

  // ===========================================================================
  // Scenario 4: Full pipeline integration (cache -> rank -> signal -> feedback)
  // ===========================================================================
  group('Scenario 4: Full pipeline — cache, rank, signal, feedback loop', () {
    test('end-to-end: cache -> rank -> signal -> re-rank -> feedback', () {
      // 1. Set up all components.
      final cache = DiscoveryCache();
      final ranker = TasteRanker();
      final errorCapture = ErrorCapture();
      final feedbackCollector = FeedbackCollector(errorCapture);

      var profile = TasteProfile(
        hardConstraints: {'dietary': ['vegetarian']},
        implicitWeights: {'restaurants': 0.8},
        tagWeights: {'italian': 4.0, 'healthy': 2.0},
        priceMin: 10.0,
        priceMax: 50.0,
      );

      final items = [
        makeItem(
          id: 'pipe-1',
          title: 'Italian Veggie',
          price: 25.0,
          tags: ['italian', 'healthy'],
          dietary: 'vegetarian',
        ),
        makeItem(
          id: 'pipe-2',
          title: 'Burger Joint',
          price: 15.0,
          tags: ['meat', 'fast-food'],
          dietary: 'carnivore',
        ),
        makeItem(
          id: 'pipe-3',
          title: 'Salad Bar',
          price: 18.0,
          tags: ['healthy', 'salad'],
          dietary: 'vegetarian',
        ),
        makeItem(
          id: 'pipe-4',
          title: 'Expensive Veggie',
          price: 200.0,
          tags: ['italian', 'fine-dining'],
          dietary: 'vegetarian',
        ),
        makeItem(
          id: 'pipe-5',
          title: 'Thai Veggie Bowl',
          price: 20.0,
          tags: ['thai', 'vegetarian'],
          dietary: 'vegetarian',
        ),
      ];

      // 2. Cache items.
      cache.cacheItems(items);
      final cached = cache.getCached(null);
      expect(cached, isNotNull);
      expect(cached!, hasLength(5));

      // 3. Rank.
      final ranked = ranker.rank(cached, profile);

      // Burger joint filtered out.
      final rankedIds = ranked.map((i) => i.id).toSet();
      expect(rankedIds, isNot(contains('pipe-2')));
      expect(ranked, hasLength(4));

      // Italian Veggie should rank highest (best tags + in budget).
      expect(ranked.first.id, 'pipe-1');

      // 4. User saves top item.
      profile = TasteSignal.applySignal(
        profile,
        ranked.first,
        TasteSignal.actionSaved,
      );
      expect(profile.savedItemIds, contains('pipe-1'));

      // 5. User dismisses last item.
      final lastItem = ranked.last;
      profile = TasteSignal.applySignal(
        profile,
        lastItem,
        TasteSignal.actionDismissed,
      );
      expect(profile.dismissedItemIds, contains(lastItem.id));

      // 6. Re-rank.
      final reRanked = ranker.rank(cached, profile);
      final reRankedIds = reRanked.map((i) => i.id).toSet();

      // Dismissed item gone.
      expect(reRankedIds, isNot(contains(lastItem.id)));
      // Fewer items than before.
      expect(reRanked.length, lessThan(ranked.length));

      // 7. Capture an error and collect feedback.
      final error = errorCapture.capture(
        errorType: 'network_error',
        errorMessage: 'Failed to refresh feed',
        context: {'screen': 'explore'},
      );

      final prompt = feedbackCollector.buildHelloFeedbackPrompt(error);
      expect(prompt, contains('network_error'));

      final feedback = feedbackCollector.submitFeedback(
        message: 'Feed did not load',
        context: {'retried': true},
      );
      expect(feedback.errorType, 'user_feedback');

      // 8. Verify error capture state.
      expect(errorCapture.pendingReports, hasLength(2));
      expect(errorCapture.unsyncedReports, hasLength(2));

      errorCapture.markSynced(error.id);
      expect(errorCapture.unsyncedReports, hasLength(1));
    });
  });
}
