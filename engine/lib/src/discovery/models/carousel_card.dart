/// Carousel card model for the discovery feed.
///
/// Groups related [DiscoveryItem]s into a swipeable card with
/// curation metadata. Pure Dart — no Flutter imports.

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';

/// A carousel card grouping related discovery items.
class CarouselCard {
  /// Creates a [CarouselCard].
  const CarouselCard({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.heroColor,
    required this.category,
    required this.items,
    required this.curationType,
  });

  /// Unique identifier for this card.
  final String id;

  /// Display title (e.g. "Top Pasta in Rome").
  final String title;

  /// Optional subtitle (e.g. "Based on your group's taste").
  final String? subtitle;

  /// Optional hero image URL for the card header.
  final String? imageUrl;

  /// Hex color string for the card background (e.g. "#FF6B35").
  final String heroColor;

  /// Category of items in this card.
  final DiscoveryCategory category;

  /// The items displayed in this carousel.
  final List<DiscoveryItem> items;

  /// How this card was curated.
  ///
  /// One of: "trending", "seasonal", "taste_match", "editorial".
  final String curationType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CarouselCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CarouselCard('
        'id: $id, '
        'title: $title, '
        'category: ${category.name}, '
        'curationType: $curationType, '
        'items: ${items.length})';
  }
}
