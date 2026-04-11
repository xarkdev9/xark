import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// A dimmed list row (not a button) that navigates to the full
/// list screen when tapped. Zero-Box: no background, no border,
/// no pill — just text + arrow glyph.
class SeeAllRow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const SeeAllRow({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: HelloColors.inkPrimary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'See all $count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: HelloColors.inkSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
