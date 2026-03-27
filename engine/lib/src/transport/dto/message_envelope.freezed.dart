// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DistributionCiphertext _$DistributionCiphertextFromJson(
    Map<String, dynamic> json) {
  return _DistributionCiphertext.fromJson(json);
}

/// @nodoc
mixin _$DistributionCiphertext {
  /// Row ID, prefixed `mc_` + UUID.
  String get id => throw _privateConstructorUsedError;

  /// Recipient user ID.
  @JsonKey(name: 'recipient_id')
  String get recipientId => throw _privateConstructorUsedError;

  /// Recipient device ID.
  @JsonKey(name: 'recipient_device_id')
  int get recipientDeviceId => throw _privateConstructorUsedError;

  /// Base64-encoded ciphertext.
  String get ciphertext => throw _privateConstructorUsedError;

  /// Base64-encoded ratchet header JSON envelope.
  @JsonKey(name: 'ratchet_header')
  String? get ratchetHeader => throw _privateConstructorUsedError;

  /// Serializes this DistributionCiphertext to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DistributionCiphertext
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DistributionCiphertextCopyWith<DistributionCiphertext> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DistributionCiphertextCopyWith<$Res> {
  factory $DistributionCiphertextCopyWith(DistributionCiphertext value,
          $Res Function(DistributionCiphertext) then) =
      _$DistributionCiphertextCopyWithImpl<$Res, DistributionCiphertext>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'recipient_id') String recipientId,
      @JsonKey(name: 'recipient_device_id') int recipientDeviceId,
      String ciphertext,
      @JsonKey(name: 'ratchet_header') String? ratchetHeader});
}

/// @nodoc
class _$DistributionCiphertextCopyWithImpl<$Res,
        $Val extends DistributionCiphertext>
    implements $DistributionCiphertextCopyWith<$Res> {
  _$DistributionCiphertextCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DistributionCiphertext
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? recipientId = null,
    Object? recipientDeviceId = null,
    Object? ciphertext = null,
    Object? ratchetHeader = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientDeviceId: null == recipientDeviceId
          ? _value.recipientDeviceId
          : recipientDeviceId // ignore: cast_nullable_to_non_nullable
              as int,
      ciphertext: null == ciphertext
          ? _value.ciphertext
          : ciphertext // ignore: cast_nullable_to_non_nullable
              as String,
      ratchetHeader: freezed == ratchetHeader
          ? _value.ratchetHeader
          : ratchetHeader // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DistributionCiphertextImplCopyWith<$Res>
    implements $DistributionCiphertextCopyWith<$Res> {
  factory _$$DistributionCiphertextImplCopyWith(
          _$DistributionCiphertextImpl value,
          $Res Function(_$DistributionCiphertextImpl) then) =
      __$$DistributionCiphertextImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'recipient_id') String recipientId,
      @JsonKey(name: 'recipient_device_id') int recipientDeviceId,
      String ciphertext,
      @JsonKey(name: 'ratchet_header') String? ratchetHeader});
}

/// @nodoc
class __$$DistributionCiphertextImplCopyWithImpl<$Res>
    extends _$DistributionCiphertextCopyWithImpl<$Res,
        _$DistributionCiphertextImpl>
    implements _$$DistributionCiphertextImplCopyWith<$Res> {
  __$$DistributionCiphertextImplCopyWithImpl(
      _$DistributionCiphertextImpl _value,
      $Res Function(_$DistributionCiphertextImpl) _then)
      : super(_value, _then);

  /// Create a copy of DistributionCiphertext
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? recipientId = null,
    Object? recipientDeviceId = null,
    Object? ciphertext = null,
    Object? ratchetHeader = freezed,
  }) {
    return _then(_$DistributionCiphertextImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientDeviceId: null == recipientDeviceId
          ? _value.recipientDeviceId
          : recipientDeviceId // ignore: cast_nullable_to_non_nullable
              as int,
      ciphertext: null == ciphertext
          ? _value.ciphertext
          : ciphertext // ignore: cast_nullable_to_non_nullable
              as String,
      ratchetHeader: freezed == ratchetHeader
          ? _value.ratchetHeader
          : ratchetHeader // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DistributionCiphertextImpl implements _DistributionCiphertext {
  const _$DistributionCiphertextImpl(
      {required this.id,
      @JsonKey(name: 'recipient_id') required this.recipientId,
      @JsonKey(name: 'recipient_device_id') required this.recipientDeviceId,
      required this.ciphertext,
      @JsonKey(name: 'ratchet_header') this.ratchetHeader});

  factory _$DistributionCiphertextImpl.fromJson(Map<String, dynamic> json) =>
      _$$DistributionCiphertextImplFromJson(json);

  /// Row ID, prefixed `mc_` + UUID.
  @override
  final String id;

  /// Recipient user ID.
  @override
  @JsonKey(name: 'recipient_id')
  final String recipientId;

  /// Recipient device ID.
  @override
  @JsonKey(name: 'recipient_device_id')
  final int recipientDeviceId;

  /// Base64-encoded ciphertext.
  @override
  final String ciphertext;

  /// Base64-encoded ratchet header JSON envelope.
  @override
  @JsonKey(name: 'ratchet_header')
  final String? ratchetHeader;

  @override
  String toString() {
    return 'DistributionCiphertext(id: $id, recipientId: $recipientId, recipientDeviceId: $recipientDeviceId, ciphertext: $ciphertext, ratchetHeader: $ratchetHeader)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DistributionCiphertextImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.recipientDeviceId, recipientDeviceId) ||
                other.recipientDeviceId == recipientDeviceId) &&
            (identical(other.ciphertext, ciphertext) ||
                other.ciphertext == ciphertext) &&
            (identical(other.ratchetHeader, ratchetHeader) ||
                other.ratchetHeader == ratchetHeader));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, recipientId,
      recipientDeviceId, ciphertext, ratchetHeader);

  /// Create a copy of DistributionCiphertext
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DistributionCiphertextImplCopyWith<_$DistributionCiphertextImpl>
      get copyWith => __$$DistributionCiphertextImplCopyWithImpl<
          _$DistributionCiphertextImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DistributionCiphertextImplToJson(
      this,
    );
  }
}

abstract class _DistributionCiphertext implements DistributionCiphertext {
  const factory _DistributionCiphertext(
          {required final String id,
          @JsonKey(name: 'recipient_id') required final String recipientId,
          @JsonKey(name: 'recipient_device_id')
          required final int recipientDeviceId,
          required final String ciphertext,
          @JsonKey(name: 'ratchet_header') final String? ratchetHeader}) =
      _$DistributionCiphertextImpl;

  factory _DistributionCiphertext.fromJson(Map<String, dynamic> json) =
      _$DistributionCiphertextImpl.fromJson;

  /// Row ID, prefixed `mc_` + UUID.
  @override
  String get id;

  /// Recipient user ID.
  @override
  @JsonKey(name: 'recipient_id')
  String get recipientId;

  /// Recipient device ID.
  @override
  @JsonKey(name: 'recipient_device_id')
  int get recipientDeviceId;

  /// Base64-encoded ciphertext.
  @override
  String get ciphertext;

  /// Base64-encoded ratchet header JSON envelope.
  @override
  @JsonKey(name: 'ratchet_header')
  String? get ratchetHeader;

  /// Create a copy of DistributionCiphertext
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DistributionCiphertextImplCopyWith<_$DistributionCiphertextImpl>
      get copyWith => throw _privateConstructorUsedError;
}

MessageEnvelope _$MessageEnvelopeFromJson(Map<String, dynamic> json) {
  return _MessageEnvelope.fromJson(json);
}

/// @nodoc
mixin _$MessageEnvelope {
  /// Conversation / space ID.
  @JsonKey(name: 'group_id')
  String get groupId => throw _privateConstructorUsedError;

  /// Sender's device ID.
  @JsonKey(name: 'sender_device_id')
  int get senderDeviceId => throw _privateConstructorUsedError;

  /// Base64-encoded ciphertext.
  String get ciphertext => throw _privateConstructorUsedError;

  /// For 1:1: recipient user ID. For group: `_group_`.
  @JsonKey(name: 'recipient_id')
  String get recipientId => throw _privateConstructorUsedError;

  /// For 1:1: target device ID. For group: `0`.
  @JsonKey(name: 'recipient_device_id')
  int get recipientDeviceId => throw _privateConstructorUsedError;

  /// Base64-encoded ratchet header JSON envelope.
  @JsonKey(name: 'ratchet_header')
  String? get ratchetHeader => throw _privateConstructorUsedError;

  /// Sender key distributions piggybacked on group messages.
  @JsonKey(name: 'distribution_ciphertexts')
  List<DistributionCiphertext> get distributionCiphertexts =>
      throw _privateConstructorUsedError;

  /// Wire-level message type (`e2ee`, `xark`, `sender_key_dist`, etc.).
  @JsonKey(name: 'message_type')
  String get messageType => throw _privateConstructorUsedError;

  /// Optional client-generated UUID.
  String? get id => throw _privateConstructorUsedError;

  /// Serializes this MessageEnvelope to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessageEnvelope
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageEnvelopeCopyWith<MessageEnvelope> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageEnvelopeCopyWith<$Res> {
  factory $MessageEnvelopeCopyWith(
          MessageEnvelope value, $Res Function(MessageEnvelope) then) =
      _$MessageEnvelopeCopyWithImpl<$Res, MessageEnvelope>;
  @useResult
  $Res call(
      {@JsonKey(name: 'group_id') String groupId,
      @JsonKey(name: 'sender_device_id') int senderDeviceId,
      String ciphertext,
      @JsonKey(name: 'recipient_id') String recipientId,
      @JsonKey(name: 'recipient_device_id') int recipientDeviceId,
      @JsonKey(name: 'ratchet_header') String? ratchetHeader,
      @JsonKey(name: 'distribution_ciphertexts')
      List<DistributionCiphertext> distributionCiphertexts,
      @JsonKey(name: 'message_type') String messageType,
      String? id});
}

/// @nodoc
class _$MessageEnvelopeCopyWithImpl<$Res, $Val extends MessageEnvelope>
    implements $MessageEnvelopeCopyWith<$Res> {
  _$MessageEnvelopeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessageEnvelope
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? senderDeviceId = null,
    Object? ciphertext = null,
    Object? recipientId = null,
    Object? recipientDeviceId = null,
    Object? ratchetHeader = freezed,
    Object? distributionCiphertexts = null,
    Object? messageType = null,
    Object? id = freezed,
  }) {
    return _then(_value.copyWith(
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      senderDeviceId: null == senderDeviceId
          ? _value.senderDeviceId
          : senderDeviceId // ignore: cast_nullable_to_non_nullable
              as int,
      ciphertext: null == ciphertext
          ? _value.ciphertext
          : ciphertext // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientDeviceId: null == recipientDeviceId
          ? _value.recipientDeviceId
          : recipientDeviceId // ignore: cast_nullable_to_non_nullable
              as int,
      ratchetHeader: freezed == ratchetHeader
          ? _value.ratchetHeader
          : ratchetHeader // ignore: cast_nullable_to_non_nullable
              as String?,
      distributionCiphertexts: null == distributionCiphertexts
          ? _value.distributionCiphertexts
          : distributionCiphertexts // ignore: cast_nullable_to_non_nullable
              as List<DistributionCiphertext>,
      messageType: null == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MessageEnvelopeImplCopyWith<$Res>
    implements $MessageEnvelopeCopyWith<$Res> {
  factory _$$MessageEnvelopeImplCopyWith(_$MessageEnvelopeImpl value,
          $Res Function(_$MessageEnvelopeImpl) then) =
      __$$MessageEnvelopeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'group_id') String groupId,
      @JsonKey(name: 'sender_device_id') int senderDeviceId,
      String ciphertext,
      @JsonKey(name: 'recipient_id') String recipientId,
      @JsonKey(name: 'recipient_device_id') int recipientDeviceId,
      @JsonKey(name: 'ratchet_header') String? ratchetHeader,
      @JsonKey(name: 'distribution_ciphertexts')
      List<DistributionCiphertext> distributionCiphertexts,
      @JsonKey(name: 'message_type') String messageType,
      String? id});
}

/// @nodoc
class __$$MessageEnvelopeImplCopyWithImpl<$Res>
    extends _$MessageEnvelopeCopyWithImpl<$Res, _$MessageEnvelopeImpl>
    implements _$$MessageEnvelopeImplCopyWith<$Res> {
  __$$MessageEnvelopeImplCopyWithImpl(
      _$MessageEnvelopeImpl _value, $Res Function(_$MessageEnvelopeImpl) _then)
      : super(_value, _then);

  /// Create a copy of MessageEnvelope
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? senderDeviceId = null,
    Object? ciphertext = null,
    Object? recipientId = null,
    Object? recipientDeviceId = null,
    Object? ratchetHeader = freezed,
    Object? distributionCiphertexts = null,
    Object? messageType = null,
    Object? id = freezed,
  }) {
    return _then(_$MessageEnvelopeImpl(
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      senderDeviceId: null == senderDeviceId
          ? _value.senderDeviceId
          : senderDeviceId // ignore: cast_nullable_to_non_nullable
              as int,
      ciphertext: null == ciphertext
          ? _value.ciphertext
          : ciphertext // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientDeviceId: null == recipientDeviceId
          ? _value.recipientDeviceId
          : recipientDeviceId // ignore: cast_nullable_to_non_nullable
              as int,
      ratchetHeader: freezed == ratchetHeader
          ? _value.ratchetHeader
          : ratchetHeader // ignore: cast_nullable_to_non_nullable
              as String?,
      distributionCiphertexts: null == distributionCiphertexts
          ? _value._distributionCiphertexts
          : distributionCiphertexts // ignore: cast_nullable_to_non_nullable
              as List<DistributionCiphertext>,
      messageType: null == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageEnvelopeImpl implements _MessageEnvelope {
  const _$MessageEnvelopeImpl(
      {@JsonKey(name: 'group_id') required this.groupId,
      @JsonKey(name: 'sender_device_id') required this.senderDeviceId,
      required this.ciphertext,
      @JsonKey(name: 'recipient_id') required this.recipientId,
      @JsonKey(name: 'recipient_device_id') required this.recipientDeviceId,
      @JsonKey(name: 'ratchet_header') this.ratchetHeader,
      @JsonKey(name: 'distribution_ciphertexts')
      final List<DistributionCiphertext> distributionCiphertexts = const [],
      @JsonKey(name: 'message_type') this.messageType = 'e2ee',
      this.id})
      : _distributionCiphertexts = distributionCiphertexts;

  factory _$MessageEnvelopeImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageEnvelopeImplFromJson(json);

  /// Conversation / space ID.
  @override
  @JsonKey(name: 'group_id')
  final String groupId;

  /// Sender's device ID.
  @override
  @JsonKey(name: 'sender_device_id')
  final int senderDeviceId;

  /// Base64-encoded ciphertext.
  @override
  final String ciphertext;

  /// For 1:1: recipient user ID. For group: `_group_`.
  @override
  @JsonKey(name: 'recipient_id')
  final String recipientId;

  /// For 1:1: target device ID. For group: `0`.
  @override
  @JsonKey(name: 'recipient_device_id')
  final int recipientDeviceId;

  /// Base64-encoded ratchet header JSON envelope.
  @override
  @JsonKey(name: 'ratchet_header')
  final String? ratchetHeader;

  /// Sender key distributions piggybacked on group messages.
  final List<DistributionCiphertext> _distributionCiphertexts;

  /// Sender key distributions piggybacked on group messages.
  @override
  @JsonKey(name: 'distribution_ciphertexts')
  List<DistributionCiphertext> get distributionCiphertexts {
    if (_distributionCiphertexts is EqualUnmodifiableListView)
      return _distributionCiphertexts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_distributionCiphertexts);
  }

  /// Wire-level message type (`e2ee`, `xark`, `sender_key_dist`, etc.).
  @override
  @JsonKey(name: 'message_type')
  final String messageType;

  /// Optional client-generated UUID.
  @override
  final String? id;

  @override
  String toString() {
    return 'MessageEnvelope(groupId: $groupId, senderDeviceId: $senderDeviceId, ciphertext: $ciphertext, recipientId: $recipientId, recipientDeviceId: $recipientDeviceId, ratchetHeader: $ratchetHeader, distributionCiphertexts: $distributionCiphertexts, messageType: $messageType, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEnvelopeImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.senderDeviceId, senderDeviceId) ||
                other.senderDeviceId == senderDeviceId) &&
            (identical(other.ciphertext, ciphertext) ||
                other.ciphertext == ciphertext) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.recipientDeviceId, recipientDeviceId) ||
                other.recipientDeviceId == recipientDeviceId) &&
            (identical(other.ratchetHeader, ratchetHeader) ||
                other.ratchetHeader == ratchetHeader) &&
            const DeepCollectionEquality().equals(
                other._distributionCiphertexts, _distributionCiphertexts) &&
            (identical(other.messageType, messageType) ||
                other.messageType == messageType) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      groupId,
      senderDeviceId,
      ciphertext,
      recipientId,
      recipientDeviceId,
      ratchetHeader,
      const DeepCollectionEquality().hash(_distributionCiphertexts),
      messageType,
      id);

  /// Create a copy of MessageEnvelope
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEnvelopeImplCopyWith<_$MessageEnvelopeImpl> get copyWith =>
      __$$MessageEnvelopeImplCopyWithImpl<_$MessageEnvelopeImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageEnvelopeImplToJson(
      this,
    );
  }
}

abstract class _MessageEnvelope implements MessageEnvelope {
  const factory _MessageEnvelope(
      {@JsonKey(name: 'group_id') required final String groupId,
      @JsonKey(name: 'sender_device_id') required final int senderDeviceId,
      required final String ciphertext,
      @JsonKey(name: 'recipient_id') required final String recipientId,
      @JsonKey(name: 'recipient_device_id')
      required final int recipientDeviceId,
      @JsonKey(name: 'ratchet_header') final String? ratchetHeader,
      @JsonKey(name: 'distribution_ciphertexts')
      final List<DistributionCiphertext> distributionCiphertexts,
      @JsonKey(name: 'message_type') final String messageType,
      final String? id}) = _$MessageEnvelopeImpl;

  factory _MessageEnvelope.fromJson(Map<String, dynamic> json) =
      _$MessageEnvelopeImpl.fromJson;

  /// Conversation / space ID.
  @override
  @JsonKey(name: 'group_id')
  String get groupId;

  /// Sender's device ID.
  @override
  @JsonKey(name: 'sender_device_id')
  int get senderDeviceId;

  /// Base64-encoded ciphertext.
  @override
  String get ciphertext;

  /// For 1:1: recipient user ID. For group: `_group_`.
  @override
  @JsonKey(name: 'recipient_id')
  String get recipientId;

  /// For 1:1: target device ID. For group: `0`.
  @override
  @JsonKey(name: 'recipient_device_id')
  int get recipientDeviceId;

  /// Base64-encoded ratchet header JSON envelope.
  @override
  @JsonKey(name: 'ratchet_header')
  String? get ratchetHeader;

  /// Sender key distributions piggybacked on group messages.
  @override
  @JsonKey(name: 'distribution_ciphertexts')
  List<DistributionCiphertext> get distributionCiphertexts;

  /// Wire-level message type (`e2ee`, `xark`, `sender_key_dist`, etc.).
  @override
  @JsonKey(name: 'message_type')
  String get messageType;

  /// Optional client-generated UUID.
  @override
  String? get id;

  /// Create a copy of MessageEnvelope
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEnvelopeImplCopyWith<_$MessageEnvelopeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
