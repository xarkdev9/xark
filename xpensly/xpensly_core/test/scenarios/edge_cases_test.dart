import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

List<Member> _members(int count) =>
    List.generate(count, (i) => Member(id: 'u$i', name: 'User $i'));

Expense _expense({
  required String id,
  required double amount,
  required String payerId,
  required List<String> splitAmong,
}) =>
    Expense(
      id: id,
      title: 'Expense $id',
      category: 'general',
      amount: amount,
      currency: 'USD',
      paidBy: [Payer(userId: payerId, amount: amount)],
      splitAmong: splitAmong,
      mode: SplitMode.equal,
      date: DateTime(2026, 1, 1),
    );

void main() {
  final engine = SettlementEngine();

  group('Edge cases', () {
    test('0 expenses → empty settlement', () {
      final result = engine.compute(
        members: _members(3),
        expenses: [],
        baseCurrency: 'USD',
      );

      expect(result.totalSpent, closeTo(0, 0.01));
      expect(result.deltas, isEmpty);
      expect(result.simplified, isEmpty);
    });

    test('1 member → no deltas', () {
      final members = _members(1);
      final expenses = [
        _expense(
          id: 'e1',
          amount: 50,
          payerId: 'u0',
          splitAmong: ['u0'],
        ),
      ];

      final result = engine.compute(
        members: members,
        expenses: expenses,
        baseCurrency: 'USD',
      );

      expect(result.deltas, isEmpty);
      expect(result.totalSpent, closeTo(50, 0.01));
    });

    test('all same payer → everyone owes them', () {
      final memberList = _members(4);
      final ids = memberList.map((m) => m.id).toList();
      final expenses = [
        _expense(id: 'e1', amount: 100, payerId: 'u0', splitAmong: ids),
        _expense(id: 'e2', amount: 80, payerId: 'u0', splitAmong: ids),
        _expense(id: 'e3', amount: 60, payerId: 'u0', splitAmong: ids),
      ];

      final result = engine.compute(
        members: memberList,
        expenses: expenses,
        baseCurrency: 'USD',
      );

      // Total 240, per person 60. u0 paid 240, owes 60 → net +180
      // Others each owe 60 → net -60 each
      for (final delta in result.deltas) {
        expect(delta.to, 'u0');
      }
      final totalOwed = result.deltas.fold(0.0, (s, d) => s + d.amount);
      expect(totalOwed, closeTo(180, 0.01));
    });

    test('zero-amount expense → no impact', () {
      final members = _members(2);
      final expenses = [
        _expense(id: 'e1', amount: 0, payerId: 'u0', splitAmong: ['u0', 'u1']),
      ];

      final result = engine.compute(
        members: members,
        expenses: expenses,
        baseCurrency: 'USD',
      );

      expect(result.deltas, isEmpty);
      expect(result.totalSpent, closeTo(0, 0.01));
    });

    test('very large group (15 members, 50 expenses) → completes without error', () {
      final members = _members(15);
      final ids = members.map((m) => m.id).toList();

      final expenses = List.generate(
        50,
        (i) => _expense(
          id: 'e$i',
          amount: 20.0 + i,
          payerId: ids[i % 15],
          splitAmong: ids,
        ),
      );

      final result = engine.compute(
        members: members,
        expenses: expenses,
        baseCurrency: 'USD',
      );

      expect(result.memberCount, 15);
      expect(result.totalSpent, greaterThan(0));

      // Verify balance consistency
      final positives = result.entries
          .where((e) => e.netBalance > 0)
          .fold(0.0, (s, e) => s + e.netBalance);
      final negatives = result.entries
          .where((e) => e.netBalance < 0)
          .fold(0.0, (s, e) => s + e.netBalance.abs());
      expect(positives, closeTo(negatives, 0.1));
    });
  });
}
