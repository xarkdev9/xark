import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

Expense _expense({
  required double amount,
  required List<Payer> paidBy,
  required List<String> splitAmong,
  SplitMode mode = SplitMode.equal,
  Map<String, double>? splitDetails,
}) =>
    Expense(
      id: 'e1',
      title: 'Test',
      category: 'general',
      amount: amount,
      currency: 'USD',
      paidBy: paidBy,
      splitAmong: splitAmong,
      mode: mode,
      splitDetails: splitDetails,
      date: DateTime(2026, 1, 1),
    );

void main() {
  final calc = SplitCalculator();

  group('SplitCalculator — equal split', () {
    test('4 people, \$100 → each non-payer owes \$25', () {
      final expense = _expense(
        amount: 100,
        paidBy: [const Payer(userId: 'A', amount: 100)],
        splitAmong: ['A', 'B', 'C', 'D'],
      );

      final results = calc.calculate(expense);

      expect(results.length, 3);
      for (final r in results) {
        expect(r.owes, closeTo(25, 0.01));
        expect(r.owesTo, 'A');
      }
    });

    test('odd amount \$100 among 3 → handles rounding', () {
      final expense = _expense(
        amount: 100,
        paidBy: [const Payer(userId: 'A', amount: 100)],
        splitAmong: ['A', 'B', 'C'],
      );

      final results = calc.calculate(expense);

      // Total owed to A should be 100 - A's share ≈ 66.66 or 66.67
      final totalOwed = results.fold(0.0, (sum, r) => sum + r.owes);
      // A pays 100 but owes ~33.33/33.34, so others owe ~66.66/66.67
      expect(totalOwed, closeTo(66.66, 0.02));

      // Each result should be ~33.33 or ~33.34
      for (final r in results) {
        expect(r.owes, closeTo(33.33, 0.01));
        expect(r.owesTo, 'A');
      }
    });
  });

  group('SplitCalculator — exact split', () {
    test('custom amounts sum correctly', () {
      final expense = _expense(
        amount: 100,
        paidBy: [const Payer(userId: 'A', amount: 100)],
        splitAmong: ['A', 'B', 'C'],
        mode: SplitMode.exact,
        splitDetails: {'A': 60, 'B': 25, 'C': 15},
      );

      final results = calc.calculate(expense);

      final bOwes = results.firstWhere((r) => r.userId == 'B');
      final cOwes = results.firstWhere((r) => r.userId == 'C');
      expect(bOwes.owes, closeTo(25, 0.01));
      expect(cOwes.owes, closeTo(15, 0.01));
    });

    test('amounts don\'t sum to total → throws ArgumentError', () {
      final expense = _expense(
        amount: 100,
        paidBy: [const Payer(userId: 'A', amount: 100)],
        splitAmong: ['A', 'B'],
        mode: SplitMode.exact,
        splitDetails: {'A': 60, 'B': 30},
      );

      expect(() => calc.calculate(expense), throwsArgumentError);
    });
  });

  group('SplitCalculator — percentage split', () {
    test('50/30/20 of \$200 → correct amounts', () {
      final expense = _expense(
        amount: 200,
        paidBy: [const Payer(userId: 'A', amount: 200)],
        splitAmong: ['A', 'B', 'C'],
        mode: SplitMode.percentage,
        splitDetails: {'A': 50, 'B': 30, 'C': 20},
      );

      final results = calc.calculate(expense);

      // A's share is 100, A paid 200 → A is owed 100
      // B's share is 60 → B owes 60
      // C's share is 40 → C owes 40
      final bOwes = results.firstWhere((r) => r.userId == 'B');
      final cOwes = results.firstWhere((r) => r.userId == 'C');
      expect(bOwes.owes, closeTo(60, 0.01));
      expect(cOwes.owes, closeTo(40, 0.01));
    });

    test('percentages don\'t sum to 100 → throws ArgumentError', () {
      final expense = _expense(
        amount: 200,
        paidBy: [const Payer(userId: 'A', amount: 200)],
        splitAmong: ['A', 'B'],
        mode: SplitMode.percentage,
        splitDetails: {'A': 50, 'B': 40},
      );

      expect(() => calc.calculate(expense), throwsArgumentError);
    });
  });

  group('SplitCalculator — shares split', () {
    test('shares {A:2, B:1, C:1} of \$100', () {
      final expense = _expense(
        amount: 100,
        paidBy: [const Payer(userId: 'A', amount: 100)],
        splitAmong: ['A', 'B', 'C'],
        mode: SplitMode.shares,
        splitDetails: {'A': 2, 'B': 1, 'C': 1},
      );

      final results = calc.calculate(expense);

      // A's share = 50, A paid 100 → A is owed 50
      // B's share = 25 → B owes 25
      // C's share = 25 → C owes 25
      final bOwes = results.firstWhere((r) => r.userId == 'B');
      final cOwes = results.firstWhere((r) => r.userId == 'C');
      expect(bOwes.owes, closeTo(25, 0.01));
      expect(cOwes.owes, closeTo(25, 0.01));
    });
  });

  group('SplitCalculator — sub-group', () {
    test('6 of 10 members, only the 6 get split', () {
      final subGroup = ['A', 'B', 'C', 'D', 'E', 'F'];
      final expense = _expense(
        amount: 120,
        paidBy: [const Payer(userId: 'A', amount: 120)],
        splitAmong: subGroup,
      );

      final results = calc.calculate(expense);

      // Each of the 5 non-payers owes 20
      expect(results.length, 5);
      for (final r in results) {
        expect(subGroup.contains(r.userId), isTrue);
        expect(r.owes, closeTo(20, 0.01));
      }
    });
  });

  group('SplitCalculator — multi-payer', () {
    test('A pays \$60, B pays \$40, equal split among A,B,C,D', () {
      final expense = _expense(
        amount: 100,
        paidBy: [
          const Payer(userId: 'A', amount: 60),
          const Payer(userId: 'B', amount: 40),
        ],
        splitAmong: ['A', 'B', 'C', 'D'],
      );

      final results = calc.calculate(expense);

      // Each share is 25.
      // A paid 60, owes 25 → net +35 (is owed 35)
      // B paid 40, owes 25 → net +15 (is owed 15)
      // C paid 0, owes 25 → net -25 (owes 25)
      // D paid 0, owes 25 → net -25 (owes 25)
      // C owes 25, D owes 25 → total 50 owed, distributed to A (35) and B (15)
      final totalOwed = results.fold(0.0, (sum, r) => sum + r.owes);
      expect(totalOwed, closeTo(50, 0.01));

      // Every debtor should be C or D
      for (final r in results) {
        expect(['C', 'D'].contains(r.userId), isTrue);
      }
    });
  });

  group('SplitCalculator — edge cases', () {
    test('single payer, single member → no debt', () {
      final expense = _expense(
        amount: 50,
        paidBy: [const Payer(userId: 'A', amount: 50)],
        splitAmong: ['A'],
      );

      final results = calc.calculate(expense);
      expect(results, isEmpty);
    });

    test('zero amount → empty result', () {
      final expense = _expense(
        amount: 0,
        paidBy: [const Payer(userId: 'A', amount: 0)],
        splitAmong: ['A', 'B'],
      );

      final results = calc.calculate(expense);
      expect(results, isEmpty);
    });
  });
}
