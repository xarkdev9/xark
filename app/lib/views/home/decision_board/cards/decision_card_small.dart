import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '_card_shell.dart';

/// 1-col decision card with inline vote buttons. React without
/// opening, or tap to open the full decision sheet.
class DecisionCardSmall extends StatefulWidget {
  final DecisionSmallFeedItem item;
  final VoidCallback onTap;

  const DecisionCardSmall({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<DecisionCardSmall> createState() => _DecisionCardSmallState();
}

class _DecisionCardSmallState extends State<DecisionCardSmall> {
  String? _myVote;

  @override
  Widget build(BuildContext context) {
    final score = (widget.item.item.agreementScore * 100).round();

    return CardShell(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item.eyebrow != null)
            Text(
              widget.item.eyebrow!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
                color: HelloColors.accent,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            widget.item.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: HelloColors.inkPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _VoteButton(
                label: '♥',
                active: _myVote == 'love_it',
                onTap: () => setState(() => _myVote = 'love_it'),
              ),
              const SizedBox(width: 6),
              _VoteButton(
                label: '✓',
                active: _myVote == 'works_for_me',
                onTap: () => setState(() => _myVote = 'works_for_me'),
              ),
              const SizedBox(width: 6),
              _VoteButton(
                label: '✗',
                active: _myVote == 'not_for_me',
                onTap: () => setState(() => _myVote = 'not_for_me'),
              ),
              const Spacer(),
              Text(
                '$score%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.item.item.agreementScore.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: HelloColors.inkPrimary.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(
                HelloColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _VoteButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: active
              ? HelloColors.accent.withValues(alpha: 0.18)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(6),
          border: active
              ? Border.all(color: HelloColors.accent, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: active
                ? HelloColors.accent
                : HelloColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
