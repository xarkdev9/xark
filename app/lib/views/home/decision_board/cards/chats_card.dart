import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/conversations_provider.dart';
import 'card_header.dart';
import 'conversation_row.dart';
import 'empty_state.dart';
import 'see_all_row.dart';

/// Chats card (1:1 DMs). Shows up to 10 rows + See all N row.
class ChatsCard extends ConsumerWidget {
  final VoidCallback onHeaderTap;
  final void Function(String conversationId) onRowTap;
  final VoidCallback onEmptyCtaTap;

  const ChatsCard({
    super.key,
    required this.onHeaderTap,
    required this.onRowTap,
    required this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dms = ref.watch(directMessagesProvider);
    final unread = ref.watch(dmUnreadCountProvider);

    return Column(
      children: [
        CardHeader(
          title: 'CHATS',
          unreadCount: unread,
          onTap: onHeaderTap,
        ),
        Expanded(
          child: dms.isEmpty
              ? CardEmptyState(
                  kind: EmptyStateKind.chats,
                  onCtaTap: onEmptyCtaTap,
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      dms.length > 10 ? 10 : dms.length,
                  itemBuilder: (context, index) {
                    if (dms.length > 10 && index == 9) {
                      return SeeAllRow(
                        count: dms.length,
                        onTap: onHeaderTap,
                      );
                    }
                    return ConversationRow(
                      conversation: dms[index],
                      isGroup: false,
                      onTap: () => onRowTap(dms[index].id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
