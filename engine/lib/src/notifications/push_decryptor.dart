import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/keys/database_key_manager.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/ratchet/double_ratchet.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/database_factory.dart';

/// Result of attempting to decrypt a push notification payload.
///
/// On success, [decrypted] is true and [senderName] / [messagePreview]
/// contain the plaintext for display.
/// On failure, use [PushDecryptResult.fallback] which shows a generic
/// "You may have new messages" notification.
class PushDecryptResult {
  /// Creates a [PushDecryptResult].
  const PushDecryptResult({
    required this.senderName,
    required this.messagePreview,
    required this.groupId,
    required this.messageId,
    required this.decrypted,
    this.error,
  });

  /// Creates a fallback result for when decryption fails.
  ///
  /// The notification will show "You may have new messages" with no
  /// sender information. Error details are never exposed to the user.
  factory PushDecryptResult.fallback({
    String groupId = '',
    String messageId = '',
    String? error,
  }) =>
      PushDecryptResult(
        senderName: 'hello',
        messagePreview: 'You may have new messages',
        groupId: groupId,
        messageId: messageId,
        decrypted: false,
        error: error,
      );

  /// Sender display name (decrypted from payload or fallback).
  final String senderName;

  /// Message preview text (decrypted from payload or fallback).
  final String messagePreview;

  /// The group/conversation this message belongs to.
  final String groupId;

  /// Unique message identifier.
  final String messageId;

  /// Whether the payload was successfully decrypted.
  final bool decrypted;

  /// Internal error description (never shown to user).
  final String? error;
}

/// Push payload received from FCM data message.
///
/// Contains the E2EE ciphertext embedded in the push payload
/// (zero-network architecture -- no fetch needed).
class PushPayload {
  /// Creates a [PushPayload].
  const PushPayload({
    required this.recipientDeviceId,
    required this.messageId,
    required this.groupId,
    required this.encryptedPayload,
    required this.ratchetHeader,
  });

  /// Deserialises a [PushPayload] from a map (FCM data payload).
  factory PushPayload.fromMap(Map<String, dynamic> map) => PushPayload(
        recipientDeviceId: map['recipientDeviceId'] as int? ?? 0,
        messageId: map['messageId'] as String? ??
            map['message_id'] as String? ??
            '',
        groupId: map['groupId'] as String? ??
            map['group_id'] as String? ??
            '',
        encryptedPayload: map['encryptedPayload'] as String? ??
            map['ciphertext'] as String? ??
            '',
        ratchetHeader: map['ratchetHeader'] as String? ??
            map['nonce'] as String? ??
            '',
      );

  /// Device ID this ciphertext was encrypted for.
  final int recipientDeviceId;

  /// Unique message identifier.
  final String messageId;

  /// Group/conversation ID.
  final String groupId;

  /// Base64-encoded ciphertext.
  final String encryptedPayload;

  /// Base64-encoded ratchet header (encrypted).
  final String ratchetHeader;
}

/// Attempt to decrypt a push notification payload.
///
/// Opens the encrypted database, loads the ratchet session for the sender,
/// decrypts the ciphertext, extracts the sender name and message preview,
/// saves the updated ratchet state, and closes the database.
///
/// Returns a [PushDecryptResult] with plaintext on success, or a fallback
/// on any failure. Never throws -- all exceptions are caught and returned
/// as [PushDecryptResult.fallback].
///
/// This function is designed to be called from:
/// - The FCM background handler (e2eeBackgroundMessageHandler)
/// - iOS NotificationServiceExtension (via Flutter method channel)
/// - Android FirebaseMessagingService (via headless Dart isolate)
Future<PushDecryptResult> decryptPushPayload(PushPayload payload) async {
  AppDatabase? db;
  try {
    // Step 1: Get the SQLCipher database encryption key from the
    // platform keychain (iOS Keychain / Android Keystore).
    final dbKey = await DatabaseKeyManager.getOrCreateKey();

    // Step 2: Open the database using the same factory and path as
    // the main app (e2ee_chat.db in app documents directory).
    db = await DatabaseFactory.create(encryptionKey: dbKey);

    // Step 3: Load the ratchet session for this sender from the DB.
    // The session ID format is "senderId:deviceId" for 1:1 DMs.
    // For group messages, it's the groupId.
    final sessionId = payload.groupId;
    final sessionRow = await (db.select(db.ratchetSessions)
          ..where((s) => s.sessionId.equals(sessionId)))
        .getSingleOrNull();

    if (sessionRow == null) {
      return PushDecryptResult.fallback(
        groupId: payload.groupId,
        messageId: payload.messageId,
        error: 'No ratchet session found for $sessionId',
      );
    }

    // Step 4: Deserialise the ratchet state from the encrypted blob.
    final stateJson =
        jsonDecode(utf8.decode(sessionRow.encryptedState))
            as Map<String, dynamic>;
    final ratchetState = _deserialiseRatchetState(stateJson);

    // Step 5: Decrypt the message. Single message, <1ms.
    final ciphertext = base64Decode(payload.encryptedPayload);
    final encryptedHeader = base64Decode(payload.ratchetHeader);

    final decryptResult = await DoubleRatchet.decrypt(
      ratchetState,
      Uint8List.fromList(ciphertext),
      Uint8List.fromList(encryptedHeader),
    );

    // Step 6: Parse the decrypted plaintext to extract sender name
    // and message preview.
    final plaintext = utf8.decode(decryptResult.plaintext);
    String senderName;
    String messagePreview;

    try {
      final messageJson =
          jsonDecode(plaintext) as Map<String, dynamic>;
      senderName =
          messageJson['sender_name'] as String? ??
          messageJson['senderName'] as String? ??
          'Chat';
      messagePreview =
          messageJson['content'] as String? ??
          messageJson['text'] as String? ??
          messageJson['body'] as String? ??
          plaintext;
    } catch (_) {
      // Plaintext is not JSON -- use it directly as preview.
      senderName = 'Chat';
      messagePreview = plaintext;
    }

    // Truncate preview to a reasonable length for notification display.
    if (messagePreview.length > 100) {
      messagePreview = '${messagePreview.substring(0, 97)}...';
    }

    // Step 7: Save the updated ratchet state to the database.
    final newStateJson = _serialiseRatchetState(decryptResult.newState);
    await db.into(db.ratchetSessions).insertOnConflictUpdate(
          RatchetSessionsCompanion.insert(
            sessionId: sessionId,
            encryptedState:
                Uint8List.fromList(utf8.encode(jsonEncode(newStateJson))),
            updatedAt: DateTime.now(),
          ),
        );

    // Step 8: Close the database.
    await db.close();

    return PushDecryptResult(
      senderName: senderName,
      messagePreview: messagePreview,
      groupId: payload.groupId,
      messageId: payload.messageId,
      decrypted: true,
    );
  } catch (e) {
    // Close database if it was opened.
    try {
      await db?.close();
    } catch (_) {
      // Ignore close errors.
    }

    return PushDecryptResult.fallback(
      groupId: payload.groupId,
      messageId: payload.messageId,
      error: e.toString(),
    );
  }
}

/// Deserialises a [RatchetState] from a JSON map stored in the database.
RatchetState _deserialiseRatchetState(Map<String, dynamic> json) {
  return RatchetState(
    rootKey: _decodeBytes(json['rootKey']),
    headerSecret: _decodeBytes(json['headerSecret']),
    sendChainKey: json['sendChainKey'] != null
        ? _decodeBytes(json['sendChainKey'])
        : null,
    recvChainKey: json['recvChainKey'] != null
        ? _decodeBytes(json['recvChainKey'])
        : null,
    sendRatchetKeyPair: json['sendRatchetKeyPair'] != null
        ? RatchetKeyPair(
            publicKey: _decodeBytes(
              (json['sendRatchetKeyPair']
                  as Map<String, dynamic>)['publicKey'],
            ),
            privateKey: _decodeBytes(
              (json['sendRatchetKeyPair']
                  as Map<String, dynamic>)['privateKey'],
            ),
          )
        : null,
    recvRatchetPublicKey: json['recvRatchetPublicKey'] != null
        ? _decodeBytes(json['recvRatchetPublicKey'])
        : null,
    sendMessageNumber: json['sendMessageNumber'] as int? ?? 0,
    recvMessageNumber: json['recvMessageNumber'] as int? ?? 0,
    previousSendCount: json['previousSendCount'] as int? ?? 0,
    skippedKeys: _deserialiseSkippedKeys(json['skippedKeys']),
  );
}

/// Serialises a [RatchetState] to a JSON-compatible map for DB storage.
Map<String, dynamic> _serialiseRatchetState(RatchetState state) {
  return <String, dynamic>{
    'rootKey': base64Encode(state.rootKey),
    'headerSecret': base64Encode(state.headerSecret),
    if (state.sendChainKey != null)
      'sendChainKey': base64Encode(state.sendChainKey!),
    if (state.recvChainKey != null)
      'recvChainKey': base64Encode(state.recvChainKey!),
    if (state.sendRatchetKeyPair != null)
      'sendRatchetKeyPair': <String, dynamic>{
        'publicKey': base64Encode(state.sendRatchetKeyPair!.publicKey),
        'privateKey': base64Encode(state.sendRatchetKeyPair!.privateKey),
      },
    if (state.recvRatchetPublicKey != null)
      'recvRatchetPublicKey': base64Encode(state.recvRatchetPublicKey!),
    'sendMessageNumber': state.sendMessageNumber,
    'recvMessageNumber': state.recvMessageNumber,
    'previousSendCount': state.previousSendCount,
    'skippedKeys': _serialiseSkippedKeys(state.skippedKeys),
  };
}

Uint8List _decodeBytes(dynamic value) {
  if (value is List<int>) return Uint8List.fromList(value);
  if (value is String) return Uint8List.fromList(base64Decode(value));
  return Uint8List(0);
}

Map<String, Uint8List> _deserialiseSkippedKeys(dynamic value) {
  if (value == null) return <String, Uint8List>{};
  if (value is! Map) return <String, Uint8List>{};
  return (value as Map<String, dynamic>).map(
    (key, v) => MapEntry(key, _decodeBytes(v)),
  );
}

Map<String, String> _serialiseSkippedKeys(Map<String, Uint8List> keys) {
  return keys.map((key, value) => MapEntry(key, base64Encode(value)));
}
