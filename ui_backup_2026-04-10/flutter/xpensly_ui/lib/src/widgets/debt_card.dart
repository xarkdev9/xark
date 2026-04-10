import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';
import '../utils/formatters.dart';
import 'payment_button.dart';

/// Card displaying a single debt between two users, with payment buttons.
class DebtCard extends StatelessWidget {
  final DebtDelta delta;
  final List<XpenslyPaymentProvider> paymentProviders;
  final void Function(DebtDelta delta, XpenslyPaymentProvider provider)? onSettle;

  /// Optional builder for rendering user avatars.
  final Widget Function(BuildContext, String userId)? avatarBuilder;

  const DebtCard({
    super.key,
    required this.delta,
    this.paymentProviders = const [],
    this.onSettle,
    this.avatarBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
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
          Row(
            children: [
              if (avatarBuilder != null) ...[
                avatarBuilder!(context, delta.from),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.bodyStyle.copyWith(color: theme.textPrimary),
                    children: [
                      TextSpan(
                        text: delta.from,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: ' owes ',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                      TextSpan(
                        text: delta.to,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
              if (avatarBuilder != null) ...[
                const SizedBox(width: 8),
                avatarBuilder!(context, delta.to),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(delta.amount, delta.currency),
            style: theme.amountStyle.copyWith(color: theme.negative),
          ),
          if (paymentProviders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: paymentProviders.map((provider) {
                return PaymentButton(
                  provider: provider,
                  from: delta.from,
                  to: delta.to,
                  amount: delta.amount,
                  currency: delta.currency,
                  onTap: onSettle != null
                      ? () => onSettle!(delta, provider)
                      : null,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
