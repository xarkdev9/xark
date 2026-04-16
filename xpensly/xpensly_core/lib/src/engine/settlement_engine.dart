import '../models/debt_delta.dart';
import '../models/expense.dart';
import '../models/member.dart';
import '../models/refund.dart';
import '../models/settlement.dart';
import '../models/settlement_record.dart';
import '../models/split_mode.dart';
import 'currency_converter.dart';
import 'debt_simplifier.dart';

/// Computes full settlement for a group of expenses, refunds, and
/// prior settlements.
///
/// Produces a [Settlement] containing per-member ledger entries,
/// raw pairwise debts, simplified debts, and aggregate statistics.
class SettlementEngine {

  /// Computes the settlement across all provided expenses, refunds,
  /// and prior settlement records.
  ///
  /// [members] — all participants in the group.
  /// [expenses] — all expenses to settle.
  /// [refunds] — any refunds issued against expenses.
  /// [priorSettlements] — previously recorded payments between members.
  /// [baseCurrency] — the target currency for aggregation.
  /// [exchangeRates] — rates relative to a common base for conversion.
  /// [simplifier] — optional custom debt simplifier (defaults to [DebtSimplifier]).
  /// [converter] — optional custom currency converter (defaults to [CurrencyConverter]).
  Settlement compute({
    required List<Member> members,
    required List<Expense> expenses,
    List<Refund> refunds = const [],
    List<SettlementRecord> priorSettlements = const [],
    required String baseCurrency,
    Map<String, double> exchangeRates = const {},
    DebtSimplifier? simplifier,
    CurrencyConverter? converter,
  }) {
    final effectiveSimplifier = simplifier ?? DebtSimplifier();
    final effectiveConverter = converter ?? CurrencyConverter();

    // Per-user balance: positive = owed money, negative = owes money.
    final balances = <String, double>{};

    // Per-user tracking for ledger entries.
    final totalPaidMap = <String, double>{};
    final totalOwesMap = <String, double>{};
    final expenseItems = <String, List<ExpenseItem>>{};

    // Aggregate stats.
    final byCurrency = <String, double>{};
    final byCategory = <String, double>{};
    var totalSpent = 0.0;

    // Initialize maps for all members.
    for (final m in members) {
      balances[m.id] = 0.0;
      totalPaidMap[m.id] = 0.0;
      totalOwesMap[m.id] = 0.0;
      expenseItems[m.id] = [];
    }

    // Step 1: Process each expense.
    for (final expense in expenses) {
      final convertedAmount = _convertAmount(
        expense.amount,
        expense.currency,
        baseCurrency,
        exchangeRates,
        effectiveConverter,
      );

      // Aggregate by original currency.
      byCurrency[expense.currency] =
          (byCurrency[expense.currency] ?? 0.0) + expense.amount;

      // Aggregate by category.
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0.0) + convertedAmount;

      totalSpent += convertedAmount;

      // Credit each payer.
      for (final payer in expense.paidBy) {
        final convertedPaid = _convertAmount(
          payer.amount,
          expense.currency,
          baseCurrency,
          exchangeRates,
          effectiveConverter,
        );
        balances[payer.userId] =
            (balances[payer.userId] ?? 0.0) + convertedPaid;
        totalPaidMap[payer.userId] =
            (totalPaidMap[payer.userId] ?? 0.0) + convertedPaid;
      }

      // Debit each user for their share.
      final shareMap = _computeShareMap(expense);

      for (final entry in shareMap.entries) {
        final userId = entry.key;
        final convertedShare = _convertAmount(
          entry.value,
          expense.currency,
          baseCurrency,
          exchangeRates,
          effectiveConverter,
        );
        balances[userId] =
            (balances[userId] ?? 0.0) - convertedShare;
        totalOwesMap[userId] =
            (totalOwesMap[userId] ?? 0.0) + convertedShare;
        expenseItems[userId] ??= [];
        expenseItems[userId]!.add(
            ExpenseItem(title: expense.title, amount: convertedShare));
      }
    }

    // Step 2: Apply refunds.
    for (final refund in refunds) {
      final convertedAmount = _convertAmount(
        refund.amount,
        refund.currency,
        baseCurrency,
        exchangeRates,
        effectiveConverter,
      );
      balances[refund.refundedTo] =
          (balances[refund.refundedTo] ?? 0.0) + convertedAmount;
    }

    // Step 3: Apply prior settlements.
    for (final settlement in priorSettlements) {
      final convertedAmount = _convertAmount(
        settlement.amount,
        settlement.currency,
        baseCurrency,
        exchangeRates,
        effectiveConverter,
      );
      balances[settlement.fromUser] =
          (balances[settlement.fromUser] ?? 0.0) - convertedAmount;
      balances[settlement.toUser] =
          (balances[settlement.toUser] ?? 0.0) + convertedAmount;
    }

    // Step 4: Build ledger entries.
    final entries = <LedgerEntry>[];
    for (final m in members) {
      entries.add(LedgerEntry(
        userId: m.id,
        name: m.name,
        totalPaid: _round2(totalPaidMap[m.id] ?? 0.0),
        totalOwes: _round2(totalOwesMap[m.id] ?? 0.0),
        netBalance: _round2(balances[m.id] ?? 0.0),
        items: expenseItems[m.id] ?? [],
      ));
    }

    // Step 5: Build raw debt deltas from balances.
    final deltas = _buildDeltas(balances, baseCurrency);

    // Step 6: Simplify.
    final simplified = effectiveSimplifier.simplify(
      deltas,
      currency: baseCurrency,
    );

    final memberCount = members.length;
    final perPerson =
        memberCount > 0 ? _round2(totalSpent / memberCount) : 0.0;

    return Settlement(
      entries: entries,
      deltas: deltas,
      simplified: simplified,
      totalSpent: _round2(totalSpent),
      perPerson: perPerson,
      byCurrency: byCurrency,
      byCategory: byCategory,
      memberCount: memberCount,
    );
  }

  /// Computes settlement as of a specific date, filtering expenses,
  /// refunds, and settlements to only those on or before [asOf].
  Settlement computeAsOf({
    required List<Member> members,
    required List<Expense> expenses,
    List<Refund> refunds = const [],
    List<SettlementRecord> priorSettlements = const [],
    required String baseCurrency,
    Map<String, double> exchangeRates = const {},
    required DateTime asOf,
    DebtSimplifier? simplifier,
    CurrencyConverter? converter,
  }) {
    final filteredExpenses = expenses
        .where((e) =>
            e.date.isBefore(asOf) || e.date.isAtSameMomentAs(asOf))
        .toList();

    final filteredRefunds = refunds
        .where((r) =>
            r.date.isBefore(asOf) || r.date.isAtSameMomentAs(asOf))
        .toList();

    final filteredSettlements = priorSettlements
        .where((s) =>
            s.settledAt.isBefore(asOf) ||
            s.settledAt.isAtSameMomentAs(asOf))
        .toList();

    return compute(
      members: members,
      expenses: filteredExpenses,
      refunds: filteredRefunds,
      priorSettlements: filteredSettlements,
      baseCurrency: baseCurrency,
      exchangeRates: exchangeRates,
      simplifier: simplifier,
      converter: converter,
    );
  }

  /// Computes each user's share of an expense based on its split mode.
  Map<String, double> _computeShareMap(Expense expense) {
    final shares = <String, double>{};
    final count = expense.splitAmong.length;

    switch (expense.mode) {
      case SplitMode.equal:
        final baseShare =
            (expense.amount * 100).round() ~/ count;
        final remainder =
            (expense.amount * 100).round() - baseShare * count;
        for (var i = 0; i < expense.splitAmong.length; i++) {
          final cents = baseShare + (i < remainder ? 1 : 0);
          shares[expense.splitAmong[i]] = cents / 100.0;
        }
        break;

      case SplitMode.exact:
        shares.addAll(expense.splitDetails!);
        break;

      case SplitMode.percentage:
        final totalCents = (expense.amount * 100).round();
        final entries = expense.splitDetails!.entries.toList();
        var allocated = 0;
        for (var i = 0; i < entries.length; i++) {
          if (i == entries.length - 1) {
            shares[entries[i].key] = (totalCents - allocated) / 100.0;
          } else {
            final cents =
                (entries[i].value / 100.0 * totalCents).round();
            shares[entries[i].key] = cents / 100.0;
            allocated += cents;
          }
        }
        break;

      case SplitMode.shares:
        final totalShares =
            expense.splitDetails!.values.fold(0.0, (a, b) => a + b);
        final totalCents = (expense.amount * 100).round();
        final entries = expense.splitDetails!.entries.toList();
        var allocated = 0;
        for (var i = 0; i < entries.length; i++) {
          if (i == entries.length - 1) {
            shares[entries[i].key] = (totalCents - allocated) / 100.0;
          } else {
            final cents =
                (entries[i].value / totalShares * totalCents).round();
            shares[entries[i].key] = cents / 100.0;
            allocated += cents;
          }
        }
        break;
    }

    return shares;
  }

  /// Builds raw debt deltas from net balances.
  List<DebtDelta> _buildDeltas(
      Map<String, double> balances, String currency) {
    final creditors = <_Entry>[];
    final debtors = <_Entry>[];

    for (final entry in balances.entries) {
      final rounded = _round2(entry.value);
      if (rounded > 0) {
        creditors.add(_Entry(entry.key, rounded));
      } else if (rounded < 0) {
        debtors.add(_Entry(entry.key, rounded.abs()));
      }
    }

    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final deltas = <DebtDelta>[];
    var ci = 0;
    var di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final transfer = _round2(creditors[ci].amount < debtors[di].amount
          ? creditors[ci].amount
          : debtors[di].amount);

      if (transfer > 0) {
        deltas.add(DebtDelta(
          from: debtors[di].userId,
          to: creditors[ci].userId,
          amount: transfer,
          currency: currency,
        ));
      }

      creditors[ci] = _Entry(
          creditors[ci].userId,
          _round2(creditors[ci].amount - transfer));
      debtors[di] = _Entry(
          debtors[di].userId,
          _round2(debtors[di].amount - transfer));

      if (creditors[ci].amount == 0) ci++;
      if (debtors[di].amount == 0) di++;
    }

    return deltas;
  }

  /// Converts an amount between currencies, returning the original
  /// amount if both currencies are the same or no rates are provided.
  double _convertAmount(
    double amount,
    String from,
    String to,
    Map<String, double> rates,
    CurrencyConverter converter,
  ) {
    if (from == to || rates.isEmpty) return amount;
    return converter.convert(amount, from, to, rates);
  }

  double _round2(double value) =>
      (value * 100).roundToDouble() / 100;
}

class _Entry {
  final String userId;
  final double amount;

  const _Entry(this.userId, this.amount);
}
