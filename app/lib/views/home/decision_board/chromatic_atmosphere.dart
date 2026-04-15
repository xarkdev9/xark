// Chromatic Atmosphere — living surface renderer.
//
// Replaces the legacy AmbientMesh. Full-bleed, content-responsive,
// theme-aware, idle-sleeping, OLED-dithered background.
//
// Reads: ambientPaletteProvider (global content palette)
// Respects: MediaQuery.disableAnimationsOf (reduced motion)
//           WidgetsBindingObserver (app lifecycle)
//           pointer/scroll activity (idle sleep after 3s)
//
// See docs/superpowers/specs/2026-04-14-chromatic-atmosphere-design.md

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ambient_palette.dart';
import '../../../providers/ambient_palette_provider.dart';
import '../../../theme.dart';

/// Density hint — passed via InheritedWidget from each screen.
/// List pages use `dense` (saturation × 0.6). Detail pages use `focus` (× 1.0).
enum AtmosphereDensity { dense, focus }

class AtmosphereDensityScope extends InheritedWidget {
  final AtmosphereDensity density;
  const AtmosphereDensityScope({
    super.key,
    required this.density,
    required super.child,
  });

  static AtmosphereDensity of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AtmosphereDensityScope>();
    return scope?.density ?? AtmosphereDensity.focus;
  }

  @override
  bool updateShouldNotify(AtmosphereDensityScope old) => old.density != density;
}

/// Full-bleed living atmosphere. Place as the FIRST child of a Stack
/// wrapping the scaffold body.
class ChromaticAtmosphere extends ConsumerStatefulWidget {
  const ChromaticAtmosphere({super.key});

  @override
  ConsumerState<ChromaticAtmosphere> createState() => _ChromaticAtmosphereState();
}

class _ChromaticAtmosphereState extends ConsumerState<ChromaticAtmosphere>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Drift — slow background motion (20s cycle). Pauses when idle.
  late final AnimationController _drift;

  // Cross-fade — 800ms tween when palette changes.
  late final AnimationController _crossfade;

  AmbientPalette? _current;
  AmbientPalette? _previous;

  // Idle sleep — drift pauses after 3s of no user activity.
  Timer? _idleTimer;
  static const Duration _idleThreshold = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _crossfade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    WidgetsBinding.instance.addObserver(this);
    _armIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    _crossfade.dispose();
    super.dispose();
  }

  // ── Idle sleep ────────────────────────────────────────────────

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleThreshold, () {
      if (mounted && _drift.isAnimating) _drift.stop();
    });
  }

  void _onUserActivity() {
    if (!_drift.isAnimating) _drift.repeat();
    _armIdleTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _drift.stop();
      _idleTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _drift.repeat();
      _armIdleTimer();
    }
  }

  // ── Cross-fade on palette change ──────────────────────────────

  void _handlePaletteChange(AmbientPalette next) {
    if (_current == null) {
      _current = next;
      return;
    }
    if (next == _current) return;

    _previous = _current;
    _current = next;

    // Reduced motion → snap
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _crossfade.value = 1.0;
      setState(() {});
      return;
    }

    _crossfade
      ..reset()
      ..animateTo(1.0, curve: Curves.easeInOutCubic);

    // Wake drift — palette change = new content = greet the user
    _onUserActivity();
  }

  AmbientPalette get _displayPalette {
    if (_current == null) return AmbientPalette.neutral;
    if (_previous == null) return _current!;
    if (_crossfade.value >= 1.0) return _current!;
    return AmbientPalette.lerp(_previous!, _current!, _crossfade.value);
  }

  Alignment _driftedCenter(int index, double t) {
    final phase = t * 2 * math.pi + index * (2 * math.pi / 5);
    const baseX = [-0.5, 0.3, 0.7, -0.2, 0.0];
    const baseY = [-0.3, -0.5, 0.2, 0.5, 0.1];
    return Alignment(
      baseX[index] + 0.2 * math.sin(phase),
      baseY[index] + 0.2 * math.cos(phase * 0.7),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to palette changes — triggers _handlePaletteChange
    ref.listen<AmbientPalette>(ambientPaletteProvider, (prev, next) {
      _handlePaletteChange(next);
    });
    // Also seed _current on first build
    final initialPalette = ref.watch(ambientPaletteProvider);
    _current ??= initialPalette;

    final density = AtmosphereDensityScope.of(context);
    final saturationMultiplier = density == AtmosphereDensity.dense ? 0.6 : 1.0;

    // Reward Layer 3 — transient pulse modulation.
    // affirm   → saturation ×1.15
    // negate   → saturation ×0.85, brightness ×0.90 (dims glow alpha)
    // hesitate → dither opacity 0.015 → 0.025
    final pulse = ref.watch(ambientPalettePulseProvider);
    final pulseSat = switch (pulse) {
      AmbientPalettePulse.affirm => 1.15,
      AmbientPalettePulse.negate => 0.85,
      _ => 1.0,
    };
    final pulseBrightness =
        pulse == AmbientPalettePulse.negate ? 0.90 : 1.0;
    final ditherOpacity =
        pulse == AmbientPalettePulse.hesitate ? 0.025 : 0.015;
    final effectiveAlpha =
        0.40 * saturationMultiplier * pulseSat * pulseBrightness;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      onPointerMove: (_) => _onUserActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _onUserActivity();
          return false;
        },
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_drift, _crossfade]),
            builder: (context, _) {
              final palette = _displayPalette;
              final colors = palette.colors;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Canvas base (brightness-aware)
                  ColoredBox(color: HelloColors.voidBg),

                  // 5 radial gradients — one per palette color.
                  // Alpha folds in density (0.6/1.0) + reward pulse
                  // (affirm 1.15 / negate 0.85 / none 1.0) + brightness
                  // (negate 0.90 / else 1.0).
                  for (var i = 0; i < 5; i++)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: _driftedCenter(i, _drift.value),
                            radius: 0.9,
                            colors: [
                              colors[i].withValues(alpha: effectiveAlpha),
                              colors[i].withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // OLED dither overlay — 1.5% opacity noise breaks banding.
                  // Bumps to 2.5% during Maybe (hesitate) pulse.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: ditherOpacity,
                        child: Image.asset(
                          'assets/textures/dither_noise.png',
                          repeat: ImageRepeat.repeat,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
