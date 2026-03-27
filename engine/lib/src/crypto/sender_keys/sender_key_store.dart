import 'package:hello_engine/src/crypto/keys/key_types.dart';

/// Abstract interface for persisting Sender Key records.
///
/// Each group member distributes a Sender Key to other members via
/// the 1:1 Double Ratchet channel. This store holds those records
/// for encryption and decryption of group messages.
abstract class SenderKeyStore {
  /// Stores a Sender Key record for a specific group member.
  ///
  /// The [groupId] identifies the group, and [senderId] identifies
  /// the member whose Sender Key this is.
  Future<void> storeSenderKey(
    String groupId,
    String senderId,
    SenderKeyRecord record,
  );

  /// Loads a previously stored Sender Key record, or null if not found.
  Future<SenderKeyRecord?> loadSenderKey(String groupId, String senderId);

  /// Deletes a Sender Key record (e.g., when a member leaves the group
  /// or their key is rotated).
  Future<void> deleteSenderKey(String groupId, String senderId);
}
