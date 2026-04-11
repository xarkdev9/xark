import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Shared card header: 56px, tiny caps title + unread count.
/// Tappable — fires onTap to navigate to the full list screen.
/// Zero-Box: no background, no border, only a bottom hairline.
class CardHeader extends StatelessWidget {
  /// Already-uppercased title (e.g. "CHATS").
  final String title;
  final int unreadCount;
  final VoidCallback onTap;

  const CardHeader({
    super.key,
    required this.title,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
                color: HelloColors.inkSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: HelloColors.inkTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              unreadCount > 0 ? '$unreadCount UNREAD' : 'CAUGHT UP',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
                color: unreadCount > 0
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
