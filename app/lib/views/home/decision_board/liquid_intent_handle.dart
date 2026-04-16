import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../../../providers/tabs_provider.dart';
import 'plasma/plasma.dart';

enum IntentState { idle, proximity, active }

/// Wraps the scrollable spatial feed and overlays a physics-driven,
/// velocity-aware liquid plasma intent handle. Follows Z-Axis Isolation
/// and Luminous Minimalism doctrines.
class LiquidIntentLayer extends ConsumerStatefulWidget {
  final Widget child;
  
  const LiquidIntentLayer({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<LiquidIntentLayer> createState() => _LiquidIntentLayerState();
}

class _LiquidIntentLayerState extends ConsumerState<LiquidIntentLayer> with SingleTickerProviderStateMixin {
  IntentState _state = IntentState.idle;
  late final AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, lowerBound: 0.0, upperBound: 2.0);
    _controller.value = 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateState(IntentState nextState) {
    if (_state == nextState) return;
    setState(() => _state = nextState);
    
    // 0 = idle, 1 = proximity, 2 = active
    final target = nextState == IntentState.idle
        ? 0.0
        : nextState == IntentState.proximity
            ? 1.0
            : 2.0;

    final simulation = SpringSimulation(
      const SpringDescription(mass: 1.0, stiffness: 300.0, damping: 25.0),
      _controller.value,
      target,
      _controller.velocity,
    );
    _controller.animateWith(simulation);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (notification.scrollDelta != null) {
        // Velocity threshold: if Delta exceeds 8px per 16ms frame (approx 500px/s)
        if (notification.scrollDelta!.abs() > 8) {
          _updateState(IntentState.idle);
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final phase = PlasmaClockScope.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // Layer 0: The Feed (With Passive Velocity Tracking)
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        // Layer 0.5: Invisible Click-Away Interceptor
        // ALWAYS keep in the tree to prevent Stack index shifting which unmounts the intent handle
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Only active/opaque during active phase (>1.0)
              final double opacity = _controller.value > 1.0 ? (_controller.value - 1.0) : 0.0;
              if (opacity == 0.0) return const SizedBox.shrink();

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _updateState(IntentState.idle),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2 * opacity), // Apple-style focus dimming
                ),
              );
            },
          ),
        ),

        // NOTE: Layer 0.6 ("Organic Frost Gradient") was deleted
        // 2026-04-15. It painted a 110-120pt HelloColors.voidBg wash
        // at the bottom of the screen, keyed to a legacy 3-tab layout
        // (Inbox/Home/Plans) where Home was at tabAnimationProvider
        // position 1.0. After the NS3 4-tab scaffold and then the
        // 2026-04-15 Chats+Groups merge (back to a 3-tab Home/Chats/
        // Plans), Home sits at position 0.0 — the formula painted a
        // full-opacity white wash over the ChromaticAtmosphere. The
        // atmosphere now drenches to the bottom edge uniformly.

        // Layer 0.75: Ghost Indicator (Inbox • Home • Plans)
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomSafe > 0 ? bottomSafe + 32 + 24 : 32 + 24, // Sits above the intent handle
          child: const _GhostIndicator(),
        ),
          
        // Layer 1: Isolated Z-Axis Intent Handle
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomSafe > 0 ? bottomSafe + 32 : 32, // Intent Handle Pushed Higher
          child: MouseRegion(
            onEnter: (_) => _updateState(IntentState.proximity),
            onExit: (_) {
              if (_state == IntentState.proximity) {
                _updateState(IntentState.idle);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_state != IntentState.active) {
                  _updateState(IntentState.active);
                }
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null) {
                  if (details.primaryDelta! < -2) {
                    _updateState(IntentState.active); // Drag up -> Active
                  } else if (details.primaryDelta! > 2) {
                    _updateState(IntentState.idle);   // Drag down -> Idle
                  }
                }
              },
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  
                  // Phase 1 (0 to 1): Idle -> Proximity (Width/Height morphing)
                  // Phase 2 (1 to 2): Proximity -> Active (Full Glass Bloom)
                  
                  final width = t <= 1.0 
                      ? lerpDouble(160, 220, t)! 
                      : lerpDouble(220, 360, t - 1.0)!;
                      
                  final height = t <= 1.0 
                      ? lerpDouble(4, 6, t)! 
                      : lerpDouble(6, 64, t - 1.0)!;
                      
                  final radius = t <= 1.0 
                      ? lerpDouble(2, 3, t)! 
                      : lerpDouble(3, 42, t - 1.0)!;
                      
                  final opacity = t <= 1.0 
                      ? lerpDouble(0.6, 1.0, t)! 
                      : 1.0;

                  // Active content fades in synchronously with the glass bloom
                  final contentOpacity = t <= 1.0 ? 0.0 : (t - 1.0);

                  final shape = ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(radius * 1.5), 
                  );
                  final activeShape = ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(radius * 1.5), 
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  );

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        fit: StackFit.expand,
                        children: [
                           // 1. Opaque Liquid Plasma Core
                           Opacity(
                             opacity: opacity,
                             child: ListenableBuilder(
                               listenable: phase,
                               builder: (context, _) {
                                 return DecoratedBox(
                                   decoration: ShapeDecoration(
                                     shape: shape,
                                     gradient: buildPlasmaGradient(phase.value, alpha: 1.0),
                                   ),
                                 );
                               },
                             ),
                           ),
                           
                           // 2. Translucent Glass Shell & UI Overlay (Only paints when Blooming)
                           if (t > 1.0)
                             Opacity(
                               opacity: contentOpacity,
                               child: ClipPath(
                                 clipper: ShapeBorderClipper(shape: shape),
                                 child: DecoratedBox(
                                     decoration: ShapeDecoration(
                                       shape: activeShape,
                                       color: Colors.white.withValues(alpha: 0.75),
                                     ),
                                     child: _ActiveContent(
                                       opacity: contentOpacity, 
                                       onClose: () => _updateState(IntentState.idle),
                                     ),
                                   ),
                                 ),
                             ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveContent extends StatelessWidget {
  final double opacity;
  final VoidCallback onClose;

  const _ActiveContent({required this.opacity, required this.onClose});

  @override
  Widget build(BuildContext context) {
     return Padding(
       padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.center,
         children: [
            const SizedBox(width: 4),
            Expanded(
              child: Opacity(
                opacity: opacity,
                child: TextField(
                  cursorHeight: 18,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(2),
                  cursorColor: HelloColors.accent,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: HelloColors.inkPrimary,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or ask...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: HelloColors.inkTertiary,
                      height: 1.2,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_none_rounded, size: 18, color: HelloColors.inkSecondary),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Icon(Icons.add_rounded, size: 20, color: HelloColors.pulse),
            ),
         ],
       ),
      );
  }
}

class _GhostIndicator extends ConsumerWidget {
  const _GhostIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // tabAnimationProvider is 0.0 to 2.0 (Inbox -> Home -> Plans)
    final animValue = ref.watch(tabAnimationProvider);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GhostDot(label: 'Home', isActive: animValue < 0.5),
        const SizedBox(width: 12),
        _GhostDot(
          label: 'Chats',
          isActive: animValue >= 0.5 && animValue <= 1.5,
        ),
        const SizedBox(width: 12),
        _GhostDot(label: 'Plans', isActive: animValue > 1.5),
      ],
    );
  }
}

class _GhostDot extends StatelessWidget {
  final String label;
  final bool isActive;
  const _GhostDot({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isActive ? 0.8 : 0.3,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isActive ? 1.0 : 0.8,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 2.0,
            color: HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
