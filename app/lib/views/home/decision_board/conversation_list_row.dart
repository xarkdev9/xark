// iMessage / WhatsApp-style conversation list row.
//
// Flat 72px row (no card chrome) with:
//   • Unread dot on the far left (8px, Rausch, only if unread)
//   • 50px recessed avatar circle with initial
//   • Name + timestamp on top row
//   • 1-line message preview below, inkSecondary thin weight
//   • 1px bottom hairline separator at 6% white
//
// Used by ChatsPage and GroupsPage instead of the masonry card
// layout. Font weights stay within the No-Bold rule (max w400,
// preview w300).

import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../../../theme.dart';

class ConversationListRow extends StatelessWidget {
  final Conversation conversation;
  final bool isGroup;
  final VoidCallback onTap;

  const ConversationListRow({
    super.key,
    required this.conversation,
    required this.isGroup,
    required this.onTap,
  });

  bool get _isUnread => conversation.unreadCount > 0;

  String _displayName() {
    final id = conversation.id;
    if (id.isEmpty) return 'Unknown';
    if (isGroup) {
      return id
          .split('_')
          .map((w) =>
              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  String _timestampText() {
    final ts = conversation.lastMessageTimestamp;
    if (ts == null) return '';
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${ts.month}/${ts.day}';
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final preview = conversation.lastMessageText ?? '';
    final subtitleText = preview.isEmpty ? 'No messages yet' : preview;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.02),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Unread dot gutter on the far left, iMessage style.
              SizedBox(
                width: 14,
                child: _isUnread
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: HelloColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: HelloColors.recessed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name + preview + timestamp column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: HelloColors.inkPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _timestampText(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        height: 1.3,
                        color: HelloColors.inkSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
