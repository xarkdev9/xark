import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

List<Member> _members(List<String> ids) =>
    ids.map((id) => Member(id: id, name: id)).toList();

Expense _expense({
  required String id,
  required double amount,
  required String payerId,
  required List<String> splitAmong,
  required String category,
  DateTime? date,
}) =>
    Expense(
      id: id,
      title: 'Expense $id',
      category: category,
      amount: amount,
      currency: 'USD',
      paidBy: [Payer(userId: payerId, amount: amount)],
      splitAmong: splitAmong,
      mode: SplitMode.equal,
      date: date ?? DateTime(2026, 1, 1),
    );

void main() {
  final aggregator = TripAggregator();
  final members = _members(['A', 'B', 'C']);

  group('TripAggregator — byCategory', () {
    test('2 food + 1 transport → correct sums', () {
      final expenses = [
        _expense(
            id: 'e1', amount: 30, payerId: 'A', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
        _expense(
            id: 'e2', amount: 20, payerId: 'B', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
        _expense(
            id: 'e3', amount: 50, payerId: 'C', splitAmong: ['A', 'B', 'C'],
            category: 'transport'),
      ];

      final summary = aggregator.summarize(
        expenses: expenses,
        members: members,
        baseCurrency: 'USD',
      );

      expect(summary.byCategory['food'], closeTo(50, 0.01));
      expect(summary.byCategory['transport'], closeTo(50, 0.01));
    });
  });

  group('TripAggregator — byMember', () {
    test('3 members with different amounts', () {
      final expenses = [
        _expense(
            id: 'e1', amount: 100, payerId: 'A', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
        _expense(
            id: 'e2', amount: 50, payerId: 'B', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
        _expense(
            id: 'e3', amount: 30, payerId: 'C', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
      ];

      final summary = aggregator.summarize(
        expenses: expenses,
        members: members,
        baseCurrency: 'USD',
      );

      // byMember is byMemberPaid in the implementation
      expect(summary.byMember['A'], closeTo(100, 0.01));
      expect(summary.byMember['B'], closeTo(50, 0.01));
      expect(summary.byMember['C'], closeTo(30, 0.01));
    });
  });

  group('TripAggregator — topPayer', () {
    test('identifies member who paid the most', () {
      final expenses = [
        _expense(
            id: 'e1', amount: 200, payerId: 'A', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
        _expense(
            id: 'e2', amount: 50, payerId: 'B', splitAmong: ['A', 'B', 'C'],
            category: 'food'),
      ];

      final summary = aggregator.summarize(
        expenses: expenses,
        members: members,
        baseCurrency: 'USD',
      );

      expect(summary.topPayer, 'A');
    });
  });

  group('TripAggregator — averages', () {
    test('avgPerPerson and avgPerDay', () {
      final expenses = [
        _expense(
            id: 'e1', amount: 60, payerId: 'A', splitAmong: ['A', 'B', 'C'],
            category: 'food', date: DateTime(2026, 1, 1)),
        _expense(
            id: 'e2', amount: 90, payerId: 'B', splitAmong: ['A', 'B', 'C'],
            category: 'food', date: DateTime(2026, 1, 2)),
      ];

      final summary = aggregator.summarize(
        expenses: expenses,
        members: members,
        baseCurrency: 'USD',
      );

      // Total 150, 3 members → avgPerPerson = 50
      expect(summary.avgPerPerson, closeTo(50, 0.01));
      // 2 distinct days → avgPerDay = 75
      expect(summary.avgPerDay, closeTo(75, 0.01));
    });
  });

  group('TripAggregator — timeline', () {
    test('3 expenses over 2 days → 2 DailyTotal entries', () {
      final expenses = [
        _expense(
            id: 'e1', amount: 30, payerId: 'A', splitAmong: ['A', 'B'],
            category: 'food', date: DateTime(2026, 1, 1)),
        _expense(
            id: 'e2', amount: 20, payerId: 'B', splitAmong: ['A', 'B'],
            category: 'food', date: DateTime(2026, 1, 1)),
        _expense(
            id: 'e3', amount: 50, payerId: 'A', splitAmong: ['A', 'B'],
            category: 'transport', date: DateTime(2026, 1, 2)),
      ];

      final summary = aggregator.summarize(
        expenses: expenses,
        members: _members(['A', 'B']),
        baseCurrency: 'USD',
      );

      expect(summary.timeline.length, 2);
      expect(summary.timeline[0].total, closeTo(50, 0.01));
      expect(summary.timeline[0].count, 2);
      expect(summary.timeline[1].total, closeTo(50, 0.01));
      expect(summary.timeline[1].count, 1);
    });
  });
}
