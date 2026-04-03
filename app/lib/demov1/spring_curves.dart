import 'package:flutter/physics.dart';
import 'package:flutter/animation.dart';

/// Parameterized spring physics for tactile, weighty animations.
/// Replaces all Curves.easeOut with physically-modeled springs.

class SpringCurve extends Curve {
  final double mass;
  final double stiffness;
  final double damping;

  /// Default: snappy response (like iOS)
  const SpringCurve({
    this.mass = 1.0,
    this.stiffness = 500.0,
    this.damping = 25.0,
  });

  /// Bouncy: for message send animation
  static const bouncy = SpringCurve(mass: 1.0, stiffness: 300.0, damping: 15.0);

  /// Snappy: for swipe-to-reply snap-back
  static const snappy = SpringCurve(mass: 1.0, stiffness: 600.0, damping: 30.0);

  /// Gentle: for sheet/modal presentations
  static const gentle = SpringCurve(mass: 1.2, stiffness: 200.0, damping: 20.0);

  /// Heavy: for drag-and-drop with momentum
  static const heavy = SpringCurve(mass: 2.0, stiffness: 400.0, damping: 35.0);

  @override
  double transformInternal(double t) {
    final simulation = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0.0, // start
      1.0, // end
      0.0, // initial velocity
    );
    return simulation.x(t);
  }
}

/// Extension to easily use spring curves on any AnimationController
extension SpringAnimationExtension on AnimationController {
  TickerFuture animateWithSpring({
    SpringCurve curve = const SpringCurve(),
    double? from,
  }) {
    return animateTo(
      1.0,
      duration: const Duration(milliseconds: 600),
      curve: curve,
    );
  }
}
