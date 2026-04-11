import 'package:flutter/material.dart';

import '../../../models/trip.dart';
import '../../../theme.dart';

/// Header strip at the top of the home feed.
/// Left: "LIVE SURFACE" eyebrow + "What matters now" display title.
/// Right: "FOCUS" eyebrow in the focus accent color + focus title.
class FeedHeader extends StatelessWidget {
  final Trip? focus;
  const FeedHeader({super.key, this.focus});

  @override
  Widget build(BuildContext context) {
    final focusColor = focus?.accentColor ?? HelloColors.focusViolet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LIVE SURFACE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                    color: HelloColors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'What matters now',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                    height: 1.1,
                    color: HelloColors.inkPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (focus != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: focusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FOCUS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        color: focusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  focus!.destination,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkPrimary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
