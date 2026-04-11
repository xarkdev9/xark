import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

class AiNudgeCard extends StatelessWidget {
  final AiNudgeFeedItem item;
  final VoidCallback onTap;

  const AiNudgeCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CardShell(
      onTap: onTap,
      accentColor: HelloColors.focusAlpine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: HelloColors.focusAlpine,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '@HELLO',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: HelloColors.focusAlpine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w300,
              height: 1.45,
              color: HelloColors.inkPrimary,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.ctaLabel != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  item.ctaLabel!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.focusAlpine,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: HelloColors.focusAlpine,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
