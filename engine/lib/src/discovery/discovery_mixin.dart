/// Optional discovery engine extension for ChatEngine.
///
/// Provides Instagram-style recommendation feed, explore search,
/// and contextual error/feedback reporting.
///
/// This is NOT part of the core E2EE chat SDK.
/// It's an optional extension for apps that need discovery features.
/// Pure Dart — no Flutter imports.

import 'package:e2ee_chat_sdk/src/discovery/models/carousel_card.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item_detail.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/error_report.dart';
import 'package:e2ee_chat_sdk/src/public_api/chat_engine.dart';

/// Optional discovery engine extension for ChatEngine.
/// Provides Instagram-style recommendation feed, explore search,
/// and contextual error/feedback reporting.
///
/// Usage:
///   final engine = await ChatEngine.initialize(config);
///   if (engine is ChatEngineDiscovery) {
///     engine.discoveryFeed.listen((items) => renderFeed(items));
///     final results = await engine.explore(query: 'pasta in Rome');
///   }
mixin ChatEngineDiscovery on ChatEngine {
  /// Stream of ranked discovery items for the feed.
  ///
  /// Items are ranked by the [TasteRanker] against the user's
  /// [TasteProfile]. Emits a new list whenever the feed refreshes
  /// or the taste profile changes.
  Stream<List<DiscoveryItem>> get discoveryFeed;

  /// Stream of carousel cards for the discovery home screen.
  ///
  /// Each card groups related items by curation type
  /// (trending, seasonal, taste_match, editorial).
  Stream<List<CarouselCard>> get carouselItems;

  /// Current state of the discovery feed.
  Stream<DiscoveryState> get discoveryState;

  /// Searches for discovery items matching the given criteria.
  ///
  /// Returns a ranked list of items. Results are cached locally
  /// for offline access.
  Future<List<DiscoveryItem>> explore({
    String? query,
    DiscoveryCategory? category,
    String? location,
    int limit = 20,
    int offset = 0,
  });

  /// Fetches full detail for a discovery item.
  ///
  /// Includes extended description, gallery images, hours,
  /// ratings, and AI summary.
  Future<DiscoveryItemDetail> getItemDetail(String itemId);

  /// Returns contextual suggestions for a group conversation.
  ///
  /// Uses the group's decision history and member taste profiles
  /// to suggest relevant items. Limited to [limit] results.
  Future<List<DiscoveryItem>> getSuggestionsForGroup(
    String groupId, {
    int limit = 3,
  });

  /// Adds a discovery item to a group's decision board.
  ///
  /// Creates a [DecisionItem] from the [DiscoveryItem] and
  /// sends a "added_to_board" taste signal.
  Future<void> addToDecisionBoard(String groupId, DiscoveryItem item);

  /// Dismisses an item from the user's feed.
  ///
  /// Sends a "dismissed" taste signal and adds the item to
  /// the dismissed list so it won't appear again.
  Future<void> dismissItem(String itemId);

  /// Saves an item for later.
  ///
  /// Sends a "saved" taste signal and adds the item to
  /// the saved list.
  Future<void> saveItem(String itemId);

  /// Reports an error to the feedback system.
  ///
  /// The report is stored locally and synced to the server
  /// when connectivity is available.
  Future<void> reportError(ErrorReport report);

  /// Submits user feedback with optional context.
  ///
  /// Creates an error report of type "user_feedback" and
  /// optionally correlates it with a recent error.
  Future<void> submitFeedback(
    String message, {
    Map<String, dynamic>? context,
  });

  /// Stream of pending error reports awaiting sync.
  Stream<List<ErrorReport>> get pendingReports;
}
