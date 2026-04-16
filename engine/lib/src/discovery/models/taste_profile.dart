/// Taste profile model for personalized discovery ranking.
///
/// Captures both explicit user preferences (hard constraints) and
/// implicit behavioral signals (weights). Pure Dart — no Flutter imports.

/// A user's taste profile for discovery ranking.
class TasteProfile {
  /// Creates a [TasteProfile].
  const TasteProfile({
    this.hardConstraints = const {},
    this.implicitWeights = const {},
    this.tagWeights = const {},
    this.priceMin,
    this.priceMax,
    this.dismissedItemIds = const [],
    this.savedItemIds = const [],
  });

  /// An empty taste profile with no preferences.
  static const empty = TasteProfile();

  /// Hard constraints that must be satisfied.
  ///
  /// Keys are constraint categories (e.g. "dietary", "allergies").
  /// Values are lists of required values (e.g. ["vegetarian"], ["nuts"]).
  /// Items violating these constraints are filtered out entirely.
  final Map<String, List<String>> hardConstraints;

  /// Implicit category/cuisine weights learned from behavior.
  ///
  /// Keys are category or cuisine names (e.g. "restaurants", "italian").
  /// Values are weights (0.0 - 1.0) where higher = stronger preference.
  final Map<String, double> implicitWeights;

  /// Tag-level weights learned from interactions.
  ///
  /// Keys are tag names (e.g. "seafood", "outdoor", "rooftop").
  /// Values are accumulated signal weights (can exceed 1.0).
  final Map<String, double> tagWeights;

  /// Minimum acceptable price (in user's preferred currency).
  final double? priceMin;

  /// Maximum acceptable price (in user's preferred currency).
  final double? priceMax;

  /// IDs of items the user has dismissed.
  final List<String> dismissedItemIds;

  /// IDs of items the user has saved.
  final List<String> savedItemIds;

  /// Creates a copy with the given fields replaced.
  TasteProfile copyWith({
    Map<String, List<String>>? hardConstraints,
    Map<String, double>? implicitWeights,
    Map<String, double>? tagWeights,
    double? priceMin,
    double? priceMax,
    List<String>? dismissedItemIds,
    List<String>? savedItemIds,
  }) {
    return TasteProfile(
      hardConstraints: hardConstraints ?? this.hardConstraints,
      implicitWeights: implicitWeights ?? this.implicitWeights,
      tagWeights: tagWeights ?? this.tagWeights,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      dismissedItemIds: dismissedItemIds ?? this.dismissedItemIds,
      savedItemIds: savedItemIds ?? this.savedItemIds,
    );
  }

  @override
  String toString() {
    return 'TasteProfile('
        'constraints: ${hardConstraints.length}, '
        'weights: ${implicitWeights.length}, '
        'tags: ${tagWeights.length}, '
        'dismissed: ${dismissedItemIds.length}, '
        'saved: ${savedItemIds.length})';
  }
}
