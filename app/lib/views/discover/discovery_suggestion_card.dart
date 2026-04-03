import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';

/// In-feed suggestion card for inside group decision boards.
///
/// Styled distinctly with dashed border. Shows "@hello suggests" label,
/// 1-3 compact item rows, per-item "Add to board" button, and
/// "Not now" dismiss at bottom.
class DiscoverySuggestionCard extends StatelessWidget {
  final List<DiscoveryItem> suggestions;
  final void Function(DiscoveryItem item)? onAdd;
  final VoidCallback? onDismiss;

  const DiscoverySuggestionCard({
    super.key,
    required this.suggestions,
    this.onAdd,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    // Show at most 3 suggestions
    final items = suggestions.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: HelloColors.chrome,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: HelloColors.inkTertiary.withValues(alpha: 0.3),
          width: 1.0,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // "@hello suggests" label
          Row(
            children: [
              Container(
                width: 6.0,
                height: 6.0,
                decoration: const BoxDecoration(
                  color: HelloColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                '@hello suggests',
                style: HelloTypography.hint.copyWith(
                  fontWeight: FontWeight.w300,
                  color: HelloColors.accent,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10.0),

          // Item rows
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _SuggestionRow(
                item: item,
                onAdd: () => onAdd?.call(item),
              ),
            );
          }),

          // "Not now" dismiss
          const SizedBox(height: 4.0),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'Not now',
                style: HelloTypography.hint.copyWith(
                  fontWeight: FontWeight.w300,
                  color: HelloColors.inkTertiary,
                  decoration: TextDecoration.underline,
                  decorationColor: HelloColors.inkTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final DiscoveryItem item;
  final VoidCallback? onAdd;

  const _SuggestionRow({
    required this.item,
    this.onAdd,
  });

  String _formatPrice() {
    if (item.price == null) return '';
    final currency = item.currency ?? 'USD';
    final symbol = currency == 'EUR' ? '\u20ac' : '\$';
    return '$symbol${item.price!.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: SizedBox(
            width: 40.0,
            height: 40.0,
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, st) => Container(
                      color: HelloColors.recessed,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 16.0,
                        color: HelloColors.inkTertiary,
                      ),
                    ),
                  )
                : Container(
                    color: HelloColors.recessed,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 16.0,
                      color: HelloColors.inkTertiary,
                    ),
                  ),
          ),
        ),

        const SizedBox(width: 10.0),

        // Title + price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                style: HelloTypography.body.copyWith(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.price != null)
                Text(
                  _formatPrice(),
                  style: HelloTypography.hint.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 12.0,
                  ),
                ),
            ],
          ),
        ),

        // "Add to board" button
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: HelloColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Text(
              'Add',
              style: HelloTypography.label.copyWith(
                fontWeight: FontWeight.w400,
                color: HelloColors.accent,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
