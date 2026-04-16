import 'dart:async';

import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seed_data.dart';

const int _playgroundGroupSize = 6;

class PlaygroundDecisionNotifier extends Notifier<List<DecisionItem>> {
  final _consensusController = StreamController<String>.broadcast();

  Stream<String> get consensusEvents => _consensusController.stream;

  @override
  List<DecisionItem> build() {
    ref.onDispose(_consensusController.close);
    return List<DecisionItem>.from(mockDecisions);
  }

  void vote(String itemId, String signal, String userId) {
    final items = [...state];
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;

    final item = items[idx];
    final reactions = Map<String, String>.from(item.reactions);
    reactions[userId] = signal;

    double weightedScore = 0;
    for (final r in reactions.values) {
      weightedScore += switch (r) {
        'love_it' => 5,
        'works_for_me' => 1,
        'not_for_me' => -3,
        _ => 0,
      };
    }

    final agreementScore =
        (reactions.length / _playgroundGroupSize).clamp(0.0, 1.0);
    final newState = agreementScore >= 0.8 ? 'locked' : item.state;
    final wasLocked = item.state == 'locked';

    items[idx] = item.copyWith(
      reactions: reactions,
      weightedScore: weightedScore,
      agreementScore: agreementScore,
      state: newState,
      isLocked: newState == 'locked',
    );

    items.sort((a, b) {
      if (a.state == 'locked' && b.state != 'locked') return 1;
      if (b.state == 'locked' && a.state != 'locked') return -1;
      return b.weightedScore.compareTo(a.weightedScore);
    });

    state = items;

    if (!wasLocked && newState == 'locked') {
      _consensusController.add(itemId);
    }
  }

  void addItem(String title, String category, String photoUrl) {
    final id = 'pg_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = DecisionItem(
      id: id,
      groupId: 'swiss_jun_2026',
      ciphertextPayload: title,
      nonce: category,
      state: 'proposed',
      weightedScore: 0,
      agreementScore: 0,
      reactions: const {},
      proposedBy: 'me',
    );
    state = [newItem, ...state];
  }
}

final playgroundDecisionsProvider =
    NotifierProvider<PlaygroundDecisionNotifier, List<DecisionItem>>(() {
  return PlaygroundDecisionNotifier();
});

final playgroundConsensusEventProvider = StreamProvider<String>((ref) {
  final notifier = ref.watch(playgroundDecisionsProvider.notifier);
  return notifier.consensusEvents;
});
