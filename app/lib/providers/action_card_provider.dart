import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'conversation_controller.dart';

final actionCardProvider = Provider.family<AsyncValue<List<Message>>, String>((ref, groupId) {
  final asyncValue = ref.watch(conversationControllerProvider(groupId));
  return asyncValue.whenData((messages) {
    return messages.where((msg) => msg.role == 'hello' || msg.type == MessageType.hello).toList();
  });
});
