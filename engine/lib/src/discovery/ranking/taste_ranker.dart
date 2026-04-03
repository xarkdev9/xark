/// Core taste-matching ranking algorithm.
///
/// Pure Dart, no I/O. Scores and sorts [DiscoveryItem]s against
/// a [TasteProfile] using weighted multi-signal scoring.

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';

/// Ranks discovery items against a user's taste profile.
///
/// The ranking algorithm uses five weighted signals:
/// - Category affinity (0.35): how much the user likes this category
/// - Price affinity (0.25): whether the price fits the budget
/// - Tag affinity (0.25): overlap with preferred tags
/// - Diversity boost (0.10): penalizes over-represented categories
/// - Recency decay (0.05): slight penalty for already-saved items
class TasteRanker {
  /// Ranks [items] against [profile], returning a new list sorted by
  /// taste score descending.
  ///
  /// Items violating hard constraints are filtered out.
  /// Each returned item has [DiscoveryItem.tasteScore] and
  /// [DiscoveryItem.tasteReason] set.
  List<DiscoveryItem> rank(
    List<DiscoveryItem> items,
    TasteProfile profile,
  ) {
    // Step 1: Filter out hard-constraint violations and dismissed items.
    final filtered = items.where((item) {
      if (profile.dismissedItemIds.contains(item.id)) return false;
      return !_violatesHardConstraints(item, profile);
    }).toList();

    // Step 2: Score each item.
    final categoryCounts = <String, int>{};
    final scored = <DiscoveryItem>[];

    for (final item in filtered) {
      final categoryName = item.category.name;
      categoryCounts[categoryName] =
          (categoryCounts[categoryName] ?? 0) + 1;

      final categoryScore = _categoryAffinity(item, profile);
      final priceScore = _priceAffinity(item, profile);
      final tagScore = _tagAffinity(item, profile);
      final diversityScore =
          _diversityBoost(categoryName, categoryCounts);
      final recencyScore = _recencyDecay(item, profile);

      final totalScore = (categoryScore * 0.35) +
          (priceScore * 0.25) +
          (tagScore * 0.25) +
          (diversityScore * 0.10) +
          (recencyScore * 0.05);

      final clampedScore = totalScore.clamp(0.0, 1.0);
      final reason = explainMatch(item, profile);

      scored.add(item.copyWith(
        tasteScore: clampedScore,
        tasteReason: reason,
      ));
    }

    // Step 3: Sort by taste score descending.
    scored.sort((a, b) => b.tasteScore.compareTo(a.tasteScore));

    return scored;
  }

  /// Builds a human-readable explanation of why [item] matches [profile].
  ///
  /// Returns `null` if the computed score would be below 0.3.
  String? explainMatch(DiscoveryItem item, TasteProfile profile) {
    final categoryScore = _categoryAffinity(item, profile);
    final priceScore = _priceAffinity(item, profile);
    final tagScore = _tagAffinity(item, profile);

    final estimatedScore = (categoryScore * 0.35) +
        (priceScore * 0.25) +
        (tagScore * 0.25) +
        0.10 + // diversity default
        0.05; // recency default

    if (estimatedScore < 0.3) return null;

    // Find the top matching tag.
    final itemTags = _extractTags(item);
    String? topTag;
    var topTagWeight = 0.0;

    for (final tag in itemTags) {
      final weight = profile.tagWeights[tag] ?? 0.0;
      if (weight > topTagWeight) {
        topTagWeight = weight;
        topTag = tag;
      }
    }

    // Build explanation based on strongest signal.
    if (topTag != null && topTagWeight > 1.0) {
      return 'Matches your love of $topTag';
    }

    if (priceScore >= 0.9 && item.price != null) {
      final symbol = _currencySymbol(item.currency);
      return 'Within your $symbol budget';
    }

    if (categoryScore >= 0.7) {
      return 'Popular in ${item.category.name} you like';
    }

    if (estimatedScore >= 0.5) {
      return 'Good match for your taste';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Scoring signals
  // ---------------------------------------------------------------------------

  double _categoryAffinity(DiscoveryItem item, TasteProfile profile) {
    return profile.implicitWeights[item.category.name] ?? 0.5;
  }

  double _priceAffinity(DiscoveryItem item, TasteProfile profile) {
    if (item.price == null) return 0.7;

    final price = item.price!;
    final hasMin = profile.priceMin != null;
    final hasMax = profile.priceMax != null;

    if (!hasMin && !hasMax) return 0.7;

    final min = profile.priceMin ?? 0.0;
    final max = profile.priceMax ?? double.infinity;

    if (price >= min && price <= max) return 1.0;

    // Within 2x range.
    final expandedMin = hasMin ? min / 2.0 : 0.0;
    final expandedMax = hasMax ? max * 2.0 : double.infinity;

    if (price >= expandedMin && price <= expandedMax) return 0.5;

    return 0.1;
  }

  double _tagAffinity(DiscoveryItem item, TasteProfile profile) {
    final itemTags = _extractTags(item);
    if (itemTags.isEmpty || profile.tagWeights.isEmpty) return 0.5;

    var matchedWeight = 0.0;
    var maxPossible = 0.0;

    for (final entry in profile.tagWeights.entries) {
      maxPossible += entry.value.abs();
      if (itemTags.contains(entry.key)) {
        matchedWeight += entry.value;
      }
    }

    if (maxPossible == 0.0) return 0.5;

    return (matchedWeight / maxPossible).clamp(0.0, 1.0);
  }

  double _diversityBoost(
    String categoryName,
    Map<String, int> categoryCounts,
  ) {
    final count = categoryCounts[categoryName] ?? 0;
    if (count > 3) return 0.8;
    if (count < 2) return 1.0; // 1.2 clamped effect via weight
    return 1.0;
  }

  double _recencyDecay(DiscoveryItem item, TasteProfile profile) {
    if (profile.savedItemIds.contains(item.id)) return 0.9;
    return 1.0;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _violatesHardConstraints(
    DiscoveryItem item,
    TasteProfile profile,
  ) {
    for (final entry in profile.hardConstraints.entries) {
      final constraintKey = entry.key;
      final requiredValues = entry.value;

      // Check item metadata for the constraint key.
      final itemValues = item.metadata[constraintKey];
      if (itemValues == null) continue;

      final itemValueList = itemValues is List
          ? itemValues.cast<String>()
          : <String>[itemValues.toString()];

      // Check item tags for allergens / dietary violations.
      final itemTags = _extractTags(item);

      // For "allergies": if any allergen appears in item tags, reject.
      if (constraintKey == 'allergies') {
        for (final allergen in requiredValues) {
          if (itemTags.contains(allergen) ||
              itemValueList.contains(allergen)) {
            return true;
          }
        }
      }

      // For "dietary": if item declares a conflicting dietary type, reject.
      if (constraintKey == 'dietary') {
        for (final requirement in requiredValues) {
          if (itemValueList.isNotEmpty &&
              !itemValueList.contains(requirement)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  List<String> _extractTags(DiscoveryItem item) {
    final raw = item.metadata['tags'];
    if (raw is List) {
      return raw.cast<String>();
    }
    return const [];
  }

  String _currencySymbol(String? currency) {
    switch (currency?.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'JPY':
        return '\u00A5';
      default:
        return currency ?? r'$';
    }
  }
}
