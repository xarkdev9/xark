import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'carousel_card_tile.dart';

/// Stories-style horizontal carousel for the home screen top.
///
/// Displays a scrollable row of [CarouselCardTile] widgets, each occupying
/// ~80% of screen width. Returns [SizedBox.shrink] when cards is empty.
class DiscoveryCarousel extends StatelessWidget {
  final List<CarouselCard> cards;
  final void Function(DiscoveryItem item)? onItemTap;
  final void Function(String cardId)? onDismiss;

  const DiscoveryCarousel({
    super.key,
    required this.cards,
    this.onItemTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.80;
    const cardHeight = 200.0;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return Dismissible(
            key: ValueKey(card.id),
            direction: DismissDirection.up,
            onDismissed: (_) => onDismiss?.call(card.id),
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: CarouselCardTile(
                card: card,
                onItemTap: onItemTap,
              ),
            ),
          );
        },
      ),
    );
  }
}
