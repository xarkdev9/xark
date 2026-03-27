import 'dart:convert';
import 'dart:typed_data';

import 'package:hello_engine/src/crypto/keys/key_types.dart';
import 'package:hello_engine/src/crypto/media/media_crypto.dart';
import 'package:hello_engine/src/domain/models/chat_engine_error.dart';
import 'package:hello_engine/src/domain/models/media_metadata.dart';
import 'package:hello_engine/src/media/media_cache.dart';
import 'package:hello_engine/src/media/upload_progress.dart';
import 'package:hello_engine/src/observer/chat_engine_observer.dart';
import 'package:hello_engine/src/transport/media_upload_client.dart';

/// Manages the download-verify-decrypt pipeline for media attachments.
///
/// For each download:
/// 1. Downloads the encrypted blob from remote storage.
/// 2. Verifies the SHA-256 hash against the expected value.
/// 3. Decrypts the blob with the AES-256-GCM key from [MediaMetadata].
/// 4. Caches the decrypted bytes in an in-memory LRU cache.
class DownloadManager {
  /// Creates a [DownloadManager].
  DownloadManager({
    required MediaUploadClient mediaClient,
    MediaCache? cache,
    this.observer,
  })  : _mediaClient = mediaClient,
        _cache = cache ?? MediaCache();

  final MediaUploadClient _mediaClient;
  final MediaCache _cache;

  /// Optional observer for diagnostic callbacks.
  final ChatEngineObserver? observer;

  /// Downloads, verifies, and decrypts media described by [metadata].
  ///
  /// Yields [DownloadProgress] snapshots for each pipeline phase.
  /// Throws [MediaDownloadFailed] if no download URL is available.
  /// Throws [MediaDecryptionFailed] if the hash does not match or
  /// the key/IV is missing.
  Stream<DownloadProgress> download(MediaMetadata metadata) async* {
    final mediaId = metadata.mediaId;
    final stopwatch = Stopwatch()..start();

    // Check in-memory cache first.
    final cached = _cache.get(mediaId);
    if (cached != null) {
      yield DownloadProgress(
        mediaId: mediaId,
        phase: DownloadPhase.done,
        bytesProcessed: cached.length,
        totalBytes: cached.length,
      );
      return;
    }

    if (metadata.downloadUrl == null) {
      throw MediaDownloadFailed('No download URL for $mediaId');
    }

    // Phase 1: Downloading.
    yield DownloadProgress(
      mediaId: mediaId,
      phase: DownloadPhase.downloading,
      totalBytes: metadata.sizeBytes,
    );

    final encryptedBytes = await _mediaClient.downloadEncryptedBlob(
      metadata.downloadUrl!,
    );

    // Phase 2: Verifying hash.
    yield DownloadProgress(
      mediaId: mediaId,
      phase: DownloadPhase.verifying,
      bytesProcessed: encryptedBytes.length,
      totalBytes: metadata.sizeBytes,
    );

    if (metadata.sha256Hash != null) {
      final expectedHash = base64Decode(metadata.sha256Hash!);
      final valid = await MediaCrypto.verifySha256(
        encryptedBytes,
        Uint8List.fromList(expectedHash),
      );
      if (!valid) {
        throw const MediaDecryptionFailed('sha256-mismatch');
      }
    }

    // Phase 3: Decrypting.
    yield DownloadProgress(
      mediaId: mediaId,
      phase: DownloadPhase.decrypting,
      bytesProcessed: encryptedBytes.length,
      totalBytes: metadata.sizeBytes,
    );

    if (metadata.encryptedKey == null || metadata.iv == null) {
      throw MediaDecryptionFailed(mediaId);
    }

    final key = MediaKey(
      key: Uint8List.fromList(base64Decode(metadata.encryptedKey!)),
      iv: Uint8List.fromList(base64Decode(metadata.iv!)),
    );

    final decrypted = await MediaCrypto.decrypt(encryptedBytes, key);

    stopwatch.stop();
    observer?.onMediaDownload(mediaId, decrypted.length, stopwatch.elapsed);

    _cache.put(mediaId, decrypted);

    // Phase 4: Done.
    yield DownloadProgress(
      mediaId: mediaId,
      phase: DownloadPhase.done,
      bytesProcessed: decrypted.length,
      totalBytes: metadata.sizeBytes,
    );
  }

  /// Returns cached decrypted bytes for [mediaId], or `null`.
  Uint8List? getCachedBytes(String mediaId) => _cache.get(mediaId);
}
