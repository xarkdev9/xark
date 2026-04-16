import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces any `BoxDecoration(color: HelloColors.accent)` with an
/// animated liquid plasma fill. Rebuilds only its own subtree on each
/// plasma clock tick — the rest of the parent tree is untouched.
///
/// [alpha] scales the fill opacity while preserving the plasma hue,
/// used for tinted chip backgrounds (e.g. 0.18).
///
/// [shape] supports `BoxShape.rectangle` (default — requires
/// [borderRadius]) or `BoxShape.circle` (for dots and small badges).
class PlasmaFill extends StatelessWidget {
  final Widget? child;
  final BorderRadiusGeometry? borderRadius;
  final double alpha;
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;
  final double? width;
  final double? height;

  const PlasmaFill({
    super.key,
    this.child,
    this.borderRadius,
    this.alpha = 1.0,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: buildPlasmaGradient(phase.value, alpha: alpha),
            borderRadius:
                shape == BoxShape.rectangle ? borderRadius : null,
            shape: shape,
          ),
          child: child,
        );
      },
    );
  }
}
