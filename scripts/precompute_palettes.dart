// Build-time script: scans asset images and writes palettes.json manifest.
//
// Run: cd app && dart run ../scripts/precompute_palettes.dart
// Output: app/assets/palettes.json
//
// Format:
//   {
//     "decide/bali_beach.jpg": {
//       "dominant":    "#1a6b8f",
//       "vibrant":     "#e8b844",
//       "muted":       "#6b5a3d",
//       "lightAccent": "#a3c8d6",
//       "darkAccent":  "#0d3a4e"
//     },
//     ...
//   }

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  // Resolve scan roots relative to cwd. Works from either repo root
  // (`app/assets/...`) or from app/ (`assets/...`).
  final cwd = Directory.current.path;
  final insideApp = cwd.endsWith('/app');
  final scanDirs = insideApp
      ? ['assets/decide', 'assets/memories']
      : ['app/assets/decide', 'app/assets/memories'];
  final outPath = insideApp
      ? 'assets/palettes.json'
      : 'app/assets/palettes.json';
  // When running inside app/, the relPath prefix we strip is 'assets/'.
  // When running from repo root, the prefix is 'app/assets/'.
  final stripPrefix = insideApp ? 'assets/' : 'app/assets/';

  final result = <String, Map<String, String>>{};

  for (final dirPath in scanDirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      print('[precompute] skipping missing dir: $dirPath');
      continue;
    }
    for (final entity in dir.listSync(recursive: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') &&
          !lower.endsWith('.png') && !lower.endsWith('.webp')) continue;

      final relPath = entity.path.startsWith(stripPrefix)
          ? entity.path.substring(stripPrefix.length)
          : entity.path;
      try {
        final bytes = entity.readAsBytesSync();
        final image = img.decodeImage(bytes);
        if (image == null) {
          print('[precompute] decode failed: ${entity.path}');
          continue;
        }
        final palette = _extractPalette(image);
        result[relPath] = palette;
        print('[precompute] $relPath → ${palette['dominant']}');
      } catch (e) {
        print('[precompute] error on ${entity.path}: $e');
      }
    }
  }

  final out = File(outPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  print('\nWrote ${result.length} palettes to ${out.path}');
}

/// Lightweight palette extraction: downscale, k-means-like cluster across
/// 5 lightness bands, pick the most-saturated color from each band.
Map<String, String> _extractPalette(img.Image source) {
  // Downscale to 100×100 for speed and to dampen outliers
  final small = img.copyResize(source, width: 100, height: 100);

  // Collect pixels into 5 lightness buckets
  final buckets = List.generate(5, (_) => <_PixelHsl>[]);
  for (final px in small) {
    final hsl = _toHsl(px);
    if (hsl.s < 0.05) continue; // skip near-grayscale
    final bucketIndex = (hsl.l * 5).floor().clamp(0, 4);
    buckets[bucketIndex].add(hsl);
  }

  // Pick the most-saturated color from each bucket (fallback to avg)
  String colorOf(List<_PixelHsl> bucket, {double lFallback = 0.5}) {
    if (bucket.isEmpty) {
      return _hslToHex(0.0, 0.3, lFallback);
    }
    bucket.sort((a, b) => b.s.compareTo(a.s));
    final top = bucket.first;
    return _hslToHex(top.h, top.s, top.l);
  }

  // Overall dominant = most-saturated across all buckets
  final allPixels = buckets.expand((b) => b).toList();
  allPixels.sort((a, b) => b.s.compareTo(a.s));
  final dominant = allPixels.isEmpty
      ? _hslToHex(0.0, 0.2, 0.5)
      : _hslToHex(allPixels.first.h, allPixels.first.s, allPixels.first.l);

  return {
    'dominant':    dominant,
    'vibrant':     colorOf(buckets[3], lFallback: 0.6), // bright band
    'muted':       colorOf(buckets[2], lFallback: 0.5), // mid band
    'lightAccent': colorOf(buckets[4], lFallback: 0.8), // lightest band
    'darkAccent':  colorOf(buckets[1], lFallback: 0.3), // darker band
  };
}

class _PixelHsl {
  final double h, s, l;
  const _PixelHsl(this.h, this.s, this.l);
}

_PixelHsl _toHsl(img.Pixel px) {
  final r = px.r / 255.0;
  final g = px.g / 255.0;
  final b = px.b / 255.0;
  final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
  final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
  final l = (maxC + minC) / 2;
  if (maxC == minC) return _PixelHsl(0, 0, l);
  final d = maxC - minC;
  final s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC);
  double h;
  if (maxC == r) {
    h = ((g - b) / d) + (g < b ? 6 : 0);
  } else if (maxC == g) {
    h = ((b - r) / d) + 2;
  } else {
    h = ((r - g) / d) + 4;
  }
  h /= 6;
  return _PixelHsl(h, s, l);
}

String _hslToHex(double h, double s, double l) {
  double hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }
  double r, g, b;
  if (s == 0) {
    r = g = b = l;
  } else {
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  final ri = (r * 255).round();
  final gi = (g * 255).round();
  final bi = (b * 255).round();
  return '#${ri.toRadixString(16).padLeft(2, '0')}'
      '${gi.toRadixString(16).padLeft(2, '0')}'
      '${bi.toRadixString(16).padLeft(2, '0')}';
}
