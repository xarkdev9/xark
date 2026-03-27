import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════
/// HELLO APP - GLOBAL DESIGN TOKENS
/// Strict adherence to:
/// 1. The No-Bold Mandate (Max weight 400)
/// 2. The Zero-Box Doctrine (0px radius by default)
/// ═══════════════════════════════════════════════

class HelloColors {
  // Backgrounds & Surfaces
  static const Color voidBg = Color(0xFFFAFAFA);
  static const Color chrome = Color(0xFFFAFAFA);
  static const Color recessed = Color(0xFFF0F0F0);

  // Ink & Text
  static const Color inkPrimary = Color(0xFF1A1A1A); 
  static const Color inkSecondary = Color(0xFF6B6B78);
  static const Color inkTertiary = Color(0xFF8A8A94);
  static const Color white = Color(0xFFFFFFFF);

  // Accents & Intelligence
  static const Color accent = Color(0xFFFF6B35); // Deep Rose / Searing Orange
  static const Color gold = Color(0xFF8B6914);

  // Status
  static const Color errorOrange = Color(0xFFC43D08);
  static const Color neutralGray = Color(0xFF8A8A94);
  static const Color seekingAmber = Color(0xFF9E6A06);
  static const Color successGreen = Color(0xFF047857);

  // Gradients
  static const LinearGradient liquidFireStandard = LinearGradient(
    colors: [
      Color(0xFF8B2500),
      Color(0xFFFF6B35),
      Color(0xFFFF9F43),
      Color(0xFFFF6B35),
      Color(0xFF8B2500),
    ],
    stops: [0.0, 0.25, 0.50, 0.75, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient liquidFireInvocation = LinearGradient(
    colors: [
      Color(0xFF8B2500),
      Color(0xFFFF6B35),
      Color(0xFFFF9F43),
      Color(0xFFFF6B35),
      Color(0xFF8B2500),
    ],
    stops: [0.0, 0.30, 0.50, 0.80, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class HelloTypography {
  // Note: Ensure 'Inter' and 'Syne' are defined in your pubspec.yaml
  static const String primaryFont = 'Inter';
  static const String displayFont = 'Syne';

  static const TextStyle hero = TextStyle(
    fontFamily: primaryFont,
    fontSize: 26.0, // 1.625rem
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.26, // -0.01em
    color: HelloColors.inkPrimary,
  );

  static const TextStyle spaceTitle = TextStyle(
    fontFamily: primaryFont,
    fontSize: 22.0, // clamp approx
    fontWeight: FontWeight.w400,
    letterSpacing: -0.22, // -0.01em
    color: HelloColors.inkPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: primaryFont,
    fontSize: 17.0, // 1.0625rem
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0.17, // 0.01em
    color: HelloColors.inkPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: primaryFont,
    fontSize: 13.0, // 0.8125rem
    fontWeight: FontWeight.w300,
    height: 1.4,
    letterSpacing: 1.56, // 0.12em
    color: HelloColors.inkSecondary,
  );

  static const TextStyle hint = TextStyle(
    fontFamily: primaryFont,
    fontSize: 13.0, // 0.8125rem
    fontWeight: FontWeight.w300,
    letterSpacing: 1.04, // 0.08em
    color: HelloColors.inkTertiary,
  );
}

class HelloTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: HelloColors.voidBg,
      primaryColor: HelloColors.accent,
      fontFamily: HelloTypography.primaryFont,
      
      // Zero-Box Doctrine Enforcement
      cardTheme: const CardThemeData(
        color: HelloColors.chrome,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, 
        ),
      ),
      
      // Global Text Theme mapping
      textTheme: const TextTheme(
        displayLarge: HelloTypography.hero,
        titleLarge: HelloTypography.spaceTitle,
        bodyLarge: HelloTypography.body,
        labelLarge: HelloTypography.label,
        bodySmall: HelloTypography.hint,
      ),

      // Remove all material splash/ripple effects for a silent, native feel
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }
}
