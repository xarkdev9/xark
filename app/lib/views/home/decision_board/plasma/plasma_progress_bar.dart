import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'plasma_clock.dart';
import 'plasma_gradient.dart';

/// Replaces `LinearProgressIndicator(valueColor: HelloColors.accent)`
/// with a custom-painted rounded track whose filled portion sweeps
/// with the plasma gradient. [value] is clamped to [0, 1]. Zero-value
/// progress paints only the background track.
class PlasmaProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color backgroundColor;

  const PlasmaProgressBar({
    super.key,
    required this.value,
    this.height = 4.0,
    this.backgroundColor = const Color(0x0F1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double> phase = PlasmaClockScope.of(context);
    return ListenableBuilder(
      listenable: phase,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          size: Size(double.infinity, height),
          painter: _PlasmaProgressPainter(
            value: value.clamp(0.0, 1.0),
            gradient: buildPlasmaGradient(phase.value),
            backgroundColor: backgroundColor,
            height: height,
          ),
        );
      },
    );
  }
}

class _PlasmaProgressPainter extends CustomPainter {
  final double value;
  final LinearGradient gradient;
  final Color backgroundColor;
  final double height;

  _PlasmaProgressPainter({
    required this.value,
    required this.gradient,
    required this.backgroundColor,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = height / 2;
    final Rect trackRect = Rect.fromLTWH(0, 0, size.width, height);
    final RRect trackRRect =
        RRect.fromRectAndRadius(trackRect, Radius.circular(radius));
    canvas.drawRRect(trackRRect, Paint()..color = backgroundColor);

    if (value > 0) {
      final Rect fillRect =
          Rect.fromLTWH(0, 0, size.width * value, height);
      final RRect fillRRect =
          RRect.fromRectAndRadius(fillRect, Radius.circular(radius));
      final Paint fillPaint = Paint()
        ..shader = gradient.createShader(trackRect);
      canvas.drawRRect(fillRRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlasmaProgressPainter old) =>
      old.value != value ||
      old.gradient != gradient ||
      old.backgroundColor != backgroundColor ||
      old.height != height;
}
