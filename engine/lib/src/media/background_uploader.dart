import 'dart:async';

import 'package:drift/drift.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';

/// Background media upload manager.
///
/// Encrypts via streaming AEAD, uploads in chunks, and persists progress
/// to the Drift [UploadTasks] table for resumability across app restarts
/// and force-quits.
///
/// The upload loop polls every 5 seconds and processes up to 3 tasks
/// concurrently. Each task transitions through:
///   pending -> encrypting -> uploading -> complete | failed
///
/// Actual streaming encryption (via [StreamingAead]) and Firebase Storage
/// upload are wired during the integration phase. This class provides the
/// queue infrastructure, persistence, progress tracking, retry, and cancel.

/// Upload lifecycle status.
enum UploadStatus {
  /// Queued, waiting for processing.
  pending,

  /// File is being encrypted via streaming AEAD.
  encrypting,

  /// Encrypted blob is being uploaded to remote storage.
  uploading,

  /// Upload completed successfully; download URL available.
  complete,

  /// Upload failed (retryable via [BackgroundUploader.retry]).
  failed,
}

/// Queue-based background upload manager with Drift persistence.
///
/// Usage:
/// ```dart
/// final uploader = BackgroundUploader(db: appDatabase);
/// uploader.start();
/// final mediaId = await uploader.enqueue(
///   groupId: 'group_abc',
///   localPath: '/tmp/photo.enc',
///   mimeType: 'image/jpeg',
///   totalBytes: 204800,
/// );
/// uploader.watchUpload(mediaId).listen((task) {
///   print('${task?.status}: ${task?.uploadedBytes}/${task?.totalBytes}');
/// });
/// ```
class BackgroundUploader {
  /// Creates a [BackgroundUploader] backed by the given [db].
  BackgroundUploader({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  Timer? _processTimer;
  bool _isProcessing = false;

  /// Maximum number of tasks processed per polling cycle.
  static const int maxConcurrentTasks = 3;

  /// Polling interval for the processing loop.
  static const Duration pollInterval = Duration(seconds: 5);

  /// Start the upload processing loop.
  ///
  /// Calls [processQueue] immediately, then every [pollInterval].
  void start() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(pollInterval, (_) => processQueue());
    // Immediate first run so queued tasks don't wait for the first tick.
    processQueue();
  }

  /// Stop the upload processing loop.
  ///
  /// Does not cancel in-flight uploads — it simply stops polling for new
  /// work. Call [start] to resume.
  void stop() {
    _processTimer?.cancel();
    _processTimer = null;
  }

  /// Queue a new media file for encrypted upload.
  ///
  /// Returns the generated `mediaId` which can be used to track progress
  /// via [watchUpload] or [watchAllUploads].
  Future<String> enqueue({
    required String groupId,
    required String localPath,
    required String mimeType,
    required int totalBytes,
  }) async {
    final mediaId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

    await _db.into(_db.uploadTasks).insert(
          UploadTasksCompanion(
            mediaId: Value(mediaId),
            groupId: Value(groupId),
            localPath: Value(localPath),
            mimeType: Value(mimeType),
            totalBytes: Value(totalBytes),
            status: const Value('pending'),
          ),
        );

    return mediaId;
  }

  /// Process pending and in-progress uploads.
  ///
  /// Re-entrant guard prevents overlapping runs. Picks up to
  /// [maxConcurrentTasks] tasks ordered by creation time.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final tasks = await (_db.select(_db.uploadTasks)
            ..where(
              (t) => t.status.isIn(
                [
                  UploadStatus.pending.name,
                  UploadStatus.uploading.name,
                ],
              ),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(maxConcurrentTasks))
          .get();

      for (final task in tasks) {
        await _processTask(task);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single upload task through the encrypt -> upload pipeline.
  Future<void> _processTask(UploadTaskRow task) async {
    try {
      // Step 1: Mark as encrypting.
      await _updateStatus(task.mediaId, UploadStatus.encrypting);

      // Step 2: Encrypt the file using streaming AEAD.
      // TODO(MOBILE-05): Wire StreamingAead from crypto/media/streaming_aead.dart.
      // The encrypted file and key material will be persisted to
      // encryptionKeyJson on the task row.

      // Step 3: Mark as uploading.
      await _updateStatus(task.mediaId, UploadStatus.uploading);

      // Step 4: Upload encrypted chunks to Firebase Storage.
      // TODO(MOBILE-05): Implement chunked upload with progress tracking.
      // Update uploadedBytes as chunks complete via:
      //   _updateUploadedBytes(task.mediaId, bytesUploaded);

      // Step 5: Mark complete with download URL.
      await (_db.update(_db.uploadTasks)
            ..where((t) => t.mediaId.equals(task.mediaId)))
          .write(
        UploadTasksCompanion(
          status: Value(UploadStatus.complete.name),
          uploadedBytes: Value(task.totalBytes),
          // downloadUrl: Value(remoteUrl), — set when upload completes
        ),
      );
    } catch (e) {
      await _updateStatus(task.mediaId, UploadStatus.failed);
    }
  }

  /// Update the status column for the given [mediaId].
  Future<void> _updateStatus(String mediaId, UploadStatus status) async {
    await (_db.update(_db.uploadTasks)
          ..where((t) => t.mediaId.equals(mediaId)))
        .write(UploadTasksCompanion(status: Value(status.name)));
  }

  /// Update the uploaded byte count for progress reporting.
  ///
  /// Called during chunked upload to persist progress so it survives
  /// app restart.
  Future<void> _updateUploadedBytes(String mediaId, int bytes) async {
    await (_db.update(_db.uploadTasks)
          ..where((t) => t.mediaId.equals(mediaId)))
        .write(UploadTasksCompanion(uploadedBytes: Value(bytes)));
  }

  /// Watch upload progress for a specific media item.
  ///
  /// Emits `null` if the task does not exist (e.g. after [cancel]).
  Stream<UploadTaskRow?> watchUpload(String mediaId) {
    return (_db.select(_db.uploadTasks)
          ..where((t) => t.mediaId.equals(mediaId)))
        .watchSingleOrNull();
  }

  /// Watch all active (non-terminal) uploads.
  ///
  /// Emits an updated list whenever any pending, encrypting, or uploading
  /// task changes, ordered by creation time.
  Stream<List<UploadTaskRow>> watchAllUploads() {
    return (_db.select(_db.uploadTasks)
          ..where(
            (t) => t.status.isIn([
              UploadStatus.pending.name,
              UploadStatus.encrypting.name,
              UploadStatus.uploading.name,
            ]),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Retry a previously failed upload.
  ///
  /// Resets the task status to [UploadStatus.pending] so the next
  /// [processQueue] cycle picks it up again.
  Future<void> retry(String mediaId) async {
    await _updateStatus(mediaId, UploadStatus.pending);
  }

  /// Cancel and remove an upload task.
  ///
  /// The row is deleted from the database. Any partially uploaded remote
  /// blob is orphaned (garbage collected by storage lifecycle rules).
  Future<void> cancel(String mediaId) async {
    await (_db.delete(_db.uploadTasks)
          ..where((t) => t.mediaId.equals(mediaId)))
        .go();
  }
}
