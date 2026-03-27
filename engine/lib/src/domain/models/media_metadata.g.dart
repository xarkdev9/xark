// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MediaMetadataImpl _$$MediaMetadataImplFromJson(Map<String, dynamic> json) =>
    _$MediaMetadataImpl(
      mediaId: json['mediaId'] as String,
      mimeType: json['mimeType'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      downloadUrl: json['downloadUrl'] as String?,
      encryptedKey: json['encryptedKey'] as String?,
      iv: json['iv'] as String?,
      sha256Hash: json['sha256Hash'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      thumbnailKey: json['thumbnailKey'] as String?,
      thumbnailIv: json['thumbnailIv'] as String?,
      inlineThumbnail: json['inlineThumbnail'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$MediaMetadataImplToJson(_$MediaMetadataImpl instance) =>
    <String, dynamic>{
      'mediaId': instance.mediaId,
      'mimeType': instance.mimeType,
      'sizeBytes': instance.sizeBytes,
      'downloadUrl': instance.downloadUrl,
      'encryptedKey': instance.encryptedKey,
      'iv': instance.iv,
      'sha256Hash': instance.sha256Hash,
      'thumbnailUrl': instance.thumbnailUrl,
      'thumbnailKey': instance.thumbnailKey,
      'thumbnailIv': instance.thumbnailIv,
      'inlineThumbnail': instance.inlineThumbnail,
      'durationMs': instance.durationMs,
      'width': instance.width,
      'height': instance.height,
    };
