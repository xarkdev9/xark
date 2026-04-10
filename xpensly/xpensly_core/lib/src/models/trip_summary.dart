/// A single day's expense total for timeline display.
class DailyTotal {
  final DateTime date;
  final double total;
  final int count;

  const DailyTotal({
    required this.date,
    required this.total,
    required this.count,
  });

  @override
  String toString() =>
      'DailyTotal(date: $date, total: $total, count: $count)';
}

/// Aggregated analytics for a trip's expenses.
class TripSummary {
  final double totalSpent;

  /// Total spend grouped by currency code.
  final Map<String, double> byCurrency;

  /// Total spend grouped by category.
  final Map<String, double> byCategory;

  /// Total spend grouped by trip phase name.
  final Map<String, double> byPhase;

  /// Total spend grouped by member ID.
  final Map<String, double> byMember;

  /// User ID of the member who paid the most.
  final String topPayer;

  /// User ID of the member whose share is largest.
  final String topSpender;

  /// Average daily spend across the trip duration.
  final double avgPerDay;

  /// Average spend per person.
  final double avgPerPerson;

  /// Day-by-day expense timeline.
  final List<DailyTotal> timeline;

  const TripSummary({
    required this.totalSpent,
    required this.byCurrency,
    required this.byCategory,
    required this.byPhase,
    required this.byMember,
    required this.topPayer,
    required this.topSpender,
    required this.avgPerDay,
    required this.avgPerPerson,
    required this.timeline,
  });

  @override
  String toString() =>
      'TripSummary(totalSpent: $totalSpent, avgPerDay: $avgPerDay, '
      'avgPerPerson: $avgPerPerson, topPayer: $topPayer)';
}
