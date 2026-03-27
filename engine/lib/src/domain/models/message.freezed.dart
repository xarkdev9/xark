// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Message _$MessageFromJson(Map<String, dynamic> json) {
  return _Message.fromJson(json);
}

/// @nodoc
mixin _$Message {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get senderDeviceId => throw _privateConstructorUsedError;
  MessageType get type => throw _privateConstructorUsedError;
  MessageStatus get status => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  int? get serverSeq => throw _privateConstructorUsedError;
  String? get text => throw _privateConstructorUsedError;
  MediaMetadata? get media => throw _privateConstructorUsedError;
  String? get replyToMessageId => throw _privateConstructorUsedError;
  Map<String, List<String>> get reactions => throw _privateConstructorUsedError;
  bool get isStarred => throw _privateConstructorUsedError;
  bool get isViewOnce => throw _privateConstructorUsedError;
  int? get disappearsAt => throw _privateConstructorUsedError;
  bool get isDeleted => throw _privateConstructorUsedError;

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageCopyWith<Message> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) then) =
      _$MessageCopyWithImpl<$Res, Message>;
  @useResult
  $Res call(
      {String id,
      String groupId,
      String senderId,
      String senderDeviceId,
      MessageType type,
      MessageStatus status,
      DateTime timestamp,
      String role,
      int? serverSeq,
      String? text,
      MediaMetadata? media,
      String? replyToMessageId,
      Map<String, List<String>> reactions,
      bool isStarred,
      bool isViewOnce,
      int? disappearsAt,
      bool isDeleted});

  $MediaMetadataCopyWith<$Res>? get media;
}

/// @nodoc
class _$MessageCopyWithImpl<$Res, $Val extends Message>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? senderId = null,
    Object? senderDeviceId = null,
    Object? type = null,
    Object? status = null,
    Object? timestamp = null,
    Object? role = null,
    Object? serverSeq = freezed,
    Object? text = freezed,
    Object? media = freezed,
    Object? replyToMessageId = freezed,
    Object? reactions = null,
    Object? isStarred = null,
    Object? isViewOnce = null,
    Object? disappearsAt = freezed,
    Object? isDeleted = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      senderDeviceId: null == senderDeviceId
          ? _value.senderDeviceId
          : senderDeviceId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as MessageStatus,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      serverSeq: freezed == serverSeq
          ? _value.serverSeq
          : serverSeq // ignore: cast_nullable_to_non_nullable
              as int?,
      text: freezed == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String?,
      media: freezed == media
          ? _value.media
          : media // ignore: cast_nullable_to_non_nullable
              as MediaMetadata?,
      replyToMessageId: freezed == replyToMessageId
          ? _value.replyToMessageId
          : replyToMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      reactions: null == reactions
          ? _value.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      isStarred: null == isStarred
          ? _value.isStarred
          : isStarred // ignore: cast_nullable_to_non_nullable
              as bool,
      isViewOnce: null == isViewOnce
          ? _value.isViewOnce
          : isViewOnce // ignore: cast_nullable_to_non_nullable
              as bool,
      disappearsAt: freezed == disappearsAt
          ? _value.disappearsAt
          : disappearsAt // ignore: cast_nullable_to_non_nullable
              as int?,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MediaMetadataCopyWith<$Res>? get media {
    if (_value.media == null) {
      return null;
    }

    return $MediaMetadataCopyWith<$Res>(_value.media!, (value) {
      return _then(_value.copyWith(media: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MessageImplCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$$MessageImplCopyWith(
          _$MessageImpl value, $Res Function(_$MessageImpl) then) =
      __$$MessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String groupId,
      String senderId,
      String senderDeviceId,
      MessageType type,
      MessageStatus status,
      DateTime timestamp,
      String role,
      int? serverSeq,
      String? text,
      MediaMetadata? media,
      String? replyToMessageId,
      Map<String, List<String>> reactions,
      bool isStarred,
      bool isViewOnce,
      int? disappearsAt,
      bool isDeleted});

  @override
  $MediaMetadataCopyWith<$Res>? get media;
}

/// @nodoc
class __$$MessageImplCopyWithImpl<$Res>
    extends _$MessageCopyWithImpl<$Res, _$MessageImpl>
    implements _$$MessageImplCopyWith<$Res> {
  __$$MessageImplCopyWithImpl(
      _$MessageImpl _value, $Res Function(_$MessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? senderId = null,
    Object? senderDeviceId = null,
    Object? type = null,
    Object? status = null,
    Object? timestamp = null,
    Object? role = null,
    Object? serverSeq = freezed,
    Object? text = freezed,
    Object? media = freezed,
    Object? replyToMessageId = freezed,
    Object? reactions = null,
    Object? isStarred = null,
    Object? isViewOnce = null,
    Object? disappearsAt = freezed,
    Object? isDeleted = null,
  }) {
    return _then(_$MessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      senderDeviceId: null == senderDeviceId
          ? _value.senderDeviceId
          : senderDeviceId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as MessageStatus,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      serverSeq: freezed == serverSeq
          ? _value.serverSeq
          : serverSeq // ignore: cast_nullable_to_non_nullable
              as int?,
      text: freezed == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String?,
      media: freezed == media
          ? _value.media
          : media // ignore: cast_nullable_to_non_nullable
              as MediaMetadata?,
      replyToMessageId: freezed == replyToMessageId
          ? _value.replyToMessageId
          : replyToMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      reactions: null == reactions
          ? _value._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      isStarred: null == isStarred
          ? _value.isStarred
          : isStarred // ignore: cast_nullable_to_non_nullable
              as bool,
      isViewOnce: null == isViewOnce
          ? _value.isViewOnce
          : isViewOnce // ignore: cast_nullable_to_non_nullable
              as bool,
      disappearsAt: freezed == disappearsAt
          ? _value.disappearsAt
          : disappearsAt // ignore: cast_nullable_to_non_nullable
              as int?,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageImpl implements _Message {
  const _$MessageImpl(
      {required this.id,
      required this.groupId,
      required this.senderId,
      required this.senderDeviceId,
      required this.type,
      required this.status,
      required this.timestamp,
      this.role = 'user',
      this.serverSeq,
      this.text,
      this.media,
      this.replyToMessageId,
      final Map<String, List<String>> reactions = const {},
      this.isStarred = false,
      this.isViewOnce = false,
      this.disappearsAt,
      this.isDeleted = false})
      : _reactions = reactions;

  factory _$MessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageImplFromJson(json);

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String senderId;
  @override
  final String senderDeviceId;
  @override
  final MessageType type;
  @override
  final MessageStatus status;
  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final String role;
  @override
  final int? serverSeq;
  @override
  final String? text;
  @override
  final MediaMetadata? media;
  @override
  final String? replyToMessageId;
  final Map<String, List<String>> _reactions;
  @override
  @JsonKey()
  Map<String, List<String>> get reactions {
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_reactions);
  }

  @override
  @JsonKey()
  final bool isStarred;
  @override
  @JsonKey()
  final bool isViewOnce;
  @override
  final int? disappearsAt;
  @override
  @JsonKey()
  final bool isDeleted;

  @override
  String toString() {
    return 'Message(id: $id, groupId: $groupId, senderId: $senderId, senderDeviceId: $senderDeviceId, type: $type, status: $status, timestamp: $timestamp, role: $role, serverSeq: $serverSeq, text: $text, media: $media, replyToMessageId: $replyToMessageId, reactions: $reactions, isStarred: $isStarred, isViewOnce: $isViewOnce, disappearsAt: $disappearsAt, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) ||
                other.groupId == groupId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderDeviceId, senderDeviceId) ||
                other.senderDeviceId == senderDeviceId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.serverSeq, serverSeq) ||
                other.serverSeq == serverSeq) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.media, media) || other.media == media) &&
            (identical(other.replyToMessageId, replyToMessageId) ||
                other.replyToMessageId == replyToMessageId) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            (identical(other.isStarred, isStarred) ||
                other.isStarred == isStarred) &&
            (identical(other.isViewOnce, isViewOnce) ||
                other.isViewOnce == isViewOnce) &&
            (identical(other.disappearsAt, disappearsAt) ||
                other.disappearsAt == disappearsAt) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      groupId,
      senderId,
      senderDeviceId,
      type,
      status,
      timestamp,
      role,
      serverSeq,
      text,
      media,
      replyToMessageId,
      const DeepCollectionEquality().hash(_reactions),
      isStarred,
      isViewOnce,
      disappearsAt,
      isDeleted);

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      __$$MessageImplCopyWithImpl<_$MessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageImplToJson(
      this,
    );
  }
}

abstract class _Message implements Message {
  const factory _Message(
      {required final String id,
      required final String groupId,
      required final String senderId,
      required final String senderDeviceId,
      required final MessageType type,
      required final MessageStatus status,
      required final DateTime timestamp,
      final String role,
      final int? serverSeq,
      final String? text,
      final MediaMetadata? media,
      final String? replyToMessageId,
      final Map<String, List<String>> reactions,
      final bool isStarred,
      final bool isViewOnce,
      final int? disappearsAt,
      final bool isDeleted}) = _$MessageImpl;

  factory _Message.fromJson(Map<String, dynamic> json) = _$MessageImpl.fromJson;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get senderId;
  @override
  String get senderDeviceId;
  @override
  MessageType get type;
  @override
  MessageStatus get status;
  @override
  DateTime get timestamp;
  @override
  String get role;
  @override
  int? get serverSeq;
  @override
  String? get text;
  @override
  MediaMetadata? get media;
  @override
  String? get replyToMessageId;
  @override
  Map<String, List<String>> get reactions;
  @override
  bool get isStarred;
  @override
  bool get isViewOnce;
  @override
  int? get disappearsAt;
  @override
  bool get isDeleted;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
