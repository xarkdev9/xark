import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';

Future<void> openDecisionSheet(BuildContext context, FeedItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DecisionSheet(item: item),
  );
}

class _DecisionSheet extends StatefulWidget {
  final FeedItem item;
  const _DecisionSheet({required this.item});

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  String? _vote;

  ({String title, String? subtitle, String? photoUrl, double score})
      _extract() {
    final it = widget.item;
    if (it is DecisionHeroFeedItem) {
      return (
        title: it.title,
        subtitle: it.subtitle,
        photoUrl: it.photoUrl,
        score: it.item.agreementScore,
      );
    }
    if (it is DecisionSmallFeedItem) {
      return (
        title: it.title,
        subtitle: it.eyebrow,
        photoUrl: null,
        score: it.item.agreementScore,
      );
    }
    return (title: 'Decision', subtitle: null, photoUrl: null, score: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final data = _extract();
    final scorePct = (data.score * 100).round();
    final height = MediaQuery.of(context).size.height * 0.92;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'DECISION',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: HelloColors.inkTertiary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (data.photoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            data.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: HelloColors.surfaceDeep,
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const ColoredBox(
                                color: HelloColors.surfaceDeep,
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3,
                        height: 1.1,
                        color: HelloColors.inkPrimary,
                      ),
                    ),
                    if (data.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        data.subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          '$scorePct%',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 36,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.5,
                            color: HelloColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'consensus',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: data.score.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor:
                            HelloColors.inkPrimary.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          HelloColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _BigVoteButton(
                      label: 'Love it',
                      active: _vote == 'love_it',
                      onTap: () => setState(() => _vote = 'love_it'),
                    ),
                    const SizedBox(height: 10),
                    _BigVoteButton(
                      label: 'Works for me',
                      active: _vote == 'works_for_me',
                      onTap: () => setState(() => _vote = 'works_for_me'),
                    ),
                    const SizedBox(height: 10),
                    _BigVoteButton(
                      label: 'Not for me',
                      active: _vote == 'not_for_me',
                      onTap: () => setState(() => _vote = 'not_for_me'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigVoteButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BigVoteButton({
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
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? HelloColors.accent.withValues(alpha: 0.22)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: HelloColors.accent, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: active ? HelloColors.accent : HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
