// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'presence_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PresenceState _$PresenceStateFromJson(Map<String, dynamic> json) {
  return _PresenceState.fromJson(json);
}

/// @nodoc
mixin _$PresenceState {
  String get userId => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  DateTime? get lastSeenAt => throw _privateConstructorUsedError;
  PresenceVisibility get visibility => throw _privateConstructorUsedError;

  /// Serializes this PresenceState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PresenceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PresenceStateCopyWith<PresenceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PresenceStateCopyWith<$Res> {
  factory $PresenceStateCopyWith(
          PresenceState value, $Res Function(PresenceState) then) =
      _$PresenceStateCopyWithImpl<$Res, PresenceState>;
  @useResult
  $Res call(
      {String userId,
      bool isOnline,
      DateTime? lastSeenAt,
      PresenceVisibility visibility});
}

/// @nodoc
class _$PresenceStateCopyWithImpl<$Res, $Val extends PresenceState>
    implements $PresenceStateCopyWith<$Res> {
  _$PresenceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PresenceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? isOnline = null,
    Object? lastSeenAt = freezed,
    Object? visibility = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeenAt: freezed == lastSeenAt
          ? _value.lastSeenAt
          : lastSeenAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as PresenceVisibility,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PresenceStateImplCopyWith<$Res>
    implements $PresenceStateCopyWith<$Res> {
  factory _$$PresenceStateImplCopyWith(
          _$PresenceStateImpl value, $Res Function(_$PresenceStateImpl) then) =
      __$$PresenceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      bool isOnline,
      DateTime? lastSeenAt,
      PresenceVisibility visibility});
}

/// @nodoc
class __$$PresenceStateImplCopyWithImpl<$Res>
    extends _$PresenceStateCopyWithImpl<$Res, _$PresenceStateImpl>
    implements _$$PresenceStateImplCopyWith<$Res> {
  __$$PresenceStateImplCopyWithImpl(
      _$PresenceStateImpl _value, $Res Function(_$PresenceStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PresenceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? isOnline = null,
    Object? lastSeenAt = freezed,
    Object? visibility = null,
  }) {
    return _then(_$PresenceStateImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeenAt: freezed == lastSeenAt
          ? _value.lastSeenAt
          : lastSeenAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as PresenceVisibility,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PresenceStateImpl implements _PresenceState {
  const _$PresenceStateImpl(
      {required this.userId,
      this.isOnline = false,
      this.lastSeenAt,
      this.visibility = PresenceVisibility.everyone});

  factory _$PresenceStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PresenceStateImplFromJson(json);

  @override
  final String userId;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final DateTime? lastSeenAt;
  @override
  @JsonKey()
  final PresenceVisibility visibility;

  @override
  String toString() {
    return 'PresenceState(userId: $userId, isOnline: $isOnline, lastSeenAt: $lastSeenAt, visibility: $visibility)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PresenceStateImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeenAt, lastSeenAt) ||
                other.lastSeenAt == lastSeenAt) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, isOnline, lastSeenAt, visibility);

  /// Create a copy of PresenceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PresenceStateImplCopyWith<_$PresenceStateImpl> get copyWith =>
      __$$PresenceStateImplCopyWithImpl<_$PresenceStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PresenceStateImplToJson(
      this,
    );
  }
}

abstract class _PresenceState implements PresenceState {
  const factory _PresenceState(
      {required final String userId,
      final bool isOnline,
      final DateTime? lastSeenAt,
      final PresenceVisibility visibility}) = _$PresenceStateImpl;

  factory _PresenceState.fromJson(Map<String, dynamic> json) =
      _$PresenceStateImpl.fromJson;

  @override
  String get userId;
  @override
  bool get isOnline;
  @override
  DateTime? get lastSeenAt;
  @override
  PresenceVisibility get visibility;

  /// Create a copy of PresenceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PresenceStateImplCopyWith<_$PresenceStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
