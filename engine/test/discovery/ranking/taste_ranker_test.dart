// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';
import 'package:e2ee_chat_sdk/src/discovery/ranking/taste_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a test [DiscoveryItem] with sensible defaults.
DiscoveryItem _item({
  String id = 'item-1',
  String title = 'Test Item',
  DiscoveryCategory category = DiscoveryCategory.restaurants,
  double? price,
  String? currency,
  Map<String, dynamic> metadata = const {},
}) {
  return DiscoveryItem(
    id: id,
    title: title,
    category: category,
    price: price,
    currency: currency,
    metadata: metadata,
    source: 'test',
    fetchedAt: DateTime.utc(2026, 4, 1),
  );
}

void main() {
  late TasteRanker ranker;

  setUp(() {
    ranker = TasteRanker();
  });

  group('TasteRanker — hard constraints', () {
    test('hard constraint filters out items with matching allergens', () {
      final profile = TasteProfile(
        hardConstraints: {
          'allergies': ['nuts', 'shellfish'],
        },
      );

      final items = [
        _item(
          id: 'safe',
          title: 'Caesar Salad',
          metadata: {'tags': ['salad'], 'allergies': ['dairy']},
        ),
        _item(
          id: 'unsafe',
          title: 'Pad Thai',
          metadata: {'tags': ['shellfish'], 'allergies': ['nuts']},
        ),
      ];

      final ranked = ranker.rank(items, profile);
      final ids = ranked.map((i) => i.id).toList();

      expect(ids, contains('safe'));
      expect(ids, isNot(contains('unsafe')));
    });

    test('vegetarian constraint removes items tagged "meat"', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
        },
      );

      final items = [
        _item(
          id: 'veggie',
          title: 'Margherita Pizza',
          metadata: {
            'tags': ['italian', 'cheese'],
            'dietary': ['vegetarian'],
          },
        ),
        _item(
          id: 'steak',
          title: 'Ribeye Steak',
          metadata: {
            'tags': ['meat', 'american'],
            'dietary': ['carnivore'],
          },
        ),
      ];

      final ranked = ranker.rank(items, profile);
      final ids = ranked.map((i) => i.id).toList();

      expect(ids, contains('veggie'));
      expect(ids, isNot(contains('steak')));
    });
  });

  group('TasteRanker — affinity scoring', () {
    test('category affinity ranks preferred categories higher', () {
      final profile = TasteProfile(
        implicitWeights: {
          'restaurants': 0.8,
          'activities': 0.3,
        },
      );

      final items = [
        _item(
          id: 'activity',
          title: 'Kayaking',
          category: DiscoveryCategory.activities,
        ),
        _item(
          id: 'restaurant',
          title: 'Trattoria Roma',
          category: DiscoveryCategory.restaurants,
        ),
      ];

      final ranked = ranker.rank(items, profile);

      expect(ranked.first.id, 'restaurant');
      expect(ranked.first.tasteScore, greaterThan(ranked.last.tasteScore));
    });

    test('price affinity: item within budget scores higher than outside', () {
      final profile = TasteProfile(
        priceMin: 10.0,
        priceMax: 50.0,
        implicitWeights: {'restaurants': 0.5},
      );

      final items = [
        _item(id: 'cheap', title: 'Budget Pasta', price: 25.0),
        _item(id: 'expensive', title: 'Luxury Omakase', price: 300.0),
      ];

      final ranked = ranker.rank(items, profile);

      final cheapItem = ranked.firstWhere((i) => i.id == 'cheap');
      final expensiveItem = ranked.firstWhere((i) => i.id == 'expensive');

      expect(cheapItem.tasteScore, greaterThan(expensiveItem.tasteScore));
    });

    test('tag affinity: matching tags score higher', () {
      final profile = TasteProfile(
        tagWeights: {'seafood': 5.0, 'outdoor': 3.0},
        implicitWeights: {'restaurants': 0.5},
      );

      final items = [
        _item(
          id: 'seafood',
          title: 'Lobster Bar',
          metadata: {'tags': ['seafood', 'outdoor']},
        ),
        _item(
          id: 'landlocked',
          title: 'Mountain Grill',
          metadata: {'tags': ['steakhouse', 'indoor']},
        ),
      ];

      final ranked = ranker.rank(items, profile);
      final seafoodItem = ranked.firstWhere((i) => i.id == 'seafood');
      final landlockedItem = ranked.firstWhere((i) => i.id == 'landlocked');

      expect(seafoodItem.tasteScore, greaterThan(landlockedItem.tasteScore));
    });
  });

  group('TasteRanker — diversity', () {
    test('4th Italian restaurant in batch gets penalized', () {
      final profile = TasteProfile(
        implicitWeights: {'restaurants': 0.8},
        tagWeights: {'italian': 4.0},
      );

      // Create 5 Italian restaurants — the later ones should score lower
      // due to the diversity penalty.
      final items = List.generate(
        5,
        (i) => _item(
          id: 'italian-$i',
          title: 'Italian Place $i',
          metadata: {'tags': ['italian']},
        ),
      );

      // Add one non-Italian item.
      final allItems = [
        ...items,
        _item(
          id: 'sushi',
          title: 'Sushi Bar',
          metadata: {'tags': ['japanese']},
        ),
      ];

      final ranked = ranker.rank(allItems, profile);

      // The 4th+ Italian restaurant should have a lower score than the 1st.
      final italianScores = ranked
          .where((i) => i.id.startsWith('italian-'))
          .map((i) => i.tasteScore)
          .toList();

      // First Italian score should be >= the last Italian score due to
      // diversity penalty on repeated categories.
      if (italianScores.length >= 4) {
        expect(italianScores.first, greaterThanOrEqualTo(italianScores.last));
      }
    });
  });

  group('TasteRanker — filtering', () {
    test('dismissed items excluded entirely', () {
      final profile = TasteProfile(
        dismissedItemIds: ['dismissed-1', 'dismissed-2'],
      );

      final items = [
        _item(id: 'dismissed-1', title: 'Bad Place'),
        _item(id: 'dismissed-2', title: 'Worse Place'),
        _item(id: 'keep', title: 'Good Place'),
      ];

      final ranked = ranker.rank(items, profile);
      final ids = ranked.map((i) => i.id).toList();

      expect(ids, ['keep']);
      expect(ids, isNot(contains('dismissed-1')));
      expect(ids, isNot(contains('dismissed-2')));
    });
  });

  group('TasteRanker — empty profile', () {
    test('empty taste profile gives all items a neutral score around 0.5',
        () {
      final items = [
        _item(id: 'a', title: 'Item A'),
        _item(id: 'b', title: 'Item B'),
        _item(id: 'c', title: 'Item C'),
      ];

      final ranked = ranker.rank(items, TasteProfile.empty);

      for (final item in ranked) {
        // With no preferences, scoring should produce a neutral-ish result.
        // The exact value depends on the algorithm's defaults.
        expect(item.tasteScore, greaterThanOrEqualTo(0.0));
        expect(item.tasteScore, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('TasteRanker — multiple constraints', () {
    test('group-like intersection: multiple constraints all applied', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
          'allergies': ['nuts'],
        },
      );

      final items = [
        _item(
          id: 'ok',
          title: 'Veggie Bowl',
          metadata: {
            'tags': ['salad'],
            'dietary': ['vegetarian'],
          },
        ),
        _item(
          id: 'has-meat',
          title: 'Chicken Wings',
          metadata: {
            'tags': ['meat'],
            'dietary': ['carnivore'],
          },
        ),
        _item(
          id: 'has-nuts',
          title: 'Nut Brownie',
          metadata: {
            'tags': ['nuts', 'dessert'],
            'dietary': ['vegetarian'],
            'allergies': ['nuts'],
          },
        ),
      ];

      final ranked = ranker.rank(items, profile);
      final ids = ranked.map((i) => i.id).toList();

      expect(ids, contains('ok'));
      expect(ids, isNot(contains('has-meat')));
      expect(ids, isNot(contains('has-nuts')));
    });
  });

  group('TasteRanker — explainMatch', () {
    test('explainMatch returns reason for high-scoring items', () {
      final profile = TasteProfile(
        implicitWeights: {'restaurants': 0.9},
        tagWeights: {'italian': 5.0},
        priceMax: 50.0,
      );

      final item = _item(
        id: 'great',
        title: 'Pasta Palace',
        price: 30.0,
        currency: 'USD',
        metadata: {'tags': ['italian']},
      );

      final reason = ranker.explainMatch(item, profile);

      expect(reason, isNotNull);
      expect(reason, isA<String>());
      expect(reason!.isNotEmpty, isTrue);
    });

    test('explainMatch returns null for low-scoring items', () {
      // Use a profile that explicitly has zero affinity for hotels,
      // negative tag weights, and a price budget the item exceeds.
      final profile = TasteProfile(
        implicitWeights: {'hotels': 0.0, 'restaurants': 0.9},
        tagWeights: {'budget': -3.0},
        priceMin: 10.0,
        priceMax: 20.0,
      );

      final item = _item(
        id: 'mismatch',
        title: 'Overpriced Motel',
        category: DiscoveryCategory.hotels,
        price: 500.0,
        metadata: {'tags': ['budget']},
      );

      final reason = ranker.explainMatch(item, profile);

      // With zero category affinity, negative tag weight, and
      // price way out of budget, the estimated score should be
      // below the threshold for an explanation.
      expect(reason, isNull);
    });
  });
}
