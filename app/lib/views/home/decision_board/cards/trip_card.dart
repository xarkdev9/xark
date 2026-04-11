import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// Tall 1-col trip card with destination photo, dates, member stack,
/// pending-decision count. Tap navigates to the trip view (placeholder
/// route in v1).
class TripCard extends StatelessWidget {
  final TripFeedItem item;
  final VoidCallback onTap;

  const TripCard({super.key, required this.item, required this.onTap});

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

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    return CardShell(
      id: item.id,
      onTap: onTap,
      accentColor: trip.accentColor,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 280,
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
            ColoredBox(color: Colors.black.withValues(alpha: 0.30)),
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
              top: 16,
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
                    trip.phase.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                      color: trip.accentColor,
                    ),
                  ),
                ],
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
                  Text(
                    trip.destination,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                      color: Color(0xFFF0EFF4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateRange(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFFF0EFF4).withValues(alpha: 0.80),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${trip.memberIds.length} members',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                          color: Color(0xFFF0EFF4),
                        ),
                      ),
                      const Spacer(),
                      if (trip.pendingDecisionCount > 0)
                        Text(
                          '${trip.pendingDecisionCount} pending',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                            color: HelloColors.accent,
                          ),
                        ),
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
