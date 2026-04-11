import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// Tall 1-col hero decision card with photo background, scrim,
/// live tag, and vote progress.
class DecisionCardHero extends StatelessWidget {
  final DecisionHeroFeedItem item;
  final VoidCallback onTap;

  const DecisionCardHero({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CardShell(
      id: item.id,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: HelloColors.surfaceDeep,
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(color: HelloColors.surfaceDeep);
              },
            ),
            const ColoredBox(color: Color(0x55000000)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.liveTag != null)
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: HelloColors.liveGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.liveTag!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.liveGreen,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 1.15,
                      color: Color(0xFFF0EFF4),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFFF0EFF4).withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${item.votedCount} of ${item.totalCount} voted',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                      color: Color(0xFFF0EFF4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: item.totalCount == 0
                          ? 0
                          : item.votedCount / item.totalCount,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        HelloColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
