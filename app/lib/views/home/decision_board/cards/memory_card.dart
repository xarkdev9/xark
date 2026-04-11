import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

class MemoryCard extends StatelessWidget {
  final MemoryFeedItem item;
  final VoidCallback onTap;

  const MemoryCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CardShell(
      id: item.id,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.photoUrl != null)
            AspectRatio(
              aspectRatio: 1.6,
              child: Image.network(
                item.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: HelloColors.surfaceDeep,
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const ColoredBox(
                    color: HelloColors.surfaceDeep,
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.eyebrow,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5,
                    color: HelloColors.focusSunset,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: HelloColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                    color: HelloColors.inkSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
