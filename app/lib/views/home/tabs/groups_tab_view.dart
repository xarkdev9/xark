import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../../../theme.dart';
import '../../../../src/mock_data_seed.dart';
import 'chats_tab_view.dart';
import '../../../demov2/space_layout.dart';

class GroupsTabView extends ConsumerWidget {
  const GroupsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (conversations) {
        final groups = conversations.where((c) => c.type == ConversationType.group).toList();
        
        if (groups.isEmpty) {
          return const Center(
            child: Text(
              "No group chats yet.",
              style: HelloTypography.hint,
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final convo = groups[index];
            return GroupRow(conversation: convo);
          },
        );
      },
    );
  }
}

class GroupRow extends StatelessWidget {
  final Conversation conversation;

  const GroupRow({
    super.key,
    required this.conversation,
  });

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    
    final displayName = MockDataSeed.displayNames[conversation.id] ?? conversation.id;
    final initial = displayName.substring(0, 1).toUpperCase();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => SpaceLayout(spaceId: conversation.id, spaceTitle: displayName),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar differentiation: soft rounded rectangle, radius 18
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                // Use recessed as the soft surface color matching the UI tokens
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(18.0),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: HelloTypography.spaceTitle.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: HelloTypography.spaceTitle.copyWith(fontWeight: FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // The #D4536B rose dot for unread indicators
                      if (hasUnread) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4536B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatTimestamp(conversation.lastMessageTimestamp),
                        style: HelloTypography.hint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessageText ?? 'Draft',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HelloTypography.body.copyWith(
                      color: HelloColors.inkSecondary, 
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
