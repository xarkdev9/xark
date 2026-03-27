import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_engine/chat_engine.dart';
import 'conversation_controller.dart';

final actionCardProvider = Provider.family<AsyncValue<List<Message>>, String>((ref, spaceId) {
  final asyncValue = ref.watch(conversationControllerProvider(spaceId));
  return asyncValue.whenData((messages) {
    return messages.where((msg) => msg.role == 'hello' || msg.type == MessageType.xark).toList();
  });
});
