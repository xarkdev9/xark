import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_metadata.freezed.dart';
part 'media_metadata.g.dart';

/// Metadata for an encrypted media attachment.
@freezed
class MediaMetadata with _$MediaMetadata {
  /// Creates a [MediaMetadata] instance.
  const factory MediaMetadata({
    required String mediaId,
    required String mimeType,
    required int sizeBytes,
    String? downloadUrl,

    /// Base64-encoded AES-256-GCM key.
    String? encryptedKey,

    /// Base64-encoded initialization vector.
    String? iv,
    String? sha256Hash,
    String? thumbnailUrl,
    String? thumbnailKey,
    String? thumbnailIv,

    /// Base64-encoded JPEG thumbnail (backwards compat with React).
    String? inlineThumbnail,
    int? durationMs,
    int? width,
    int? height,
  }) = _MediaMetadata;

  /// Deserializes from JSON.
  factory MediaMetadata.fromJson(Map<String, dynamic> json) =>
      _$MediaMetadataFromJson(json);
}
