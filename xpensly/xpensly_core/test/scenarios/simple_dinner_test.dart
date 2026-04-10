import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

void main() {
  test('Simple dinner: \$80, Alice pays, split 4 ways → 3 deltas of \$20', () {
    final members = ['alice', 'bob', 'charlie', 'diana']
        .map((id) => Member(id: id, name: id))
        .toList();

    final result = SettlementEngine().compute(
      members: members,
      expenses: [
        Expense(
          id: 'dinner',
          title: 'Dinner',
          category: 'food',
          amount: 80,
          currency: 'USD',
          paidBy: [const Payer(userId: 'alice', amount: 80)],
          splitAmong: ['alice', 'bob', 'charlie', 'diana'],
          mode: SplitMode.equal,
          date: DateTime(2026, 3, 1),
        ),
      ],
      baseCurrency: 'USD',
    );

    expect(result.deltas.length, 3);
    for (final d in result.deltas) {
      expect(d.to, 'alice');
      expect(d.amount, closeTo(20, 0.01));
    }
  });
}
