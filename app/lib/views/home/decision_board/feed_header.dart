import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Top bar — just a user avatar on the left. Replaces the previous
/// "LIVE SURFACE / What matters now / FOCUS" text strip so that
/// space is available for profile chrome (future: tap → settings).
class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          _UserAvatar(),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // v2: open settings / profile sheet
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: HelloColors.recessed,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          'R',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
