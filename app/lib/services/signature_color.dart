import 'dart:convert';
import 'dart:math' as math;

import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';

import '../models/ambient_palette.dart';
import 'oklch.dart';

/// Generate a deterministic AmbientPalette for a stable identifier
/// (userId, groupId). Same identifier always returns the same palette.
///
/// Uses CRC32 hashing of UTF-8 bytes for cross-platform stability
/// (Dart's String.hashCode is not stable across web vs native).
///
/// Uses Oklch color space for perceptually uniform output: every
/// identifier gets a palette with equal perceived brightness and
/// saturation, regardless of which hue it lands on.
AmbientPalette signaturePalette(String identifier) {
  final bytes = utf8.encode(identifier);
  final crc = Crc32().convert(bytes).toBigInt().toInt();
  final hueRadians = (crc.abs() % 360).toDouble() * (math.pi / 180);

  Color at(double l, double c) => Oklch(l: l, c: c, h: hueRadians).toColor();

  return AmbientPalette(
    dominant:    at(0.65, 0.12),
    vibrant:     at(0.72, 0.15),
    muted:       at(0.65, 0.06),
    lightAccent: at(0.85, 0.09),
    darkAccent:  at(0.45, 0.10),
  );
}
