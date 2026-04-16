import 'debt_delta.dart';

/// A single expense line item within a ledger entry.
class ExpenseItem {
  final String title;
  final double amount;

  const ExpenseItem({required this.title, required this.amount});

  @override
  String toString() => 'ExpenseItem(title: $title, amount: $amount)';
}

/// Per-member ledger summary showing what they paid, owe, and their net balance.
class LedgerEntry {
  final String userId;
  final String name;
  final double totalPaid;
  final double totalOwes;
  final double netBalance;
  final List<ExpenseItem> items;

  const LedgerEntry({
    required this.userId,
    required this.name,
    required this.totalPaid,
    required this.totalOwes,
    required this.netBalance,
    required this.items,
  });

  @override
  String toString() =>
      'LedgerEntry(userId: $userId, name: $name, '
      'paid: $totalPaid, owes: $totalOwes, net: $netBalance)';
}

/// Complete settlement result for a group of expenses.
class Settlement {
  /// Per-member ledger breakdown.
  final List<LedgerEntry> entries;

  /// Raw pairwise debts before simplification.
  final List<DebtDelta> deltas;

  /// Minimum-transaction simplified debts.
  final List<DebtDelta> simplified;

  /// Total amount spent across all expenses.
  final double totalSpent;

  /// Average spend per person.
  final double perPerson;

  /// Total spend grouped by currency code.
  final Map<String, double> byCurrency;

  /// Total spend grouped by category.
  final Map<String, double> byCategory;

  /// Number of members in the settlement.
  final int memberCount;

  const Settlement({
    required this.entries,
    required this.deltas,
    required this.simplified,
    required this.totalSpent,
    required this.perPerson,
    required this.byCurrency,
    required this.byCategory,
    required this.memberCount,
  });

  @override
  String toString() =>
      'Settlement(totalSpent: $totalSpent, perPerson: $perPerson, '
      'members: $memberCount, deltas: ${deltas.length}, '
      'simplified: ${simplified.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settlement &&
          runtimeType == other.runtimeType &&
          totalSpent == other.totalSpent &&
          perPerson == other.perPerson &&
          memberCount == other.memberCount &&
          deltas.length == other.deltas.length &&
          simplified.length == other.simplified.length;

  @override
  int get hashCode =>
      Object.hash(totalSpent, perPerson, memberCount,
          Object.hashAll(deltas), Object.hashAll(simplified));
}
