import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_engine/chat_engine.dart';
import '../main.dart'; // engineProvider

final conversationControllerProvider = StreamProvider.family<List<Message>, String>((ref, spaceId) {
  final engine = ref.watch(engineProvider);
  return engine.getSession(spaceId).messages;
});
