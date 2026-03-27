import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_controller.dart';
import 'chat_bubble.dart';

class ChatFeed extends ConsumerWidget {
  const ChatFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Apple-Scale Mandate: Watch strictly the length to know when to insert
    final messageCount = ref.watch(
      conversationControllerProvider('default_space').select((asyncData) => asyncData.value?.length ?? 0)
    );

    return ListView.builder(
      reverse: true, // Anchor newest to bottom
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      itemCount: messageCount,
      itemBuilder: (context, index) {
        final reversedIndex = messageCount - 1 - index;
        return _FeedItem(index: reversedIndex);
      },
    );
  }
}

class _FeedItem extends ConsumerWidget {
  final int index;
  const _FeedItem({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Apple-Scale Mandate: Watch specific item only. Never rebuilds other rows.
    final message = ref.watch(
      conversationControllerProvider('default_space').select((asyncData) {
        final list = asyncData.value;
        if (list == null || index < 0 || index >= list.length) return null;
        return list[index];
      })
    );

    if (message == null) return const SizedBox.shrink();

    return ChatBubble(
      text: message.text ?? '',
      isOutbound: message.role == 'user',
    );
  }
}
