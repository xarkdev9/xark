import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';

/// Small pill-shaped button for a payment provider.
///
/// Displays the provider name and optionally generates a payment link on tap.
class PaymentButton extends StatelessWidget {
  final XpenslyPaymentProvider provider;
  final String from;
  final String to;
  final double amount;
  final String currency;
  final String? note;
  final bool showQr;
  final VoidCallback? onTap;

  const PaymentButton({
    super.key,
    required this.provider,
    required this.from,
    required this.to,
    required this.amount,
    required this.currency,
    this.note,
    this.showQr = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          provider.name,
          style: theme.captionStyle.copyWith(color: theme.primary),
        ),
      ),
    );
  }
}
