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

  /// Submit an encrypted decision item to the oblivious server.
  Future<void> addDecisionItem(String groupId, {required String ciphertextPayload, required String nonce});

  /// Decrypt an oblivious payload using the group's ratcheted key state.
  Future<String> decryptPayload({
    required String groupId,
    required String ciphertext,
    required String nonce,
  });

  /// Encrypt a plaintext JSON map using the group's ratcheted key state.
  /// Returns a tuple-like Map or object containing `ciphertextPayload` and `nonce`.
  Future<Map<String, String>> encryptPayload({
    required String groupId,
    required String plaintext,
  });
}
