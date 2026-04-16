import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ambient_palette.dart';
import '../theme.dart';
import 'signature_color.dart';

/// Describes a content reference whose palette should be resolved.
///
/// Priority order for resolution:
/// 1. If `photoPath` or `photoUrl` is non-null → Path A (photo extraction)
/// 2. Else if `signatureId` is non-null → Path B (signature hash)
/// 3. Else → Path C (kind token)
@immutable
class ContentRef {
  /// Asset path, e.g. "assets/decide/bali_beach.jpg".
  final String? photoPath;

  /// Network URL for a photo.
  final String? photoUrl;

  /// Stable identifier for a person or group (used for signature fallback).
  final String? signatureId;

  /// Fallback kind: 'dm', 'group', 'decision', 'settlement', 'itinerary', 'memory', 'ai'.
  final String? kind;

  const ContentRef({
    this.photoPath,
    this.photoUrl,
    this.signatureId,
    this.kind,
  });
}

/// Global service for resolving palettes.
///
/// Lifecycle:
/// - `PaletteExtractor.init()` must be called once at app startup
///   to load the asset palette manifest.
/// - `PaletteExtractor.resolve(ref)` is the only public entry point.
class PaletteExtractor {
  static Map<String, AmbientPalette> _assetManifest = {};
  static Map<String, AmbientPalette> _networkCache = {};
  static bool _initialized = false;

  static const String _networkCacheKey = 'hello.palette.network_cache.v1';
  static const int _networkCacheMaxEntries = 500;

  /// Load the build-time asset palette manifest and warm the network cache.
  /// Call once at app startup, before any atmosphere is rendered.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Asset manifest — pre-computed by scripts/precompute_palettes.dart
    try {
      final raw = await rootBundle.loadString('assets/palettes.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _assetManifest = {
        for (final entry in map.entries)
          entry.key: AmbientPalette.fromJson(entry.value as Map<String, dynamic>),
      };
    } catch (e) {
      debugPrint('[PaletteExtractor] manifest missing or invalid: $e');
      _assetManifest = {};
    }

    // Network cache — LRU-bounded, persisted across app restarts
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_networkCacheKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _networkCache = {
          for (final entry in map.entries)
            entry.key: AmbientPalette.fromJson(entry.value as Map<String, dynamic>),
        };
      }
    } catch (e) {
      debugPrint('[PaletteExtractor] network cache load failed: $e');
      _networkCache = {};
    }
  }

  /// Resolve a ContentRef to an AmbientPalette using the 3-path chain.
  ///
  /// Returns synchronously from cache when possible. Network extraction
  /// is async but returns the kind-token fallback immediately if no cache hit;
  /// when the real extraction completes it cross-fades in via provider updates.
  static Future<AmbientPalette> resolve(ContentRef ref) async {
    // Path A — asset photo
    if (ref.photoPath != null) {
      final key = ref.photoPath!.replaceFirst('assets/', '');
      final cached = _assetManifest[key] ?? _assetManifest[ref.photoPath!];
      if (cached != null) return cached;
      // Asset not in manifest — fall through to runtime extract
      return await _extractFromAsset(ref.photoPath!);
    }

    // Path A — network photo
    if (ref.photoUrl != null) {
      final cached = _networkCache[ref.photoUrl!];
      if (cached != null) return cached;
      return await _extractFromNetwork(ref.photoUrl!);
    }

    // Path B — signature
    if (ref.signatureId != null) {
      return signaturePalette(ref.signatureId!);
    }

    // Path C — kind token
    if (ref.kind != null) {
      return kindPalette(ref.kind!);
    }

    return AmbientPalette.neutral;
  }

  /// Synchronous resolve for paths B/C (used in provider derivation
  /// where async is impractical).
  static AmbientPalette resolveSync(ContentRef ref) {
    if (ref.photoPath != null) {
      final key = ref.photoPath!.replaceFirst('assets/', '');
      return _assetManifest[key]
          ?? _assetManifest[ref.photoPath!]
          ?? (ref.kind != null ? kindPalette(ref.kind!) : AmbientPalette.neutral);
    }
    if (ref.photoUrl != null) {
      return _networkCache[ref.photoUrl!]
          ?? (ref.kind != null ? kindPalette(ref.kind!) : AmbientPalette.neutral);
    }
    if (ref.signatureId != null) return signaturePalette(ref.signatureId!);
    if (ref.kind != null) return kindPalette(ref.kind!);
    return AmbientPalette.neutral;
  }

  static Future<AmbientPalette> _extractFromAsset(String assetPath) async {
    // Asset images are low-res already in most cases; still downscale to 100px
    // to guarantee <5ms extraction.
    final provider = ResizeImage(AssetImage(assetPath), width: 100, height: 100);
    final generator = await PaletteGenerator.fromImageProvider(provider);
    final palette = AmbientPalette.fromGenerator(generator);
    _assetManifest[assetPath] = palette;
    return palette;
  }

  static Future<AmbientPalette> _extractFromNetwork(String url) async {
    // CRITICAL: Must run on main isolate. dart:ui objects cannot cross
    // isolate boundaries. Downscale to 100×100 gives <5ms extraction
    // and prevents RAM spikes on 4K source images.
    final provider = ResizeImage(NetworkImage(url), width: 100, height: 100);
    final generator = await PaletteGenerator.fromImageProvider(provider);
    final palette = AmbientPalette.fromGenerator(generator);
    _networkCache[url] = palette;
    _evictOldestIfOverflow();
    unawaited(_persistNetworkCache());
    return palette;
  }

  static void _evictOldestIfOverflow() {
    if (_networkCache.length <= _networkCacheMaxEntries) return;
    // Simple LRU: iteration order is insertion order in Dart Maps.
    final overflow = _networkCache.length - _networkCacheMaxEntries;
    final keysToRemove = _networkCache.keys.take(overflow).toList();
    for (final k in keysToRemove) {
      _networkCache.remove(k);
    }
  }

  static Future<void> _persistNetworkCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        for (final entry in _networkCache.entries) entry.key: entry.value.toJson(),
      };
      await prefs.setString(_networkCacheKey, jsonEncode(json));
    } catch (e) {
      debugPrint('[PaletteExtractor] network cache persist failed: $e');
    }
  }
}

/// Pre-computed palettes for each `HelloColors.kind*` token.
/// Used as Path C fallback when no photo and no signatureId.
AmbientPalette kindPalette(String kind) {
  final base = switch (kind) {
    'dm'         => HelloColors.kindDm,
    'group'      => HelloColors.kindGroup,
    'decision'   => HelloColors.kindDecision,
    'settlement' => HelloColors.kindSettlement,
    'itinerary'  => HelloColors.kindItinerary,
    'memory'     => HelloColors.kindMemory,
    'ai'         => HelloColors.kindAiNudge,
    _            => HelloColors.accent,
  };
  // kind* colors have low alpha (0x2B or 0x1E) by design. Force full opacity
  // before building the palette so Oklch calculations are meaningful.
  final opaque = Color.fromARGB(255, (base.r * 255).round(), (base.g * 255).round(), (base.b * 255).round());
  return AmbientPalette.fromBaseColor(opaque);
}
