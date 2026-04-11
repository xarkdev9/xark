import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// A single list row for a conversation (1:1 or group).
/// 64px tall, horizontal layout: avatar · name / preview · timestamp.
class ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final bool isGroup;
  final VoidCallback onTap;

  const ConversationRow({
    super.key,
    required this.conversation,
    required this.isGroup,
    required this.onTap,
  });

  bool get _isUnread => conversation.unreadCount > 0;

  String _displayName() {
    if (isGroup) {
      final count = conversation.participantIds.length;
      return 'Group · $count members';
    }
    return conversation.id.length > 8
        ? 'Chat ${conversation.id.substring(0, 8)}'
        : 'Chat ${conversation.id}';
  }

  String _previewText() {
    final text = conversation.lastMessageText ?? '';
    if (text.isEmpty) return 'No messages yet';
    return text;
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
    final nameColor =
        _isUnread ? HelloColors.inkPrimary : HelloColors.inkSecondary;
    final previewColor = _isUnread
        ? const Color(0xADF0EFF4)
        : HelloColors.inkTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: HelloColors.inkPrimary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            _Avatar(
              conversation: conversation,
              isGroup: isGroup,
              isUnread: _isUnread,
              unreadCount: conversation.unreadCount,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: nameColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _previewText(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: previewColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _timestampText(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.4,
                color: _isUnread
                    ? HelloColors.accent
                    : HelloColors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Conversation conversation;
  final bool isGroup;
  final bool isUnread;
  final int unreadCount;

  const _Avatar({
    required this.conversation,
    required this.isGroup,
    required this.isUnread,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (conversation.id.isNotEmpty
            ? conversation.id[0].toUpperCase()
            : '?');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGroup
                  ? const [Color(0xFFFF385C), Color(0xFF14B8A6)]
                  : const [Color(0xFFF472B6), Color(0xFF9D174D)],
            ),
            border: isUnread
                ? Border.all(
                    color: HelloColors.accent,
                    width: 1.5,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Color(0xFFF0EFF4),
            ),
          ),
        ),
        if (isUnread && unreadCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              decoration: BoxDecoration(
                color: HelloColors.accent,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: HelloColors.voidBg,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HelloColors.accent.withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.voidBg,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
