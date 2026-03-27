/// Engine connection state.
///
/// Named [EngineConnectionState] to avoid conflict with `dart:io`'s
/// `ConnectionState`.
enum EngineConnectionState {
  /// WebSocket is attempting to connect.
  connecting,

  /// WebSocket is connected and authenticated.
  connected,

  /// WebSocket is disconnected.
  disconnected,

  /// Engine is suspended (app backgrounded).
  suspended,
}
