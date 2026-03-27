/// Shared push decryption logic used by iOS NSE, Android Service,
/// and potentially web Service Worker via method channel.
///
/// This runs in a headless context — no UI, no main isolate.
/// It accesses the encrypted Drift database directly.

class PushDecryptResult {
  final String senderName;
  final String messagePreview;
  final String groupId;
  final String messageId;
  final bool decrypted;
  final String? error;

  const PushDecryptResult({
    required this.senderName,
    required this.messagePreview,
    required this.groupId,
    required this.messageId,
    required this.decrypted,
    this.error,
  });

  factory PushDecryptResult.fallback({
    required String groupId,
    required String messageId,
    String? error,
  }) =>
      PushDecryptResult(
        senderName: 'hello',
        messagePreview: 'You have a new encrypted message',
        groupId: groupId,
        messageId: messageId,
        decrypted: false,
        error: error,
      );
}

class PushPayload {
  final int recipientDeviceId;
  final String messageId;
  final String groupId;
  final String encryptedPayload;
  final String ratchetHeader;

  const PushPayload({
    required this.recipientDeviceId,
    required this.messageId,
    required this.groupId,
    required this.encryptedPayload,
    required this.ratchetHeader,
  });

  factory PushPayload.fromMap(Map<String, dynamic> map) => PushPayload(
    recipientDeviceId: map['recipientDeviceId'] as int? ?? 0,
    messageId: map['messageId'] as String? ?? '',
    groupId: map['groupId'] as String? ?? '',
    encryptedPayload: map['encryptedPayload'] as String? ?? '',
    ratchetHeader: map['ratchetHeader'] as String? ?? '',
  );
}

/// Attempt to decrypt a push notification payload.
/// Returns a result with plaintext on success, or a fallback on failure.
///
/// This function is designed to be called from:
/// - iOS NotificationServiceExtension (via Flutter method channel)
/// - Android FirebaseMessagingService (via headless Dart isolate)
/// - The crypto isolate (if available and registered via IsolateNameServer)
Future<PushDecryptResult> decryptPushPayload(PushPayload payload) async {
  try {
    // TODO: Access the crypto isolate via IsolateNameServer
    // TODO: If not available, open Drift DB directly and load ratchet state
    // TODO: Decrypt payload
    // TODO: Parse plaintext to extract sender name + message preview
    // TODO: Persist updated ratchet state

    // For now, return fallback (decryption wiring requires crypto isolate integration)
    return PushDecryptResult.fallback(
      groupId: payload.groupId,
      messageId: payload.messageId,
      error: 'Push decryption not yet wired to crypto isolate',
    );
  } catch (e) {
    return PushDecryptResult.fallback(
      groupId: payload.groupId,
      messageId: payload.messageId,
      error: e.toString(),
    );
  }
}
