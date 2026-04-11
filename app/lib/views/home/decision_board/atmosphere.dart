// Home atmosphere — ambient mesh that shifts with the current focus.
//
// The primary blob color is driven by [focusTripProvider]. Swiss →
// alpine blue, Goa → ocean teal, Bali → sunset amber, no focus →
// default deep violet.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';

const Color _defaultPrimary = Color(0xFF7C3AED); // deep violet
const Color _teal = Color(0xFF14B8A6);
const Color _rose = Color(0xFFD4536B);
const Color _gold = Color(0xFFC8A84E);

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
    final primary = focus?.accentColor ?? _defaultPrimary;

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
              // Base wash — subtle violet undercoat
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
              // Focus-tinted blob — top left
              Positioned(
                left: -60 + dx1,
                top: -80 + dy1,
                width: 560,
                height: 460,
                child: _BlurBlob(color: primary, opacity: 0.22),
              ),
              // Teal accent — right mid
              Positioned(
                right: -80 + dx2,
                top: 200 + dy2,
                width: 500,
                height: 460,
                child: const _BlurBlob(color: _teal, opacity: 0.10),
              ),
              // Rose accent — bottom left
              Positioned(
                left: -100 - dx1,
                bottom: -60 - dy1,
                width: 520,
                height: 420,
                child: const _BlurBlob(color: _rose, opacity: 0.08),
              ),
              // Gold accent — center bottom
              Positioned(
                left: 40,
                right: 40,
                bottom: -140 + dy2.abs(),
                height: 380,
                child: const _BlurBlob(color: _gold, opacity: 0.06),
              ),
              // Grain overlay
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
