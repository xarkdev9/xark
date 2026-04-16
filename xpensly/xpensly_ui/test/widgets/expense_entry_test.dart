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

final testMembers = [
  const Member(id: 'u1', name: 'Alice'),
  const Member(id: 'u2', name: 'Bob'),
  const Member(id: 'u3', name: 'Carol'),
  const Member(id: 'u4', name: 'Dave'),
];

void main() {
  group('ExpenseEntry', () {
    testWidgets('renders title and amount fields', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        ExpenseEntry(
          members: testMembers,
          onSubmit: (_) {},
        ),
      ));

      // Title field with hint text.
      expect(find.text('What was it for?'), findsOneWidget);
      // Amount field with hint text.
      expect(find.text('Amount'), findsOneWidget);
      // "Add expense" header and submit button.
      expect(find.text('Add expense'), findsNWidgets(2));
      // Member names rendered as chips.
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
    });

    testWidgets('submit creates Expense with correct values',
        (tester) async {
      Expense? submittedExpense;

      await tester.pumpWidget(buildTestWidget(
        ExpenseEntry(
          members: testMembers,
          onSubmit: (expense) => submittedExpense = expense,
        ),
      ));

      // Enter title.
      await tester.enterText(
        find.widgetWithText(TextField, 'What was it for?'),
        'Dinner',
      );

      // Enter amount.
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '80.00',
      );

      // Select a payer (tap "Alice" in the "Paid by" section).
      // The member chips appear twice: once for "Paid by", once for "Split among".
      // "Paid by" chips come first. We tap the first "Alice" chip.
      final aliceChips = find.text('Alice');
      await tester.tap(aliceChips.first);
      await tester.pump();

      // Tap the "Add expense" submit button (second instance).
      final addButtons = find.text('Add expense');
      await tester.tap(addButtons.last);
      await tester.pump();

      expect(submittedExpense, isNotNull);
      expect(submittedExpense!.title, 'Dinner');
      expect(submittedExpense!.amount, 80.0);
      expect(submittedExpense!.currency, 'USD');
      expect(submittedExpense!.paidBy.length, 1);
      expect(submittedExpense!.paidBy.first.userId, 'u1');
      expect(submittedExpense!.splitAmong.length, 4);
    });
  });
}
