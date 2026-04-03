import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// A single particle in the gold burst animation.
class _Particle {
  final double angle;
  final double velocity;
  final double size;
  final double opacity;

  _Particle()
      : angle = Random().nextDouble() * 2 * pi,
        velocity = 200 + Random().nextDouble() * 300,
        size = 4 + Random().nextDouble() * 8,
        opacity = 0.6 + Random().nextDouble() * 0.4;
}

/// CustomPainter that draws exploding gold particles.
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0.0 to 1.0

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();

    for (final p in particles) {
      final distance = p.velocity * progress;
      final dx = center.dx + cos(p.angle) * distance;
      final dy = center.dy + sin(p.angle) * distance;
      final currentSize = p.size * (1.0 - progress * 0.7);
      final currentOpacity = p.opacity * (1.0 - progress);

      paint.color = HelloColors.gold.withValues(alpha: currentOpacity);
      canvas.drawCircle(Offset(dx, dy), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

/// Overlay widget that plays the gold burst animation.
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
  final List<_Particle> _particles = List.generate(40, (_) => _Particle());
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The card with animated gold border
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final borderProgress = (_controller.value * 2.5).clamp(0.0, 1.0);
            final glowProgress = _controller.value < 0.5
                ? (_controller.value * 2.0)
                : (1.0 - (_controller.value - 0.5) * 1.0).clamp(0.0, 1.0);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: _hasPlayed
                    ? Border.all(
                        color: HelloColors.gold.withValues(alpha: borderProgress * 0.8),
                        width: 2,
                      )
                    : null,
                boxShadow: _hasPlayed
                    ? [
                        BoxShadow(
                          color: HelloColors.gold.withValues(alpha: glowProgress * 0.3),
                          blurRadius: 20 + glowProgress * 10,
                          spreadRadius: glowProgress * 4,
                        ),
                      ]
                    : [],
              ),
              child: widget.child,
            );
          },
        ),

        // Particle layer
        if (_hasPlayed)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  if (_controller.value >= 1.0) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
