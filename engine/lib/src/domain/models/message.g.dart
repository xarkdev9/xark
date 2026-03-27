// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      senderDeviceId: json['senderDeviceId'] as String,
      type: $enumDecode(_$MessageTypeEnumMap, json['type']),
      status: $enumDecode(_$MessageStatusEnumMap, json['status']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      role: json['role'] as String? ?? 'user',
      serverSeq: (json['serverSeq'] as num?)?.toInt(),
      text: json['text'] as String?,
      media: json['media'] == null
          ? null
          : MediaMetadata.fromJson(json['media'] as Map<String, dynamic>),
      replyToMessageId: json['replyToMessageId'] as String?,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
                k, (e as List<dynamic>).map((e) => e as String).toList()),
          ) ??
          const {},
      isStarred: json['isStarred'] as bool? ?? false,
      isViewOnce: json['isViewOnce'] as bool? ?? false,
      disappearsAt: (json['disappearsAt'] as num?)?.toInt(),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'senderId': instance.senderId,
      'senderDeviceId': instance.senderDeviceId,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'status': _$MessageStatusEnumMap[instance.status]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'role': instance.role,
      'serverSeq': instance.serverSeq,
      'text': instance.text,
      'media': instance.media?.toJson(),
      'replyToMessageId': instance.replyToMessageId,
      'reactions': instance.reactions,
      'isStarred': instance.isStarred,
      'isViewOnce': instance.isViewOnce,
      'disappearsAt': instance.disappearsAt,
      'isDeleted': instance.isDeleted,
    };

const _$MessageTypeEnumMap = {
  MessageType.e2ee: 'e2ee',
  MessageType.xark: 'xark',
  MessageType.system: 'system',
  MessageType.legacy: 'legacy',
  MessageType.senderKeyDist: 'sender_key_dist',
  MessageType.text: 'message',
  MessageType.media: 'media',
};

const _$MessageStatusEnumMap = {
  MessageStatus.sending: 'sending',
  MessageStatus.sent: 'sent',
  MessageStatus.delivered: 'delivered',
  MessageStatus.read: 'read',
  MessageStatus.failed: 'failed',
};
