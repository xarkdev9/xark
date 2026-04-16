/// Device registry for multi-device (Sesame protocol).
/// Each user has up to 5 linked devices, each with own crypto identity.

/// Information about a registered device.
class DeviceInfo {
  /// Creates a [DeviceInfo].
  const DeviceInfo({
    required this.deviceId,
    required this.platform,
    required this.isPrimary,
    this.lastActiveAt,
  });

  /// Deserializes from JSON (server response format).
  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        deviceId: json['device_id'] as int,
        platform: json['platform'] as String,
        isPrimary: json['is_primary'] as bool,
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.parse(json['last_active_at'] as String)
            : null,
      );

  /// Numeric device identifier (unique per user).
  final int deviceId;

  /// Platform string: 'ios', 'android', 'web', 'macos', 'windows', 'linux'.
  final String platform;

  /// Whether this is the user's primary device.
  final bool isPrimary;

  /// Last time this device was active (null if never heartbeated).
  final DateTime? lastActiveAt;
}

/// Abstract device registry for multi-device support.
///
/// Implementations handle registration, listing, and unlinking of devices
/// via the server's `user_devices` table and associated RPCs.
abstract class DeviceRegistry {
  /// Register this device with the server.
  Future<void> registerDevice(DeviceInfo device);

  /// Get all devices for a user (for fan-out encryption).
  Future<List<DeviceInfo>> getUserDevices(String userId);

  /// Unlink a device (revoke keys, remove from registry).
  Future<void> unlinkDevice(int deviceId);

  /// Get this device's info.
  DeviceInfo get currentDevice;
}
