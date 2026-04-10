import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';
import 'package:xpensly_ui/xpensly_ui.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: XpenslyTheme(
      theme: XpenslyThemeData.material(),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

final testSettlement = Settlement(
  entries: [
    const LedgerEntry(
      userId: 'u1',
      name: 'Alice',
      totalPaid: 100.0,
      totalOwes: 50.0,
      netBalance: 50.0,
      items: [ExpenseItem(title: 'Dinner', amount: 100.0)],
    ),
    const LedgerEntry(
      userId: 'u2',
      name: 'Bob',
      totalPaid: 0.0,
      totalOwes: 50.0,
      netBalance: -50.0,
      items: [],
    ),
  ],
  deltas: const [
    DebtDelta(from: 'Bob', to: 'Alice', amount: 50.0, currency: 'USD'),
  ],
  simplified: const [
    DebtDelta(from: 'Bob', to: 'Alice', amount: 50.0, currency: 'USD'),
  ],
  totalSpent: 100.0,
  perPerson: 50.0,
  byCurrency: const {'USD': 100.0},
  byCategory: const {'Food': 100.0},
  memberCount: 2,
);

void main() {
  group('SettlementCard', () {
    testWidgets('renders ledger entries', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        SettlementCard(settlement: testSettlement, currency: 'USD'),
      ));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('\$100.00'), findsWidgets);
      expect(find.textContaining('\$50.00'), findsWidgets);
    });

    testWidgets('renders debt deltas', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        SettlementCard(
          settlement: testSettlement,
          currency: 'USD',
          simplifyToggle: false,
        ),
      ));

      expect(find.textContaining('Bob'), findsWidgets);
      expect(find.textContaining('Alice'), findsWidgets);
    });

    testWidgets('simplify toggle switches between modes', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        SettlementCard(settlement: testSettlement, currency: 'USD'),
      ));

      expect(find.text('Simplified'), findsOneWidget);

      await tester.tap(find.text('Simplify debts'));
      await tester.pump();

      expect(find.text('All debts'), findsOneWidget);
    });
  });
}
