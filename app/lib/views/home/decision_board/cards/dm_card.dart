import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col DM card. Flat recessed avatar + name + eyebrow + 2-line
/// preview + unread dot. Tap opens [openDmSheet].
class DmCard extends StatelessWidget {
  final DmFeedItem item;
  final VoidCallback onTap;

  const DmCard({super.key, required this.item, required this.onTap});

  String _displayName() {
    final id = item.conversation.id;
    if (id.isEmpty) return 'Unknown';
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  String _timestamp() {
    final ts = item.conversation.lastMessageTimestamp;
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = item.conversation.unreadCount > 0;
    final preview = item.conversation.lastMessageText ?? '';
    final initial = _displayName()[0].toUpperCase();

    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Avatar(initial: initial),
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
                    Row(
                      children: [
                        const Text(
                          'DIRECT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timestamp(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.4,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ],
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
            preview.isEmpty ? 'No messages yet' : preview,
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
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  const _Avatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
