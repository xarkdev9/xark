import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show engineProvider;
import 'conversations_provider.dart';

ChatEngine? _engineOrNull(Ref ref) {
  try {
    return ref.watch(engineProvider);
  } catch (_) {
    return null;
  }
}

/// Cross-group active decisions via client-side merge.
///
/// Watches [conversationsStreamProvider], fetches
/// `engine.getDecisionItems(groupId)` for every group conversation,
/// filters to `!isLocked && state != 'archived'`, sorts by
/// `agreementScore` descending.
///
/// v1 note: the raw `DecisionItem` holds ciphertext payloads. Decision
/// rows render the item id (truncated) as a placeholder title and the
/// `state` as category. A `DecryptedItemPayload` wrapper is planned
/// for v2 — this provider's public shape will not change.
final activeDecisionsProvider =
    FutureProvider<List<DecisionItem>>((ref) async {
  final engine = _engineOrNull(ref);
  if (engine is! ChatEngineDecisions) {
    return const <DecisionItem>[];
  }
  final groups = ref.watch(groupChatsProvider);
  if (groups.isEmpty) return const <DecisionItem>[];

  final lists = await Future.wait(
    groups.map((g) => engine.getDecisionItems(g.id)),
  );
  final merged = <DecisionItem>[
    for (final list in lists) ...list,
  ]
      .where((d) => !d.isLocked && d.state != 'archived')
      .toList()
    ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));

  return merged;
});

/// Count of active decisions for the Decisions card header badge.
final activeDecisionsCountProvider = Provider<int>((ref) {
  return ref.watch(activeDecisionsProvider).value?.length ?? 0;
});
