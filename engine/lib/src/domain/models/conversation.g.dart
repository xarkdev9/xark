// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConversationImpl _$$ConversationImplFromJson(Map<String, dynamic> json) =>
    _$ConversationImpl(
      id: json['id'] as String,
      type: $enumDecode(_$ConversationTypeEnumMap, json['type']),
      participantIds: (json['participantIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastMessageId: json['lastMessageId'] as String?,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageTimestamp: json['lastMessageTimestamp'] == null
          ? null
          : DateTime.parse(json['lastMessageTimestamp'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      muteUntil: json['muteUntil'] == null
          ? null
          : DateTime.parse(json['muteUntil'] as String),
      disappearingMessageTimerMs:
          (json['disappearingMessageTimerMs'] as num?)?.toInt(),
      isEncrypted: json['isEncrypted'] as bool? ?? true,
    );

Map<String, dynamic> _$$ConversationImplToJson(_$ConversationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ConversationTypeEnumMap[instance.type]!,
      'participantIds': instance.participantIds,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'lastMessageId': instance.lastMessageId,
      'lastMessageText': instance.lastMessageText,
      'lastMessageTimestamp': instance.lastMessageTimestamp?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'isPinned': instance.isPinned,
      'isArchived': instance.isArchived,
      'isMuted': instance.isMuted,
      'muteUntil': instance.muteUntil?.toIso8601String(),
      'disappearingMessageTimerMs': instance.disappearingMessageTimerMs,
      'isEncrypted': instance.isEncrypted,
    };

const _$ConversationTypeEnumMap = {
  ConversationType.oneToOne: 'oneToOne',
  ConversationType.group: 'group',
};
