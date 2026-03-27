import 'package:hello_engine/src/domain/models/chat_engine_error.dart';
import 'package:hello_engine/src/domain/models/connection_state.dart';
import 'package:hello_engine/src/domain/models/contact_match.dart';
import 'package:hello_engine/src/domain/models/conversation.dart';
import 'package:hello_engine/src/public_api/chat_session.dart';

/// The top-level handle to the E2EE chat engine.
///
/// There should be only one active instance per app.
/// All interaction with the engine flows through this class and
/// [ChatSession] instances obtained via [getSession].
abstract class ChatEngine {
  /// Returns a session handle for [groupId].
  ///
  /// Sessions are cached -- calling twice with the same ID returns
  /// the same instance.
  ChatSession getSession(String groupId);

  /// All conversations, sorted: pinned first, then by updatedAt
  /// descending.
  Stream<List<Conversation>> get conversations;

  /// Current network connection state.
  Stream<EngineConnectionState> get connectionState;

  /// Total unread count across all conversations.
  Stream<int> get totalUnreadCount;

  /// All errors surfaced by the engine.
  Stream<ChatEngineError> get errors;

  /// Discover which phone hashes correspond to registered users.
  Future<List<ContactMatch>> discoverContacts(List<String> phoneHashes);

  /// Update the FCM/APNs push token.
  Future<void> updatePushToken(String newToken);

  /// Pause sync when app is backgrounded.
  Future<void> suspend();

  /// Resume sync when app is foregrounded.
  Future<void> resume();

  /// Full teardown. Zeroes key material in memory.
  Future<void> dispose();
}
