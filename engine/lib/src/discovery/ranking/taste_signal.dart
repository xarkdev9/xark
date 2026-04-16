/// Taste signal processing for implicit preference learning.
///
/// Applies user interaction signals (save, dismiss, view, etc.)
/// to update a [TasteProfile]. Pure Dart — no I/O.

import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';

/// Processes user interaction signals to update taste profiles.
///
/// Each action type has a fixed weight that is applied to the
/// item's category and tag weights in the profile.
class TasteSignal {
  TasteSignal._();

  /// Weight for adding an item to a decision board.
  static const double addedToBoard = 3.0;

  /// Weight for saving an item.
  static const double saved = 2.0;

  /// Weight for viewing an item detail.
  static const double viewed = 0.5;

  /// Weight for dismissing an item.
  static const double dismissed = -2.0;

  /// Signal action constants.
  static const String actionAddedToBoard = 'added_to_board';
  static const String actionSaved = 'saved';
  static const String actionViewed = 'viewed';
  static const String actionDismissed = 'dismissed';

  /// Applies a user interaction signal to update the [profile].
  ///
  /// Updates the category weight and tag weights based on the
  /// [action] type and the [item]'s metadata.
  ///
  /// For "dismissed", the item is also added to [TasteProfile.dismissedItemIds].
  /// For "saved", the item is added to [TasteProfile.savedItemIds].
  static TasteProfile applySignal(
    TasteProfile profile,
    DiscoveryItem item,
    String action,
  ) {
    final weight = _weightForAction(action);
    if (weight == 0.0) return profile;

    // Update category weight.
    final categoryName = item.category.name;
    final updatedImplicitWeights =
        Map<String, double>.from(profile.implicitWeights);
    final currentCategoryWeight =
        updatedImplicitWeights[categoryName] ?? 0.5;
    updatedImplicitWeights[categoryName] =
        (currentCategoryWeight + weight * 0.1).clamp(0.0, 1.0);

    // Update tag weights.
    final updatedTagWeights = Map<String, double>.from(profile.tagWeights);
    final itemTags = _extractTags(item);
    for (final tag in itemTags) {
      final currentWeight = updatedTagWeights[tag] ?? 0.0;
      updatedTagWeights[tag] = currentWeight + weight;
    }

    // Update dismissed/saved lists.
    var updatedDismissedIds = profile.dismissedItemIds;
    var updatedSavedIds = profile.savedItemIds;

    if (action == actionDismissed) {
      if (!updatedDismissedIds.contains(item.id)) {
        updatedDismissedIds = [...updatedDismissedIds, item.id];
      }
    }

    if (action == actionSaved) {
      if (!updatedSavedIds.contains(item.id)) {
        updatedSavedIds = [...updatedSavedIds, item.id];
      }
    }

    return profile.copyWith(
      implicitWeights: updatedImplicitWeights,
      tagWeights: updatedTagWeights,
      dismissedItemIds: updatedDismissedIds,
      savedItemIds: updatedSavedIds,
    );
  }

  static double _weightForAction(String action) {
    switch (action) {
      case actionAddedToBoard:
        return addedToBoard;
      case actionSaved:
        return saved;
      case actionViewed:
        return viewed;
      case actionDismissed:
        return dismissed;
      default:
        return 0.0;
    }
  }

  static List<String> _extractTags(DiscoveryItem item) {
    final raw = item.metadata['tags'];
    if (raw is List) {
      return raw.cast<String>();
    }
    return const [];
  }
}
