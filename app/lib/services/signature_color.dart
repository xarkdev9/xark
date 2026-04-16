import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';

import '../models/ambient_palette.dart';
import 'oklch.dart';

/// Generates a deterministic 5-color [AmbientPalette] from a string
/// seed (user ID, group ID, kind token). Uses CRC32 for a stable
/// cross-platform hash, then maps into Oklch color space for
/// perceptually uniform hue distribution.
///
/// IMPORTANT (landmine #14): uses Oklch, NOT HSL. HSL has
/// non-uniform perceived brightness across hues.
AmbientPalette signaturePalette(String seed) {
  final crc = Crc32().convert(seed.codeUnits).hashCode;

  // Base hue from CRC, distributed across full circle
  final baseHue = (crc % 360).toDouble();

  // Generate 5 hues: base, +72, +144, +216, +288 (pentagonal spread)
  final hues = List.generate(5, (i) => (baseHue + i * 72) % 360);

  // Convert Oklch → sRGB for each
  final colors = hues.map((h) {
    final rgb = oklchToSrgb(0.72, 0.12, h.toDouble());
    return Color.fromARGB(255, rgb.r, rgb.g, rgb.b);
  }).toList();

  return AmbientPalette(
    dominant: colors[0],
    vibrant: colors[1],
    muted: colors[2],
    lightAccent: colors[3],
    darkAccent: colors[4],
  );
}
