import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sender_key_store.dart';

/// Handles incoming SenderKeyRequest NACKs (crypto.md #19).
///
/// When a peer cannot decrypt our Sender Key messages (missed the
/// original distribution), they broadcast an `sk_request`. This
/// handler responds by preparing a [SenderKeyDistribution] from our
/// current Sender Key so the caller can encrypt it via 1:1 Double
/// Ratchet and send it to the requester.
///
/// Flow:
/// 1. [RealtimeListener] delivers [SKRecoveryRequest] via stream.
/// 2. Caller invokes [handleNack] with the request details.
/// 3. We load our current Sender Key for the group.
/// 4. Return a [SenderKeyDistribution] for the caller to encrypt
///    via Double Ratchet (1:1) and send to the requester.
///
/// The key insight: recovery uses 1:1 encryption (not group SK)
/// so the requester can always decrypt it regardless of their
/// Sender Key state. The actual encryption + transport is handled
/// by the caller (the sync/session layer), keeping this class
/// focused on the Sender Key lookup and distribution creation.
class SkRecoveryHandler {
  /// Creates an [SkRecoveryHandler].
  ///
  /// [senderKeyStore] provides access to our Sender Key records.
  SkRecoveryHandler({
    required SenderKeyStore senderKeyStore,
  }) : _senderKeyStore = senderKeyStore;

  final SenderKeyStore _senderKeyStore;

  /// Responds to a Sender Key recovery request (NACK).
  ///
  /// Loads our current Sender Key for [groupId] and returns a
  /// [SenderKeyDistribution] that the caller should encrypt via
  /// 1:1 Double Ratchet and send to the requester.
  ///
  /// Returns `null` if we don't have a Sender Key for this group
  /// (e.g., we haven't sent any messages in this group yet).
  ///
  /// [myUserId] is the current user's ID (the sender being asked).
  Future<SenderKeyDistribution?> handleNack({
    required String groupId,
    required String myUserId,
  }) async {
    // Load our current Sender Key for this group
    final record = await _senderKeyStore.loadSenderKey(
      groupId,
      myUserId,
    );

    if (record == null) {
      // We don't have a SK for this group — nothing to re-distribute.
      return null;
    }

    // Create a SenderKeyDistribution payload (public material only —
    // no private signing key, matching BUG 15 safety on the web side).
    return SenderKeyDistribution(
      chainKey: record.chainKey,
      signingPublicKey: record.signingPublicKey,
      iteration: record.iteration,
    );
  }
}
