import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import 'cosmos_sender_model.dart';

/// Horizontal row of up to 6 face-only avatars at 48px.
///
/// Render order: left → right by recency (fresher on the left).
/// Renders fewer than 6 when the queue is shorter; never pads with
/// placeholders.
///
/// Zero-box: just HologramAvatars in a Row with gaps. No container,
/// no ring, no shadow, no background fill.
///
/// Phase 6 (Task 20) will add ghost-opacity during the ascending
/// reward phase to preserve row width while queue[0] is promoted.
class QueueRow extends StatelessWidget {
  /// Up to 6 pending senders, already recency-sorted.
  final List<PendingSender> senders;

  /// Invoked when a queue avatar is tapped. Receives the sender.
  final ValueChanged<PendingSender>? onTap;

  const QueueRow({
    super.key,
    required this.senders,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (senders.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < senders.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap!(senders[i]),
            child: HologramAvatar(
              avatarPath: getAvatarImagePath(senders[i].name),
              size: 48,
            ),
          ),
        ],
      ],
    );
  }
}
