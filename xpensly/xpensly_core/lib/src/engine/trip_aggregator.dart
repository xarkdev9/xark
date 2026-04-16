import '../models/expense.dart';
import '../models/member.dart';
import '../models/split_mode.dart';
import '../models/trip_summary.dart';
import 'currency_converter.dart';

/// Aggregates expense data into a comprehensive trip summary.
///
/// Computes totals by currency, category, phase, and member, along
/// with top payer/spender and timeline data.
class TripAggregator {
  /// Produces a [TripSummary] from a list of expenses and members.
  ///
  /// All amounts are converted to [baseCurrency] for aggregation.
  /// Original currency amounts are preserved in [byCurrency].
  TripSummary summarize({
    required List<Expense> expenses,
    required List<Member> members,
    required String baseCurrency,
    Map<String, double> exchangeRates = const {},
    CurrencyConverter? converter,
  }) {
    final effectiveConverter = converter ?? CurrencyConverter();

    var totalSpent = 0.0;
    final byCurrency = <String, double>{};
    final byCategory = <String, double>{};
    final byPhase = <String, double>{};
    final byMemberPaid = <String, double>{};
    final byMemberShare = <String, double>{};
    final dailyMap = <DateTime, _DailyAccumulator>{};

    for (final expense in expenses) {
      final convertedAmount = _convertAmount(
        expense.amount,
        expense.currency,
        baseCurrency,
        exchangeRates,
        effectiveConverter,
      );

      totalSpent += convertedAmount;

      // By original currency.
      byCurrency[expense.currency] =
          (byCurrency[expense.currency] ?? 0.0) + expense.amount;

      // By category (in base currency).
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0.0) + convertedAmount;

      // By phase (in base currency).
      if (expense.phase != null) {
        byPhase[expense.phase!] =
            (byPhase[expense.phase!] ?? 0.0) + convertedAmount;
      }

      // By member paid (in base currency).
      for (final payer in expense.paidBy) {
        final convertedPaid = _convertAmount(
          payer.amount,
          expense.currency,
          baseCurrency,
          exchangeRates,
          effectiveConverter,
        );
        byMemberPaid[payer.userId] =
            (byMemberPaid[payer.userId] ?? 0.0) + convertedPaid;
      }

      // By member share (in base currency).
      final shareMap = _computeShareMap(expense);
      for (final entry in shareMap.entries) {
        final convertedShare = _convertAmount(
          entry.value,
          expense.currency,
          baseCurrency,
          exchangeRates,
          effectiveConverter,
        );
        byMemberShare[entry.key] =
            (byMemberShare[entry.key] ?? 0.0) + convertedShare;
      }

      // Timeline: group by date (date only, no time).
      final dateKey = DateTime(
          expense.date.year, expense.date.month, expense.date.day);
      final acc = dailyMap[dateKey] ??
          _DailyAccumulator(date: dateKey);
      acc.total += convertedAmount;
      acc.count += 1;
      dailyMap[dateKey] = acc;
    }

    // Top payer: member who paid the most.
    final topPayer = _maxKey(byMemberPaid);

    // Top spender: member whose split share is highest.
    final topSpender = _maxKey(byMemberShare);

    // Distinct expense dates for avgPerDay.
    final distinctDates = dailyMap.length;
    final avgPerDay = distinctDates > 0
        ? _round2(totalSpent / distinctDates)
        : 0.0;

    final avgPerPerson = members.isNotEmpty
        ? _round2(totalSpent / members.length)
        : 0.0;

    // Build sorted timeline.
    final sortedDates = dailyMap.keys.toList()..sort();
    final timeline = sortedDates
        .map((d) => DailyTotal(
              date: d,
              total: _round2(dailyMap[d]!.total),
              count: dailyMap[d]!.count,
            ))
        .toList();

    return TripSummary(
      totalSpent: _round2(totalSpent),
      byCurrency: byCurrency,
      byCategory: byCategory,
      byPhase: byPhase,
      byMember: byMemberPaid,
      topPayer: topPayer,
      topSpender: topSpender,
      avgPerDay: avgPerDay,
      avgPerPerson: avgPerPerson,
      timeline: timeline,
    );
  }

  /// Computes per-user share amounts for an expense.
  Map<String, double> _computeShareMap(Expense expense) {
    final shares = <String, double>{};
    final count = expense.splitAmong.length;

    switch (expense.mode) {
      case SplitMode.equal:
        final baseShare =
            (expense.amount * 100).round() ~/ count;
        final remainder =
            (expense.amount * 100).round() - baseShare * count;
        for (var i = 0; i < count; i++) {
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

  /// Returns the key with the largest value, or empty string if the map
  /// is empty.
  String _maxKey(Map<String, double> map) {
    if (map.isEmpty) return '';
    var maxKey = map.keys.first;
    var maxVal = map.values.first;
    for (final entry in map.entries) {
      if (entry.value > maxVal) {
        maxKey = entry.key;
        maxVal = entry.value;
      }
    }
    return maxKey;
  }

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

class _DailyAccumulator {
  final DateTime date;
  double total = 0.0;
  int count = 0;

  _DailyAccumulator({required this.date});
}
