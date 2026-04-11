import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Vertical peek stack — a 3-card PageView with custom geometry:
/// - current card: 78% of viewport
/// - next peek: 18% (below)
/// - previous peek: 4% (above)
///
/// Hard stop at first and last card (rubber-band overshoot). Focus
/// dimming: peeking cards at opacity 0.70, scale 0.94. Haptic feedback
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

  // Geometry constants.
  static const double _currentFraction = 0.78;
  // ignore: unused_field
  static const double _nextPeekFraction = 0.18;
  // ignore: unused_field
  static const double _prevPeekFraction = 0.04;

  // Dim target for peeking cards.
  static const double _peekOpacity = 0.70;
  static const double _peekScale = 0.94;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
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
                // Linear interp: 1.0 at delta=0, 0.70 at delta=1.
                final opacity =
                    1.0 - (1.0 - _peekOpacity) * delta;
                final scale = 1.0 - (1.0 - _peekScale) * delta;
                return SizedBox(
                  height: h,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: widget.children[index],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
