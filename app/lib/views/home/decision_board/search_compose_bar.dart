import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/viewport_focus_provider.dart';
import '../../../theme.dart';

/// Floating glass pill at the bottom of the home screen. Combines
/// a search tap region (with an adaptive hint that follows the
/// currently-centered card kind) and a separate compose button
/// (tinted by the focus trip's accent color).
///
/// Tap the search region → [onSearchTap]. Tap the compose icon →
/// [onComposeTap]. The page wires these to open the search and
/// new-chat sheets respectively.
class SearchComposeBar extends ConsumerWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onComposeTap;

  const SearchComposeBar({
    super.key,
    required this.onSearchTap,
    required this.onComposeTap,
  });

  String _hintForKind(String? kind) {
    return switch (kind) {
      'dm' => 'Search or start a DM',
      'group' => 'Search or start a group',
      'decision' => 'Search or open a decision',
      'trip' => 'Search or plan a trip',
      'settlement' => "Search or split with…",
      'itinerary' => 'Search or add an event',
      'memory' => 'Search your memory',
      'ai' => 'Ask @hello anything',
      _ => 'Search or start a chat',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(centeredFeedItemKindProvider);
    final focus = ref.watch(focusTripProvider);
    final composeColor = focus?.accentColor ?? HelloColors.accent;
    final hint = _hintForKind(kind);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onSearchTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: HelloColors.inkSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.18),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  hint,
                                  key: ValueKey<String>(hint),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: HelloColors.inkTertiary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onComposeTap,
                    child: SizedBox(
                      width: 60,
                      height: double.infinity,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: composeColor.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.edit_square,
                            size: 18,
                            color: composeColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
