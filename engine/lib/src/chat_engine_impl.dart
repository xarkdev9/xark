import 'dart:async';

import 'package:chat_engine/src/chat_session_impl.dart';
import 'package:chat_engine/src/crypto/keys/key_store.dart';
import 'package:chat_engine/src/crypto/sender_keys/group_cipher.dart';
import 'package:chat_engine/src/crypto/sender_keys/sender_key_store.dart';
import 'package:chat_engine/src/domain/models/chat_engine_error.dart';
import 'package:chat_engine/src/domain/models/connection_state.dart';
import 'package:chat_engine/src/domain/models/contact_match.dart';
import 'package:chat_engine/src/domain/models/conversation.dart';
import 'package:chat_engine/src/domain/repositories/conversation_repository.dart';
import 'package:chat_engine/src/domain/repositories/message_repository.dart';
import 'package:chat_engine/src/domain/repositories/receipt_repository.dart';
import 'package:chat_engine/src/domain/use_cases/delete_message_use_case.dart';
import 'package:chat_engine/src/domain/use_cases/mark_read_use_case.dart';
import 'package:chat_engine/src/domain/use_cases/send_message_use_case.dart';
import 'package:chat_engine/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:chat_engine/src/persistence/repositories/outbox_repository.dart';
import 'package:chat_engine/src/public_api/chat_engine.dart';
import 'package:chat_engine/src/public_api/chat_engine_config.dart';
import 'package:chat_engine/src/public_api/chat_session.dart';
import 'package:chat_engine/src/sync/sync_coordinator.dart';
import 'package:chat_engine/src/transport/realtime_listener.dart';
import 'package:chat_engine/src/transport/supabase_client.dart';
import 'package:chat_engine/src/persistence/database/database_factory.dart';
import 'package:chat_engine/src/persistence/repositories/message_repository_impl.dart';
import 'package:chat_engine/src/persistence/repositories/conversation_repository_impl.dart';
import 'package:chat_engine/src/persistence/repositories/receipt_repository_impl.dart';
import 'package:chat_engine/src/persistence/repositories/outbox_repository_impl.dart';
import 'package:chat_engine/src/persistence/repositories/decrypted_message_repository_impl.dart';
import 'package:chat_engine/src/crypto/keys/key_store_impl.dart';
import 'package:chat_engine/src/crypto/keys/key_types.dart';
import 'package:chat_engine/src/sync/outbox_processor.dart';
import 'package:chat_engine/src/sync/gap_detector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level engine implementation.
///
/// Owns all repositories, use cases, and the sync coordinator.
/// External code interacts via [getSession], stream properties,
/// and lifecycle methods ([suspend], [resume], [dispose]).
class ChatEngineImpl implements ChatEngine {
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
    final db = await DatabaseFactory.create();

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
    final senderKeyStoreImpl = _InMemorySenderKeyStore();
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
    final syncCoordinator = SyncCoordinator(
      outboxProcessor: outboxProcessor,
      gapDetector: gapDetector,
      realtimeListener: realtimeListener,
      receiptRepo: receiptRepo,
    );

    // 6. Assemble engine.
    return ChatEngineImpl._(
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

  final Map<String, ChatSessionImpl> _sessions = <String, ChatSessionImpl>{};

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
  ChatSession getSession(String conversationId) {
    return _sessions.putIfAbsent(
      conversationId,
      () => ChatSessionImpl(
        conversationId: conversationId,
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
  }


  @override
  Future<void> resume() async {
    if (!_connectionController.isClosed) {
      _connectionController.add(EngineConnectionState.connecting);
    }

    final conversations = await _conversationRepo.getAllConversations();
    final spaceIds = conversations.map((c) => c.id).toList();
    await _syncCoordinator.onConnected(spaceIds);

    if (!_connectionController.isClosed) {
      _connectionController.add(EngineConnectionState.connected);
    }
  }

  @override
  Future<void> dispose() async {
    _sessions.clear();
    await _syncCoordinator.dispose();
    _apiClient.dispose();
    await _errorController.close();
    await _connectionController.close();
  }
}

/// In-memory [SenderKeyStore] for bootstrapping.
/// TODO: Replace with a drift-backed implementation for persistence.
class _InMemorySenderKeyStore implements SenderKeyStore {
  final _store = <String, SenderKeyRecord>{};

  String _key(String groupId, String senderId) => '$groupId:$senderId';

  @override
  Future<void> storeSenderKey(
    String groupId, String senderId, SenderKeyRecord record,
  ) async {
    _store[_key(groupId, senderId)] = record;
  }

  @override
  Future<SenderKeyRecord?> loadSenderKey(
    String groupId, String senderId,
  ) async {
    return _store[_key(groupId, senderId)];
  }

  @override
  Future<void> deleteSenderKey(
    String groupId, String senderId,
  ) async {
    _store.remove(_key(groupId, senderId));
  }
}
