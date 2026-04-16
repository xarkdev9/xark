import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '../plasma/plasma.dart';

Future<void> openDecisionSheet(BuildContext context, FeedItem item) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'DecisionSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DecisionSheet(item: item),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
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

  ({
    String title,
    String? subtitle,
    String? photoUrl,
    double score,
    bool isLiveEvent,
  }) _extract() {
    final it = widget.item;
    if (it is DecisionHeroFeedItem) {
      return (
        title: it.title,
        subtitle: it.subtitle,
        photoUrl: it.photoUrl,
        score: it.item.agreementScore,
        isLiveEvent: it.liveTag == 'LIVE EVENT',
      );
    }
    if (it is DecisionSmallFeedItem) {
      return (
        title: it.title,
        subtitle: it.eyebrow,
        photoUrl: null,
        score: it.item.agreementScore,
        isLiveEvent: false,
      );
    }
    return (
      title: 'Decision',
      subtitle: null,
      photoUrl: null,
      score: 0.0,
      isLiveEvent: false,
    );
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
            color: HelloColors.voidBg.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
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
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.isLiveEvent ? 'LIVE EVENT' : 'DECISION',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: data.isLiveEvent
                              ? HelloColors.liveGreen
                              : HelloColors.inkTertiary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
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
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (data.isLiveEvent)
                      _ConstellationHero(score: scorePct)
                    else if (data.photoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            data.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
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
                      style: TextStyle(
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
                        style: TextStyle(
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
                          style: TextStyle(
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
                    PlasmaProgressBar(
                      value: data.score.clamp(0.0, 1.0),
                      height: 4,
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
      child: active
          ? PlasmaStroke(
              width: 1,
              borderRadius: BorderRadius.circular(12),
              child: PlasmaFill(
                alpha: 0.22,
                borderRadius: BorderRadius.circular(12),
                height: 52,
                child: Center(
                  child: PlasmaTint(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white, // opaque for srcIn
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container(
              height: 52,
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ),
    );
  }
}

/// Swiss-in-June style constellation mind-map. Big consensus number
/// in the center, 5 icon nodes orbiting around a radial glow.
class _ConstellationHero extends StatelessWidget {
  final int score;
  const _ConstellationHero({required this.score});

  static const _nodes = <(String, IconData, Offset)>[
    ('HOTELS', Icons.hotel_rounded, Offset(-100, -70)),
    ('FLIGHTS', Icons.flight_rounded, Offset(92, -80)),
    ('BUDGET', Icons.account_balance_wallet_rounded, Offset(110, 30)),
    ('VOTES', Icons.check_circle_outline_rounded, Offset(0, 105)),
    ('MAP', Icons.map_rounded, Offset(-8, -120)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer radial glow
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 0.72],
                  ),
                ),
              ),
              // Center consensus number
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HOTEL VOTE LIVE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      color: HelloColors.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$score',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -3,
                      height: 1,
                      color: Color(0xFFFFB380),
                    ),
                  ),
                ],
              ),
              // Orbiting nodes
              for (final (label, icon, offset) in _nodes)
                Transform.translate(
                  offset: offset,
                  child: _ConstellationNode(label: label, icon: icon),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstellationNode extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ConstellationNode({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: HelloColors.inkPrimary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.5,
            color: HelloColors.inkTertiary,
          ),
        ),
      ],
    );
  }
}
