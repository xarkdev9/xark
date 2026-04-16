import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../chromatic_atmosphere.dart';
import '../conversation_list_row.dart';
import '../empty_state.dart';
import '../sheets/dm_sheet.dart';
import '../sheets/group_sheet.dart';

/// iMessage-style merged conversation list. Renders DMs and Groups
/// in a single scrollable list sorted by recency. The per-row
/// `isGroup` flag toggles name-casing on [ConversationListRow] and
/// decides which detail sheet to open on tap.
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(chatsFeedProvider);

    return AtmosphereDensityScope(
      density: AtmosphereDensity.dense,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 56)),
          if (feed.isEmpty)
            const SliverFillRemaining(
              child: HelloEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                headline: 'No Conversations Yet',
                body: 'Start chatting with someone',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 96),
              sliver: SliverList.builder(
                itemCount: feed.length,
                itemBuilder: (ctx, i) {
                  final item = feed[i];
                  if (item is DmFeedItem) {
                    return ConversationListRow(
                      conversation: item.conversation,
                      isGroup: false,
                      onTap: () => openDmSheet(ctx, item),
                    );
                  }
                  if (item is GroupFeedItem) {
                    return ConversationListRow(
                      conversation: item.conversation,
                      isGroup: true,
                      onTap: () => openGroupSheet(ctx, item),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
        ],
      ),
    );
  }
}
