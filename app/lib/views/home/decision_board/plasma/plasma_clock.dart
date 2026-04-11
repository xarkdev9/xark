import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'plasma_gradient.dart';

/// Owns the single AnimationController that drives every plasma
/// surface in the app. Wrap the app's root widget with this once.
///
/// Exposes the current phase in [0, 1) via a [ValueListenable<double>]
/// published through [PlasmaClockScope]. Every plasma widget reads the
/// same phase so all 28 surfaces animate in unison with one tick per
/// frame.
///
/// Respects [MediaQuery.disableAnimations]: when the system requests
/// reduced motion the controller stops and the phase freezes at 0.5,
/// keeping the plasma colorful but static.
class PlasmaClock extends StatefulWidget {
  final Widget child;
  const PlasmaClock({super.key, required this.child});

  @override
  State<PlasmaClock> createState() => _PlasmaClockState();
}

class _PlasmaClockState extends State<PlasmaClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ValueNotifier<double> _phase;

  @override
  void initState() {
    super.initState();
    _phase = ValueNotifier<double>(0.0);
    _controller = AnimationController(vsync: this, duration: kPlasmaCycle)
      ..addListener(() {
        _phase.value = _controller.value;
      });
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disable = MediaQuery.disableAnimationsOf(context);
    if (disable) {
      if (_controller.isAnimating) _controller.stop();
      _phase.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlasmaClockScope(phase: _phase, child: widget.child);
  }
}

/// InheritedWidget that publishes the plasma phase to descendants.
/// Call [PlasmaClockScope.of] from a plasma widget's `build` method
/// to obtain the shared [ValueListenable<double>].
class PlasmaClockScope extends InheritedWidget {
  final ValueListenable<double> phase;

  const PlasmaClockScope({
    super.key,
    required this.phase,
    required super.child,
  });

  /// Returns the current plasma phase listenable. Asserts that a
  /// [PlasmaClock] ancestor exists.
  static ValueListenable<double> of(BuildContext context) {
    final PlasmaClockScope? scope =
        context.dependOnInheritedWidgetOfExactType<PlasmaClockScope>();
    assert(
      scope != null,
      'PlasmaClockScope.of() called with no PlasmaClock ancestor. '
      'Wrap your app root in a PlasmaClock widget.',
    );
    return scope!.phase;
  }

  @override
  bool updateShouldNotify(covariant PlasmaClockScope old) =>
      old.phase != phase;
}
