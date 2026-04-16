/// Discovery item model for the recommendation engine.
///
/// Represents a single discoverable entity (restaurant, hotel, activity, etc.)
/// with taste-matching metadata. Pure Dart — no Flutter imports.

/// Category of a discoverable item.
enum DiscoveryCategory {
  /// Restaurant or dining establishment.
  restaurants,

  /// Hotel or accommodation.
  hotels,

  /// Activity or experience.
  activities,

  /// Travel destination.
  destinations,

  /// Curated day plan.
  dayPlans,

  /// Bookable experience.
  experiences,
}

/// State of the discovery feed.
enum DiscoveryState {
  /// Feed is loading data.
  loading,

  /// Feed is ready with items.
  ready,

  /// An error occurred loading the feed.
  error,

  /// Device is offline — showing cached data.
  offline,
}

/// A single discoverable item with taste-matching score.
class DiscoveryItem {
  /// Creates a [DiscoveryItem].
  const DiscoveryItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.category,
    this.imageUrl,
    this.description,
    this.price,
    this.currency,
    this.location,
    this.metadata = const {},
    this.tasteScore = 0.0,
    this.tasteReason,
    required this.source,
    required this.fetchedAt,
  });

  /// Unique identifier for this item.
  final String id;

  /// Display title.
  final String title;

  /// Optional subtitle (e.g. cuisine type, neighborhood).
  final String? subtitle;

  /// Category of this item.
  final DiscoveryCategory category;

  /// URL for the primary image.
  final String? imageUrl;

  /// Short description of the item.
  final String? description;

  /// Price in the specified currency.
  final double? price;

  /// ISO 4217 currency code (e.g. "USD", "EUR").
  final String? currency;

  /// Human-readable location string.
  final String? location;

  /// Arbitrary metadata (tags, dietary info, etc.).
  final Map<String, dynamic> metadata;

  /// Taste-match score (0.0 - 1.0), assigned by [TasteRanker].
  final double tasteScore;

  /// Human-readable explanation of the taste match.
  final String? tasteReason;

  /// Data source identifier (e.g. "apify", "editorial", "gemini").
  final String source;

  /// When this item was fetched from the source.
  final DateTime fetchedAt;

  /// Creates a copy with the given fields replaced.
  DiscoveryItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    DiscoveryCategory? category,
    String? imageUrl,
    String? description,
    double? price,
    String? currency,
    String? location,
    Map<String, dynamic>? metadata,
    double? tasteScore,
    String? tasteReason,
    String? source,
    DateTime? fetchedAt,
  }) {
    return DiscoveryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
      tasteScore: tasteScore ?? this.tasteScore,
      tasteReason: tasteReason ?? this.tasteReason,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DiscoveryItem('
        'id: $id, '
        'title: $title, '
        'category: ${category.name}, '
        'tasteScore: ${tasteScore.toStringAsFixed(2)}, '
        'source: $source)';
  }
}
