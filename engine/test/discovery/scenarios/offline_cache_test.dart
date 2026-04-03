// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/cache/discovery_cache.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a list of test restaurant [DiscoveryItem]s in Rome.
List<DiscoveryItem> _buildRomeItems(int count) {
  return List.generate(
    count,
    (i) => DiscoveryItem(
      id: 'rome-restaurant-$i',
      title: 'Rome Restaurant $i',
      category: DiscoveryCategory.restaurants,
      location: 'Rome',
      price: 20.0 + i * 5,
      currency: 'EUR',
      metadata: {'tags': ['italian']},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 4, 1),
    ),
  );
}

void main() {
  group('Scenario: Cache populated, then accessed offline', () {
    test('full cache lifecycle: populate, access, expire, prune', () async {
      // Use a short TTL (1 second) for testing.
      final cache = DiscoveryCache(
        defaultTtl: Duration(seconds: 1),
      );

      // Step 1: Cache 15 items in "restaurants" category for "Rome".
      final items = _buildRomeItems(15);
      cache.cacheItems(items);

      // Step 2: getCached returns the 15 items.
      final cached = cache.getCached(
        DiscoveryCategory.restaurants,
        location: 'Rome',
      );
      expect(cached, isNotNull);
      expect(cached, hasLength(15));
      expect(cached!.first.id, 'rome-restaurant-0');
      expect(cached.last.id, 'rome-restaurant-14');

      // Step 3: Wait for TTL to expire (1 second + buffer).
      await Future<void>.delayed(Duration(milliseconds: 1200));

      // Step 4: After TTL, getCached returns null (expired).
      final expired = cache.getCached(
        DiscoveryCategory.restaurants,
        location: 'Rome',
      );
      expect(expired, isNull);

      // Step 5: pruneExpired clears the entry.
      cache.pruneExpired();
      expect(cache.entryCount, 0);
    });

    test('custom TTL overrides default', () async {
      final cache = DiscoveryCache(
        defaultTtl: Duration(hours: 1), // Long default.
      );

      // Cache with a short custom TTL.
      final items = _buildRomeItems(5);
      cache.cacheItems(items, ttl: Duration(milliseconds: 100));

      expect(
        cache.getCached(DiscoveryCategory.restaurants, location: 'Rome'),
        isNotNull,
      );

      await Future<void>.delayed(Duration(milliseconds: 200));

      expect(
        cache.getCached(DiscoveryCategory.restaurants, location: 'Rome'),
        isNull,
      );
    });

    test('different locations cached independently', () {
      final cache = DiscoveryCache();

      final romeItems = _buildRomeItems(10);
      final parisItems = List.generate(
        8,
        (i) => DiscoveryItem(
          id: 'paris-restaurant-$i',
          title: 'Paris Restaurant $i',
          category: DiscoveryCategory.restaurants,
          location: 'Paris',
          source: 'test',
          fetchedAt: DateTime.utc(2026, 4, 1),
        ),
      );

      cache.cacheItems(romeItems);
      cache.cacheItems(parisItems);

      final rome = cache.getCached(
        DiscoveryCategory.restaurants,
        location: 'Rome',
      );
      final paris = cache.getCached(
        DiscoveryCategory.restaurants,
        location: 'Paris',
      );

      expect(rome, hasLength(10));
      expect(paris, hasLength(8));

      // Invalidating Rome does not affect Paris.
      cache.invalidate(
        category: DiscoveryCategory.restaurants,
        location: 'Rome',
      );

      expect(
        cache.getCached(DiscoveryCategory.restaurants, location: 'Rome'),
        isNull,
      );
      expect(
        cache.getCached(DiscoveryCategory.restaurants, location: 'Paris'),
        isNotNull,
      );
    });
  });
}
