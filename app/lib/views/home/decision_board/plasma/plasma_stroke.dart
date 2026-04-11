import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces `Border.all(color: HelloColors.accent, width: w)` with an
/// animated plasma stroke painted via [CustomPaint.foregroundPainter].
/// The child renders normally inside the painted stroke.
class PlasmaStroke extends StatelessWidget {
  final Widget child;
  final double width;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  const PlasmaStroke({
    super.key,
    required this.child,
    required this.width,
    required this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          foregroundPainter: _PlasmaStrokePainter(
            gradient: buildPlasmaGradient(phase.value),
            strokeWidth: width,
            borderRadius: borderRadius,
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        );
      },
    );
  }
}

class _PlasmaStrokePainter extends CustomPainter {
  final LinearGradient gradient;
  final double strokeWidth;
  final BorderRadius borderRadius;

  _PlasmaStrokePainter({
    required this.gradient,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    // Deflate by half the stroke width so the stroke sits inside the
    // shape's bounds — matches how Flutter's Border paints.
    final RRect rrect = borderRadius
        .toRRect(rect)
        .deflate(strokeWidth / 2);
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _PlasmaStrokePainter old) =>
      old.gradient != gradient ||
      old.strokeWidth != strokeWidth ||
      old.borderRadius != borderRadius;
}
