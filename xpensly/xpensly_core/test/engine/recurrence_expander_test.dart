import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

Expense _recurring({
  required String frequency,
  required DateTime start,
  required DateTime until,
}) =>
    Expense(
      id: 'rec1',
      title: 'Recurring Expense',
      category: 'rent',
      amount: 1000,
      currency: 'USD',
      paidBy: [const Payer(userId: 'A', amount: 1000)],
      splitAmong: ['A', 'B'],
      mode: SplitMode.equal,
      date: start,
      recurring: Recurrence(frequency: frequency, until: until),
    );

void main() {
  final expander = RecurrenceExpander();

  group('RecurrenceExpander', () {
    test('daily x 5 days → 5 expenses', () {
      final expense = _recurring(
        frequency: 'daily',
        start: DateTime(2026, 1, 1),
        until: DateTime(2026, 1, 6), // 5 days: Jan 1-5
      );

      final results = expander.expand(expense);

      expect(results.length, 5);
      expect(results[0].date, DateTime(2026, 1, 1));
      expect(results[4].date, DateTime(2026, 1, 5));
    });

    test('weekly x 3 weeks → 3 expenses', () {
      final expense = _recurring(
        frequency: 'weekly',
        start: DateTime(2026, 1, 1),
        until: DateTime(2026, 1, 22), // 3 weeks: Jan 1, 8, 15
      );

      final results = expander.expand(expense);

      expect(results.length, 3);
      expect(results[0].date, DateTime(2026, 1, 1));
      expect(results[1].date, DateTime(2026, 1, 8));
      expect(results[2].date, DateTime(2026, 1, 15));
    });

    test('monthly x 2 months → 2 expenses', () {
      final expense = _recurring(
        frequency: 'monthly',
        start: DateTime(2026, 1, 1),
        until: DateTime(2026, 3, 1), // 2 months: Jan 1, Feb 1
      );

      final results = expander.expand(expense);

      expect(results.length, 2);
      expect(results[0].date, DateTime(2026, 1, 1));
      expect(results[1].date, DateTime(2026, 2, 1));
    });

    test('non-recurring expense → returns single item', () {
      final expense = Expense(
        id: 'single',
        title: 'One-off',
        category: 'food',
        amount: 50,
        currency: 'USD',
        paidBy: [const Payer(userId: 'A', amount: 50)],
        splitAmong: ['A', 'B'],
        mode: SplitMode.equal,
        date: DateTime(2026, 3, 1),
      );

      final results = expander.expand(expense);

      expect(results.length, 1);
      expect(results.first.id, 'single');
    });

    test('preserves all fields except recurring (null) and id (suffixed)', () {
      final expense = _recurring(
        frequency: 'daily',
        start: DateTime(2026, 1, 1),
        until: DateTime(2026, 1, 3),
      );

      final results = expander.expand(expense);

      expect(results.length, 2);
      for (final r in results) {
        expect(r.recurring, isNull);
        expect(r.title, expense.title);
        expect(r.category, expense.category);
        expect(r.amount, expense.amount);
        expect(r.currency, expense.currency);
        expect(r.mode, expense.mode);
      }
      expect(results[0].id, 'rec1_0');
      expect(results[1].id, 'rec1_1');
    });
  });
}
