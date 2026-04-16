/// The result of splitting a single expense for one user.
class SplitResult {
  final String userId;
  final double owes;
  final String owesTo;

  const SplitResult({
    required this.userId,
    required this.owes,
    required this.owesTo,
  });

  @override
  String toString() =>
      'SplitResult(userId: $userId, owes: $owes, owesTo: $owesTo)';
}
