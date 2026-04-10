import 'split_mode.dart';

/// A single payer contribution within a multi-payer expense.
class Payer {
  final String userId;
  final double amount;

  const Payer({required this.userId, required this.amount});

  @override
  String toString() => 'Payer(userId: $userId, amount: $amount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payer &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          amount == other.amount;

  @override
  int get hashCode => Object.hash(userId, amount);
}

/// A recurring schedule for an expense.
class Recurrence {
  /// One of: "daily", "weekly", "monthly".
  final String frequency;

  /// When the recurrence ends.
  final DateTime until;

  const Recurrence({required this.frequency, required this.until});

  @override
  String toString() =>
      'Recurrence(frequency: $frequency, until: $until)';
}

/// A single expense entry with multi-payer and sub-group splitting support.
class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final String currency;

  /// Who paid and how much each person contributed.
  final List<Payer> paidBy;

  /// User IDs of members this expense is split among.
  final List<String> splitAmong;

  /// How the expense is divided.
  final SplitMode mode;

  /// Per-user overrides for exact, percentage, or shares split modes.
  /// Keys are user IDs; values depend on the mode:
  /// - exact: absolute amount owed
  /// - percentage: percentage of total (should sum to 100)
  /// - shares: relative share weight
  final Map<String, double>? splitDetails;

  final DateTime date;

  /// Optional trip phase this expense belongs to.
  final String? phase;

  /// Free-form notes.
  final String? notes;

  /// URL to an uploaded receipt image.
  final String? receiptUrl;

  /// Recurring schedule, if this expense repeats.
  final Recurrence? recurring;

  /// Arbitrary tags for filtering and grouping.
  final List<String> tags;

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.currency,
    required this.paidBy,
    required this.splitAmong,
    required this.mode,
    this.splitDetails,
    required this.date,
    this.phase,
    this.notes,
    this.receiptUrl,
    this.recurring,
    this.tags = const [],
  });

  @override
  String toString() =>
      'Expense(id: $id, title: $title, amount: $amount $currency, '
      'mode: $mode, paidBy: ${paidBy.length} payer(s), '
      'splitAmong: ${splitAmong.length} member(s))';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          amount == other.amount &&
          currency == other.currency &&
          mode == other.mode &&
          date == other.date;

  @override
  int get hashCode =>
      Object.hash(id, title, category, amount, currency, mode, date);
}
