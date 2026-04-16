import 'package:flutter/material.dart';
import '../../../utils/haptics.dart';

class LiquidFireConsensusBurst extends StatefulWidget {
  final Widget child;
  final bool isIgnited;

  const LiquidFireConsensusBurst({
    super.key,
    required this.child,
    required this.isIgnited,
  });

  @override
  State<LiquidFireConsensusBurst> createState() => _LiquidFireConsensusBurstState();
}

class _LiquidFireConsensusBurstState extends State<LiquidFireConsensusBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutExpo,
      ),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 80),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant LiquidFireConsensusBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isIgnited && !oldWidget.isIgnited && !_hasTriggered) {
      _hasTriggered = true;
      _triggerBurst();
    } else if (!widget.isIgnited && oldWidget.isIgnited) {
      _hasTriggered = false;
    }
  }

  void _triggerBurst() {
    HelloHaptic.celebrate();
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (_hasTriggered)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFEF7C6E).withValues(alpha: 0.6), // Saturated Coral
                          const Color(0xFFD4636E).withValues(alpha: 0.4), // Liquid Fire Brand
                          const Color(0xFF7C1D3E).withValues(alpha: 0.0), // Fade to void
                        ],
                        stops: const [0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        widget.child,
      ],
    );
  }
}
