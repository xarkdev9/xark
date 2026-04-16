import '../models/expense.dart';
import '../models/expense_filter.dart';
import '../models/member.dart';
import '../models/refund.dart';
import '../models/settlement_record.dart';
import '../models/trip.dart';

/// Abstract interface for all Xpensly data access operations.
///
/// Implementations may be backed by an in-memory store (for testing),
/// a local database, or a remote API. All operations are asynchronous
/// to support both synchronous and network-backed implementations.
abstract class XpenslyDataSource {
  // ---------------------------------------------------------------------------
  // Trip
  // ---------------------------------------------------------------------------

  /// Creates a new trip and returns it with a server-assigned ID.
  Future<Trip> createTrip(Trip trip);

  /// Retrieves a trip by its unique identifier, or `null` if not found.
  Future<Trip?> getTrip(String tripId);

  /// Replaces a trip's data and returns the updated trip.
  Future<Trip> updateTrip(String tripId, Trip trip);

  /// Permanently deletes a trip and all associated data.
  Future<void> deleteTrip(String tripId);

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------

  /// Returns all members belonging to the given trip.
  Future<List<Member>> fetchMembers(String tripId);

  /// Adds a member to the trip.
  Future<void> addMember(String tripId, Member member);

  /// Removes a member from the trip by user ID.
  Future<void> removeMember(String tripId, String userId);

  // ---------------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------------

  /// Returns expenses for a trip, optionally narrowed by [filter].
  Future<List<Expense>> fetchExpenses(String tripId, {ExpenseFilter? filter});

  /// Adds an expense to the trip and returns it with a server-assigned ID.
  Future<Expense> addExpense(String tripId, Expense expense);

  /// Replaces an expense's data and returns the updated expense.
  Future<Expense> updateExpense(
    String tripId,
    String expenseId,
    Expense expense,
  );

  /// Permanently deletes an expense from the trip.
  Future<void> deleteExpense(String tripId, String expenseId);

  // ---------------------------------------------------------------------------
  // Settlements
  // ---------------------------------------------------------------------------

  /// Returns all settlement records for the trip.
  Future<List<SettlementRecord>> fetchSettlements(String tripId);

  /// Records a new settlement and returns it with a server-assigned ID.
  Future<SettlementRecord> recordSettlement(
    String tripId,
    SettlementRecord record,
  );

  // ---------------------------------------------------------------------------
  // Refunds
  // ---------------------------------------------------------------------------

  /// Returns all refunds for the trip.
  Future<List<Refund>> fetchRefunds(String tripId);

  /// Adds a refund to the trip and returns it with a server-assigned ID.
  Future<Refund> addRefund(String tripId, Refund refund);
}
