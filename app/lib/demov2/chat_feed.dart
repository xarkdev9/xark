import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../providers/conversation_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/encrypted_image_view.dart';
import '../theme.dart';

import '../main.dart'; // engineProvider

/// E2EE Chat Feed — reverse-scrolled, virtualized message list.
///
/// Apple-Scale: per-item selection via .select() — only changed rows rebuild.
/// Smart Grouping: consecutive same-sender messages get tighter radii.
/// Swipe-to-Reply: each bubble supports horizontal spring drag.

class ChatFeed extends ConsumerStatefulWidget {
  final String spaceId;
  final ValueChanged<Message>? onReply;

  const ChatFeed({
    super.key,
    required this.spaceId,
    this.onReply,
  });

  @override
  ConsumerState<ChatFeed> createState() => _ChatFeedState();
}

class _ChatFeedState extends ConsumerState<ChatFeed> {
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;
  bool _showTimestamps = false;
  Timer? _scrollPauseTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // Show timestamps briefly on load, then fade after 2s
    _showTimestamps = true;
    _scrollPauseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showTimestamps = false);
    });
  }

  @override
  void dispose() {
    _scrollPauseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Cancel any pending timestamp show
    _scrollPauseTimer?.cancel();

    // Hide timestamps while scrolling
    if (_showTimestamps) {
      setState(() => _showTimestamps = false);
    }

    // Show timestamps after 1s pause
    _scrollPauseTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showTimestamps = true);
    });

    // Existing load-more logic
    if (_isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _isLoadingMore = true;
      ref
          .read(engineProvider)
          .getSession(widget.spaceId)
          .loadMore(limit: 50)
          .whenComplete(() {
        if (mounted) _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageCount = ref.watch(
      conversationControllerProvider(widget.spaceId)
          .select((asyncData) => asyncData.value?.length ?? 0),
    );

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 130, bottom: 100),
      itemCount: messageCount,
      itemBuilder: (context, index) {
        final reversedIndex = messageCount - 1 - index;
        return _FeedItem(
          index: reversedIndex,
          spaceId: widget.spaceId,
          totalCount: messageCount,
          onReply: widget.onReply,
          showTimestamp: _showTimestamps,
        );
      },
    );
  }
}

class _FeedItem extends ConsumerWidget {
  final int index;
  final String spaceId;
  final int totalCount;
  final ValueChanged<Message>? onReply;
  final bool showTimestamp;

  const _FeedItem({
    required this.index,
    required this.spaceId,
    required this.totalCount,
    this.onReply,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch this specific message + neighbors for grouping
    final messageData = ref.watch(
      conversationControllerProvider(spaceId).select((asyncData) {
        final list = asyncData.value;
        if (list == null || index < 0 || index >= list.length) return null;

        final msg = list[index];
        final prev = index > 0 ? list[index - 1] : null;
        final next = index < list.length - 1 ? list[index + 1] : null;

        return _MessageWithContext(
          message: msg,
          prevSenderId: prev?.senderId,
          nextSenderId: next?.senderId,
        );
      }),
    );

    if (messageData == null) return const SizedBox.shrink();

    final message = messageData.message;
    final isOutbound = message.senderId == 'me';

    // Smart grouping: detect consecutive messages from same sender
    final isFirstInGroup = messageData.prevSenderId != message.senderId;
    final isLastInGroup = messageData.nextSenderId != message.senderId;

    // Compute receipt status from stream
    final receipts = ref.watch(
      receiptsProvider(spaceId).select((asyncData) {
        return asyncData.value
                ?.where((r) => r.messageId == message.id)
                .toList() ??
            <Receipt>[];
      }),
    );

    var computedStatus = message.status;
    if (receipts.any((r) => r.readAt != null)) {
      computedStatus = MessageStatus.read;
    } else if (receipts.any((r) => r.deliveredAt != null)) {
      computedStatus = MessageStatus.delivered;
    }

    // Media child for image messages
    Widget? mediaChild;
    if (message.media != null) {
      mediaChild = EncryptedImageView(metadata: message.media!);
    }

    final ts = message.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    // Show time header if timestamps are visible and this is last in group
    final shouldShowTime = showTimestamp && isLastInGroup;

    return RepaintBoundary(
      child: Column(
        children: [
          ChatBubble(
            text: message.text ?? '',
            isOutbound: isOutbound,
            status: computedStatus,
            isFirstInGroup: isFirstInGroup,
            isLastInGroup: isLastInGroup,
            mediaChild: mediaChild,
            senderId: message.senderId,
            onReply: onReply != null ? () => onReply!(message) : null,
          ),
          if (shouldShowTime)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: showTimestamp ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: HelloColors.inkTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper to pass message + neighbor context for grouping
class _MessageWithContext {
  final Message message;
  final String? prevSenderId;
  final String? nextSenderId;

  const _MessageWithContext({
    required this.message,
    this.prevSenderId,
    this.nextSenderId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessageWithContext &&
          message.id == other.message.id &&
          message.status == other.message.status &&
          prevSenderId == other.prevSenderId &&
          nextSenderId == other.nextSenderId;

  @override
  int get hashCode => Object.hash(
        message.id,
        message.status,
        prevSenderId,
        nextSenderId,
      );
}
