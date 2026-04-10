import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Liquid Fire celebration — pulses the brand orange gradient when consensus hits.
/// Replaces the muted gold with the searing orange (#FF6B35) brand identity.
class GoldBurstOverlay extends StatefulWidget {
  final bool trigger;
  final Widget child;

  const GoldBurstOverlay({
    super.key,
    required this.trigger,
    required this.child,
  });

  @override
  State<GoldBurstOverlay> createState() => _GoldBurstOverlayState();
}

class _GoldBurstOverlayState extends State<GoldBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didUpdateWidget(GoldBurstOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !_hasPlayed) {
      _fire();
    }
  }

  void _fire() {
    _hasPlayed = true;
    HapticFeedback.heavyImpact();
    // Play once, then breathe forever
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPlayed) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Breathing glow: oscillates between 0.15 and 0.45
        final glowAlpha = 0.15 + (t * 0.3);
        final blurRadius = 16.0 + (t * 14.0);
        final spreadRadius = 1.0 + (t * 3.0);
        // Border pulses between brand orange shades
        final borderAlpha = 0.5 + (t * 0.4);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: HelloColors.accent.withValues(alpha: borderAlpha),
              width: 2,
            ),
            boxShadow: [
              // Primary Liquid Fire glow
              BoxShadow(
                color: HelloColors.accent.withValues(alpha: glowAlpha),
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
              // Secondary warm halo
              BoxShadow(
                color: const Color(0xFFFF9F43).withValues(alpha: glowAlpha * 0.5),
                blurRadius: blurRadius * 1.5,
                spreadRadius: 0,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
