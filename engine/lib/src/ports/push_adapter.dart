/// Pluggable push notification adapter.
///
/// Customers can implement this for FCM, OneSignal, Pusher, or custom push.
/// The engine calls these methods -- it never imports a specific push SDK
/// directly.
abstract class PushAdapter {
  /// Get the current push token.
  Future<String?> getToken();

  /// Listen for token refresh events.
  Stream<String> get onTokenRefresh;

  /// Register for push notifications.
  Future<void> initialize();

  /// Clean up resources.
  Future<void> dispose();
}
