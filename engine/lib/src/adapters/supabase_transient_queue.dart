import 'package:e2ee_chat_sdk/src/ports/transient_queue.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';

/// Supabase implementation of [TransientQueue].
///
/// Messages sit in `message_ciphertexts` until read.
/// The atomic send RPC handles enqueue -- this adapter provides the
/// dequeue/ack abstraction for the port interface.
///
/// Future: Redis/ScyllaDB queue with auto-delete on ACK.
class SupabaseTransientQueue implements TransientQueue {
  /// Creates a [SupabaseTransientQueue].
  ///
  /// The [client] is retained for future queue-drain operations
  /// (e.g. fetching unread ciphertexts per device).
  SupabaseTransientQueue(this._client);

  // ignore: unused_field
  final SupabaseClientWrapper _client;

  @override
  Future<void> enqueue(
    String recipientDeviceId,
    Map<String, dynamic> payload,
  ) async {
    // In the Supabase model, messages are stored in message_ciphertexts
    // by the atomic send RPC. This is a no-op -- the RPC handles enqueue.
  }

  @override
  Future<List<QueuedMessage>> dequeue(
    String deviceId, {
    int limit = 100,
  }) async {
    // Fetch unread ciphertexts for this device via the message table.
    // The actual ciphertext fetch is done per-message after realtime
    // notification. Placeholder for the full queue-drain pattern.
    return <QueuedMessage>[];
  }

  @override
  Future<void> acknowledge(
    String deviceId,
    List<String> messageIds,
  ) async {
    // In the Supabase model, acknowledgment is via read receipts.
    // Future: Redis auto-delete on ACK.
  }

  @override
  Future<int> getQueueDepth(String deviceId) async {
    // Placeholder -- count unread ciphertexts for this device.
    return 0;
  }
}
