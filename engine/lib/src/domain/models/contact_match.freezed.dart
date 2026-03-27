// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact_match.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ContactMatch _$ContactMatchFromJson(Map<String, dynamic> json) {
  return _ContactMatch.fromJson(json);
}

/// @nodoc
mixin _$ContactMatch {
  String get userId => throw _privateConstructorUsedError;
  String get phoneHash => throw _privateConstructorUsedError;
  String? get displayNameEncrypted => throw _privateConstructorUsedError;

  /// Serializes this ContactMatch to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ContactMatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContactMatchCopyWith<ContactMatch> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContactMatchCopyWith<$Res> {
  factory $ContactMatchCopyWith(
          ContactMatch value, $Res Function(ContactMatch) then) =
      _$ContactMatchCopyWithImpl<$Res, ContactMatch>;
  @useResult
  $Res call({String userId, String phoneHash, String? displayNameEncrypted});
}

/// @nodoc
class _$ContactMatchCopyWithImpl<$Res, $Val extends ContactMatch>
    implements $ContactMatchCopyWith<$Res> {
  _$ContactMatchCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContactMatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? phoneHash = null,
    Object? displayNameEncrypted = freezed,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      phoneHash: null == phoneHash
          ? _value.phoneHash
          : phoneHash // ignore: cast_nullable_to_non_nullable
              as String,
      displayNameEncrypted: freezed == displayNameEncrypted
          ? _value.displayNameEncrypted
          : displayNameEncrypted // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ContactMatchImplCopyWith<$Res>
    implements $ContactMatchCopyWith<$Res> {
  factory _$$ContactMatchImplCopyWith(
          _$ContactMatchImpl value, $Res Function(_$ContactMatchImpl) then) =
      __$$ContactMatchImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String userId, String phoneHash, String? displayNameEncrypted});
}

/// @nodoc
class __$$ContactMatchImplCopyWithImpl<$Res>
    extends _$ContactMatchCopyWithImpl<$Res, _$ContactMatchImpl>
    implements _$$ContactMatchImplCopyWith<$Res> {
  __$$ContactMatchImplCopyWithImpl(
      _$ContactMatchImpl _value, $Res Function(_$ContactMatchImpl) _then)
      : super(_value, _then);

  /// Create a copy of ContactMatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? phoneHash = null,
    Object? displayNameEncrypted = freezed,
  }) {
    return _then(_$ContactMatchImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      phoneHash: null == phoneHash
          ? _value.phoneHash
          : phoneHash // ignore: cast_nullable_to_non_nullable
              as String,
      displayNameEncrypted: freezed == displayNameEncrypted
          ? _value.displayNameEncrypted
          : displayNameEncrypted // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ContactMatchImpl implements _ContactMatch {
  const _$ContactMatchImpl(
      {required this.userId,
      required this.phoneHash,
      this.displayNameEncrypted});

  factory _$ContactMatchImpl.fromJson(Map<String, dynamic> json) =>
      _$$ContactMatchImplFromJson(json);

  @override
  final String userId;
  @override
  final String phoneHash;
  @override
  final String? displayNameEncrypted;

  @override
  String toString() {
    return 'ContactMatch(userId: $userId, phoneHash: $phoneHash, displayNameEncrypted: $displayNameEncrypted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContactMatchImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.phoneHash, phoneHash) ||
                other.phoneHash == phoneHash) &&
            (identical(other.displayNameEncrypted, displayNameEncrypted) ||
                other.displayNameEncrypted == displayNameEncrypted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, phoneHash, displayNameEncrypted);

  /// Create a copy of ContactMatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContactMatchImplCopyWith<_$ContactMatchImpl> get copyWith =>
      __$$ContactMatchImplCopyWithImpl<_$ContactMatchImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ContactMatchImplToJson(
      this,
    );
  }
}

abstract class _ContactMatch implements ContactMatch {
  const factory _ContactMatch(
      {required final String userId,
      required final String phoneHash,
      final String? displayNameEncrypted}) = _$ContactMatchImpl;

  factory _ContactMatch.fromJson(Map<String, dynamic> json) =
      _$ContactMatchImpl.fromJson;

  @override
  String get userId;
  @override
  String get phoneHash;
  @override
  String? get displayNameEncrypted;

  /// Create a copy of ContactMatch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContactMatchImplCopyWith<_$ContactMatchImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
