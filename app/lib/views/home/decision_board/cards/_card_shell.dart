import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/viewport_focus_provider.dart';

/// Kind-specific gradient overlays. Painted on top of the glass
/// base fill, below the card content. Low alpha so the card stays
/// readable and the brand-color restraint rule holds (Rausch only
/// in unread dots, live tags, and action buttons — never in these
/// overlays).
class CardKindGradients {
  const CardKindGradients._();

  static const LinearGradient dm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2B8B5CF6), Color(0x143B82F6), Color(0x00000000)],
  );
  static const LinearGradient group = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2BF97316), Color(0x14EC4899), Color(0x00000000)],
  );
  static const LinearGradient decision = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2B10B981), Color(0x1406B6D4), Color(0x00000000)],
  );
  static const LinearGradient settlement = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1EFACC15), Color(0x0E10B981), Color(0x00000000)],
  );
  static const LinearGradient itinerary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2B14B8A6), Color(0x143B82F6), Color(0x00000000)],
  );
  static const LinearGradient memory = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2BFF9B6E), Color(0x14D4536B), Color(0x00000000)],
  );
  static const LinearGradient ai = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2B4A90E2), Color(0x148B5CF6), Color(0x00000000)],
  );
}

/// Glass surface wrapper. Registers a [GlobalKey] in
/// [cardKeyRegistry] so the page's scroll listener can find the
/// card closest to the viewport midline. When focused:
/// - scales to 1.04
/// - lifts 1.2% upward
/// - pulses a 1px white ring at [0.14 → 0.44] opacity over 1s
///
/// When [ambientPulse] is true, a very faint unread-rim pulses
/// even when not focused (opacity [0.06 → 0.16] over 3s).
///
/// Tap gives a quick spring-ish scale dip (1.0 → 0.97 → 1.0).
class CardShell extends ConsumerStatefulWidget {
  final String id;
  final Widget child;
  final Color? accentColor;
  final LinearGradient? kindOverlay;
  final bool ambientPulse;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const CardShell({
    super.key,
    required this.id,
    required this.child,
    this.accentColor,
    this.kindOverlay,
    this.ambientPulse = false,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  ConsumerState<CardShell> createState() => _CardShellState();
}

class _CardShellState extends ConsumerState<CardShell>
    with TickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  late final AnimationController _ringController;
  late final Animation<double> _ringOpacity;
  late final AnimationController _unreadController;
  late final Animation<double> _unreadOpacity;
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    cardKeyRegistry[widget.id] = _key;

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _ringOpacity = Tween<double>(begin: 0.14, end: 0.44).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );

    _unreadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _unreadOpacity = Tween<double>(begin: 0.06, end: 0.16).animate(
      CurvedAnimation(parent: _unreadController, curve: Curves.easeInOut),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant CardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      if (cardKeyRegistry[oldWidget.id] == _key) {
        cardKeyRegistry.remove(oldWidget.id);
      }
      cardKeyRegistry[widget.id] = _key;
    }
  }

  @override
  void dispose() {
    if (cardKeyRegistry[widget.id] == _key) {
      cardKeyRegistry.remove(widget.id);
    }
    _ringController.dispose();
    _unreadController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _tapController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _tapController.reverse();
  }

  void _handleTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = ref.watch(centeredFeedItemIdProvider) == widget.id;
    final rimColor =
        (widget.accentColor ?? Colors.black).withValues(alpha: 0.06);

    return KeyedSubtree(
      key: _key,
      child: AnimatedBuilder(
        animation: _tapScale,
        builder: (context, inner) {
          return Transform.scale(
            scale: _tapScale.value,
            child: inner,
          );
        },
        child: AnimatedScale(
          scale: isFocused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: isFocused ? const Offset(0, -0.012) : Offset.zero,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  onTap: widget.onTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white,
                              border: Border.all(color: rimColor, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: widget.padding,
                              child: widget.child,
                            ),
                          ),
                          if (widget.kindOverlay != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(24),
                                    gradient: widget.kindOverlay,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.ambientPulse && !isFocused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _unreadOpacity,
                        builder: (context, _) {
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFFF385C)
                                    .withValues(alpha: _unreadOpacity.value),
                                width: 1,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (isFocused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ringOpacity,
                        builder: (context, _) {
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.black
                                    .withValues(alpha: _ringOpacity.value * 0.5),
                                width: 1,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
