import '../models/expense.dart';
import '../models/expense_filter.dart';
import '../models/member.dart';
import '../models/refund.dart';
import '../models/settlement_record.dart';
import '../models/trip.dart';
import '../ports/data_source.dart';

/// A fully in-memory implementation of [XpenslyDataSource].
///
/// Useful for unit tests, prototyping, and local-first scenarios where
/// persistence is not required. All data lives in plain [Map]s and is lost
/// when the instance is garbage-collected.
///
/// IDs are generated using a simple auto-incrementing counter with a `mem_`
/// prefix (e.g., `mem_1`, `mem_2`).
class InMemoryDataSource implements XpenslyDataSource {
  int _nextId = 1;

  final Map<String, Trip> _trips = {};
  final Map<String, List<Member>> _members = {};
  final Map<String, List<Expense>> _expenses = {};
  final Map<String, List<SettlementRecord>> _settlements = {};
  final Map<String, List<Refund>> _refunds = {};

  /// Generates the next unique in-memory ID.
  String _genId() => 'mem_${_nextId++}';

  // ---------------------------------------------------------------------------
  // Trip
  // ---------------------------------------------------------------------------

  @override
  Future<Trip> createTrip(Trip trip) {
    final id = _genId();
    final created = Trip(
      id: id,
      groupId: trip.groupId,
      title: trip.title,
      baseCurrency: trip.baseCurrency,
      startDate: trip.startDate,
      endDate: trip.endDate,
      phases: trip.phases,
      categories: trip.categories,
      members: trip.members,
      settings: trip.settings,
    );
    _trips[id] = created;
    _members[id] = List<Member>.from(trip.members);
    _expenses[id] = [];
    _settlements[id] = [];
    _refunds[id] = [];
    return Future.value(created);
  }

  @override
  Future<Trip?> getTrip(String tripId) {
    return Future.value(_trips[tripId]);
  }

  @override
  Future<Trip> updateTrip(String tripId, Trip trip) {
    final updated = Trip(
      id: tripId,
      groupId: trip.groupId,
      title: trip.title,
      baseCurrency: trip.baseCurrency,
      startDate: trip.startDate,
      endDate: trip.endDate,
      phases: trip.phases,
      categories: trip.categories,
      members: trip.members,
      settings: trip.settings,
    );
    _trips[tripId] = updated;
    return Future.value(updated);
  }

  @override
  Future<void> deleteTrip(String tripId) {
    _trips.remove(tripId);
    _members.remove(tripId);
    _expenses.remove(tripId);
    _settlements.remove(tripId);
    _refunds.remove(tripId);
    return Future.value();
  }

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------

  @override
  Future<List<Member>> fetchMembers(String tripId) {
    return Future.value(List<Member>.unmodifiable(_members[tripId] ?? []));
  }

  @override
  Future<void> addMember(String tripId, Member member) {
    _members.putIfAbsent(tripId, () => []);
    _members[tripId]!.add(member);
    return Future.value();
  }

  @override
  Future<void> removeMember(String tripId, String userId) {
    _members[tripId]?.removeWhere((m) => m.id == userId);
    return Future.value();
  }

  // ---------------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------------

  @override
  Future<List<Expense>> fetchExpenses(
    String tripId, {
    ExpenseFilter? filter,
  }) {
    var results = List<Expense>.from(_expenses[tripId] ?? []);

    if (filter != null && !filter.isEmpty) {
      results = results.where((e) {
        if (filter.category != null && e.category != filter.category) {
          return false;
        }
        if (filter.phase != null && e.phase != filter.phase) {
          return false;
        }
        if (filter.paidBy != null &&
            !e.paidBy.any((p) => p.userId == filter.paidBy)) {
          return false;
        }
        if (filter.from != null && e.date.isBefore(filter.from!)) {
          return false;
        }
        if (filter.to != null && e.date.isAfter(filter.to!)) {
          return false;
        }
        if (filter.tags != null && filter.tags!.isNotEmpty) {
          if (!filter.tags!.any((t) => e.tags.contains(t))) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    return Future.value(results);
  }

  @override
  Future<Expense> addExpense(String tripId, Expense expense) {
    final id = _genId();
    final created = Expense(
      id: id,
      title: expense.title,
      category: expense.category,
      amount: expense.amount,
      currency: expense.currency,
      paidBy: expense.paidBy,
      splitAmong: expense.splitAmong,
      mode: expense.mode,
      splitDetails: expense.splitDetails,
      date: expense.date,
      phase: expense.phase,
      notes: expense.notes,
      receiptUrl: expense.receiptUrl,
      recurring: expense.recurring,
      tags: expense.tags,
    );
    _expenses.putIfAbsent(tripId, () => []);
    _expenses[tripId]!.add(created);
    return Future.value(created);
  }

  @override
  Future<Expense> updateExpense(
    String tripId,
    String expenseId,
    Expense expense,
  ) {
    final list = _expenses[tripId];
    if (list == null) {
      throw StateError('Trip $tripId not found');
    }
    final index = list.indexWhere((e) => e.id == expenseId);
    if (index == -1) {
      throw StateError('Expense $expenseId not found in trip $tripId');
    }
    final updated = Expense(
      id: expenseId,
      title: expense.title,
      category: expense.category,
      amount: expense.amount,
      currency: expense.currency,
      paidBy: expense.paidBy,
      splitAmong: expense.splitAmong,
      mode: expense.mode,
      splitDetails: expense.splitDetails,
      date: expense.date,
      phase: expense.phase,
      notes: expense.notes,
      receiptUrl: expense.receiptUrl,
      recurring: expense.recurring,
      tags: expense.tags,
    );
    list[index] = updated;
    return Future.value(updated);
  }

  @override
  Future<void> deleteExpense(String tripId, String expenseId) {
    _expenses[tripId]?.removeWhere((e) => e.id == expenseId);
    return Future.value();
  }

  // ---------------------------------------------------------------------------
  // Settlements
  // ---------------------------------------------------------------------------

  @override
  Future<List<SettlementRecord>> fetchSettlements(String tripId) {
    return Future.value(
      List<SettlementRecord>.unmodifiable(_settlements[tripId] ?? []),
    );
  }

  @override
  Future<SettlementRecord> recordSettlement(
    String tripId,
    SettlementRecord record,
  ) {
    final id = _genId();
    final created = SettlementRecord(
      id: id,
      tripId: tripId,
      fromUser: record.fromUser,
      toUser: record.toUser,
      amount: record.amount,
      currency: record.currency,
      provider: record.provider,
      proof: record.proof,
      note: record.note,
      settledAt: record.settledAt,
    );
    _settlements.putIfAbsent(tripId, () => []);
    _settlements[tripId]!.add(created);
    return Future.value(created);
  }

  // ---------------------------------------------------------------------------
  // Refunds
  // ---------------------------------------------------------------------------

  @override
  Future<List<Refund>> fetchRefunds(String tripId) {
    return Future.value(List<Refund>.unmodifiable(_refunds[tripId] ?? []));
  }

  @override
  Future<Refund> addRefund(String tripId, Refund refund) {
    final id = _genId();
    final created = Refund(
      id: id,
      originalExpenseId: refund.originalExpenseId,
      amount: refund.amount,
      currency: refund.currency,
      refundedTo: refund.refundedTo,
      reason: refund.reason,
      date: refund.date,
    );
    _refunds.putIfAbsent(tripId, () => []);
    _refunds[tripId]!.add(created);
    return Future.value(created);
  }
}
