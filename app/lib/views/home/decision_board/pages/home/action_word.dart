import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../../plasma/plasma.dart';

/// A single action word rendered as text-as-action.
///
/// - Word IS the button. No container, no edge, no rounded rect.
/// - Hit zone claims the full parent (Expanded slot) via an internal
///   transparent-fill Container — GestureDetector(opaque) then covers
///   the entire slot edge-to-edge, eliminating dead zones between
///   siblings (v2-review Patch #5).
/// - On approach (pressDown for touch; hover on web/desktop):
///   the atmosphere behind the word brightens via a shapeless
///   RadialGradient — alpha tapers to 0 at ~60pt radius. No visible
///   edge — reads as warm light behind frosted glass.
/// - On tap: PlasmaTint sweeps through the letters. Single
///   ShaderMask layer (no nesting — avoids double-saveLayer).
/// - FittedBox(scaleDown) as a sub-320pt safety net; single-word
///   copy fits 26pt on any phone viewport.
class ActionWord extends StatefulWidget {
  final String word;
  final VoidCallback onTap;

  const ActionWord({
    super.key,
    required this.word,
    required this.onTap,
  });

  @override
  State<ActionWord> createState() => _ActionWordState();
}

class _ActionWordState extends State<ActionWord>
    with SingleTickerProviderStateMixin {
  bool _approaching = false;
  late final AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _approaching = true);
  }

  void _handleTapUp(TapUpDetails _) {
    _tapController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _approaching = false);
    });
    widget.onTap();
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _approaching = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      // Transparent-fill Container forces the GestureDetector to claim
      // the full Expanded slot (its parent's tight constraints) rather
      // than shrinking to the text's visual bounds. Eliminates dead-zone
      // taps in the space between words (v2-review Patch #5).
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Approach glow — shapeless radial, no edge
            if (_approaching)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 0.35,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 120,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          HelloColors.accent.withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                        radius: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
            // The word itself — plasma sweep through letters on tap
            AnimatedBuilder(
              animation: _tapController,
              builder: (ctx, _) {
                final tapping = _tapController.value > 0.0;
                final text = FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.word,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: HelloColors.inkPrimary,
                      height: 1.0,
                    ),
                  ),
                );
                if (!tapping) return text;
                // Plasma sweep — single ShaderMask (via PlasmaTint)
                // fills the letters themselves. One layer, one
                // saveLayer, no nesting.
                return PlasmaTint(child: text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
