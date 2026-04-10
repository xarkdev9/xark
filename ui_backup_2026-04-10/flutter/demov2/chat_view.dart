import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'chat_feed.dart';
import '../widgets/chat_input.dart';
import '../main.dart';

import '../providers/conversation_controller.dart';

// ═══════════════════════════════════════════════════════
// OVERLAY ARCHITECTURE — Z-axis layered Stack
//
// Layer 0: Ambient gradient (animated, full-bleed)
// Layer 1: Chat messages (full screen, padded top/bottom)
// Layer 2: Floating glass input bar (Positioned bottom)
//
// NO fake gradient fades. NO rigid Columns. NO SafeArea clamps.
// Messages scroll UNDER the glass overlays and blur naturally.
// ═══════════════════════════════════════════════════════

const _groupAmbientColors = <String, List<Color>>{
  'family': [Color(0xFFFFB347), Color(0xFFFF6B6B)],
  'bali': [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
  'tokyo': [Color(0xFF9B59B6), Color(0xFF3498DB)],
  'sarah': [Color(0xFFE74C8B), Color(0xFFF39C12)],
  'poker': [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
  'alaska': [Color(0xFF45B7D1), Color(0xFF96E6A1)],
  'swiss': [Color(0xFF87CEEB), Color(0xFF98FB98)],
  'sf': [Color(0xFFFF6347), Color(0xFFFFD700)],
  'delhi': [Color(0xFFFF9933), Color(0xFF138808)],
};

class ChatView extends ConsumerStatefulWidget {
  final String spaceId;
  const ChatView({super.key, required this.spaceId});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        // ═══ LAYER 0: Ambient gradient (full-bleed, animated) ═══
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              final t = _gradientController.value;
              final colors = _groupAmbientColors[widget.spaceId] ??
                  [const Color(0xFFFF6B35), const Color(0xFFFF9F43)];
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(t - 0.5, -1),
                    end: Alignment(1 - t, 1),
                    colors: [
                      colors[0].withValues(alpha: 0.07),
                      colors[1].withValues(alpha: 0.07),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ═══ LAYER 1: Chat messages (full screen, padded for overlays) ═══
        Positioned.fill(
          child: ChatFeed(spaceId: widget.spaceId),
        ),

        // ═══ LAYER 2: Floating glass input bar ═══
        Positioned(
          bottom: bottomInset + 8,
          left: 12,
          right: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TypingIndicatorWidget(spaceId: widget.spaceId),
                    LiquidChatComposer(
                      onSend: (text) {
                        ref.read(engineProvider).getSession(widget.spaceId).sendText(text);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingIndicatorWidget extends ConsumerStatefulWidget {
  final String spaceId;
  const _TypingIndicatorWidget({required this.spaceId});

  @override
  ConsumerState<_TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends ConsumerState<_TypingIndicatorWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typingAsync = ref.watch(typingProvider(widget.spaceId));

    final isTyping = typingAsync.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutExpo,
      child: isTyping
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 20.0, bottom: 4.0, top: 8.0),
              alignment: Alignment.centerLeft,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: const Text(
                  "typing...",
                  style: HelloTypography.hint,
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
