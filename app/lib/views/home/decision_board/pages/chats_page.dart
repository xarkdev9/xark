import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../conversation_list_row.dart';
import '../sheets/dm_sheet.dart';

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
    final dms = feed.whereType<DmFeedItem>().toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 96),
          sliver: SliverList.builder(
            itemCount: dms.length,
            itemBuilder: (ctx, i) {
              final item = dms[i];
              return ConversationListRow(
                conversation: item.conversation,
                isGroup: false,
                onTap: () => openDmSheet(ctx, item),
              );
            },
          ),
        ),
      ],
    );
  }
}
