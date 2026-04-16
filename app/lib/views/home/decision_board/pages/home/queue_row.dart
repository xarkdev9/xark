import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import 'cosmos_sender_model.dart';
import 'reward_controller.dart';

/// Horizontal row of up to 6 face-only avatars at 48px.
///
/// When a RewardController is in the ascending phase, queue[0] is
/// being promoted to the foreground (via QueuePromotionAvatar below).
/// To keep the row's width stable and prevent sibling snap-shift,
/// queue[0] is rendered here at **opacity 0.0** — the space it
/// occupied stays reserved; remaining avatars do not re-center.
/// When the reward completes at t=1700ms and the provider re-emits
/// without queue[0], the row smoothly re-centers in the normal
/// layout pass (v2-review Patch #5b).
class QueueRow extends StatelessWidget {
  final List<PendingSender> senders;
  final ValueChanged<PendingSender>? onTap;
  final RewardController? rewardController;

  const QueueRow({
    super.key,
    required this.senders,
    this.onTap,
    this.rewardController,
  });

  @override
  Widget build(BuildContext context) {
    if (senders.isEmpty) return const SizedBox.shrink();
    if (rewardController == null) {
      return _buildRow(senders, ghostFirst: false);
    }
    return ListenableBuilder(
      listenable: rewardController!,
      builder: (ctx, _) {
        final isAscending =
            rewardController!.phase == RewardPhase.ascending;
        return _buildRow(senders, ghostFirst: isAscending);
      },
    );
  }

  Widget _buildRow(List<PendingSender> list, {required bool ghostFirst}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Opacity(
            opacity: ghostFirst && i == 0 ? 0.0 : 1.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: (onTap == null || (ghostFirst && i == 0))
                  ? null
                  : () => onTap!(list[i]),
              child: HologramAvatar(
                avatarPath: getAvatarImagePath(list[i].name),
                size: 48,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The rising-into-foreground widget for queue[0] during the
/// ascending phase. Rendered by home_page.dart in the foreground
/// position (top = h * 0.18) — the Transform.translate below
/// handles the physical travel from the queue row's Y (204pt below
/// the foreground anchor) up to 0 as the ascent progresses.
///
/// Without the Transform.translate the avatar would teleport
/// instantly from queue row to foreground slot (scaling but not
/// moving vertically). That shatters the spatial illusion
/// (v2-review Patch #5a).
class QueuePromotionAvatar extends StatelessWidget {
  final PendingSender sender;
  final RewardController rewardController;

  /// Vertical distance the avatar travels: computed as
  /// (foreground.height + label gap + label height + queue gap)
  /// = 140 + 12 + 20 + 32 = 204 per the layout in home_page.dart.
  /// If home_page layout constants change, update this.
  final double travelDistance;

  const QueuePromotionAvatar({
    super.key,
    required this.sender,
    required this.rewardController,
    this.travelDistance = 204.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewardController,
      builder: (ctx, _) {
        if (rewardController.phase != RewardPhase.ascending) {
          return const SizedBox.shrink();
        }
        // Clamp ascentProgress defensively before feeding the curve —
        // protects Curves.easeOutBack's own assert(t in [0,1]) from
        // any floating-point edge overshoot.
        final p = rewardController.ascentProgress.clamp(0.0, 1.0);
        // easeOutBack intentionally overshoots above 1.0 near the end
        // (spring effect). We keep the overshoot on size + yOffset —
        // that's what makes the avatar arrive with a subtle spring —
        // but clamp it for Opacity, which asserts 0 <= opacity <= 1.
        final eased = Curves.easeOutBack.transform(p);
        final size = 48.0 + (140.0 - 48.0) * eased;
        // Starts at +travelDistance (at queue row Y), ends at 0
        // (at foreground Y). Positive = down in Flutter.
        final yOffset = travelDistance * (1.0 - eased);

        return Center(
          child: Transform.translate(
            offset: Offset(0, yOffset),
            child: Opacity(
              opacity: eased.clamp(0.0, 1.0),
              child: HologramAvatar(
                avatarPath: getAvatarImagePath(sender.name),
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }
}
