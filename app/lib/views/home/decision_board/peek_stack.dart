import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Horizontal peek stack — a 3-card PageView where the active card
/// occupies 78% of viewport width and the prev/next cards peek from
/// the left/right edges.
///
/// Each card gets an Apple Liquid Glass surface (soft blur + low-alpha
/// fill + hairline rim) so the card is clearly visible against the
/// ambient mesh background.
///
/// Hard stop at first and last card (rubber-band overshoot). Focus
/// dimming: peeking cards at opacity 0.62, scale 0.92. Haptic feedback
/// on snap.
///
/// Accepts exactly 3 children.
class PeekStackPageView extends StatefulWidget {
  final List<Widget> children;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  const PeekStackPageView({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.onIndexChanged,
  }) : assert(
          children.length == 3,
          'PeekStackPageView expects exactly 3 children',
        );

  @override
  State<PeekStackPageView> createState() => _PeekStackPageViewState();
}

class _PeekStackPageViewState extends State<PeekStackPageView> {
  late final PageController _controller;

  // Active card fills 78% of viewport; ~11% peek on each side.
  static const double _currentFraction = 0.78;

  // Dim target for peeking cards.
  static const double _peekOpacity = 0.62;
  static const double _peekScale = 0.92;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: _currentFraction,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePageChanged(int idx) {
    HapticFeedback.lightImpact();
    widget.onIndexChanged?.call(idx);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: widget.children.length,
      onPageChanged: _handlePageChanged,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            double page;
            if (_controller.position.haveDimensions) {
              page = _controller.page ?? widget.initialIndex.toDouble();
            } else {
              page = widget.initialIndex.toDouble();
            }
            final delta = (index - page).abs().clamp(0.0, 1.0);
            final opacity = 1.0 - (1.0 - _peekOpacity) * delta;
            final scale = 1.0 - (1.0 - _peekScale) * delta;
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 32, 6, 40),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: _GlassCardSurface(child: widget.children[index]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Apple Liquid Glass surface for each peek-stack card.
///
/// Renders as: backdrop blur → low-alpha gradient fill →
/// 1px hairline rim at 10% white → 28px rounded radius.
/// No hard shadows — depth comes from the blur + rim alone.
class _GlassCardSurface extends StatelessWidget {
  final Widget child;
  const _GlassCardSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
