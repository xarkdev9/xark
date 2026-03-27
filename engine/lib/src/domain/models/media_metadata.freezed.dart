// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MediaMetadata _$MediaMetadataFromJson(Map<String, dynamic> json) {
  return _MediaMetadata.fromJson(json);
}

/// @nodoc
mixin _$MediaMetadata {
  String get mediaId => throw _privateConstructorUsedError;
  String get mimeType => throw _privateConstructorUsedError;
  int get sizeBytes => throw _privateConstructorUsedError;
  String? get downloadUrl => throw _privateConstructorUsedError;

  /// Base64-encoded AES-256-GCM key.
  String? get encryptedKey => throw _privateConstructorUsedError;

  /// Base64-encoded initialization vector.
  String? get iv => throw _privateConstructorUsedError;
  String? get sha256Hash => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  String? get thumbnailKey => throw _privateConstructorUsedError;
  String? get thumbnailIv => throw _privateConstructorUsedError;

  /// Base64-encoded JPEG thumbnail (backwards compat with React).
  String? get inlineThumbnail => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  int? get width => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;

  /// Serializes this MediaMetadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MediaMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaMetadataCopyWith<MediaMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaMetadataCopyWith<$Res> {
  factory $MediaMetadataCopyWith(
          MediaMetadata value, $Res Function(MediaMetadata) then) =
      _$MediaMetadataCopyWithImpl<$Res, MediaMetadata>;
  @useResult
  $Res call(
      {String mediaId,
      String mimeType,
      int sizeBytes,
      String? downloadUrl,
      String? encryptedKey,
      String? iv,
      String? sha256Hash,
      String? thumbnailUrl,
      String? thumbnailKey,
      String? thumbnailIv,
      String? inlineThumbnail,
      int? durationMs,
      int? width,
      int? height});
}

/// @nodoc
class _$MediaMetadataCopyWithImpl<$Res, $Val extends MediaMetadata>
    implements $MediaMetadataCopyWith<$Res> {
  _$MediaMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mediaId = null,
    Object? mimeType = null,
    Object? sizeBytes = null,
    Object? downloadUrl = freezed,
    Object? encryptedKey = freezed,
    Object? iv = freezed,
    Object? sha256Hash = freezed,
    Object? thumbnailUrl = freezed,
    Object? thumbnailKey = freezed,
    Object? thumbnailIv = freezed,
    Object? inlineThumbnail = freezed,
    Object? durationMs = freezed,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_value.copyWith(
      mediaId: null == mediaId
          ? _value.mediaId
          : mediaId // ignore: cast_nullable_to_non_nullable
              as String,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      sizeBytes: null == sizeBytes
          ? _value.sizeBytes
          : sizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      downloadUrl: freezed == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      encryptedKey: freezed == encryptedKey
          ? _value.encryptedKey
          : encryptedKey // ignore: cast_nullable_to_non_nullable
              as String?,
      iv: freezed == iv
          ? _value.iv
          : iv // ignore: cast_nullable_to_non_nullable
              as String?,
      sha256Hash: freezed == sha256Hash
          ? _value.sha256Hash
          : sha256Hash // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailKey: freezed == thumbnailKey
          ? _value.thumbnailKey
          : thumbnailKey // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailIv: freezed == thumbnailIv
          ? _value.thumbnailIv
          : thumbnailIv // ignore: cast_nullable_to_non_nullable
              as String?,
      inlineThumbnail: freezed == inlineThumbnail
          ? _value.inlineThumbnail
          : inlineThumbnail // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MediaMetadataImplCopyWith<$Res>
    implements $MediaMetadataCopyWith<$Res> {
  factory _$$MediaMetadataImplCopyWith(
          _$MediaMetadataImpl value, $Res Function(_$MediaMetadataImpl) then) =
      __$$MediaMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mediaId,
      String mimeType,
      int sizeBytes,
      String? downloadUrl,
      String? encryptedKey,
      String? iv,
      String? sha256Hash,
      String? thumbnailUrl,
      String? thumbnailKey,
      String? thumbnailIv,
      String? inlineThumbnail,
      int? durationMs,
      int? width,
      int? height});
}

/// @nodoc
class __$$MediaMetadataImplCopyWithImpl<$Res>
    extends _$MediaMetadataCopyWithImpl<$Res, _$MediaMetadataImpl>
    implements _$$MediaMetadataImplCopyWith<$Res> {
  __$$MediaMetadataImplCopyWithImpl(
      _$MediaMetadataImpl _value, $Res Function(_$MediaMetadataImpl) _then)
      : super(_value, _then);

  /// Create a copy of MediaMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mediaId = null,
    Object? mimeType = null,
    Object? sizeBytes = null,
    Object? downloadUrl = freezed,
    Object? encryptedKey = freezed,
    Object? iv = freezed,
    Object? sha256Hash = freezed,
    Object? thumbnailUrl = freezed,
    Object? thumbnailKey = freezed,
    Object? thumbnailIv = freezed,
    Object? inlineThumbnail = freezed,
    Object? durationMs = freezed,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_$MediaMetadataImpl(
      mediaId: null == mediaId
          ? _value.mediaId
          : mediaId // ignore: cast_nullable_to_non_nullable
              as String,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      sizeBytes: null == sizeBytes
          ? _value.sizeBytes
          : sizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      downloadUrl: freezed == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      encryptedKey: freezed == encryptedKey
          ? _value.encryptedKey
          : encryptedKey // ignore: cast_nullable_to_non_nullable
              as String?,
      iv: freezed == iv
          ? _value.iv
          : iv // ignore: cast_nullable_to_non_nullable
              as String?,
      sha256Hash: freezed == sha256Hash
          ? _value.sha256Hash
          : sha256Hash // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailKey: freezed == thumbnailKey
          ? _value.thumbnailKey
          : thumbnailKey // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailIv: freezed == thumbnailIv
          ? _value.thumbnailIv
          : thumbnailIv // ignore: cast_nullable_to_non_nullable
              as String?,
      inlineThumbnail: freezed == inlineThumbnail
          ? _value.inlineThumbnail
          : inlineThumbnail // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MediaMetadataImpl implements _MediaMetadata {
  const _$MediaMetadataImpl(
      {required this.mediaId,
      required this.mimeType,
      required this.sizeBytes,
      this.downloadUrl,
      this.encryptedKey,
      this.iv,
      this.sha256Hash,
      this.thumbnailUrl,
      this.thumbnailKey,
      this.thumbnailIv,
      this.inlineThumbnail,
      this.durationMs,
      this.width,
      this.height});

  factory _$MediaMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$MediaMetadataImplFromJson(json);

  @override
  final String mediaId;
  @override
  final String mimeType;
  @override
  final int sizeBytes;
  @override
  final String? downloadUrl;

  /// Base64-encoded AES-256-GCM key.
  @override
  final String? encryptedKey;

  /// Base64-encoded initialization vector.
  @override
  final String? iv;
  @override
  final String? sha256Hash;
  @override
  final String? thumbnailUrl;
  @override
  final String? thumbnailKey;
  @override
  final String? thumbnailIv;

  /// Base64-encoded JPEG thumbnail (backwards compat with React).
  @override
  final String? inlineThumbnail;
  @override
  final int? durationMs;
  @override
  final int? width;
  @override
  final int? height;

  @override
  String toString() {
    return 'MediaMetadata(mediaId: $mediaId, mimeType: $mimeType, sizeBytes: $sizeBytes, downloadUrl: $downloadUrl, encryptedKey: $encryptedKey, iv: $iv, sha256Hash: $sha256Hash, thumbnailUrl: $thumbnailUrl, thumbnailKey: $thumbnailKey, thumbnailIv: $thumbnailIv, inlineThumbnail: $inlineThumbnail, durationMs: $durationMs, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaMetadataImpl &&
            (identical(other.mediaId, mediaId) || other.mediaId == mediaId) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.encryptedKey, encryptedKey) ||
                other.encryptedKey == encryptedKey) &&
            (identical(other.iv, iv) || other.iv == iv) &&
            (identical(other.sha256Hash, sha256Hash) ||
                other.sha256Hash == sha256Hash) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.thumbnailKey, thumbnailKey) ||
                other.thumbnailKey == thumbnailKey) &&
            (identical(other.thumbnailIv, thumbnailIv) ||
                other.thumbnailIv == thumbnailIv) &&
            (identical(other.inlineThumbnail, inlineThumbnail) ||
                other.inlineThumbnail == inlineThumbnail) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      mediaId,
      mimeType,
      sizeBytes,
      downloadUrl,
      encryptedKey,
      iv,
      sha256Hash,
      thumbnailUrl,
      thumbnailKey,
      thumbnailIv,
      inlineThumbnail,
      durationMs,
      width,
      height);

  /// Create a copy of MediaMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaMetadataImplCopyWith<_$MediaMetadataImpl> get copyWith =>
      __$$MediaMetadataImplCopyWithImpl<_$MediaMetadataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MediaMetadataImplToJson(
      this,
    );
  }
}

abstract class _MediaMetadata implements MediaMetadata {
  const factory _MediaMetadata(
      {required final String mediaId,
      required final String mimeType,
      required final int sizeBytes,
      final String? downloadUrl,
      final String? encryptedKey,
      final String? iv,
      final String? sha256Hash,
      final String? thumbnailUrl,
      final String? thumbnailKey,
      final String? thumbnailIv,
      final String? inlineThumbnail,
      final int? durationMs,
      final int? width,
      final int? height}) = _$MediaMetadataImpl;

  factory _MediaMetadata.fromJson(Map<String, dynamic> json) =
      _$MediaMetadataImpl.fromJson;

  @override
  String get mediaId;
  @override
  String get mimeType;
  @override
  int get sizeBytes;
  @override
  String? get downloadUrl;

  /// Base64-encoded AES-256-GCM key.
  @override
  String? get encryptedKey;

  /// Base64-encoded initialization vector.
  @override
  String? get iv;
  @override
  String? get sha256Hash;
  @override
  String? get thumbnailUrl;
  @override
  String? get thumbnailKey;
  @override
  String? get thumbnailIv;

  /// Base64-encoded JPEG thumbnail (backwards compat with React).
  @override
  String? get inlineThumbnail;
  @override
  int? get durationMs;
  @override
  int? get width;
  @override
  int? get height;

  /// Create a copy of MediaMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaMetadataImplCopyWith<_$MediaMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
