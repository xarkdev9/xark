import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

void main() {
  group('Roommates — recurring rent', () {
    test('3 months of \$3000 rent → Bob and Charlie each owe \$3000', () {
      final members = ['alice', 'bob', 'charlie']
          .map((id) => Member(id: id, name: id))
          .toList();

      final expander = RecurrenceExpander();
      final engine = SettlementEngine();

      // Alice pays $3000/month rent, split 3 ways
      final rentTemplate = Expense(
        id: 'rent',
        title: 'Rent',
        category: 'rent',
        amount: 3000,
        currency: 'USD',
        paidBy: [const Payer(userId: 'alice', amount: 3000)],
        splitAmong: ['alice', 'bob', 'charlie'],
        mode: SplitMode.equal,
        date: DateTime(2026, 1, 1),
        recurring: Recurrence(
          frequency: 'monthly',
          until: DateTime(2026, 4, 1), // Jan, Feb, Mar = 3 months
        ),
      );

      final expanded = expander.expand(rentTemplate);
      expect(expanded.length, 3);

      final result = engine.compute(
        members: members,
        expenses: expanded,
        baseCurrency: 'USD',
      );

      // Total: 9000, per person: 3000
      expect(result.totalSpent, closeTo(9000, 0.01));
      expect(result.perPerson, closeTo(3000, 0.01));

      // Alice paid 9000, owes 3000 → net +6000
      // Bob paid 0, owes 3000 → net -3000
      // Charlie paid 0, owes 3000 → net -3000
      final bobEntry = result.entries.firstWhere((e) => e.userId == 'bob');
      final charlieEntry =
          result.entries.firstWhere((e) => e.userId == 'charlie');

      expect(bobEntry.netBalance, closeTo(-3000, 0.01));
      expect(charlieEntry.netBalance, closeTo(-3000, 0.01));

      // Should have 2 deltas: bob→alice $3000, charlie→alice $3000
      expect(result.deltas.length, 2);
      for (final d in result.deltas) {
        expect(d.to, 'alice');
        expect(d.amount, closeTo(3000, 0.01));
      }
    });
  });
}
