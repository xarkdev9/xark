import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// Full-width hero card for the pinned focus trip. Always appears
/// at the top of the feed (outside the masonry grid).
class FocusHeroCard extends StatelessWidget {
  final FocusHeroFeedItem item;
  final VoidCallback onTap;

  const FocusHeroCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _dateRange() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final s = item.trip.startDate;
    final e = item.trip.endDate;
    return '${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}';
  }

  int _daysUntil() {
    final diff = item.trip.startDate.difference(DateTime.now()).inDays;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    final days = _daysUntil();

    return CardShell(
      id: item.id,
      onTap: onTap,
      accentColor: trip.accentColor,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 340,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              trip.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: trip.accentColor.withValues(alpha: 0.3),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: trip.accentColor.withValues(alpha: 0.3),
                );
              },
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xDD000000)],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 20,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: trip.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'YOUR FOCUS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      color: trip.accentColor,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.destination,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      height: 1.05,
                      letterSpacing: -0.5,
                      color: Color(0xFFF0EFF4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateRange(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFFF0EFF4).withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (days > 0) ...[
                        Text(
                          '$days DAYS',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: Color(0xFFF0EFF4),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        '${trip.memberIds.length} MEMBERS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: const Color(0xFFF0EFF4).withValues(alpha: 0.85),
                        ),
                      ),
                      if (trip.pendingDecisionCount > 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          '${trip.pendingDecisionCount} PENDING',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.accent,
                          ),
                        ),
                      ],
                    ],
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
