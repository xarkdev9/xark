import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'chat_feed.dart';
import 'chat_input.dart';
import 'demov1_main.dart'; // engineProvider

import 'conversation_controller.dart';

class ChatView extends ConsumerWidget {
  final String spaceId;
  const ChatView({super.key, required this.spaceId});

  static const _titleMap = {
    'bali': 'Bali Trip 🌴',
    'sarah': "Sarah's Birthday",
    'alice': 'Alice',
    'tokyo': 'Tokyo 2026',
    'horizon': 'Project Horizon',
    'dm_emma': 'Emma',
    'dm_liam': 'Liam',
    'dm_olivia': 'Olivia',
    'dm_noah': 'Noah',
    'dm_ava': 'Ava',
    'dm_ethan': 'Ethan',
    'dm_sophia': 'Sophia',
    'dm_mason': 'Mason',
    'group_weekend_hike': 'Weekend Hike 🥾',
    'group_roommates': 'Roommates',
    'group_book_club': 'Book Club 📚',
    'group_startup_ideas': 'Startup Ideas 💡',
    'group_family': 'Family ❤️',
    'group_gym_crew': 'Gym Crew 💪',
    'group_music_fest': 'Music Fest 🎵',
  };

  String _resolveTitle(String id) => _titleMap[id] ?? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      appBar: AppBar(
        backgroundColor: HelloColors.voidBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20,
            color: HelloColors.inkPrimary.withValues(alpha: 0.7)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _resolveTitle(spaceId),
              style: HelloTypography.spaceTitle.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            _PresenceIndicator(spaceId: spaceId),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ChatFeed(spaceId: spaceId), // Keeping the separate Feed component
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

class _PresenceIndicator extends ConsumerWidget {
  final String spaceId;
  const _PresenceIndicator({required this.spaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(presenceProvider(spaceId));

    return presenceAsync.when(
      data: (presence) {

        final isOnline = presence.isOnline;
        String text = '';
        if (isOnline) {
          text = 'Online';
        } else if (presence.lastSeenAt != null) {
          final now = DateTime.now();
          final diff = now.difference(presence.lastSeenAt!);
          if (diff.inMinutes < 60) {
            text = 'Last seen ${diff.inMinutes}m ago';
          } else if (diff.inHours < 24) {
             text = 'Last seen ${diff.inHours}h ago';
          } else {
             text = 'Last seen ${diff.inDays}d ago';
          }
        }

        if (text.isEmpty) return const SizedBox.shrink();

        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: isOnline ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Text(
            text,
            style: HelloTypography.hint.copyWith(
              color: const Color(0xFFD4536B),
            ),
          ),
          secondChild: Text(
            text,
            style: HelloTypography.hint.copyWith(
              color: HelloColors.inkTertiary,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
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
