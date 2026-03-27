import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles encrypted media blob upload and download via Supabase Storage.
///
/// Media files are encrypted client-side (AES-256-GCM) before upload.
/// The server only ever sees ciphertext. The AES key and IV travel
/// through the Double Ratchet as part of the E2EE message payload.
class MediaUploadClient {
  /// Creates a [MediaUploadClient].
  ///
  /// [client] is the Supabase client whose Storage API is used.
  /// [bucket] is the storage bucket name for encrypted media blobs.
  MediaUploadClient({
    required SupabaseClient client,
    required String bucket,
  })  : _client = client,
        _bucket = bucket;

  final SupabaseClient _client;
  final String _bucket;

  /// Uploads an encrypted blob to Supabase Storage.
  ///
  /// [encryptedBytes] is the AES-256-GCM ciphertext.
  /// [path] is the storage object path (e.g., `media/<uuid>`).
  ///
  /// Returns the object path written (same as [path]).
  Future<String> uploadEncryptedBlob(
    Uint8List encryptedBytes,
    String path,
  ) async {
    return _client.storage.from(_bucket).uploadBinary(path, encryptedBytes);
  }

  /// Downloads an encrypted blob from Supabase Storage.
  ///
  /// Returns the raw ciphertext bytes for client-side AES-GCM decryption.
  Future<Uint8List> downloadEncryptedBlob(String path) async {
    return _client.storage.from(_bucket).download(path);
  }

  /// Deletes an encrypted blob from Supabase Storage.
  Future<void> deleteBlob(String path) async {
    await _client.storage.from(_bucket).remove([path]);
  }

  /// Creates a time-limited signed download URL.
  ///
  /// The URL grants access to the ciphertext blob; actual security comes
  /// from the AES key being E2EE-protected, not from URL secrecy.
  Future<String> createSignedUrl(
    String path, {
    int expiresInSeconds = 3600,
  }) async {
    return _client.storage.from(_bucket).createSignedUrl(
          path,
          expiresInSeconds,
        );
  }
}
