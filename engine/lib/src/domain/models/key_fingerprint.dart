import 'dart:typed_data';

/// A cryptographic key fingerprint used for safety number verification.
///
/// Does not use `@freezed` because [Uint8List] does not support structural
/// equality, which would break freezed's generated `==` and `hashCode`.
class KeyFingerprint {
  /// Creates a [KeyFingerprint] instance.
  const KeyFingerprint({
    required this.userId,
    required this.deviceId,
    required this.fingerprintBytes,
  });

  /// The user who owns this key.
  final String userId;

  /// The device this key belongs to.
  final String deviceId;

  /// Raw fingerprint bytes (30 bytes).
  final Uint8List fingerprintBytes;

  /// Formats as 12 groups of 5 digits (Signal-style safety number).
  String get numericDisplay {
    final buffer = StringBuffer();
    for (var i = 0; i < 30; i += 5) {
      if (i > 0) buffer.write(' ');
      var value = 0;
      for (var j = 0; j < 5 && (i + j) < fingerprintBytes.length; j++) {
        value = (value << 8) | fingerprintBytes[i + j];
      }
      buffer.write((value % 100000).toString().padLeft(5, '0'));
    }
    return buffer.toString();
  }
}
