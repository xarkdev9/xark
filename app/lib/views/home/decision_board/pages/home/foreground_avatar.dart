import 'package:flutter/material.dart';

import '../../avatar_utils.dart';
import '../../plasma/plasma.dart';
import 'cosmos_sender_model.dart';
import 'reward_controller.dart';

/// The 140×140 foreground avatar — reward-aware.
///
/// - rewardController null → static render (Ambient state)
/// - rewardController != null:
///   - phase infusing → translate Y -7pt (peaks at t≈300ms, eases
///     back) + ColorFiltered(srcATop) plasma overlay through palette
///   - phase ascending → translate Y -60pt (linear) +
///     _CustomGuillotineAvatar with gradient stops that animate
///     feet-fade → head-fade so the person dissolves from the top
///
/// Critical: does NOT use BlendMode.srcIn (would produce a faceless
/// plasma blob). Uses ColorFiltered with srcATop → single saveLayer,
/// face features remain intact (v2-review Patch #2).
class ForegroundAvatar extends StatelessWidget {
  final PendingSender sender;
  final VoidCallback? onTap;
  final RewardController? rewardController;

  const ForegroundAvatar({
    super.key,
    required this.sender,
    this.onTap,
    this.rewardController,
  });

  @override
  Widget build(BuildContext context) {
    // Static render path — Ambient state, no controller attached.
    if (rewardController == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: HologramAvatar(
          avatarPath: getAvatarImagePath(sender.name),
          size: 140,
        ),
      );
    }

    return ListenableBuilder(
      listenable: rewardController!,
      builder: (ctx, _) {
        final ctrl = rewardController!;
        final translateY = _computeTranslateY(ctrl);
        final avatar = _buildAvatar(ctrl);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: _withInfusion(avatar, ctrl),
          ),
        );
      },
    );
  }

  /// Levitation + ascent combined:
  /// - Levitation: ease up to -7pt over 300ms, drift back to 0 over 400ms
  /// - Ascent: linear up to -60pt over 700ms
  double _computeTranslateY(RewardController ctrl) {
    if (ctrl.phase == RewardPhase.infusing) {
      final p = ctrl.infusionProgress;
      // Tent function: peaks at 0.43 (about 300ms / 700ms ≈ 0.43)
      if (p < 0.43) {
        final t = p / 0.43;
        final eased = Curves.easeOutCubic.transform(t);
        return -7.0 * eased;
      } else {
        final t = (p - 0.43) / 0.57;
        final eased = Curves.easeInOut.transform(t);
        return -7.0 * (1.0 - eased);
      }
    }
    if (ctrl.phase == RewardPhase.ascending) {
      return -60.0 * ctrl.ascentProgress;
    }
    return 0.0;
  }

  /// Build the avatar with phase-aware guillotine gradient stops.
  /// - idle/infusing: default stops [0.0, 0.5, 0.85, 1.0]
  /// - ascending: stops interpolate toward [0.0, 0.15, 0.5, 1.0]
  ///   (fade migrates from feet to head — person dissolves from top down)
  Widget _buildAvatar(RewardController ctrl) {
    if (ctrl.phase != RewardPhase.ascending) {
      return HologramAvatar(
        avatarPath: getAvatarImagePath(sender.name),
        size: 140,
      );
    }

    final p = ctrl.ascentProgress;
    final stop1 = 0.5 * (1 - p) + 0.15 * p;
    final stop2 = 0.85 * (1 - p) + 0.5 * p;

    return _CustomGuillotineAvatar(
      avatarPath: getAvatarImagePath(sender.name),
      size: 140,
      stops: [0.0, stop1, stop2, 1.0],
    );
  }

  /// Plasma infusion: wrap the avatar in a ColorFiltered whose
  /// color animates through the plasma palette over the infusing
  /// phase. srcATop draws on top of existing pixels only where
  /// the PNG has alpha — face features remain visible.
  ///
  /// CRITICALLY NOT srcIn (which would replace face pixels with
  /// plasma and leave a faceless blob).
  Widget _withInfusion(Widget child, RewardController ctrl) {
    if (ctrl.phase != RewardPhase.infusing) return child;
    final color = _plasmaColorAt(ctrl.infusionProgress)
        .withValues(alpha: 0.55 * _infusionEnvelope(ctrl.infusionProgress));
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
      child: child,
    );
  }

  /// Linear interpolation through kPlasmaColors as t goes 0 → 1.
  Color _plasmaColorAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final segmentCount = kPlasmaColors.length - 1;
    final scaled = clamped * segmentCount;
    final idx = scaled.floor().clamp(0, segmentCount - 1);
    final frac = scaled - idx;
    return Color.lerp(kPlasmaColors[idx], kPlasmaColors[idx + 1], frac)!;
  }

  /// Envelope — fade in over first 30% of infusion, hold, fade out
  /// over last 30%. Avoids jumpy alpha at phase boundaries.
  double _infusionEnvelope(double t) {
    if (t < 0.3) return t / 0.3;
    if (t > 0.7) return (1.0 - t) / 0.3;
    return 1.0;
  }
}

/// Internal — a HologramAvatar variant with caller-supplied
/// gradient stops. Used only during the ascending reward phase
/// to animate the guillotine from feet-fade to head-fade.
///
/// Uses BlendMode.dstIn (same as HologramAvatar) — keeps
/// destination pixels, uses source alpha for the fade. No srcIn,
/// no nesting with the rest of the reward layers.
class _CustomGuillotineAvatar extends StatelessWidget {
  final String avatarPath;
  final double size;
  final List<double> stops;

  const _CustomGuillotineAvatar({
    required this.avatarPath,
    required this.size,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00000000),
          ],
          stops: stops,
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        avatarPath,
        fit: BoxFit.contain,
        width: size,
        height: size,
      ),
    );
  }
}
