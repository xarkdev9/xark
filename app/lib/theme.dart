import 'package:flutter/material.dart';

class HelloColors {
  static const Color voidBg = Color(0xFF050507);
  static const Color surfaceDeep = Color(0xFF0A0A0E);
  static const Color recessed = Color(0xFF17171C); // flat avatar / chip bg
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)
  static const Color focusViolet = Color(0xFF7C3AED); // default focus tint
  static const Color focusAlpine = Color(0xFF4A90E2); // Swiss
  static const Color focusOcean = Color(0xFF14B8A6); // Goa
  static const Color focusSunset = Color(0xFFFF9B6E); // Bali
  static const Color liveGreen = Color(0xFF10B981); // LIVE EVENT tag
  static const Color primary = Color(0xFFD4536B); // Deep Rose / Liquid Fire
  static const Color inkPrimary = Color(0xFFF0EFF4);
  static const Color inkSecondary = Color(0x8CF0EFF4); // 55% opacity
  static const Color inkTertiary = Color(0x47F0EFF4); // 28% opacity
  static const Color gold = Color(0xFFC8A84E);
  static const Color error = Color(0xFFFF6B8A);
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
