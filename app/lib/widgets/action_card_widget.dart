import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';
import '../providers/consensus_listener.dart';

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

    return Container(
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
            // 1. Image Background
            if (photoUrl != null && photoUrl.isNotEmpty) // Use Image.network for external Unsplash URL
              Image.network(photoUrl, fit: BoxFit.cover)
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

            // 3. Typography & Metadata (Bottom Left)
            Positioned(
              left: 24.0,
              bottom: 24.0,
              right: 140.0, // Leave room for signals
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                     (_agreementScore * 100).toInt().toString(),
                     style: HelloTypography.hero.copyWith(
                       fontSize: 48,
                       color: _getScoreColor(_agreementScore),
                       height: 1.0,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     widget.item.title,
                     style: HelloTypography.spaceTitle.copyWith(
                       color: Colors.white,
                       fontWeight: FontWeight.w400,
                     ),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
              ),
            ),

            // 4. The 3-Signal Physics Matrix (Bottom Right)
            Positioned(
              right: 24.0,
              bottom: 24.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _PhysicsSignalButton(
                     label: "Pass",
                     onTap: () {
                       HapticFeedback.lightImpact();
                       _handleReaction('pass');
                     },
                   ),
                   const SizedBox(width: 8),
                   _PhysicsSignalButton(
                     label: "Okay",
                     onTap: () {
                       HapticFeedback.lightImpact();
                       _handleReaction('okay');
                     },
                   ),
                   const SizedBox(width: 8),
                   _PhysicsSignalButton(
                     label: "Love",
                     isRose: true,
                     onTap: () {
                       HapticFeedback.heavyImpact();
                       _handleReaction('love');
                     },
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

class _PhysicsSignalButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isRose;

  const _PhysicsSignalButton({
    required this.label,
    required this.onTap,
    this.isRose = false,
  });

  @override
  State<_PhysicsSignalButton> createState() => _PhysicsSignalButtonState();
}

class _PhysicsSignalButtonState extends State<_PhysicsSignalButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.value = 0.85; // Instantly shrink
  }

  void _onTapUp(TapUpDetails details) {
    widget.onTap();
    _runSpringRelease();
  }

  void _onTapCancel() {
    _runSpringRelease();
  }

  void _runSpringRelease() {
    final spring = const SpringDescription(mass: 1.0, stiffness: 500.0, damping: 24.0);
    final simulation = SpringSimulation(spring, _controller.value, 1.0, 0.0);
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRose ? const Color(0xFFD4536B) : Colors.white;

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.label,
                style: HelloTypography.label.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
