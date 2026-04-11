import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/conversations_provider.dart';
import 'card_header.dart';
import 'conversation_row.dart';
import 'empty_state.dart';
import 'see_all_row.dart';

/// Groups card (group chats). Up to 10 rows + See all N row.
class GroupsCard extends ConsumerWidget {
  final VoidCallback onHeaderTap;
  final void Function(String conversationId) onRowTap;
  final VoidCallback onEmptyCtaTap;

  const GroupsCard({
    super.key,
    required this.onHeaderTap,
    required this.onRowTap,
    required this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupChatsProvider);
    final unread = ref.watch(groupUnreadCountProvider);

    return Column(
      children: [
        CardHeader(
          title: 'GROUPS',
          unreadCount: unread,
          onTap: onHeaderTap,
        ),
        Expanded(
          child: groups.isEmpty
              ? CardEmptyState(
                  kind: EmptyStateKind.groups,
                  onCtaTap: onEmptyCtaTap,
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      groups.length > 10 ? 10 : groups.length,
                  itemBuilder: (context, index) {
                    if (groups.length > 10 && index == 9) {
                      return SeeAllRow(
                        count: groups.length,
                        onTap: onHeaderTap,
                      );
                    }
                    return ConversationRow(
                      conversation: groups[index],
                      isGroup: true,
                      onTap: () => onRowTap(groups[index].id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
