import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';
import '../providers/consensus_listener.dart';
import '../demov2/gold_burst.dart';

class ActionCardWidget extends ConsumerStatefulWidget {
  final DecisionItem item;
  final VoidCallback onReact;
  final VoidCallback onPinCommit;

  const ActionCardWidget({
    super.key,
    required this.item,
    required this.onReact,
    required this.onPinCommit,
  });

  @override
  ConsumerState<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends ConsumerState<ActionCardWidget> {
  double _agreementScore = 0.0;
  bool _isLocallyLocked = false;
  
  @override
  void initState() {
    super.initState();
    _agreementScore = widget.item.agreementScore;
    _checkConsensus();
  }

  void _checkConsensus() {
    if (_agreementScore >= 0.8 && !_isLocallyLocked) {
      _isLocallyLocked = true;
      Future.microtask(() {
        if (ref.read(globalLockProvider) == null && mounted) {
          ref.read(globalLockProvider.notifier).lock(widget.item.id);
        }
      });
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 0.80) return HelloColors.gold;
    if (score >= 0.50) return Colors.cyan;
    return Colors.amber;
  }

  void _handleReaction(String reaction) {
    setState(() {
      if (reaction == 'love') {
        _agreementScore += 0.8;
      } else if (reaction == 'okay') {
        _agreementScore += 0.5;
      }
      _checkConsensus();
    });
    widget.onReact();
  }

  @override
  Widget build(BuildContext context) {
    final bool isIgnited = _agreementScore >= 0.8 || _isLocallyLocked;

    final photoUrl = widget.item.photoUrl;

    return GoldBurstOverlay(
      trigger: isIgnited,
      child: Container(
        decoration: BoxDecoration(
          color: HelloColors.chrome,
          borderRadius: BorderRadius.circular(26.0),
          boxShadow: isIgnited
              ? [
                  BoxShadow(
                    color: HelloColors.gold.withValues(alpha: 0.2),
                    blurRadius: 30.0,
                    offset: const Offset(0, 10),
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Image Background (asset or network)
              if (photoUrl != null && photoUrl.isNotEmpty)
                photoUrl.startsWith('assets/')
                    ? Image.asset(photoUrl, fit: BoxFit.cover)
                    : Image.network(photoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black12))
              else
                Container(color: Colors.black12),

              // 2. The Dark Wash
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: const Alignment(0.0, -0.2), // Fades out at 60% mark
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Title + Score (Bottom)
              Positioned(
                left: 16.0,
                bottom: 56.0, // Room for voting bar
                right: 16.0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.item.title,
                            style: HelloTypography.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              fontSize: 16,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.item.description!.split('\n').first,
                              style: HelloTypography.hint.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_agreementScore * 100).toInt()}',
                      style: HelloTypography.hero.copyWith(
                        fontSize: 28,
                        color: _getScoreColor(_agreementScore),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Voting Bar (Bottom — full width, frosted glass)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(26),
                      bottomRight: Radius.circular(26),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pass — dim, transparent
                      _VoteChip(
                        label: 'Pass',
                        color: Colors.white.withValues(alpha: 0.15),
                        textColor: Colors.white.withValues(alpha: 0.5),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleReaction('pass');
                        },
                      ),
                      const SizedBox(width: 8),
                      // Okay — subtle white fill
                      _VoteChip(
                        label: 'Okay',
                        color: Colors.white.withValues(alpha: 0.25),
                        textColor: Colors.white.withValues(alpha: 0.85),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleReaction('okay');
                        },
                      ),
                      const SizedBox(width: 8),
                      // Love — Liquid Fire gradient border + glow
                      Expanded(
                        child: _VoteChip(
                          label: 'Love',
                          color: HelloColors.accent.withValues(alpha: 0.25),
                          textColor: HelloColors.accent,
                          borderColor: HelloColors.accent.withValues(alpha: 0.6),
                          isLove: true,
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            _handleReaction('love');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact vote chip with spring physics and Liquid Fire support.
class _VoteChip extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final bool isLove;
  final VoidCallback onTap;

  const _VoteChip({
    required this.label,
    required this.color,
    required this.textColor,
    this.borderColor,
    this.isLove = false,
    required this.onTap,
  });

  @override
  State<_VoteChip> createState() => _VoteChipState();
}

class _VoteChipState extends State<_VoteChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 1.0, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _onTapDown(TapDownDetails _) => _controller.value = 0.88;

  void _onTapUp(TapUpDetails _) {
    widget.onTap();
    final spring = const SpringDescription(mass: 1.0, stiffness: 500.0, damping: 24.0);
    _controller.animateWith(SpringSimulation(spring, _controller.value, 1.0, 0.0));
  }

  void _onTapCancel() {
    final spring = const SpringDescription(mass: 1.0, stiffness: 500.0, damping: 24.0);
    _controller.animateWith(SpringSimulation(spring, _controller.value, 1.0, 0.0));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(14),
                border: widget.borderColor != null
                    ? Border.all(color: widget.borderColor!, width: 1.5)
                    : null,
                boxShadow: widget.isLove
                    ? [BoxShadow(color: HelloColors.accent.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 0)]
                    : [],
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: widget.textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
