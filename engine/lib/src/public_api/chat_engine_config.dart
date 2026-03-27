import 'package:hello_engine/src/observer/chat_engine_observer.dart';

/// Configuration for initializing the chat engine.
///
/// The host app provides these values at startup. All required fields
/// must be supplied -- the engine does not authenticate or register
/// users itself.
///
/// This class is re-exported from the public barrel file
/// (`chat_engine.dart`) and is the canonical location for the
/// configuration type.
class ChatEngineConfig {
  /// Creates a [ChatEngineConfig].
  const ChatEngineConfig({
    required this.authToken,
    required this.userId,
    required this.deviceId,
    required this.pushToken,
    required this.serverBaseUrl,
    this.supabaseAnonKey = '',
    this.observer,
  });

  /// Opaque auth token from the host's authentication system.
  final String authToken;

  /// Authenticated user ID.
  final String userId;

  /// Unique per-device identifier (integer, matching backend schema).
  final int deviceId;

  /// FCM/APNs push notification token.
  final String pushToken;

  /// Server base URL for WebSocket + REST connections.
  final Uri serverBaseUrl;

  /// Supabase anonymous key for PostgREST access.
  final String supabaseAnonKey;

  /// Optional diagnostics observer.
  final ChatEngineObserver? observer;
}
