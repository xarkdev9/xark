import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Oklch (Oklab in polar coordinates) — perceptually uniform color space.
///
/// Reference: Björn Ottosson, 2020 — https://bottosson.github.io/posts/oklab/
///
/// Using Oklch instead of HSL guarantees that signatures at the same
/// `l` and `c` have equal perceived brightness regardless of `h`.
/// Yellow-Sarah and Blue-Alex look equally vibrant; neither blinding
/// nor muddy.
class Oklch {
  /// Lightness, 0.0 (black) to 1.0 (white). Perceptually linear.
  final double l;

  /// Chroma, 0.0 (gray) to ~0.4 (max displayable). Perceptually linear saturation.
  final double c;

  /// Hue in radians (0 to 2π).
  final double h;

  const Oklch({required this.l, required this.c, required this.h});

  /// Convert Oklch → sRGB Color.
  Color toColor() {
    // Polar → cartesian (Oklch → Oklab)
    final a = c * math.cos(h);
    final b = c * math.sin(h);

    // Oklab → linear sRGB (Ottosson's matrix)
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

    final lCubed = l_ * l_ * l_;
    final mCubed = m_ * m_ * m_;
    final sCubed = s_ * s_ * s_;

    final rLin =  4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed;
    final gLin = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed;
    final bLin = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed;

    // Linear sRGB → gamma-encoded sRGB
    double gamma(double x) {
      if (x <= 0.0031308) return 12.92 * x;
      return 1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055;
    }

    final r = gamma(rLin).clamp(0.0, 1.0);
    final g = gamma(gLin).clamp(0.0, 1.0);
    final bOut = gamma(bLin).clamp(0.0, 1.0);

    return Color.fromRGBO(
      (r * 255).round(),
      (g * 255).round(),
      (bOut * 255).round(),
      1.0,
    );
  }
}
