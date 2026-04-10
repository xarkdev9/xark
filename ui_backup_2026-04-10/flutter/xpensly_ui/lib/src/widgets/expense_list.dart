import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';
import '../utils/formatters.dart';

/// Grouping strategy for the expense list.
enum GroupBy { date, category, payer, phase }

/// Renders a grouped, scrollable list of expenses.
class ExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final ExpenseFilter? filters;
  final GroupBy groupBy;
  final void Function(Expense)? onTap;
  final void Function(Expense)? onDelete;

  /// Optional custom item builder. If null, the default row is used.
  final Widget Function(BuildContext, Expense)? itemBuilder;

  const ExpenseList({
    super.key,
    required this.expenses,
    this.filters,
    this.groupBy = GroupBy.date,
    this.onTap,
    this.onDelete,
    this.itemBuilder,
  });

  Map<String, List<Expense>> _group(List<Expense> items) {
    final grouped = <String, List<Expense>>{};
    for (final e in items) {
      final key = _keyFor(e);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    return grouped;
  }

  String _keyFor(Expense e) {
    switch (groupBy) {
      case GroupBy.date:
        return formatDate(e.date);
      case GroupBy.category:
        return e.category;
      case GroupBy.payer:
        return e.paidBy.map((p) => p.userId).join(', ');
      case GroupBy.phase:
        return e.phase ?? 'No phase';
    }
  }

  List<Expense> _applyFilters(List<Expense> items) {
    if (filters == null || filters!.isEmpty) return items;
    return items.where((e) {
      if (filters!.category != null && e.category != filters!.category) {
        return false;
      }
      if (filters!.phase != null && e.phase != filters!.phase) return false;
      if (filters!.paidBy != null &&
          !e.paidBy.any((p) => p.userId == filters!.paidBy)) {
        return false;
      }
      if (filters!.from != null && e.date.isBefore(filters!.from!)) {
        return false;
      }
      if (filters!.to != null && e.date.isAfter(filters!.to!)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);
    final filtered = _applyFilters(expenses);
    final groups = _group(filtered);
    final sortedKeys = groups.keys.toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No expenses',
          style: theme.bodyStyle.copyWith(color: theme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: sortedKeys.length,
      itemBuilder: (context, sectionIndex) {
        final key = sortedKeys[sectionIndex];
        final items = groups[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                key,
                style: theme.captionStyle.copyWith(color: theme.textSecondary),
              ),
            ),
            ...items.map((expense) {
              if (itemBuilder != null) return itemBuilder!(context, expense);
              return _DefaultExpenseRow(
                expense: expense,
                onTap: onTap != null ? () => onTap!(expense) : null,
                onDelete: onDelete != null ? () => onDelete!(expense) : null,
              );
            }),
          ],
        );
      },
    );
  }
}

class _DefaultExpenseRow extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _DefaultExpenseRow({
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: theme.bodyStyle.copyWith(color: theme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${expense.paidBy.map((p) => p.userId).join(", ")} \u2022 ${formatDate(expense.date)}',
                    style:
                        theme.captionStyle.copyWith(color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              formatCurrency(expense.amount, expense.currency),
              style: theme.amountStyle.copyWith(color: theme.textPrimary),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close, size: 16, color: theme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
