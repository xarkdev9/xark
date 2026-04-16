import 'dart:convert';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';

class DecryptedItemPayload {
  final DecisionItem obliviousItem;
  final String title;
  final String? description;
  final String? category;
  final String? photoUrl;

  DecryptedItemPayload({
    required this.obliviousItem,
    required this.title,
    this.description,
    this.category,
    this.photoUrl,
  });

  // Proxy getters for oblivious item fields to avoid rewriting the entire UI
  String get id => obliviousItem.id;
  String get groupId => obliviousItem.groupId;
  String get state => obliviousItem.state;
  double get weightedScore => obliviousItem.weightedScore;
  double get agreementScore => obliviousItem.agreementScore;
  Map<String, String> get reactions => obliviousItem.reactions;
  bool get isLocked => obliviousItem.isLocked;
  String? get proposedBy => obliviousItem.proposedBy;

  factory DecryptedItemPayload.fromJson(DecisionItem obliviousItem, String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return DecryptedItemPayload(
        obliviousItem: obliviousItem,
        title: map['title'] as String? ?? 'Decrypted Item',
        description: map['description'] as String?,
        category: map['category'] as String?,
        photoUrl: map['photoUrl'] as String?,
      );
    } catch (e) {
      return DecryptedItemPayload(
        obliviousItem: obliviousItem,
        title: 'Decryption Error',
        description: 'Failed to process payload: $e',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}
