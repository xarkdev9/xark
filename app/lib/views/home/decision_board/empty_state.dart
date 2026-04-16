import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../utils/haptics.dart';
import 'plasma/plasma.dart';

class HelloEmptyState extends StatelessWidget {
  const HelloEmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String headline;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: HelloColors.inkTertiary),
            const SizedBox(height: 16),
            Text(headline,
                style: HelloText.heading, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body,
                style: HelloText.small
                    .copyWith(color: HelloColors.inkSecondary),
                textAlign: TextAlign.center),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HelloHaptic.tap();
                  onCta!();
                },
                child: PlasmaFill(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    child: Text(ctaLabel!,
                        style: HelloText.small
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
