import 'package:e2ee_chat_sdk/src/domain/models/media_metadata.dart';

/// The current phase of a media upload operation.
enum UploadPhase {
  /// Encrypting the media payload client-side (AES-256-GCM).
  encrypting,

  /// Uploading the encrypted blob to remote storage.
  uploading,

  /// Upload complete -- [UploadProgress.mediaMetadata] is available.
  done,
}

/// The current phase of a media download operation.
enum DownloadPhase {
  /// Downloading the encrypted blob from remote storage.
  downloading,

  /// Verifying the SHA-256 hash of the downloaded ciphertext.
  verifying,

  /// Decrypting the blob with AES-256-GCM.
  decrypting,

  /// Download complete -- decrypted bytes are available in cache.
  done,
}

/// Progress snapshot emitted during a media upload.
class UploadProgress {
  /// Creates an [UploadProgress].
  const UploadProgress({
    required this.mediaId,
    required this.phase,
    this.bytesProcessed = 0,
    this.totalBytes = 0,
    this.downloadUrl,
    this.mediaMetadata,
  });

  /// Unique identifier for this upload operation.
  final String mediaId;

  /// Current phase of the upload pipeline.
  final UploadPhase phase;

  /// Number of bytes processed so far.
  final int bytesProcessed;

  /// Total bytes to process (may be 0 if unknown).
  final int totalBytes;

  /// Remote download URL (set when [phase] is [UploadPhase.done]).
  final String? downloadUrl;

  /// Complete media metadata (set when [phase] is [UploadPhase.done]).
  final MediaMetadata? mediaMetadata;
}

/// Progress snapshot emitted during a media download.
class DownloadProgress {
  /// Creates a [DownloadProgress].
  const DownloadProgress({
    required this.mediaId,
    required this.phase,
    this.bytesProcessed = 0,
    this.totalBytes = 0,
  });

  /// Unique identifier for this download operation.
  final String mediaId;

  /// Current phase of the download pipeline.
  final DownloadPhase phase;

  /// Number of bytes processed so far.
  final int bytesProcessed;

  /// Total bytes to process (may be 0 if unknown).
  final int totalBytes;
}
