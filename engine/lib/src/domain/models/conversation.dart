import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

/// Whether a conversation is a direct 1:1 chat or a group chat.
enum ConversationType {
  /// Direct message between two users.
  oneToOne,

  /// Group conversation with multiple participants.
  group,
}

/// A conversation (chat thread) with metadata and state.
@freezed
class Conversation with _$Conversation {
  /// Creates a [Conversation] instance.
  const factory Conversation({
    required String id,
    required ConversationType type,
    required List<String> participantIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? lastMessageId,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    @Default(0) int unreadCount,
    @Default(false) bool isPinned,
    @Default(false) bool isArchived,
    @Default(false) bool isMuted,
    DateTime? muteUntil,
    int? disappearingMessageTimerMs,
    @Default(true) bool isEncrypted,
  }) = _Conversation;

  /// Deserializes from JSON.
  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}
