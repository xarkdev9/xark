// Contextual top-left header.
//
// Home tab  → floating user avatar ("R")
// Chats tab → "Chats" large title
// Plans tab → "Plans" large title
//
// Crossfades (220ms ease-out) between the two states when the
// active tab changes, so the header reads as a single living
// element, not as jumping chrome.
//
// The Groups tab was merged into Chats on 2026-04-15 — no
// separate Groups header remains.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'floating_avatar.dart';

class TabHeader extends ConsumerWidget {
  const TabHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(activeTabProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.12),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: tab == HomeTab.home
          ? const SizedBox(
              key: ValueKey<String>('header_avatar'),
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FloatingAvatar(),
              ),
            )
          : SizedBox(
              key: ValueKey<String>('header_title_${tab.label}'),
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tab.titleCase,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.5,
                    color: HelloColors.inkPrimary,
                    height: 1.0,
                  ),
                ),
              ),
            ),
    );
  }
}
