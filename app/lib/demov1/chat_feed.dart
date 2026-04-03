import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'conversation_controller.dart';
import 'chat_bubble.dart';
import 'encrypted_image_view.dart';

import 'demov1_main.dart'; // engineProvider

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
    final messagesAsync = ref.watch(conversationControllerProvider(widget.spaceId));

    return messagesAsync.when(
      loading: () => const Center(
        child: Text('Loading messages...', style: TextStyle(
          fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w300,
          color: Color(0x40000000),
        )),
      ),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(
            child: Text('Send the first message', style: TextStyle(
              fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w300,
              color: Color(0x40000000),
            )),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final prev = index < messages.length - 1 ? messages[index + 1] : null;
            final next = index > 0 ? messages[index - 1] : null;

            final isOutbound = msg.senderId == 'me';
            final isFirstInGroup = prev?.senderId != msg.senderId;
            final isLastInGroup = next?.senderId != msg.senderId;

            // Compute receipts
            final receiptsAsync = ref.watch(receiptsProvider(widget.spaceId));
            final receipts = receiptsAsync.value
                ?.where((r) => r.messageId == msg.id).toList() ?? [];

            var status = msg.status;
            if (receipts.any((r) => r.readAt != null)) {
              status = MessageStatus.read;
            } else if (receipts.any((r) => r.deliveredAt != null)) {
              status = MessageStatus.delivered;
            }

            final ts = msg.timestamp;
            final timeStr = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

            // Sender name for group chats (show on first message in group)
            String? senderName;
            if (!isOutbound && isFirstInGroup) {
              senderName = _resolveSenderName(msg.senderId);
            }

            Widget? mediaChild;
            if (msg.media != null) {
              mediaChild = EncryptedImageView(metadata: msg.media!);
            }

            // System messages
            if (msg.type == MessageType.system) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                child: Text(
                  msg.text ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w300,
                    color: Color(0x60000000),
                  ),
                ),
              );
            }

            // AI messages
            if (msg.type == MessageType.ai) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                child: Text(
                  msg.text ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w300,
                    color: Color(0xFFFF6B35), // Liquid Fire orange
                  ),
                ),
              );
            }

            return RepaintBoundary(
              child: Column(
                crossAxisAlignment: isOutbound
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, bottom: 2, top: 8),
                      child: Text(senderName, style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
                        color: Color(0xFFFF6B35),
                      )),
                    ),
                  ChatBubble(
                    text: msg.text ?? '',
                    isOutbound: isOutbound,
                    status: status,
                    isFirstInGroup: isFirstInGroup,
                    isLastInGroup: isLastInGroup,
                    timestamp: timeStr,
                    mediaChild: mediaChild,
                    onReply: widget.onReply != null ? () => widget.onReply!(msg) : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _resolveSenderName(String senderId) {
    const names = {
      'user_0': 'Sarah', 'user_1': 'Alex', 'user_2': 'Maya',
      'user_3': 'Jordan', 'user_X': 'Chris', 'user_a': 'Kim',
    };
    return names[senderId] ?? senderId;
  }
}

// Old _FeedItem and _MessageWithContext removed — rendering is now inline in data: callback
