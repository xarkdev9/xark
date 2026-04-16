// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/transport/media_upload_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, SupabaseStorageClient, StorageFileApi, FileObject;
import 'package:storage_client/storage_client.dart' show FileOptions;

void main() {
  // -------------------------------------------------------------------------
  // MediaUploadClient
  // -------------------------------------------------------------------------
  group('MediaUploadClient', () {
    test('uploadEncryptedBlob delegates to Storage and returns path', () async {
      const bucket = 'e2ee-media';
      const path = 'media/test-uuid';
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final fakeClient = _FakeSupabaseClientWithStorage(
        uploadResult: path,
      );

      final client = MediaUploadClient(
        client: fakeClient,
        bucket: bucket,
      );

      final result = await client.uploadEncryptedBlob(bytes, path);

      expect(result, path);
      expect(fakeClient.lastUploadBucket, bucket);
      expect(fakeClient.lastUploadPath, path);
      expect(fakeClient.lastUploadBytes, bytes);
    });

    test('downloadEncryptedBlob returns raw bytes', () async {
      final expectedBytes = Uint8List.fromList([10, 20, 30, 40]);

      final fakeClient = _FakeSupabaseClientWithStorage(
        downloadResult: expectedBytes,
      );

      final client = MediaUploadClient(
        client: fakeClient,
        bucket: 'e2ee-media',
      );

      final result = await client.downloadEncryptedBlob('media/some-file');

      expect(result, expectedBytes);
      expect(fakeClient.lastDownloadPath, 'media/some-file');
    });

    test('deleteBlob calls remove with correct path', () async {
      final fakeClient = _FakeSupabaseClientWithStorage();

      final client = MediaUploadClient(
        client: fakeClient,
        bucket: 'e2ee-media',
      );

      await client.deleteBlob('media/old-file');

      expect(fakeClient.lastDeletePaths, ['media/old-file']);
    });

    test('createSignedUrl returns URL with expiry', () async {
      final fakeClient = _FakeSupabaseClientWithStorage(
        signedUrlResult:
            'https://storage.example.com/e2ee-media/media/file?token=abc',
      );

      final client = MediaUploadClient(
        client: fakeClient,
        bucket: 'e2ee-media',
      );

      final url = await client.createSignedUrl('media/file');

      expect(url, contains('storage.example.com'));
      expect(fakeClient.lastSignedUrlPath, 'media/file');
      expect(fakeClient.lastSignedUrlExpiry, 3600);
    });

    test('createSignedUrl respects custom expiry', () async {
      final fakeClient = _FakeSupabaseClientWithStorage(
        signedUrlResult: 'https://example.com/signed',
      );

      final client = MediaUploadClient(
        client: fakeClient,
        bucket: 'e2ee-media',
      );

      await client.createSignedUrl('path', expiresInSeconds: 600);

      expect(fakeClient.lastSignedUrlExpiry, 600);
    });

    test('uses correct bucket for all operations', () async {
      final fakeClient = _FakeSupabaseClientWithStorage(
        uploadResult: 'p',
        downloadResult: Uint8List(0),
        signedUrlResult: 'url',
      );

      final client = MediaUploadClient(
        client: fakeClient,
        bucket: 'custom-bucket',
      );

      await client.uploadEncryptedBlob(Uint8List(1), 'p');
      expect(fakeClient.lastUploadBucket, 'custom-bucket');

      await client.downloadEncryptedBlob('p');
      expect(fakeClient.lastDownloadBucket, 'custom-bucket');

      await client.deleteBlob('p');
      expect(fakeClient.lastDeleteBucket, 'custom-bucket');

      await client.createSignedUrl('p');
      expect(fakeClient.lastSignedUrlBucket, 'custom-bucket');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes — use noSuchMethod to avoid signature mismatches with the
// actual Supabase SDK version. Only the methods MediaUploadClient calls
// are intercepted; everything else returns null.
// ---------------------------------------------------------------------------

class _FakeSupabaseClientWithStorage implements SupabaseClient {
  _FakeSupabaseClientWithStorage({
    this.uploadResult = '',
    this.downloadResult,
    this.signedUrlResult = '',
  });

  final String uploadResult;
  final Uint8List? downloadResult;
  final String signedUrlResult;

  String? lastUploadBucket;
  String? lastUploadPath;
  Uint8List? lastUploadBytes;

  String? lastDownloadBucket;
  String? lastDownloadPath;

  String? lastDeleteBucket;
  List<String>? lastDeletePaths;

  String? lastSignedUrlBucket;
  String? lastSignedUrlPath;
  int? lastSignedUrlExpiry;

  late final _storage = _FakeStorageClient(this);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #storage) {
      return _storage;
    }
    return null;
  }
}

class _FakeStorageClient implements SupabaseStorageClient {
  _FakeStorageClient(this._parent);
  final _FakeSupabaseClientWithStorage _parent;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Intercept .from(bucketId) call
    if (invocation.memberName == #from) {
      final bucket = invocation.positionalArguments.first as String;
      return _FakeStorageFileApi(_parent, bucket);
    }
    return null;
  }
}

class _FakeStorageFileApi implements StorageFileApi {
  _FakeStorageFileApi(this._parent, this._bucket);
  final _FakeSupabaseClientWithStorage _parent;
  final String _bucket;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;

    if (name == #uploadBinary) {
      final path = invocation.positionalArguments[0] as String;
      final data = invocation.positionalArguments[1] as Uint8List;
      _parent
        ..lastUploadBucket = _bucket
        ..lastUploadPath = path
        ..lastUploadBytes = data;
      return Future<String>.value(_parent.uploadResult);
    }

    if (name == #download) {
      final path = invocation.positionalArguments[0] as String;
      _parent
        ..lastDownloadBucket = _bucket
        ..lastDownloadPath = path;
      return Future<Uint8List>.value(_parent.downloadResult ?? Uint8List(0));
    }

    if (name == #remove) {
      final paths = invocation.positionalArguments[0] as List<String>;
      _parent
        ..lastDeleteBucket = _bucket
        ..lastDeletePaths = paths;
      return Future<List<FileObject>>.value(<FileObject>[]);
    }

    if (name == #createSignedUrl) {
      final path = invocation.positionalArguments[0] as String;
      final expiry = invocation.positionalArguments[1] as int;
      _parent
        ..lastSignedUrlBucket = _bucket
        ..lastSignedUrlPath = path
        ..lastSignedUrlExpiry = expiry;
      return Future<String>.value(_parent.signedUrlResult);
    }

    return null;
  }
}
