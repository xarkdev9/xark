import 'package:flutter/material.dart';

import '../../../../theme.dart';

enum EmptyStateKind { chats, groups, decisions }

/// Shared empty state for all 3 cards. Renders an icon + tagline + CTA.
/// CTAs are text actions (no pills, no buttons) per Zero-Box doctrine.
class CardEmptyState extends StatelessWidget {
  final EmptyStateKind kind;
  final VoidCallback onCtaTap;

  const CardEmptyState({
    super.key,
    required this.kind,
    required this.onCtaTap,
  });

  IconData get _icon {
    switch (kind) {
      case EmptyStateKind.chats:
        return Icons.chat_bubble_outline_rounded;
      case EmptyStateKind.groups:
        return Icons.people_outline_rounded;
      case EmptyStateKind.decisions:
        return Icons.lightbulb_outline_rounded;
    }
  }

  String get _tagline {
    switch (kind) {
      case EmptyStateKind.chats:
        return 'No conversations yet';
      case EmptyStateKind.groups:
        return 'No group chats yet';
      case EmptyStateKind.decisions:
        return 'Nothing to vote on';
    }
  }

  String get _ctaLabel {
    switch (kind) {
      case EmptyStateKind.chats:
        return 'Start a chat';
      case EmptyStateKind.groups:
        return 'Create a group';
      case EmptyStateKind.decisions:
        return 'Start a decision';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icon,
              size: 48,
              color: HelloColors.inkTertiary,
            ),
            const SizedBox(height: 20),
            Text(
              _tagline,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: HelloColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCtaTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ctaLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.17,
                      color: HelloColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: HelloColors.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
