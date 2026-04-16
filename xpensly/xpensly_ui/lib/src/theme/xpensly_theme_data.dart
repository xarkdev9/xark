import 'package:flutter/material.dart';

/// Visual configuration for all Xpensly widgets.
///
/// Ships with three presets: [hello], [material], and [minimal].
/// Pass a custom instance to [XpenslyTheme] to fully control the look.
class XpenslyThemeData {
  final Color primary;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color positive; // "you're owed" green
  final Color negative; // "you owe" orange/red
  final Color neutral; // settled/even gray
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle captionStyle;
  final TextStyle amountStyle; // tabular figures for money
  final BorderRadius cardRadius;
  final double cardElevation;

  const XpenslyThemeData({
    required this.primary,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.titleStyle,
    required this.bodyStyle,
    required this.captionStyle,
    required this.amountStyle,
    required this.cardRadius,
    this.cardElevation = 0,
  });

  /// hello app aesthetic — dark, atmospheric, cyan accent.
  static XpenslyThemeData hello() => XpenslyThemeData(
        primary: const Color(0xFF00D4FF),
        surface: const Color(0xFF1A1A2E),
        background: const Color(0xFF0D0D1A),
        textPrimary: const Color(0xFFE0E0E0),
        textSecondary: const Color(0xFF808080),
        positive: const Color(0xFF4CAF50),
        negative: const Color(0xFFFF6B35),
        neutral: const Color(0xFF808080),
        titleStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.02,
        ),
        bodyStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        captionStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.04,
        ),
        amountStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        cardRadius: BorderRadius.circular(12),
        cardElevation: 0,
      );

  /// Material 3 defaults.
  static XpenslyThemeData material() => XpenslyThemeData(
        primary: const Color(0xFF6750A4),
        surface: Colors.white,
        background: const Color(0xFFFFFBFE),
        textPrimary: const Color(0xFF1C1B1F),
        textSecondary: const Color(0xFF49454F),
        positive: const Color(0xFF2E7D32),
        negative: const Color(0xFFC62828),
        neutral: const Color(0xFF757575),
        titleStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        bodyStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        captionStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        amountStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        cardRadius: BorderRadius.circular(16),
        cardElevation: 1,
      );

  /// Ultra-clean minimal.
  static XpenslyThemeData minimal() => XpenslyThemeData(
        primary: const Color(0xFF000000),
        surface: Colors.white,
        background: Colors.white,
        textPrimary: const Color(0xFF111111),
        textSecondary: const Color(0xFF999999),
        positive: const Color(0xFF34A853),
        negative: const Color(0xFFEA4335),
        neutral: const Color(0xFFBDBDBD),
        titleStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        bodyStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        captionStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w300,
        ),
        amountStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        cardRadius: BorderRadius.circular(8),
        cardElevation: 0,
      );
}
