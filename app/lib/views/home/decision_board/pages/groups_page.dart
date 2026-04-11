import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../conversation_list_row.dart';
import '../sheets/group_sheet.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(groupsFeedProvider);
    final groups = feed.whereType<GroupFeedItem>().toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 96),
          sliver: SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (ctx, i) {
              final item = groups[i];
              return ConversationListRow(
                conversation: item.conversation,
                isGroup: true,
                onTap: () => openGroupSheet(ctx, item),
              );
            },
          ),
        ),
      ],
    );
  }
}
