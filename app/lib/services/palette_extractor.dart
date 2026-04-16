import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ambient_palette.dart';
import 'signature_color.dart';

/// Reference to content whose palette we want to extract.
/// Exactly one of [photoPath], [photoUrl], or [signatureId] should
/// be non-null. [kind] is always required (used as a fallback).
class ContentRef {
  final String? photoPath;
  final String? photoUrl;
  final String? signatureId;
  final String kind;

  const ContentRef({
    this.photoPath,
    this.photoUrl,
    this.signatureId,
    required this.kind,
  });
}

/// Main-isolate palette extraction + caching.
///
/// CRITICAL (landmine #11): palette_generator uses dart:ui objects
/// (Image, ImageProvider) that cannot cross isolate boundaries.
/// Never compute() or Isolate.spawn a PaletteGenerator call.
/// The extractor downscales via ResizeImage(100×100) so main-isolate
/// cost is bounded.
class PaletteExtractor {
  static Map<String, AmbientPalette>? _assetManifest;
  static final Map<String, AmbientPalette> _networkCache = {};
  static const int _maxNetworkCache = 500;
  static SharedPreferences? _prefs;

  /// Initialize at app startup. Loads the asset palette manifest
  /// (assets/palettes.json) and warms the network LRU cache from
  /// shared_preferences.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load bundled asset manifest
    try {
      final jsonStr = await rootBundle.loadString('assets/palettes.json');
      final Map<String, dynamic> raw = json.decode(jsonStr) as Map<String, dynamic>;
      _assetManifest = raw.map((key, value) =>
          MapEntry(key, AmbientPalette.fromJson(value as Map<String, dynamic>)));
    } catch (_) {
      _assetManifest = {};
    }

    // Warm network cache from prefs
    final cached = _prefs?.getString('palette_cache');
    if (cached != null) {
      try {
        final Map<String, dynamic> raw = json.decode(cached) as Map<String, dynamic>;
        for (final entry in raw.entries) {
          _networkCache[entry.key] =
              AmbientPalette.fromJson(entry.value as Map<String, dynamic>);
        }
      } catch (_) {}
    }
  }

  /// Resolve a ContentRef to an AmbientPalette. Three-path fallback:
  /// 1. Photo path → extract from bundled asset (manifest-cached)
  /// 2. Photo URL → extract from network image (LRU-cached)
  /// 3. Signature ID → deterministic Oklch palette from string seed
  /// 4. Kind token → AmbientPalette.fromBaseColor(kindColor)
  static Future<AmbientPalette> resolve(ContentRef ref) async {
    // Path A: bundled asset
    if (ref.photoPath != null) {
      final manifest = _assetManifest ?? {};
      if (manifest.containsKey(ref.photoPath)) {
        return manifest[ref.photoPath]!;
      }
      // Extract on-the-fly (main isolate, downscaled)
      try {
        final provider = ResizeImage(
          AssetImage(ref.photoPath!),
          width: 100,
          height: 100,
        );
        final generator = await PaletteGenerator.fromImageProvider(provider);
        final palette = AmbientPalette.fromGenerator(generator);
        return palette;
      } catch (_) {
        // Fall through to signature
      }
    }

    // Path B: network image
    if (ref.photoUrl != null) {
      if (_networkCache.containsKey(ref.photoUrl)) {
        return _networkCache[ref.photoUrl]!;
      }
      try {
        final provider = ResizeImage(
          NetworkImage(ref.photoUrl!),
          width: 100,
          height: 100,
        );
        final generator = await PaletteGenerator.fromImageProvider(provider);
        final palette = AmbientPalette.fromGenerator(generator);
        _networkCache[ref.photoUrl!] = palette;
        // Evict oldest if over limit
        while (_networkCache.length > _maxNetworkCache) {
          _networkCache.remove(_networkCache.keys.first);
        }
        // Persist to shared_preferences (fire-and-forget)
        unawaited(_persistNetworkCache());
        return palette;
      } catch (_) {
        // Fall through to signature
      }
    }

    // Path C: signature ID → Oklch deterministic palette
    if (ref.signatureId != null) {
      return signaturePalette(ref.signatureId!);
    }

    // Path D: kind token fallback
    return _kindPalette(ref.kind);
  }

  static Future<void> _persistNetworkCache() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final map = _networkCache.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString('palette_cache', json.encode(map));
  }

  static AmbientPalette _kindPalette(String kind) {
    // Map kind tokens to HelloColors.kind* values
    const kindColors = <String, Color>{
      'dm': Color(0xFF8B5CF6),
      'group': Color(0xFFF97316),
      'decision': Color(0xFFFF4D00),
      'trip': Color(0xFF4A90E2),
      'settlement': Color(0xFF8B6914),
      'itinerary': Color(0xFF14B8A6),
      'memory': Color(0xFF7C3AED),
      'ai': Color(0xFFD4536B),
    };
    final color = kindColors[kind] ?? const Color(0xFFE5E5EA);
    return AmbientPalette.fromBaseColor(color);
  }
}
