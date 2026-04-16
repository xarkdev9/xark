import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';

/// Individual carousel card — rounded rectangle with image background,
/// gradient overlay, and title/subtitle at bottom.
class CarouselCardTile extends StatelessWidget {
  final CarouselCard card;
  final void Function(DiscoveryItem item)? onItemTap;

  const CarouselCardTile({
    super.key,
    required this.card,
    this.onItemTap,
  });

  Color _parseHeroColor() {
    try {
      final hex = card.heroColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return HelloColors.recessed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroColor = _parseHeroColor();

    return GestureDetector(
      onTap: () {
        if (card.items.isNotEmpty && onItemTap != null) {
          onItemTap!(card.items.first);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: heroColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image background or hero color fallback
            if (card.imageUrl != null && card.imageUrl!.isNotEmpty)
              Image.network(
                card.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, st) => Container(color: heroColor),
              )
            else
              Container(color: heroColor),

            // Gradient overlay: transparent top -> dark bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Title + subtitle at bottom
            Positioned(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.title,
                    style: HelloTypography.spaceTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (card.subtitle != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      card.subtitle!,
                      style: HelloTypography.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Item count badge
            if (card.items.length > 1)
              Positioned(
                top: 12.0,
                right: 12.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '${card.items.length} items',
                    style: HelloTypography.hint.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
