/// Proof of commitment attached to a locked decision item.
class CommitmentProof {
  /// Creates a [CommitmentProof].
  CommitmentProof({
    required this.type,
    required this.value,
    required this.submittedBy,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  /// The type of proof (e.g. 'reservation', 'payment', 'screenshot').
  final String type;

  /// The proof value (e.g. confirmation number, URL).
  final String value;

  /// User ID of the person who submitted the proof.
  final String submittedBy;

  /// When the proof was submitted.
  final DateTime submittedAt;
}
