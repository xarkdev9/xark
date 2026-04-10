import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

void main() {
  final members = ['alice', 'bob', 'charlie']
      .map((id) => Member(id: id, name: id))
      .toList();

  // Rates relative to EUR as base.
  final rates = {'EUR': 1.0, 'GBP': 0.86, 'CHF': 0.94};
  final converter = CurrencyConverter();
  final engine = SettlementEngine();
  final aggregator = TripAggregator();

  final expenses = [
    Expense(
      id: 'e1',
      title: 'Paris dinner',
      category: 'food',
      amount: 120,
      currency: 'EUR',
      paidBy: [const Payer(userId: 'alice', amount: 120)],
      splitAmong: ['alice', 'bob', 'charlie'],
      mode: SplitMode.equal,
      date: DateTime(2026, 5, 1),
    ),
    Expense(
      id: 'e2',
      title: 'London taxi',
      category: 'transport',
      amount: 45,
      currency: 'GBP',
      paidBy: [const Payer(userId: 'bob', amount: 45)],
      splitAmong: ['alice', 'bob', 'charlie'],
      mode: SplitMode.equal,
      date: DateTime(2026, 5, 5),
    ),
    Expense(
      id: 'e3',
      title: 'Swiss chocolate',
      category: 'food',
      amount: 30,
      currency: 'CHF',
      paidBy: [const Payer(userId: 'charlie', amount: 30)],
      splitAmong: ['alice', 'bob', 'charlie'],
      mode: SplitMode.equal,
      date: DateTime(2026, 5, 8),
    ),
  ];

  group('Multi-currency trip', () {
    test('conversion to base currency is correct', () {
      final result = engine.compute(
        members: members,
        expenses: expenses,
        baseCurrency: 'EUR',
        exchangeRates: rates,
        converter: converter,
      );

      // EUR dinner: 120 EUR
      // GBP taxi: 45 * (1.0 / 0.86) ≈ 52.33 EUR
      // CHF chocolate: 30 * (1.0 / 0.94) ≈ 31.91 EUR
      // Total ≈ 204.24 EUR
      expect(result.totalSpent, closeTo(204.24, 0.5));
    });

    test('byCurrency shows original amounts', () {
      final result = engine.compute(
        members: members,
        expenses: expenses,
        baseCurrency: 'EUR',
        exchangeRates: rates,
        converter: converter,
      );

      expect(result.byCurrency['EUR'], closeTo(120, 0.01));
      expect(result.byCurrency['GBP'], closeTo(45, 0.01));
      expect(result.byCurrency['CHF'], closeTo(30, 0.01));
    });

    test('settlement is in base currency', () {
      final result = engine.compute(
        members: members,
        expenses: expenses,
        baseCurrency: 'EUR',
        exchangeRates: rates,
        converter: converter,
      );

      for (final d in result.deltas) {
        expect(d.currency, 'EUR');
      }
    });

    test('aggregator byCurrency tracks originals', () {
      final summary = aggregator.summarize(
        expenses: expenses,
        members: members,
        baseCurrency: 'EUR',
        exchangeRates: rates,
        converter: converter,
      );

      expect(summary.byCurrency['EUR'], closeTo(120, 0.01));
      expect(summary.byCurrency['GBP'], closeTo(45, 0.01));
      expect(summary.byCurrency['CHF'], closeTo(30, 0.01));
    });
  });
}
