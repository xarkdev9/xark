import 'package:flutter/material.dart';

class HelloColors {
  // Light theme — ported from ui_backup_2026-04-10/flutter/theme.dart
  static const Color voidBg = Color(0xFFFAFAFA); // off-white base
  static const Color surfaceDeep = Color(0xFFFFFFFF); // elevated surfaces
  static const Color recessed = Color(0xFFF0F0F0); // subtle gray (chips, avatars)
  static const Color white = Color(0xFFFFFFFF); // explicit white for bubbles

  // Brand / accent (unchanged from dark theme)
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)

  // Focus trip accents (unchanged)
  static const Color focusViolet = Color(0xFF7C3AED);
  static const Color focusAlpine = Color(0xFF4A90E2); // Swiss
  static const Color focusOcean = Color(0xFF14B8A6); // Goa
  static const Color focusSunset = Color(0xFFFF9B6E); // Bali

  static const Color liveGreen = Color(0xFF047857); // darker green for light bg

  static const Color primary = Color(0xFFD4536B); // kept for backward compat

  // Ink — dark text on light backgrounds
  static const Color inkPrimary = Color(0xFF1A1A1A); // near-black
  static const Color inkSecondary = Color(0xFF6B6B78); // medium gray
  static const Color inkTertiary = Color(0xFF8A8A94); // light gray

  static const Color gold = Color(0xFF8B6914); // darker gold for light bg
  static const Color error = Color(0xFFC43D08); // archive error orange
}

class HelloText {
  static const TextStyle display = TextStyle(
    fontFamily: 'Inter',
    fontSize: 44,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.03,
    height: 1.1,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.02,
    height: 1.2,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: HelloColors.inkPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: HelloColors.inkTertiary,
  );
}

// Glassmorphism helper variables
class HelloGlass {
  static const Color fill = Color(0x0AFFFFFF); // 4% white
  static const Color border = Color(0x0FFFFFFF); // 6% white
  static const double blurRadius = 40.0;
}
