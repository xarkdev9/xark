import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/playground_provider.dart';
import '../../../../theme.dart';
import '../../../../utils/haptics.dart';
import '../plasma/plasma.dart';
import '_card_shell.dart';

/// Full-width decision card with voting and progress bar.
/// Used by non-cosmos surfaces (Plans, detail routes).
class DecisionCard extends ConsumerWidget {
  final DecisionHeroFeedItem item;
  final VoidCallback onTap;

  const DecisionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisions = ref.watch(playgroundDecisionsProvider);
    final liveItem =
        decisions.where((d) => d.id == item.item.id).firstOrNull ??
            item.item;
    final myVote = liveItem.reactions['me'];
    final scorePct = (liveItem.agreementScore * 100).round();

    return CardShell(
      id: item.id,
      kindOverlay: CardKindGradients.decision,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.liveTag != null)
            PlasmaTint(
              child: Text(
                item.liveTag!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: HelloText.body.copyWith(height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          // Vote row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _VoteChip(
                label: 'Love',
                active: myVote == 'love_it',
                onTap: () {
                  HelloHaptic.tap();
                  ref
                      .read(playgroundDecisionsProvider.notifier)
                      .vote(item.item.id, 'love_it', 'me');
                },
              ),
              _VoteChip(
                label: 'Works',
                active: myVote == 'works_for_me',
                onTap: () {
                  HelloHaptic.tap();
                  ref
                      .read(playgroundDecisionsProvider.notifier)
                      .vote(item.item.id, 'works_for_me', 'me');
                },
              ),
              _VoteChip(
                label: 'Pass',
                active: myVote == 'not_for_me',
                onTap: () {
                  HelloHaptic.tap();
                  ref
                      .read(playgroundDecisionsProvider.notifier)
                      .vote(item.item.id, 'not_for_me', 'me');
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: PlasmaProgressBar(
                  value: liveItem.agreementScore.clamp(0.0, 1.0),
                  height: 3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$scorePct%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VoteChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: active
          ? PlasmaStroke(
              width: 1,
              borderRadius: BorderRadius.circular(6),
              child: PlasmaFill(
                alpha: 0.18,
                borderRadius: BorderRadius.circular(6),
                width: 64,
                height: 28,
                child: Center(
                  child: PlasmaTint(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container(
              width: 64,
              height: 28,
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkSecondary,
                ),
              ),
            ),
    );
  }
}
