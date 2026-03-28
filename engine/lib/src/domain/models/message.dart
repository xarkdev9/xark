import 'package:e2ee_chat_sdk/src/domain/models/media_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Status of a message in the send pipeline.
enum MessageStatus {
  /// Message is being sent.
  sending,

  /// Message has been sent to the server.
  sent,

  /// Message has been delivered to the recipient's device.
  delivered,

  /// Message has been read by the recipient.
  read,

  /// Message failed to send.
  failed,
}

/// Wire-level message type matching the backend protocol.
enum MessageType {
  /// End-to-end encrypted message.
  @JsonValue('e2ee')
  e2ee,

  /// AI assistant message.
  @JsonValue('ai')
  ai,

  /// System-generated message (e.g., user joined).
  @JsonValue('system')
  system,

  /// Legacy unencrypted message.
  @JsonValue('legacy')
  legacy,

  /// Sender key distribution message for group chats.
  @JsonValue('sender_key_dist')
  senderKeyDist,

  /// Standard text message.
  @JsonValue('message')
  text,

  /// Media message (image, video, audio, document).
  @JsonValue('media')
  media,
}

/// A chat message with metadata, encryption status, and optional media.
@freezed
class Message with _$Message {
  /// Creates a [Message] instance.
  const factory Message({
    required String id,
    required String groupId,
    required String senderId,
    required String senderDeviceId,
    required MessageType type,
    required MessageStatus status,
    required DateTime timestamp,
    @Default('user') String role,
    int? serverSeq,
    String? text,
    MediaMetadata? media,
    String? replyToMessageId,
    @Default({}) Map<String, List<String>> reactions,
    @Default(false) bool isStarred,
    @Default(false) bool isViewOnce,
    int? disappearsAt,
    @Default(false) bool isDeleted,
  }) = _Message;

  /// Deserializes from JSON.
  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
