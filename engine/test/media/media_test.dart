// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/media/media_crypto.dart';
import 'package:e2ee_chat_sdk/src/domain/models/chat_engine_error.dart';
import 'package:e2ee_chat_sdk/src/domain/models/media_metadata.dart';
import 'package:e2ee_chat_sdk/src/domain/models/media_payload.dart';
import 'package:e2ee_chat_sdk/src/media/download_manager.dart';
import 'package:e2ee_chat_sdk/src/media/media_cache.dart';
import 'package:e2ee_chat_sdk/src/media/upload_manager.dart';
import 'package:e2ee_chat_sdk/src/media/upload_progress.dart';
import 'package:e2ee_chat_sdk/src/observer/chat_engine_observer.dart';
import 'package:e2ee_chat_sdk/src/transport/media_upload_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaUploadClient extends Mock implements MediaUploadClient {}

class TestObserver extends ChatEngineObserver {
  String? lastMediaUploadId;
  int? lastMediaUploadBytes;
  Duration? lastMediaUploadElapsed;
  int mediaUploadCallCount = 0;

  String? lastMediaDownloadId;
  int? lastMediaDownloadBytes;
  Duration? lastMediaDownloadElapsed;
  int mediaDownloadCallCount = 0;

  @override
  void onMediaUpload(String mediaId, int bytes, Duration elapsed) {
    lastMediaUploadId = mediaId;
    lastMediaUploadBytes = bytes;
    lastMediaUploadElapsed = elapsed;
    mediaUploadCallCount++;
  }

  @override
  void onMediaDownload(String mediaId, int bytes, Duration elapsed) {
    lastMediaDownloadId = mediaId;
    lastMediaDownloadBytes = bytes;
    lastMediaDownloadElapsed = elapsed;
    mediaDownloadCallCount++;
  }
}

void main() {
  late MockMediaUploadClient mockClient;
  late TestObserver testObserver;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockClient = MockMediaUploadClient();
    testObserver = TestObserver();
  });

  group('UploadManager', () {
    test('encrypts and uploads, yielding correct progress phases', () async {
      final payload = MediaPayload(
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        mimeType: 'image/png',
        fileName: 'test.png',
      );

      when(
        () => mockClient.uploadEncryptedBlob(any(), any()),
      ).thenAnswer((_) async => 'https://storage.example.com/blob');

      final manager = UploadManager(
        mediaClient: mockClient,
        observer: testObserver,
      );

      final events = await manager.upload(payload, 'space-1').toList();

      expect(events.length, 3);
      expect(events[0].phase, UploadPhase.encrypting);
      expect(events[0].totalBytes, 5);
      expect(events[1].phase, UploadPhase.uploading);
      expect(events[2].phase, UploadPhase.done);
      expect(events[2].downloadUrl, 'https://storage.example.com/blob');
      expect(events[2].mediaMetadata, isNotNull);
      expect(events[2].mediaMetadata!.mimeType, 'image/png');
      expect(events[2].mediaMetadata!.sizeBytes, 5);
      expect(events[2].mediaMetadata!.encryptedKey, isNotNull);
      expect(events[2].mediaMetadata!.iv, isNotNull);
      expect(events[2].mediaMetadata!.sha256Hash, isNotNull);

      expect(testObserver.mediaUploadCallCount, 1);
      expect(testObserver.lastMediaUploadBytes, 5);
    });

    test('generates separate thumbnail key', () async {
      final payload = MediaPayload(
        bytes: Uint8List.fromList([10, 20, 30]),
        mimeType: 'image/jpeg',
        fileName: 'photo.jpg',
        thumbnailBytes: Uint8List.fromList([1, 2]),
      );

      when(
        () => mockClient.uploadEncryptedBlob(any(), any()),
      ).thenAnswer((_) async => 'https://storage.example.com/blob');

      final manager = UploadManager(mediaClient: mockClient);

      final events = await manager.upload(payload, 'space-2').toList();
      final metadata = events.last.mediaMetadata!;

      expect(metadata.thumbnailUrl, isNotNull);
      expect(metadata.thumbnailKey, isNotNull);
      expect(metadata.thumbnailIv, isNotNull);
      // Thumbnail key must differ from main key.
      expect(metadata.thumbnailKey, isNot(equals(metadata.encryptedKey)));

      // Two uploads: main + thumbnail.
      verify(
        () => mockClient.uploadEncryptedBlob(any(), any()),
      ).called(2);
    });

    test('cancel stops upload after encryption phase', () async {
      final payload = MediaPayload(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'application/octet-stream',
        fileName: 'data.bin',
      );

      final manager = UploadManager(mediaClient: mockClient);

      // Listen to the first event and cancel immediately.
      final events = <UploadProgress>[];
      await for (final event in manager.upload(payload, 'space-3')) {
        events.add(event);
        if (event.phase == UploadPhase.encrypting) {
          manager.cancel(event.mediaId);
        }
      }

      // Only the encrypting phase should have been emitted.
      expect(events.length, 1);
      expect(events[0].phase, UploadPhase.encrypting);

      // No upload should have occurred.
      verifyNever(() => mockClient.uploadEncryptedBlob(any(), any()));
    });

    test('sets inline thumbnail for backwards compat', () async {
      final thumbBytes = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final payload = MediaPayload(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'image/png',
        fileName: 'img.png',
        thumbnailBytes: thumbBytes,
      );

      when(
        () => mockClient.uploadEncryptedBlob(any(), any()),
      ).thenAnswer((_) async => 'https://cdn.example.com/blob');

      final manager = UploadManager(mediaClient: mockClient);
      final events = await manager.upload(payload, 'space-4').toList();
      final metadata = events.last.mediaMetadata!;

      expect(metadata.inlineThumbnail, base64Encode(thumbBytes));
    });
  });

  group('DownloadManager', () {
    /// Helper: encrypts plaintext and returns [MediaMetadata] with the
    /// correct key, IV, and hash.
    Future<(MediaMetadata, Uint8List)> prepareMetadata(
      Uint8List plaintext, {
      String mediaId = 'media-123',
    }) async {
      final key = await MediaCrypto.generateMediaKey();
      final encrypted = await MediaCrypto.encrypt(plaintext, key);
      final hash = await MediaCrypto.computeSha256(encrypted);

      final metadata = MediaMetadata(
        mediaId: mediaId,
        mimeType: 'image/png',
        sizeBytes: plaintext.length,
        downloadUrl: 'media/$mediaId',
        encryptedKey: base64Encode(key.key),
        iv: base64Encode(key.iv),
        sha256Hash: base64Encode(hash),
      );

      return (metadata, encrypted);
    }

    test('downloads, verifies hash, and decrypts correctly', () async {
      final plaintext = Uint8List.fromList([10, 20, 30, 40, 50]);
      final (metadata, encrypted) = await prepareMetadata(plaintext);

      when(
        () => mockClient.downloadEncryptedBlob(any()),
      ).thenAnswer((_) async => encrypted);

      final manager = DownloadManager(
        mediaClient: mockClient,
        observer: testObserver,
      );

      final events = await manager.download(metadata).toList();

      expect(events.length, 4);
      expect(events[0].phase, DownloadPhase.downloading);
      expect(events[1].phase, DownloadPhase.verifying);
      expect(events[2].phase, DownloadPhase.decrypting);
      expect(events[3].phase, DownloadPhase.done);

      // Check that decrypted bytes are cached.
      final cached = manager.getCachedBytes('media-123');
      expect(cached, isNotNull);
      expect(cached, plaintext);

      expect(testObserver.mediaDownloadCallCount, 1);
      expect(testObserver.lastMediaDownloadId, 'media-123');
      expect(testObserver.lastMediaDownloadBytes, 5);
    });

    test('rejects hash mismatch with MediaDecryptionFailed', () async {
      final plaintext = Uint8List.fromList([1, 2, 3]);
      final key = await MediaCrypto.generateMediaKey();
      final encrypted = await MediaCrypto.encrypt(plaintext, key);

      // Use a wrong hash.
      final wrongHash = base64Encode(Uint8List(32));

      final metadata = MediaMetadata(
        mediaId: 'media-bad-hash',
        mimeType: 'image/png',
        sizeBytes: plaintext.length,
        downloadUrl: 'media/media-bad-hash',
        encryptedKey: base64Encode(key.key),
        iv: base64Encode(key.iv),
        sha256Hash: wrongHash,
      );

      when(
        () => mockClient.downloadEncryptedBlob(any()),
      ).thenAnswer((_) async => encrypted);

      final manager = DownloadManager(mediaClient: mockClient);

      expect(
        () => manager.download(metadata).toList(),
        throwsA(isA<MediaDecryptionFailed>()),
      );
    });

    test('serves from cache on second call', () async {
      final plaintext = Uint8List.fromList([5, 10, 15]);
      final (metadata, encrypted) = await prepareMetadata(plaintext);

      when(
        () => mockClient.downloadEncryptedBlob(any()),
      ).thenAnswer((_) async => encrypted);

      final manager = DownloadManager(mediaClient: mockClient);

      // First download -- hits the network.
      await manager.download(metadata).toList();

      // Second download -- should come from cache.
      final events = await manager.download(metadata).toList();

      expect(events.length, 1);
      expect(events[0].phase, DownloadPhase.done);
      expect(events[0].bytesProcessed, plaintext.length);

      // Only one network call should have been made.
      verify(
        () => mockClient.downloadEncryptedBlob(any()),
      ).called(1);
    });

    test('throws on missing download URL', () async {
      final metadata = MediaMetadata(
        mediaId: 'no-url',
        mimeType: 'image/png',
        sizeBytes: 100,
      );

      final manager = DownloadManager(mediaClient: mockClient);

      expect(
        () => manager.download(metadata).toList(),
        throwsA(isA<MediaDownloadFailed>()),
      );
    });

    test('throws when key or IV is missing', () async {
      final plaintext = Uint8List.fromList([1, 2, 3]);
      final key = await MediaCrypto.generateMediaKey();
      final encrypted = await MediaCrypto.encrypt(plaintext, key);

      // Metadata without key/IV.
      final metadata = MediaMetadata(
        mediaId: 'no-key',
        mimeType: 'image/png',
        sizeBytes: plaintext.length,
        downloadUrl: 'media/no-key',
      );

      when(
        () => mockClient.downloadEncryptedBlob(any()),
      ).thenAnswer((_) async => encrypted);

      final manager = DownloadManager(mediaClient: mockClient);

      expect(
        () => manager.download(metadata).toList(),
        throwsA(isA<MediaDecryptionFailed>()),
      );
    });
  });

  group('MediaCache', () {
    test('LRU eviction: adding maxItems+1 items evicts the first', () {
      final cache = MediaCache(maxItems: 5);

      for (var i = 0; i < 6; i++) {
        cache.put('item-$i', Uint8List.fromList([i]));
      }

      expect(cache.length, 5);
      expect(cache.get('item-0'), isNull);
      expect(cache.get('item-1'), isNotNull);
      expect(cache.get('item-5'), isNotNull);
    });

    test('get moves item to MRU position', () {
      final cache = MediaCache(maxItems: 3)
        ..put('a', Uint8List.fromList([1]))
        ..put('b', Uint8List.fromList([2]))
        ..put('c', Uint8List.fromList([3]))
        ..get('a')
        ..put('d', Uint8List.fromList([4]));

      expect(cache.get('b'), isNull);
      expect(cache.get('a'), isNotNull);
      expect(cache.get('c'), isNotNull);
      expect(cache.get('d'), isNotNull);
    });

    test('clear removes all entries', () {
      final cache = MediaCache()
        ..put('x', Uint8List.fromList([1]))
        ..put('y', Uint8List.fromList([2]));

      expect(cache.length, 2);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('x'), isNull);
      expect(cache.get('y'), isNull);
    });

    test('put with same key updates position', () {
      final cache = MediaCache(maxItems: 3)
        ..put('a', Uint8List.fromList([1]))
        ..put('b', Uint8List.fromList([2]))
        ..put('c', Uint8List.fromList([3]))
        ..put('a', Uint8List.fromList([10]))
        ..put('d', Uint8List.fromList([4]));

      expect(cache.get('b'), isNull);
      expect(cache.get('a'), Uint8List.fromList([10]));
      expect(cache.get('c'), isNotNull);
      expect(cache.get('d'), isNotNull);
    });

    test('remove deletes a single entry', () {
      final cache = MediaCache()
        ..put('x', Uint8List.fromList([1]))
        ..put('y', Uint8List.fromList([2]))
        ..remove('x');

      expect(cache.get('x'), isNull);
      expect(cache.get('y'), isNotNull);
      expect(cache.length, 1);
    });

    test('get returns null for non-existent key', () {
      final cache = MediaCache();
      expect(cache.get('nonexistent'), isNull);
    });
  });
}
