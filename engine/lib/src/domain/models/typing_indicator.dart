import 'package:freezed_annotation/freezed_annotation.dart';

part 'typing_indicator.freezed.dart';
part 'typing_indicator.g.dart';

/// Ephemeral typing indicator for a user in a conversation.
@freezed
class TypingIndicator with _$TypingIndicator {
  /// Creates a [TypingIndicator] instance.
  const factory TypingIndicator({
    required String conversationId,
    required String userId,
    required DateTime startedAt,
  }) = _TypingIndicator;

  /// Deserializes from JSON.
  factory TypingIndicator.fromJson(Map<String, dynamic> json) =>
      _$TypingIndicatorFromJson(json);
}
