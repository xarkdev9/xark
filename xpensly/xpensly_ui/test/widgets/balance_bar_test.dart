import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xpensly_ui/xpensly_ui.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: XpenslyTheme(
      theme: XpenslyThemeData.material(),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('BalanceBar', () {
    testWidgets('renders positive balance in green with "owed" text',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const BalanceBar(
          userId: 'u1',
          name: 'Alice',
          netBalance: 50.0,
          currency: 'USD',
          maxBalance: 100.0,
        ),
      ));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining('owed'), findsOneWidget);
      expect(find.textContaining('\$50.00'), findsOneWidget);
    });

    testWidgets('renders negative balance in orange with "owes" text',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const BalanceBar(
          userId: 'u2',
          name: 'Bob',
          netBalance: -30.0,
          currency: 'USD',
          maxBalance: 100.0,
        ),
      ));

      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('owes'), findsOneWidget);
      expect(find.textContaining('\$30.00'), findsOneWidget);
    });

    testWidgets('renders zero balance as neutral', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const BalanceBar(
          userId: 'u3',
          name: 'Carol',
          netBalance: 0.0,
          currency: 'USD',
          maxBalance: 100.0,
        ),
      ));

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('settled'), findsOneWidget);
    });
  });
}
