import 'package:flutter/material.dart';

class HelloColors {
  static const Color voidBg = Color(0xFF050507);
  static const Color surfaceDeep = Color(0xFF0A0A0E);
  static const Color accent = Color(0xFFFF385C); // Rausch (Airbnb)
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
