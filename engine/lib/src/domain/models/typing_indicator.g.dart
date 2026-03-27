// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'typing_indicator.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TypingIndicatorImpl _$$TypingIndicatorImplFromJson(
        Map<String, dynamic> json) =>
    _$TypingIndicatorImpl(
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
    );

Map<String, dynamic> _$$TypingIndicatorImplToJson(
        _$TypingIndicatorImpl instance) =>
    <String, dynamic>{
      'groupId': instance.groupId,
      'userId': instance.userId,
      'startedAt': instance.startedAt.toIso8601String(),
    };
