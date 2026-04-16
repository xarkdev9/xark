/// Device linking protocol for Sesame multi-device.
/// Primary device generates QR code, new device scans it.

import 'dart:convert';
import 'dart:typed_data';

/// Represents a device linking request, encoded as a QR code payload.
class LinkingRequest {
  /// Creates a [LinkingRequest].
  const LinkingRequest({
    required this.userId,
    required this.linkingSecret,
    required this.serverUrl,
    required this.primaryDeviceId,
  });

  /// Deserializes from a QR code payload string.
  factory LinkingRequest.fromQrPayload(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return LinkingRequest(
      userId: json['u'] as String,
      linkingSecret: json['s'] as String,
      serverUrl: json['url'] as String,
      primaryDeviceId: json['pd'] as int,
    );
  }

  /// The user ID of the account being linked.
  final String userId;

  /// 32-byte random secret (base64-encoded), used as pre-shared key
  /// for the encrypted transfer channel.
  final String linkingSecret;

  /// Server base URL for the new device to connect to.
  final String serverUrl;

  /// Device ID of the primary device initiating the link.
  final int primaryDeviceId;

  /// Encode to QR code payload string.
  String toQrPayload() => jsonEncode(<String, dynamic>{
        'u': userId,
        's': linkingSecret,
        'url': serverUrl,
        'pd': primaryDeviceId,
      });
}

/// States of the device linking process.
enum LinkingState {
  /// No linking in progress.
  idle,

  /// Primary device is displaying QR code, waiting for scan.
  waitingForScan,

  /// Verifying the new device's identity key fingerprint.
  verifying,

  /// Transferring encrypted message history to the new device.
  transferringHistory,

  /// Linking completed successfully.
  complete,

  /// Linking failed.
  failed,
}

/// Abstract device linking protocol.
///
/// The primary device generates a linking request (displayed as QR code).
/// The new device scans the QR, registers with the server, and receives
/// encrypted history from the primary device.
abstract class DeviceLinking {
  /// Primary device: generate linking request (displayed as QR code).
  Future<LinkingRequest> generateLinkingRequest();

  /// New device: process scanned QR code, register with server.
  Future<void> processLinkingRequest(LinkingRequest request);

  /// Primary device: verify the new device's identity key fingerprint.
  Future<bool> verifyNewDevice(
    int newDeviceId,
    Uint8List identityKeyFingerprint,
  );

  /// Primary device: transfer encrypted message history to new device.
  /// Uses the linking secret as a pre-shared key for the transfer channel.
  Future<void> transferHistory(int newDeviceId, String linkingSecret);

  /// Current linking state stream.
  Stream<LinkingState> get linkingState;
}
