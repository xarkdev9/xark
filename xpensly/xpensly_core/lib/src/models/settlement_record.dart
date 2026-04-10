/// A recorded payment between two users that settles a debt.
class SettlementRecord {
  final String id;
  final String tripId;
  final String fromUser;
  final String toUser;
  final double amount;
  final String currency;

  /// Payment provider (e.g., "venmo", "zelle", "cash").
  final String? provider;

  /// URL or reference to proof of payment.
  final String? proof;

  /// Optional note from the payer.
  final String? note;

  final DateTime settledAt;

  const SettlementRecord({
    required this.id,
    required this.tripId,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.currency,
    this.provider,
    this.proof,
    this.note,
    required this.settledAt,
  });

  @override
  String toString() =>
      'SettlementRecord(id: $id, from: $fromUser, to: $toUser, '
      'amount: $amount $currency, at: $settledAt)';
}
