import 'package:freezed_annotation/freezed_annotation.dart';

part 'decision_item.freezed.dart';
part 'decision_item.g.dart';

/// A decision item within a group's consensus board.
@freezed
class DecisionItem with _$DecisionItem {
  /// Creates a [DecisionItem].
  const factory DecisionItem({
    required String id,
    required String groupId,
    required String title,
    String? description,
    String? category,
    required String state,
    @Default(0.0) double weightedScore,
    @Default(0.0) double agreementScore,
    @Default({}) Map<String, String> reactions,
    @Default(false) bool isLocked,
    String? photoUrl,
    String? proposedBy,
  }) = _DecisionItem;

  /// Creates a [DecisionItem] from a JSON map.
  factory DecisionItem.fromJson(Map<String, dynamic> json) =>
      _$DecisionItemFromJson(json);
}
