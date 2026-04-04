import 'package:e2ee_chat_sdk/e2ee_chat.dart';

class MockDataSeed {
  static final DateTime _now = DateTime.now();

  static MediaMetadata createMockE2EEMedia(String id, String unsplashUrl) {
    return MediaMetadata(
      mediaId: id,
      mimeType: 'image/jpeg',
      sizeBytes: 1024 * 1024,
      downloadUrl: unsplashUrl,
      encryptedKey: 'mock_base64_key====',
      iv: 'mock_iv_base64==',
      thumbnailUrl: unsplashUrl,
    );
  }

  /// Display name map — used by UI to resolve conversation IDs to human names.
  static const displayNames = <String, String>{
    // 1:1 DMs
    'dm_priya': 'Priya',
    'dm_alex': 'Alex',
    'dm_emma': 'Emma',
    'dm_liam': 'Liam',
    'dm_sofia': 'Sofia',
    'dm_noah': 'Noah',
    'dm_maya': 'Maya',
    'dm_dad': 'Dad',
    // Groups
    'bali': 'Bali Trip 2026',
    'sarah': "Sarah's Birthday",
    'tokyo': 'Tokyo Neon Nights',
    'family': 'Family',
    'classof2000': 'Class of 2000',
    'poker': 'Poker Night',
    'alaska': 'Alaska 2026',
    'swiss': 'Swiss Trip',
    'sf': 'SF Trip',
    'delhi': 'Delhi Trip',
  };

  static List<Conversation> buildConversations() {
    return [
      // ── 1:1 DMs (real person names) ──
      Conversation(
        id: 'dm_priya', type: ConversationType.oneToOne,
        participantIds: ['me', 'priya'],
        createdAt: _now.subtract(const Duration(days: 200)),
        updatedAt: _now.subtract(const Duration(minutes: 3)),
        unreadCount: 2, isPinned: true,
        lastMessageText: "Just landed, the weather is perfect!",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_alex', type: ConversationType.oneToOne,
        participantIds: ['me', 'alex'],
        createdAt: _now.subtract(const Duration(days: 365)),
        updatedAt: _now.subtract(const Duration(minutes: 25)),
        unreadCount: 0, isPinned: true,
        lastMessageText: "Haha yeah, see you at 7",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_emma', type: ConversationType.oneToOne,
        participantIds: ['me', 'emma'],
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now.subtract(const Duration(hours: 1)),
        unreadCount: 1, isPinned: false,
        lastMessageText: "Can you send me that recipe?",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_liam', type: ConversationType.oneToOne,
        participantIds: ['me', 'liam'],
        createdAt: _now.subtract(const Duration(days: 180)),
        updatedAt: _now.subtract(const Duration(hours: 4)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "Running 10 min late, sorry!",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_sofia', type: ConversationType.oneToOne,
        participantIds: ['me', 'sofia'],
        createdAt: _now.subtract(const Duration(days: 60)),
        updatedAt: _now.subtract(const Duration(hours: 8)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "That sunset photo is incredible",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_noah', type: ConversationType.oneToOne,
        participantIds: ['me', 'noah'],
        createdAt: _now.subtract(const Duration(days: 120)),
        updatedAt: _now.subtract(const Duration(days: 1)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "I vote yes, 100%",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_maya', type: ConversationType.oneToOne,
        participantIds: ['me', 'maya'],
        createdAt: _now.subtract(const Duration(days: 45)),
        updatedAt: _now.subtract(const Duration(days: 2)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "Happy to split the cost evenly",
        isEncrypted: true,
      ),
      Conversation(
        id: 'dm_dad', type: ConversationType.oneToOne,
        participantIds: ['me', 'dad'],
        createdAt: _now.subtract(const Duration(days: 500)),
        updatedAt: _now.subtract(const Duration(days: 3)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "Call me when you get a chance",
        isEncrypted: true,
      ),
      // ── Groups ──
      Conversation(
        id: 'bali', type: ConversationType.group,
        participantIds: ['me', 'priya', 'alex', 'emma'],
        createdAt: _now.subtract(const Duration(days: 60)),
        updatedAt: _now.subtract(const Duration(seconds: 15)),
        unreadCount: 12, isPinned: true,
        lastMessageText: "Did anyone book the St. Regis yet?",
        isEncrypted: true,
      ),
      Conversation(
        id: 'sarah', type: ConversationType.group,
        participantIds: ['me', 'sofia', 'maya'],
        createdAt: _now.subtract(const Duration(days: 30)),
        updatedAt: _now.subtract(const Duration(minutes: 5)),
        unreadCount: 5, isPinned: true,
        lastMessageText: "Okay, 7pm works for me!",
        isEncrypted: true,
      ),
      Conversation(
        id: 'tokyo', type: ConversationType.group,
        participantIds: ['me', 'liam', 'noah'],
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now.subtract(const Duration(hours: 2)),
        unreadCount: 45, isPinned: false,
        lastMessageText: "Itinerary looks packed \u{1F525}",
        isEncrypted: true,
      ),
      Conversation(
        id: 'family', type: ConversationType.group,
        participantIds: ['me', 'dad', 'priya'],
        createdAt: _now.subtract(const Duration(days: 400)),
        updatedAt: _now.subtract(const Duration(hours: 6)),
        unreadCount: 3, isPinned: false,
        lastMessageText: "Dinner at 7? Mom is cooking biryani",
        isEncrypted: true,
      ),
      Conversation(
        id: 'classof2000', type: ConversationType.group,
        participantIds: ['me', 'alex', 'liam', 'emma', 'noah', 'sofia'],
        createdAt: _now.subtract(const Duration(days: 300)),
        updatedAt: _now.subtract(const Duration(days: 1)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "Reunion confirmed for August!",
        isEncrypted: true,
      ),
      Conversation(
        id: 'poker', type: ConversationType.group,
        participantIds: ['me', 'alex', 'noah', 'liam'],
        createdAt: _now.subtract(const Duration(days: 200)),
        updatedAt: _now.subtract(const Duration(days: 2)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "I'm bringing the chips this time",
        isEncrypted: true,
      ),
      Conversation(
        id: 'alaska', type: ConversationType.group,
        participantIds: ['me', 'emma', 'priya', 'maya'],
        createdAt: _now.subtract(const Duration(days: 14)),
        updatedAt: _now.subtract(const Duration(hours: 12)),
        unreadCount: 8, isPinned: false,
        lastMessageText: "Northern lights forecast looks amazing",
        isEncrypted: true,
      ),
      // Memory groups (past trips with photos)
      Conversation(
        id: 'swiss', type: ConversationType.group,
        participantIds: ['me', 'priya', 'alex'],
        createdAt: _now.subtract(const Duration(days: 180)),
        updatedAt: _now.subtract(const Duration(days: 60)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "Best trip ever honestly",
        isEncrypted: true,
      ),
      Conversation(
        id: 'sf', type: ConversationType.group,
        participantIds: ['me', 'emma', 'liam'],
        createdAt: _now.subtract(const Duration(days: 250)),
        updatedAt: _now.subtract(const Duration(days: 90)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "The clam chowder was unreal",
        isEncrypted: true,
      ),
      Conversation(
        id: 'delhi', type: ConversationType.group,
        participantIds: ['me', 'dad', 'priya'],
        createdAt: _now.subtract(const Duration(days: 320)),
        updatedAt: _now.subtract(const Duration(days: 120)),
        unreadCount: 0, isPinned: false,
        lastMessageText: "Chandni Chowk street food was next level",
        isEncrypted: true,
      ),
    ];
  }

  static const _chatLines = [
    "Hey, what time works for everyone?",
    "I found an amazing spot, check this out",
    "lol that's exactly what I was thinking",
    "Can someone send the address?",
    "Running 10 min late, sorry!",
    "This is going to be epic",
    "Wait, did you see the price drop??",
    "I'm in. Let's do it.",
    "Anyone else craving sushi rn?",
    "Just landed! The weather is perfect",
    "Thanks for organizing everything",
    "Okay cool, I'll book it tonight",
    "Has anyone been there before?",
    "That sunset photo is incredible",
    "I vote yes, 100%",
    "Let me check my calendar real quick",
    "Perfect, see you all at 7!",
    "The hotel looks amazing from the reviews",
    "Should we rent a car or take taxis?",
    "omg the food here is unreal",
    "Send me the link when you get a chance",
    "I think we should go with option A",
    "Happy to split the cost evenly",
    "Just sent the payment",
    "This group is the best honestly",
    "Can't wait! Only 3 more days",
    "Let's make a checklist for packing",
    "Remember to bring sunscreen this time",
    "The flight is confirmed!",
    "Who's handling the dinner reservation?",
  ];

  /// Memory images grouped by trip — used for media messages in past trip groups.
  static const _memoryImages = <String, List<String>>{
    'swiss': [
      'assets/memories/swiss_1.jpg',
      'assets/memories/swiss_2.jpg',
      'assets/memories/swiss_3.jpg',
      'assets/memories/swiss_4.jpg',
    ],
    'sf': [
      'assets/memories/sf_1.jpg',
      'assets/memories/sf_2.jpg',
      'assets/memories/sf_3.jpg',
      'assets/memories/sf_4.jpg',
    ],
    'delhi': [
      'assets/memories/delhi_1.jpg',
      'assets/memories/delhi_2.jpg',
      'assets/memories/delhi_3.jpg',
      'assets/memories/delhi_4.jpg',
    ],
  };

  static List<Message> buildMessagesFor(String groupId) {
    List<Message> feed = [];
    final count = 50;

    // Memory groups get their trip photos as media messages
    final tripPhotos = _memoryImages[groupId];

    for (int i = 0; i < count; i++) {
      final msgTime = _now.subtract(Duration(hours: i * 2, minutes: i * 13));
      final isSelf = i % 5 == 0;
      final sender = isSelf ? 'me' : 'user_${i % 4}';

      bool isMedia = (i % 8 == 2);
      bool isAi = (i % 25 == 3);
      bool isSystem = (i == count - 1);

      MessageType type = MessageType.e2ee;
      String? text = _chatLines[(i * 7 + groupId.hashCode) % _chatLines.length];
      MediaMetadata? media;
      Map<String, List<String>> reactions = {};

      if (isSystem) {
        type = MessageType.system;
        text = "This group is end-to-end encrypted.";
      } else if (isAi) {
        type = MessageType.ai;
        text = "Based on your group's preferences, I'd recommend checking the top-rated option. Want me to research more?";
      } else if (isMedia) {
        type = MessageType.media;
        text = null;
        // Use trip photos if available, otherwise use decide assets
        final photoUrl = tripPhotos != null
            ? tripPhotos[(i ~/ 8) % tripPhotos.length]
            : 'assets/decide/bali_beach.jpg';
        media = createMockE2EEMedia('media_${groupId}_$i', photoUrl);
        if (i % 16 == 2) {
          reactions = {'love': ['me', 'user_1']};
        }
      }

      feed.add(Message(
        id: 'msg_${groupId}_$i',
        groupId: groupId,
        senderId: sender,
        senderDeviceId: 'dev_1',
        type: type,
        role: isAi ? 'hello' : 'user',
        status: isSelf ? MessageStatus.read : MessageStatus.delivered,
        timestamp: msgTime,
        text: text,
        media: media,
        reactions: reactions,
        isStarred: i == 1, // Pin the second to newest message often
      ));
    }

    return feed;
  }

  static List<DecisionItem> buildDecisionItemsFor(String groupId) {
    if (groupId == 'bali') {
      return [
        // Hotels (3)
        DecisionItem(
          id: 'item_bali_h1', groupId: 'bali', category: 'Hotels',
          title: 'The St. Regis Bali Resort',
          description: '\$750/night \u2022 5-star \u2022 Nusa Dua',
          state: 'locked', weightedScore: 10.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'assets/decide/bali_stregis.jpg',
          proposedBy: 'user2', reactions: {'love': 'user_X'},
        ),
        DecisionItem(
          id: 'item_bali_h2', groupId: 'bali', category: 'Hotels',
          title: 'W Bali - Seminyak',
          description: '\$450/night \u2022 5-star \u2022 Seminyak',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.45,
          photoUrl: 'assets/decide/bali_wbali.jpg',
          proposedBy: 'user3',
        ),
        DecisionItem(
          id: 'item_bali_h3', groupId: 'bali', category: 'Hotels',
          title: 'The Mulia Bali',
          description: '\$680/night \u2022 5-star \u2022 Nusa Dua',
          state: 'voting', weightedScore: 1.0, agreementScore: 0.30,
          photoUrl: 'assets/decide/bali_mulia.jpg',
          proposedBy: 'user4',
        ),
        // Experiences (3)
        DecisionItem(
          id: 'item_bali_e1', groupId: 'bali', category: 'Experiences',
          title: 'Mount Batur Sunrise Trek',
          description: '\$65/person \u2022 4 Hours',
          state: 'locked', weightedScore: 8.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'assets/decide/bali_batur.jpg',
          proposedBy: 'user4',
        ),
        DecisionItem(
          id: 'item_bali_e2', groupId: 'bali', category: 'Experiences',
          title: 'Ubud Rice Terraces Tour',
          description: '\$45/person \u2022 Half day',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.60,
          photoUrl: 'assets/decide/bali_ubud.jpg',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_bali_e3', groupId: 'bali', category: 'Experiences',
          title: 'Sunset Dinner Cruise',
          description: '\$120/person \u2022 3 Hours',
          state: 'voting', weightedScore: 1.0, agreementScore: 0.25,
          photoUrl: 'assets/decide/bali_cruise.jpg',
          proposedBy: 'user3',
        ),
        // Flights (2)
        DecisionItem(
          id: 'item_bali_f1', groupId: 'bali', category: 'Flights',
          title: 'Singapore Airlines SQ938',
          description: '\$320 \u2022 SIN \u2192 DPS \u2022 08:20 AM',
          state: 'voting', weightedScore: 5.0, agreementScore: 0.70,
          photoUrl: 'assets/decide/bali_flight_sq.jpg',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_bali_f2', groupId: 'bali', category: 'Flights',
          title: 'Garuda Indonesia GA715',
          description: '\$280 \u2022 CGK \u2192 DPS \u2022 06:00 AM',
          state: 'voting', weightedScore: 2.0, agreementScore: 0.35,
          photoUrl: 'assets/decide/bali_flight_ga.jpg',
          proposedBy: 'user4',
        ),
        // Dining (3)
        DecisionItem(
          id: 'item_bali_d1', groupId: 'bali', category: 'Dining',
          title: 'Locavore',
          description: 'Michelin-worthy tasting menu \u2022 Ubud',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.55,
          photoUrl: 'assets/decide/bali_locavore.jpg',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_bali_d2', groupId: 'bali', category: 'Dining',
          title: 'Sardine',
          description: 'Farm-to-table rice paddy views \u2022 Seminyak',
          state: 'voting', weightedScore: 2.0, agreementScore: 0.40,
          photoUrl: 'assets/decide/bali_sardine.jpg',
          proposedBy: 'user3',
        ),
        DecisionItem(
          id: 'item_bali_d3', groupId: 'bali', category: 'Dining',
          title: 'Warung Babi Guling Ibu Oka',
          description: 'Legendary roast suckling pig \u2022 Ubud',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/bali_warung.jpg',
          proposedBy: 'me',
        ),
        // Loose / Ideas (4)
        DecisionItem(
          id: 'item_bali_l1', groupId: 'bali', category: 'Ideas',
          title: 'Beach Club Day Pass',
          description: 'Potato Head or Finns?',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/bali_beach.jpg',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_bali_l2', groupId: 'bali', category: 'Ideas',
          title: 'Surfboard Rental',
          description: 'Kuta Beach, full day',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'user3',
        ),
        DecisionItem(
          id: 'item_bali_l3', groupId: 'bali', category: 'Ideas',
          title: 'Group Spa Day',
          description: 'Traditional Balinese massage',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/bali_spa.jpg',
          proposedBy: 'user4',
        ),
      ];
    } else if (groupId == 'sarah') {
      return [
        // Restaurants (3)
        DecisionItem(
          id: 'item_sarah_r1', groupId: 'sarah', category: 'Restaurants',
          title: 'Carbone (Private Room)',
          description: 'Michelin-starred Italian-American retro glamour.',
          state: 'voting', weightedScore: 8.0, agreementScore: 0.90,
          photoUrl: 'assets/decide/sarah_carbone.jpg',
          proposedBy: 'alice', reactions: {'love': 'me'},
        ),
        DecisionItem(
          id: 'item_sarah_r2', groupId: 'sarah', category: 'Restaurants',
          title: 'Balthazar',
          description: 'Classic French brasserie in SoHo.',
          state: 'voting', weightedScore: 1.0, agreementScore: 0.20,
          photoUrl: 'assets/decide/sarah_balthazar.jpg',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_sarah_r3', groupId: 'sarah', category: 'Restaurants',
          title: 'Le Bernardin',
          description: 'World-class seafood. Special occasion perfect.',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/sarah_bernardin.jpg',
          proposedBy: 'alice',
        ),
        // Gifts (3)
        DecisionItem(
          id: 'item_sarah_g1', groupId: 'sarah', category: 'Gifts',
          title: 'Aesop Departure Kit',
          description: 'Luxury travel skincare set',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.60,
          photoUrl: 'assets/decide/sarah_aesop.jpg',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_sarah_g2', groupId: 'sarah', category: 'Gifts',
          title: 'Concert Tickets (Billie Eilish)',
          description: 'MSG, 2 tickets, floor seats',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.45,
          photoUrl: 'assets/decide/sarah_concert.jpg',
          proposedBy: 'alice',
        ),
        DecisionItem(
          id: 'item_sarah_g3', groupId: 'sarah', category: 'Gifts',
          title: 'Custom Photo Book',
          description: 'Artifact Uprising hardcover',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'me',
        ),
        // Decorations (2)
        DecisionItem(
          id: 'item_sarah_d1', groupId: 'sarah', category: 'Decorations',
          title: 'Balloon Arch (Rose Gold)',
          description: 'Setup at venue 2hrs before',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'alice',
        ),
        DecisionItem(
          id: 'item_sarah_d2', groupId: 'sarah', category: 'Decorations',
          title: 'Custom Cake (Lady M)',
          description: 'Mille crepe, feeds 12',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/sarah_cake.jpg',
          proposedBy: 'me',
        ),
      ];
    } else if (groupId == 'tokyo') {
      return [
        DecisionItem(
          id: 'item_tokyo_h1', groupId: 'tokyo', category: 'Hotels',
          title: 'Park Hyatt Tokyo',
          description: '\$650/night \u2022 Lost in Translation vibes',
          state: 'voting', weightedScore: 18.0, agreementScore: 0.94,
          photoUrl: 'assets/decide/tokyo_parkhyatt.jpg',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_h2', groupId: 'tokyo', category: 'Hotels',
          title: 'Andaz Tokyo',
          description: '\$420/night \u2022 Toranomon Hills',
          state: 'voting', weightedScore: 8.0, agreementScore: 0.60,
          photoUrl: 'assets/decide/tokyo_andaz.jpg',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_h3', groupId: 'tokyo', category: 'Hotels',
          title: 'Hoshinoya Tokyo',
          description: '\$380/night \u2022 Traditional ryokan luxury',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.30,
          photoUrl: 'assets/decide/tokyo_hoshinoya.jpg',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_tokyo_a1', groupId: 'tokyo', category: 'Experiences',
          title: 'TeamLab Borderless',
          description: 'Digital art museum \u2022 Odaiba',
          state: 'voting', weightedScore: 6.0, agreementScore: 0.67,
          photoUrl: 'assets/decide/tokyo_teamlab.jpg',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_a2', groupId: 'tokyo', category: 'Experiences',
          title: 'Shibuya Crossing at Night',
          description: 'Rooftop photo session \u2022 Mag\'s Park',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.45,
          photoUrl: 'assets/decide/tokyo_shibuya.jpg',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_d1', groupId: 'tokyo', category: 'Dining',
          title: 'Sukiyabashi Jiro',
          description: '3-star Michelin sushi \u2022 Ginza',
          state: 'locked', weightedScore: 15.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'assets/decide/tokyo_jiro.jpg',
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_d2', groupId: 'tokyo', category: 'Dining',
          title: 'Ichiran Ramen',
          description: 'Solo booth ramen \u2022 Shinjuku',
          state: 'voting', weightedScore: 5.0, agreementScore: 0.55,
          photoUrl: 'assets/decide/tokyo_ichiran.jpg',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_tokyo_d3', groupId: 'tokyo', category: 'Dining',
          title: 'Robot Restaurant',
          description: 'Wild dinner show \u2022 Kabukicho',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/tokyo_robot.jpg',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_l1', groupId: 'tokyo', category: 'Ideas',
          title: 'Pocket WiFi Rental',
          description: 'Pick up at Narita',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_tokyo_l2', groupId: 'tokyo', category: 'Ideas',
          title: 'Suica Card vs Day Pass',
          description: 'Which metro strategy?',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          proposedBy: 'user2',
        ),
        DecisionItem(
          id: 'item_tokyo_l3', groupId: 'tokyo', category: 'Ideas',
          title: 'Kyoto Day Trip',
          description: 'Shinkansen round trip \u2022 \$120',
          state: 'voting', weightedScore: 7.0, agreementScore: 0.50,
          photoUrl: 'assets/decide/tokyo_kyoto.jpg',
          proposedBy: 'user5',
        ),
        DecisionItem(
          id: 'item_tokyo_l4', groupId: 'tokyo', category: 'Ideas',
          title: 'Akihabara Shopping Spree',
          description: 'Anime, tech, arcades',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/tokyo_akihabara.jpg',
          proposedBy: 'user2',
        ),
      ];
    }

    else if (groupId == 'family') {
      return [
        // ── Mom's Birthday — restaurant vote (active, hot) ──
        DecisionItem(
          id: 'item_fam_bday1', groupId: 'family', category: "Mom's Birthday",
          title: 'Carbone (Italian)',
          description: 'Private dining room \u2022 \$85/person',
          state: 'voting', weightedScore: 8.0, agreementScore: 0.82,
          photoUrl: 'assets/decide/family_italian.jpg',
          proposedBy: 'priya', reactions: {'love': 'me'},
        ),
        DecisionItem(
          id: 'item_fam_bday2', groupId: 'family', category: "Mom's Birthday",
          title: 'Nobu (Japanese)',
          description: 'Omakase tasting \u2022 \$120/person',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.40,
          photoUrl: 'assets/decide/family_dinner.jpg',
          proposedBy: 'dad',
        ),
        // ── Thanksgiving 2026 — who brings what ──
        DecisionItem(
          id: 'item_fam_thx1', groupId: 'family', category: 'Thanksgiving',
          title: 'Turkey (Deep Fried)',
          description: 'Dad volunteers \u2022 20 lb bird',
          state: 'locked', weightedScore: 10.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'assets/decide/family_thanksgiving.jpg',
          proposedBy: 'dad',
        ),
        DecisionItem(
          id: 'item_fam_thx2', groupId: 'family', category: 'Thanksgiving',
          title: 'Pumpkin Pie vs Pecan Pie',
          description: 'Annual debate \u2022 vote now',
          state: 'voting', weightedScore: 4.0, agreementScore: 0.55,
          proposedBy: 'me',
        ),
        // ── Dad's Retirement Party — venue ──
        DecisionItem(
          id: 'item_fam_retire1', groupId: 'family', category: 'Retirement Party',
          title: 'Backyard BBQ (Home)',
          description: 'Casual \u2022 50 guests \u2022 free venue',
          state: 'voting', weightedScore: 6.0, agreementScore: 0.70,
          photoUrl: 'assets/decide/family_retirement.jpg',
          proposedBy: 'me',
        ),
        DecisionItem(
          id: 'item_fam_retire2', groupId: 'family', category: 'Retirement Party',
          title: 'Restaurant Buyout',
          description: 'Fancy \u2022 50 guests \u2022 \$3,000',
          state: 'voting', weightedScore: 2.0, agreementScore: 0.30,
          proposedBy: 'priya',
        ),
        // ── Summer Vacation — destination vote ──
        DecisionItem(
          id: 'item_fam_vac1', groupId: 'family', category: 'Summer Vacation',
          title: 'Hawaii (Maui)',
          description: 'Beach house \u2022 7 nights \u2022 \$4,200',
          state: 'voting', weightedScore: 7.0, agreementScore: 0.65,
          photoUrl: 'assets/decide/family_vacation.jpg',
          proposedBy: 'priya',
        ),
        DecisionItem(
          id: 'item_fam_vac2', groupId: 'family', category: 'Summer Vacation',
          title: 'Lake Tahoe Cabin',
          description: 'Mountain retreat \u2022 5 nights \u2022 \$2,800',
          state: 'voting', weightedScore: 5.0, agreementScore: 0.50,
          proposedBy: 'dad',
        ),
        // ── Cousin's Wedding Gift ──
        DecisionItem(
          id: 'item_fam_gift1', groupId: 'family', category: 'Wedding Gift',
          title: 'KitchenAid Mixer (Red)',
          description: 'From registry \u2022 \$350',
          state: 'voting', weightedScore: 5.0, agreementScore: 0.60,
          photoUrl: 'assets/decide/family_wedding.jpg',
          proposedBy: 'me',
        ),
        // ── Home Renovation — contractor quotes ──
        DecisionItem(
          id: 'item_fam_reno1', groupId: 'family', category: 'Home Renovation',
          title: 'Kitchen Remodel (Phase 1)',
          description: 'Contractor A \u2022 \$15,000 \u2022 4 weeks',
          state: 'voting', weightedScore: 3.0, agreementScore: 0.35,
          photoUrl: 'assets/decide/family_renovation.jpg',
          proposedBy: 'dad',
        ),
        // ── Christmas 2026 — early planning ──
        DecisionItem(
          id: 'item_fam_xmas1', groupId: 'family', category: 'Christmas 2026',
          title: 'Secret Santa (Budget \$50)',
          description: 'Draw names at Thanksgiving',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/family_christmas.jpg',
          proposedBy: 'priya',
        ),
        // ── Grocery Run — this week ──
        DecisionItem(
          id: 'item_fam_groc1', groupId: 'family', category: 'Grocery Run',
          title: "Costco List (Saturday)",
          description: 'Chicken, rice, veggies, snacks',
          state: 'proposed', weightedScore: 0.0, agreementScore: 0.0,
          photoUrl: 'assets/decide/family_grocery.jpg',
          proposedBy: 'me',
        ),
        // ── Family Photo Shoot — DONE (locked) ──
        DecisionItem(
          id: 'item_fam_photo1', groupId: 'family', category: 'Photo Shoot',
          title: 'Golden Hour at Griffith Park',
          description: 'Booked \u2022 Oct 15 \u2022 4:30 PM',
          state: 'locked', weightedScore: 12.0, agreementScore: 1.0, isLocked: true,
          photoUrl: 'assets/decide/family_photoshoot.jpg',
          proposedBy: 'priya',
        ),
      ];
    }

    return [];
  }
}
