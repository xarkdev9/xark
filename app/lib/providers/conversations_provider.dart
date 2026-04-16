import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_helpers.dart';

/// Live stream of all conversations from the engine. Emits an
/// empty list while the engine is uninitialized.
final conversationsStreamProvider =
    StreamProvider<List<Conversation>>((ref) {
  final engine = engineOrNull(ref);
  if (engine == null) {
    return Stream<List<Conversation>>.value(const <Conversation>[]);
  }
  return engine.conversations;
});

/// Per-conversation message controller (family provider).
final conversationControllerProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final engine = engineOrNull(ref);
  if (engine == null) {
    return Stream<List<Message>>.value(const <Message>[]);
  }
  return engine.getSession(conversationId).messages;
});

int _unreadFirstThenRecent(Conversation a, Conversation b) {
  // Unread (count > 0) ranks above read (count == 0).
  final aUnread = a.unreadCount > 0;
  final bUnread = b.unreadCount > 0;
  if (aUnread != bUnread) return aUnread ? -1 : 1;
  // Then most recent activity first (fall back to updatedAt).
  final aTs = a.lastMessageTimestamp ?? a.updatedAt;
  final bTs = b.lastMessageTimestamp ?? b.updatedAt;
  return bTs.compareTo(aTs);
}

/// Direct messages (1:1) sorted unread-first then recent-first.
final directMessagesProvider = Provider<List<Conversation>>((ref) {
  final all = ref.watch(conversationsStreamProvider).value ??
      const <Conversation>[];
  final dms = all
      .where((c) => c.type == ConversationType.oneToOne && !c.isArchived)
      .toList()
    ..sort(_unreadFirstThenRecent);
  return dms;
});

/// Group chats sorted unread-first then recent-first.
final groupChatsProvider = Provider<List<Conversation>>((ref) {
  final all = ref.watch(conversationsStreamProvider).value ??
      const <Conversation>[];
  final groups = all
      .where((c) => c.type == ConversationType.group && !c.isArchived)
      .toList()
    ..sort(_unreadFirstThenRecent);
  return groups;
});

/// Total unread count for the Chats (DM) card header badge.
final dmUnreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(directMessagesProvider)
      .fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// Total unread count for the Groups card header badge.
final groupUnreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(groupChatsProvider)
      .fold<int>(0, (sum, c) => sum + c.unreadCount);
});
