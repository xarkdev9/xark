// iMessage-style conversation list row.
//
// Flat row: [avatar] [name + timestamp] / [preview + count badge].
// No left-side unread dot. When there are unread messages, a small
// Rausch count badge appears bottom-right, vertically aligned with
// the preview line — WhatsApp-minimal, iMessage-flat.

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
    final unread = conversation.unreadCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.black.withValues(alpha: 0.04),
        highlightColor: Colors.black.withValues(alpha: 0.02),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 10),
                          _UnreadBadge(count: unread),
                        ],
                      ],
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

/// Tiny Rausch pill with an inkPrimary count inside. 18px tall,
/// 6px horizontal padding, expands to fit 1-3 digit counts.
class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: HelloColors.accent,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1,
          color: Color(0xFFF0EFF4),
        ),
      ),
    );
  }
}
