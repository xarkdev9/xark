import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// A 5-color palette representing a piece of content's color identity.
///
/// Sources:
/// - Path A: extracted from a photo via `palette_generator`
/// - Path B: generated from a user/group identifier via Oklch hash
/// - Path C: pre-computed per `HelloColors.kind*` token
///
/// Every AmbientPalette must expose `averageSaturation`,
/// `averageLightness`, and `averageRelativeLuminance` because
/// the surface tier decision reads these three metrics.
@immutable
class AmbientPalette {
  final Color dominant;
  final Color vibrant;
  final Color muted;
  final Color lightAccent;
  final Color darkAccent;

  const AmbientPalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.lightAccent,
    required this.darkAccent,
  });

  List<Color> get colors => [dominant, vibrant, muted, lightAccent, darkAccent];

  /// Average HSL saturation across all 5 colors (0.0 to 1.0).
  double get averageSaturation {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + HSLColor.fromColor(c).saturation);
    return sum / colors.length;
  }

  /// Average HSL lightness across all 5 colors (0.0 to 1.0).
  double get averageLightness {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + HSLColor.fromColor(c).lightness);
    return sum / colors.length;
  }

  /// Average WCAG 2.1 relative luminance across all 5 colors.
  /// 0.0 = pure black, 1.0 = pure white.
  double get averageRelativeLuminance {
    final sum = colors.fold<double>(0.0, (acc, c) => acc + c.relativeLuminance);
    return sum / colors.length;
  }

  /// Linear interpolation between two palettes. Used for cross-fade animation.
  static AmbientPalette lerp(AmbientPalette a, AmbientPalette b, double t) {
    final tt = t.clamp(0.0, 1.0);
    return AmbientPalette(
      dominant: Color.lerp(a.dominant, b.dominant, tt) ?? a.dominant,
      vibrant: Color.lerp(a.vibrant, b.vibrant, tt) ?? a.vibrant,
      muted: Color.lerp(a.muted, b.muted, tt) ?? a.muted,
      lightAccent: Color.lerp(a.lightAccent, b.lightAccent, tt) ?? a.lightAccent,
      darkAccent: Color.lerp(a.darkAccent, b.darkAccent, tt) ?? a.darkAccent,
    );
  }

  /// Neutral fallback — used before any content is focused
  /// (e.g., splash, empty auth flow, settings pages).
  static const AmbientPalette neutral = AmbientPalette(
    dominant: Color(0xFFE5E5EA),
    vibrant: Color(0xFFD1D1D6),
    muted: Color(0xFFE5E5EA),
    lightAccent: Color(0xFFF2F2F7),
    darkAccent: Color(0xFFC7C7CC),
  );

  /// Build a palette from a single base color by varying HSL lightness.
  /// Used for Path C (kind tokens).
  factory AmbientPalette.fromBaseColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    HSLColor at(double s, double l) => HSLColor.fromAHSL(1.0, hsl.hue, s, l);
    return AmbientPalette(
      dominant:    base,
      vibrant:     at((hsl.saturation + 0.1).clamp(0.0, 1.0), (hsl.lightness + 0.05).clamp(0.0, 1.0)).toColor(),
      muted:       at((hsl.saturation - 0.2).clamp(0.0, 1.0), hsl.lightness).toColor(),
      lightAccent: at(hsl.saturation, (hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor(),
      darkAccent:  at(hsl.saturation, (hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
    );
  }

  /// Build a palette from a palette_generator result.
  /// Used for Path A (photo extraction).
  factory AmbientPalette.fromGenerator(PaletteGenerator generator) {
    final dominant = generator.dominantColor?.color
                  ?? generator.colors.firstOrNull
                  ?? AmbientPalette.neutral.dominant;
    final vibrant = generator.vibrantColor?.color
                 ?? generator.lightVibrantColor?.color
                 ?? dominant;
    final muted = generator.mutedColor?.color
               ?? generator.darkMutedColor?.color
               ?? dominant;
    final lightAccent = generator.lightVibrantColor?.color
                     ?? generator.lightMutedColor?.color
                     ?? vibrant;
    final darkAccent = generator.darkVibrantColor?.color
                    ?? generator.darkMutedColor?.color
                    ?? muted;
    return AmbientPalette(
      dominant: dominant,
      vibrant: vibrant,
      muted: muted,
      lightAccent: lightAccent,
      darkAccent: darkAccent,
    );
  }

  /// Serialize to JSON (for cache + manifest).
  Map<String, String> toJson() => {
    'dominant':    _hex(dominant),
    'vibrant':     _hex(vibrant),
    'muted':       _hex(muted),
    'lightAccent': _hex(lightAccent),
    'darkAccent':  _hex(darkAccent),
  };

  /// Deserialize from JSON.
  factory AmbientPalette.fromJson(Map<String, dynamic> json) => AmbientPalette(
    dominant:    _parseHex(json['dominant'] as String),
    vibrant:     _parseHex(json['vibrant'] as String),
    muted:       _parseHex(json['muted'] as String),
    lightAccent: _parseHex(json['lightAccent'] as String),
    darkAccent:  _parseHex(json['darkAccent'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is AmbientPalette &&
      other.dominant == dominant &&
      other.vibrant == vibrant &&
      other.muted == muted &&
      other.lightAccent == lightAccent &&
      other.darkAccent == darkAccent;

  @override
  int get hashCode => Object.hash(dominant, vibrant, muted, lightAccent, darkAccent);
}

String _hex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

Color _parseHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('ff$h', radix: 16));
}

/// WCAG 2.1 relative luminance formula.
/// Returns 0.0 (black) to 1.0 (white).
extension ColorRelativeLuminance on Color {
  double get relativeLuminance {
    double gamma(double c) {
      return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
    return 0.2126 * gamma(r) + 0.7152 * gamma(g) + 0.0722 * gamma(b);
  }
}
