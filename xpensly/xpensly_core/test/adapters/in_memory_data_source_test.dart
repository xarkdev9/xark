import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

Trip _trip() => Trip(
      id: '',
      title: 'Test Trip',
      baseCurrency: 'USD',
      members: [const Member(id: 'A', name: 'Alice')],
      settings: const TripSettings(),
    );

Expense _expense({String category = 'food', DateTime? date}) => Expense(
      id: '',
      title: 'Test Expense',
      category: category,
      amount: 50,
      currency: 'USD',
      paidBy: [const Payer(userId: 'A', amount: 50)],
      splitAmong: ['A', 'B'],
      mode: SplitMode.equal,
      date: date ?? DateTime(2026, 1, 15),
    );

void main() {
  late InMemoryDataSource ds;
  late String tripId;

  setUp(() async {
    ds = InMemoryDataSource();
    final trip = await ds.createTrip(_trip());
    tripId = trip.id;
  });

  group('InMemoryDataSource — Trip CRUD', () {
    test('create and get trip', () async {
      final trip = await ds.getTrip(tripId);
      expect(trip, isNotNull);
      expect(trip!.title, 'Test Trip');
    });

    test('update trip', () async {
      final updated = await ds.updateTrip(
        tripId,
        Trip(
          id: tripId,
          title: 'Updated Trip',
          baseCurrency: 'EUR',
          members: [],
          settings: const TripSettings(),
        ),
      );
      expect(updated.title, 'Updated Trip');

      final fetched = await ds.getTrip(tripId);
      expect(fetched!.title, 'Updated Trip');
    });

    test('delete trip', () async {
      await ds.deleteTrip(tripId);
      final trip = await ds.getTrip(tripId);
      expect(trip, isNull);
    });
  });

  group('InMemoryDataSource — Expense CRUD', () {
    test('add and list expenses', () async {
      await ds.addExpense(tripId, _expense());
      await ds.addExpense(tripId, _expense(category: 'transport'));

      final expenses = await ds.fetchExpenses(tripId);
      expect(expenses.length, 2);
    });

    test('update expense', () async {
      final created = await ds.addExpense(tripId, _expense());
      final updated = await ds.updateExpense(
        tripId,
        created.id,
        Expense(
          id: created.id,
          title: 'Updated Expense',
          category: 'drinks',
          amount: 75,
          currency: 'USD',
          paidBy: [const Payer(userId: 'A', amount: 75)],
          splitAmong: ['A', 'B'],
          mode: SplitMode.equal,
          date: DateTime(2026, 1, 15),
        ),
      );
      expect(updated.title, 'Updated Expense');
      expect(updated.amount, 75);
    });

    test('delete expense', () async {
      final created = await ds.addExpense(tripId, _expense());
      await ds.deleteExpense(tripId, created.id);

      final expenses = await ds.fetchExpenses(tripId);
      expect(expenses, isEmpty);
    });
  });

  group('InMemoryDataSource — Expense filtering', () {
    test('filter by category', () async {
      await ds.addExpense(tripId, _expense(category: 'food'));
      await ds.addExpense(tripId, _expense(category: 'transport'));
      await ds.addExpense(tripId, _expense(category: 'food'));

      final food = await ds.fetchExpenses(
        tripId,
        filter: const ExpenseFilter(category: 'food'),
      );
      expect(food.length, 2);
    });

    test('filter by date range', () async {
      await ds.addExpense(tripId, _expense(date: DateTime(2026, 1, 5)));
      await ds.addExpense(tripId, _expense(date: DateTime(2026, 1, 15)));
      await ds.addExpense(tripId, _expense(date: DateTime(2026, 1, 25)));

      final filtered = await ds.fetchExpenses(
        tripId,
        filter: ExpenseFilter(
          from: DateTime(2026, 1, 10),
          to: DateTime(2026, 1, 20),
        ),
      );
      expect(filtered.length, 1);
    });
  });

  group('InMemoryDataSource — Members', () {
    test('add, list, remove', () async {
      await ds.addMember(tripId, const Member(id: 'B', name: 'Bob'));
      var members = await ds.fetchMembers(tripId);
      // Initial member (Alice) + Bob
      expect(members.length, 2);

      await ds.removeMember(tripId, 'B');
      members = await ds.fetchMembers(tripId);
      expect(members.length, 1);
      expect(members.first.id, 'A');
    });
  });

  group('InMemoryDataSource — Settlements', () {
    test('record and list settlements', () async {
      await ds.recordSettlement(
        tripId,
        SettlementRecord(
          id: '',
          tripId: tripId,
          fromUser: 'B',
          toUser: 'A',
          amount: 25,
          currency: 'USD',
          settledAt: DateTime(2026, 1, 20),
        ),
      );

      final settlements = await ds.fetchSettlements(tripId);
      expect(settlements.length, 1);
      expect(settlements.first.fromUser, 'B');
      expect(settlements.first.amount, 25);
    });
  });

  group('InMemoryDataSource — Refunds', () {
    test('add and list refunds', () async {
      await ds.addRefund(
        tripId,
        Refund(
          id: '',
          amount: 10,
          currency: 'USD',
          refundedTo: 'A',
          reason: 'overcharge',
          date: DateTime(2026, 1, 20),
        ),
      );

      final refunds = await ds.fetchRefunds(tripId);
      expect(refunds.length, 1);
      expect(refunds.first.refundedTo, 'A');
      expect(refunds.first.amount, 10);
    });
  });
}
