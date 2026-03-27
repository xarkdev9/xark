import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact_match.freezed.dart';
part 'contact_match.g.dart';

/// A matched contact from the privacy-preserving contact discovery protocol.
@freezed
class ContactMatch with _$ContactMatch {
  /// Creates a [ContactMatch] instance.
  const factory ContactMatch({
    required String userId,
    required String phoneHash,
    String? displayNameEncrypted,
  }) = _ContactMatch;

  /// Deserializes from JSON.
  factory ContactMatch.fromJson(Map<String, dynamic> json) =>
      _$ContactMatchFromJson(json);
}
