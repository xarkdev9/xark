import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'chat_feed.dart';
import '../widgets/chat_input.dart';
import '../main.dart'; // engineProvider

import '../providers/conversation_controller.dart';

class ChatView extends ConsumerWidget {
  final String spaceId;
  const ChatView({super.key, required this.spaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Embedded inside SpaceLayout PageView — no Scaffold/AppBar (parent owns the nav rail)
    return Container(
      color: HelloColors.voidBg,
      child: Column(
        children: [
          Expanded(
            child: ChatFeed(spaceId: spaceId),
          ),
          _TypingIndicatorWidget(spaceId: spaceId),
          LiquidChatComposer(
            onSend: (text) {
              // SECURITY MANDATE: Pure visual morph. No decrypted context to AI.
              ref.read(engineProvider).getSession(spaceId).sendText(text);
            },
          ),
        ],
      ),
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

