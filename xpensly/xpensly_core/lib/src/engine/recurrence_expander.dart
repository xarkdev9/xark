import '../models/expense.dart';

/// Expands a recurring expense into individual expense instances.
///
/// Takes a single expense with a [Recurrence] schedule and generates
/// one expense per occurrence from [expense.date] up to (but not
/// including) [expense.recurring.until].
class RecurrenceExpander {
  /// Expands a recurring expense into a list of individual expenses.
  ///
  /// If [expense.recurring] is null, returns a single-element list
  /// containing the original expense unchanged.
  ///
  /// Supported frequencies: "daily", "weekly", "monthly".
  /// Each generated expense receives an id of `${expense.id}_${index}`
  /// and has its [recurring] field set to null.
  List<Expense> expand(Expense expense) {
    if (expense.recurring == null) return [expense];

    final recurrence = expense.recurring!;
    final results = <Expense>[];
    var current = expense.date;
    var index = 0;

    while (current.isBefore(recurrence.until)) {
      results.add(Expense(
        id: '${expense.id}_$index',
        title: expense.title,
        category: expense.category,
        amount: expense.amount,
        currency: expense.currency,
        paidBy: expense.paidBy,
        splitAmong: expense.splitAmong,
        mode: expense.mode,
        splitDetails: expense.splitDetails,
        date: current,
        phase: expense.phase,
        notes: expense.notes,
        receiptUrl: expense.receiptUrl,
        recurring: null,
        tags: expense.tags,
      ));

      current = _advance(current, recurrence.frequency);
      index++;
    }

    return results;
  }

  /// Advances a date by one period based on the frequency string.
  DateTime _advance(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily':
        return DateTime(date.year, date.month, date.day + 1);
      case 'weekly':
        return DateTime(date.year, date.month, date.day + 7);
      case 'monthly':
        return DateTime(date.year, date.month + 1, date.day);
      default:
        throw ArgumentError('Unsupported frequency: $frequency');
    }
  }
}
