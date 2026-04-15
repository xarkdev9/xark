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
import '../sheets/add_item_sheet.dart';
import '../avatar_utils.dart';
import '../plasma/plasma.dart';
import 'plans_view.dart'; // Ported zero-box plans component

Future<void> openGroupPage(BuildContext context, GroupFeedItem item) {
  return Navigator.of(context).push(
    CupertinoPageRoute(builder: (_) => GroupPage(item: item)),
  );
}

class GroupPage extends ConsumerStatefulWidget {
  final GroupFeedItem item;
  const GroupPage({super.key, required this.item});

  @override
  ConsumerState<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends ConsumerState<GroupPage> with SingleTickerProviderStateMixin {
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
    final groupId = widget.item.conversation.id;
    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: groupId, kind: 'group'),
    );
    if (!mounted) return;
    _focusStack?.push(
      FocusSource(
        id: 'group_$groupId',
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
    _pageController = PageController();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breatheTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _breatheController.stop();
    });

    // The Diegetic Tug: Tease the spatial environment after 800ms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted || !_pageController.hasClients) return;
        // Check if user already swiped instinctively
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
    final groupId = widget.item.conversation.id;
    _focusStack?.pop('group_$groupId');
    super.dispose();
  }

  String _displayName() {
    return widget.item.conversation.id
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final memberCount = widget.item.conversation.participantIds.length;
    final unread = widget.item.conversation.unreadCount;
    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // LAYER 1: The PageView (Chat vs Plans)
          Positioned.fill(
            child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                physics: const ClampingScrollPhysics(),
                children: [
                  // ── INDEX 0: CHAT FEED ──
                  _buildChatFace(name),

                  // ── INDEX 1: PLANS STREAM ──
                  PlansView(groupId: widget.item.conversation.id),
                ],
              ),
            ),

          // LAYER 2: The Feathered Glass Header Background (Global Persistent)
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

          // LAYER 3: The Header UI (Floating Above Glass)
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
                          avatarPath: getAvatarImagePath(name, isGroup: true),
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
                              // Morphing subtext based on page
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
                                        letterSpacing: 0.2
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
          
          // Ambient right-edge glow hint on Chat tab
          if (_currentIndex == 0)
            Positioned(
              right: 0, top: 0, bottom: 0, width: 14,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [HelloColors.accent.withAlpha(15), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            
          // Floating [+] Add Item button (visible on Plans page)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 80,
            right: 20,
            child: _currentIndex == 1
                ? GestureDetector(
                    onTap: () {
                      HelloHaptic.tap();
                      openAddItemSheet(context);
                    },
                    child: PlasmaFill(
                      shape: BoxShape.circle,
                      width: 48,
                      height: 48,
                      child: Icon(Icons.add_rounded, size: 24, color: Colors.white),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // LAYER 3: Morphing Symbiotic Anchor (Dynamic Island Paradigm)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                // Determine raw swipe phase. Handle initial unattached states.
                double t = 0.0;
                if (_pageController.hasClients && _pageController.position.haveDimensions) {
                  t = _pageController.page ?? 0.0;
                } else {
                  t = _currentIndex.toDouble();
                }

                // Chat View = t=0.0. Plans View = t=1.0.
                final chatOpacity = (1.0 - t).clamp(0.0, 1.0);

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // B. The Chat Message Input Bar (Fades Out + Slides Down via Swipe)
                    if (chatOpacity > 0.01)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Opacity(
                          opacity: chatOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1.0 - chatOpacity)),
                            child: IgnorePointer(
                              ignoring: chatOpacity < 0.5,
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
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildChatFace(String name) {
    final messagesAsync = ref.watch(
      conversationControllerProvider(widget.item.conversation.id),
    );

    return Stack(
      children: [
        // The messages list
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
                    senderId: isOutbound ? null : msg.senderId,
                  );
                },
              ),
            ),
          ),
        ),

        // Feathered glass footer specific to chat
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: IgnorePointer(
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
                    color: HelloColors.voidBg.withAlpha(220),
                ),
              ),
            ),
          ),
        ),

      ],
    );
  }
}
