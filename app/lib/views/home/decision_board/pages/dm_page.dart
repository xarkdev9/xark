import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/feed_item.dart';
import '../../../../../providers/conversations_provider.dart';
import '../../../../../providers/focus_sources_provider.dart';
import '../../../../../services/palette_extractor.dart';
import '../../../../../main.dart' show engineProvider;
import '../../../../../theme.dart';
import '../../../../../utils/haptics.dart';
import '../chat_bubble.dart';
import '../chromatic_atmosphere.dart';
import '../message_input_bar.dart';
import '../sheets/attachment_sheet.dart';
import '../avatar_utils.dart';
import 'plans_view.dart';

Future<void> openDmPage(BuildContext context, DmFeedItem item) {
  return Navigator.of(context).push(
    CupertinoPageRoute(builder: (_) => DmPage(item: item)),
  );
}

class DmPage extends ConsumerStatefulWidget {
  final DmFeedItem item;
  const DmPage({super.key, required this.item});

  @override
  ConsumerState<DmPage> createState() => _DmPageState();
}

class _DmPageState extends ConsumerState<DmPage> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final PageController _pageController;
  late final AnimationController _breatheController;
  Timer? _breatheTimer;
  int _currentIndex = 0;

  bool _focusPushed = false;
  Animation<double>? _routeAnim;
  // Captured at initState; used in dispose() because Riverpod 3 disposes
  // the ref before State.dispose() runs.
  FocusSourceStack? _focusStack;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusPushed) return;
    final anim = ModalRoute.of(context)?.animation;
    _routeAnim = anim;
    anim?.addListener(_onRouteTick);
    _focusPushed = true;
    _pushFocusSource();
  }

  Future<void> _pushFocusSource() async {
    final peerId = widget.item.conversation.id;
    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: peerId, kind: 'dm'),
    );
    if (!mounted) return;
    _focusStack?.push(
      FocusSource(
        id: 'dm_$peerId',
        palette: palette,
        priority: 50,
        routeAnimation: _routeAnim,
      ),
    );
  }

  void _onRouteTick() {
    if (!mounted) return;
    _focusStack?.touch();
  }

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
    _scrollController = ScrollController();
    _pageController = PageController(initialPage: 0);
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breatheTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _breatheController.stop();
    });

    // The Diegetic Tug: Tease the spatial environment softly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted || !_pageController.hasClients) return;
        if (_pageController.offset > 10.0) return;

        // 1. Physically rubber-band the page to the left softly
        await _pageController.animateTo(
          MediaQuery.sizeOf(context).width * 0.12, 
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutQuart,
        );
        
        if (!mounted || !_pageController.hasClients) return;
        
        // 2. Snap it gently back to center
        await _pageController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutBack,
        );
      });
    });
  }

  @override
  void dispose() {
    _breatheTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    _breatheController.dispose();
    _routeAnim?.removeListener(_onRouteTick);
    final peerId = widget.item.conversation.id;
    _focusStack?.pop('dm_$peerId');
    super.dispose();
  }

  String _displayName() {
    final id = widget.item.conversation.id;
    if (id.isEmpty) return 'Unknown';
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  Widget _buildChatFace(String name) {
    final messagesAsync = ref.watch(
      conversationControllerProvider(widget.item.conversation.id),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // LAYER 1: The Chat Messages (Bottom Layer)
        Positioned.fill(
          child: RepaintBoundary(
            child: messagesAsync.when(
              loading: () => Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: HelloColors.inkSecondary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load messages',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: HelloColors.inkTertiary,
                    ),
                  ),
                ),
              ),
              data: (messages) => ListView.builder(
                controller: _scrollController,
                clipBehavior: Clip.none,
                reverse: true,
                padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 80, 12, 100 + MediaQuery.of(context).padding.bottom),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isOutbound = msg.senderId == 'me';
                  final isFirstInGroup = i == messages.length - 1 || messages[i + 1].senderId != msg.senderId;
                  final isLastInGroup = i == 0 || messages[i - 1].senderId != msg.senderId;
                  return ChatBubble(
                    text: msg.text ?? '',
                    isOutbound: isOutbound,
                    isFirstInGroup: isFirstInGroup,
                    isLastInGroup: isLastInGroup,
                  );
                },
              ),
            ),
          ),
        ),
        // LAYER 4: The Feathered Glass Footer Background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black],
              stops: [0.0, 0.4],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: Container(
                  height: MediaQuery.of(context).padding.bottom + 80,
                  color: HelloColors.voidBg.withValues(alpha: 0.85),
                ),
            ),
          ),
        ),
        // LAYER 5: The Footer UI (Floating Above Glass)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: MessageInputBar(
              hintText: 'Message $name',
              onPlusTap: () => openAttachmentSheet(context),
              onSend: (text) {
                HelloHaptic.confirm();
                if (text.isEmpty) return;
                try {
                  ref.read(engineProvider).getSession(widget.item.conversation.id).sendText(text);
                } catch (_) {}
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // LAYER 1: PageView
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              physics: const ClampingScrollPhysics(),
              children: [
                _buildChatFace(name),
                PlansView(groupId: widget.item.conversation.id),
              ],
            ),
          ),
          
          // LAYER 2: Glass Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.6, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: Container(
                      height: MediaQuery.of(context).padding.top + 80,
                      color: _currentIndex == 1
                          ? Colors.black.withAlpha(20)
                          : HelloColors.voidBg.withAlpha(220),
                    ),
                ),
              ),
            ),
          ),

          // LAYER 3: Header UI
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12, left: 4, top: 4, bottom: 4),
                            child: Icon(
                              CupertinoIcons.back, 
                              size: 28, 
                              color: _currentIndex == 1 ? Colors.white : HelloColors.inkSecondary,
                            ),
                          ),
                        ),
                        HologramAvatar(
                          avatarPath: getAvatarImagePath(name),
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 400),
                                style: TextStyle(
                                  fontFamily: 'Inter', 
                                  fontSize: 24, 
                                  fontWeight: FontWeight.w400, 
                                  letterSpacing: -0.3, 
                                  color: _currentIndex == 1 ? Colors.white : HelloColors.inkPrimary, 
                                  decoration: TextDecoration.none
                                ),
                                child: Text(name),
                              ),
                              const SizedBox(height: 1),
                              AnimatedBuilder(
                                animation: _breatheController,
                                builder: (context, child) {
                                  final opacity = 0.4 + (_breatheController.value * 0.4);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Text(
                                      _currentIndex == 0 ? 'swipe to explore plans' : 'swipe to chat',
                                      style: TextStyle(
                                        fontFamily: 'Inter', 
                                        fontSize: 13, 
                                        fontWeight: FontWeight.w300, 
                                        color: _currentIndex == 1 ? Colors.white70 : HelloColors.inkSecondary, 
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

