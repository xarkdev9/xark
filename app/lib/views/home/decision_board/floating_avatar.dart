import 'package:flutter/material.dart';

import '../../../theme.dart';

/// A 36px user avatar circle that floats at top-left, positioned by
/// the caller via `Positioned` or `Align`. Replaces the previous
/// `feed_header.dart` strip — no bar chrome around it, just the
/// avatar on top of the feed.
class FloatingAvatar extends StatelessWidget {
  FloatingAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // v2: profile / settings
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HelloColors.recessed,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'R',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
