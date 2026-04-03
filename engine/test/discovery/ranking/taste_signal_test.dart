// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';
import 'package:e2ee_chat_sdk/src/discovery/ranking/taste_signal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a test [DiscoveryItem] with sensible defaults.
DiscoveryItem _item({
  String id = 'item-1',
  String title = 'Test Item',
  DiscoveryCategory category = DiscoveryCategory.restaurants,
  Map<String, dynamic> metadata = const {},
}) {
  return DiscoveryItem(
    id: id,
    title: title,
    category: category,
    metadata: metadata,
    source: 'test',
    fetchedAt: DateTime.utc(2026, 4, 1),
  );
}

void main() {
  group('TasteSignal — weight application', () {
    test('addedToBoard increases category weight by addedToBoard constant',
        () {
      final profile = TasteProfile.empty;
      final item = _item(category: DiscoveryCategory.restaurants);

      final updated = TasteSignal.applySignal(
        profile,
        item,
        TasteSignal.actionAddedToBoard,
      );

      // Category weight starts at 0.5 (default) and increases by
      // addedToBoard * 0.1 = 3.0 * 0.1 = 0.3.
      final weight = updated.implicitWeights['restaurants']!;
      expect(weight, closeTo(0.5 + TasteSignal.addedToBoard * 0.1, 0.01));
    });

    test('saved increases category weight by saved constant', () {
      final profile = TasteProfile.empty;
      final item = _item(category: DiscoveryCategory.restaurants);

      final updated = TasteSignal.applySignal(
        profile,
        item,
        TasteSignal.actionSaved,
      );

      final weight = updated.implicitWeights['restaurants']!;
      expect(weight, closeTo(0.5 + TasteSignal.saved * 0.1, 0.01));
    });

    test('viewed increases category weight by viewed constant', () {
      final profile = TasteProfile.empty;
      final item = _item(category: DiscoveryCategory.restaurants);

      final updated = TasteSignal.applySignal(
        profile,
        item,
        TasteSignal.actionViewed,
      );

      final weight = updated.implicitWeights['restaurants']!;
      expect(weight, closeTo(0.5 + TasteSignal.viewed * 0.1, 0.01));
    });

    test('dismissed decreases category weight and adds to dismissedItemIds',
        () {
      final profile = TasteProfile.empty;
      final item = _item(id: 'bad-item');

      final updated = TasteSignal.applySignal(
        profile,
        item,
        TasteSignal.actionDismissed,
      );

      // Weight decreases by dismissed * 0.1 = -2.0 * 0.1 = -0.2.
      // Starting from 0.5 default = 0.3, but clamped to 0.0-1.0.
      final weight = updated.implicitWeights['restaurants']!;
      expect(weight, closeTo(0.5 + TasteSignal.dismissed * 0.1, 0.01));
      expect(weight, greaterThanOrEqualTo(0.0));

      expect(updated.dismissedItemIds, contains('bad-item'));
    });

    test('saved adds to savedItemIds', () {
      final profile = TasteProfile.empty;
      final item = _item(id: 'saved-item');

      final updated = TasteSignal.applySignal(
        profile,
        item,
        TasteSignal.actionSaved,
      );

      expect(updated.savedItemIds, contains('saved-item'));
    });
  });

  group('TasteSignal — accumulation', () {
    test('signals accumulate: 2x saved on restaurants gives +2x weight', () {
      var profile = TasteProfile.empty;
      final item1 = _item(id: 'r1', title: 'Restaurant A');
      final item2 = _item(id: 'r2', title: 'Restaurant B');

      profile = TasteSignal.applySignal(
        profile,
        item1,
        TasteSignal.actionSaved,
      );
      profile = TasteSignal.applySignal(
        profile,
        item2,
        TasteSignal.actionSaved,
      );

      final weight = profile.implicitWeights['restaurants']!;

      // First apply: 0.5 + 0.2 = 0.7. Second apply: 0.7 + 0.2 = 0.9.
      expect(weight, closeTo(0.5 + 2 * TasteSignal.saved * 0.1, 0.01));
    });
  });

  group('TasteSignal — tag weights', () {
    test('tag weights updated from item tags', () {
      final profile = TasteProfile.empty;
      final item = _item(
        metadata: {
          'tags': ['seafood', 'outdoor'],
        },
      );

      final updated = TasteSignal.applySignal(
        profile,
        item,
        TasteSignal.actionSaved,
      );

      expect(updated.tagWeights['seafood'], closeTo(TasteSignal.saved, 0.01));
      expect(updated.tagWeights['outdoor'], closeTo(TasteSignal.saved, 0.01));
    });
  });
}
