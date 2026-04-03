import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

class GhostInput extends StatefulWidget {
  final bool isStreaming;
  final ValueChanged<String> onSend;

  const GhostInput({
    super.key,
    required this.isStreaming,
    required this.onSend,
  });

  @override
  State<GhostInput> createState() => _GhostInputState();
}

class _GhostInputState extends State<GhostInput> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  late final AnimationController _pulseController;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    // Step 2: 1200ms pulsing aura
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: HelloColors.accent.withValues(alpha: 0.15), // #D4536B Rose aura
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    // Auto focus when opened
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !widget.isStreaming) {
         _focusNode.requestFocus();
      }
    });

    _handleStreamingChange();
  }

  @override
  void didUpdateWidget(covariant GhostInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStreaming != widget.isStreaming) {
      _handleStreamingChange();
    }
  }

  void _handleStreamingChange() {
    if (widget.isStreaming) {
      _pulseController.repeat(reverse: true); // Breathing Aura
      _focusNode.unfocus();
    } else {
      _pulseController.stop();
      _pulseController.value = 0.0;
      // Optionally request focus again when stream finishes
      if (mounted) _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty && !widget.isStreaming) {
      // Step 2: Haptic feedback, locking, and pulse logic triggered in parent
      HapticFeedback.lightImpact();
      widget.onSend(_controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _colorAnimation.value, // Zero-Box mandate, no borders just a color wash
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: child,
        );
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        readOnly: widget.isStreaming, // Locking it while streaming
        enabled: !widget.isStreaming,
        onSubmitted: (_) => _submit(),
        textInputAction: TextInputAction.send,
        decoration: InputDecoration.collapsed(
          hintText: "whisper to @hello...",
          hintStyle: HelloTypography.spaceTitle.copyWith(
            color: HelloColors.inkTertiary,
          ),
        ),
        style: HelloTypography.spaceTitle.copyWith(
          color: HelloColors.inkPrimary,
        ),
      ),
    );
  }
}
