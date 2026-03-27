import 'dart:convert';
import 'dart:typed_data';

import 'package:hello_engine/src/transport/dto/message_envelope.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when a server API call fails.
class ApiException implements Exception {
  /// Creates an [ApiException].
  const ApiException(this.statusCode, this.body);

  /// HTTP status code from the server.
  final int statusCode;

  /// Response body (typically JSON with an `error` key).
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Wraps all server interactions for the chat engine.
///
/// Uses the Next.js API routes via direct HTTP for key management and
/// messaging, and Supabase PostgREST for direct table queries where
/// appropriate.
class SupabaseClientWrapper {
  /// Creates a [SupabaseClientWrapper].
  ///
  /// [client] is the Supabase client for PostgREST / Storage / Realtime.
  /// [apiBaseUrl] is the server base URL for `/api/*` routes
  /// (the Next.js backend).
  SupabaseClientWrapper({
    required SupabaseClient client,
    required String apiBaseUrl,
    http.Client? httpClient,
  })  : _client = client,
        _apiBaseUrl = apiBaseUrl.endsWith('/')
            ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
            : apiBaseUrl,
        _httpClient = httpClient ?? http.Client();

  final SupabaseClient _client;
  final String _apiBaseUrl;
  final http.Client _httpClient;

  /// JWT auth token used for all API requests. Set this before making
  /// any authenticated call.
  String? authToken;

  /// The underlying Supabase client (exposed for Realtime and Storage).
  SupabaseClient get supabaseClient => _client;

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// POST to a `/api/*` route on the Next.js backend.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_apiBaseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'data': decoded};
  }

  // ---------------------------------------------------------------------------
  // Key Management
  // ---------------------------------------------------------------------------

  /// Uploads an identity key bundle for the given device.
  ///
  /// Calls `POST /api/keys/bundle`.
  Future<void> uploadKeyBundle({
    required int deviceId,
    required String identityKey,
    required String signedPreKey,
    required int signedPreKeyId,
    required String preKeySig,
  }) async {
    await _post('/api/keys/bundle', <String, dynamic>{
      'device_id': deviceId,
      'identity_key': identityKey,
      'signed_pre_key': signedPreKey,
      'signed_pre_key_id': signedPreKeyId,
      'pre_key_sig': preKeySig,
    });
  }

  /// Uploads a batch of one-time pre-keys.
  ///
  /// Calls `POST /api/keys/otk`. Maximum 200 keys per call.
  Future<Map<String, dynamic>> uploadOTKs({
    required int deviceId,
    required List<Map<String, String>> keys,
  }) async {
    return _post('/api/keys/otk', <String, dynamic>{
      'device_id': deviceId,
      'keys': keys,
    });
  }

  /// Fetches a peer's key bundle (with atomic OTK consumption).
  ///
  /// Calls `POST /api/keys/fetch`.
  Future<Map<String, dynamic>> fetchPeerKeyBundle({
    required String userId,
    required int deviceId,
  }) async {
    return _post('/api/keys/fetch', <String, dynamic>{
      'user_id': userId,
      'device_id': deviceId,
    });
  }

  /// Returns the number of remaining OTKs for a device via PostgREST.
  Future<int> getOTKCount({
    required String userId,
    required int deviceId,
  }) async {
    final response = await _client
        .from('one_time_pre_keys')
        .select()
        .eq('user_id', userId)
        .eq('device_id', deviceId)
        .count(CountOption.exact);

    return response.count;
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// Sends an encrypted message envelope.
  ///
  /// Calls `POST /api/message`.
  Future<Map<String, dynamic>> sendMessage(MessageEnvelope envelope) async {
    return _post('/api/message', envelope.toJson());
  }

  /// Fetches ciphertext rows for a given message via PostgREST.
  Future<List<Map<String, dynamic>>> fetchCiphertexts(
    String messageId,
  ) async {
    final response = await _client
        .from('message_ciphertexts')
        .select()
        .eq('message_id', messageId);

    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  /// Fetches message history for a space, ordered by creation time.
  ///
  /// Optionally filters messages created after [after]. Returns at most
  /// [limit] rows.
  Future<List<Map<String, dynamic>>> fetchMessageHistory(
    String groupId, {
    DateTime? after,
    int limit = 50,
  }) async {
    var query = _client.from('messages').select().eq('group_id', groupId);

    if (after != null) {
      query = query.gt('created_at', after.toIso8601String());
    }

    final response = await query.order('created_at').limit(limit);
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  /// Finds or creates a 1:1 conversation with a peer.
  ///
  /// Calls `POST /api/chat/start`.
  Future<String> findOrCreateChat(String peerId) async {
    final result = await _post('/api/chat/start', <String, dynamic>{
      'peer_id': peerId,
    });
    return result['group_id'] as String;
  }

  // ---------------------------------------------------------------------------
  // Space management
  // ---------------------------------------------------------------------------

  /// Returns the list of member records for a space.
  Future<List<Map<String, dynamic>>> getSpaceMembers(String groupId) async {
    final response = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId);

    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  /// Checks whether a tombstone exists for the given space that is newer
  /// than [senderKeyCreatedAt], indicating the Sender Key must be rotated.
  Future<bool> checkTombstone(
    String groupId,
    DateTime senderKeyCreatedAt,
  ) async {
    final response = await _client
        .from('group_tombstones')
        .select()
        .eq('group_id', groupId)
        .gt('created_at', senderKeyCreatedAt.toIso8601String())
        .limit(1);

    final rows = response as List<dynamic>;
    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Contacts
  // ---------------------------------------------------------------------------

  /// Discovers which phone numbers are registered on the platform.
  ///
  /// Calls `POST /api/contacts/check`. Maximum 500 phones per call.
  Future<List<Map<String, dynamic>>> discoverContacts(
    List<String> phones,
  ) async {
    final result = await _post('/api/contacts/check', <String, dynamic>{
      'phones': phones,
    });
    final registered = result['registered'];
    if (registered is List<dynamic>) {
      return List<Map<String, dynamic>>.from(registered);
    }
    return <Map<String, dynamic>>[];
  }

  // ---------------------------------------------------------------------------
  // Push Tokens
  // ---------------------------------------------------------------------------

  /// Updates the FCM/APNs push token for the current device.
  ///
  /// Calls `POST /api/push/token`.
  Future<void> updatePushToken(String token) async {
    await _post('/api/push/token', <String, dynamic>{
      'token': token,
    });
  }

  // ---------------------------------------------------------------------------
  // Media / Storage
  // ---------------------------------------------------------------------------

  /// Uploads an encrypted binary blob to Supabase Storage.
  ///
  /// Returns the path that was written.
  Future<String> uploadEncryptedBlob(
    Uint8List encryptedBytes,
    String bucket,
    String path,
  ) async {
    return _client.storage.from(bucket).uploadBinary(path, encryptedBytes);
  }

  /// Downloads an encrypted binary blob from Supabase Storage.
  Future<Uint8List> downloadEncryptedBlob(
    String bucket,
    String path,
  ) async {
    return _client.storage.from(bucket).download(path);
  }

  /// Deletes a blob from Supabase Storage.
  Future<void> deleteBlob(String bucket, String path) async {
    await _client.storage.from(bucket).remove([path]);
  }

  /// Creates a signed download URL valid for [expiresInSeconds].
  Future<String> createSignedUrl(
    String bucket,
    String path, {
    int expiresInSeconds = 3600,
  }) async {
    return _client.storage.from(bucket).createSignedUrl(
          path,
          expiresInSeconds,
        );
  }

  /// Releases resources held by the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
