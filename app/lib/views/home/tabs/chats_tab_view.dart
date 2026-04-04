import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../../../main.dart';
import '../../../../theme.dart';
import '../../../../src/mock_data_seed.dart';
import '../../../demov2/space_layout.dart';

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final engine = ref.watch(engineProvider);
  return engine.conversations;
});

class ChatsTabView extends ConsumerWidget {
  const ChatsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (conversations) {
        // Chats tab = 1:1 DMs only
        final dms = conversations.where((c) => c.type == ConversationType.oneToOne).toList();

        if (dms.isEmpty) {
          return const Center(
            child: Text("No chats yet.", style: HelloTypography.hint),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: dms.length,
          itemBuilder: (context, index) {
            final convo = dms[index];
            return ChatRow(conversation: convo);
          },
        );
      },
    );
  }
}

class ChatRow extends StatelessWidget {
  final Conversation conversation;

  const ChatRow({
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
            // 56x56 Edge-to-Edge Circular Avatar
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: HelloColors.recessed,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: HelloTypography.spaceTitle, // Clean, 400 weight typography
              ),
            ),
            const SizedBox(width: 16),
            
            // Text Column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row (Name and Timestamp)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: HelloTypography.spaceTitle.copyWith(
                            fontWeight: FontWeight.w400, // Explicitly enforce No-Bold
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  // Bottom Row (Preview)
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
