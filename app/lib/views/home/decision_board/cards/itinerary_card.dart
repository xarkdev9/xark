import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

class ItineraryCard extends StatelessWidget {
  final ItineraryFeedItem item;
  final VoidCallback onTap;

  const ItineraryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _countdown() {
    final diff = item.event.startsAt.difference(DateTime.now());
    if (diff.isNegative) return 'NOW';
    if (diff.inHours < 1) return 'IN ${diff.inMinutes}M';
    if (diff.inHours < 24) return 'IN ${diff.inHours}H';
    return 'IN ${diff.inDays}D';
  }

  @override
  Widget build(BuildContext context) {
    return CardShell(
      id: item.id,
      kindOverlay: CardKindGradients.itinerary,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _countdown(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: HelloColors.liveGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.event.title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: HelloColors.inkPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            item.event.location,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: HelloColors.inkSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '${item.event.memberIds.length} attending',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
