/// Result of joining a group via an invite link.
class JoinResult {
  /// Creates a [JoinResult].
  const JoinResult({required this.groupId, required this.accessToken});

  /// The group that was joined.
  final String groupId;

  /// Access token for the joined group session.
  final String accessToken;
}
