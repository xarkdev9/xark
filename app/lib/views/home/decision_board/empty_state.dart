import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Simple empty-state placeholder shared across tabs.
/// Icon + headline + body, centered vertically.
class HelloEmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String body;

  const HelloEmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: HelloColors.inkTertiary),
            const SizedBox(height: 16),
            Text(
              headline,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: HelloColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
