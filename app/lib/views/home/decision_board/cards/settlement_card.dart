import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col settlement card. Shows "You owe X" or "X owes you" plus
/// an inline pay button (mock — prints to debug).
class SettlementCard extends StatelessWidget {
  final SettlementFeedItem item;
  final VoidCallback onTap;

  const SettlementCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = item.settlement;
    final abs = s.amount.abs().toStringAsFixed(2);
    final prefix = s.currency == 'USD' ? '\$' : s.currency;
    return CardShell(
      id: item.id,
      kindOverlay: CardKindGradients.settlement,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.isOwedToYou ? 'OWED TO YOU' : 'YOU OWE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: s.isOwedToYou
                  ? HelloColors.liveGreen
                  : HelloColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                prefix,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                abs,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.isOwedToYou
                ? 'from ${s.counterpartyName}'
                : 'to ${s.counterpartyName}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.reason,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: HelloColors.inkTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (!s.isOwedToYou)
            _PayButton(onTap: () => debugPrint('[mock] pay ${s.id}'))
          else
            _RequestButton(onTap: () => debugPrint('[mock] remind ${s.id}')),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          color: HelloColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
          'PAY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RequestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          color: HelloColors.recessed,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
          'REMIND',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: HelloColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
