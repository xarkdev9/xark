/// In-memory discovery cache with TTL expiration.
///
/// Provides fast access to recently fetched discovery items
/// without network calls. Actual SQLCipher persistence is handled
/// by engine internals. Pure Dart — no Flutter imports.

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';

/// Internal cache entry with expiration timestamp.
class _CacheEntry {
  _CacheEntry({
    required this.items,
    required this.expiresAt,
  });

  final List<DiscoveryItem> items;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// In-memory cache for discovery items with TTL-based expiration.
///
/// Cache keys are formatted as `"{category}_{location}"` where
/// category defaults to "all" and location defaults to "any".
class DiscoveryCache {
  /// Creates a [DiscoveryCache] with the given default TTL.
  DiscoveryCache({
    this.defaultTtl = const Duration(hours: 6),
  });

  /// Default time-to-live for cached entries.
  final Duration defaultTtl;

  final Map<String, _CacheEntry> _cache = {};
  final Set<String> _dismissedIds = {};
  final Set<String> _savedIds = {};

  /// Returns cached items for the given [category] and [location],
  /// or `null` if no valid cache entry exists.
  List<DiscoveryItem>? getCached(
    DiscoveryCategory? category, {
    String? location,
  }) {
    final key = _buildKey(category, location);
    final entry = _cache[key];

    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return List<DiscoveryItem>.unmodifiable(entry.items);
  }

  /// Caches [items] under their category/location key.
  ///
  /// If [ttl] is not provided, [defaultTtl] is used.
  void cacheItems(List<DiscoveryItem> items, {Duration? ttl}) {
    final effectiveTtl = ttl ?? defaultTtl;
    final expiresAt = DateTime.now().add(effectiveTtl);

    // Group items by category + location.
    final groups = <String, List<DiscoveryItem>>{};
    for (final item in items) {
      final key = _buildKey(item.category, item.location);
      groups.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in groups.entries) {
      _cache[entry.key] = _CacheEntry(
        items: List<DiscoveryItem>.unmodifiable(entry.value),
        expiresAt: expiresAt,
      );
    }

    // Also cache under the "all" key for unfiltered queries.
    final allKey = _buildKey(null, null);
    final existing = _cache[allKey]?.items.toList() ?? [];
    final merged = <String, DiscoveryItem>{};
    for (final item in existing) {
      merged[item.id] = item;
    }
    for (final item in items) {
      merged[item.id] = item;
    }
    _cache[allKey] = _CacheEntry(
      items: List<DiscoveryItem>.unmodifiable(merged.values.toList()),
      expiresAt: expiresAt,
    );
  }

  /// Invalidates cache entries matching the given [category] and [location].
  ///
  /// If both are `null`, the entire cache is cleared.
  void invalidate({DiscoveryCategory? category, String? location}) {
    if (category == null && location == null) {
      _cache.clear();
      return;
    }

    final key = _buildKey(category, location);
    _cache.remove(key);
  }

  /// Removes all expired cache entries.
  void pruneExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// IDs of items the user has dismissed.
  List<String> get dismissedIds => List<String>.unmodifiable(
        _dismissedIds.toList(),
      );

  /// IDs of items the user has saved.
  List<String> get savedIds => List<String>.unmodifiable(
        _savedIds.toList(),
      );

  /// Adds [itemId] to the dismissed set.
  void addDismissed(String itemId) {
    _dismissedIds.add(itemId);
  }

  /// Adds [itemId] to the saved set.
  void addSaved(String itemId) {
    _savedIds.add(itemId);
  }

  /// Returns the total number of cached entries.
  int get entryCount => _cache.length;

  /// Returns the total number of cached items across all entries.
  int get itemCount =>
      _cache.values.fold(0, (sum, entry) => sum + entry.items.length);

  String _buildKey(DiscoveryCategory? category, String? location) {
    final cat = category?.name ?? 'all';
    final loc = location ?? 'any';
    return '${cat}_$loc';
  }
}
