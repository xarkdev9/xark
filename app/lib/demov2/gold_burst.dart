import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Overlay widget that plays a gold glow + border animation on consensus.
class GoldBurstOverlay extends StatefulWidget {
  /// Set to true to trigger the animation.
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
      duration: const Duration(milliseconds: 1200),
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
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Before burst has fired, skip the Stack entirely to avoid layout issues
    if (!_hasPlayed) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final borderProgress = (_controller.value * 2.5).clamp(0.0, 1.0);
        final glowProgress = _controller.value < 0.5
            ? (_controller.value * 2.0)
            : (1.0 - (_controller.value - 0.5) * 1.0).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: HelloColors.gold.withValues(alpha: borderProgress * 0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: HelloColors.gold.withValues(alpha: glowProgress * 0.3),
                blurRadius: 20 + glowProgress * 10,
                spreadRadius: glowProgress * 4,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
