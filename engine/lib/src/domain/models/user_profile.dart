import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

/// A user's public profile information.
@freezed
class UserProfile with _$UserProfile {
  /// Creates a [UserProfile].
  const factory UserProfile({
    required String userId,
    required String displayName,
    String? photoUrl,
    String? phone,
  }) = _UserProfile;

  /// Deserializes from JSON.
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
