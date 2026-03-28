import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:e2ee_chat_sdk/src/sync/deduplication_set.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/message_envelope.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/realtime_event.dart';
import 'package:e2ee_chat_sdk/src/transport/supabase_client.dart';

/// Result of processing an incoming message notification.
///
/// Contains the raw ciphertext data for the caller to decrypt. The
/// actual decryption is performed by the messaging service (which has
/// access to the full crypto layer), not by the processor itself.
class ProcessedMessageResult {
  /// Creates a [ProcessedMessageResult].
  const ProcessedMessageResult({
    required this.event,
    required this.ciphertext,
    required this.ratchetHeader,
    required this.isGroupMessage,
  });

  /// The original Realtime event.
  final RealtimeMessageEvent event;

  /// Base64-encoded ciphertext for our device.
  final String ciphertext;

  /// Base64-encoded ratchet header, if present.
  final String? ratchetHeader;

  /// Whether this is a group message (recipient is [groupRecipientSentinel]).
  final bool isGroupMessage;
}

/// Processes incoming message notifications from Realtime.
///
/// Handles deduplication, plaintext cache lookup, ciphertext fetching,
/// and recipient matching. The actual decryption is left to the caller
/// (the messaging service) which has access to the crypto layer.
class MessageProcessor {
  /// Creates a [MessageProcessor].
  MessageProcessor({
    required SupabaseClientWrapper apiClient,
    required DecryptedMessageRepository decryptedCache,
    required String myUserId,
    required int myDeviceId,
  })  : _apiClient = apiClient,
        _decryptedCache = decryptedCache,
        _myUserId = myUserId,
        _myDeviceId = myDeviceId;

  final SupabaseClientWrapper _apiClient;
  final DecryptedMessageRepository _decryptedCache;
  final String _myUserId;
  final int _myDeviceId;

  /// Per-conversation deduplication sets. Keyed by space ID.
  final Map<String, DeduplicationSet> _dedupSets =
      <String, DeduplicationSet>{};

  /// Returns the deduplication set for [groupId], creating one if needed.
  DeduplicationSet _dedupFor(String groupId) {
    return _dedupSets.putIfAbsent(groupId, DeduplicationSet.new);
  }

  /// Processes an incoming message notification from Realtime.
  ///
  /// Returns a [ProcessedMessageResult] containing the ciphertext for
  /// our device if the message is new and addressed to us. Returns
  /// `null` if:
  /// - The message is a duplicate (already seen in the dedup set).
  /// - The plaintext is already cached (previously decrypted).
  /// - No ciphertext targets our device.
  /// - The sender is ourselves.
  Future<ProcessedMessageResult?> processIncomingMessage(
    RealtimeMessageEvent event,
  ) async {
    // Skip our own messages.
    if (event.senderId == _myUserId) return null;

    // Dedup check (per-conversation LRU).
    if (!_dedupFor(event.groupId).tryAdd(event.messageId)) return null;

    // Check plaintext cache -- if already decrypted, skip.
    final cached =
        await _decryptedCache.getCachedPlaintext(event.messageId);
    if (cached != null) return null;

    // Fetch ciphertexts from server.
    final ciphertexts =
        await _apiClient.fetchCiphertexts(event.messageId);

    // Find the ciphertext addressed to us.
    final ourCt = _findOurCiphertext(ciphertexts);
    if (ourCt == null) return null;

    final recipientId = ourCt['recipient_id'] as String;

    return ProcessedMessageResult(
      event: event,
      ciphertext: ourCt['ciphertext'] as String,
      ratchetHeader: ourCt['ratchet_header'] as String?,
      isGroupMessage: recipientId == groupRecipientSentinel,
    );
  }

  /// Finds the ciphertext row addressed to our device.
  ///
  /// For 1:1 messages: matches recipient_id == myUserId AND
  /// recipient_device_id == myDeviceId.
  /// For group messages: matches recipient_id == '_group_'.
  Map<String, dynamic>? _findOurCiphertext(
    List<Map<String, dynamic>> ciphertexts,
  ) {
    for (final ct in ciphertexts) {
      final recipientId = ct['recipient_id'] as String;
      if (recipientId == groupRecipientSentinel) return ct;

      final recipientDeviceId = ct['recipient_device_id'] as int;
      if (recipientId == _myUserId &&
          recipientDeviceId == _myDeviceId) {
        return ct;
      }
    }
    return null;
  }

  /// Clears all deduplication state. Call on logout or full reset.
  void clearDedup() {
    for (final set in _dedupSets.values) {
      set.clear();
    }
    _dedupSets.clear();
  }
}
