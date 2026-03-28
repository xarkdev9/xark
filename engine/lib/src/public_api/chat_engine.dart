import 'package:e2ee_chat_sdk/src/devices/device_registry.dart';
import 'package:e2ee_chat_sdk/src/domain/models/chat_engine_error.dart';
import 'package:e2ee_chat_sdk/src/domain/models/connection_state.dart';
import 'package:e2ee_chat_sdk/src/domain/models/contact_match.dart';
import 'package:e2ee_chat_sdk/src/domain/models/conversation.dart';
import 'package:e2ee_chat_sdk/src/domain/models/hello_response_chunk.dart';
import 'package:e2ee_chat_sdk/src/domain/models/invite_link.dart';
import 'package:e2ee_chat_sdk/src/domain/models/join_result.dart';
import 'package:e2ee_chat_sdk/src/domain/models/user_profile.dart';
import 'package:e2ee_chat_sdk/src/public_api/chat_session.dart';

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

  /// Get a user's profile.
  Future<UserProfile> getProfile(String userId);

  /// Update the current user's profile.
  Future<void> updateProfile({String? displayName, String? photoUrl});

  /// Get all devices for the current user.
  Future<List<DeviceInfo>> getDevices();

  /// Unlink (revoke) a device.
  Future<void> unlinkDevice(int deviceId);

  /// Get a cached display name for a user.
  Future<String> getDisplayName(String userId);

  /// Create a new group conversation.
  Future<Conversation> createGroup({required String title, String? atmosphere});

  /// Stream AI responses from @hello (SSE).
  ///
  /// The engine handles auth tokens and SSE parsing.
  /// UI passes ONLY the prompt -- NEVER decrypted message history.
  Stream<HelloResponseChunk> streamHelloResponse({
    required String prompt,
    required String groupId,
  });

  /// Generate a cryptographic invite link.
  Future<InviteLink> generateInvite();

  /// Claim an invite link and join the group.
  Future<JoinResult> claimInvite(String code);
}
