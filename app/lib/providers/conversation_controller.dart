import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_engine/chat_engine.dart';
import '../main.dart'; // engineProvider

final conversationControllerProvider = StreamProvider.family<List<Message>, String>((ref, groupId) {
  final engine = ref.watch(engineProvider);
  return engine.getSession(groupId).messages;
});
