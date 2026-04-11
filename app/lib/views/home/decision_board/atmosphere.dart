// Home atmosphere — light focus-tinted wash.
//
// Off-white base (#FAFAFA) with a very faint radial wash in the
// current focus trip's accent color. Lerps smoothly during tab
// swipes via [tabAnimationProvider]. Preserves the "living field"
// concept in a light-appropriate way: you feel the background
// shift more than you see it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/tabs_provider.dart';
import '../../../providers/viewport_focus_provider.dart';

const Color _base = Color(0xFFFAFAFA);
const Color _defaultPrimary = Color(0xFF7C3AED);
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

Color _primaryForTabAnimation(double value) {
  final clamped = value.clamp(0.0, HomeTab.values.length - 1.0);
  final lowerIndex = clamped.floor();
  final upperIndex = (lowerIndex + 1).clamp(0, HomeTab.values.length - 1);
  final t = clamped - lowerIndex;
  final lower = HomeTab.values[lowerIndex].signatureColor;
  final upper = HomeTab.values[upperIndex].signatureColor;
  return Color.lerp(lower, upper, t) ?? lower;
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
    final tabAnimation = ref.watch(tabAnimationProvider);

    final tabColor = _primaryForTabAnimation(tabAnimation);
    final primary = tabColor != HomeTab.values[0].signatureColor
        ? tabColor
        : (_primaryForKind(centeredKind) ??
            focus?.accentColor ??
            _defaultPrimary);

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
              const ColoredBox(color: _base),
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
                    return _LightBlob(
                      color: color ?? primary,
                      opacity: 0.08,
                    );
                  },
                ),
              ),
              Positioned(
                right: -80 + dx2,
                top: 200 + dy2,
                width: 500,
                height: 460,
                child: const _LightBlob(color: _teal, opacity: 0.04),
              ),
              Positioned(
                left: -100 - dx1,
                bottom: -60 - dy1,
                width: 520,
                height: 420,
                child: const _LightBlob(color: _rose, opacity: 0.03),
              ),
              Positioned(
                left: 40,
                right: 40,
                bottom: -140 + dy2.abs(),
                height: 380,
                child: const _LightBlob(color: _gold, opacity: 0.025),
              ),
              const Positioned(
                right: -80,
                top: -80,
                width: 400,
                height: 400,
                child: _LightBlob(
                  color: Colors.white,
                  opacity: 0.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LightBlob extends StatelessWidget {
  final Color color;
  final double opacity;
  const _LightBlob({required this.color, required this.opacity});

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
