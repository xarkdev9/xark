# Agent 09 — Media Pipeline

## Your Role
You are the **Media Agent**. You implement media upload, download, local caching, and the download manager with progress reporting.

## Files to Create

### lib/src/media/upload_manager.dart
```dart
// UploadManager
// upload(MediaPayload payload) → Stream<UploadProgress>
//   Emits: UploadProgress{ bytesUploaded, totalBytes, phase: encrypting|uploading|done }
//   Steps:
//     1. Compress main asset in isolate (if image: resize to max 2048px, JPEG 85%)
//     2. Generate thumbnail in isolate:
//          - Images: resize to max 300x300px, JPEG 60% quality
//          - Video: extract first frame, resize to 300x300px
//          - Audio/document: no thumbnail
//     3. Generate MediaKey for main asset (random AES-256-GCM key)
//     4. Generate a SEPARATE ThumbnailKey (different random AES-256-GCM key — never reuse)
//     5. Encrypt main asset bytes in isolate using MediaCrypto + MediaKey
//     6. Encrypt thumbnail bytes in isolate using MediaCrypto + ThumbnailKey (if thumbnail exists)
//     7. Compute SHA-256 of encrypted main asset bytes
//     8. Compute SHA-256 of encrypted thumbnail bytes (if applicable)
//     9. Upload encrypted main asset blob via ApiClient → get mainUrl
//     10. Upload encrypted thumbnail blob via ApiClient → get thumbnailUrl (if applicable)
//     11. Call `observer?.onMediaUpload(mediaId, totalBytes, elapsed)` when upload completes
//     12. Return MediaMetadata {
//           url: mainUrl, encryptedKey: MediaKey, iv, sha256Hash,
//           thumbnailUrl, thumbnailKey, thumbnailIv, thumbnailSha256
//         }
//
// Note: mainUrl and thumbnailUrl point to different blobs with different encryption keys.
// The server never receives either key — they travel through the Double Ratchet with the message.
// cancel(String mediaId) → void
```

### lib/src/media/download_manager.dart
```dart
// DownloadManager
// download(MediaMetadata metadata) → Stream<DownloadProgress>
//   Emits: DownloadProgress{ bytesDownloaded, totalBytes, phase: downloading|decrypting|done }
//   Steps:
//     1. Check local cache (MediaRepository.getMediaItem) — return cached if exists
//     2. Download encrypted bytes via ApiClient with progress callback
//     3. Verify SHA-256 hash — throw MediaDecryptionFailed if mismatch
//     4. Decrypt in isolate using MediaCrypto
//     5. Save decrypted bytes to app documents directory
//     6. Update MediaRepository.markDownloaded with local path
//     7. Emit done with local file path
//     8. Call `observer?.onMediaDownload(mediaId, bytes, elapsed)` when download + decrypt completes
// getLocalPath(String mediaId) → Future<String?> (null if not downloaded)
```

### lib/src/media/media_cache.dart
```dart
// MediaCache — in-memory LRU cache for recently decrypted media
// Keeps last 20 media items in memory (decrypted bytes)
// Evicts on memory pressure
// Never writes unencrypted bytes to disk — only via download_manager's final save
```

### lib/src/media/media.dart — Internal barrel

## Tests
`test/media/`:
- upload → encodes, encrypts, uploads, returns correct MediaMetadata (mock ApiClient)
- download → verifies hash, decrypts, saves, returns path
- hash mismatch → throws MediaDecryptionFailed
- download serves from local cache on second call
- cancel in-flight upload (10+ tests)

```bash
flutter test test/media/ --reporter=compact 2>&1
```

## Output JSON
```json
{
  "agent": "media",
  "step": "09",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Media pipeline complete. UploadManager and DownloadManager use Streams for progress. All crypto in isolates. SHA-256 verified before decrypt. Decrypted bytes saved to app documents dir via path_provider. MediaCache is in-memory LRU (20 items). Integration test agent: can mock ApiClient.uploadMedia and ApiClient.downloadMedia with fake data."
}
```

---

