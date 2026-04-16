/// A refund issued against a previous expense.
class Refund {
  final String id;

  /// The expense this refund applies to, if known.
  final String? originalExpenseId;

  final double amount;
  final String currency;

  /// User ID of the person receiving the refund.
  final String refundedTo;

  final String reason;
  final DateTime date;

  const Refund({
    required this.id,
    this.originalExpenseId,
    required this.amount,
    required this.currency,
    required this.refundedTo,
    required this.reason,
    required this.date,
  });

  @override
  String toString() =>
      'Refund(id: $id, amount: $amount $currency, to: $refundedTo, '
      'reason: $reason)';
}
