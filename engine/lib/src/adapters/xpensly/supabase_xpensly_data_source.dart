import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xpensly_core/xpensly_core.dart';

/// Supabase-backed implementation of [XpenslyDataSource].
///
/// This adapter lives inside the engine package (not xpensly_core) because
/// xpensly_core is a pure Dart SDK with zero Supabase coupling. Host apps
/// that use Supabase can use this adapter; others implement [XpenslyDataSource]
/// against their own database.
class SupabaseXpenslyDataSource implements XpenslyDataSource {
  final SupabaseClient client;

  SupabaseXpenslyDataSource({required this.client});

  // ---------------------------------------------------------------------------
  // Trip
  // ---------------------------------------------------------------------------
  @override
  Future<Trip> createTrip(Trip trip) async {
    await client.from('xp_trips').insert({
      'id': trip.id,
      'group_id': trip.groupId,
      'title': trip.title,
      'base_currency': trip.baseCurrency,
      'start_date': trip.startDate?.toIso8601String(),
      'end_date': trip.endDate?.toIso8601String(),
      'categories': trip.categories,
      'settings': {
        'simplifyDebts': trip.settings.simplifyDebts,
        'defaultSplitMode': trip.settings.defaultSplitMode.name,
        'baseCurrency': trip.settings.baseCurrency,
      },
    });

    if (trip.phases.isNotEmpty) {
      final phaseData = trip.phases
          .map((phase) => {
                'trip_id': trip.id,
                'name': phase.name,
                'start_date': phase.startDate.toIso8601String(),
                'end_date': phase.endDate.toIso8601String(),
              })
          .toList();
      await client.from('xp_trip_phases').insert(phaseData);
    }

    if (trip.members.isNotEmpty) {
      final membersData = trip.members
          .map((member) => {
                'trip_id': trip.id,
                'id': member.id,
                'name': member.name,
              })
          .toList();
      await client.from('xp_trip_members').insert(membersData);
    }

    return trip;
  }

  @override
  Future<Trip?> getTrip(String tripId) async {
    final Map<String, dynamic>? data = await client
        .from('xp_trips')
        .select()
        .eq('id', tripId)
        .maybeSingle();

    if (data == null) return null;

    final phasesData =
        await client.from('xp_trip_phases').select().eq('trip_id', tripId);

    final membersData =
        await client.from('xp_trip_members').select().eq('trip_id', tripId);

    final phases = phasesData
        .map((p) => TripPhase(
              name: p['name'] as String,
              startDate: DateTime.parse(p['start_date'] as String),
              endDate: DateTime.parse(p['end_date'] as String),
            ))
        .toList();

    final members = membersData
        .map((m) => Member(
              id: m['id'] as String,
              name: m['name'] as String,
            ))
        .toList();

    final settingsData = data['settings'] as Map<String, dynamic>? ?? {};
    final settings = TripSettings(
      simplifyDebts: settingsData['simplifyDebts'] as bool? ?? true,
      defaultSplitMode: SplitMode.values.firstWhere(
        (e) => e.name == settingsData['defaultSplitMode'],
        orElse: () => SplitMode.equal,
      ),
      baseCurrency: settingsData['baseCurrency'] as String? ?? 'USD',
    );

    return Trip(
      id: data['id'] as String,
      groupId: data['group_id'] as String?,
      title: data['title'] as String,
      baseCurrency: data['base_currency'] as String,
      startDate: data['start_date'] != null
          ? DateTime.parse(data['start_date'] as String)
          : null,
      endDate: data['end_date'] != null
          ? DateTime.parse(data['end_date'] as String)
          : null,
      phases: phases,
      categories: List<String>.from(data['categories'] as Iterable? ?? []),
      members: members,
      settings: settings,
    );
  }

  @override
  Future<Trip> updateTrip(String tripId, Trip trip) async {
    await client
        .from('xp_trips')
        .update({
          'group_id': trip.groupId,
          'title': trip.title,
          'base_currency': trip.baseCurrency,
          'start_date': trip.startDate?.toIso8601String(),
          'end_date': trip.endDate?.toIso8601String(),
          'categories': trip.categories,
          'settings': {
            'simplifyDebts': trip.settings.simplifyDebts,
            'defaultSplitMode': trip.settings.defaultSplitMode.name,
            'baseCurrency': trip.settings.baseCurrency,
          },
        })
        .eq('id', tripId);

    await client.from('xp_trip_phases').delete().eq('trip_id', tripId);
    if (trip.phases.isNotEmpty) {
      final phaseData = trip.phases
          .map((phase) => {
                'trip_id': trip.id,
                'name': phase.name,
                'start_date': phase.startDate.toIso8601String(),
                'end_date': phase.endDate.toIso8601String(),
              })
          .toList();
      await client.from('xp_trip_phases').insert(phaseData);
    }

    await client.from('xp_trip_members').delete().eq('trip_id', tripId);
    if (trip.members.isNotEmpty) {
      final membersData = trip.members
          .map((member) => {
                'trip_id': trip.id,
                'id': member.id,
                'name': member.name,
              })
          .toList();
      await client.from('xp_trip_members').insert(membersData);
    }

    return trip;
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    await client.from('xp_trips').delete().eq('id', tripId);
  }

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------
  @override
  Future<List<Member>> fetchMembers(String tripId) async {
    final data =
        await client.from('xp_trip_members').select().eq('trip_id', tripId);
    return data
        .map((m) =>
            Member(id: m['id'] as String, name: m['name'] as String))
        .toList();
  }

  @override
  Future<void> addMember(String tripId, Member member) async {
    await client.from('xp_trip_members').insert({
      'trip_id': tripId,
      'id': member.id,
      'name': member.name,
    });
  }

  @override
  Future<void> removeMember(String tripId, String userId) async {
    await client
        .from('xp_trip_members')
        .delete()
        .eq('trip_id', tripId)
        .eq('id', userId);
  }

  // ---------------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------------
  @override
  Future<List<Expense>> fetchExpenses(
    String tripId, {
    ExpenseFilter? filter,
  }) async {
    final expensesData =
        await client.from('xp_expenses').select().eq('trip_id', tripId);

    final List<Expense> expenses = [];
    for (final data in expensesData) {
      final expenseId = data['id'] as String;

      final payersData = await client
          .from('xp_expense_payers')
          .select()
          .eq('expense_id', expenseId);
      final splitsData = await client
          .from('xp_expense_splits')
          .select()
          .eq('expense_id', expenseId);

      final paidBy = payersData
          .map((p) => Payer(
                userId: p['user_id'] as String,
                amount: double.parse(p['amount'].toString()),
              ))
          .toList();

      final splitAmong =
          splitsData.map((s) => s['user_id'] as String).toList();
      final Map<String, double> splitDetails = {};
      for (final s in splitsData) {
        splitDetails[s['user_id'] as String] =
            double.parse(s['amount'].toString());
      }

      final recurringData = data['recurring'] as Map<String, dynamic>?;
      Recurrence? recurring;
      if (recurringData != null) {
        recurring = Recurrence(
          frequency: recurringData['frequency'] as String,
          until: DateTime.parse(recurringData['until'] as String),
        );
      }

      expenses.add(Expense(
        id: expenseId,
        title: data['title'] as String,
        category: data['category'] as String,
        amount: double.parse(data['amount'].toString()),
        currency: data['currency'] as String,
        paidBy: paidBy,
        splitAmong: splitAmong,
        mode: SplitMode.values.firstWhere(
          (e) => e.name == data['mode'],
          orElse: () => SplitMode.equal,
        ),
        splitDetails: splitDetails.isNotEmpty ? splitDetails : null,
        date: DateTime.parse(data['date'] as String),
        phase: data['phase'] as String?,
        notes: data['notes'] as String?,
        receiptUrl: data['receipt_url'] as String?,
        recurring: recurring,
        tags: List<String>.from(data['tags'] as Iterable? ?? []),
      ));
    }

    if (filter != null) {
      return expenses.where((e) {
        if (filter.category != null && e.category != filter.category) {
          return false;
        }
        if (filter.phase != null && e.phase != filter.phase) return false;
        if (filter.paidBy != null &&
            !e.paidBy.any((p) => p.userId == filter.paidBy)) {
          return false;
        }
        if (filter.from != null && e.date.isBefore(filter.from!)) {
          return false;
        }
        if (filter.to != null && e.date.isAfter(filter.to!)) return false;
        if (filter.tags != null &&
            filter.tags!.isNotEmpty &&
            !e.tags.any((t) => filter.tags!.contains(t))) {
          return false;
        }
        return true;
      }).toList();
    }
    return expenses;
  }

  @override
  Future<Expense> addExpense(String tripId, Expense expense) async {
    await client.from('xp_expenses').insert({
      'id': expense.id,
      'trip_id': tripId,
      'title': expense.title,
      'category': expense.category,
      'amount': expense.amount,
      'currency': expense.currency,
      'mode': expense.mode.name,
      'date': expense.date.toIso8601String(),
      'phase': expense.phase,
      'notes': expense.notes,
      'receipt_url': expense.receiptUrl,
      'recurring': expense.recurring != null
          ? {
              'frequency': expense.recurring!.frequency,
              'until': expense.recurring!.until.toIso8601String(),
            }
          : null,
      'tags': expense.tags,
    });

    if (expense.paidBy.isNotEmpty) {
      final payersData = expense.paidBy
          .map((payer) => {
                'expense_id': expense.id,
                'user_id': payer.userId,
                'amount': payer.amount,
              })
          .toList();
      await client.from('xp_expense_payers').insert(payersData);
    }

    if (expense.splitDetails != null) {
      final splitsData = expense.splitDetails!.entries
          .map((entry) => {
                'expense_id': expense.id,
                'user_id': entry.key,
                'amount': entry.value,
              })
          .toList();
      await client.from('xp_expense_splits').insert(splitsData);
    } else {
      final splitsData = expense.splitAmong
          .map((userId) => {
                'expense_id': expense.id,
                'user_id': userId,
                'amount': 0,
              })
          .toList();
      if (splitsData.isNotEmpty) {
        await client.from('xp_expense_splits').insert(splitsData);
      }
    }

    return expense;
  }

  @override
  Future<Expense> updateExpense(
    String tripId,
    String expenseId,
    Expense expense,
  ) async {
    await client
        .from('xp_expenses')
        .update({
          'title': expense.title,
          'category': expense.category,
          'amount': expense.amount,
          'currency': expense.currency,
          'mode': expense.mode.name,
          'date': expense.date.toIso8601String(),
          'phase': expense.phase,
          'notes': expense.notes,
          'receipt_url': expense.receiptUrl,
          'recurring': expense.recurring != null
              ? {
                  'frequency': expense.recurring!.frequency,
                  'until': expense.recurring!.until.toIso8601String(),
                }
              : null,
          'tags': expense.tags,
        })
        .eq('id', expenseId);

    await client
        .from('xp_expense_payers')
        .delete()
        .eq('expense_id', expenseId);
    if (expense.paidBy.isNotEmpty) {
      final payersData = expense.paidBy
          .map((payer) => {
                'expense_id': expenseId,
                'user_id': payer.userId,
                'amount': payer.amount,
              })
          .toList();
      await client.from('xp_expense_payers').insert(payersData);
    }

    await client
        .from('xp_expense_splits')
        .delete()
        .eq('expense_id', expenseId);
    if (expense.splitDetails != null) {
      final splitsData = expense.splitDetails!.entries
          .map((entry) => {
                'expense_id': expenseId,
                'user_id': entry.key,
                'amount': entry.value,
              })
          .toList();
      await client.from('xp_expense_splits').insert(splitsData);
    } else {
      final splitsData = expense.splitAmong
          .map((userId) => {
                'expense_id': expenseId,
                'user_id': userId,
                'amount': 0,
              })
          .toList();
      if (splitsData.isNotEmpty) {
        await client.from('xp_expense_splits').insert(splitsData);
      }
    }

    return expense;
  }

  @override
  Future<void> deleteExpense(String tripId, String expenseId) async {
    await client.from('xp_expenses').delete().eq('id', expenseId);
  }

  // ---------------------------------------------------------------------------
  // Settlements
  // ---------------------------------------------------------------------------
  @override
  Future<List<SettlementRecord>> fetchSettlements(String tripId) async {
    final data =
        await client.from('xp_settlements').select().eq('trip_id', tripId);
    return data
        .map((d) => SettlementRecord(
              id: d['id'] as String,
              tripId: tripId,
              fromUser: d['from_user_id'] as String,
              toUser: d['to_user_id'] as String,
              amount: double.parse(d['amount'].toString()),
              currency: d['currency'] as String,
              settledAt: DateTime.parse(d['date'] as String),
            ))
        .toList();
  }

  @override
  Future<SettlementRecord> recordSettlement(
    String tripId,
    SettlementRecord record,
  ) async {
    await client.from('xp_settlements').insert({
      'id': record.id,
      'trip_id': tripId,
      'from_user_id': record.fromUser,
      'to_user_id': record.toUser,
      'amount': record.amount,
      'currency': record.currency,
      'date': record.settledAt.toIso8601String(),
      'status': 'completed',
    });
    return record;
  }

  // ---------------------------------------------------------------------------
  // Refunds
  // ---------------------------------------------------------------------------
  @override
  Future<List<Refund>> fetchRefunds(String tripId) async {
    final data =
        await client.from('xp_refunds').select().eq('trip_id', tripId);
    return data
        .map((d) => Refund(
              id: d['id'] as String,
              originalExpenseId: d['expense_id'] as String,
              refundedTo: d['user_id'] as String,
              amount: double.parse(d['amount'].toString()),
              currency: 'USD',
              reason: 'Refund',
              date: DateTime.parse(d['date'] as String),
            ))
        .toList();
  }

  @override
  Future<Refund> addRefund(String tripId, Refund refund) async {
    await client.from('xp_refunds').insert({
      'id': refund.id,
      'trip_id': tripId,
      'expense_id': refund.originalExpenseId ?? '',
      'user_id': refund.refundedTo,
      'amount': refund.amount,
      'date': refund.date.toIso8601String(),
    });
    return refund;
  }
}
