import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/viewport_focus_provider.dart';
import '../../../theme.dart';
import 'message_input_bar.dart';

/// Floating glass pill at the bottom of the home screen, wrapping
/// a [MessageInputBar]. The bar gives an iMessage-style compose
/// surface:
/// - `+` button opens the "New Chat / Group / Event" slider
/// - Text field with an adaptive hint that follows the currently-
///   centered card kind
/// - Mic (when empty) morphs into send arrow (when text present).
///   Tapping send triggers [onSend], which opens the search sheet.
class SearchComposeBar extends ConsumerWidget {
  final VoidCallback onPlusTap;
  final VoidCallback onSend;

  const SearchComposeBar({
    super.key,
    required this.onPlusTap,
    required this.onSend,
  });

  String _hintForKind(String? kind) {
    return switch (kind) {
      'dm' => 'Message or search',
      'group' => 'Message group or search',
      'decision' => 'Search a decision',
      'trip' => 'Search a trip',
      'settlement' => 'Search settlements',
      'itinerary' => 'Search events',
      'memory' => 'Search your memory',
      'ai' => 'Ask @hello',
      _ => 'Message or search',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(centeredFeedItemKindProvider);
    final focus = ref.watch(focusTripProvider);
    final accent = focus?.accentColor ?? HelloColors.accent;
    final hint = _hintForKind(kind);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
              child: MessageInputBar(
                hintText: hint,
                onPlusTap: onPlusTap,
                onSend: (_) => onSend(),
                accentColor: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
