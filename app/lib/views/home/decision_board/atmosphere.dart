// Home atmosphere — ambient mesh that shifts primary glow based on
// the card the user is currently scrolling through. As each card
// kind comes under the viewport midline, the primary blob lerps
// to that kind's signature color over 450ms.
//
// Fallback cascade: centered kind → focus trip accent → default
// deep violet.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/viewport_focus_provider.dart';

const Color _defaultPrimary = Color(0xFF7C3AED); // deep violet
const Color _teal = Color(0xFF14B8A6);
const Color _rose = Color(0xFFD4536B);
const Color _gold = Color(0xFFC8A84E);

Color? _primaryForKind(String? kind) {
  if (kind == null) return null;
  return switch (kind) {
    'dm' => const Color(0xFF8B5CF6),
    'group' => const Color(0xFFF97316),
    'decision' => const Color(0xFF10B981),
    'trip' => const Color(0xFF4A90E2),
    'settlement' => const Color(0xFFFACC15),
    'itinerary' => const Color(0xFF14B8A6),
    'memory' => const Color(0xFFFF9B6E),
    'ai' => const Color(0xFF4A90E2),
    _ => null,
  };
}

class AmbientMesh extends ConsumerStatefulWidget {
  const AmbientMesh({super.key});

  @override
  ConsumerState<AmbientMesh> createState() => _AmbientMeshState();
}

class _AmbientMeshState extends ConsumerState<AmbientMesh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(focusTripProvider);
    final centeredKind = ref.watch(centeredFeedItemKindProvider);
    final primary = _primaryForKind(centeredKind) ??
        focus?.accentColor ??
        _defaultPrimary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final dx1 = math.sin(t * 2 * math.pi) * 28;
        final dy1 = math.cos(t * 2 * math.pi) * 36;
        final dx2 = math.cos(t * 2 * math.pi) * 34;
        final dy2 = math.sin(t * 2 * math.pi) * 26;

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.5,
                    colors: [
                      Color(0xFF1A0F2E),
                      Color(0xFF0A0814),
                      Color(0xFF050507),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: -60 + dx1,
                top: -80 + dy1,
                width: 560,
                height: 460,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: primary),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, color, _) {
                    return _BlurBlob(
                      color: color ?? primary,
                      opacity: 0.22,
                    );
                  },
                ),
              ),
              Positioned(
                right: -80 + dx2,
                top: 200 + dy2,
                width: 500,
                height: 460,
                child: const _BlurBlob(color: _teal, opacity: 0.10),
              ),
              Positioned(
                left: -100 - dx1,
                bottom: -60 - dy1,
                width: 520,
                height: 420,
                child: const _BlurBlob(color: _rose, opacity: 0.08),
              ),
              Positioned(
                left: 40,
                right: 40,
                bottom: -140 + dy2.abs(),
                height: 380,
                child: const _BlurBlob(color: _gold, opacity: 0.06),
              ),
              const _GrainLayer(),
            ],
          ),
        );
      },
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Color color;
  final double opacity;
  const _BlurBlob({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}

class _GrainLayer extends StatelessWidget {
  const _GrainLayer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GrainPainter(),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();
    final count = (size.width * size.height / 420).round();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = 0.015 + rng.nextDouble() * 0.02;
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
