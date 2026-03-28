import 'package:e2ee_chat_sdk/src/ports/message_gateway.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';

/// Supabase implementation of [MessageGateway].
///
/// Uses [SupabaseClientWrapper] for all message operations.
/// This is the default adapter -- customers can swap it for any backend.
class SupabaseMessageGateway implements MessageGateway {
  /// Creates a [SupabaseMessageGateway].
  SupabaseMessageGateway(this._client);

  final SupabaseClientWrapper _client;

  @override
  Future<SendResult> sendMessage(Map<String, dynamic> envelope) async {
    // Convert the raw map into a typed MessageEnvelope for the client.
    final typedEnvelope = MessageEnvelope.fromJson(envelope);
    final response = await _client.sendMessage(typedEnvelope);
    return SendResult(
      messageId: response['message_id'] as String? ?? '',
      serverSeq: response['server_seq'] as int? ?? 0,
      createdAt: DateTime.tryParse(
            response['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      status: response['status'] as String? ?? 'inserted',
    );
  }

  @override
  Future<MessagePage> fetchMessages(
    String groupId, {
    String? cursor,
    SyncDirection direction = SyncDirection.forward,
    int limit = 50,
  }) async {
    // The cursor is an ISO-8601 timestamp string for pagination.
    final after =
        cursor != null ? DateTime.tryParse(cursor) : null;
    final messages = await _client.fetchMessageHistory(
      groupId,
      after: after,
      limit: limit,
    );

    // Derive next cursor from the latest created_at in the page.
    String? nextCursor;
    if (messages.isNotEmpty) {
      final timestamps = messages
          .map((m) => m['created_at'] as String?)
          .whereType<String>()
          .toList();
      if (timestamps.isNotEmpty) {
        timestamps.sort();
        nextCursor = timestamps.last;
      }
    }

    return MessagePage(messages: messages, nextCursor: nextCursor);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCiphertexts(
    String messageId,
    String recipientId,
    int deviceId,
  ) async {
    // SupabaseClientWrapper.fetchCiphertexts queries by messageId.
    // RLS on the server filters to the authenticated user's device rows.
    return _client.fetchCiphertexts(messageId);
  }

  @override
  Future<void> acknowledgeDelivery(String messageId, int deviceId) async {
    // Delivery acknowledgment is handled by the realtime gateway
    // via receipt broadcasts -- not a direct DB write.
  }
}
