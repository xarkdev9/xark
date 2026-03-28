import 'package:e2ee_chat_sdk/e2ee_chat.dart';

Map<String, dynamic> createMockE2EEMedia(String imageUrl) {
  return {
    'encrypted_image': {
      'mediaUrl': imageUrl,
      'aesKeyBase64': 'mock_key',
      'ivBase64': 'mock_iv',
      'mimeType': 'image/jpeg',
      'inlineThumbnail': null
    }
  };
}

class MockDataSeed {
  // Decision Rails for Project Horizon
  static final horizonTasks = [
    DecisionItem(id: 't1', groupId: 'project_horizon', title: 'Finalize Q3 Budget', state: 'active', weightedScore: 8.0, agreementScore: 0.10, isLocked: false),
    DecisionItem(id: 't2', groupId: 'project_horizon', title: 'Hire Senior iOS Engineer', state: 'active', weightedScore: 19.5, agreementScore: 0.88, isLocked: false),
    DecisionItem(id: 't3', groupId: 'project_horizon', title: 'Migrate to Postgres 16', state: 'active', weightedScore: 25.0, agreementScore: 0.96, isLocked: true),
  ];

  // Tokyo Trip Items
  static final tokyoHotels = [
    DecisionItem(id: 'h1', groupId: 'tokyo_trip', title: 'Park Hyatt Tokyo', state: 'active', weightedScore: 18.0, agreementScore: 0.94, isLocked: false, photoUrl: 'https://images.unsplash.com/photo-1542051842857-cb39178ad01e?q=80&w=2873&auto=format&fit=crop'),
    DecisionItem(id: 'h2', groupId: 'tokyo_trip', title: 'Aman Tokyo', state: 'active', weightedScore: 15.0, agreementScore: 0.85, isLocked: false, photoUrl: 'https://images.unsplash.com/photo-1526620925725-d055172ea6f6?q=80&w=2938&auto=format&fit=crop'),
    DecisionItem(id: 'h3', groupId: 'tokyo_trip', title: 'Trunk Hotel', state: 'active', weightedScore: 11.0, agreementScore: 0.68, isLocked: false, photoUrl: 'https://images.unsplash.com/photo-1560963683-1dd8125dbb2c?q=80&w=2942&auto=format&fit=crop'),
  ];
  static final tokyoTasks = [
    DecisionItem(id: 't1', groupId: 'tokyo_trip', title: 'Book the Uber to Narita', state: 'active', weightedScore: 5.0, agreementScore: 0.20, isLocked: false),
    DecisionItem(id: 't2', groupId: 'tokyo_trip', title: 'Pick up pocket wifi at airport', state: 'active', weightedScore: 12.0, agreementScore: 0.70, isLocked: true),
  ];

  static List<Message> generateMessagesForGroup(String groupId, int count, {bool injectMedia = false}) {
    final msgs = <Message>[];
    final now = DateTime.now();
    for (int i = 0; i < count; i++) {
      msgs.add(Message(
        id: '${groupId}_msg_$i',
        groupId: groupId,
        senderId: i % 2 == 0 ? 'me' : 'other_user',
        senderDeviceId: 'mobile',
        type: MessageType.text,
        status: i < 5 ? MessageStatus.delivered : MessageStatus.read, // Varied receipt statuses
        timestamp: now.subtract(Duration(minutes: count - i)),
        text: 'This is a high-fidelity mock message #$i for $groupId.',
      ));
    }

    if (injectMedia) {
      msgs.add(Message(
        id: '${groupId}_media1',
        groupId: groupId,
        senderId: 'other_user',
        senderDeviceId: 'mobile',
        type: MessageType.media,
        status: MessageStatus.read,
        timestamp: now.subtract(const Duration(seconds: 45)),
        text: 'Look at this!',
        media: MediaMetadata(
          mediaId: 'm1',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
          downloadUrl: 'https://images.unsplash.com/photo-1551468641-fcdae9a9307b?q=80&w=2600&auto=format&fit=crop',
        ),
      ));
      msgs.add(Message(
        id: '${groupId}_media2',
        groupId: groupId,
        senderId: 'me',
        senderDeviceId: 'mobile',
        type: MessageType.media,
        status: MessageStatus.read,
        timestamp: now.subtract(const Duration(seconds: 15)),
        text: 'Wow, gorgeous.',
        media: MediaMetadata(
          mediaId: 'm2',
          mimeType: 'image/jpeg',
          sizeBytes: 2048,
          downloadUrl: 'https://images.unsplash.com/photo-1518684079-3c830dcef090?q=80&w=2800&auto=format&fit=crop', // Dubai / Skyline
        ),
      ));
    }

    return msgs.reversed.toList();
  }
}

