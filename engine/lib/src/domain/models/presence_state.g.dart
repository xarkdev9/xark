// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PresenceStateImpl _$$PresenceStateImplFromJson(Map<String, dynamic> json) =>
    _$PresenceStateImpl(
      userId: json['userId'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.parse(json['lastSeenAt'] as String),
      visibility: $enumDecodeNullable(
              _$PresenceVisibilityEnumMap, json['visibility']) ??
          PresenceVisibility.everyone,
    );

Map<String, dynamic> _$$PresenceStateImplToJson(_$PresenceStateImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'isOnline': instance.isOnline,
      'lastSeenAt': instance.lastSeenAt?.toIso8601String(),
      'visibility': _$PresenceVisibilityEnumMap[instance.visibility]!,
    };

const _$PresenceVisibilityEnumMap = {
  PresenceVisibility.everyone: 'everyone',
  PresenceVisibility.contacts: 'contacts',
  PresenceVisibility.nobody: 'nobody',
};
