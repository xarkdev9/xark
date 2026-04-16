import 'dart:async';
import 'dart:ui' show IsolateNameServer;

import 'package:e2ee_chat_sdk/src/notifications/push_decryptor.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Name of the IsolateNameServer port registered by the main engine.
///
/// When the main app is alive (suspended or active), the background
/// handler sends push data through this port instead of touching the
/// database directly. This prevents ratchet state forks.
const String mainEnginePortName = 'main_engine_port';

/// Notification channel ID for Android.
const String _channelId = 'e2ee_chat_messages';

/// Notification channel name for Android.
const String _channelName = 'Messages';

/// Top-level function -- must be outside any class for FCM background handler.
///
/// Zero-network architecture: the ciphertext is embedded in the FCM data
/// payload (up to 4KB). No network calls are made in this background handler.
///
/// Ratchet fork prevention: if the main app is alive (suspended in RAM),
/// the handler hands off the payload via [IsolateNameServer] port. The main
/// thread decrypts atomically with its own in-memory ratchet state.
/// If the main app is dead, the handler owns the database exclusively.
@pragma('vm:entry-point')
Future<void> e2eeBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  if (data['type'] != 'e2ee_message') {
    // Not an E2EE message (tickle or other event) -- show generic notification
    await _showFallbackNotification();
    return;
  }

  try {
    final ciphertextBase64 = data['ciphertext'] as String?;
    final nonceBase64 = data['nonce'] as String?;
    final senderId = data['sender_id'] as String?;
    final groupId = data['group_id'] as String?;
    final messageId = data['message_id'] as String?;

    if (ciphertextBase64 == null || nonceBase64 == null) {
      await _showFallbackNotification();
      return;
    }

    // Step 1: Check if main app is alive via IsolateNameServer.
    // This is a single in-memory lookup -- microseconds, zero network.
    final mainPort =
        IsolateNameServer.lookupPortByName(mainEnginePortName);

    if (mainPort != null) {
      // HAND OFF to main thread -- prevents ratchet fork.
      // Main thread will decrypt and show notification.
      mainPort.send(<String, dynamic>{
        'type': 'push_decrypt',
        'message_id': messageId ?? '',
        'sender_id': senderId ?? '',
        'group_id': groupId ?? '',
        'ciphertext': ciphertextBase64,
        'nonce': nonceBase64,
      });
      // Background handler returns immediately. Main thread handles the rest.
      return;
    }

    // Step 2: Main app is dead -- decrypt locally.
    // We own the database exclusively, so no ratchet fork is possible.
    await _decryptAndNotify(
      messageId: messageId ?? '',
      senderId: senderId ?? '',
      groupId: groupId ?? '',
      ciphertextBase64: ciphertextBase64,
      nonceBase64: nonceBase64,
    );
  } catch (_) {
    // Any exception at any step -> show generic notification.
    // Never expose error details. Never block.
    await _showFallbackNotification();
  }
}

/// Decrypts the push payload locally and shows a notification with
/// sender name and message preview.
///
/// Only called when the main app is dead (killed by OS). The background
/// handler owns the database exclusively in this path.
Future<void> _decryptAndNotify({
  required String messageId,
  required String senderId,
  required String groupId,
  required String ciphertextBase64,
  required String nonceBase64,
}) async {
  try {
    final payload = PushPayload(
      recipientDeviceId: 0,
      messageId: messageId,
      groupId: groupId,
      encryptedPayload: ciphertextBase64,
      ratchetHeader: nonceBase64,
    );

    final result = await decryptPushPayload(payload);

    if (result.decrypted) {
      await _showDecryptedNotification(
        senderName: result.senderName,
        messagePreview: result.messagePreview,
        groupId: result.groupId,
        messageId: result.messageId,
      );
    } else {
      await _showFallbackNotification();
    }
  } catch (_) {
    await _showFallbackNotification();
  }
}

/// Shows a notification with decrypted sender name and message preview.
Future<void> _showDecryptedNotification({
  required String senderName,
  required String messagePreview,
  required String groupId,
  required String messageId,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.show(
    messageId.hashCode,
    senderName,
    messagePreview,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

/// Shows a generic "You may have new messages" notification.
///
/// Used as the fallback when:
/// - The push payload is not an E2EE message
/// - Decryption fails for any reason
/// - The payload is malformed or missing fields
Future<void> _showFallbackNotification() async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch % 100000,
    'hello',
    'You may have new messages',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}
