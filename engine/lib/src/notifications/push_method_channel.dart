import 'package:e2ee_chat_sdk/src/notifications/push_decryptor.dart';
import 'package:flutter/services.dart';

/// Flutter method channel bridge for background push decryption.
///
/// Native code (iOS NSE, Android Service) calls this channel to decrypt
/// E2EE push payloads. The engine handles the crypto; native code handles
/// the notification display.
///
/// Channel name: 'com.e2ee_chat.push_decrypt'
///
/// Methods:
///   'decryptPush' -> accepts Map payload -> returns Map result
///     The payload must contain: ciphertext, nonce, sender_id, group_id,
///     message_id. The engine opens the encrypted DB, loads the ratchet
///     session, decrypts, and returns sender name + preview text.
///   'getDecryptionReady' -> returns bool (engine crypto available?)

class PushMethodChannel {
  static const _channel = MethodChannel('com.e2ee_chat.push_decrypt');
  static bool _initialized = false;

  /// Initialize the method channel handler.
  /// Call this during engine initialization.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'decryptPush':
        return _handleDecryptPush(call.arguments);
      case 'getDecryptionReady':
        return true; // Engine is ready if this handler is registered
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  static Future<Map<String, dynamic>> _handleDecryptPush(
    dynamic arguments,
  ) async {
    try {
      final args = Map<String, dynamic>.from(arguments as Map);
      final payload = PushPayload.fromMap(args);

      // Calls the real decryptPushPayload which opens the encrypted DB,
      // loads ratchet state, decrypts via DoubleRatchet, and persists
      // the updated ratchet state. Returns sender name + preview on
      // success, or a safe fallback on any failure.
      final result = await decryptPushPayload(payload);

      return {
        'senderName': result.senderName,
        'messagePreview': result.messagePreview,
        'groupId': result.groupId,
        'messageId': result.messageId,
        'decrypted': result.decrypted,
        if (result.error != null) 'error': result.error,
      };
    } catch (e) {
      return {
        'senderName': 'hello',
        'messagePreview': 'You may have new messages',
        'groupId': '',
        'messageId': '',
        'decrypted': false,
        'error': e.toString(),
      };
    }
  }

  /// Dispose the channel handler.
  static void dispose() {
    _channel.setMethodCallHandler(null);
    _initialized = false;
  }
}
