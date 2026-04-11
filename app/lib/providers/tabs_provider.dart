import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum HomeTab { home, chats, groups, plans }

extension HomeTabDisplay on HomeTab {
  String get label => switch (this) {
    HomeTab.home => 'HOME',
    HomeTab.chats => 'CHATS',
    HomeTab.groups => 'GROUPS',
    HomeTab.plans => 'PLANS',
  };

  String get titleCase => switch (this) {
    HomeTab.home => 'Home',
    HomeTab.chats => 'Chats',
    HomeTab.groups => 'Groups',
    HomeTab.plans => 'Plans',
  };

  String get searchHint => switch (this) {
    HomeTab.home => 'Search or a name…',
    HomeTab.chats => 'Search chats or a name…',
    HomeTab.groups => 'Search groups…',
    HomeTab.plans => 'Search plans…',
  };

  Color get signatureColor => switch (this) {
    HomeTab.home => const Color(0xFF7C3AED),
    HomeTab.chats => const Color(0xFF8B5CF6),
    HomeTab.groups => const Color(0xFFF97316),
    HomeTab.plans => const Color(0xFF4A90E2),
  };

  IconData get icon => switch (this) {
    HomeTab.home => Icons.home_rounded,
    HomeTab.chats => Icons.chat_bubble_outline_rounded,
    HomeTab.groups => Icons.people_outline_rounded,
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
