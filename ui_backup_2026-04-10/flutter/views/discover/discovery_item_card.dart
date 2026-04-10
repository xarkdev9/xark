import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';

/// Grid card for a single [DiscoveryItem].
///
/// Shows image (placeholder if null), title, subtitle, optional price,
/// taste score dot, taste reason, and source badge.
class DiscoveryItemCard extends StatelessWidget {
  final DiscoveryItem item;
  final VoidCallback? onTap;

  const DiscoveryItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  Color _tasteColor() {
    if (item.tasteScore > 0.7) return HelloColors.successGreen;
    if (item.tasteScore > 0.4) return HelloColors.seekingAmber;
    return HelloColors.neutralGray;
  }

  String _sourceBadge() {
    switch (item.source) {
      case 'gemini':
        return 'AI';
      case 'catalog':
      case 'editorial':
        return 'curated';
      default:
        return item.source;
    }
  }

  String _formatPrice() {
    if (item.price == null) return '';
    final currency = item.currency ?? 'USD';
    final symbol = currency == 'EUR' ? '\u20ac' : '\$';
    return '$symbol${item.price!.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: HelloColors.chrome,
          borderRadius: BorderRadius.circular(12.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            AspectRatio(
              aspectRatio: 4 / 3,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, st) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            // Content area
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: HelloTypography.body.copyWith(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Subtitle
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      item.subtitle!,
                      style: HelloTypography.hint.copyWith(
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 6.0),

                  // Price + taste score + source badge row
                  Row(
                    children: [
                      // Taste dot
                      Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: _tasteColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6.0),

                      // Price
                      if (item.price != null) ...[
                        Text(
                          _formatPrice(),
                          style: HelloTypography.label.copyWith(
                            color: HelloColors.inkPrimary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),

                      // Source badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          _sourceBadge(),
                          style: HelloTypography.hint.copyWith(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w300,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Taste reason
                  if (item.tasteReason != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      item.tasteReason!,
                      style: HelloTypography.hint.copyWith(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w300,
                        color: HelloColors.inkTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: HelloColors.recessed,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: HelloColors.inkTertiary,
          size: 32.0,
        ),
      ),
    );
  }
}
