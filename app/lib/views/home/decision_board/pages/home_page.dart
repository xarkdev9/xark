import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/ambient_palette_provider.dart';
import '../../../../providers/filtered_feed_providers.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../chromatic_atmosphere.dart';
import 'home/action_words_row.dart';
import 'home/context_label.dart';
import 'home/cosmos_sender_model.dart';
import 'home/foreground_avatar.dart';
import 'home/queue_row.dart';
import 'home/reward_controller.dart';

/// Cosmos Home — floating avatar surface with vsynced reward sequence.
///
/// Ambient state: atmosphere + foreground avatar + context label + queue.
/// Expanded state: tap avatar → cross-fade to full message + actions.
/// Rewarding state: tap action → 1700ms reward plays on locked snapshot
///   (levitation + plasma infusion + atmosphere pulse + ascent + handoff),
///   Expanded layer dismisses after 500ms so ActionWord plasma reaches full.
///
/// Patches embedded:
/// - v2 #1: ref.watch unconditional (subscriptions preserved during reward)
/// - v2 #3: SingleTickerProviderStateMixin → RewardController.vsync
/// - v2 #4: async _onActionTap with 500ms delay before Expanded collapse
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  FocusSourceStack? _focusStack;
  String? _pushedSourceId;

  PendingSender? _focusedSender;
  final TextEditingController _replyController = TextEditingController();

  late final RewardController _rewardController;

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
    _rewardController = RewardController(vsync: this);
    _rewardController.addListener(_onRewardTick);
  }

  @override
  void dispose() {
    if (_pushedSourceId != null) {
      _focusStack?.pop(_pushedSourceId!);
    }
    _replyController.dispose();
    _rewardController.removeListener(_onRewardTick);
    _rewardController.dispose();
    super.dispose();
  }

  void _onRewardTick() {
    if (mounted) setState(() {});
  }

  Future<void> _syncForegroundPalette(PendingSender? sender) async {
    final stack = _focusStack;
    if (stack == null) return;

    if (sender == null) {
      if (_pushedSourceId != null) {
        stack.pop(_pushedSourceId!);
        _pushedSourceId = null;
      }
      return;
    }

    final id = 'home_fg_${sender.id}';
    if (_pushedSourceId == id) return;

    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: sender.name, kind: 'dm'),
    );
    if (!mounted) return;
    if (_pushedSourceId != null && _pushedSourceId != id) {
      stack.pop(_pushedSourceId!);
    }
    stack.push(FocusSource(
      id: id,
      palette: palette,
      priority: 20,
    ));
    _pushedSourceId = id;
  }

  void _onAvatarTap(PendingSender sender) {
    setState(() {
      _focusedSender = sender;
      _replyController.clear();
    });
  }

  void _dismissExpansion() {
    setState(() {
      _focusedSender = null;
      _replyController.clear();
    });
  }

  bool _isAffirmative(String word) {
    return word == 'Yes' ||
        word == 'Love' ||
        word == 'Works' ||
        word == 'Pay now';
  }

  AmbientPalettePulse _pulseFor(String word) {
    if (_isAffirmative(word)) return AmbientPalettePulse.affirm;
    if (word == 'Maybe') return AmbientPalettePulse.hesitate;
    return AmbientPalettePulse.negate;
  }

  /// Stub for engine mutation — Great Wiring pass routes this to
  /// session.vote / session.sendText / settlement.pay.
  void _applyAction(PendingSender sender, String word) {}

  Future<void> _onActionTap(String word) async {
    final sender = _focusedSender;
    if (sender == null) return;

    // Fire atmosphere pulse (fire-and-forget 800ms)
    ref.read(ambientPalettePulseProvider.notifier).pulse(_pulseFor(word));

    // Fire engine mutation in parallel (stubbed — Great Wiring)
    _applyAction(sender, word);

    // Start the reward-sequence animation against a snapshot.
    // The acted-on sender is what levitates + dissolves; queue
    // excludes them.
    final liveQueue = ref.read(pendingSendersQueueProvider);
    _rewardController.start(
      foreground: sender,
      queue: liveQueue.where((s) => s != sender).toList(),
    );

    // CRITICAL (v2-review Patch #4): wait for ActionWord's 500ms
    // plasma sweep to finish before collapsing the Expanded layer.
    // Collapsing in 180ms (AnimatedOpacity) would fade the word
    // to invisible before its own reward plays — user never sees it.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _focusedSender = null;
      _replyController.clear();
    });
  }

  Future<void> _onReplySubmit() async {
    final sender = _focusedSender;
    if (sender == null) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(ambientPalettePulseProvider.notifier)
        .pulse(AmbientPalettePulse.affirm);

    _applyAction(sender, text);

    final liveQueue = ref.read(pendingSendersQueueProvider);
    _rewardController.start(
      foreground: sender,
      queue: liveQueue.where((s) => s != sender).toList(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _focusedSender = null;
      _replyController.clear();
    });
  }

  String _expandedMessageText(PendingSender sender) {
    return sender.subject.isEmpty ? '(no message content)' : sender.subject;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // v2-review Patch #1: unconditional ref.watch. Skipping the watch
    // based on _rewardController.isAnimating would unsubscribe the
    // widget from the providers and (if autoDispose / eviction heuristics)
    // destroy cached state. Watch always; branch on the value.
    final liveForeground = ref.watch(freshestPendingSenderProvider);
    final liveQueue = ref.watch(pendingSendersQueueProvider);

    // Animation lock: during the reward, prefer the locked snapshot
    // (captured at reward.start()) so the UI doesn't flash the next
    // person mid-sequence. Subscription above still holds.
    final foreground = _rewardController.isAnimating
        ? _rewardController.lockedForeground
        : liveForeground;
    final queue = _rewardController.isAnimating
        ? (_rewardController.lockedQueue ?? const <PendingSender>[])
        : liveQueue;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncForegroundPalette(_focusedSender ?? foreground);
    });

    // Empty state: no pending items at all (not during reward).
    if (foreground == null &&
        queue.isEmpty &&
        _focusedSender == null &&
        !_rewardController.isAnimating) {
      return AtmosphereDensityScope(
        density: AtmosphereDensity.focus,
        child: Center(
          child: Text(
            'All Caught Up',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ),
      );
    }

    final isExpanded = _focusedSender != null;
    final displayedSender = _focusedSender ?? foreground;

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Dismiss layer — tap-outside dismisses Expanded
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissExpansion,
                  ),
                ),
              ),

              // Foreground avatar — reward-aware now
              if (displayedSender != null)
                Positioned(
                  top: h * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForegroundAvatar(
                      sender: displayedSender,
                      rewardController: _rewardController,
                      onTap: isExpanded
                          ? null
                          : () => _onAvatarTap(displayedSender),
                    ),
                  ),
                ),

              // Queue promotion — visible only during ascending phase,
              // rises into the foreground slot as the previous avatar
              // drifts up (v2-review Patch #5a)
              if (_rewardController.isAnimating &&
                  _rewardController.phase == RewardPhase.ascending &&
                  (_rewardController.lockedQueue?.isNotEmpty ?? false))
                Positioned(
                  top: h * 0.18,
                  left: 0,
                  right: 0,
                  child: QueuePromotionAvatar(
                    sender: _rewardController.lockedQueue!.first,
                    rewardController: _rewardController,
                  ),
                ),

              // Ambient layer — context label + queue
              AnimatedOpacity(
                opacity: isExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: isExpanded,
                  child: Stack(
                    children: [
                      if (foreground != null)
                        Positioned(
                          top: h * 0.18 + 140 + 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: ContextLabel(sender: foreground),
                          ),
                        ),
                      Positioned(
                        top: h * 0.18 + 140 + 12 + 20 + 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: QueueRow(
                            senders: queue,
                            onTap: _onAvatarTap,
                            rewardController: _rewardController,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded layer — full message + action words
              AnimatedOpacity(
                opacity: isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: displayedSender == null || !isExpanded
                      ? const SizedBox.shrink()
                      : Stack(
                          children: [
                            Positioned(
                              top: h * 0.18 + 140 + 12,
                              left: 24,
                              right: 24,
                              child: Text(
                                _expandedMessageText(displayedSender),
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: HelloColors.inkPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Positioned(
                              top: h * 0.18 + 140 + 12 + 130 + 32,
                              left: 32,
                              right: 32,
                              child: ActionWordsRow(
                                kind: displayedSender.messageKind,
                                onAction: _onActionTap,
                                replyController: _replyController,
                                onReplySubmit: _onReplySubmit,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
