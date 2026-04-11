// Home atmosphere — ambient mesh, grain.
//
// These are atmospheric layers that give the screen depth without
// creating any visible containers. Everything fades to transparent.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen ambient mesh background — slowly drifts.
/// Creates the "cinematic dark + mesh" feel from DESIGN.md.
class AmbientMesh extends StatefulWidget {
  const AmbientMesh({super.key});

  @override
  State<AmbientMesh> createState() => _AmbientMeshState();
}

class _AmbientMeshState extends State<AmbientMesh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final dx1 = math.sin(t * 2 * math.pi) * 24;
        final dy1 = math.cos(t * 2 * math.pi) * 32;
        final dx2 = math.cos(t * 2 * math.pi) * 30;
        final dy2 = math.sin(t * 2 * math.pi) * 22;

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Rausch glow — top left
              Positioned(
                left: -40 + dx1,
                top: -60 + dy1,
                width: 520,
                height: 420,
                child: const _BlurBlob(color: Color(0xFFFF385C), opacity: 0.14),
              ),
              // Teal glow — right mid
              Positioned(
                right: -60 + dx2,
                top: 180 + dy2,
                width: 460,
                height: 420,
                child: const _BlurBlob(color: Color(0xFF14B8A6), opacity: 0.09),
              ),
              // Pink glow — bottom left
              Positioned(
                left: -80 - dx1,
                bottom: -40 - dy1,
                width: 500,
                height: 400,
                child: const _BlurBlob(color: Color(0xFFF472B6), opacity: 0.06),
              ),
              // Gold glow — center bottom
              Positioned(
                left: 40,
                right: 40,
                bottom: -120 + dy2.abs(),
                height: 380,
                child: const _BlurBlob(color: Color(0xFFC8A84E), opacity: 0.07),
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

/// Grain texture painted with a noise-ish pattern.
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
    final rng = math.Random(42); // deterministic
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


