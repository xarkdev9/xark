/// BlurHash generation for E2EE image placeholders.
/// Calculate a tiny base64 BlurHash BEFORE encrypting the image.
/// Send it in the plaintext envelope metadata so recipients can
/// show a beautiful blurred placeholder instantly while the
/// encrypted payload downloads in the background.

class BlurHashGenerator {
  /// Generate a BlurHash string from image bytes.
  /// The hash is ~20-30 characters and goes in plaintext metadata.
  /// Components: 4x3 gives good quality at minimal size.
  static String? generate(List<int> imageBytes,
      {int xComponents = 4, int yComponents = 3}) {
    // BlurHash encoding algorithm
    // For production: use the 'blurhash_dart' package
    // This is the integration point — the hash goes in MessageEnvelope metadata
    try {
      // TODO: Integrate blurhash_dart package for actual encoding
      // For now, return a placeholder that indicates the feature is wired
      return null;
    } catch (_) {
      return null; // BlurHash generation failure is non-fatal
    }
  }
}

/// BlurHash metadata attached to encrypted media messages.
/// This travels in the PLAINTEXT envelope (not encrypted)
/// so recipients can render the placeholder before decryption.
class BlurHashMetadata {
  final String? blurHash;
  final int width;
  final int height;

  const BlurHashMetadata(
      {this.blurHash, required this.width, required this.height});

  Map<String, dynamic> toJson() => {
        if (blurHash != null) 'blur_hash': blurHash,
        'w': width,
        'h': height,
      };

  factory BlurHashMetadata.fromJson(Map<String, dynamic> json) =>
      BlurHashMetadata(
        blurHash: json['blur_hash'] as String?,
        width: json['w'] as int? ?? 0,
        height: json['h'] as int? ?? 0,
      );
}
