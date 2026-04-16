import 'dart:math' as math;

/// Oklch → sRGB conversion per Björn Ottosson (2020).
///
/// Oklch is a perceptually uniform color space where equal numerical
/// differences correspond to equal perceived color differences —
/// unlike HSL where yellow at L=0.5 reads far brighter than blue
/// at L=0.5. Used by signature_color.dart for deterministic,
/// visually balanced palette generation.
///
/// Reference: https://bottosson.github.io/posts/oklab/
({int r, int g, int b}) oklchToSrgb(double L, double C, double h) {
  final hRad = h * math.pi / 180.0;
  final a = C * math.cos(hRad);
  final b = C * math.sin(hRad);

  // Oklab → linear sRGB via the inverse of Ottosson's matrix
  final l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = L - 0.0894841775 * a - 1.2914855480 * b;

  final l = l_ * l_ * l_;
  final m = m_ * m_ * m_;
  final s = s_ * s_ * s_;

  final rLinear = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final gLinear = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final bLinear = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  int toSrgb(double c) {
    final clamped = c.clamp(0.0, 1.0);
    // Linear → sRGB gamma
    final gamma = clamped <= 0.0031308
        ? 12.92 * clamped
        : 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
    return (gamma.clamp(0.0, 1.0) * 255).round();
  }

  return (r: toSrgb(rLinear), g: toSrgb(gLinear), b: toSrgb(bLinear));
}
