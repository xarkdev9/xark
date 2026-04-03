/// Discovery filter model for explore queries.
///
/// Parameterizes discovery feed and search requests.
/// Pure Dart — no Flutter imports.

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';

/// Filter parameters for discovery queries.
class DiscoveryFilter {
  /// Creates a [DiscoveryFilter].
  const DiscoveryFilter({
    this.query,
    this.category,
    this.location,
    this.limit = 20,
    this.offset = 0,
    this.excludeIds,
  });

  /// Free-text search query (e.g. "pasta in Rome").
  final String? query;

  /// Filter by category.
  final DiscoveryCategory? category;

  /// Filter by location string.
  final String? location;

  /// Maximum number of results to return.
  final int limit;

  /// Offset for pagination.
  final int offset;

  /// Item IDs to exclude from results (e.g. already-shown items).
  final List<String>? excludeIds;

  /// Creates a copy with the given fields replaced.
  DiscoveryFilter copyWith({
    String? query,
    DiscoveryCategory? category,
    String? location,
    int? limit,
    int? offset,
    List<String>? excludeIds,
  }) {
    return DiscoveryFilter(
      query: query ?? this.query,
      category: category ?? this.category,
      location: location ?? this.location,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      excludeIds: excludeIds ?? this.excludeIds,
    );
  }

  @override
  String toString() {
    return 'DiscoveryFilter('
        'query: $query, '
        'category: ${category?.name}, '
        'location: $location, '
        'limit: $limit, '
        'offset: $offset)';
  }
}
