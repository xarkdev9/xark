import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_envelope.freezed.dart';
part 'message_envelope.g.dart';

/// Per-device ciphertext for sender key distribution, piggybacked on a
/// group message POST.
@freezed
class DistributionCiphertext with _$DistributionCiphertext {
  /// Creates a [DistributionCiphertext].
  const factory DistributionCiphertext({
    /// Row ID, prefixed `mc_` + UUID.
    required String id,

    /// Recipient user ID.
    @JsonKey(name: 'recipient_id') required String recipientId,

    /// Recipient device ID.
    @JsonKey(name: 'recipient_device_id') required int recipientDeviceId,

    /// Base64-encoded ciphertext.
    required String ciphertext,

    /// Base64-encoded ratchet header JSON envelope.
    @JsonKey(name: 'ratchet_header') String? ratchetHeader,
  }) = _DistributionCiphertext;

  /// Deserialises from JSON.
  factory DistributionCiphertext.fromJson(Map<String, dynamic> json) =>
      _$DistributionCiphertextFromJson(json);
}

/// Wire-format envelope for `POST /api/message`.
///
/// Maps directly to the server's expected JSON body with snake_case
/// field names.
@freezed
class MessageEnvelope with _$MessageEnvelope {
  /// Creates a [MessageEnvelope].
  const factory MessageEnvelope({
    /// Conversation / space ID.
    @JsonKey(name: 'group_id') required String groupId,

    /// Sender's device ID.
    @JsonKey(name: 'sender_device_id') required int senderDeviceId,

    /// Base64-encoded ciphertext.
    required String ciphertext,

    /// For 1:1: recipient user ID. For group: `_group_`.
    @JsonKey(name: 'recipient_id') required String recipientId,

    /// For 1:1: target device ID. For group: `0`.
    @JsonKey(name: 'recipient_device_id') required int recipientDeviceId,

    /// Base64-encoded ratchet header JSON envelope.
    @JsonKey(name: 'ratchet_header') String? ratchetHeader,

    /// Sender key distributions piggybacked on group messages.
    @JsonKey(name: 'distribution_ciphertexts')
    @Default([])
    List<DistributionCiphertext> distributionCiphertexts,

    /// Wire-level message type (`e2ee`, `hello`, `sender_key_dist`, etc.).
    @JsonKey(name: 'message_type') @Default('e2ee') String messageType,

    /// Optional client-generated UUID.
    String? id,
  }) = _MessageEnvelope;

  /// Deserialises from JSON.
  factory MessageEnvelope.fromJson(Map<String, dynamic> json) =>
      _$MessageEnvelopeFromJson(json);
}

/// Sentinel value used as `recipientId` for group messages.
const String groupRecipientSentinel = '_group_';
