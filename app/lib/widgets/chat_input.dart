import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../main.dart'; // To access engineProvider

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isHelloMode = false;

  @override
  void initState() {
    super.initState();
    // Target 9: Tactical text listener measuring @hello intent
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

    // Target 8: Optimistic UI. Send instantly for 120fps perceived input snap.
    ref.read(engineProvider).getSession('default_space').sendText(text);
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
        bottom: 96.0, // Global input padding bottom boundary: 96px
      ),
      child: Row(
        children: [
          Expanded(
            // Target 9: fluid color morph mapping to intelligence threshold constraints
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn, // Natural Apple-tier physical inertia
              decoration: BoxDecoration(
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
                  hintText: _isHelloMode ? "ask hello anything..." : "Message...",
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
          // Fluid transition for the send button
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
