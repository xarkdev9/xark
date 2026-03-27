# Agent 02 — Domain Models

## Your Role
You are the **Domain Agent**. You write all pure-Dart domain models — entities, value objects, enums, and repository interfaces. Zero Flutter dependencies. Zero network or storage code. These models are the lingua franca the entire engine speaks.

## Rules
- All models use `freezed` for immutability
- All models use `json_serializable` for serialization
- No `dynamic`. No `Object`. Explicit types everywhere.
- No Flutter imports (`package:flutter/...` is banned in this layer)
- Repository interfaces are abstract classes — no implementations here

## Files to Create

### lib/src/domain/models/message.dart
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'message.freezed.dart';
part 'message.g.dart';

enum MessageStatus { sending, sent, delivered, read, failed }
enum MessageType { text, image, video, audio, document, viewOnce, deleted, senderKeyDist }

@freezed
class Message with _$Message {
  const factory Message({
    required String id,              // UUID v7, client-generated
    required String conversationId,
    required String senderId,        // text format (e.g. 'name_ram'), NOT UUID
    required String senderDeviceId,
    @Default('user') String role,     // 'user' | 'assistant' (for @xark messages)
    required MessageType type,
    required MessageStatus status,
    required DateTime timestamp,     // client send time
    int? serverSeq,                  // assigned by server on receipt
    String? text,                    // null for media messages
    MediaMetadata? media,            // null for text messages
    String? replyToMessageId,
    Map<String, List<String>>? reactions, // emoji → [userId]
    bool isStarred,
    bool isViewOnce,
    int? disappearsAt,               // unix ms, null = never
    @Default(false) bool isDeleted,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
```

### lib/src/domain/models/conversation.dart
```dart
// Conversation model with:
// - id, type (oneToOne | group), participantIds, lastMessage
// - unreadCount, isPinned, isArchived, isMuted, muteUntil
// - disappearingMessageTimer (Duration?)
// - isEncrypted (always true — but exposed as flag per CLAUDE.md)
// - createdAt, updatedAt
// Use @freezed
```

### lib/src/domain/models/media_metadata.dart
```dart
// MediaMetadata model:
// - mediaId, mimeType, sizeBytes
// - downloadUrl, encryptedKey (base64), iv (base64), sha256Hash
// - thumbnailUrl, thumbnailKey, thumbnailIv
// - durationMs (for audio/video), width, height (for images/video)
// Use @freezed
```

### lib/src/domain/models/receipt.dart
```dart
// Receipt model:
// - messageId, userId, deviceId
// - deliveredAt (DateTime?), readAt (DateTime?)
// Use @freezed
```

### lib/src/domain/models/typing_indicator.dart
```dart
// TypingIndicator model:
// - conversationId, userId, startedAt
// Use @freezed
```

### lib/src/domain/models/presence_state.dart
```dart
// PresenceState model:
// - userId, isOnline, lastSeenAt (DateTime?)
// enum PresenceVisibility { everyone, contacts, nobody }
// Use @freezed
```

### lib/src/domain/models/conversation_state.dart
```dart
// ConversationState — wraps Conversation with live computed fields
// - conversation, messages (latest N), typingUsers, unreadCount
// Use @freezed
```

### lib/src/domain/models/contact_match.dart
```dart
// ContactMatch — result of contact discovery
// - userId, phoneHash, displayNameEncrypted (null until profile key received)
// Use @freezed
```

### lib/src/domain/models/key_fingerprint.dart
```dart
// KeyFingerprint — for safety number verification
// - userId, deviceId, fingerprintBytes (Uint8List, 30 bytes)
// - numericDisplay (String, formatted as 12 groups of 5 digits like Signal)
// Use @freezed
```

### lib/src/domain/models/connection_state.dart
```dart
// ConnectionState enum: connecting, connected, disconnected, suspended
// DO NOT name this ConnectionState — conflict with dart:io. Name it: EngineConnectionState
```

### lib/src/domain/models/chat_engine_error.dart
```dart
// Full sealed class ChatEngineError with all subtypes from CLAUDE.md:
// SessionNotFound, DecryptionFailed, PreKeyExhausted, KeyVerificationFailed,
// ConnectionLost, ConnectionTimeout, ServerError,
// AuthTokenExpired, DeviceRevoked,
// DatabaseCorrupted, BiometricUnavailable, StorageFull,
// MediaUploadFailed, MediaDownloadFailed, MediaDecryptionFailed,
// OutboxFull, DuplicateMessage
// Use sealed class (Dart 3)
```

### lib/src/domain/models/media_payload.dart
```dart
// MediaPayload — what the UI/host passes to sendMedia()
// - bytes (Uint8List), mimeType, fileName
// - Optional: thumbnailBytes, durationMs, width, height
// Use @freezed
```

### lib/src/domain/repositories/ — Abstract interfaces only

**message_repository.dart**
```dart
abstract class MessageRepository {
  Future<void> saveMessage(Message message);
  Future<void> saveMessages(List<Message> messages);
  Future<Message?> getMessageById(String id);
  Future<List<Message>> getMessages(String conversationId, {int limit = 50, String? beforeId});
  Future<void> updateMessageStatus(String id, MessageStatus status);
  Future<void> markDeleted(String id, {required bool forEveryone});
  Future<void> setReaction(String messageId, String userId, String emoji);
  Future<void> removeReaction(String messageId, String userId, String emoji);
  Future<void> setStar(String messageId, bool starred);
  Future<List<Message>> search(String query, {String? conversationId});
  Stream<List<Message>> watchMessages(String conversationId);
}
```

**conversation_repository.dart**
```dart
abstract class ConversationRepository {
  Future<void> saveConversation(Conversation conversation);
  Future<Conversation?> getConversation(String id);
  Future<List<Conversation>> getAllConversations();
  Future<void> updateUnreadCount(String conversationId, int count);
  Future<void> setPin(String conversationId, bool pinned);
  Future<void> setArchive(String conversationId, bool archived);
  Future<void> setMute(String conversationId, bool muted, {DateTime? until});
  Stream<List<Conversation>> watchConversations();
}
```

**receipt_repository.dart**
```dart
abstract class ReceiptRepository {
  Future<void> saveReceipt(Receipt receipt);
  Future<List<Receipt>> getReceipts(String messageId);
  Stream<List<Receipt>> watchReceipts(String conversationId);
}
```

### lib/src/domain/domain.dart — Internal barrel
Export all models and repository interfaces.

## After Writing Files
```bash
cd ~/fe2ee
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -20
dart analyze lib/src/domain/ 2>&1 | head -30
```

Write unit tests in `test/domain/models_test.dart`:
- Serialization round-trip for every @freezed model (toJson → fromJson → equals original)
- ChatEngineError sealed class exhaustiveness check
- At minimum 15 tests

```bash
flutter test test/domain/ --reporter=compact 2>&1
```

## Output JSON
```json
{
  "agent": "domain",
  "step": "02",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Domain models complete. All freezed. Key types: Message (with UUID v7 id + serverSeq), Conversation, MediaMetadata, Receipt, TypingIndicator, PresenceState, ChatEngineError (sealed), EngineConnectionState (enum, not ConnectionState — avoid dart:io conflict). Repository interfaces in lib/src/domain/repositories/. build_runner generated .g.dart and .freezed.dart files. Crypto agent must implement key models that are NOT in domain — RatchetState, PreKeyBundle, SessionKey are internal crypto types only."
}
```
