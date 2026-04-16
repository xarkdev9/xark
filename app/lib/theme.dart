import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Brightness-aware color tokens. Auto-detects platform brightness
/// via SchedulerBinding (non-widget-context-dependent). All getters
/// return the light or dark variant based on [isDark].
class HelloColors {
  HelloColors._();

  // ── Brightness detection ──────────────────────────────────────
  static bool _isDark = false;

  /// Read the current brightness. Updated by HelloApp.didChangeDependencies
  /// via [updatePlatformBrightness()].
  static bool get isDark => _isDark;

  /// Call once per frame from the root widget's didChangeDependencies:
  ///   HelloColors.updatePlatformBrightness(
  ///     MediaQuery.platformBrightnessOf(context));
  static void updatePlatformBrightness([Brightness? b]) {
    final brightness = b ??
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    _isDark = brightness == Brightness.dark;
  }

  // ── Core surfaces (brightness-aware) ──────────────────────────
  static Color get voidBg =>
      _isDark ? const Color(0xFF111111) : Color(0xFFFAFAFA);
  static Color get surfaceDeep =>
      _isDark ? const Color(0xFF1C1C1E) : Color(0xFFFFFFFF);
  static Color get recessed =>
      _isDark ? const Color(0xFF2C2C2E) : Color(0xFFF0F0F0);
  static Color get chrome =>
      _isDark ? const Color(0xFF1C1C1E) : Color(0xFFF0EFF4);
  static const Color white = Color(0xFFFFFFFF);

  // Brand / accent — Liquid Plasma representative hue (flat fallback).
  static const Color accent = Color(0xFFFF4D00);

  // Focus trip accents
  static const Color focusViolet = Color(0xFF7C3AED);
  static const Color focusAlpine = Color(0xFF4A90E2);
  static const Color focusOcean = Color(0xFF14B8A6);
  static const Color focusSunset = Color(0xFFFF9B6E);

  // Status
  static Color get liveGreen =>
      _isDark ? const Color(0xFF34D399) : Color(0xFF047857);
  static Color get gold =>
      _isDark ? const Color(0xFFFBBF24) : Color(0xFF8B6914);
  static Color get error =>
      _isDark ? const Color(0xFFEF4444) : Color(0xFFC43D08);
  static Color get pulse =>
      _isDark ? const Color(0xFFFF6B6B) : Color(0xFFFF385C);

  static const Color scoreHigh = Color(0xFF047857);
  static const Color scoreLow = Color(0xFFC43D08);
  static const Color warmPeach = Color(0xFFFFB38A);

  // Ink (brightness-aware)
  static Color get inkPrimary =>
      _isDark ? const Color(0xFFF5F5F7) : Color(0xFF1A1A1A);
  static Color get inkSecondary =>
      _isDark ? const Color(0xFF98989F) : Color(0xFF6B6B78);
  static Color get inkTertiary =>
      _isDark ? const Color(0xFF636366) : Color(0xFF8A8A94);

  // Backward-compat
  static const Color primary = Color(0xFFD4536B);

  // Kind card-tint colors (low-alpha overlays on CardShell)
  static const Color kindDm = Color(0x0A8B5CF6);
  static const Color kindDmFade = Color(0x058B5CF6);
  static const Color kindGroup = Color(0x0AF97316);
  static const Color kindGroupFade = Color(0x05F97316);
  static const Color kindDecision = Color(0x0AFF4D00);
  static const Color kindDecisionFade = Color(0x05FF4D00);
  static const Color kindSettlement = Color(0x0A8B6914);
  static const Color kindSettlementFade = Color(0x058B6914);
  static const Color kindItinerary = Color(0x0A14B8A6);
  static const Color kindItineraryFade = Color(0x0514B8A6);
  static const Color kindMemory = Color(0x0A7C3AED);
  static const Color kindMemoryFade = Color(0x057C3AED);
  static const Color kindAiNudge = Color(0x0AD4536B);
  static const Color kindAiNudgeFade = Color(0x05D4536B);
  static const Color kindTrip = Color(0x0A4A90E2);
  static const Color kindTripFade = Color(0x054A90E2);
  static const Color kindFocus = Color(0x0A7C3AED);
  static const Color kindFocusFade = Color(0x057C3AED);
  static const Color kindDiscovery = Color(0x0A14B8A6);
  static const Color kindEvent = Color(0x0AF97316);
  static const Color kindPoll = Color(0x0AFF4D00);
  static const Color kindChecklist = Color(0x0A047857);
  static const Color kindBookmark = Color(0x0A8B6914);
}

class HelloText {
  static TextStyle get display => TextStyle(
        fontFamily: 'Inter',
        fontSize: 44,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.03,
        height: 1.1,
        color: HelloColors.inkPrimary,
      );

  static TextStyle get title => TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.02,
        height: 1.2,
        color: HelloColors.inkPrimary,
      );

  static TextStyle get heading => TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.01,
        height: 1.3,
        color: HelloColors.inkPrimary,
      );

  static TextStyle get body => TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: HelloColors.inkPrimary,
      );

  static TextStyle get small => TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: HelloColors.inkPrimary,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w300,
        height: 1.4,
        color: HelloColors.inkSecondary,
      );

  static TextStyle get label => TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.4,
        color: HelloColors.inkTertiary,
      );

  static TextStyle get mono => TextStyle(
        fontFamily: 'SF Mono',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: HelloColors.inkPrimary,
      );
}

/// 3-tier blur hierarchy for glassmorphic surfaces.
class HelloGlass {
  HelloGlass._();

  // Tier 1 — navigation chrome, card surfaces
  static const double whisperSigma = 14;
  static Color get whisperFill =>
      HelloColors.isDark ? const Color(0xB31C1C1E) : Color(0xB3FFFFFF);
  static Color get whisperBorder =>
      HelloColors.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06);

  // Tier 2 — sheet headers/footers, popovers
  static const double veilSigma = 20;
  static Color get veilFill =>
      HelloColors.isDark ? const Color(0xCC1C1C1E) : Color(0xCCFFFFFF);

  // Tier 3 — full-attention modals, sheet bodies
  static const double curtainSigma = 24;
  static Color get curtainFill =>
      HelloColors.isDark ? const Color(0xE61C1C1E) : Color(0xE6FFFFFF);

  // Chat bubble special case
  static const double bubbleOutboundSigma = 20;
  static const double bubbleInboundSigma = 8;

  // Legacy holdovers (pre-tier system) — do not use in new code
  static const Color fill = Color(0x0AFFFFFF);
  static const Color border = Color(0x0FFFFFFF);
  static const double blurRadius = 40.0;
}

/// Theme mode: auto detects from OS, or user picks light/dark.
enum HelloThemeMode { auto, light, dark }
