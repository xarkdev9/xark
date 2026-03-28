import 'package:flutter/services.dart';
import 'push_decryptor.dart';

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
///   'getDecryptionReady' -> returns bool (crypto isolate available?)

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
        'senderName': 'Chat',
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
