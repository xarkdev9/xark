// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DistributionCiphertextImpl _$$DistributionCiphertextImplFromJson(
        Map<String, dynamic> json) =>
    _$DistributionCiphertextImpl(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      recipientDeviceId: (json['recipient_device_id'] as num).toInt(),
      ciphertext: json['ciphertext'] as String,
      ratchetHeader: json['ratchet_header'] as String?,
    );

Map<String, dynamic> _$$DistributionCiphertextImplToJson(
        _$DistributionCiphertextImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'recipient_id': instance.recipientId,
      'recipient_device_id': instance.recipientDeviceId,
      'ciphertext': instance.ciphertext,
      'ratchet_header': instance.ratchetHeader,
    };

_$MessageEnvelopeImpl _$$MessageEnvelopeImplFromJson(
        Map<String, dynamic> json) =>
    _$MessageEnvelopeImpl(
      groupId: json['group_id'] as String,
      senderDeviceId: (json['sender_device_id'] as num).toInt(),
      ciphertext: json['ciphertext'] as String,
      recipientId: json['recipient_id'] as String,
      recipientDeviceId: (json['recipient_device_id'] as num).toInt(),
      ratchetHeader: json['ratchet_header'] as String?,
      distributionCiphertexts: (json['distribution_ciphertexts']
                  as List<dynamic>?)
              ?.map((e) =>
                  DistributionCiphertext.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      messageType: json['message_type'] as String? ?? 'e2ee',
      id: json['id'] as String?,
    );

Map<String, dynamic> _$$MessageEnvelopeImplToJson(
        _$MessageEnvelopeImpl instance) =>
    <String, dynamic>{
      'group_id': instance.groupId,
      'sender_device_id': instance.senderDeviceId,
      'ciphertext': instance.ciphertext,
      'recipient_id': instance.recipientId,
      'recipient_device_id': instance.recipientDeviceId,
      'ratchet_header': instance.ratchetHeader,
      'distribution_ciphertexts':
          instance.distributionCiphertexts.map((e) => e.toJson()).toList(),
      'message_type': instance.messageType,
      'id': instance.id,
    };
