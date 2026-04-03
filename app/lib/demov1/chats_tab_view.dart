import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'demov1_main.dart';
import 'theme.dart';
import 'chat_view.dart';

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
        // Chats tab = 1:1 DMs only. Groups are on the Groups tab.
        final dms = conversations
            .where((c) => c.type == ConversationType.oneToOne)
            .toList();

        if (dms.isEmpty) {
          return const Center(
            child: Text(
              "No chats yet.",
              style: HelloTypography.hint,
            ),
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

  static const _nameMap = {
    'bali': 'Bali Trip 🌴',
    'sarah': "Sarah's Birthday",
    'alice': 'Alice',
    'tokyo': 'Tokyo 2026',
    'horizon': 'Project Horizon',
    'dm_emma': 'Emma',
    'dm_liam': 'Liam',
    'dm_olivia': 'Olivia',
    'dm_noah': 'Noah',
    'dm_ava': 'Ava',
    'dm_ethan': 'Ethan',
    'dm_sophia': 'Sophia',
    'dm_mason': 'Mason',
    'group_weekend_hike': 'Weekend Hike 🥾',
    'group_roommates': 'Roommates',
    'group_book_club': 'Book Club 📚',
    'group_startup_ideas': 'Startup Ideas 💡',
    'group_family': 'Family ❤️',
    'group_gym_crew': 'Gym Crew 💪',
    'group_music_fest': 'Music Fest 🎵',
  };

  String _resolveDisplayName(Conversation conversation) {
    return _nameMap[conversation.id] ??
        conversation.id.replaceAll('_', ' ').replaceFirst(
          conversation.id[0],
          conversation.id[0].toUpperCase(),
        );
  }

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
    
    // Resolve display name from conversation ID
    final displayName = _resolveDisplayName(conversation);
    final initial = displayName.substring(0, 1).toUpperCase();
    final isGroup = conversation.type == ConversationType.group;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ChatView(spaceId: conversation.id),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 56x56 Edge-to-Edge Avatar — circle for DM, rounded square for group
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isGroup
                    ? const Color(0xFFE8E3DD) // Warm linen for groups
                    : HelloColors.recessed,
                shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGroup ? BorderRadius.circular(16) : null,
              ),
              alignment: Alignment.center,
              child: isGroup
                  ? Icon(Icons.group_rounded, size: 24,
                      color: HelloColors.inkPrimary.withValues(alpha: 0.4))
                  : Text(initial, style: HelloTypography.spaceTitle),
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
                            color: Color(0xFFFF6B35),
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
