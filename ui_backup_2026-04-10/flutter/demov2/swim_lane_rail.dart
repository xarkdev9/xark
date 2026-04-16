import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';
import '../widgets/action_card_widget.dart';

import '../providers/decrypted_item_payload.dart';

/// Vital label computed from items in a rail.
class _RailVital {
  final String label;
  final Color color;
  const _RailVital(this.label, this.color);
}

_RailVital _computeVital(List<DecryptedItemPayload> items) {
  final total = items.length;
  final rated = items.where((i) => i.agreementScore > 0).length;
  final sorted = List<DecryptedItemPayload>.from(items)
    ..sort((a, b) => b.agreementScore.compareTo(a.agreementScore));
  final top = sorted.isNotEmpty ? sorted.first : null;

  if (top != null && top.agreementScore >= 0.8) {
    final pct = (top.agreementScore * 100).toInt();
    return _RailVital('$pct% on #1 \u00b7 $rated of $total', HelloColors.gold);
  }
  if (rated == 0) {
    return _RailVital('needs votes', HelloColors.seekingAmber);
  }
  return _RailVital('$rated of $total rated', HelloColors.accent);
}

class SwimLaneRail extends StatelessWidget {
  final String category;
  final List<DecryptedItemPayload> items;
  final void Function(DecryptedItemPayload item, String reaction) onReact;
  final void Function(DecryptedItemPayload item) onLock;

  const SwimLaneRail({
    super.key,
    required this.category,
    required this.items,
    required this.onReact,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth * 0.72;
    final cardHeight = screenHeight * 0.35;
    final vital = _computeVital(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.toLowerCase(),
                style: HelloTypography.spaceTitle,
              ),
              Text(
                vital.label,
                style: HelloTypography.hint.copyWith(
                  color: vital.color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Horizontal card scroll
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(right: index < items.length - 1 ? 12 : 0),
                child: SizedBox(
                  width: cardWidth,
                  child: ActionCardWidget(
                    item: item,
                    onReact: () => onReact(item, 'works_for_me'),
                    onPinCommit: () => onLock(item),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Collapsed locked rail — single line for trophies.
class LockedRailSummary extends StatelessWidget {
  final List<DecryptedItemPayload> items;

  const LockedRailSummary({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final first = items.first.title;
    final extra = items.length > 1 ? ' + ${items.length - 1} more' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: HelloColors.successGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text('locked', style: HelloTypography.label),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$first$extra',
              style: HelloTypography.hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
