import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/ambient_palette.dart';

/// A single focus source in the priority-sorted stack.
///
/// `routeAnimation`, when non-null, enables 1:1 swipe-back cross-fade
/// with the user's gesture (no snap at dismissal).
@immutable
class FocusSource {
  /// Stable identifier (e.g., "dm_sarah", "trip_swiss_jun_2026", "sheet_decision_abc").
  final String id;

  /// The palette this source contributes.
  final AmbientPalette palette;

  /// Priority — higher wins. 100=sheet, 50=detail page, 10=tab feed, 1=tab fallback.
  final int priority;

  /// If non-null, the atmosphere lerps `underlyingPalette → palette` by
  /// `routeAnimation.value`. When 1.0, fully on this source. When 0.0, dismissed.
  final Animation<double>? routeAnimation;

  const FocusSource({
    required this.id,
    required this.palette,
    required this.priority,
    this.routeAnimation,
  });

  FocusSource copyWith({AmbientPalette? palette, Animation<double>? routeAnimation}) {
    return FocusSource(
      id: id,
      palette: palette ?? this.palette,
      priority: priority,
      routeAnimation: routeAnimation ?? this.routeAnimation,
    );
  }
}

/// Priority-sorted stack of focus sources.
/// Use via [focusSourcesProvider].
class FocusSourceStack extends StateNotifier<List<FocusSource>> {
  FocusSourceStack() : super(const []);

  /// Push a new source. If a source with the same id exists, it is replaced.
  void push(FocusSource source) {
    final filtered = state.where((s) => s.id != source.id).toList();
    filtered.add(source);
    filtered.sort((a, b) => b.priority.compareTo(a.priority));
    state = filtered;
  }

  /// Pop the source with the given id.
  void pop(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  /// Update an existing source's palette (e.g., scrolling to a new centered card).
  void update(String id, AmbientPalette palette) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(palette: palette) else s,
    ];
  }

  /// Force a re-emit without mutating state — used by route-animation listeners
  /// to trigger derived-provider re-evaluation as the animation ticks.
  void touch() {
    state = List<FocusSource>.from(state);
  }
}

final focusSourcesProvider =
    StateNotifierProvider<FocusSourceStack, List<FocusSource>>(
  (ref) => FocusSourceStack(),
);
