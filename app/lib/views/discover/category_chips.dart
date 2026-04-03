import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';

/// Horizontal scroll of category filter chips.
///
/// "All" chip at start (selected when [selected] is null).
/// Selected chip highlighted with the app's accent color.
class CategoryChips extends StatelessWidget {
  final DiscoveryCategory? selected;
  final void Function(DiscoveryCategory? category)? onSelected;

  const CategoryChips({
    super.key,
    this.selected,
    this.onSelected,
  });

  static String _displayName(DiscoveryCategory category) {
    switch (category) {
      case DiscoveryCategory.restaurants:
        return 'Restaurants';
      case DiscoveryCategory.hotels:
        return 'Hotels';
      case DiscoveryCategory.activities:
        return 'Activities';
      case DiscoveryCategory.destinations:
        return 'Destinations';
      case DiscoveryCategory.dayPlans:
        return 'Day Plans';
      case DiscoveryCategory.experiences:
        return 'Experiences';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          // "All" chip
          _ChipItem(
            label: 'All',
            isSelected: selected == null,
            onTap: () => onSelected?.call(null),
          ),
          const SizedBox(width: 8.0),
          // One chip per category
          ...DiscoveryCategory.values.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _ChipItem(
                label: _displayName(category),
                isSelected: selected == category,
                onTap: () => onSelected?.call(category),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ChipItem({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? HelloColors.accent.withValues(alpha: 0.12)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(20.0),
          border: isSelected
              ? Border.all(color: HelloColors.accent, width: 1.0)
              : null,
        ),
        child: Text(
          label,
          style: HelloTypography.label.copyWith(
            color: isSelected ? HelloColors.accent : HelloColors.inkSecondary,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
