import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../main.dart'; // engineProvider
import 'decrypted_item_payload.dart';

final decryptedPlansProvider = FutureProvider.family<List<DecryptedItemPayload>, String>((ref, groupId) async {
  final engine = ref.watch(engineProvider);
  if (engine is! ChatEngineDecisions) {
    return [];
  }
  
  final items = await engine.getDecisionItems(groupId);
  
  final decryptedFutures = items.map((item) async {
    try {
      final jsonString = await engine.decryptPayload(
        groupId: groupId,
        ciphertext: item.ciphertextPayload,
        nonce: item.nonce,
      );
      return DecryptedItemPayload.fromJson(item, jsonString);
    } catch (e) {
      return DecryptedItemPayload(
        obliviousItem: item,
        title: 'Encrypted Plan',
        description: 'Waiting for keys...',
      );
    }
  });

  return Future.wait(decryptedFutures);
});
