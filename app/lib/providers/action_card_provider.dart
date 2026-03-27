import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_engine/chat_engine.dart';
import 'conversation_controller.dart';

final actionCardProvider = Provider.family<AsyncValue<List<Message>>, String>((ref, groupId) {
  final asyncValue = ref.watch(conversationControllerProvider(groupId));
  return asyncValue.whenData((messages) {
    return messages.where((msg) => msg.role == 'hello' || msg.type == MessageType.xark).toList();
  });
});
