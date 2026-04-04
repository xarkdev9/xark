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

  static List<Conversation> buildConversations() {
    List<Conversation> list = [
      Conversation(
        id: 'bali',
        type: ConversationType.group,
        participantIds: ['me', 'user2', 'user3', 'user4'],
        createdAt: _now.subtract(const Duration(days: 60)),
        updatedAt: _now.subtract(const Duration(seconds: 15)),
        unreadCount: 12,
        isPinned: true,
        lastMessageText: "Did anyone book the St. Regis yet?",
        isArchived: false,
        isMuted: false,
        isEncrypted: true,
      ),
      Conversation(
        id: 'sarah',
        type: ConversationType.group,
        participantIds: ['me', 'sarah', 'alice'],
        createdAt: _now.subtract(const Duration(days: 30)),
        updatedAt: _now.subtract(const Duration(minutes: 5)),
        unreadCount: 5,
        isPinned: true,
        lastMessageText: "Okay, 7pm works for me!",
        isArchived: false,
        isMuted: false,
        isEncrypted: true,
      ),
      Conversation(
        id: 'alice',
        type: ConversationType.oneToOne,
        participantIds: ['me', 'alice'],
        createdAt: _now.subtract(const Duration(days: 100)),
        updatedAt: _now.subtract(const Duration(minutes: 12)),
        unreadCount: 1,
        isPinned: true,
        lastMessageText: "Check out this photo I took",
        isArchived: false,
        isMuted: false,
        isEncrypted: true,
      ),
      Conversation(
        id: 'tokyo',
        type: ConversationType.group,
        participantIds: ['me', 'user2', 'user5'],
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now.subtract(const Duration(hours: 2)),
        unreadCount: 45,
        isPinned: false,
        lastMessageText: "Itinerary looks packed \u{1F525}",
        isArchived: false,
        isMuted: false,
        isEncrypted: true,
      ),
      Conversation(
        id: 'horizon',
        type: ConversationType.group,
        participantIds: ['me', 'userX', 'userY'],
        createdAt: _now.subtract(const Duration(days: 150)),
        updatedAt: _now.subtract(const Duration(days: 1)),
        unreadCount: 3,
        isPinned: false,
        lastMessageText: "Q3 objectives are locked.",
        isArchived: false,
        isMuted: false,
        isEncrypted: true,
      ),
    ];

    // Seed 15 extra dormant/archived chats to fill the ScrollView
    for (int i = 0; i < 15; i++) {
      list.add(Conversation(
        id: 'dormant_$i',
        type: i % 3 == 0 ? ConversationType.group : ConversationType.oneToOne,
        participantIds: ['me', 'random_$i'],
        createdAt: _now.subtract(Duration(days: 180 + (i * 10))),
        updatedAt: _now.subtract(Duration(days: 10 + i * 2)),
        unreadCount: 0,
        isPinned: false,
        isArchived: i > 10,
        isMuted: i > 10,
        lastMessageText: "Yeah sounds good.",
        isEncrypted: true,
      ));
    }

    return list;
  }

  static List<Message> buildMessagesFor(String groupId) {
    List<Message> feed = [];
    int count = 50; 

    final unsplashLinks = [
      'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1542314831-c6a4d27ce66b?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1531804226530-70f8004aa44e?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800&auto=format&fit=crop',
    ];

    for (int i = 0; i < count; i++) {
      // Reverse order simulation (index 0 is the newest message)
      final msgTime = _now.subtract(Duration(hours: i * 2, minutes: i * 13));
      final isSelf = i % 5 == 0;
      final sender = isSelf ? 'me' : 'user_${i % 4}';

      bool isMedia = (i % 8 == 2);
      bool isAi = (i % 25 == 3);
      bool isSystem = (i == count - 1); // Genesis message

      MessageType type = MessageType.e2ee;
      String? text = "This is historical message $i in $groupId. E2EE payload stable.";
      MediaMetadata? media;
      Map<String, List<String>> reactions = {};

      if (isSystem) {
        type = MessageType.system;
        text = "This space was created and End-to-End Encrypted.";
      } else if (isAi) {
        type = MessageType.ai;
        text = "I've synthesized the opinions based on your taste graph. Here is what I recommend for $groupId.";
      } else if (isMedia) {
        type = MessageType.media;
        text = null;
        media = createMockE2EEMedia(
          'media_${groupId}_$i', 
          unsplashLinks[i % unsplashLinks.length]
        );
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

    return [];
  }
}
