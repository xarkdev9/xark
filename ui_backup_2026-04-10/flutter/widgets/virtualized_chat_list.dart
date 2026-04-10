import 'package:flutter/material.dart';

/// Virtualized reverse-scrolling chat list for 100k+ messages.
/// Uses SliverList with reverse:true and automatic widget recycling.
/// Dynamic heights calculated per-message type.

class VirtualizedChatList extends StatelessWidget {
  final List<dynamic> messages;
  final Widget Function(BuildContext context, dynamic message, int index) itemBuilder;
  final ScrollController? controller;
  final Future<void> Function()? onLoadMore;

  const VirtualizedChatList({
    super.key,
    required this.messages,
    required this.itemBuilder,
    this.controller,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Load more when scrolled near the top (oldest messages)
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          onLoadMore?.call();
        }
        return false;
      },
      child: CustomScrollView(
        controller: controller,
        reverse: true, // Newest at bottom
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= messages.length) return null;
                return RepaintBoundary(
                  // RepaintBoundary prevents unnecessary repaints
                  // when only one message changes
                  child: itemBuilder(context, messages[index], index),
                );
              },
              childCount: messages.length,
              // Enable automatic keep-alive for recently visible items
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: false, // We add our own above
            ),
          ),
        ],
      ),
    );
  }
}
