// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/cache/discovery_cache.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a list of test [DiscoveryItem]s for the given category and location.
List<DiscoveryItem> _items(
  int count, {
  String prefix = 'item',
  DiscoveryCategory category = DiscoveryCategory.restaurants,
  String? location,
}) {
  return List.generate(
    count,
    (i) => DiscoveryItem(
      id: '$prefix-$i',
      title: 'Test Item $i',
      category: category,
      location: location,
      source: 'test',
      fetchedAt: DateTime.utc(2026, 4, 1),
    ),
  );
}

void main() {
  late DiscoveryCache cache;

  setUp(() {
    cache = DiscoveryCache(defaultTtl: Duration(minutes: 30));
  });

  group('DiscoveryCache — basic operations', () {
    test('cacheItems stores and getCached retrieves', () {
      final items = _items(5);

      cache.cacheItems(items);
      final cached = cache.getCached(DiscoveryCategory.restaurants);

      expect(cached, isNotNull);
      expect(cached, hasLength(5));
      expect(cached!.first.id, 'item-0');
    });

    test('getCached returns null for uncached category', () {
      final cached = cache.getCached(DiscoveryCategory.hotels);
      expect(cached, isNull);
    });
  });

  group('DiscoveryCache — TTL expiration', () {
    test('items expire after duration', () async {
      // Use a very short TTL for testing.
      cache = DiscoveryCache(defaultTtl: Duration(milliseconds: 50));
      final items = _items(3);

      cache.cacheItems(items);

      // Immediately after caching, items should be available.
      expect(cache.getCached(DiscoveryCategory.restaurants), isNotNull);

      // Wait for TTL to expire.
      await Future<void>.delayed(Duration(milliseconds: 100));

      // After TTL, getCached should return null.
      expect(cache.getCached(DiscoveryCategory.restaurants), isNull);
    });

    test('pruneExpired removes stale entries', () async {
      cache = DiscoveryCache(defaultTtl: Duration(milliseconds: 50));

      cache.cacheItems(_items(3));
      cache.cacheItems(
        _items(2, prefix: 'hotel', category: DiscoveryCategory.hotels),
        ttl: Duration(hours: 1), // This one won't expire.
      );

      // Wait for the short-TTL entries to expire.
      await Future<void>.delayed(Duration(milliseconds: 100));

      cache.pruneExpired();

      // Hotels entry should remain (long TTL); restaurants should be gone.
      expect(cache.getCached(DiscoveryCategory.hotels), isNotNull);
      expect(cache.getCached(DiscoveryCategory.restaurants), isNull);
    });
  });

  group('DiscoveryCache — invalidation', () {
    test('invalidate clears specific category/location', () {
      cache.cacheItems(
        _items(3, location: 'Rome'),
      );
      cache.cacheItems(
        _items(2, prefix: 'hotel', category: DiscoveryCategory.hotels,
            location: 'Rome'),
      );

      cache.invalidate(
        category: DiscoveryCategory.restaurants,
        location: 'Rome',
      );

      expect(
        cache.getCached(DiscoveryCategory.restaurants, location: 'Rome'),
        isNull,
      );
      expect(
        cache.getCached(DiscoveryCategory.hotels, location: 'Rome'),
        isNotNull,
      );
    });

    test('invalidate without params clears all', () {
      cache.cacheItems(_items(3));
      cache.cacheItems(
        _items(2, prefix: 'hotel', category: DiscoveryCategory.hotels),
      );

      cache.invalidate();

      expect(cache.entryCount, 0);
      expect(cache.getCached(DiscoveryCategory.restaurants), isNull);
      expect(cache.getCached(DiscoveryCategory.hotels), isNull);
    });
  });

  group('DiscoveryCache — dismissed and saved IDs', () {
    test('dismissed IDs persisted across cache operations', () {
      cache.addDismissed('item-1');
      cache.addDismissed('item-2');

      // Cache and invalidate should not affect dismissed IDs.
      cache.cacheItems(_items(3));
      cache.invalidate();

      expect(cache.dismissedIds, containsAll(['item-1', 'item-2']));
    });

    test('saved IDs persisted across cache operations', () {
      cache.addSaved('item-a');
      cache.addSaved('item-b');

      cache.cacheItems(_items(3));
      cache.invalidate();

      expect(cache.savedIds, containsAll(['item-a', 'item-b']));
    });
  });
}
