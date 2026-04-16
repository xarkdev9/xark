// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decision_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DecisionItemImpl _$$DecisionItemImplFromJson(Map<String, dynamic> json) =>
    _$DecisionItemImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      ciphertextPayload: json['ciphertextPayload'] as String,
      nonce: json['nonce'] as String,
      commitmentCiphertext: json['commitmentCiphertext'] as String?,
      commitmentNonce: json['commitmentNonce'] as String?,
      state: json['state'] as String,
      weightedScore: (json['weightedScore'] as num?)?.toDouble() ?? 0.0,
      agreementScore: (json['agreementScore'] as num?)?.toDouble() ?? 0.0,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      isLocked: json['isLocked'] as bool? ?? false,
      proposedBy: json['proposedBy'] as String?,
    );

Map<String, dynamic> _$$DecisionItemImplToJson(_$DecisionItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'ciphertextPayload': instance.ciphertextPayload,
      'nonce': instance.nonce,
      'commitmentCiphertext': instance.commitmentCiphertext,
      'commitmentNonce': instance.commitmentNonce,
      'state': instance.state,
      'weightedScore': instance.weightedScore,
      'agreementScore': instance.agreementScore,
      'reactions': instance.reactions,
      'isLocked': instance.isLocked,
      'proposedBy': instance.proposedBy,
    };
