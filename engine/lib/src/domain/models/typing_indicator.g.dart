// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'typing_indicator.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TypingIndicatorImpl _$$TypingIndicatorImplFromJson(
        Map<String, dynamic> json) =>
    _$TypingIndicatorImpl(
      conversationId: json['conversationId'] as String,
      userId: json['userId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
    );

Map<String, dynamic> _$$TypingIndicatorImplToJson(
        _$TypingIndicatorImpl instance) =>
    <String, dynamic>{
      'conversationId': instance.conversationId,
      'userId': instance.userId,
      'startedAt': instance.startedAt.toIso8601String(),
    };
