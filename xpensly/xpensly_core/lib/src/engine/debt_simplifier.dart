import '../models/debt_delta.dart';

/// Reduces the number of transactions needed to settle all debts.
///
/// Uses a net-balance greedy algorithm that minimizes the total number
/// of transfers by computing each person's net position and greedily
/// matching the largest creditor with the largest debtor.
class DebtSimplifier {
  /// Simplifies a list of debt deltas into the minimum number of
  /// transactions needed to settle all balances.
  ///
  /// The [currency] parameter is applied to all output deltas.
  List<DebtDelta> simplify(
    List<DebtDelta> deltas, {
    String currency = 'USD',
  }) {
    if (deltas.isEmpty) return [];

    // Step 1: Compute net balance per person.
    // Positive = net creditor (owed money), negative = net debtor (owes money).
    final balances = <String, double>{};
    for (final delta in deltas) {
      balances[delta.from] =
          (balances[delta.from] ?? 0.0) - delta.amount;
      balances[delta.to] =
          (balances[delta.to] ?? 0.0) + delta.amount;
    }

    // Step 2: Separate into creditors and debtors.
    final creditors = <_BalanceEntry>[];
    final debtors = <_BalanceEntry>[];

    for (final entry in balances.entries) {
      final rounded = _round2(entry.value);
      if (rounded > 0) {
        creditors.add(_BalanceEntry(entry.key, rounded));
      } else if (rounded < 0) {
        debtors.add(_BalanceEntry(entry.key, rounded.abs()));
      }
    }

    // Step 3: Sort — largest amounts first for greedy matching.
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    // Step 4: Greedily match largest creditor with largest debtor.
    final simplified = <DebtDelta>[];
    var ci = 0;
    var di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final creditor = creditors[ci];
      final debtor = debtors[di];
      final transfer = _round2(
          creditor.amount < debtor.amount
              ? creditor.amount
              : debtor.amount);

      if (transfer > 0) {
        simplified.add(DebtDelta(
          from: debtor.userId,
          to: creditor.userId,
          amount: transfer,
          currency: currency,
        ));
      }

      creditors[ci] = _BalanceEntry(
          creditor.userId, _round2(creditor.amount - transfer));
      debtors[di] = _BalanceEntry(
          debtor.userId, _round2(debtor.amount - transfer));

      if (creditors[ci].amount == 0) ci++;
      if (debtors[di].amount == 0) di++;
    }

    return simplified;
  }

  /// Returns the deltas as-is without simplification.
  ///
  /// Useful when the caller wants to preserve the original pairwise
  /// debt structure (e.g., for display purposes).
  List<DebtDelta> pairwise(List<DebtDelta> deltas) {
    return List<DebtDelta>.from(deltas);
  }

  double _round2(double value) =>
      (value * 100).roundToDouble() / 100;
}

class _BalanceEntry {
  final String userId;
  final double amount;

  const _BalanceEntry(this.userId, this.amount);
}
