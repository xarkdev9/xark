import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';

class GroupSummaryCard extends StatelessWidget {
  final List<DecisionItem> items;

  const GroupSummaryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final locked = items.where((i) => i.isLocked).length;
    final voting = items.where((i) => !i.isLocked && i.agreementScore > 0).length;
    final fresh = items.where((i) => !i.isLocked && i.agreementScore == 0).length;

    // Find hottest unlocked item
    final unlocked = items.where((i) => !i.isLocked && i.agreementScore > 0).toList()
      ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
    final hottest = unlocked.isNotEmpty ? unlocked.first : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HelloColors.recessed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left: counts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$voting active  \u00b7  $locked locked  \u00b7  $fresh new',
                  style: HelloTypography.label.copyWith(letterSpacing: 0.5),
                ),
                if (hottest != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: hottest.agreementScore >= 0.8
                              ? HelloColors.gold
                              : HelloColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${hottest.title} at ${(hottest.agreementScore * 100).toInt()}%',
                          style: HelloTypography.body.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Right: total count
          Text(
            '${items.length}',
            style: HelloTypography.hero.copyWith(
              color: HelloColors.accent,
              fontSize: 32,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
