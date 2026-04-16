import 'package:flutter/material.dart';

class HelloSemantics extends StatelessWidget {
  const HelloSemantics({
    super.key,
    required this.label,
    this.hint,
    this.isButton = false,
    this.isHeader = false,
    required this.child,
  });

  final String label;
  final String? hint;
  final bool isButton;
  final bool isHeader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      header: isHeader,
      child: child,
    );
  }
}
