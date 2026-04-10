import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';

/// A row of selectable chips representing [SplitMode] options.
///
/// The selected chip is highlighted with the theme's primary color.
class SplitModeToggle extends StatelessWidget {
  final SplitMode selected;
  final List<SplitMode> available;
  final ValueChanged<SplitMode> onChanged;

  const SplitModeToggle({
    super.key,
    required this.selected,
    required this.available,
    required this.onChanged,
  });

  String _label(SplitMode mode) {
    switch (mode) {
      case SplitMode.equal:
        return 'Equal';
      case SplitMode.exact:
        return 'Exact';
      case SplitMode.percentage:
        return 'Percent';
      case SplitMode.shares:
        return 'Shares';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Wrap(
      spacing: 8,
      children: available.map((mode) {
        final isSelected = mode == selected;
        return GestureDetector(
          onTap: () => onChanged(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? theme.primary : theme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? theme.primary : theme.neutral.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _label(mode),
              style: theme.captionStyle.copyWith(
                color: isSelected ? theme.surface : theme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
