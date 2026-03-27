import 'package:freezed_annotation/freezed_annotation.dart';

part 'presence_state.freezed.dart';
part 'presence_state.g.dart';

/// Controls who can see a user's online/last-seen status.
enum PresenceVisibility {
  /// Visible to all users.
  everyone,

  /// Visible only to contacts.
  contacts,

  /// Hidden from everyone.
  nobody,
}

/// Online/offline presence state for a user.
@freezed
class PresenceState with _$PresenceState {
  /// Creates a [PresenceState] instance.
  const factory PresenceState({
    required String userId,
    @Default(false) bool isOnline,
    DateTime? lastSeenAt,
    @Default(PresenceVisibility.everyone) PresenceVisibility visibility,
  }) = _PresenceState;

  /// Deserializes from JSON.
  factory PresenceState.fromJson(Map<String, dynamic> json) =>
      _$PresenceStateFromJson(json);
}
