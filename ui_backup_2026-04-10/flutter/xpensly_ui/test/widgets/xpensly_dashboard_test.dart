import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';
import 'package:xpensly_ui/xpensly_ui.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: XpenslyTheme(
      theme: XpenslyThemeData.material(),
      child: Scaffold(body: child),
    ),
  );
}

final testMembers = [
  const Member(id: 'u1', name: 'Alice'),
  const Member(id: 'u2', name: 'Bob'),
];

final testExpenses = [
  Expense(
    id: 'e1',
    title: 'Dinner',
    category: 'Food',
    amount: 60.0,
    currency: 'USD',
    paidBy: const [Payer(userId: 'u1', amount: 60.0)],
    splitAmong: const ['u1', 'u2'],
    mode: SplitMode.equal,
    date: DateTime(2026, 4, 1),
  ),
  Expense(
    id: 'e2',
    title: 'Taxi',
    category: 'Transport',
    amount: 20.0,
    currency: 'USD',
    paidBy: const [Payer(userId: 'u2', amount: 20.0)],
    splitAmong: const ['u1', 'u2'],
    mode: SplitMode.equal,
    date: DateTime(2026, 4, 1),
  ),
  Expense(
    id: 'e3',
    title: 'Museum',
    category: 'Activity',
    amount: 40.0,
    currency: 'USD',
    paidBy: const [Payer(userId: 'u1', amount: 40.0)],
    splitAmong: const ['u1', 'u2'],
    mode: SplitMode.equal,
    date: DateTime(2026, 4, 2),
  ),
];

/// A minimal in-memory data source for dashboard testing.
class _TestDataSource extends InMemoryDataSource {
  _TestDataSource() {
    // Pre-populate the data source synchronously via the parent's API.
    // InMemoryDataSource stores data in memory maps, so we seed it
    // by calling the async methods (which complete synchronously for
    // the in-memory implementation).
  }

  late String tripId;

  Future<void> seed() async {
    final trip = await createTrip(Trip(
      id: '',
      title: 'Test Trip',
      baseCurrency: 'USD',
      members: testMembers,
      categories: const ['Food', 'Transport', 'Activity'],
      settings: const TripSettings(),
    ));
    tripId = trip.id;
    for (final e in testExpenses) {
      await addExpense(tripId, e);
    }
  }
}

void main() {
  group('XpenslyDashboard', () {
    late _TestDataSource dataSource;
    late Xpensly xpensly;

    setUp(() async {
      dataSource = _TestDataSource();
      await dataSource.seed();
      xpensly = Xpensly(dataSource: dataSource);
    });

    testWidgets('renders tab bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        XpenslyDashboard(xpensly: xpensly, tripId: dataSource.tripId),
      ));
      // Wait for async data loading.
      await tester.pumpAndSettle();

      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Balances'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
    });

    testWidgets('switches between tabs', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        XpenslyDashboard(xpensly: xpensly, tripId: dataSource.tripId),
      ));
      await tester.pumpAndSettle();

      // Initially on Expenses tab — should show expense titles.
      expect(find.text('Dinner'), findsOneWidget);

      // Tap "Balances" tab.
      await tester.tap(find.text('Balances'));
      await tester.pumpAndSettle();

      // Should show Settlement header.
      expect(find.text('Settlement'), findsOneWidget);

      // Tap "Summary" tab.
      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      // Summary tab should render (no Expenses list visible).
      expect(find.text('Dinner'), findsNothing);
    });
  });
}
