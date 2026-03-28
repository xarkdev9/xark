// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'decision_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DecisionItem _$DecisionItemFromJson(Map<String, dynamic> json) {
  return _DecisionItem.fromJson(json);
}

/// @nodoc
mixin _$DecisionItem {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  double get weightedScore => throw _privateConstructorUsedError;
  double get agreementScore => throw _privateConstructorUsedError;
  Map<String, String> get reactions => throw _privateConstructorUsedError;
  bool get isLocked => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get proposedBy => throw _privateConstructorUsedError;

  /// Serializes this DecisionItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DecisionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DecisionItemCopyWith<DecisionItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DecisionItemCopyWith<$Res> {
  factory $DecisionItemCopyWith(
          DecisionItem value, $Res Function(DecisionItem) then) =
      _$DecisionItemCopyWithImpl<$Res, DecisionItem>;
  @useResult
  $Res call(
      {String id,
      String groupId,
      String title,
      String? description,
      String? category,
      String state,
      double weightedScore,
      double agreementScore,
      Map<String, String> reactions,
      bool isLocked,
      String? photoUrl,
      String? proposedBy});
}

/// @nodoc
class _$DecisionItemCopyWithImpl<$Res, $Val extends DecisionItem>
    implements $DecisionItemCopyWith<$Res> {
  _$DecisionItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DecisionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? title = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? state = null,
    Object? weightedScore = null,
    Object? agreementScore = null,
    Object? reactions = null,
    Object? isLocked = null,
    Object? photoUrl = freezed,
    Object? proposedBy = freezed,
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
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      weightedScore: null == weightedScore
          ? _value.weightedScore
          : weightedScore // ignore: cast_nullable_to_non_nullable
              as double,
      agreementScore: null == agreementScore
          ? _value.agreementScore
          : agreementScore // ignore: cast_nullable_to_non_nullable
              as double,
      reactions: null == reactions
          ? _value.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      isLocked: null == isLocked
          ? _value.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      proposedBy: freezed == proposedBy
          ? _value.proposedBy
          : proposedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DecisionItemImplCopyWith<$Res>
    implements $DecisionItemCopyWith<$Res> {
  factory _$$DecisionItemImplCopyWith(
          _$DecisionItemImpl value, $Res Function(_$DecisionItemImpl) then) =
      __$$DecisionItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String groupId,
      String title,
      String? description,
      String? category,
      String state,
      double weightedScore,
      double agreementScore,
      Map<String, String> reactions,
      bool isLocked,
      String? photoUrl,
      String? proposedBy});
}

/// @nodoc
class __$$DecisionItemImplCopyWithImpl<$Res>
    extends _$DecisionItemCopyWithImpl<$Res, _$DecisionItemImpl>
    implements _$$DecisionItemImplCopyWith<$Res> {
  __$$DecisionItemImplCopyWithImpl(
      _$DecisionItemImpl _value, $Res Function(_$DecisionItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DecisionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? title = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? state = null,
    Object? weightedScore = null,
    Object? agreementScore = null,
    Object? reactions = null,
    Object? isLocked = null,
    Object? photoUrl = freezed,
    Object? proposedBy = freezed,
  }) {
    return _then(_$DecisionItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      weightedScore: null == weightedScore
          ? _value.weightedScore
          : weightedScore // ignore: cast_nullable_to_non_nullable
              as double,
      agreementScore: null == agreementScore
          ? _value.agreementScore
          : agreementScore // ignore: cast_nullable_to_non_nullable
              as double,
      reactions: null == reactions
          ? _value._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      isLocked: null == isLocked
          ? _value.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      proposedBy: freezed == proposedBy
          ? _value.proposedBy
          : proposedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DecisionItemImpl implements _DecisionItem {
  const _$DecisionItemImpl(
      {required this.id,
      required this.groupId,
      required this.title,
      this.description,
      this.category,
      required this.state,
      this.weightedScore = 0.0,
      this.agreementScore = 0.0,
      final Map<String, String> reactions = const {},
      this.isLocked = false,
      this.photoUrl,
      this.proposedBy})
      : _reactions = reactions;

  factory _$DecisionItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DecisionItemImplFromJson(json);

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String title;
  @override
  final String? description;
  @override
  final String? category;
  @override
  final String state;
  @override
  @JsonKey()
  final double weightedScore;
  @override
  @JsonKey()
  final double agreementScore;
  final Map<String, String> _reactions;
  @override
  @JsonKey()
  Map<String, String> get reactions {
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_reactions);
  }

  @override
  @JsonKey()
  final bool isLocked;
  @override
  final String? photoUrl;
  @override
  final String? proposedBy;

  @override
  String toString() {
    return 'DecisionItem(id: $id, groupId: $groupId, title: $title, description: $description, category: $category, state: $state, weightedScore: $weightedScore, agreementScore: $agreementScore, reactions: $reactions, isLocked: $isLocked, photoUrl: $photoUrl, proposedBy: $proposedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DecisionItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.weightedScore, weightedScore) ||
                other.weightedScore == weightedScore) &&
            (identical(other.agreementScore, agreementScore) ||
                other.agreementScore == agreementScore) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            (identical(other.isLocked, isLocked) ||
                other.isLocked == isLocked) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.proposedBy, proposedBy) ||
                other.proposedBy == proposedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      groupId,
      title,
      description,
      category,
      state,
      weightedScore,
      agreementScore,
      const DeepCollectionEquality().hash(_reactions),
      isLocked,
      photoUrl,
      proposedBy);

  /// Create a copy of DecisionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DecisionItemImplCopyWith<_$DecisionItemImpl> get copyWith =>
      __$$DecisionItemImplCopyWithImpl<_$DecisionItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DecisionItemImplToJson(
      this,
    );
  }
}

abstract class _DecisionItem implements DecisionItem {
  const factory _DecisionItem(
      {required final String id,
      required final String groupId,
      required final String title,
      final String? description,
      final String? category,
      required final String state,
      final double weightedScore,
      final double agreementScore,
      final Map<String, String> reactions,
      final bool isLocked,
      final String? photoUrl,
      final String? proposedBy}) = _$DecisionItemImpl;

  factory _DecisionItem.fromJson(Map<String, dynamic> json) =
      _$DecisionItemImpl.fromJson;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get title;
  @override
  String? get description;
  @override
  String? get category;
  @override
  String get state;
  @override
  double get weightedScore;
  @override
  double get agreementScore;
  @override
  Map<String, String> get reactions;
  @override
  bool get isLocked;
  @override
  String? get photoUrl;
  @override
  String? get proposedBy;

  /// Create a copy of DecisionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DecisionItemImplCopyWith<_$DecisionItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
