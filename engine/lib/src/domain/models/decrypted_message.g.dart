// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decrypted_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LinkPreviewImpl _$$LinkPreviewImplFromJson(Map<String, dynamic> json) =>
    _$LinkPreviewImpl(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      aesKeyBase64: json['aesKeyBase64'] as String?,
      ivBase64: json['ivBase64'] as String?,
      mimeType: json['mimeType'] as String?,
      inlineThumbnail: json['inlineThumbnail'] as String?,
    );

Map<String, dynamic> _$$LinkPreviewImplToJson(_$LinkPreviewImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'title': instance.title,
      'description': instance.description,
      'mediaUrl': instance.mediaUrl,
      'aesKeyBase64': instance.aesKeyBase64,
      'ivBase64': instance.ivBase64,
      'mimeType': instance.mimeType,
      'inlineThumbnail': instance.inlineThumbnail,
    };

_$DecryptedMessageImpl _$$DecryptedMessageImplFromJson(
        Map<String, dynamic> json) =>
    _$DecryptedMessageImpl(
      text: json['text'] as String,
      replyTo: json['replyTo'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      type: json['type'] as String? ?? 'message',
      aesKeyBase64: json['aesKeyBase64'] as String?,
      ivBase64: json['ivBase64'] as String?,
      mimeType: json['mimeType'] as String?,
      inlineThumbnail: json['inlineThumbnail'] as String?,
      linkPreview: json['linkPreview'] == null
          ? null
          : LinkPreview.fromJson(json['linkPreview'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$DecryptedMessageImplToJson(
        _$DecryptedMessageImpl instance) =>
    <String, dynamic>{
      'text': instance.text,
      'replyTo': instance.replyTo,
      'mediaUrl': instance.mediaUrl,
      'type': instance.type,
      'aesKeyBase64': instance.aesKeyBase64,
      'ivBase64': instance.ivBase64,
      'mimeType': instance.mimeType,
      'inlineThumbnail': instance.inlineThumbnail,
      'linkPreview': instance.linkPreview?.toJson(),
    };
