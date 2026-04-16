import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/media/media_crypto.dart';
import 'package:e2ee_chat_sdk/src/domain/models/media_metadata.dart';
import 'package:e2ee_chat_sdk/src/domain/models/media_payload.dart';
import 'package:e2ee_chat_sdk/src/media/upload_progress.dart';
import 'package:e2ee_chat_sdk/src/observer/chat_engine_observer.dart';
import 'package:e2ee_chat_sdk/src/transport/media_upload_client.dart';
import 'package:uuid/uuid.dart';

/// Manages the encrypt-then-upload pipeline for media attachments.
///
/// For each upload:
/// 1. Generates a one-time AES-256-GCM key.
/// 2. Encrypts the raw bytes and (optionally) thumbnail.
/// 3. Uploads the ciphertext blobs to remote storage.
/// 4. Returns a [MediaMetadata] containing the download URL, key, IV,
///    and SHA-256 hash -- this metadata is sent through the Double
///    Ratchet as a normal E2EE message.
class UploadManager {
  /// Creates an [UploadManager].
  UploadManager({
    required MediaUploadClient mediaClient,
    this.observer,
  }) : _mediaClient = mediaClient;

  final MediaUploadClient _mediaClient;

  /// Optional observer for diagnostic callbacks.
  final ChatEngineObserver? observer;

  final _activeUploads = <String, bool>{};

  /// Encrypts and uploads [payload], yielding [UploadProgress] snapshots.
  ///
  /// [storagePath] is the prefix path in remote storage (e.g. a space ID).
  Stream<UploadProgress> upload(
    MediaPayload payload,
    String storagePath,
  ) async* {
    final mediaId = const Uuid().v4();
    _activeUploads[mediaId] = true;
    final stopwatch = Stopwatch()..start();

    // Phase 1: Encrypting.
    yield UploadProgress(
      mediaId: mediaId,
      phase: UploadPhase.encrypting,
      totalBytes: payload.bytes.length,
    );

    if (!_isActive(mediaId)) return;

    final mainKey = await MediaCrypto.generateMediaKey();
    // Run heavy symmetric encryption in a fire-and-forget isolate
    // to keep the main thread free for UI work.
    final mainKeyKey = mainKey.key;
    final mainKeyIv = mainKey.iv;
    final mainBytes = payload.bytes;
    final encryptedMain = await Isolate.run(
      () => MediaCrypto.encrypt(
        mainBytes,
        MediaKey(key: mainKeyKey, iv: mainKeyIv),
      ),
    );
    final mainHash = await MediaCrypto.computeSha256(encryptedMain);

    // Encrypt thumbnail if provided.
    Uint8List? encryptedThumb;
    Uint8List? thumbKey;
    Uint8List? thumbIv;
    String? inlineThumbnail;

    if (payload.thumbnailBytes != null && payload.thumbnailBytes!.isNotEmpty) {
      final thumbnailMediaKey = await MediaCrypto.generateMediaKey();
      thumbKey = thumbnailMediaKey.key;
      thumbIv = thumbnailMediaKey.iv;
      final thumbBytes = payload.thumbnailBytes!;
      encryptedThumb = await Isolate.run(
        () => MediaCrypto.encrypt(
          thumbBytes,
          MediaKey(key: thumbKey!, iv: thumbIv!),
        ),
      );
      inlineThumbnail = base64Encode(payload.thumbnailBytes!);
    }

    if (!_isActive(mediaId)) return;

    // Phase 2: Uploading.
    final totalUploadBytes =
        encryptedMain.length + (encryptedThumb?.length ?? 0);

    yield UploadProgress(
      mediaId: mediaId,
      phase: UploadPhase.uploading,
      totalBytes: totalUploadBytes,
    );

    final mainPath = '$storagePath/$mediaId';
    final mainUrl = await _mediaClient.uploadEncryptedBlob(
      encryptedMain,
      mainPath,
    );

    if (!_isActive(mediaId)) {
      await _mediaClient.deleteBlob(mainPath);
      return;
    }

    // Upload thumbnail if present.
    String? thumbUrl;
    if (encryptedThumb != null) {
      final thumbPath = '$storagePath/${mediaId}_thumb';
      thumbUrl = await _mediaClient.uploadEncryptedBlob(
        encryptedThumb,
        thumbPath,
      );
    }

    stopwatch.stop();
    observer?.onMediaUpload(mediaId, payload.bytes.length, stopwatch.elapsed);

    final metadata = MediaMetadata(
      mediaId: mediaId,
      mimeType: payload.mimeType,
      sizeBytes: payload.bytes.length,
      downloadUrl: mainUrl,
      encryptedKey: base64Encode(mainKey.key),
      iv: base64Encode(mainKey.iv),
      sha256Hash: base64Encode(mainHash),
      thumbnailUrl: thumbUrl,
      thumbnailKey: thumbKey != null ? base64Encode(thumbKey) : null,
      thumbnailIv: thumbIv != null ? base64Encode(thumbIv) : null,
      inlineThumbnail: inlineThumbnail,
      durationMs: payload.durationMs,
      width: payload.width,
      height: payload.height,
    );

    _activeUploads.remove(mediaId);

    // Phase 3: Done.
    yield UploadProgress(
      mediaId: mediaId,
      phase: UploadPhase.done,
      bytesProcessed: totalUploadBytes,
      totalBytes: totalUploadBytes,
      downloadUrl: mainUrl,
      mediaMetadata: metadata,
    );
  }

  /// Cancels an in-progress upload. The stream will stop yielding events.
  void cancel(String mediaId) {
    _activeUploads[mediaId] = false;
  }

  bool _isActive(String mediaId) => _activeUploads[mediaId] ?? false;
}
