import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';

/// Event chip scroll — shows each category as a tappable pill.
/// Gold = locked, Accent = hot (>60%), Gray = new/cold.
class GroupSummaryCard extends StatelessWidget {
  final List<DecisionItem> items;

  const GroupSummaryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // Extract unique categories preserving order of hottest first
    final categoryScores = <String, double>{};
    final categoryStates = <String, bool>{}; // true = has locked item
    for (final item in items) {
      final cat = item.category ?? 'ideas';
      final score = item.agreementScore;
      if (!categoryScores.containsKey(cat) || score > categoryScores[cat]!) {
        categoryScores[cat] = score;
      }
      if (item.isLocked) categoryStates[cat] = true;
      categoryStates.putIfAbsent(cat, () => false);
    }

    // Sort: locked first, then by score desc
    final sortedCategories = categoryScores.keys.toList()
      ..sort((a, b) {
        final aLocked = categoryStates[a] == true;
        final bLocked = categoryStates[b] == true;
        if (aLocked != bLocked) return aLocked ? -1 : 1;
        return categoryScores[b]!.compareTo(categoryScores[a]!);
      });

    final locked = items.where((i) => i.isLocked).length;
    final total = items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact count line
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            '$total items \u00b7 $locked settled',
            style: HelloTypography.hint.copyWith(fontSize: 12),
          ),
        ),
        // Horizontal event chip scroll
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: sortedCategories.length,
            itemBuilder: (context, index) {
              final cat = sortedCategories[index];
              final score = categoryScores[cat]!;
              final isLocked = categoryStates[cat] == true;

              Color chipColor;
              Color textColor;
              if (isLocked) {
                chipColor = HelloColors.gold.withValues(alpha: 0.15);
                textColor = HelloColors.gold;
              } else if (score >= 0.6) {
                chipColor = HelloColors.accent.withValues(alpha: 0.12);
                textColor = HelloColors.accent;
              } else if (score > 0) {
                chipColor = HelloColors.inkTertiary.withValues(alpha: 0.08);
                textColor = HelloColors.inkSecondary;
              } else {
                chipColor = HelloColors.recessed;
                textColor = HelloColors.inkTertiary;
              }

              return Padding(
                padding: EdgeInsets.only(right: index < sortedCategories.length - 1 ? 8 : 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLocked) ...[
                        Icon(Icons.check_circle, size: 13, color: textColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        cat.toLowerCase(),
                        style: HelloTypography.label.copyWith(
                          color: textColor,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (score > 0 && !isLocked) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${(score * 100).toInt()}%',
                          style: HelloTypography.hint.copyWith(
                            color: textColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
