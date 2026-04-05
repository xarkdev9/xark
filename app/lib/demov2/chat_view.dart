import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'chat_feed.dart';
import '../widgets/chat_input.dart';
import '../main.dart'; // engineProvider

import '../providers/conversation_controller.dart';

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
    // iMessage-style: messages scroll BEHIND floating top and bottom bars
    // with gradient fades at the edges
    return Stack(
        children: [
          // Ambient gradient with parallax (first layer, behind messages)
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
                        colors[0].withValues(alpha: 0.06),
                        colors[1].withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Messages fill the entire space, scroll behind everything
          Positioned.fill(
            child: ChatFeed(spaceId: widget.spaceId),
          ),

          // Top fade removed — header in space_layout handles the fade

          // Bottom: typing indicator + composer floating over messages
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bottom fade: messages fade before reaching composer
                IgnorePointer(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          HelloColors.voidBg.withValues(alpha: 0.6),
                          HelloColors.voidBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Typing + Composer on transparent background (glass effect ready)
                Container(
                  color: Colors.transparent,
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
              ],
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
              padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
              alignment: Alignment.centerLeft,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: const Text(
                  "Alice is typing...", // Typographic indicator per doctrine
                  style: HelloTypography.hint,
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// Consolidated Composer enforcing the strict @hello AI protocol.
class _Composer extends ConsumerStatefulWidget {
  final String spaceId;
  const _Composer({required this.spaceId});

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final TextEditingController _controller = TextEditingController();
  bool _isHelloMode = false;

  @override
  void initState() {
    super.initState();
    // Strictly listening for the @hello trigger case-insensitively.
    _controller.addListener(() {
      final text = _controller.text;
      final helloMode = text.toLowerCase().contains('@hello');
      if (helloMode != _isHelloMode) {
        setState(() {
          _isHelloMode = helloMode;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // SECURITY MANDATE: Pure visual UI morph. No context decryption fed to AI.
    // We send payload precisely as standard text over the E2EE stream.
    ref.read(engineProvider).getSession(widget.spaceId).sendText(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HelloColors.chrome,
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 12.0,
        bottom: 96.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              decoration: BoxDecoration(
                // Morphs to #D4536B logic (HelloColors.accent) securely representing intent
                color: _isHelloMode
                    ? HelloColors.accent.withValues(alpha: 0.15)
                    : HelloColors.recessed,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: _isHelloMode
                      ? HelloColors.accent.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: _isHelloMode ? "ask hello anything..." : "Message...", // Global Branding
                  hintStyle: HelloTypography.hint.copyWith(
                    color: _isHelloMode
                        ? HelloColors.accent.withValues(alpha: 0.6)
                        : HelloColors.inkTertiary,
                  ),
                  border: InputBorder.none,
                ),
                style: HelloTypography.body.copyWith(
                  color: _isHelloMode ? HelloColors.accent : HelloColors.inkPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: const BoxDecoration(
              color: HelloColors.accent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
