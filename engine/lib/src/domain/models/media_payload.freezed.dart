// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MediaPayload {
  Uint8List get bytes => throw _privateConstructorUsedError;
  String get mimeType => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  Uint8List? get thumbnailBytes => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  int? get width => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;

  /// Create a copy of MediaPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaPayloadCopyWith<MediaPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaPayloadCopyWith<$Res> {
  factory $MediaPayloadCopyWith(
          MediaPayload value, $Res Function(MediaPayload) then) =
      _$MediaPayloadCopyWithImpl<$Res, MediaPayload>;
  @useResult
  $Res call(
      {Uint8List bytes,
      String mimeType,
      String fileName,
      Uint8List? thumbnailBytes,
      int? durationMs,
      int? width,
      int? height});
}

/// @nodoc
class _$MediaPayloadCopyWithImpl<$Res, $Val extends MediaPayload>
    implements $MediaPayloadCopyWith<$Res> {
  _$MediaPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bytes = null,
    Object? mimeType = null,
    Object? fileName = null,
    Object? thumbnailBytes = freezed,
    Object? durationMs = freezed,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_value.copyWith(
      bytes: null == bytes
          ? _value.bytes
          : bytes // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailBytes: freezed == thumbnailBytes
          ? _value.thumbnailBytes
          : thumbnailBytes // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
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
abstract class _$$MediaPayloadImplCopyWith<$Res>
    implements $MediaPayloadCopyWith<$Res> {
  factory _$$MediaPayloadImplCopyWith(
          _$MediaPayloadImpl value, $Res Function(_$MediaPayloadImpl) then) =
      __$$MediaPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Uint8List bytes,
      String mimeType,
      String fileName,
      Uint8List? thumbnailBytes,
      int? durationMs,
      int? width,
      int? height});
}

/// @nodoc
class __$$MediaPayloadImplCopyWithImpl<$Res>
    extends _$MediaPayloadCopyWithImpl<$Res, _$MediaPayloadImpl>
    implements _$$MediaPayloadImplCopyWith<$Res> {
  __$$MediaPayloadImplCopyWithImpl(
      _$MediaPayloadImpl _value, $Res Function(_$MediaPayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of MediaPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bytes = null,
    Object? mimeType = null,
    Object? fileName = null,
    Object? thumbnailBytes = freezed,
    Object? durationMs = freezed,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_$MediaPayloadImpl(
      bytes: null == bytes
          ? _value.bytes
          : bytes // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailBytes: freezed == thumbnailBytes
          ? _value.thumbnailBytes
          : thumbnailBytes // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
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

class _$MediaPayloadImpl implements _MediaPayload {
  const _$MediaPayloadImpl(
      {required this.bytes,
      required this.mimeType,
      required this.fileName,
      this.thumbnailBytes,
      this.durationMs,
      this.width,
      this.height});

  @override
  final Uint8List bytes;
  @override
  final String mimeType;
  @override
  final String fileName;
  @override
  final Uint8List? thumbnailBytes;
  @override
  final int? durationMs;
  @override
  final int? width;
  @override
  final int? height;

  @override
  String toString() {
    return 'MediaPayload(bytes: $bytes, mimeType: $mimeType, fileName: $fileName, thumbnailBytes: $thumbnailBytes, durationMs: $durationMs, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaPayloadImpl &&
            const DeepCollectionEquality().equals(other.bytes, bytes) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            const DeepCollectionEquality()
                .equals(other.thumbnailBytes, thumbnailBytes) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(bytes),
      mimeType,
      fileName,
      const DeepCollectionEquality().hash(thumbnailBytes),
      durationMs,
      width,
      height);

  /// Create a copy of MediaPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaPayloadImplCopyWith<_$MediaPayloadImpl> get copyWith =>
      __$$MediaPayloadImplCopyWithImpl<_$MediaPayloadImpl>(this, _$identity);
}

abstract class _MediaPayload implements MediaPayload {
  const factory _MediaPayload(
      {required final Uint8List bytes,
      required final String mimeType,
      required final String fileName,
      final Uint8List? thumbnailBytes,
      final int? durationMs,
      final int? width,
      final int? height}) = _$MediaPayloadImpl;

  @override
  Uint8List get bytes;
  @override
  String get mimeType;
  @override
  String get fileName;
  @override
  Uint8List? get thumbnailBytes;
  @override
  int? get durationMs;
  @override
  int? get width;
  @override
  int? get height;

  /// Create a copy of MediaPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaPayloadImplCopyWith<_$MediaPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
