// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ContactMatchImpl _$$ContactMatchImplFromJson(Map<String, dynamic> json) =>
    _$ContactMatchImpl(
      userId: json['userId'] as String,
      phoneHash: json['phoneHash'] as String,
      displayNameEncrypted: json['displayNameEncrypted'] as String?,
    );

Map<String, dynamic> _$$ContactMatchImplToJson(_$ContactMatchImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'phoneHash': instance.phoneHash,
      'displayNameEncrypted': instance.displayNameEncrypted,
    };
