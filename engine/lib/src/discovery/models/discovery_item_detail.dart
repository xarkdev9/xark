/// Extended detail model for a discovery item.
///
/// Uses composition (not inheritance) to wrap a [DiscoveryItem]
/// with additional detail fields. Pure Dart — no Flutter imports.

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';

/// Full detail view of a discovery item.
///
/// Wraps a [DiscoveryItem] with extended metadata that is only
/// fetched on demand (when the user taps into an item).
class DiscoveryItemDetail {
  /// Creates a [DiscoveryItemDetail].
  const DiscoveryItemDetail({
    required this.item,
    this.longDescription,
    this.imageUrls = const [],
    this.hours,
    this.website,
    this.phone,
    this.rating,
    this.reviewCount,
    this.tags = const [],
    this.aiSummary,
  });

  /// The base discovery item.
  final DiscoveryItem item;

  /// Extended description (may contain markdown).
  final String? longDescription;

  /// All image URLs for this item (gallery view).
  final List<String> imageUrls;

  /// Operating hours keyed by day (e.g. {"monday": "9:00-17:00"}).
  final Map<String, String>? hours;

  /// Website URL.
  final String? website;

  /// Phone number.
  final String? phone;

  /// Average rating (0.0 - 5.0).
  final double? rating;

  /// Total number of reviews.
  final int? reviewCount;

  /// Descriptive tags (e.g. ["outdoor", "family-friendly"]).
  final List<String> tags;

  /// AI-generated summary from @hello.
  final String? aiSummary;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveryItemDetail && other.item.id == item.id;
  }

  @override
  int get hashCode => item.id.hashCode;

  @override
  String toString() {
    return 'DiscoveryItemDetail('
        'item: ${item.id}, '
        'rating: $rating, '
        'reviewCount: $reviewCount, '
        'tags: $tags)';
  }
}
