import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';
import 'expense_entry.dart';
import 'expense_list.dart';
import 'settlement_card.dart';
import 'trip_summary_widget.dart';

/// Tab identifiers for the dashboard.
enum DashboardTab { expenses, balances, summary }

/// Full-page dashboard with tab navigation for expenses, balances, and summary.
///
/// Loads data from [xpensly.dataSource] on init and provides tabs for:
/// - Expenses: [ExpenseList] with a FAB for [ExpenseEntry]
/// - Balances: [SettlementCard]
/// - Summary: [TripSummaryWidget]
class XpenslyDashboard extends StatefulWidget {
  final Xpensly xpensly;
  final String tripId;
  final List<DashboardTab> tabs;

  /// Optional custom builder for the settlement view.
  final Widget Function(BuildContext, Settlement)? settlementBuilder;

  /// Optional custom builder for the trip summary view.
  final Widget Function(BuildContext, TripSummary)? summaryBuilder;

  /// Optional callback when an expense row is tapped.
  final void Function(Expense)? onExpenseTap;

  const XpenslyDashboard({
    super.key,
    required this.xpensly,
    required this.tripId,
    this.tabs = const [
      DashboardTab.expenses,
      DashboardTab.balances,
      DashboardTab.summary,
    ],
    this.settlementBuilder,
    this.summaryBuilder,
    this.onExpenseTap,
  });

  @override
  State<XpenslyDashboard> createState() => _XpenslyDashboardState();
}

class _XpenslyDashboardState extends State<XpenslyDashboard> {
  int _tabIndex = 0;
  bool _loading = true;
  String? _error;

  List<Expense> _expenses = [];
  List<Member> _members = [];
  Settlement? _settlement;
  TripSummary? _summary;
  Trip? _trip;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ds = widget.xpensly.dataSource;
      final results = await Future.wait([
        ds.fetchExpenses(widget.tripId),
        ds.fetchMembers(widget.tripId),
        ds.getTrip(widget.tripId),
        widget.xpensly.computeTripSettlement(widget.tripId),
        widget.xpensly.computeTripSummary(widget.tripId),
      ]);

      if (!mounted) return;

      setState(() {
        _expenses = results[0] as List<Expense>;
        _members = results[1] as List<Member>;
        _trip = results[2] as Trip?;
        _settlement = results[3] as Settlement;
        _summary = results[4] as TripSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showExpenseEntry() {
    final theme = XpenslyTheme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: theme.cardRadius),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ExpenseEntry(
          members: _members,
          categories: _trip?.categories ?? [],
          currencies: [_trip?.baseCurrency ?? widget.xpensly.config.baseCurrency],
          defaultMode: _trip?.settings.defaultSplitMode ??
              widget.xpensly.config.defaultSplitMode,
          onSubmit: (expense) async {
            Navigator.of(ctx).pop();
            await widget.xpensly.dataSource
                .addExpense(widget.tripId, expense);
            _loadData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load data',
              style: theme.bodyStyle.copyWith(color: theme.negative),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _loadData,
              child: Text(
                'Retry',
                style: theme.bodyStyle.copyWith(color: theme.primary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tab bar
        _TabBar(
          tabs: widget.tabs,
          selected: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
        ),

        // Tab content
        Expanded(
          child: _buildTab(widget.tabs[_tabIndex]),
        ),
      ],
    );
  }

  Widget _buildTab(DashboardTab tab) {
    final currency =
        _trip?.baseCurrency ?? widget.xpensly.config.baseCurrency;

    switch (tab) {
      case DashboardTab.expenses:
        return Stack(
          children: [
            ExpenseList(
              expenses: _expenses,
              onTap: widget.onExpenseTap,
              onDelete: (expense) async {
                await widget.xpensly.dataSource
                    .deleteExpense(widget.tripId, expense.id);
                _loadData();
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: _Fab(onTap: _showExpenseEntry),
            ),
          ],
        );
      case DashboardTab.balances:
        if (_settlement == null) {
          return const Center(child: Text('No settlement data'));
        }
        if (widget.settlementBuilder != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: widget.settlementBuilder!(context, _settlement!),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SettlementCard(
            settlement: _settlement!,
            currency: currency,
            showCategoryBreakdown: true,
          ),
        );
      case DashboardTab.summary:
        if (_summary == null) {
          return const Center(child: Text('No summary data'));
        }
        if (widget.summaryBuilder != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: widget.summaryBuilder!(context, _summary!),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TripSummaryWidget(
            summary: _summary!,
            currency: currency,
            showCategoryBreakdown: true,
            showMemberRanking: true,
            showPhaseBreakdown: true,
            showTimeline: true,
          ),
        );
    }
  }
}

class _TabBar extends StatelessWidget {
  final List<DashboardTab> tabs;
  final int selected;
  final ValueChanged<int> onTap;

  const _TabBar({
    required this.tabs,
    required this.selected,
    required this.onTap,
  });

  String _label(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.expenses:
        return 'Expenses';
      case DashboardTab.balances:
        return 'Balances';
      case DashboardTab.summary:
        return 'Summary';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.surface,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? theme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _label(tabs[i]),
                  style: theme.bodyStyle.copyWith(
                    color: isSelected ? theme.primary : theme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final VoidCallback onTap;

  const _Fab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.add, color: theme.surface),
      ),
    );
  }
}
