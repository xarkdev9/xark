// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Conversation _$ConversationFromJson(Map<String, dynamic> json) {
  return _Conversation.fromJson(json);
}

/// @nodoc
mixin _$Conversation {
  String get id => throw _privateConstructorUsedError;
  ConversationType get type => throw _privateConstructorUsedError;
  List<String> get participantIds => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String? get lastMessageId => throw _privateConstructorUsedError;
  String? get lastMessageText => throw _privateConstructorUsedError;
  DateTime? get lastMessageTimestamp => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;
  bool get isPinned => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  bool get isMuted => throw _privateConstructorUsedError;
  DateTime? get muteUntil => throw _privateConstructorUsedError;
  int? get disappearingMessageTimerMs => throw _privateConstructorUsedError;
  bool get isEncrypted => throw _privateConstructorUsedError;

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Conversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationCopyWith<Conversation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationCopyWith<$Res> {
  factory $ConversationCopyWith(
          Conversation value, $Res Function(Conversation) then) =
      _$ConversationCopyWithImpl<$Res, Conversation>;
  @useResult
  $Res call(
      {String id,
      ConversationType type,
      List<String> participantIds,
      DateTime createdAt,
      DateTime updatedAt,
      String? lastMessageId,
      String? lastMessageText,
      DateTime? lastMessageTimestamp,
      int unreadCount,
      bool isPinned,
      bool isArchived,
      bool isMuted,
      DateTime? muteUntil,
      int? disappearingMessageTimerMs,
      bool isEncrypted});
}

/// @nodoc
class _$ConversationCopyWithImpl<$Res, $Val extends Conversation>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Conversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? participantIds = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastMessageId = freezed,
    Object? lastMessageText = freezed,
    Object? lastMessageTimestamp = freezed,
    Object? unreadCount = null,
    Object? isPinned = null,
    Object? isArchived = null,
    Object? isMuted = null,
    Object? muteUntil = freezed,
    Object? disappearingMessageTimerMs = freezed,
    Object? isEncrypted = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ConversationType,
      participantIds: null == participantIds
          ? _value.participantIds
          : participantIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastMessageId: freezed == lastMessageId
          ? _value.lastMessageId
          : lastMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastMessageText: freezed == lastMessageText
          ? _value.lastMessageText
          : lastMessageText // ignore: cast_nullable_to_non_nullable
              as String?,
      lastMessageTimestamp: freezed == lastMessageTimestamp
          ? _value.lastMessageTimestamp
          : lastMessageTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      isPinned: null == isPinned
          ? _value.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      muteUntil: freezed == muteUntil
          ? _value.muteUntil
          : muteUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      disappearingMessageTimerMs: freezed == disappearingMessageTimerMs
          ? _value.disappearingMessageTimerMs
          : disappearingMessageTimerMs // ignore: cast_nullable_to_non_nullable
              as int?,
      isEncrypted: null == isEncrypted
          ? _value.isEncrypted
          : isEncrypted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ConversationImplCopyWith<$Res>
    implements $ConversationCopyWith<$Res> {
  factory _$$ConversationImplCopyWith(
          _$ConversationImpl value, $Res Function(_$ConversationImpl) then) =
      __$$ConversationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      ConversationType type,
      List<String> participantIds,
      DateTime createdAt,
      DateTime updatedAt,
      String? lastMessageId,
      String? lastMessageText,
      DateTime? lastMessageTimestamp,
      int unreadCount,
      bool isPinned,
      bool isArchived,
      bool isMuted,
      DateTime? muteUntil,
      int? disappearingMessageTimerMs,
      bool isEncrypted});
}

/// @nodoc
class __$$ConversationImplCopyWithImpl<$Res>
    extends _$ConversationCopyWithImpl<$Res, _$ConversationImpl>
    implements _$$ConversationImplCopyWith<$Res> {
  __$$ConversationImplCopyWithImpl(
      _$ConversationImpl _value, $Res Function(_$ConversationImpl) _then)
      : super(_value, _then);

  /// Create a copy of Conversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? participantIds = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastMessageId = freezed,
    Object? lastMessageText = freezed,
    Object? lastMessageTimestamp = freezed,
    Object? unreadCount = null,
    Object? isPinned = null,
    Object? isArchived = null,
    Object? isMuted = null,
    Object? muteUntil = freezed,
    Object? disappearingMessageTimerMs = freezed,
    Object? isEncrypted = null,
  }) {
    return _then(_$ConversationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ConversationType,
      participantIds: null == participantIds
          ? _value._participantIds
          : participantIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastMessageId: freezed == lastMessageId
          ? _value.lastMessageId
          : lastMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastMessageText: freezed == lastMessageText
          ? _value.lastMessageText
          : lastMessageText // ignore: cast_nullable_to_non_nullable
              as String?,
      lastMessageTimestamp: freezed == lastMessageTimestamp
          ? _value.lastMessageTimestamp
          : lastMessageTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      isPinned: null == isPinned
          ? _value.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      muteUntil: freezed == muteUntil
          ? _value.muteUntil
          : muteUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      disappearingMessageTimerMs: freezed == disappearingMessageTimerMs
          ? _value.disappearingMessageTimerMs
          : disappearingMessageTimerMs // ignore: cast_nullable_to_non_nullable
              as int?,
      isEncrypted: null == isEncrypted
          ? _value.isEncrypted
          : isEncrypted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ConversationImpl implements _Conversation {
  const _$ConversationImpl(
      {required this.id,
      required this.type,
      required final List<String> participantIds,
      required this.createdAt,
      required this.updatedAt,
      this.lastMessageId,
      this.lastMessageText,
      this.lastMessageTimestamp,
      this.unreadCount = 0,
      this.isPinned = false,
      this.isArchived = false,
      this.isMuted = false,
      this.muteUntil,
      this.disappearingMessageTimerMs,
      this.isEncrypted = true})
      : _participantIds = participantIds;

  factory _$ConversationImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationImplFromJson(json);

  @override
  final String id;
  @override
  final ConversationType type;
  final List<String> _participantIds;
  @override
  List<String> get participantIds {
    if (_participantIds is EqualUnmodifiableListView) return _participantIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participantIds);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String? lastMessageId;
  @override
  final String? lastMessageText;
  @override
  final DateTime? lastMessageTimestamp;
  @override
  @JsonKey()
  final int unreadCount;
  @override
  @JsonKey()
  final bool isPinned;
  @override
  @JsonKey()
  final bool isArchived;
  @override
  @JsonKey()
  final bool isMuted;
  @override
  final DateTime? muteUntil;
  @override
  final int? disappearingMessageTimerMs;
  @override
  @JsonKey()
  final bool isEncrypted;

  @override
  String toString() {
    return 'Conversation(id: $id, type: $type, participantIds: $participantIds, createdAt: $createdAt, updatedAt: $updatedAt, lastMessageId: $lastMessageId, lastMessageText: $lastMessageText, lastMessageTimestamp: $lastMessageTimestamp, unreadCount: $unreadCount, isPinned: $isPinned, isArchived: $isArchived, isMuted: $isMuted, muteUntil: $muteUntil, disappearingMessageTimerMs: $disappearingMessageTimerMs, isEncrypted: $isEncrypted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality()
                .equals(other._participantIds, _participantIds) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastMessageId, lastMessageId) ||
                other.lastMessageId == lastMessageId) &&
            (identical(other.lastMessageText, lastMessageText) ||
                other.lastMessageText == lastMessageText) &&
            (identical(other.lastMessageTimestamp, lastMessageTimestamp) ||
                other.lastMessageTimestamp == lastMessageTimestamp) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.muteUntil, muteUntil) ||
                other.muteUntil == muteUntil) &&
            (identical(other.disappearingMessageTimerMs,
                    disappearingMessageTimerMs) ||
                other.disappearingMessageTimerMs ==
                    disappearingMessageTimerMs) &&
            (identical(other.isEncrypted, isEncrypted) ||
                other.isEncrypted == isEncrypted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      const DeepCollectionEquality().hash(_participantIds),
      createdAt,
      updatedAt,
      lastMessageId,
      lastMessageText,
      lastMessageTimestamp,
      unreadCount,
      isPinned,
      isArchived,
      isMuted,
      muteUntil,
      disappearingMessageTimerMs,
      isEncrypted);

  /// Create a copy of Conversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationImplCopyWith<_$ConversationImpl> get copyWith =>
      __$$ConversationImplCopyWithImpl<_$ConversationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationImplToJson(
      this,
    );
  }
}

abstract class _Conversation implements Conversation {
  const factory _Conversation(
      {required final String id,
      required final ConversationType type,
      required final List<String> participantIds,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final String? lastMessageId,
      final String? lastMessageText,
      final DateTime? lastMessageTimestamp,
      final int unreadCount,
      final bool isPinned,
      final bool isArchived,
      final bool isMuted,
      final DateTime? muteUntil,
      final int? disappearingMessageTimerMs,
      final bool isEncrypted}) = _$ConversationImpl;

  factory _Conversation.fromJson(Map<String, dynamic> json) =
      _$ConversationImpl.fromJson;

  @override
  String get id;
  @override
  ConversationType get type;
  @override
  List<String> get participantIds;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  String? get lastMessageId;
  @override
  String? get lastMessageText;
  @override
  DateTime? get lastMessageTimestamp;
  @override
  int get unreadCount;
  @override
  bool get isPinned;
  @override
  bool get isArchived;
  @override
  bool get isMuted;
  @override
  DateTime? get muteUntil;
  @override
  int? get disappearingMessageTimerMs;
  @override
  bool get isEncrypted;

  /// Create a copy of Conversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationImplCopyWith<_$ConversationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
