import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
// ignore: implementation_imports
import 'package:e2ee_chat_sdk/src/devices/device_registry.dart'; // For DeviceInfo

import '../widgets/encrypted_image_view.dart'; // For LocalDownloadProgress
import 'mock_data_seed.dart';

class MockChatEngine implements ChatEngine {
  final Map<String, MockChatSession> _sessions = {};
  final _conversationsController = StreamController<List<Conversation>>.broadcast();

  List<Conversation> _mockConversations = [];

  MockChatEngine() {
    _initSeedData();
  }

  void _initSeedData() {
    final now = DateTime.now();
    
    final aliceConv = Conversation(
      id: 'alice_1',
      type: ConversationType.oneToOne,
      participantIds: ['me', 'alice'],
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
      lastMessageId: 'a1',
      lastMessageText: 'See you tomorrow!',
      unreadCount: 0,
    );

    final horizonConv = Conversation(
      id: 'project_horizon',
      type: ConversationType.group,
      participantIds: ['me', 'sarah', 'lucy', 'tom', 'alex'],
      createdAt: now.subtract(const Duration(days: 40)),
      updatedAt: now.subtract(const Duration(seconds: 10)),
      lastMessageId: 'ph1',
      lastMessageText: 'Wow, gorgeous.',
      unreadCount: 2,
    );

    final tokyoConv = Conversation(
      id: 'tokyo_trip',
      type: ConversationType.group,
      participantIds: ['me', 'sarah'],
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
      lastMessageId: 't1',
      lastMessageText: 'Look at this view from the Andaz!',
      unreadCount: 0,
    );

    _sessions['alice_1'] = MockChatSession('alice_1', aliceConv, populateMassiveScale: true);
    _sessions['project_horizon'] = MockChatSession('project_horizon', horizonConv, populateMassiveScale: true);
    _sessions['tokyo_trip'] = MockChatSession('tokyo_trip', tokyoConv, populateMassiveScale: true);

    _mockConversations = [horizonConv, tokyoConv, aliceConv];
    _conversationsController.add(_mockConversations);
  }

  @override
  ChatSession getSession(String groupId) {
    if (!_sessions.containsKey(groupId)) {
      final fallbackConv = Conversation(
        id: groupId,
        type: ConversationType.group,
        participantIds: ['me'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _sessions[groupId] = MockChatSession(groupId, fallbackConv);
    }
    return _sessions[groupId]!;
  }

  @override
  Stream<List<Conversation>> get conversations async* {
    yield _mockConversations;
    yield* _conversationsController.stream;
  }
  
  // THE TROJAN PAYLOAD
  // Shadows the ChatEngineMediaExt extension to trick the UI into loading HTTP urls immediately.
  Stream<LocalDownloadProgress> downloadMedia(MediaMetadata metadata) async* {
    yield LocalDownloadProgress(DownloadPhase.done, metadata.downloadUrl ?? "");
  }

  @override
  Future<List<DecisionItem>> getDecisionItems(String groupId) async {
    if (groupId == 'tokyo_trip') {
      return [...MockDataSeed.tokyoHotels, ...MockDataSeed.tokyoTasks];
    } else if (groupId == 'project_horizon') {
      return [...MockDataSeed.horizonTasks];
    }
    return [];
  }

  @override
  Stream<EngineConnectionState> get connectionState => Stream.value(EngineConnectionState.connected);

  @override
  Stream<int> get totalUnreadCount => Stream.value(3);

  @override
  Stream<ChatEngineError> get errors => const Stream.empty();

  @override
  Future<List<ContactMatch>> discoverContacts(List<String> phoneHashes) async => [];

  @override
  Future<void> updatePushToken(String newToken) async {}

  @override
  Future<void> suspend() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<UserProfile> getProfile(String userId) async { throw UnimplementedError(); }

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {}

  @override
  Future<List<DeviceInfo>> getDevices() async => [];

  @override
  Future<void> unlinkDevice(int deviceId) async {}

  @override
  Future<String> getDisplayName(String userId) async => 'Mock User';

  @override
  Future<Conversation> createGroup({required String title, String? atmosphere}) async { throw UnimplementedError(); }

  @override
  Stream<HelloResponseChunk> streamHelloResponse({required String prompt, required String groupId}) async* {
    final response = "I've analyzed the constraints for $groupId. Let me propose an itinerary that perfectly aligns with everyone's preferences.";
    // Progressively yield words every 50ms to strictly test the SSE-style SpotlightSheet rendering.
    final words = response.split(' ');
    String current = "";
    for (final word in words) {
      current = current.isEmpty ? word : "$current $word";
      await Future.delayed(const Duration(milliseconds: 50));
      yield HelloResponseChunk(current);
    }
  }

  @override
  Future<void> reactToItem(String itemId, String signal) async {}

  @override
  Future<void> lockItem(String itemId, CommitmentProof proof) async {}

  @override
  Future<InviteLink> generateInvite() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const InviteLink(code: 'a1b2c3d4', url: 'https://hello.sh/s/a1b2c3d4');
  }

  @override
  Future<JoinResult> claimInvite(String code) async {
    // Artificial 800ms delay to enforce the physical SpringSimulation "Hold-to-Sign" claim mechanics testing.
    await Future.delayed(const Duration(milliseconds: 800));
    return const JoinResult(groupId: 'project_horizon', accessToken: 'mock_token');
  }

  @override
  Future<void> dispose() async {
    _conversationsController.close();
    for (var s in _sessions.values) {
      s.dispose();
    }
  }
}

class MockChatSession implements ChatSession {
  final String groupId;
  final Conversation conversation;
  
  final _messages = <Message>[];
  final _messagesController = StreamController<List<Message>>.broadcast();
  
  final _typingController = StreamController<List<TypingIndicator>>.broadcast();
  final _receiptsController = StreamController<List<Receipt>>.broadcast();
  final _presenceController = StreamController<PresenceState>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _receiptMorphTimer;

  MockChatSession(this.groupId, this.conversation, {bool populateMassiveScale = false}) {
    if (populateMassiveScale) {
       _messages.addAll(MockDataSeed.generateMessagesForGroup(
         groupId, 
         groupId == 'tokyo_trip' ? 50 : 20, 
         injectMedia: true,
       ));
    }
    
    // Initial emit for Riverpod
    Future.microtask(() => _messagesController.add(List.from(_messages)));
    
    // The 120fps Heartbeat
    if (groupId == 'tokyo_trip') {
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
        final newMsg = Message(
          id: 'live_${DateTime.now().millisecondsSinceEpoch}',
          groupId: groupId,
          senderId: 'sarah',
          senderDeviceId: 'mobile',
          type: MessageType.text,
          status: MessageStatus.delivered,
          timestamp: DateTime.now(),
          text: 'Haha, are we booking this yet?',
        );
        _messages.insert(0, newMsg); // Reverse pagination
        _messagesController.add(List.from(_messages));
      });
      
      // Simulate typing every 5s before pulse
      Timer.periodic(const Duration(seconds: 8), (timer) {
        _typingController.add([TypingIndicator(groupId: groupId, userId: 'sarah', startedAt: DateTime.now())]);
        Future.delayed(const Duration(seconds: 3), () {
          _typingController.add([]);
        });
      });
    }
    
    // Receipt morphing simulation
    _receiptMorphTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      final receiptBuffer = <Receipt>[];
      for (final msg in _messages) {
        if (msg.senderId == 'me' && msg.status != MessageStatus.read) {
          receiptBuffer.add(Receipt(
            messageId: msg.id,
            userId: 'sarah',
            deviceId: 'mobile', // Matches Receipt class signature
            deliveredAt: msg.status == MessageStatus.sent ? DateTime.now() : null,
            readAt: msg.status == MessageStatus.delivered ? DateTime.now() : null,
          ));
        }
      }
      if (receiptBuffer.isNotEmpty) {
        _receiptsController.add(receiptBuffer);
      }
    });
  }

  @override
  Stream<List<Message>> get messages async* {
    yield List.from(_messages);
    yield* _messagesController.stream;
  }

  @override
  Stream<List<TypingIndicator>> get typing => _typingController.stream;

  @override
  Stream<List<Receipt>> get receipts => _receiptsController.stream;

  @override
  Stream<PresenceState> get presence => _presenceController.stream;

  @override
  Future<Message> sendText(String plaintext) async {
    final msg = Message(
      id: 'sent_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: 'me',
      senderDeviceId: 'mobile',
      type: MessageType.text,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
      text: plaintext,
    );
    _messages.insert(0, msg);
    _messagesController.add(List.from(_messages));
    return msg;
  }

  @override
  Future<Message> sendMedia(MediaPayload payload) async {
    throw UnimplementedError('Mock sendMedia not implemented');
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
  Future<List<Message>> loadMore({int limit = 50}) async {
    return []; // Reverse pagination mock limit hit
  }

  @override
  Future<KeyFingerprint> getKeyFingerprint() async {
    return KeyFingerprint(userId: 'mock', deviceId: '1', fingerprintBytes: Uint8List(30));
  }
  
  void dispose() {
    _heartbeatTimer?.cancel();
    _receiptMorphTimer?.cancel();
    _messagesController.close();
    _typingController.close();
    _receiptsController.close();
    _presenceController.close();
  }
}
