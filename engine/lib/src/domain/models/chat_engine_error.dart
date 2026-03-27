/// Base class for all typed errors surfaced by the chat engine.
///
/// Uses Dart's `sealed` class feature for exhaustive pattern matching.
/// The UI decides how to render each error -- the engine never shows
/// toasts, dialogs, or snackbars.
sealed class ChatEngineError implements Exception {
  /// Creates a [ChatEngineError].
  const ChatEngineError();
}

// ---------------------------------------------------------------------------
// Crypto errors
// ---------------------------------------------------------------------------

/// No ratchet session exists for the target device -- trigger X3DH.
class SessionNotFound extends ChatEngineError {
  /// Creates a [SessionNotFound] error.
  const SessionNotFound(this.recipientDeviceId);

  /// The device ID that has no session.
  final String recipientDeviceId;
}

/// Ciphertext could not be decrypted (corrupt or out-of-order ratchet).
class DecryptionFailed extends ChatEngineError {
  /// Creates a [DecryptionFailed] error.
  const DecryptionFailed(this.messageId);

  /// The message that could not be decrypted.
  final String messageId;
}

/// The server has no remaining one-time PreKeys for the target user.
class PreKeyExhausted extends ChatEngineError {
  /// Creates a [PreKeyExhausted] error.
  const PreKeyExhausted(this.userId);

  /// The user whose PreKeys are exhausted.
  final String userId;
}

/// The peer's identity key has changed (possible MITM attack).
class KeyVerificationFailed extends ChatEngineError {
  /// Creates a [KeyVerificationFailed] error.
  const KeyVerificationFailed(this.userId);

  /// The user whose identity key changed.
  final String userId;
}

// ---------------------------------------------------------------------------
// Transport errors
// ---------------------------------------------------------------------------

/// The WebSocket connection was dropped.
class ConnectionLost extends ChatEngineError {
  /// Creates a [ConnectionLost] error.
  const ConnectionLost();
}

/// The server did not respond within the timeout window.
class ConnectionTimeout extends ChatEngineError {
  /// Creates a [ConnectionTimeout] error.
  const ConnectionTimeout();
}

/// The server returned a non-2xx HTTP response.
class ServerError extends ChatEngineError {
  /// Creates a [ServerError].
  const ServerError(this.statusCode, this.body);

  /// HTTP status code.
  final int statusCode;

  /// Response body.
  final String body;
}

// ---------------------------------------------------------------------------
// Auth errors
// ---------------------------------------------------------------------------

/// The auth token has expired -- the host must provide a fresh one.
class AuthTokenExpired extends ChatEngineError {
  /// Creates an [AuthTokenExpired] error.
  const AuthTokenExpired();
}

/// This device has been unlinked remotely.
class DeviceRevoked extends ChatEngineError {
  /// Creates a [DeviceRevoked] error.
  const DeviceRevoked(this.deviceId);

  /// The device that was revoked.
  final String deviceId;
}

// ---------------------------------------------------------------------------
// Storage errors
// ---------------------------------------------------------------------------

/// SQLCipher integrity check failed.
class DatabaseCorrupted extends ChatEngineError {
  /// Creates a [DatabaseCorrupted] error.
  const DatabaseCorrupted();
}

/// Device biometric/PIN is unavailable -- cannot unlock the encrypted DB.
class BiometricUnavailable extends ChatEngineError {
  /// Creates a [BiometricUnavailable] error.
  const BiometricUnavailable();
}

/// Device storage is insufficient.
class StorageFull extends ChatEngineError {
  /// Creates a [StorageFull] error.
  const StorageFull();
}

// ---------------------------------------------------------------------------
// Media errors
// ---------------------------------------------------------------------------

/// Encrypted media blob upload failed (retryable).
class MediaUploadFailed extends ChatEngineError {
  /// Creates a [MediaUploadFailed] error.
  const MediaUploadFailed(this.mediaId);

  /// The media that failed to upload.
  final String mediaId;
}

/// Encrypted media blob download failed (retryable).
class MediaDownloadFailed extends ChatEngineError {
  /// Creates a [MediaDownloadFailed] error.
  const MediaDownloadFailed(this.url);

  /// The URL that could not be downloaded.
  final String url;
}

/// AES key mismatch or corrupt blob during media decryption.
class MediaDecryptionFailed extends ChatEngineError {
  /// Creates a [MediaDecryptionFailed] error.
  const MediaDecryptionFailed(this.mediaId);

  /// The media that could not be decrypted.
  final String mediaId;
}

// ---------------------------------------------------------------------------
// Sync errors
// ---------------------------------------------------------------------------

/// Too many messages queued in the outbox (>500).
class OutboxFull extends ChatEngineError {
  /// Creates an [OutboxFull] error.
  const OutboxFull(this.pendingCount);

  /// Number of pending messages.
  final int pendingCount;
}

/// A message with this ID has already been processed -- safe to ignore.
class DuplicateMessage extends ChatEngineError {
  /// Creates a [DuplicateMessage] error.
  const DuplicateMessage(this.messageId);

  /// The duplicate message ID.
  final String messageId;
}
