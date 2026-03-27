import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/encrypted_image_view.dart';
import '../providers/consensus_listener.dart';

import 'package:chat_engine/chat_engine.dart';

class ActionCardWidget extends ConsumerStatefulWidget {
  final Message message;
  final String? inlineThumbnail; // Pass this if E2EE EncryptedMedia applies

  const ActionCardWidget({
    super.key,
    required this.message,
    this.inlineThumbnail,
  });

  @override
  ConsumerState<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends ConsumerState<ActionCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_animController);
  }

  void _runSpringRelease() {
    // Target 11: Apple-Scale physical mass and depth
    final spring = const SpringDescription(mass: 1.0, stiffness: 500.0, damping: 24.0);
    final simulation = SpringSimulation(spring, _animController.value, 0.0, _animController.velocity);
    _animController.animateWith(simulation);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double get _agreementScore => 0.85; // Fixed mock threshold
  bool get _isLocked => false;
  String get _title => widget.message.text ?? "Unknown Action";

  Color get _consensusColor {
    if (_agreementScore >= 0.8) return HelloColors.gold;
    if (_agreementScore >= 0.3) return HelloColors.accent;
    return HelloColors.seekingAmber;
  }

  @override
  Widget build(BuildContext context) {
    // Target 14: Global Lock
    final isGloballyLocked = ref.watch(globalLockProvider) || _isLocked;

    return GestureDetector(
      onTapDown: isGloballyLocked ? null : (_) {
        _animController.duration = const Duration(milliseconds: 100);
        _animController.forward();
      },
      onTapUp: isGloballyLocked ? null : (_) => _runSpringRelease(),
      onTapCancel: isGloballyLocked ? null : () => _runSpringRelease(),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          // Dim opacity smoothly if globally locked
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: isGloballyLocked ? 0.6 : 1.0,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 260,
                height: 380, // clamp approx
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0), // Zero-Box doctrine exception: exactly 16px
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A2A3A), Color(0xFF0A0A14)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                     if (widget.inlineThumbnail != null)
                       Positioned.fill(
                         child: EncryptedImageView(
                           metadata: widget.message.media ?? MediaMetadata(
                             mediaId: 'mock',
                             mimeType: 'image/jpeg',
                             sizeBytes: 0,
                             inlineThumbnail: widget.inlineThumbnail,
                           ),
                           inlineThumbnail: widget.inlineThumbnail,
                           fillContainer: true,
                         )
                       ),
                     
                     Positioned.fill(
                       child: DecoratedBox(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.bottomCenter,
                             end: Alignment.center,
                             colors: [
                               Colors.black.withValues(alpha: 0.95),
                               Colors.transparent,
                             ],
                           )
                         )
                       )
                     ),

                     Positioned(
                       bottom: 44.0,
                       left: 16.0,
                       right: 16.0,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             "${(_agreementScore * 100).round()}%",
                             style: TextStyle(
                               fontSize: 40.0,
                               fontWeight: FontWeight.w300,
                               color: _consensusColor,
                               height: 1.0,
                               letterSpacing: -1.0,
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             _title,
                             style: const TextStyle(
                               fontSize: 16.0,
                               fontWeight: FontWeight.w300,
                               color: Color(0xFFE8E8EC),
                               height: 1.3,
                             ),
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
      ),
    );
  }
}
