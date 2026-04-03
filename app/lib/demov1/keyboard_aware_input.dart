import 'package:flutter/material.dart';

/// Chat input that is physically bound to the keyboard edge at 120hz.
/// Uses MediaQuery.viewInsets (not resizeToAvoidBottomInset) for
/// pixel-perfect tracking as the keyboard slides up.

class KeyboardAwareInput extends StatefulWidget {
  final Widget child;
  const KeyboardAwareInput({super.key, required this.child});

  @override
  State<KeyboardAwareInput> createState() => _KeyboardAwareInputState();
}

class _KeyboardAwareInputState extends State<KeyboardAwareInput>
    with WidgetsBindingObserver {
  double _keyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final newInsets = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (newInsets != _keyboardHeight) {
      setState(() => _keyboardHeight = newInsets);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: _keyboardHeight),
      duration: const Duration(milliseconds: 0), // Instant — no animation delay
      child: widget.child,
    );
  }
}
