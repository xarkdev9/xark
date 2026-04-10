/// A directed debt between two users in a specific currency.
class DebtDelta {
  final String from;
  final String to;
  final double amount;
  final String currency;

  const DebtDelta({
    required this.from,
    required this.to,
    required this.amount,
    required this.currency,
  });

  @override
  String toString() =>
      'DebtDelta(from: $from, to: $to, amount: $amount, currency: $currency)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtDelta &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          amount == other.amount &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(from, to, amount, currency);
}
