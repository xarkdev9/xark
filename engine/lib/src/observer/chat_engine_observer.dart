import 'package:hello_engine/src/domain/models/chat_engine_error.dart';
import 'package:hello_engine/src/domain/models/connection_state.dart';

/// Observer interface for engine-wide diagnostic events.
///
/// All methods have no-op defaults so callers can override only
/// the callbacks they care about.
///
/// **Never log plaintext, keys, or user content** in observer callbacks
/// -- only event names, IDs, counts, and durations.
abstract class ChatEngineObserver {
  /// Called when a Double Ratchet session is established with a peer.
  void onSessionEstablished(String userId, int deviceId) {}

  /// Called when a session establishment attempt fails.
  void onSessionFailed(
    String userId,
    int deviceId,
    ChatEngineError error,
  ) {}

  /// Called after one-time pre-keys are replenished on the server.
  void onPreKeyReplenishment(int keysUploaded, int keysRemaining) {}

  /// Called after a gap-fill sync completes.
  void onSyncCompleted(int messagesPulled, Duration elapsed) {}

  /// Called after the outbox has been fully drained.
  void onOutboxDrained(int messagesSent, int messagesFailed) {}

  /// Called each time the Double Ratchet advances a chain step.
  void onRatchetAdvanced(String sessionId, int chainIndex) {}

  /// Called after a media blob is uploaded.
  void onMediaUpload(String mediaId, int bytes, Duration elapsed) {}

  /// Called after a media blob is downloaded.
  void onMediaDownload(String mediaId, int bytes, Duration elapsed) {}

  /// Called when the WebSocket connection state changes.
  void onWebSocketStateChange(
    EngineConnectionState from,
    EngineConnectionState to,
  ) {}

  /// Called after a contact discovery request completes.
  void onContactDiscovery(int hashesSent, int matchesFound) {}

  /// Called when a user's profile key is rotated.
  void onProfileKeyRotation(String userId) {}

  /// Called when a new device is linked.
  void onDeviceLinked(String deviceId) {}

  /// Called when a device is revoked.
  void onDeviceRevoked(String deviceId) {}
}
