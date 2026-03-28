import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../providers/conversation_controller.dart';
import 'chat_bubble.dart';

import '../main.dart'; // engineProvider

class ChatFeed extends ConsumerStatefulWidget {
  const ChatFeed({super.key});

  @override
  ConsumerState<ChatFeed> createState() => _ChatFeedState();
}

class _ChatFeedState extends ConsumerState<ChatFeed> {
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _isLoadingMore = true;
      ref.read(engineProvider).getSession('default_space').loadMore(limit: 50).whenComplete(() {
        if (mounted) {
          _isLoadingMore = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apple-Scale Mandate: Watch strictly the length to know when to insert
    final messageCount = ref.watch(
      conversationControllerProvider('default_space').select((asyncData) => asyncData.value?.length ?? 0)
    );

    return ListView.builder(
      controller: _scrollController,
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

    // Consume the session.receipts stream and map them to the corresponding Message object
    final receipts = ref.watch(
      receiptsProvider('default_space').select((asyncData) {
        return asyncData.value?.where((r) => r.messageId == message.id).toList() ?? <Receipt>[];
      })
    );

    var computedStatus = message.status;
    bool isRead = receipts.any((r) => r.readAt != null);
    bool isDelivered = receipts.any((r) => r.deliveredAt != null);

    if (isRead) {
      computedStatus = MessageStatus.read;
    } else if (isDelivered && computedStatus != MessageStatus.read) {
      computedStatus = MessageStatus.delivered;
    }

    return ChatBubble(
      text: message.text ?? '',
      isOutbound: message.role == 'user',
      status: computedStatus,
    );
  }
}
