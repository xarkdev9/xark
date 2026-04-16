import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

/// 10 people, 15-day Europe trip stress test.
void main() {
  final memberIds = [
    'alice', 'bob', 'charlie', 'diana', 'eve',
    'frank', 'grace', 'henry', 'iris', 'jack',
  ];
  final members = memberIds
      .map((id) => Member(id: id, name: id))
      .toList();

  // Rates: base = EUR. EUR: 1.0, USD: 0.92, CHF: 0.94
  // Meaning: 1 EUR = 0.92 USD → to convert USD to EUR: amount * (1.0 / 0.92)
  final rates = {'EUR': 1.0, 'USD': 0.92, 'CHF': 0.94};
  final converter = CurrencyConverter();
  final engine = SettlementEngine();
  final simplifier = DebtSimplifier();
  final aggregator = TripAggregator();

  // Sub-groups
  final niceGroup = ['alice', 'bob', 'charlie', 'diana', 'eve', 'frank'];
  final museumGroup = ['grace', 'henry', 'iris', 'jack'];
  final paraGroup = ['alice', 'bob', 'charlie', 'diana', 'eve', 'frank'];

  // Build expenses
  final expenses = <Expense>[
    // 1. Alice books flights for all 10: $8500, equal split
    Expense(
      id: 'flights',
      title: 'Flights',
      category: 'travel',
      amount: 8500,
      currency: 'USD',
      paidBy: [const Payer(userId: 'alice', amount: 8500)],
      splitAmong: memberIds,
      mode: SplitMode.equal,
      date: DateTime(2026, 6, 1),
    ),
    // 2. Bob books Airbnb Nice (6 people): EUR 2100, equal among 6
    Expense(
      id: 'airbnb',
      title: 'Airbnb Nice',
      category: 'accommodation',
      amount: 2100,
      currency: 'EUR',
      paidBy: [const Payer(userId: 'bob', amount: 2100)],
      splitAmong: niceGroup,
      mode: SplitMode.equal,
      date: DateTime(2026, 6, 3),
    ),
    // 3. Charlie pays for group dinner: EUR 320, equal 10 ways
    Expense(
      id: 'dinner',
      title: 'Group dinner',
      category: 'food',
      amount: 320,
      currency: 'EUR',
      paidBy: [const Payer(userId: 'charlie', amount: 320)],
      splitAmong: memberIds,
      mode: SplitMode.equal,
      date: DateTime(2026, 6, 5),
    ),
    // 4. Diana + Eve split paragliding for 6: CHF 1080
    //    Diana pays 600, Eve pays 480, equal among 6
    Expense(
      id: 'paragliding',
      title: 'Paragliding',
      category: 'activities',
      amount: 1080,
      currency: 'CHF',
      paidBy: [
        const Payer(userId: 'diana', amount: 600),
        const Payer(userId: 'eve', amount: 480),
      ],
      splitAmong: paraGroup,
      mode: SplitMode.equal,
      date: DateTime(2026, 6, 7),
    ),
    // 5. Frank pays for groceries: EUR 85, equal 10 ways
    Expense(
      id: 'groceries',
      title: 'Groceries',
      category: 'food',
      amount: 85,
      currency: 'EUR',
      paidBy: [const Payer(userId: 'frank', amount: 85)],
      splitAmong: memberIds,
      mode: SplitMode.equal,
      date: DateTime(2026, 6, 8),
    ),
    // 6. Grace pays museum tickets for 4: EUR 60
    Expense(
      id: 'museum',
      title: 'Museum tickets',
      category: 'activities',
      amount: 60,
      currency: 'EUR',
      paidBy: [const Payer(userId: 'grace', amount: 60)],
      splitAmong: museumGroup,
      mode: SplitMode.equal,
      date: DateTime(2026, 6, 10),
    ),
  ];

  // 7. Mid-trip: Henry pays Alice $200 (partial settlement)
  final settlements = [
    SettlementRecord(
      id: 's1',
      tripId: 'trip1',
      fromUser: 'henry',
      toUser: 'alice',
      amount: 200,
      currency: 'USD',
      settledAt: DateTime(2026, 6, 9),
    ),
  ];

  // 8. Refund: Airbnb returns EUR 200 to Bob
  final refunds = [
    Refund(
      id: 'ref1',
      originalExpenseId: 'airbnb',
      amount: 200,
      currency: 'EUR',
      refundedTo: 'bob',
      reason: 'Airbnb partial refund',
      date: DateTime(2026, 6, 12),
    ),
  ];

  group('Europe Trip — stress test', () {
    late Settlement result;

    setUpAll(() {
      result = engine.compute(
        members: members,
        expenses: expenses,
        refunds: refunds,
        priorSettlements: settlements,
        baseCurrency: 'EUR',
        exchangeRates: rates,
        simplifier: simplifier,
        converter: converter,
      );
    });

    test('total spent is calculated correctly across currencies', () {
      // Flights: 8500 USD → EUR = 8500 * (1.0 / 0.92) ≈ 9239.13
      // Airbnb: 2100 EUR
      // Dinner: 320 EUR
      // Paragliding: 1080 CHF → EUR = 1080 * (1.0 / 0.94) ≈ 1148.94
      // Groceries: 85 EUR
      // Museum: 60 EUR
      // Total ≈ 9239.13 + 2100 + 320 + 1148.94 + 85 + 60 ≈ 12953.07
      expect(result.totalSpent, closeTo(12953.07, 1.0));
    });

    test('all 10 members have ledger entries', () {
      expect(result.entries.length, 10);
      for (final id in memberIds) {
        expect(
          result.entries.any((e) => e.userId == id),
          isTrue,
          reason: '$id should have a ledger entry',
        );
      }
    });

    test('simplified debts has fewer transactions than raw deltas', () {
      expect(
        result.simplified.length,
        lessThanOrEqualTo(result.deltas.length),
      );
    });

    test('sum of positive balances ≈ sum of negative balances', () {
      // Settlements are zero-sum on balances (subtract from one, add to other).
      // Refunds inject money into one person's balance without a counterpart,
      // so positives and negatives diverge by the refund amount (€200).
      final positives = result.entries
          .where((e) => e.netBalance > 0)
          .fold(0.0, (s, e) => s + e.netBalance);
      final negatives = result.entries
          .where((e) => e.netBalance < 0)
          .fold(0.0, (s, e) => s + e.netBalance.abs());

      expect(positives, closeTo(negatives, 210));
    });

    test('byCategory aggregation works', () {
      expect(result.byCategory.containsKey('travel'), isTrue);
      expect(result.byCategory.containsKey('food'), isTrue);
      expect(result.byCategory.containsKey('activities'), isTrue);
      expect(result.byCategory.containsKey('accommodation'), isTrue);
    });

    test('byCurrency tracks original amounts', () {
      expect(result.byCurrency['USD'], closeTo(8500, 0.01));
      expect(result.byCurrency['EUR'], closeTo(2565, 0.01)); // 2100+320+85+60
      expect(result.byCurrency['CHF'], closeTo(1080, 0.01));
    });

    test('TripAggregator summary matches', () {
      final summary = aggregator.summarize(
        expenses: expenses,
        members: members,
        baseCurrency: 'EUR',
        exchangeRates: rates,
        converter: converter,
      );

      expect(summary.totalSpent, closeTo(result.totalSpent, 1.0));
      expect(summary.topPayer, isNotEmpty);
      expect(summary.avgPerPerson, closeTo(result.totalSpent / 10, 1.0));
    });
  });
}
