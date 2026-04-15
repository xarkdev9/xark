import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import 'cosmos_sender_model.dart';

/// The 140×140 foreground avatar at upper-third of Home.
///
/// Uses HologramAvatar's built-in guillotine ShaderMask dissolve
/// — never wraps the photo in a container, ring, or shadow. The
/// photo floats in the atmosphere.
///
/// Reward-animation wiring (levitation, plasma infusion, ascent)
/// is added in Phase 6 (Task 18); this task is the static-placement
/// baseline.
class ForegroundAvatar extends StatelessWidget {
  final PendingSender sender;
  final VoidCallback? onTap;

  const ForegroundAvatar({
    super.key,
    required this.sender,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: HologramAvatar(
        avatarPath: getAvatarImagePath(sender.name),
        size: 140,
      ),
    );
  }
}
