// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decision_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DecisionItemImpl _$$DecisionItemImplFromJson(Map<String, dynamic> json) =>
    _$DecisionItemImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      state: json['state'] as String,
      weightedScore: (json['weightedScore'] as num?)?.toDouble() ?? 0.0,
      agreementScore: (json['agreementScore'] as num?)?.toDouble() ?? 0.0,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      isLocked: json['isLocked'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      proposedBy: json['proposedBy'] as String?,
    );

Map<String, dynamic> _$$DecisionItemImplToJson(_$DecisionItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'state': instance.state,
      'weightedScore': instance.weightedScore,
      'agreementScore': instance.agreementScore,
      'reactions': instance.reactions,
      'isLocked': instance.isLocked,
      'photoUrl': instance.photoUrl,
      'proposedBy': instance.proposedBy,
    };
