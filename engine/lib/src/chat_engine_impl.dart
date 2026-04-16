import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show IsolateNameServer;

import 'package:e2ee_chat_sdk/src/chat_session_impl.dart';
import 'package:e2ee_chat_sdk/src/domain/models/commitment_proof.dart';
import 'package:e2ee_chat_sdk/src/domain/models/decision_item.dart';
import 'package:e2ee_chat_sdk/src/extensions/chat_engine_decisions.dart';
import 'package:e2ee_chat_sdk/src/domain/models/hello_response_chunk.dart';
import 'package:e2ee_chat_sdk/src/domain/models/invite_link.dart';
import 'package:e2ee_chat_sdk/src/domain/models/join_result.dart';
import 'package:http/http.dart' as http;
import 'package:e2ee_chat_sdk/src/crypto/keys/key_store.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/group_cipher.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sender_key_store.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sqlite_sender_key_store.dart';
import 'package:e2ee_chat_sdk/src/domain/models/chat_engine_error.dart';
import 'package:e2ee_chat_sdk/src/domain/models/connection_state.dart';
import 'package:e2ee_chat_sdk/src/domain/models/contact_match.dart';
import 'package:e2ee_chat_sdk/src/domain/models/conversation.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/conversation_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/message_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/receipt_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/delete_message_use_case.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/mark_read_use_case.dart';
import 'package:e2ee_chat_sdk/src/domain/use_cases/send_message_use_case.dart';
import 'package:e2ee_chat_sdk/src/media/background_uploader.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/outbox_repository.dart';
import 'package:e2ee_chat_sdk/src/public_api/chat_engine.dart';
import 'package:e2ee_chat_sdk/src/public_api/chat_engine_config.dart';
import 'package:e2ee_chat_sdk/src/public_api/chat_session.dart';
import 'package:e2ee_chat_sdk/src/sync/conflict_resolver.dart';
import 'package:e2ee_chat_sdk/src/sync/sync_coordinator.dart';
import 'package:e2ee_chat_sdk/src/transport/realtime_listener.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/database_key_manager.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/database_factory.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/message_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/conversation_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/receipt_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/outbox_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository_impl.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_store_impl.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/devices/device_registry.dart';
import 'package:e2ee_chat_sdk/src/domain/models/user_profile.dart';
import 'package:e2ee_chat_sdk/src/notifications/push_decryptor.dart';
import 'package:e2ee_chat_sdk/src/notifications/push_handler.dart';
import 'package:e2ee_chat_sdk/src/notifications/push_method_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:e2ee_chat_sdk/src/sync/outbox_processor.dart';
import 'package:e2ee_chat_sdk/src/sync/gap_detector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level engine implementation.
///
/// Owns all repositories, use cases, and the sync coordinator.
/// External code interacts via [getSession], stream properties,
/// and lifecycle methods ([suspend], [resume], [dispose]).
class ChatEngineImpl extends ChatEngine with ChatEngineDecisions {
  ChatEngineImpl._({
    required this.config,
    required KeyStore keyStore,
    required SupabaseClientWrapper apiClient,
    required MessageRepository messageRepo,
    required ConversationRepository conversationRepo,
    required ReceiptRepository receiptRepo,
    required OutboxRepository outboxRepo,
    required DecryptedMessageRepository decryptedCache,
    required SenderKeyStore senderKeyStore,
    required GroupCipher groupCipher,
    required SyncCoordinator syncCoordinator,
  })  : _keyStore = keyStore,
        _apiClient = apiClient,
        _messageRepo = messageRepo,
        _conversationRepo = conversationRepo,
        _receiptRepo = receiptRepo,
        _outboxRepo = outboxRepo,
        _decryptedCache = decryptedCache,
        _senderKeyStore = senderKeyStore,
        _groupCipher = groupCipher,
        _syncCoordinator = syncCoordinator;

  /// Creates and returns a fully initialized [ChatEngine].
  ///
  /// Opens the encrypted database, sets up the transport layer,
  /// initializes crypto key storage, and starts the sync coordinator.
  static Future<ChatEngine> initialize(ChatEngineConfig config) async {
    // 1. Initialize Supabase FIRST (must happen before any .instance access).
    try {
      await Supabase.initialize(
        url: config.serverBaseUrl.toString(),
        anonKey: config.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized — safe to ignore.
    }

    // 2. Open encrypted database.
    // Get or generate database encryption key (null on web)
    final dbKey = await DatabaseKeyManager.getOrCreateKey();
    final db = await DatabaseFactory.create(encryptionKey: dbKey);

    // 3. Build transport layer.
    final apiClient = SupabaseClientWrapper(
      client: Supabase.instance.client,
      apiBaseUrl: config.serverBaseUrl.toString(),
    )..authToken = config.authToken;

    final realtimeListener = RealtimeListener(
      client: Supabase.instance.client,
    );

    // 3. Build repositories.
    final messageRepo = MessageRepositoryImpl(db);
    final conversationRepo = ConversationRepositoryImpl(db);
    final receiptRepo = ReceiptRepositoryImpl(db);
    final outboxRepo = OutboxRepositoryImpl(db);
    final decryptedCache = DecryptedMessageRepositoryImpl(db);

    // 4. Build crypto layer.
    final keyStore = KeyStoreImpl();
    final senderKeyStoreImpl = SqliteSenderKeyStore();
    // Initialize the DB structure if it hasn't been created yet
    await senderKeyStoreImpl.initialize();
    final groupCipher = GroupCipher(store: senderKeyStoreImpl);

    // 5. Build sync layer.
    final outboxProcessor = OutboxProcessor(
      outboxRepository: outboxRepo,
      apiClient: apiClient,
    );
    final gapDetector = GapDetector(
      apiClient: apiClient,
      messageRepo: messageRepo,
    );

    // MOBILE-04: Conflict resolution after sync.
    final conflictResolver = ConflictResolver(db: db);

    // MOBILE-05: Background media upload queue.
    final backgroundUploader = BackgroundUploader(db: db);

    // MOBILE-06: Central sync coordinator.
    //
    // OutboxWorker (MOBILE-03) and WatermarkSync (MOBILE-02) require a
    // MessageGateway implementation. They are wired here as null until
    // SupabaseClientWrapper implements the MessageGateway port interface.
    // The coordinator degrades gracefully — the legacy OutboxProcessor
    // and GapDetector continue to handle those responsibilities.
    final syncCoordinator = SyncCoordinator(
      outboxProcessor: outboxProcessor,
      gapDetector: gapDetector,
      realtimeListener: realtimeListener,
      receiptRepo: receiptRepo,
      conversationRepo: conversationRepo,
      userId: config.userId,
      conflictResolver: conflictResolver,
      backgroundUploader: backgroundUploader,
    );

    // 6. Register push decryption method channel (native bridge).
    PushMethodChannel.initialize();

    // 6c. Register IsolateNameServer port for background push hand-off.
    //
    // When the FCM background handler receives a push while the main app
    // is alive (suspended in RAM), it sends the ciphertext over this port
    // instead of touching the DB. This prevents ratchet state forks.
    // The main thread decrypts atomically with its own in-memory state.
    final pushReceivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(mainEnginePortName);
    IsolateNameServer.registerPortWithName(
      pushReceivePort.sendPort,
      mainEnginePortName,
    );

    // 7. Assemble engine.
    final engine = ChatEngineImpl._(
      config: config,
      keyStore: keyStore,
      apiClient: apiClient,
      messageRepo: messageRepo,
      conversationRepo: conversationRepo,
      receiptRepo: receiptRepo,
      outboxRepo: outboxRepo,
      decryptedCache: decryptedCache,
      senderKeyStore: senderKeyStoreImpl,
      groupCipher: groupCipher,
      syncCoordinator: syncCoordinator,
    );

    // 8. Listen for push decrypt hand-offs from the background handler.
    engine._pushReceivePort = pushReceivePort;
    pushReceivePort.listen((data) {
      if (data is Map<String, dynamic>) {
        engine._handlePushDecryptHandoff(data);
      }
    });

    return engine;
  }

  /// The configuration this engine was initialized with.
  final ChatEngineConfig config;

  final KeyStore _keyStore;
  final SupabaseClientWrapper _apiClient;
  final MessageRepository _messageRepo;
  final ConversationRepository _conversationRepo;
  final ReceiptRepository _receiptRepo;
  final OutboxRepository _outboxRepo;
  final DecryptedMessageRepository _decryptedCache;
  final SenderKeyStore _senderKeyStore;
  final GroupCipher _groupCipher;
  final SyncCoordinator _syncCoordinator;

  /// ReceivePort for background push handler hand-off.
  /// Set after construction in [initialize].
  ReceivePort? _pushReceivePort;

  final Map<String, ChatSessionImpl> _sessions = <String, ChatSessionImpl>{};

  /// In-memory display name cache to avoid repeated profile lookups.
  final Map<String, String> _displayNameCache = <String, String>{};

  final StreamController<EngineConnectionState> _connectionController =
      StreamController<EngineConnectionState>.broadcast();

  SendMessageUseCase? _sendUseCase;
  MarkReadUseCase? _markReadUseCase;
  DeleteMessageUseCase? _deleteUseCase;

  SendMessageUseCase get _send => _sendUseCase ??= SendMessageUseCase(
        keyStore: _keyStore,
        apiClient: _apiClient,
        messageRepo: _messageRepo,
        conversationRepo: _conversationRepo,
        outboxRepo: _outboxRepo,
        decryptedCache: _decryptedCache,
        senderKeyStore: _senderKeyStore,
        groupCipher: _groupCipher,
        myUserId: config.userId,
        myDeviceId: config.deviceId,
        observer: config.observer,
      );

  MarkReadUseCase get _markRead => _markReadUseCase ??= MarkReadUseCase(
        messageRepo: _messageRepo,
        conversationRepo: _conversationRepo,
      );

  DeleteMessageUseCase get _delete =>
      _deleteUseCase ??= DeleteMessageUseCase(messageRepo: _messageRepo);

  @override
  ChatSession getSession(String groupId) {
    return _sessions.putIfAbsent(
      groupId,
      () => ChatSessionImpl(
        groupId: groupId,
        sendUseCase: _send,
        markReadUseCase: _markRead,
        deleteUseCase: _delete,
        messageRepo: _messageRepo,
        receiptRepo: _receiptRepo,
        syncCoordinator: _syncCoordinator,
      ),
    );
  }

  final StreamController<ChatEngineError> _errorController =
      StreamController<ChatEngineError>.broadcast();

  @override
  Stream<List<Conversation>> get conversations =>
      _conversationRepo.watchConversations();

  @override
  Stream<EngineConnectionState> get connectionState =>
      _connectionController.stream;

  @override
  Stream<int> get totalUnreadCount =>
      _conversationRepo.watchConversations().map(
            (convos) =>
                convos.fold<int>(0, (sum, c) => sum + c.unreadCount),
          );

  @override
  Stream<ChatEngineError> get errors => _errorController.stream;

  @override
  Future<List<ContactMatch>> discoverContacts(
    List<String> phoneHashes,
  ) async {
    // Delegate to the API client's contact discovery endpoint.
    // The server receives only truncated SHA-256 hashes, never raw
    // phone numbers.
    final rawMatches = await _apiClient.discoverContacts(phoneHashes);
    return rawMatches
        .map(ContactMatch.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> updatePushToken(String newToken) async {
    await _apiClient.updatePushToken(newToken);
  }

  @override
  Future<void> suspend() async {
    if (!_connectionController.isClosed) {
      _connectionController.add(EngineConnectionState.suspended);
    }

    // Stop all background sync workers (outbox, realtime, uploads).
    await _syncCoordinator.stop();
  }

  @override
  Future<void> resume() async {
    if (!_connectionController.isClosed) {
      _connectionController.add(EngineConnectionState.connecting);
    }

    // Start all background sync workers (outbox, watermark, conflict
    // resolution, realtime subscriptions, media uploads).
    await _syncCoordinator.start();

    if (!_connectionController.isClosed) {
      _connectionController.add(EngineConnectionState.connected);
    }
  }

  @override
  Future<UserProfile> getProfile(String userId) async {
    final response = await _apiClient.supabaseClient
        .from('users')
        .select('id, display_name, photo_url, phone')
        .eq('id', userId)
        .single();
    return UserProfile(
      userId: response['id'] as String,
      displayName: response['display_name'] as String? ?? userId,
      photoUrl: response['photo_url'] as String?,
      phone: response['phone'] as String?,
    );
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (photoUrl != null) updates['photo_url'] = photoUrl;
    if (updates.isNotEmpty) {
      await _apiClient.supabaseClient
          .from('users')
          .update(updates)
          .eq('id', config.userId);
    }
  }

  @override
  Future<List<DeviceInfo>> getDevices() async {
    final data = await _apiClient.getUserDevices(config.userId);
    return data.map(DeviceInfo.fromJson).toList();
  }

  @override
  Future<void> unlinkDevice(int deviceId) async {
    await _apiClient.supabaseClient
        .rpc('unlink_device', params: {'p_device_id': deviceId});
  }

  @override
  Future<String> getDisplayName(String userId) async {
    if (_displayNameCache.containsKey(userId)) {
      return _displayNameCache[userId]!;
    }
    try {
      final profile = await getProfile(userId);
      _displayNameCache[userId] = profile.displayName;
      return profile.displayName;
    } catch (_) {
      return userId; // Fallback to user ID.
    }
  }

  @override
  Future<String> findOrCreateChat(String peerId) async {
    return _apiClient.findOrCreateChat(peerId);
  }

  @override
  Future<Conversation> createGroup({
    required String title,
    String? atmosphere,
  }) async {
    final response = await _apiClient.supabaseClient
        .rpc('create_space_rpc', params: {
      'p_title': title,
      'p_atmosphere': atmosphere ?? 'cyan_horizon',
      'p_owner_id': config.userId,
    });
    // Return the newly created conversation.
    // The conversations stream will update reactively.
    return Conversation(
      id: response['group_id'] as String,
      type: ConversationType.group,
      participantIds: [config.userId],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // AI, Decision, and Invite APIs
  // ---------------------------------------------------------------------------

  @override
  Stream<HelloResponseChunk> streamHelloResponse({
    required String prompt,
    required String groupId,
  }) async* {
    try {
      final uri = config.serverBaseUrl.resolve(config.brand.aiEndpoint);
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${config.authToken}';
      request.body = jsonEncode({'prompt': prompt, 'groupId': groupId});

      final response = await http.Client().send(request);

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // Parse SSE: "data: {...}\n\n"
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final json = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            if (json['done'] == true) {
              yield const HelloResponseChunk(text: '', done: true);
              return;
            }
            if (json['error'] != null) {
              yield HelloResponseChunk(
                text: '',
                error: json['error'] as String,
              );
              return;
            }
            yield HelloResponseChunk(text: json['text'] as String? ?? '');
          }
        }
      }
    } catch (e) {
      yield HelloResponseChunk(text: '', error: e.toString());
    }
  }

  @override
  Future<List<DecisionItem>> getDecisionItems(String groupId) async {
    final response = await _apiClient.supabaseClient
        .from('decision_items')
        .select('*, reactions(*)')
        .eq('group_id', groupId)
        .order('weighted_score', ascending: false);

    final rows = response as List<dynamic>;
    return rows.map((item) {
      final reactions = <String, String>{};
      for (final r in (item['reactions'] as List<dynamic>? ?? <dynamic>[])) {
        reactions[r['user_id'] as String] = r['signal'] as String;
      }
      return DecisionItem(
        id: item['id'] as String,
        groupId: groupId,
        ciphertextPayload: item['ciphertext_payload'] as String,
        nonce: item['nonce'] as String,
        commitmentCiphertext: item['commitment_ciphertext'] as String?,
        commitmentNonce: item['commitment_nonce'] as String?,
        state: item['state'] as String? ?? 'proposed',
        weightedScore:
            (item['weighted_score'] as num?)?.toDouble() ?? 0.0,
        agreementScore:
            (item['agreement_score'] as num?)?.toDouble() ?? 0.0,
        reactions: reactions,
        isLocked: item['is_locked'] as bool? ?? false,
        proposedBy: item['proposed_by'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> reactToItem(String itemId, String signal) async {
    await _apiClient.supabaseClient.rpc(
      'upsert_reaction',
      params: {
        'p_item_id': itemId,
        'p_user_id': config.userId,
        'p_signal': signal,
      },
    );
  }



  @override
  Future<void> addDecisionItem(String groupId, {required String ciphertextPayload, required String nonce}) async {
    await _apiClient.supabaseClient.from('decision_items').insert({
      'group_id': groupId,
      'proposed_by': config.userId,
      'ciphertext_payload': ciphertextPayload,
      'nonce': nonce,
      'state': 'proposed',
      'version': 1,
    });
  }

  @override
  Future<String> decryptPayload({
    required String groupId,
    required String ciphertext,
    required String nonce,
  }) async {
    final ctBytes = base64Decode(ciphertext);
    // Use config.userId as sender fallback for now
    final result = await _groupCipher.decrypt(groupId, config.userId, ctBytes);
    return utf8.decode(result);
  }

  @override
  Future<Map<String, String>> encryptPayload({
    required String groupId,
    required String plaintext,
  }) async {
    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final result = await _groupCipher.encrypt(groupId, config.userId, plainBytes);
    return {
      'ciphertextPayload': base64Encode(result),
      'nonce': 'embedded',
    };
  }

  @override
  Future<void> lockItem(String itemId, CommitmentProof proof) async {
    await _apiClient.supabaseClient
        .from('decision_items')
        .update({
          'is_locked': true,
          'locked_at': DateTime.now().toIso8601String(),
          'commitment_proof': jsonEncode({
            'type': proof.type,
            'value': proof.value,
            'submitted_by': proof.submittedBy,
          }),
        })
        .eq('id', itemId);
  }

  @override
  Future<InviteLink> generateInvite() async {
    final uri = config.serverBaseUrl.resolve('/api/invite');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.authToken}',
      },
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return InviteLink(
      code: data['code'] as String,
      url: data['url'] as String,
    );
  }

  @override
  Future<JoinResult> claimInvite(String code) async {
    final uri = config.serverBaseUrl.resolve('/api/invite/claim');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return JoinResult(
      groupId: data['groupId'] as String,
      accessToken: data['accessToken'] as String,
    );
  }

  // ---------------------------------------------------------------------------
  // Background Push Hand-off
  // ---------------------------------------------------------------------------

  /// Handles a push decrypt request handed off from the FCM background
  /// handler via IsolateNameServer.
  ///
  /// The background handler detected that the main app is alive (suspended
  /// in RAM) and sent the ciphertext here instead of touching the database.
  /// We decrypt atomically with our in-memory ratchet state and show a
  /// local notification.
  void _handlePushDecryptHandoff(Map<String, dynamic> data) {
    // Fire-and-forget -- errors are swallowed and fallback notification shown.
    _doPushDecryptHandoff(data);
  }

  Future<void> _doPushDecryptHandoff(Map<String, dynamic> data) async {
    try {
      final payload = PushPayload.fromMap(data);
      final result = await decryptPushPayload(payload);

      // Show local notification with decrypted content or fallback.
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      await plugin.show(
        result.messageId.hashCode,
        result.senderName,
        result.messagePreview,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'e2ee_chat_messages',
            'Messages',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Swallow all errors -- never crash the main engine from push handling.
    }
  }

  @override
  Future<void> dispose() async {
    _sessions.clear();

    // Unregister the background push hand-off port.
    IsolateNameServer.removePortNameMapping(mainEnginePortName);
    _pushReceivePort?.close();
    _pushReceivePort = null;

    PushMethodChannel.dispose();
    await _syncCoordinator.dispose();
    _apiClient.dispose();
    await _errorController.close();
    await _connectionController.close();
  }
}

