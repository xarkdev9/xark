import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '../plasma/plasma.dart';
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
      id: item.id,
      kindOverlay: CardKindGradients.group,
      ambientPulse: isUnread,
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
                decoration: BoxDecoration(
                  color: HelloColors.recessed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
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
                      style: TextStyle(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isUnread
                            ? PlasmaTint(
                                child: Text(
                                  _eyebrow(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _eyebrow(),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1.5,
                                  color: HelloColors.inkTertiary,
                                ),
                              ),
                        if (item.typingCount > 0) ...[
                          const SizedBox(width: 8),
                          const _TypingDots(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isUnread)
                const PlasmaFill(
                  shape: BoxShape.circle,
                  width: 6,
                  height: 6,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview.isEmpty ? 'No activity yet' : preview,
            style: TextStyle(
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
            style: TextStyle(
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

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.16) % 1.0;
            final a = 0.24 +
                (0.76 *
                    (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0));
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 3 : 0),
              child: PlasmaFill(
                shape: BoxShape.circle,
                width: 3,
                height: 3,
                alpha: a,
              ),
            );
          }),
        );
      },
    );
  }
}
