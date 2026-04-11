import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// A single list row for a decision item. 64px tall.
/// Horizontal layout: thumbnail · score · title/category · consensus bar as bottom separator.
class DecisionRow extends StatelessWidget {
  final DecisionItem item;
  final VoidCallback onTap;

  const DecisionRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  int get _score => (item.agreementScore * 100).round();

  Color _scoreColor() {
    if (item.agreementScore >= 0.80) return const Color(0xFFE8C86A); // gold
    if (item.agreementScore >= 0.50) return const Color(0xFFFF9B6E); // accent-light
    return const Color(0xFFFBBF24); // warning
  }

  String _title() => 'Decision ${item.id.substring(0, 8)}';

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 2),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Thumbnail (placeholder gradient, 40×40, 0 radius per Zero-Box)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scoreColor.withValues(alpha: 0.4),
                          scoreColor.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Score (Geist Mono 22px, tabular)
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_score',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.44,
                        color: scoreColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + category stacked
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: HelloColors.inkPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.state} · ${item.reactions.length} reactions',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1,
                            color: HelloColors.inkTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Consensus bar REPLACES the row's bottom separator.
            // Width proportional to agreementScore (0.0 – 1.0).
            SizedBox(
              height: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: item.agreementScore.clamp(0.0, 1.0),
                  child: Container(color: scoreColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
