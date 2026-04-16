import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The app has three top-level tabs as of 2026-04-15:
/// - Home  (cosmos floating-avatar surface)
/// - Chats (iMessage-style merged DMs + Groups list)
/// - Plans (focus trip + trip list)
///
/// The prior `groups` variant was removed when Chats absorbed
/// Groups into a single unified conversation list.
enum HomeTab { home, chats, plans }

extension HomeTabDisplay on HomeTab {
  /// Title-case display label. Used by ValueKeys + headers. Not
  /// ALL-CAPS — Apple-style 2030 surfaces read Title Case across
  /// nav chrome.
  String get label => switch (this) {
        HomeTab.home => 'Home',
        HomeTab.chats => 'Chats',
        HomeTab.plans => 'Plans',
      };

  /// Alias for [label] — kept for semantic sites that historically
  /// used `titleCase` to distinguish from the older ALL-CAPS `label`.
  String get titleCase => label;

  String get searchHint => switch (this) {
        HomeTab.home => 'Search or a name…',
        HomeTab.chats => 'Search conversations…',
        HomeTab.plans => 'Search plans…',
      };

  Color get signatureColor => switch (this) {
        HomeTab.home => const Color(0xFF7C3AED),
        HomeTab.chats => const Color(0xFF8B5CF6),
        HomeTab.plans => const Color(0xFF4A90E2),
      };

  IconData get icon => switch (this) {
        HomeTab.home => Icons.home_rounded,
        HomeTab.chats => Icons.chat_bubble_outline_rounded,
        HomeTab.plans => Icons.map_outlined,
      };
}

/// The active tab index. Updated by a TabController listener in
/// decision_board_page.dart.
final activeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Derived HomeTab enum from the index.
final activeTabProvider = Provider<HomeTab>((ref) {
  final index = ref.watch(activeTabIndexProvider);
  return HomeTab.values[index.clamp(0, HomeTab.values.length - 1)];
});

/// Live fractional tab position (0.0 — 2.0) during a TabBarView
/// drag. Updated on every frame by a listener on
/// `TabController.animation` in decision_board_page.dart. Consumed
/// by the atmosphere and the ghost-indicator to lerp smoothly
/// across tab signature colors as the user swipes.
final tabAnimationProvider = StateProvider<double>((ref) => 0.0);
