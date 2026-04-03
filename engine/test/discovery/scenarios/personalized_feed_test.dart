// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';
import 'package:e2ee_chat_sdk/src/discovery/ranking/taste_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a test [DiscoveryItem].
DiscoveryItem _item({
  required String id,
  required String title,
  DiscoveryCategory category = DiscoveryCategory.restaurants,
  double? price,
  String currency = 'USD',
  List<String> tags = const [],
  String? dietary,
}) {
  return DiscoveryItem(
    id: id,
    title: title,
    category: category,
    price: price,
    currency: currency,
    metadata: {
      'tags': tags,
      if (dietary != null) 'dietary': [dietary],
    },
    source: 'test',
    fetchedAt: DateTime.utc(2026, 4, 1),
  );
}

/// Creates a diverse set of 20 items for the personalized feed scenario.
List<DiscoveryItem> _buildDiverseItems() {
  return [
    // Italian restaurants (vegetarian-friendly).
    _item(
      id: 'it-1',
      title: 'Trattoria Bella',
      price: 25.0,
      tags: ['italian', 'pasta'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'it-2',
      title: 'Pasta Fresca',
      price: 30.0,
      tags: ['italian', 'handmade'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'it-3',
      title: 'Pizzeria Napoli',
      price: 18.0,
      tags: ['italian', 'pizza'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'it-4',
      title: 'Risotto House',
      price: 35.0,
      tags: ['italian', 'risotto'],
      dietary: 'vegetarian',
    ),

    // Meat restaurants (should be filtered out for vegetarian).
    _item(
      id: 'meat-1',
      title: 'BBQ Pit',
      price: 40.0,
      tags: ['meat', 'bbq', 'american'],
      dietary: 'carnivore',
    ),
    _item(
      id: 'meat-2',
      title: 'Steak Palace',
      price: 80.0,
      tags: ['meat', 'steak'],
      dietary: 'carnivore',
    ),
    _item(
      id: 'meat-3',
      title: 'Burger Joint',
      price: 15.0,
      tags: ['meat', 'burgers'],
      dietary: 'carnivore',
    ),

    // Other vegetarian restaurants (non-Italian).
    _item(
      id: 'veg-1',
      title: 'Green Bowl',
      price: 20.0,
      tags: ['salad', 'healthy'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'veg-2',
      title: 'Thai Garden',
      price: 22.0,
      tags: ['thai', 'curry'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'veg-3',
      title: 'Sushi Zen',
      price: 45.0,
      tags: ['japanese', 'sushi'],
      dietary: 'vegetarian',
    ),

    // Expensive restaurants (outside $10-$50 budget).
    _item(
      id: 'exp-1',
      title: 'Michelin Star',
      price: 150.0,
      tags: ['french', 'fine-dining'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'exp-2',
      title: 'Omakase Suite',
      price: 200.0,
      tags: ['japanese', 'premium'],
      dietary: 'vegetarian',
    ),

    // Activities.
    _item(
      id: 'act-1',
      title: 'Cooking Class',
      category: DiscoveryCategory.activities,
      price: 40.0,
      tags: ['italian', 'cooking'],
    ),
    _item(
      id: 'act-2',
      title: 'Wine Tasting',
      category: DiscoveryCategory.activities,
      price: 55.0,
      tags: ['wine', 'tasting'],
    ),

    // Hotels.
    _item(
      id: 'hotel-1',
      title: 'Boutique Hotel Rome',
      category: DiscoveryCategory.hotels,
      price: 120.0,
      tags: ['boutique', 'central'],
    ),
    _item(
      id: 'hotel-2',
      title: 'Budget Hostel',
      category: DiscoveryCategory.hotels,
      price: 30.0,
      tags: ['budget', 'social'],
    ),

    // Cheap vegetarian.
    _item(
      id: 'cheap-1',
      title: 'Street Food Stand',
      price: 8.0,
      tags: ['street-food', 'quick'],
      dietary: 'vegetarian',
    ),
    _item(
      id: 'cheap-2',
      title: 'Falafel King',
      price: 12.0,
      tags: ['middle-eastern', 'falafel'],
      dietary: 'vegetarian',
    ),

    // Italian with meat (should be filtered).
    _item(
      id: 'it-meat-1',
      title: 'Osso Buco House',
      price: 35.0,
      tags: ['italian', 'meat'],
      dietary: 'carnivore',
    ),
    _item(
      id: 'it-meat-2',
      title: 'Bolognese Bar',
      price: 28.0,
      tags: ['italian', 'meat'],
      dietary: 'carnivore',
    ),
  ];
}

void main() {
  group('Scenario: Vegetarian user who loves Italian food, \$\$ budget', () {
    late TasteRanker ranker;
    late TasteProfile profile;
    late List<DiscoveryItem> items;

    setUp(() {
      ranker = TasteRanker();
      profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
        },
        implicitWeights: {
          'restaurants': 0.8,
          'italian': 0.9,
        },
        tagWeights: {
          'italian': 5.0,
          'pasta': 3.0,
          'pizza': 2.0,
        },
        priceMin: 10.0,
        priceMax: 50.0,
      );
      items = _buildDiverseItems();
    });

    test('no meat items in results', () {
      final ranked = ranker.rank(items, profile);
      final rankedIds = ranked.map((i) => i.id).toSet();

      // All meat items should be filtered out.
      expect(rankedIds, isNot(contains('meat-1')));
      expect(rankedIds, isNot(contains('meat-2')));
      expect(rankedIds, isNot(contains('meat-3')));
      expect(rankedIds, isNot(contains('it-meat-1')));
      expect(rankedIds, isNot(contains('it-meat-2')));
    });

    test('Italian items ranked near top', () {
      final ranked = ranker.rank(items, profile);

      // The top 5 should contain Italian vegetarian items.
      final topFiveIds = ranked.take(5).map((i) => i.id).toSet();
      final italianIds = {'it-1', 'it-2', 'it-3', 'it-4'};

      // At least 2 of the top 5 should be Italian.
      final italianInTop = topFiveIds.intersection(italianIds);
      expect(
        italianInTop.length,
        greaterThanOrEqualTo(2),
        reason: 'Expected at least 2 Italian items in top 5, '
            'got: $italianInTop from top 5: $topFiveIds',
      );
    });

    test('items within \$10-50 ranked higher than \$100+ items', () {
      final ranked = ranker.rank(items, profile);

      // Find an in-budget vegetarian restaurant and an expensive one.
      final inBudget = ranked.where(
        (i) => i.price != null && i.price! >= 10 && i.price! <= 50,
      );
      final expensive = ranked.where(
        (i) => i.price != null && i.price! >= 100,
      );

      if (inBudget.isNotEmpty && expensive.isNotEmpty) {
        // The best in-budget item should score higher than the best expensive.
        expect(
          inBudget.first.tasteScore,
          greaterThan(expensive.first.tasteScore),
          reason: 'In-budget items should score higher than expensive ones',
        );
      }
    });

    test('dismiss 3 Italian items then re-rank: non-Italian items rise', () {
      // Initial rank.
      final initialRanked = ranker.rank(items, profile);

      // Find the position of the first non-Italian vegetarian restaurant.
      int initialNonItalianRank(List<DiscoveryItem> ranked) {
        for (var i = 0; i < ranked.length; i++) {
          if (ranked[i].id.startsWith('veg-')) return i;
        }
        return ranked.length;
      }

      final initialPos = initialNonItalianRank(initialRanked);

      // Dismiss 3 Italian items.
      final updatedProfile = profile.copyWith(
        dismissedItemIds: ['it-1', 'it-2', 'it-3'],
      );

      final reRanked = ranker.rank(items, updatedProfile);
      final reRankedPos = initialNonItalianRank(reRanked);

      // Non-Italian items should move up (lower index = higher rank).
      expect(
        reRankedPos,
        lessThanOrEqualTo(initialPos),
        reason: 'Non-Italian items should rise after Italian dismissals. '
            'Initial position: $initialPos, new position: $reRankedPos',
      );

      // Dismissed items should not appear at all.
      final reRankedIds = reRanked.map((i) => i.id).toSet();
      expect(reRankedIds, isNot(contains('it-1')));
      expect(reRankedIds, isNot(contains('it-2')));
      expect(reRankedIds, isNot(contains('it-3')));
    });
  });
}
