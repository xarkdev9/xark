// One-shot script: generates a 256×256 gaussian grayscale noise PNG.
// Used as dither overlay in ChromaticAtmosphere (prevents OLED banding).
//
// Run: cd app && dart run ../scripts/generate_dither_noise.dart
// Output: app/assets/textures/dither_noise.png

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const size = 256;
  final rng = math.Random(42); // deterministic — same output every run

  final image = img.Image(width: size, height: size, numChannels: 1);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      // Box-Muller transform → gaussian distribution centered at 128, σ≈32
      final u1 = rng.nextDouble().clamp(1e-9, 1.0);
      final u2 = rng.nextDouble();
      final z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
      final v = (128 + z * 32).clamp(0, 255).round();
      image.setPixel(x, y, img.ColorUint8.rgb(v, v, v));
    }
  }

  // Resolve path relative to cwd. Works from either repo root
  // (`app/assets/...`) or from app/ (`assets/...`).
  final cwd = Directory.current.path;
  final target = cwd.endsWith('/app')
      ? File('assets/textures/dither_noise.png')
      : File('app/assets/textures/dither_noise.png');
  target.parent.createSync(recursive: true);
  target.writeAsBytesSync(img.encodePng(image));
  print('Wrote ${target.path} — ${target.lengthSync()} bytes');
}
