import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'action_card_provider.dart';

// Target 14: The Global Lock State
class GlobalLockNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
  void lock(String id) => state = id;
}
final globalLockProvider = NotifierProvider<GlobalLockNotifier, String?>(() => GlobalLockNotifier());

final consensusListenerProvider = Provider.family<bool, String>((ref, groupId) {
  final asyncCards = ref.watch(actionCardProvider(groupId));
  
  return asyncCards.maybeWhen(
    data: (cards) {
      if (cards.isEmpty) return false;
      return cards.any((msg) => msg.isStarred); // Placeholder mapping for score trigger
    },
    orElse: () => false,
  );
});
