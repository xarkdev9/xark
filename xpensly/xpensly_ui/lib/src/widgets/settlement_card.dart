import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';
import '../utils/formatters.dart';
import 'balance_bar.dart';

/// Full settlement summary card.
///
/// Displays ledger entries with balance bars, debt deltas (simplified or
/// pairwise depending on the toggle), and an optional category breakdown.
class SettlementCard extends StatefulWidget {
  final Settlement settlement;
  final void Function(DebtDelta)? onPaymentTap;
  final bool simplifyToggle;
  final bool showCategoryBreakdown;

  /// Optional custom builder for each debt delta row.
  final Widget Function(BuildContext, DebtDelta)? deltaBuilder;
  final String currency;

  const SettlementCard({
    super.key,
    required this.settlement,
    this.onPaymentTap,
    this.simplifyToggle = true,
    this.showCategoryBreakdown = false,
    this.deltaBuilder,
    this.currency = 'USD',
  });

  @override
  State<SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends State<SettlementCard> {
  late bool _simplified;

  @override
  void initState() {
    super.initState();
    _simplified = widget.simplifyToggle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);
    final s = widget.settlement;
    final deltas = _simplified ? s.simplified : s.deltas;
    final maxBalance = s.entries.isEmpty
        ? 0.0
        : s.entries
            .map((e) => e.netBalance.abs())
            .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.cardRadius,
        boxShadow: theme.cardElevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: theme.cardElevation * 2,
                  offset: Offset(0, theme.cardElevation),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settlement',
                style: theme.titleStyle.copyWith(color: theme.textPrimary),
              ),
              Text(
                'Total: ${formatCurrency(s.totalSpent, widget.currency)}',
                style: theme.captionStyle.copyWith(color: theme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${s.memberCount} members \u2022 ${formatCurrency(s.perPerson, widget.currency)} per person',
            style: theme.captionStyle.copyWith(color: theme.textSecondary),
          ),
          const SizedBox(height: 12),

          // Balance bars
          ...s.entries.map((entry) => BalanceBar(
                userId: entry.userId,
                name: entry.name,
                netBalance: entry.netBalance,
                currency: widget.currency,
                maxBalance: maxBalance,
              )),

          const SizedBox(height: 12),

          // Simplify toggle
          if (widget.simplifyToggle && s.simplified.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _simplified = !_simplified),
              child: Row(
                children: [
                  Icon(
                    _simplified ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: theme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Simplify debts',
                    style: theme.captionStyle.copyWith(color: theme.textSecondary),
                  ),
                ],
              ),
            ),

          if (deltas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _simplified ? 'Simplified' : 'All debts',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 4),
            ...deltas.map((delta) {
              if (widget.deltaBuilder != null) {
                return widget.deltaBuilder!(context, delta);
              }
              return _DefaultDeltaRow(
                delta: delta,
                onTap: widget.onPaymentTap != null
                    ? () => widget.onPaymentTap!(delta)
                    : null,
              );
            }),
          ],

          // Category breakdown
          if (widget.showCategoryBreakdown && s.byCategory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'By category',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 4),
            ...s.byCategory.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style:
                            theme.bodyStyle.copyWith(color: theme.textPrimary),
                      ),
                      Text(
                        formatCurrency(e.value, widget.currency),
                        style: theme.amountStyle
                            .copyWith(color: theme.textPrimary),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _DefaultDeltaRow extends StatelessWidget {
  final DebtDelta delta;
  final VoidCallback? onTap;

  const _DefaultDeltaRow({required this.delta, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${delta.from} \u2192 ${delta.to}',
                style: theme.bodyStyle.copyWith(color: theme.textPrimary),
              ),
            ),
            Text(
              formatCurrency(delta.amount, delta.currency),
              style: theme.amountStyle.copyWith(color: theme.negative),
            ),
          ],
        ),
      ),
    );
  }
}
