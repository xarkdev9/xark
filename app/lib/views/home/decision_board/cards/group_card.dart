import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col group card. Flat recessed avatar + group name + live eyebrow
/// + activity blurb + unread dot. Tap opens [openGroupSheet].
class GroupCard extends StatelessWidget {
  final GroupFeedItem item;
  final VoidCallback onTap;

  const GroupCard({super.key, required this.item, required this.onTap});

  String _displayName() {
    return item.conversation.id
        .split('_')
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _eyebrow() {
    if (item.typingCount > 0) return '${item.typingCount} TYPING';
    if (item.conversation.unreadCount > 0) return 'ACTIVE';
    return 'GROUP';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = item.conversation.unreadCount > 0;
    final preview = item.conversation.lastMessageText ?? '';
    final memberCount = item.conversation.participantIds.length;
    final initial = _displayName().isNotEmpty
        ? _displayName()[0].toUpperCase()
        : 'G';

    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: HelloColors.recessed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eyebrow(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                        color: isUnread
                            ? HelloColors.accent
                            : HelloColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: HelloColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview.isEmpty ? 'No activity yet' : preview,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w300,
              height: 1.35,
              color: HelloColors.inkSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            '$memberCount members',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
