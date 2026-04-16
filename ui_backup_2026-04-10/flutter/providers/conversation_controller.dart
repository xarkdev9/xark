import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../main.dart'; // engineProvider

final conversationControllerProvider = StreamProvider.family<List<Message>, String>((ref, groupId) {
  final engine = ref.watch(engineProvider);
  return engine.getSession(groupId).messages;
});

final presenceProvider = StreamProvider.family<PresenceState, String>((ref, groupId) {
  final engine = ref.watch(engineProvider);
  return engine.getSession(groupId).presence;
});

final typingProvider = StreamProvider.family<List<TypingIndicator>, String>((ref, groupId) {
  final engine = ref.watch(engineProvider);
  return engine.getSession(groupId).typing;
});

final receiptsProvider = StreamProvider.family<List<Receipt>, String>((ref, groupId) {
  final engine = ref.watch(engineProvider);
  return engine.getSession(groupId).receipts;
});
