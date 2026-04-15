import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/ambient_palette.dart';
import '../theme.dart';
import 'focus_sources_provider.dart';

/// The currently active atmospheric palette.
///
/// Derived from `focusSourcesProvider`. If the top source has a
/// `routeAnimation` attached, the palette lerps between the top
/// and underlying sources based on the animation value — enabling
/// 1:1 swipe-back fluidity on iOS/Android edge-swipe dismissals.
final ambientPaletteProvider = Provider<AmbientPalette>((ref) {
  final sources = ref.watch(focusSourcesProvider);
  if (sources.isEmpty) return AmbientPalette.neutral;
  if (sources.length == 1) return sources.first.palette;

  final top = sources.first;
  final underlying = sources[1];

  final anim = top.routeAnimation;
  if (anim != null) {
    return AmbientPalette.lerp(underlying.palette, top.palette, anim.value);
  }
  return top.palette;
});

/// Card surface opacity tier.
///
/// Low risk (muted, near-neutral palette) → Whisper (70% surface)
/// Medium risk → Veil (80% surface)
/// High risk (vivid and luminance-far-from-theme) → Curtain (90% surface)
///
/// Risk = 0.6 × |paletteLuminance − themeNeutralLuminance| + 0.4 × paletteSaturation.
enum AmbientSurfaceTier { whisper, veil, curtain }

final ambientSurfaceTierProvider = Provider<AmbientSurfaceTier>((ref) {
  final palette = ref.watch(ambientPaletteProvider);

  final avgLum = palette.averageRelativeLuminance;
  final avgSat = palette.averageSaturation;

  // Theme's neutral base luminance:
  //   Light theme canvas #FAFAFA ≈ 0.95 relative luminance
  //   Dark theme canvas #111111  ≈ 0.009 relative luminance
  final themeNeutralLum = HelloColors.isDark ? 0.009 : 0.95;
  final luminanceDelta = (avgLum - themeNeutralLum).abs();

  final risk = (luminanceDelta * 0.6) + (avgSat * 0.4);

  if (risk < 0.20) return AmbientSurfaceTier.whisper;
  if (risk < 0.50) return AmbientSurfaceTier.veil;
  return AmbientSurfaceTier.curtain;
});

/// Theme-aware surface colors for each tier.
/// In light mode, blends toward white. In dark mode, blends toward #1C1C1E.
extension AmbientSurfaceTierColors on AmbientSurfaceTier {
  Color get fill {
    final base = HelloColors.isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFFFFFFF);
    final alpha = switch (this) {
      AmbientSurfaceTier.whisper => 0.70,
      AmbientSurfaceTier.veil    => 0.80,
      AmbientSurfaceTier.curtain => 0.90,
    };
    return base.withValues(alpha: alpha);
  }

  Color get border {
    final base = HelloColors.isDark ? Colors.white : Colors.black;
    final alpha = switch (this) {
      AmbientSurfaceTier.whisper => 0.06,
      AmbientSurfaceTier.veil    => 0.10,
      AmbientSurfaceTier.curtain => 0.14,
    };
    return base.withValues(alpha: alpha);
  }
}

// ── Reward Layer 3: Atmosphere pulse ────────────────────────────
//
// A transient modulation applied during an action tap's reward
// sequence. ChromaticAtmosphere reads this signal and adjusts
// saturation/brightness/dither for the duration of the pulse,
// then auto-relaxes back to `none`.

/// A transient modulation applied to the ambient palette during
/// a reward animation. Lasts ~800ms; then the pulse controller
/// emits `AmbientPalettePulse.none` and the atmosphere relaxes
/// back to the base palette.
enum AmbientPalettePulse {
  /// No active pulse — atmosphere renders the base palette as-is.
  none,

  /// Affirmative action (Yes / Love / Works / Pay now) —
  /// saturation +15% over 800ms, then relax.
  affirm,

  /// Soft-negative action (No / Pass / Later) — saturation -15%
  /// + brightness -10% over 800ms, then relax.
  negate,

  /// Hesitant action (Maybe) — dither opacity bump (0.015 → 0.025)
  /// over 800ms, then relax.
  hesitate,
}

class AmbientPalettePulseController
    extends StateNotifier<AmbientPalettePulse> {
  AmbientPalettePulseController() : super(AmbientPalettePulse.none);

  /// Fire a pulse for the standard 800ms duration, then auto-relax
  /// back to `none`. Safe to call while a prior pulse is in flight
  /// — the latest call wins.
  Future<void> pulse(AmbientPalettePulse kind) async {
    state = kind;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (state == kind) state = AmbientPalettePulse.none;
  }
}

final ambientPalettePulseProvider =
    StateNotifierProvider<AmbientPalettePulseController, AmbientPalettePulse>(
  (ref) => AmbientPalettePulseController(),
);
