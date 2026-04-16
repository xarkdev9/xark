import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

void main() {
  final simplifier = DebtSimplifier();

  group('DebtSimplifier — simplification', () {
    test('3 people circular debt → simplified to 2 or fewer transfers', () {
      // A→B $30, B→C $20, C→A $10
      // Net: A: -30+10 = -20, B: +30-20 = +10, C: +20-10 = +10
      // Simplified: A pays B $10, A pays C $10 (2 transfers)
      final deltas = [
        const DebtDelta(from: 'A', to: 'B', amount: 30, currency: 'USD'),
        const DebtDelta(from: 'B', to: 'C', amount: 20, currency: 'USD'),
        const DebtDelta(from: 'C', to: 'A', amount: 10, currency: 'USD'),
      ];

      final result = simplifier.simplify(deltas, currency: 'USD');

      expect(result.length, lessThanOrEqualTo(2));

      // Verify total transferred is correct (sum of all amounts = 20)
      final totalTransferred = result.fold(0.0, (s, d) => s + d.amount);
      expect(totalTransferred, closeTo(20, 0.01));
    });

    test('5 people, 8 debts → fewer transactions after simplification', () {
      final deltas = [
        const DebtDelta(from: 'A', to: 'B', amount: 10, currency: 'USD'),
        const DebtDelta(from: 'A', to: 'C', amount: 15, currency: 'USD'),
        const DebtDelta(from: 'B', to: 'C', amount: 5, currency: 'USD'),
        const DebtDelta(from: 'B', to: 'D', amount: 20, currency: 'USD'),
        const DebtDelta(from: 'C', to: 'E', amount: 10, currency: 'USD'),
        const DebtDelta(from: 'D', to: 'A', amount: 8, currency: 'USD'),
        const DebtDelta(from: 'D', to: 'E', amount: 12, currency: 'USD'),
        const DebtDelta(from: 'E', to: 'B', amount: 5, currency: 'USD'),
      ];

      final result = simplifier.simplify(deltas, currency: 'USD');

      expect(result.length, lessThan(8));
    });

    test('already optimal (1 transfer) → unchanged', () {
      final deltas = [
        const DebtDelta(from: 'A', to: 'B', amount: 50, currency: 'USD'),
      ];

      final result = simplifier.simplify(deltas, currency: 'USD');

      expect(result.length, 1);
      expect(result.first.from, 'A');
      expect(result.first.to, 'B');
      expect(result.first.amount, closeTo(50, 0.01));
    });

    test('single debt → passthrough', () {
      final deltas = [
        const DebtDelta(from: 'X', to: 'Y', amount: 25, currency: 'EUR'),
      ];

      final result = simplifier.simplify(deltas, currency: 'EUR');

      expect(result.length, 1);
      expect(result.first.amount, closeTo(25, 0.01));
      expect(result.first.currency, 'EUR');
    });
  });

  group('DebtSimplifier — pairwise mode', () {
    test('returns original deltas', () {
      final deltas = [
        const DebtDelta(from: 'A', to: 'B', amount: 30, currency: 'USD'),
        const DebtDelta(from: 'B', to: 'C', amount: 20, currency: 'USD'),
      ];

      final result = simplifier.pairwise(deltas);

      expect(result.length, 2);
      expect(result[0].from, 'A');
      expect(result[1].from, 'B');
    });
  });

  group('DebtSimplifier — edge cases', () {
    test('empty deltas → empty result', () {
      final result = simplifier.simplify([], currency: 'USD');
      expect(result, isEmpty);
    });
  });
}
