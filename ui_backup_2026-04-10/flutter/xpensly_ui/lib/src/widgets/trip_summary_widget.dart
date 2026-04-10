import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';
import '../theme/xpensly_theme_data.dart';
import '../utils/formatters.dart';

/// Analytics view for a trip's expense summary.
///
/// Displays total spent, per-person average, and optional breakdowns
/// by category, phase, member ranking, and timeline.
class TripSummaryWidget extends StatelessWidget {
  final TripSummary summary;
  final String currency;
  final bool showTimeline;
  final bool showCategoryBreakdown;
  final bool showMemberRanking;
  final bool showPhaseBreakdown;

  const TripSummaryWidget({
    super.key,
    required this.summary,
    this.currency = 'USD',
    this.showTimeline = true,
    this.showCategoryBreakdown = true,
    this.showMemberRanking = true,
    this.showPhaseBreakdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline numbers
          Text(
            'Trip summary',
            style: theme.titleStyle.copyWith(color: theme.textPrimary),
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Total spent',
            value: formatCurrency(summary.totalSpent, currency),
            theme: theme,
          ),
          _StatRow(
            label: 'Per person',
            value: formatCurrency(summary.avgPerPerson, currency),
            theme: theme,
          ),
          _StatRow(
            label: 'Per day',
            value: formatCurrency(summary.avgPerDay, currency),
            theme: theme,
          ),
          _StatRow(
            label: 'Top payer',
            value: summary.topPayer,
            theme: theme,
          ),
          _StatRow(
            label: 'Top spender',
            value: summary.topSpender,
            theme: theme,
          ),

          // Category breakdown
          if (showCategoryBreakdown && summary.byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'By category',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 4),
            ..._sortedEntries(summary.byCategory).map(
              (e) => _StatRow(label: e.key, value: formatCurrency(e.value, currency), theme: theme),
            ),
          ],

          // Phase breakdown
          if (showPhaseBreakdown && summary.byPhase.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'By phase',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 4),
            ..._sortedEntries(summary.byPhase).map(
              (e) => _StatRow(label: e.key, value: formatCurrency(e.value, currency), theme: theme),
            ),
          ],

          // Member ranking
          if (showMemberRanking && summary.byMember.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Member spending',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 4),
            ..._sortedEntries(summary.byMember).map(
              (e) => _StatRow(label: e.key, value: formatCurrency(e.value, currency), theme: theme),
            ),
          ],

          // Timeline bar chart
          if (showTimeline && summary.timeline.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Daily spending',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 8),
            _TimelineChart(
              timeline: summary.timeline,
              currency: currency,
            ),
          ],
        ],
      ),
    );
  }

  List<MapEntry<String, double>> _sortedEntries(Map<String, double> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final XpenslyThemeData theme;

  const _StatRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.bodyStyle.copyWith(color: theme.textPrimary)),
          Text(value, style: theme.amountStyle.copyWith(color: theme.textPrimary)),
        ],
      ),
    );
  }
}

/// Simple horizontal bar chart for daily totals.
class _TimelineChart extends StatelessWidget {
  final List<DailyTotal> timeline;
  final String currency;

  const _TimelineChart({
    required this.timeline,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);
    final maxTotal =
        timeline.map((d) => d.total).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: timeline.map((day) {
          final fraction = maxTotal > 0 ? day.total / maxTotal : 0.0;
          return Expanded(
            child: Tooltip(
              message:
                  '${formatDate(day.date)}\n${formatCurrency(day.total, currency)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: FractionallySizedBox(
                  heightFactor: fraction.clamp(0.02, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.7),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
