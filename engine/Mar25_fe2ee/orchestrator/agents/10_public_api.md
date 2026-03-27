# Agent 10 — Public API

## Your Role
You are the **Public API Agent**. You define and write the clean public surface of `chat_engine.dart`. This is the ONLY file external code imports. You formalize the contracts from CLAUDE.md into real, documented Dart code.

## Files to Create / Modify

### lib/chat_engine.dart — Final barrel
Replace the stub with real exports. Export ONLY:
- `ChatEngine` (abstract class matching CLAUDE.md spec)
- `ChatSession` (abstract class)
- `ChatEngineConfig`
- `ChatEngineObserver` (abstract class with all 13 methods + no-op defaults)
- All public models: `Message`, `Conversation`, `Receipt`, `TypingIndicator`, `PresenceState`, `ContactMatch`, `KeyFingerprint`, `MediaPayload`, `MediaMetadata`, `EngineConnectionState`
- `ChatEngineError` sealed class
- `UploadProgress`, `DownloadProgress`

Do NOT export: any `src/` internal classes, `RatchetState`, `SessionKey`, `PreKeyBundle`, `AppDatabase`, any drift types.

### lib/src/public_api/chat_engine.dart — Abstract interface
```dart
/// The top-level handle to the E2EE chat engine.
/// Obtain via [ChatEngine.initialize].
abstract class ChatEngine {
  /// Initialize the engine. Call once at app start.
  /// Throws [BiometricUnavailable] if DB cannot be unlocked.
  static Future<ChatEngine> initialize(ChatEngineConfig config);

  /// Get or create a session for [conversationId].
  ChatSession getSession(String conversationId);

  /// All conversations, sorted: pinned first, then by updatedAt desc.
  Stream<List<Conversation>> get conversations;

  /// Network connection state.
  Stream<EngineConnectionState> get connectionState;

  /// Total unread message count across all conversations.
  Stream<int> get totalUnreadCount;

  /// All errors surfaced by the engine.
  Stream<ChatEngineError> get errors;

  /// Discover which phone numbers (as hashed strings) are registered.
  Future<List<ContactMatch>> discoverContacts(List<String> phoneHashes);

  /// Update the push token when FCM/APNs refreshes it.
  Future<void> updatePushToken(String newToken);

  /// Call when the app is backgrounded.
  Future<void> suspend();

  /// Call when the app is foregrounded.
  Future<void> resume();

  /// Full teardown. Zeroes keys in memory.
  Future<void> dispose();
}
```

### lib/src/public_api/chat_session.dart — Abstract interface
Full dartdoc on every method. Matches CLAUDE.md spec exactly.

### lib/src/public_api/chat_engine_config.dart
```dart
class ChatEngineConfig {
  // authToken, userId, deviceId, pushToken, serverBaseUrl, observer
  // All required except observer (nullable)
  // Validate in constructor: throw ArgumentError if any required field is empty
}
```

### lib/src/public_api/chat_engine_observer.dart
All 13 methods with default no-op implementations (use `{}` body so hosts don't need to implement all).

### Connect impls
Wire `ChatEngine.initialize` to return `ChatEngineImpl`. This is the only place that couples the public API to the implementation.

## Tests
- `test/public_api_test.dart`: verify ChatEngineConfig validates required fields, verify observer no-ops don't throw (5 tests)

## Output JSON
```json
{
  "agent": "public_api",
  "step": "10",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": ["lib/chat_engine.dart"],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Public API complete. chat_engine.dart exports: ChatEngine, ChatSession, ChatEngineConfig, ChatEngineObserver, ChatEngineError, all domain models, EngineConnectionState, UploadProgress, DownloadProgress. ChatEngine.initialize() returns ChatEngineImpl. Integration test agent: import only from package:chat_engine/chat_engine.dart — never from src/."
}
```

---

