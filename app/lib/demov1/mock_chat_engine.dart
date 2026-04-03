import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
// ignore: implementation_imports
import 'package:e2ee_chat_sdk/src/devices/device_registry.dart';
import 'mock_data_seed.dart';

class MockChatSession implements ChatSession {
  final String groupId;
  final BehaviorSubject<List<Message>> _messagesController = BehaviorSubject<List<Message>>();
  final BehaviorSubject<List<TypingIndicator>> _typingController = BehaviorSubject<List<TypingIndicator>>();
  final BehaviorSubject<List<Receipt>> _receiptsController = BehaviorSubject<List<Receipt>>();
  final BehaviorSubject<PresenceState> _presenceController = BehaviorSubject<PresenceState>();

  List<Message> _cache = [];

  MockChatSession(this.groupId) {
    _cache = MockDataSeed.buildMessagesFor(groupId);
    // Seed BehaviorSubjects immediately — Riverpod needs a value at subscription time
    _messagesController.add(_cache);
    _typingController.add([]);
    _receiptsController.add([]);
    _presenceController.add(PresenceState(
      userId: groupId,
      isOnline: true,
      lastSeenAt: DateTime.now(),
    ));
  }

  void pushNewInbound() {
    final newMsg = Message(
      id: 'mock_inbound_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: 'user_X',
      senderDeviceId: 'dev_1',
      type: MessageType.e2ee,
      status: MessageStatus.delivered,
      timestamp: DateTime.now(),
      text: "Yeah, totally agree. Let's do it.",
    );
    _cache.insert(0, newMsg); // reverse sorted means index 0 is newest
    _messagesController.add(List.from(_cache));
  }

  void morphTopLocalReceipt() {
    for (int i = 0; i < _cache.length; i++) {
      var m = _cache[i];
      if (m.senderId == 'me' && m.status != MessageStatus.read) {
        if (m.status == MessageStatus.sent) {
          _cache[i] = m.copyWith(status: MessageStatus.delivered);
        } else if (m.status == MessageStatus.delivered) {
          _cache[i] = m.copyWith(status: MessageStatus.read);
        }
        _messagesController.add(List.from(_cache));
        break; // Only morph one per tick
      }
    }
  }

  @override
  Stream<List<Message>> get messages => _messagesController.stream;

  @override
  Stream<List<TypingIndicator>> get typing => _typingController.stream;

  @override
  Stream<List<Receipt>> get receipts => _receiptsController.stream;

  @override
  Stream<PresenceState> get presence => _presenceController.stream;

  @override
  Future<Message> sendText(String plaintext) async {
    final m = Message(
      id: 'mock_sent_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: 'me',
      senderDeviceId: 'dev_1',
      type: MessageType.e2ee,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
      text: plaintext,
    );
    _cache.insert(0, m);
    _messagesController.add(List.from(_cache));
    return m;
  }

  @override
  Future<Message> sendMedia(MediaPayload payload) async {
    final m = Message(
      id: 'mock_media_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: 'me',
      senderDeviceId: 'dev_1',
      type: MessageType.media,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
      media: MediaMetadata(
        mediaId: 'temp_media',
        mimeType: 'image/jpeg',
        sizeBytes: 1000,
        downloadUrl: 'https://images.unsplash.com/photo-1542314831-c6a4d27ce66b?q=80&w=800&auto=format&fit=crop',
      ),
    );
    _cache.insert(0, m);
    _messagesController.add(List.from(_cache));
    return m;
  }

  @override
  Future<void> sendTyping() async {}

  @override
  Future<void> markRead(String messageId) async {}

  @override
  Future<void> react(String messageId, String emoji) async {}

  @override
  Future<void> deleteForMe(String messageId) async {}

  @override
  Future<void> deleteForEveryone(String messageId) async {}

  @override
  Future<List<Message>> loadMore({int limit = 50}) async => [];

  @override
  Future<KeyFingerprint> getKeyFingerprint() async {
    return KeyFingerprint(
      userId: 'me',
      deviceId: 'dev_1',
      fingerprintBytes: Uint8List.fromList(List.generate(30, (i) => i)),
    );
  }
}

class MockChatEngine extends ChatEngine with ChatEngineDecisions {
  final Map<String, MockChatSession> _sessions = {};
  
  final BehaviorSubject<List<Conversation>> _convosController = BehaviorSubject<List<Conversation>>();
  final BehaviorSubject<EngineConnectionState> _connStateController = BehaviorSubject<EngineConnectionState>();
  final BehaviorSubject<int> _unreadController = BehaviorSubject<int>();
  final BehaviorSubject<ChatEngineError> _errorController = BehaviorSubject<ChatEngineError>();

  List<Conversation> _convoCache = [];
  final Map<String, List<DecisionItem>> _decisionCache = {};
  
  Timer? _heartbeat;

  MockChatEngine() {
    _convoCache = MockDataSeed.buildConversations();
    for (var c in _convoCache) {
      _decisionCache[c.id] = MockDataSeed.buildDecisionItemsFor(c.id);
    }
    
    Future.microtask(() {
      _connStateController.add(EngineConnectionState.connected);
      _convosController.add(_convoCache);
      _unreadController.add(_convoCache.fold(0, (sum, item) => sum + item.unreadCount));
    });

    _startHeartbeat();
  }

  void _startHeartbeat() {
    int ticks = 0;
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (timer) {
      ticks++;

      // 1. Receipt Morphing on Bali (active session)
      if (_sessions.containsKey('bali')) {
        _sessions['bali']!.morphTopLocalReceipt();
      }

      // 2. Incoming Firehose randomly
      if (ticks % 5 == 0 && _sessions.containsKey('tokyo')) {
        _sessions['tokyo']!.pushNewInbound();
        
        // Bump conversation unread
        int idx = _convoCache.indexWhere((c) => c.id == 'tokyo');
        if (idx >= 0) {
          _convoCache[idx] = _convoCache[idx].copyWith(
            unreadCount: _convoCache[idx].unreadCount + 1,
            lastMessageText: "Yeah, totally agree. Let's do it.",
            updatedAt: DateTime.now(),
          );
          _convosController.add(List.from(_convoCache));
        }
      }

      // 3. Consensus Glow: Ramp Bali Hotel score
      if (ticks % 3 == 0) {
        final items = _decisionCache['bali'];
        if (items != null) {
          int hotIdx = items.indexWhere((i) => i.id == 'item_bali_1');
          if (hotIdx >= 0) {
            double oldScore = items[hotIdx].agreementScore;
            if (oldScore < 0.85) {
              items[hotIdx] = items[hotIdx].copyWith(
                agreementScore: min(1.0, oldScore + 0.1),
              );
            }
          }
        }
      }
    });
  }

  @override
  ChatSession getSession(String groupId) {
    return _sessions.putIfAbsent(groupId, () => MockChatSession(groupId));
  }

  @override
  Stream<List<Conversation>> get conversations => _convosController.stream;

  @override
  Stream<EngineConnectionState> get connectionState => _connStateController.stream;

  @override
  Stream<int> get totalUnreadCount => _unreadController.stream;

  @override
  Stream<ChatEngineError> get errors => _errorController.stream;

  @override
  Future<UserProfile> getProfile(String userId) async {
    return UserProfile(userId: userId, displayName: 'User $userId', photoUrl: null);
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {}

  @override
  Future<List<DeviceInfo>> getDevices() async => [];

  @override
  Future<void> unlinkDevice(int deviceId) async {}

  @override
  Future<String> getDisplayName(String userId) async => 'Mock $userId';

  @override
  Future<List<ContactMatch>> discoverContacts(List<String> phoneHashes) async => [];

  @override
  Future<Conversation> createGroup({required String title, String? atmosphere}) async {
    final c = Conversation(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      type: ConversationType.group,
      participantIds: ['me'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isEncrypted: true,
    );
    _convoCache.insert(0, c);
    _convosController.add(List.from(_convoCache));
    return c;
  }

  @override
  Future<InviteLink> generateInvite() async {
    await Future.delayed(const Duration(milliseconds: 800)); // Tension physics testing
    return const InviteLink(code: 'ABCD-1234', url: 'https://xark.vercel.app/s/ABCD-1234');
  }

  @override
  Future<JoinResult> claimInvite(String code) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Tension physics
    return const JoinResult(groupId: 'new_joined_group', accessToken: 'mock_token');
  }

  @override
  Stream<HelloResponseChunk> streamHelloResponse({required String prompt, required String groupId}) async* {
    final text = "I've synthesized the opinions based on your taste graph. St. Regis is highly recommended due to the beachfront access and group preferences. Would you like me to initiate the lock?";
    final words = text.split(" ");
    for (var i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      yield HelloResponseChunk(
        text: "${words[i]} ",
        done: i == words.length - 1,
      );
    }
  }

  @override
  Future<void> updatePushToken(String newToken) async {}

  @override
  Future<void> suspend() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async {
    _heartbeat?.cancel();
  }

  // --- ChatEngineDecisions Mixin Implementation ---

  @override
  Future<List<DecisionItem>> getDecisionItems(String groupId) async {
    return _decisionCache[groupId] ?? [];
  }

  @override
  Future<void> reactToItem(String itemId, String signal) async {
    // Artificial latency for reactor feedback
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> lockItem(String itemId, CommitmentProof proof) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
