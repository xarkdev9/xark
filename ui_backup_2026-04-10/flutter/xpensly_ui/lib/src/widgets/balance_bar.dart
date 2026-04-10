import 'package:flutter/material.dart';

import '../theme/xpensly_theme.dart';
import '../utils/formatters.dart';

/// Horizontal bar showing a member's net balance.
///
/// Positive balance = green bar ("owed $X").
/// Negative balance = orange bar ("owes $X").
/// Zero = neutral text, no bar.
class BalanceBar extends StatelessWidget {
  final String userId;
  final String name;
  final double netBalance;
  final String currency;

  /// Maximum absolute balance in the group, used to scale bar width.
  final double maxBalance;

  const BalanceBar({
    super.key,
    required this.userId,
    required this.name,
    required this.netBalance,
    required this.currency,
    required this.maxBalance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);
    final isPositive = netBalance > 0;
    final isZero = netBalance == 0;
    final barColor = isZero
        ? theme.neutral
        : isPositive
            ? theme.positive
            : theme.negative;
    final fraction = maxBalance > 0 ? netBalance.abs() / maxBalance : 0.0;
    final label = isZero
        ? 'settled'
        : isPositive
            ? 'owed ${formatCurrency(netBalance.abs(), currency)}'
            : 'owes ${formatCurrency(netBalance.abs(), currency)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              name,
              style: theme.bodyStyle.copyWith(color: theme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isZero
                ? const SizedBox.shrink()
                : FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction.clamp(0.02, 1.0),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.captionStyle.copyWith(color: barColor),
          ),
        ],
      ),
    );
  }
}
