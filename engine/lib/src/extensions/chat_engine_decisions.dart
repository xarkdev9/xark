import '../domain/models/decision_item.dart';
import '../domain/models/commitment_proof.dart';
import '../public_api/chat_engine.dart';

/// Optional decision engine extension for ChatEngine.
/// Provides Heart-Sort ranking, reaction voting, and Green-Lock commitment.
///
/// Usage:
///   final engine = await ChatEngine.initialize(config);
///   if (engine is ChatEngineDecisions) {
///     final items = await engine.getDecisionItems('group_123');
///     await engine.reactToItem('item_1', 'love_it');
///   }
///
/// This is NOT part of the core E2EE chat SDK.
/// It's an optional extension for apps that need collaborative decision-making.
mixin ChatEngineDecisions on ChatEngine {
  /// Get ranked decision items for a group.
  Future<List<DecisionItem>> getDecisionItems(String groupId);

  /// React to a decision item (love_it / works_for_me / not_for_me).
  Future<void> reactToItem(String itemId, String signal);

  /// Lock a decision item with commitment proof (Green-Lock).
  Future<void> lockItem(String itemId, CommitmentProof proof);
}
