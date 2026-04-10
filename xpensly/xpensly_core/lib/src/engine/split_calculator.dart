import '../models/expense.dart';
import '../models/split_mode.dart';
import '../models/split_result.dart';

/// Calculates how an expense should be split among participants.
///
/// Supports four split modes: equal, exact, percentage, and shares.
/// Handles multi-payer expenses and distributes rounding remainders
/// to the first member(s) so totals match exactly.
class SplitCalculator {
  /// Calculates split results for a single expense.
  ///
  /// Returns a list of [SplitResult] entries where each entry indicates
  /// that [userId] owes [owes] amount to [owesTo]. Only entries with
  /// owes > 0 are included.
  List<SplitResult> calculate(Expense expense) {
    final shares = _computeShares(expense);
    return _resolveDebts(expense, shares);
  }

  /// Computes the per-user share of the total expense amount.
  Map<String, double> _computeShares(Expense expense) {
    switch (expense.mode) {
      case SplitMode.equal:
        return _equalShares(expense);
      case SplitMode.exact:
        return _exactShares(expense);
      case SplitMode.percentage:
        return _percentageShares(expense);
      case SplitMode.shares:
        return _relativeShares(expense);
    }
  }

  Map<String, double> _equalShares(Expense expense) {
    final count = expense.splitAmong.length;
    if (count == 0) {
      throw ArgumentError('splitAmong must not be empty');
    }

    final baseShare = (expense.amount * 100).round() ~/ count;
    final remainder = (expense.amount * 100).round() - baseShare * count;

    final shares = <String, double>{};
    for (var i = 0; i < expense.splitAmong.length; i++) {
      final userId = expense.splitAmong[i];
      final cents = baseShare + (i < remainder ? 1 : 0);
      shares[userId] = cents / 100.0;
    }

    return shares;
  }

  Map<String, double> _exactShares(Expense expense) {
    final details = expense.splitDetails;
    if (details == null) {
      throw ArgumentError(
          'splitDetails is required for exact split mode');
    }

    final sum = details.values.fold(0.0, (a, b) => a + b);
    if ((sum - expense.amount).abs() > 0.01) {
      throw ArgumentError(
          'Exact split details sum to $sum but expense amount is '
          '${expense.amount}. Difference exceeds \$0.01.');
    }

    return Map<String, double>.from(details);
  }

  Map<String, double> _percentageShares(Expense expense) {
    final details = expense.splitDetails;
    if (details == null) {
      throw ArgumentError(
          'splitDetails is required for percentage split mode');
    }

    final percentSum = details.values.fold(0.0, (a, b) => a + b);
    if ((percentSum - 100.0).abs() > 0.01) {
      throw ArgumentError(
          'Percentage split details sum to $percentSum, expected 100.');
    }

    // Compute raw shares in cents for precise rounding.
    final totalCents = (expense.amount * 100).round();
    final entries = details.entries.toList();
    final rawCents = <String, int>{};
    var allocatedCents = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i == entries.length - 1) {
        // Last entry gets the remainder to ensure exact total.
        rawCents[entry.key] = totalCents - allocatedCents;
      } else {
        final cents = (entry.value / 100.0 * totalCents).round();
        rawCents[entry.key] = cents;
        allocatedCents += cents;
      }
    }

    return rawCents.map((k, v) => MapEntry(k, v / 100.0));
  }

  Map<String, double> _relativeShares(Expense expense) {
    final details = expense.splitDetails;
    if (details == null) {
      throw ArgumentError(
          'splitDetails is required for shares split mode');
    }

    final totalShares = details.values.fold(0.0, (a, b) => a + b);
    if (totalShares == 0) {
      throw ArgumentError('Total shares must be greater than zero.');
    }

    // Compute in cents for precise rounding.
    final totalCents = (expense.amount * 100).round();
    final entries = details.entries.toList();
    final rawCents = <String, int>{};
    var allocatedCents = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i == entries.length - 1) {
        rawCents[entry.key] = totalCents - allocatedCents;
      } else {
        final cents =
            (entry.value / totalShares * totalCents).round();
        rawCents[entry.key] = cents;
        allocatedCents += cents;
      }
    }

    return rawCents.map((k, v) => MapEntry(k, v / 100.0));
  }

  /// Resolves who owes whom based on each user's share vs what they paid.
  List<SplitResult> _resolveDebts(
      Expense expense, Map<String, double> shares) {
    // Build a per-user balance: positive = overpaid (is owed money),
    // negative = underpaid (owes money).
    final balances = <String, double>{};

    // Credit each payer for what they paid.
    for (final payer in expense.paidBy) {
      balances[payer.userId] =
          (balances[payer.userId] ?? 0.0) + payer.amount;
    }

    // Debit each user for their share.
    for (final entry in shares.entries) {
      balances[entry.key] =
          (balances[entry.key] ?? 0.0) - entry.value;
    }

    // Separate into creditors (positive balance) and debtors (negative).
    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];

    for (final entry in balances.entries) {
      final rounded = _round2(entry.value);
      if (rounded > 0) {
        creditors.add(MapEntry(entry.key, rounded));
      } else if (rounded < 0) {
        debtors.add(MapEntry(entry.key, rounded.abs()));
      }
    }

    // Sort for deterministic output: largest amounts first.
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    // Greedily match debtors to creditors.
    final results = <SplitResult>[];
    var ci = 0;
    var di = 0;
    final cBal = creditors.map((e) => e.value).toList();
    final dBal = debtors.map((e) => e.value).toList();

    while (ci < creditors.length && di < debtors.length) {
      final transfer = _round2(
          cBal[ci] < dBal[di] ? cBal[ci] : dBal[di]);
      if (transfer > 0) {
        results.add(SplitResult(
          userId: debtors[di].key,
          owes: transfer,
          owesTo: creditors[ci].key,
        ));
      }
      cBal[ci] = _round2(cBal[ci] - transfer);
      dBal[di] = _round2(dBal[di] - transfer);

      if (cBal[ci] == 0) ci++;
      if (dBal[di] == 0) di++;
    }

    return results;
  }

  double _round2(double value) =>
      (value * 100).roundToDouble() / 100;
}
