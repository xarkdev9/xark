import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Liquid plasma brand palette. Four warm colors ordered by hue so
/// each transition is a smooth walk, never a jump.
const List<Color> kPlasmaColors = <Color>[
  Color(0xFFFF0055), // vibrant magenta-red
  Color(0xFFFF0000), // pure red
  Color(0xFFFF4D00), // vivid red-orange
  Color(0xFFFF8C00), // dark neon orange
];

const List<double> kPlasmaStops = <double>[0.0, 0.33, 0.66, 1.0];

/// Shared animation cycle for every plasma surface in the app.
const Duration kPlasmaCycle = Duration(seconds: 5);

/// Builds the animated plasma gradient for a given phase in [0, 1).
///
/// The begin/end vector walks diagonally around the shape's center,
/// producing an oil-on-water sweep that never settles. [alpha] scales
/// each color's opacity while preserving hue (used for chip backgrounds
/// at ~0.18 so the plasma still breathes at lower intensity).
LinearGradient buildPlasmaGradient(double phase, {double alpha = 1.0}) {
  final double angle = 2 * math.pi * phase;
  final double dx = math.cos(angle);
  final double dy = math.sin(angle);
  final List<Color> colors = alpha >= 1.0
      ? kPlasmaColors
      : kPlasmaColors
          .map((Color c) => c.withValues(alpha: c.a * alpha))
          .toList(growable: false);
  return LinearGradient(
    colors: colors,
    stops: kPlasmaStops,
    begin: Alignment(dx - 1, dy - 1),
    end: Alignment(dx + 1, dy + 1),
  );
}
