import 'package:flutter/services.dart';

/// Semantic haptic feedback. Named by user intent, not engine level.
class HelloHaptic {
  static void tap() => HapticFeedback.lightImpact();
  static void confirm() => HapticFeedback.mediumImpact();
  static void celebrate() => HapticFeedback.heavyImpact();
  static void select() => HapticFeedback.selectionClick();
  static void warning() => HapticFeedback.mediumImpact();
}
