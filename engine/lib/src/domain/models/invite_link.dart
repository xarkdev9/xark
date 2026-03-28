/// An invite link that can be shared to join a group.
class InviteLink {
  /// Creates an [InviteLink].
  const InviteLink({required this.code, required this.url});

  /// The short invite code.
  final String code;

  /// The full shareable URL.
  final String url;
}
