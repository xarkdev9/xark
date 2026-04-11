import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces `color: HelloColors.accent` on any `Text` or `Icon`.
/// Wraps the child in a [ShaderMask] whose shader is the plasma
/// gradient for the current phase. Works on any widget whose visible
/// pixels should receive the plasma treatment.
///
/// Uses [BlendMode.srcIn] so the mask replaces the child's pixels with
/// the plasma shader instead of blending — this is what produces the
/// "text painted in plasma" look.
class PlasmaTint extends StatelessWidget {
  final Widget child;
  const PlasmaTint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect rect) =>
              buildPlasmaGradient(phase.value).createShader(rect),
          child: child,
        );
      },
    );
  }
}
