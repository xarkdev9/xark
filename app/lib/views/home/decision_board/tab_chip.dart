import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';

/// The `[HOME ▾]` chip that lives on the BottomBar. Watches
/// [activeTabProvider] and shows the current tab's label + caret.
/// Tapping invokes [onTap] (which the BottomBar wires to open the
/// TabPopover).
class TabChip extends ConsumerWidget {
  final VoidCallback onTap;
  const TabChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(activeTabProvider);
    final accent = tab.signatureColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(
          color: HelloColors.recessed.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
                color: accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 14,
              color: accent.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}
